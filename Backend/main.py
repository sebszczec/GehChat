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

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

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
        self.server = "slaugh.pl"
        self.port = 6667
        self.channel = "#vorest"
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
            
            # Create socket connection
            self.irc_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.irc_socket.settimeout(30)
            self.irc_socket.connect((server, port))
            self.irc_socket.setblocking(False)
            
            # Send IRC handshake
            self._send_irc(f"NICK {nickname}")
            self._send_irc(f"USER {nickname} 0 * :{nickname}")
            
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
        if self.websocket:
            try:
                await self.websocket.send_json(data)
            except Exception as e:
                logger.error(f"Error sending to client: {e}")
    
    async def handle_client_message(self, data: dict):
        """Handle message from WebSocket client"""
        msg_type = data.get('type')
        
        if msg_type == 'connect':
            server = data.get('server', 'slaugh.pl')
            port = int(data.get('port', 6667))
            channel = data.get('channel', '#vorest')
            nickname = data.get('nickname', 'GehUser')
            
            await self.connect_to_irc(server, port, channel, nickname)
            
        elif msg_type == 'message':
            target = data.get('target', self.channel)
            content = data.get('content', '')
            
            if self.connected:
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


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for IRC bridge"""
    await websocket.accept()
    
    # Create IRC bridge for this connection
    bridge = IRCBridge()
    bridge.websocket = websocket
    bridges[websocket] = bridge
    
    logger.info(f"New WebSocket connection. Total: {len(bridges)}")
    
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
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
    finally:
        # Cleanup
        await bridge.disconnect()
        if websocket in bridges:
            del bridges[websocket]
        logger.info(f"Connection closed. Total: {len(bridges)}")


if __name__ == "__main__":
    logger.info("Starting GehChat Backend Server...")
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )
