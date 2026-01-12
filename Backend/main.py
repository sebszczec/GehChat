"""
GehChat Backend Server
Main application entry point - IRC Bridge
"""
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import logging
import asyncio
import json
import socket
from typing import Optional
from config import get_irc_config, BACKEND_HOST, BACKEND_PORT

# Configure logging - DEBUG level to log everything
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Log levels:
# DEBUG - Detailed information for diagnosing problems
# INFO - General informational messages
# WARNING - Warning messages for potentially harmful situations
# ERROR - Error messages for serious problems

# Initialize FastAPI app
app = FastAPI(
    title="GehChat Backend",
    description="Backend server for GehChat IRC client with IRC bridge",
    version="0.2.0"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# IRC Bridge manager
class IRCBridge:
    def __init__(self):
        self.irc_socket: Optional[socket.socket] = None
        self.websocket: Optional[WebSocket] = None
        # Load IRC config from config file
        irc_config = get_irc_config()
        self.server = irc_config.server
        self.port = irc_config.port
        self.channel = irc_config.channel
        self.nickname = None
        self.connected = False
        self.reader_task = None
        
    async def connect_to_irc(self, server: str, port: int, channel: str, nickname: str):
        """Connect to IRC server"""
        try:
            self.server = server
            self.port = port
            self.channel = channel
            self.nickname = nickname
            
            logger.info(f"Connecting to IRC: {server}:{port}")
            logger.debug(f"IRC connection params - Server: {server}, Port: {port}, Channel: {channel}, Nickname: {nickname}")
            
            # Create socket connection
            logger.debug("Creating IRC socket connection...")
            self.irc_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.irc_socket.settimeout(30)
            logger.debug(f"Connecting to {server}:{port}...")
            self.irc_socket.connect((server, port))
            self.irc_socket.setblocking(False)
            logger.debug("IRC socket connected and set to non-blocking mode")
            
            # Send IRC handshake
            logger.debug(f"Sending IRC handshake for nickname: {nickname}")
            self._send_irc(f"NICK {nickname}")
            self._send_irc(f"USER {nickname} 0 * :{nickname}")
            logger.debug("IRC handshake sent")
            
            self.connected = True
            
            # Start reading from IRC
            self.reader_task = asyncio.create_task(self._read_from_irc())
            
            await self._send_to_client({
                "type": "system",
                "content": f"Connected to IRC server {server}:{port}"
            })
            
            return True
            
        except Exception as e:
            logger.error(f"IRC connection error: {e}")
            logger.debug(f"IRC connection error details - Server: {server}, Port: {port}", exc_info=True)
            await self._send_to_client({
                "type": "error",
                "content": f"Failed to connect to IRC: {str(e)}"
            })
            return False
    
    def _send_irc(self, message: str):
        """Send message to IRC server"""
        if self.irc_socket:
            try:
                self.irc_socket.send(f"{message}\r\n".encode('utf-8'))
                logger.debug(f"IRC >>> {message}")
            except Exception as e:
                logger.error(f"Error sending to IRC: {e}")
    
    async def _read_from_irc(self):
        """Read messages from IRC server"""
        logger.debug("Starting IRC reader task")
        buffer = ""
        while self.connected and self.irc_socket:
            try:
                await asyncio.sleep(0.1)
                data = self.irc_socket.recv(4096)
                if not data:
                    break
                    
                buffer += data.decode('utf-8', errors='ignore')
                
                while '\r\n' in buffer:
                    line, buffer = buffer.split('\r\n', 1)
                    if line:
                        await self._process_irc_line(line)
                        
            except BlockingIOError:
                await asyncio.sleep(0.1)
            except Exception as e:
                logger.error(f"Error reading from IRC: {e}")
                logger.warning("IRC reader loop interrupted due to error")
                break
        
        logger.info("IRC reader task ended")
    
    async def _process_irc_line(self, line: str):
        """Process IRC protocol line"""
        logger.debug(f"IRC <<< {line}")
        
        # Handle PING
        if line.startswith('PING'):
            server = line.split(':', 1)[1] if ':' in line else ''
            self._send_irc(f"PONG :{server}")
            return
        
        parts = line.split(' ')
        if len(parts) < 2:
            return
        
        # Parse IRC message
        if parts[0].startswith(':'):
            prefix = parts[0][1:]
            command = parts[1]
            params = parts[2:]
        else:
            prefix = ''
            command = parts[0]
            params = parts[1:]
        
        # Handle different IRC commands
        if command == '376' or command == '422':  # End of MOTD
            self._send_irc(f"JOIN {self.channel}")
            await self._send_to_client({
                "type": "system",
                "content": f"Joining channel {self.channel}..."
            })
            
        elif command == '353':  # NAMES reply
            users = line.split(':', 2)[2].split() if line.count(':') >= 2 else []
            await self._send_to_client({
                "type": "users",
                "users": users
            })
            
        elif command == '366':  # End of NAMES
            await self._send_to_client({
                "type": "system",
                "content": f"Successfully joined {self.channel}!"
            })
            
        elif command == 'PRIVMSG':
            sender = prefix.split('!')[0] if '!' in prefix else prefix
            target = params[0] if params else ''
            message = line.split(':', 2)[2] if line.count(':') >= 2 else ''
            
            await self._send_to_client({
                "type": "message",
                "sender": sender,
                "target": target,
                "content": message,
                "is_private": target == self.nickname
            })
            
        elif command == 'JOIN':
            user = prefix.split('!')[0] if '!' in prefix else prefix
            await self._send_to_client({
                "type": "join",
                "user": user
            })
            
        elif command == 'PART':
            user = prefix.split('!')[0] if '!' in prefix else prefix
            await self._send_to_client({
                "type": "part",
                "user": user
            })
            
        elif command == 'QUIT':
            user = prefix.split('!')[0] if '!' in prefix else prefix
            await self._send_to_client({
                "type": "quit",
                "user": user
            })
    
    async def _send_to_client(self, data: dict):
        """Send data to WebSocket client"""
        logger.debug(f"Sending to client: {data.get('type', 'unknown')} message")
        if self.websocket:
            try:
                await self.websocket.send_json(data)
                logger.debug(f"Successfully sent {data.get('type')} to client")
            except Exception as e:
                logger.error(f"Error sending to client: {e}")
                logger.warning("Failed to send message to WebSocket client")
    
    async def handle_client_message(self, data: dict):
        """Handle message from WebSocket client"""
        logger.debug(f"Handling client message: {data}")
        msg_type = data.get('type')
        logger.debug(f"Message type: {msg_type}")
        
        if msg_type == 'connect':
            # IRC server configuration comes from config.py, NOT from client
            irc_config = get_irc_config()
            server = irc_config.server
            port = irc_config.port
            channel = irc_config.channel
            
            # Only nickname comes from client
            nickname = data.get('nickname', 'GehUser')
            
            logger.info(f"Client requested connection with nickname: {nickname}")
            logger.debug(f"Using IRC config - Server: {server}, Port: {port}, Channel: {channel}")
            
            await self.connect_to_irc(server, port, channel, nickname)
            
        elif msg_type == 'message':
            target = data.get('target', self.channel)
            content = data.get('content', '')
            logger.debug(f"Message request - Target: {target}, Content length: {len(content) if content else 0}")
            
            if self.connected:
                logger.debug(f"Sending PRIVMSG to {target}")
                self._send_irc(f"PRIVMSG {target} :{content}")
                # Echo back to client
                await self._send_to_client({
                    "type": "message",
                    "sender": self.nickname,
                    "target": target,
                    "content": content,
                    "is_private": target != self.channel
                })
            
        elif msg_type == 'disconnect':
            logger.info(f"Client {self.nickname} requested disconnect")
            await self.disconnect()
    
    async def disconnect(self):
        """Disconnect from IRC"""
        if self.irc_socket:
            try:
                self._send_irc("QUIT :Goodbye")
                self.irc_socket.close()
            except:
                pass
            
        self.connected = False
        self.irc_socket = None
        
        if self.reader_task:
            self.reader_task.cancel()
        
        await self._send_to_client({
            "type": "disconnected",
            "content": "Disconnected from IRC"
        })

# Store IRC bridges per connection
bridges: dict[WebSocket, IRCBridge] = {}


@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "status": "running",
        "message": "GehChat Backend Server - IRC Bridge",
        "version": "0.2.0",
        "active_connections": len(bridges)
    }


@app.get("/api/health")
async def health_check():
    """Detailed health check"""
    return {
        "status": "healthy",
        "active_connections": len(bridges),
        "irc_connections": sum(1 for b in bridges.values() if b.connected)
    }


@app.get("/api/irc-config")
async def get_irc_server_config():
    """Get IRC server configuration for clients"""
    irc_config = get_irc_config()
    return {
        "server": irc_config.server,
        "port": irc_config.port,
        "channel": irc_config.channel
    }


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for IRC bridge"""
    await websocket.accept()
    logger.debug(f"WebSocket connection accepted from {websocket.client}")
    
    # Create IRC bridge for this connection
    bridge = IRCBridge()
    bridge.websocket = websocket
    bridges[websocket] = bridge
    
    logger.info(f"New WebSocket connection. Total: {len(bridges)}")
    logger.debug(f"Created new IRC bridge for WebSocket connection")
    
    await websocket.send_json({
        "type": "connected",
        "content": "Connected to GehChat backend. Send 'connect' message to join IRC."
    })
    
    try:
        while True:
            data = await websocket.receive_text()
            message = json.loads(data)
            logger.info(f"Client message: {message}")
            
            await bridge.handle_client_message(message)
            
    except WebSocketDisconnect:
        logger.info("WebSocket disconnected")
        logger.warning("Client disconnected from WebSocket")
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
        logger.debug("WebSocket exception details", exc_info=True)
    finally:
        # Cleanup
        await bridge.disconnect()
        if websocket in bridges:
            del bridges[websocket]
        logger.info(f"Connection closed. Total: {len(bridges)}")


if __name__ == "__main__":
    irc_config = get_irc_config()
    logger.info("Starting GehChat Backend Server...")
    logger.info(f"IRC Server: {irc_config.server}:{irc_config.port}, Channel: {irc_config.channel}")
    logger.info(f"Backend listening on {BACKEND_HOST}:{BACKEND_PORT}")
    uvicorn.run(
        "main:app",
        host=BACKEND_HOST,
        port=BACKEND_PORT,
        reload=True,
        log_level="info"
    )
