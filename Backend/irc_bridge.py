"""
IRC Bridge for GehChat
Manages connection between WebSocket clients and IRC server
"""

import asyncio
import socket
import logging
from typing import Optional, TYPE_CHECKING
from fastapi import WebSocket

from config import get_irc_config
from irc_parser import (
    parse_irc_line,
    parse_privmsg,
    parse_names_list,
    extract_sender_from_prefix,
    extract_ping_server,
    is_end_of_motd,
    is_names_reply,
    is_end_of_names,
)

if TYPE_CHECKING:
    from encryption_service import SignalProtocolService

logger = logging.getLogger(__name__)


class IRCBridge:
    """
    Manages bidirectional communication between a WebSocket client and IRC server.
    Each WebSocket connection gets its own IRCBridge instance.
    """

    def __init__(self, encryption_service: "SignalProtocolService"):
        """
        Initialize IRC Bridge

        Args:
            encryption_service: Shared encryption service for all bridges
        """
        self.encryption_service = encryption_service
        self.irc_socket: Optional[socket.socket] = None
        self.websocket: Optional[WebSocket] = None

        # Load IRC config
        irc_config = get_irc_config()
        self.server = irc_config.server
        self.port = irc_config.port
        self.channel = irc_config.channel

        self.nickname: Optional[str] = None
        self.device_id: Optional[str] = None
        self.connected = False
        self.reader_task: Optional[asyncio.Task] = None
        self.is_frontend_user = False

    async def connect_to_irc(
        self,
        server: str,
        port: int,
        channel: str,
        nickname: str,
        is_frontend_user: bool = True,
    ) -> bool:
        """
        Connect to IRC server

        Args:
            server: IRC server hostname
            port: IRC server port
            channel: Channel to join
            nickname: User's nickname
            is_frontend_user: Whether user is connecting from Frontend app

        Returns:
            True if connection successful, False otherwise
        """
        try:
            self._update_connection_params(
                server, port, channel, nickname, is_frontend_user
            )

            logger.info(f"Connecting to IRC: {server}:{port}")
            logger.debug(
                f"IRC connection params - Server: {server}, Port: {port}, "
                f"Channel: {channel}, Nickname: {nickname}, Frontend User: {is_frontend_user}"
            )

            # Register Frontend user for encryption
            if is_frontend_user:
                await self._setup_encryption_for_user(nickname)

            # Create and configure socket
            await self._create_irc_socket(server, port)

            # Send IRC handshake
            self._send_irc_handshake(nickname)

            self.connected = True

            # Start reading from IRC
            self.reader_task = asyncio.create_task(self._read_from_irc())

            await self.send_to_client(
                {
                    "type": "system",
                    "content": f"Connected to IRC server {server}:{port}",
                }
            )

            return True

        except Exception as e:
            logger.error(f"IRC connection error: {e}")
            logger.debug(
                f"IRC connection error details - Server: {server}, Port: {port}",
                exc_info=True,
            )
            await self.send_to_client(
                {"type": "error", "content": f"Failed to connect to IRC: {str(e)}"}
            )
            return False

    def _update_connection_params(
        self,
        server: str,
        port: int,
        channel: str,
        nickname: str,
        is_frontend_user: bool,
    ) -> None:
        """Update connection parameters"""
        self.server = server
        self.port = port
        self.channel = channel
        self.nickname = nickname
        self.is_frontend_user = is_frontend_user

    async def _setup_encryption_for_user(self, nickname: str) -> None:
        """Setup encryption for a Frontend user"""
        self.device_id = self.encryption_service.register_user(nickname)
        logger.info(
            f"Registered Frontend user {nickname} with device_id {self.device_id}"
        )

        # Get list of other Frontend users to establish encryption with
        other_frontend_users = self.encryption_service.get_unencrypted_frontend_users(
            nickname
        )

        if other_frontend_users:
            await self.send_to_client(
                {
                    "type": "setup_encryption",
                    "users": other_frontend_users,
                }
            )
            logger.info(
                f"Instructed {nickname} to setup encryption with {other_frontend_users}"
            )

            # Mark these sessions as pending
            for other_user in other_frontend_users:
                self.encryption_service.add_pending_session(nickname, other_user)
                self.encryption_service.add_pending_session(other_user, nickname)

    async def _create_irc_socket(self, server: str, port: int) -> None:
        """Create and connect IRC socket"""
        logger.debug("Creating IRC socket connection...")
        self.irc_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.irc_socket.settimeout(30)

        logger.debug(f"Connecting to {server}:{port}...")
        self.irc_socket.connect((server, port))
        self.irc_socket.setblocking(False)

        logger.debug("IRC socket connected and set to non-blocking mode")

    def _send_irc_handshake(self, nickname: str) -> None:
        """Send IRC handshake (NICK and USER commands)"""
        logger.debug(f"Sending IRC handshake for nickname: {nickname}")
        self.send_irc_raw(f"NICK {nickname}")
        self.send_irc_raw(f"USER {nickname} 0 * :{nickname}")
        logger.debug("IRC handshake sent")

    def send_irc_raw(self, message: str) -> None:
        """
        Send raw message to IRC server

        Args:
            message: IRC protocol message (without CRLF)
        """
        if self.irc_socket:
            try:
                self.irc_socket.send(f"{message}\r\n".encode("utf-8"))
                logger.debug(f"IRC >>> {message}")
            except Exception as e:
                logger.error(f"Error sending to IRC: {e}")

    async def _read_from_irc(self) -> None:
        """Read messages from IRC server (background task)"""
        logger.debug("Starting IRC reader task")
        buffer = ""

        while self.connected and self.irc_socket:
            try:
                await asyncio.sleep(0.1)
                data = self.irc_socket.recv(4096)

                if not data:
                    break

                buffer += data.decode("utf-8", errors="ignore")

                while "\r\n" in buffer:
                    line, buffer = buffer.split("\r\n", 1)
                    if line:
                        await self._process_irc_line(line)

            except BlockingIOError:
                await asyncio.sleep(0.1)
            except Exception as e:
                logger.error(f"Error reading from IRC: {e}")
                logger.warning("IRC reader loop interrupted due to error")
                break

        logger.info("IRC reader task ended")

    async def _process_irc_line(self, line: str) -> None:
        """
        Process a single IRC protocol line

        Args:
            line: Raw IRC protocol line
        """
        logger.debug(f"IRC <<< {line}")

        # Handle PING
        if line.startswith("PING"):
            server = extract_ping_server(line)
            self.send_irc_raw(f"PONG :{server}")
            return

        parsed = parse_irc_line(line)
        if not parsed:
            return

        # Route to specific handler based on command
        await self._handle_irc_command(
            parsed.prefix, parsed.command, parsed.params, line
        )

    async def _handle_irc_command(
        self,
        prefix: str,
        command: str,
        params: list,
        raw_line: str,
    ) -> None:
        """
        Handle specific IRC command

        Args:
            prefix: IRC message prefix
            command: IRC command or numeric
            params: Command parameters
            raw_line: Original raw line
        """
        # End of MOTD - join channel
        if is_end_of_motd(command):
            self.send_irc_raw(f"JOIN {self.channel}")
            await self.send_to_client(
                {
                    "type": "system",
                    "content": f"Joining channel {self.channel}...",
                }
            )

        # NAMES reply
        elif is_names_reply(command):
            users = parse_names_list(raw_line)
            await self.send_to_client({"type": "users", "users": users})

        # End of NAMES
        elif is_end_of_names(command):
            await self.send_to_client(
                {
                    "type": "system",
                    "content": f"Successfully joined {self.channel}!",
                }
            )

        # Private message
        elif command == "PRIVMSG":
            privmsg = parse_privmsg(prefix, params, raw_line)
            await self.send_to_client(
                {
                    "type": "message",
                    "sender": privmsg.sender,
                    "target": privmsg.target,
                    "content": privmsg.content,
                    "is_private": privmsg.target == self.nickname,
                    "is_encrypted": privmsg.is_encrypted,
                    "encrypted_data": privmsg.encrypted_data,
                }
            )

        # User joined
        elif command == "JOIN":
            user = extract_sender_from_prefix(prefix)
            await self.send_to_client({"type": "join", "user": user})

        # User left
        elif command == "PART":
            user = extract_sender_from_prefix(prefix)
            await self.send_to_client({"type": "part", "user": user})

        # User quit
        elif command == "QUIT":
            user = extract_sender_from_prefix(prefix)
            await self.send_to_client({"type": "quit", "user": user})

    async def send_to_client(self, data: dict) -> None:
        """
        Send data to WebSocket client

        Args:
            data: Dictionary to send as JSON
        """
        logger.debug(f"Sending to client: {data.get('type', 'unknown')} message")

        if self.websocket:
            try:
                await self.websocket.send_json(data)
                logger.debug(f"Successfully sent {data.get('type')} to client")
            except Exception as e:
                logger.error(f"Error sending to client: {e}")
                logger.warning("Failed to send message to WebSocket client")

    async def handle_client_message(self, data: dict) -> None:
        """
        Handle message from WebSocket client

        Args:
            data: Parsed JSON message from client
        """
        from message_handlers import handlers, set_encryption_service

        logger.debug(f"Handling client message: {data}")
        msg_type = data.get("type")
        logger.debug(f"Message type: {msg_type}")

        # Inject encryption service
        set_encryption_service(self.encryption_service)

        # Dispatch to appropriate handler
        handled = await handlers.dispatch(self, data)

        if not handled:
            logger.warning(f"Unhandled message type: {msg_type}")

    async def disconnect(self) -> None:
        """Disconnect from IRC server and cleanup"""
        if self.irc_socket:
            try:
                self.send_irc_raw("QUIT :Goodbye")
                self.irc_socket.close()
            except:
                pass

        self.connected = False
        self.irc_socket = None

        if self.reader_task:
            self.reader_task.cancel()

        await self.send_to_client(
            {
                "type": "disconnected",
                "content": "Disconnected from IRC",
            }
        )
