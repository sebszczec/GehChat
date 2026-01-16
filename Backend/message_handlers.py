"""
WebSocket Message Handlers for GehChat
Handles different types of client messages (connect, message, session, etc.)
"""

import base64
import json
import logging
from typing import TYPE_CHECKING, Dict, Any, Callable, Awaitable

from config import get_irc_config

if TYPE_CHECKING:
    from irc_bridge import IRCBridge

logger = logging.getLogger(__name__)


class MessageHandlerRegistry:
    """Registry for message type handlers"""

    def __init__(self):
        self._handlers: Dict[
            str, Callable[["IRCBridge", Dict[str, Any]], Awaitable[None]]
        ] = {}

    def register(self, msg_type: str):
        """Decorator to register a handler for a message type"""

        def decorator(func: Callable[["IRCBridge", Dict[str, Any]], Awaitable[None]]):
            self._handlers[msg_type] = func
            return func

        return decorator

    async def dispatch(self, bridge: "IRCBridge", data: Dict[str, Any]) -> bool:
        """
        Dispatch message to appropriate handler

        Returns:
            True if handler was found and executed, False otherwise
        """
        msg_type = data.get("type")
        if msg_type is None:
            logger.warning("Message has no type field")
            return False

        handler = self._handlers.get(msg_type)

        if handler:
            await handler(bridge, data)
            return True

        logger.warning(f"Unknown message type: {msg_type}")
        return False


# Global handler registry
handlers = MessageHandlerRegistry()


@handlers.register("connect")
async def handle_connect(bridge: "IRCBridge", data: Dict[str, Any]) -> None:
    """Handle client connection request to IRC"""
    # IRC server configuration comes from config.py, NOT from client
    irc_config = get_irc_config()
    server = irc_config.server
    port = irc_config.port
    channel = irc_config.channel

    # Only nickname comes from client
    nickname = data.get("nickname", "GehUser")
    is_frontend_user = data.get("is_frontend_user", True)

    logger.info(f"Client requested connection with nickname: {nickname}")
    logger.debug(
        f"Using IRC config - Server: {server}, Port: {port}, Channel: {channel}"
    )

    await bridge.connect_to_irc(server, port, channel, nickname, is_frontend_user)


@handlers.register("message")
async def handle_message(bridge: "IRCBridge", data: Dict[str, Any]) -> None:
    """Handle message send request from client"""
    target = data.get("target", bridge.channel)
    # Remove @ prefix if present (IRC doesn't accept @ in nicknames)
    if target.startswith("@"):
        target = target[1:]

    content = data.get("content", "")
    is_encrypted = data.get("is_encrypted", False)
    encrypted_data = data.get("encrypted_data", None)

    logger.debug(
        f"Message request - Target: {target}, Content length: {len(content) if content else 0}, "
        f"Encrypted: {is_encrypted}"
    )

    if not bridge.connected:
        logger.warning("Attempted to send message while not connected")
        return

    # Determine if this is a private message
    is_private = target != bridge.channel

    # If message is already encrypted and target is Frontend user, relay encrypted
    if is_encrypted and encrypted_data and is_private:
        logger.debug(f"Relaying encrypted message from {bridge.nickname} to {target}")
        bridge.send_irc_raw(f"PRIVMSG {target} :{json.dumps(encrypted_data)}")
    else:
        # Plain message - either public chat or IRC user
        logger.debug(f"Sending plain PRIVMSG to {target}")
        bridge.send_irc_raw(f"PRIVMSG {target} :{content}")

    # Echo back to client
    await bridge.send_to_client(
        {
            "type": "message",
            "sender": bridge.nickname,
            "target": target,
            "content": content,
            "is_private": is_private,
            "is_encrypted": is_encrypted,
        }
    )


@handlers.register("establish_session")
async def handle_establish_session(bridge: "IRCBridge", data: Dict[str, Any]) -> None:
    """Handle encryption session establishment request"""
    other_user = data.get("other_user")

    if not (bridge.nickname and other_user and bridge.is_frontend_user):
        logger.warning(
            "Cannot establish session: missing nickname or not frontend user"
        )
        return

    from encryption_service import SignalProtocolService

    encryption_service = _get_encryption_service()

    encryption_service.establish_session(bridge.nickname, other_user)
    logger.info(f"Session established between {bridge.nickname} and {other_user}")

    await bridge.send_to_client(
        {
            "type": "session_established",
            "content": f"Encrypted session established with {other_user}",
        }
    )


@handlers.register("get_session_key")
async def handle_get_session_key(bridge: "IRCBridge", data: Dict[str, Any]) -> None:
    """Handle session key request from client"""
    from_user = data.get("from")

    if not (bridge.nickname and from_user and bridge.is_frontend_user):
        logger.warning("Cannot get session key: missing data or not frontend user")
        return

    encryption_service = _get_encryption_service()

    # Establish session if it doesn't exist yet
    encryption_service.establish_session(from_user, bridge.nickname)

    # Get the session key (sorted naming to match Frontend)
    users = sorted([from_user, bridge.nickname])
    session_key_name = f"{users[0]}_{users[1]}"

    session_key_bytes = encryption_service.session_keys.get(session_key_name)

    if session_key_bytes:
        session_key_b64 = base64.b64encode(session_key_bytes).decode("utf-8")
        logger.debug(f"Sending session key from {from_user} to {bridge.nickname}")

        await bridge.send_to_client(
            {
                "type": "session_key",
                "from": from_user,
                "key": session_key_b64,
            }
        )


@handlers.register("encryption_session_ready")
async def handle_encryption_session_ready(
    bridge: "IRCBridge", data: Dict[str, Any]
) -> None:
    """Handle client confirmation of encryption session establishment"""
    other_user = data.get("with")

    if not (bridge.nickname and other_user and bridge.is_frontend_user):
        logger.warning("Cannot confirm session: missing data or not frontend user")
        return

    logger.info(
        f"Client {bridge.nickname} confirmed encryption session with {other_user}"
    )

    encryption_service = _get_encryption_service()

    # Establish session on Backend side if not already done
    encryption_service.establish_session(bridge.nickname, other_user)

    # Send session key to this client
    users = sorted([bridge.nickname, other_user])
    session_key_name = f"{users[0]}_{users[1]}"

    session_key_bytes = encryption_service.session_keys.get(session_key_name)

    if session_key_bytes:
        session_key_b64 = base64.b64encode(session_key_bytes).decode("utf-8")

        await bridge.send_to_client(
            {
                "type": "session_key",
                "from": other_user,
                "key": session_key_b64,
            }
        )
        logger.debug(f"Sent session key to {bridge.nickname} for {other_user}")

        # Mark session as confirmed
        encryption_service.mark_session_confirmed(bridge.nickname, other_user)


@handlers.register("disconnect")
async def handle_disconnect(bridge: "IRCBridge", data: Dict[str, Any]) -> None:
    """Handle client disconnect request"""
    logger.info(f"Client {bridge.nickname} requested disconnect")

    # Clean up encryption sessions
    if bridge.nickname and bridge.is_frontend_user:
        encryption_service = _get_encryption_service()
        encryption_service.cleanup_session(bridge.nickname)

    await bridge.disconnect()


# Helper to get encryption service (avoids circular imports)
_encryption_service_instance = None


def _get_encryption_service():
    """Get the global encryption service instance"""
    global _encryption_service_instance
    if _encryption_service_instance is None:
        from encryption_service import SignalProtocolService

        _encryption_service_instance = SignalProtocolService()
    return _encryption_service_instance


def set_encryption_service(service):
    """Set the global encryption service instance (for dependency injection)"""
    global _encryption_service_instance
    _encryption_service_instance = service
