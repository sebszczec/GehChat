"""
GehChat Backend Server
Main application entry point - FastAPI endpoints and WebSocket handler
"""

import json
import logging
import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware

from config import get_irc_config, BACKEND_HOST, BACKEND_PORT
from encryption_service import SignalProtocolService
from irc_bridge import IRCBridge

# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="GehChat Backend",
    description="Backend server for GehChat IRC client with IRC bridge and Signal Protocol Encryption",
    version="0.3.0",
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global services
encryption_service = SignalProtocolService()

# Store IRC bridges per WebSocket connection
bridges: dict[WebSocket, IRCBridge] = {}


# ============================================================================
# REST API Endpoints
# ============================================================================

@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "status": "running",
        "message": "GehChat Backend Server - IRC Bridge",
        "version": "0.2.0",
        "active_connections": len(bridges),
    }


@app.get("/api/health")
async def health_check():
    """Detailed health check"""
    return {
        "status": "healthy",
        "active_connections": len(bridges),
        "irc_connections": sum(1 for b in bridges.values() if b.connected),
    }


@app.get("/api/irc-config")
async def get_irc_server_config():
    """Get IRC server configuration for clients"""
    irc_config = get_irc_config()
    return {
        "server": irc_config.server,
        "port": irc_config.port,
        "channel": irc_config.channel,
    }


@app.get("/api/is-frontend-user/{nickname}")
async def check_is_frontend_user(nickname: str):
    """Check if a user is a Frontend user with active encryption sessions"""
    is_frontend = encryption_service.is_frontend_user(nickname)
    logger.debug(f"Frontend user check for {nickname}: {is_frontend}")
    return {
        "nickname": nickname,
        "is_frontend_user": is_frontend,
    }


# ============================================================================
# WebSocket Endpoint
# ============================================================================

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for IRC bridge"""
    logger.info(f"WebSocket connection attempt from {websocket.client}")
    logger.debug(
        f"WebSocket details - Client IP: {websocket.client[0]}, Port: {websocket.client[1]}"
    )

    await websocket.accept()
    logger.debug(f"WebSocket connection accepted from {websocket.client}")
    logger.info(f"WebSocket ACCEPTED from {websocket.client[0]}")

    # Create IRC bridge for this connection
    bridge = IRCBridge(encryption_service)
    bridge.websocket = websocket
    bridges[websocket] = bridge

    logger.info(f"New WebSocket connection. Total: {len(bridges)}")
    logger.debug("Created new IRC bridge for WebSocket connection")

    await websocket.send_json({
        "type": "connected",
        "content": "Connected to GehChat backend. Send 'connect' message to join IRC.",
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


# ============================================================================
# Application Entry Point
# ============================================================================

if __name__ == "__main__":
    irc_config = get_irc_config()
    logger.info("Starting GehChat Backend Server...")
    logger.info(
        f"IRC Server: {irc_config.server}:{irc_config.port}, Channel: {irc_config.channel}"
    )
    logger.info(f"Backend listening on {BACKEND_HOST}:{BACKEND_PORT}")
    uvicorn.run(
        "main:app",
        host=BACKEND_HOST,
        port=BACKEND_PORT,
        reload=True,
        log_level="info",
    )
