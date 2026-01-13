"""
Tests for main.py IRC Bridge functionality
"""

import pytest
import asyncio
from fastapi.testclient import TestClient
from fastapi.websockets import WebSocket
from unittest.mock import Mock, AsyncMock, patch, MagicMock
import json
from main import app, IRCBridge, bridges


@pytest.fixture
def client():
    """Create test client for FastAPI app"""
    return TestClient(app)


class TestHealthEndpoints:
    """Test health check endpoints"""

    def test_root_endpoint(self, client):
        """Test root endpoint returns status"""
        response = client.get("/")

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "running"
        assert "version" in data
        assert "active_connections" in data

    def test_health_check_endpoint(self, client):
        """Test health check endpoint"""
        response = client.get("/api/health")

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert "active_connections" in data
        assert "irc_connections" in data

    def test_irc_config_endpoint(self, client):
        """Test IRC config endpoint returns server settings"""
        response = client.get("/api/irc-config")

        assert response.status_code == 200
        data = response.json()
        assert "server" in data
        assert "port" in data
        assert "channel" in data
        assert data["server"] == "slaugh.pl"
        assert data["port"] == 6667
        assert data["channel"] == "#vorest"


class TestIRCBridge:
    """Test IRCBridge class functionality"""

    def test_irc_bridge_initialization(self):
        """Test IRCBridge initializes with correct defaults"""
        bridge = IRCBridge()

        assert bridge.irc_socket is None
        assert bridge.websocket is None
        assert bridge.server == "slaugh.pl"
        assert bridge.port == 6667
        assert bridge.channel == "#vorest"
        assert bridge.nickname is None
        assert bridge.connected is False

    @pytest.mark.asyncio
    async def test_send_to_client_success(self):
        """Test sending message to WebSocket client"""
        bridge = IRCBridge()
        mock_websocket = Mock(spec=WebSocket)
        mock_websocket.send_json = AsyncMock(return_value=None)
        bridge.websocket = mock_websocket

        test_data = {"type": "system", "content": "Test message"}
        await bridge._send_to_client(test_data)

        mock_websocket.send_json.assert_called_once_with(test_data)

    @pytest.mark.asyncio
    async def test_send_to_client_no_websocket(self):
        """Test sending message when no WebSocket is connected"""
        bridge = IRCBridge()

        # Should not raise exception even without websocket
        test_data = {"type": "system", "content": "Test message"}
        await bridge._send_to_client(test_data)

    @pytest.mark.asyncio
    async def test_handle_connect_message(self):
        """Test handling connect message from client"""
        bridge = IRCBridge()
        bridge.websocket = AsyncMock(spec=WebSocket)

        with patch.object(
            bridge, "connect_to_irc", new_callable=AsyncMock
        ) as mock_connect:
            connect_data = {"type": "connect", "nickname": "TestUser123"}

            await bridge.handle_client_message(connect_data)

            mock_connect.assert_called_once()
            call_args = mock_connect.call_args[0]
            assert call_args[0] == "slaugh.pl"  # server
            assert call_args[1] == 6667  # port
            assert call_args[2] == "#vorest"  # channel
            assert call_args[3] == "TestUser123"  # nickname

    @pytest.mark.asyncio
    async def test_handle_message_when_connected(self):
        """Test handling message when connected to IRC"""
        bridge = IRCBridge()
        bridge.connected = True
        bridge.nickname = "TestUser"
        bridge.channel = "#vorest"
        bridge.websocket = AsyncMock(spec=WebSocket)
        bridge.irc_socket = MagicMock()

        with patch.object(bridge, "_send_irc") as mock_send_irc:
            message_data = {
                "type": "message",
                "target": "#vorest",
                "content": "Hello, World!",
            }

            await bridge.handle_client_message(message_data)

            mock_send_irc.assert_called_once_with("PRIVMSG #vorest :Hello, World!")

    @pytest.mark.asyncio
    async def test_handle_private_message_strips_at_prefix(self):
        """Test handling private message strips @ prefix from target"""
        bridge = IRCBridge()
        bridge.connected = True
        bridge.nickname = "TestUser"
        bridge.channel = "#vorest"
        bridge.websocket = AsyncMock(spec=WebSocket)
        bridge.irc_socket = MagicMock()

        with patch.object(bridge, "_send_irc") as mock_send_irc:
            message_data = {
                "type": "message",
                "target": "@slaughOP",  # Target with @ prefix
                "content": "Hello slaughOP!",
            }

            await bridge.handle_client_message(message_data)

            # Should send without @ prefix
            mock_send_irc.assert_called_once_with("PRIVMSG slaughOP :Hello slaughOP!")

    @pytest.mark.asyncio
    async def test_handle_disconnect_message(self):
        """Test handling disconnect message from client"""
        bridge = IRCBridge()
        bridge.websocket = AsyncMock(spec=WebSocket)

        with patch.object(
            bridge, "disconnect", new_callable=AsyncMock
        ) as mock_disconnect:
            disconnect_data = {"type": "disconnect"}

            await bridge.handle_client_message(disconnect_data)

            mock_disconnect.assert_called_once()

    @pytest.mark.asyncio
    async def test_disconnect_cleanup(self):
        """Test disconnect cleans up resources properly"""
        bridge = IRCBridge()
        bridge.connected = True
        bridge.irc_socket = MagicMock()
        bridge.reader_task = MagicMock()
        bridge.reader_task.cancel = MagicMock()
        bridge.websocket = AsyncMock(spec=WebSocket)

        await bridge.disconnect()

        assert bridge.connected is False
        assert bridge.irc_socket is None
        bridge.reader_task.cancel.assert_called_once()

    def test_send_irc_message(self):
        """Test sending message to IRC server"""
        bridge = IRCBridge()
        mock_socket = MagicMock()
        bridge.irc_socket = mock_socket

        bridge._send_irc("NICK TestUser")

        mock_socket.send.assert_called_once()
        sent_data = mock_socket.send.call_args[0][0]
        assert b"NICK TestUser\r\n" == sent_data

    @pytest.mark.asyncio
    async def test_process_irc_ping(self):
        """Test processing IRC PING command"""
        bridge = IRCBridge()
        bridge.irc_socket = MagicMock()

        with patch.object(bridge, "_send_irc") as mock_send:
            await bridge._process_irc_line("PING :server.name")

            mock_send.assert_called_once_with("PONG :server.name")

    @pytest.mark.asyncio
    async def test_process_irc_privmsg(self):
        """Test processing IRC PRIVMSG"""
        bridge = IRCBridge()
        bridge.nickname = "MyNick"
        mock_websocket = Mock(spec=WebSocket)
        mock_websocket.send_json = AsyncMock(return_value=None)
        bridge.websocket = mock_websocket

        irc_line = ":sender!user@host PRIVMSG #channel :Hello everyone"
        await bridge._process_irc_line(irc_line)

        # Verify message was sent to client
        mock_websocket.send_json.assert_called_once()
        call_args = mock_websocket.send_json.call_args[0][0]
        assert call_args["type"] == "message"
        assert call_args["sender"] == "sender"
        assert call_args["content"] == "Hello everyone"


class TestWebSocketEndpoint:
    """Test WebSocket connection handling"""

    def test_websocket_connection(self, client):
        """Test WebSocket connection establishment"""
        with client.websocket_connect("/ws") as websocket:
            # Receive connection confirmation
            data = websocket.receive_json()
            assert data["type"] == "connected"
            assert "Connected to GehChat backend" in data["content"]

    def test_websocket_connect_command(self, client):
        """Test sending connect command via WebSocket"""
        with client.websocket_connect("/ws") as websocket:
            # Receive initial connection message
            websocket.receive_json()

            # Send connect command
            with patch("main.IRCBridge.connect_to_irc", new_callable=AsyncMock):
                websocket.send_json({"type": "connect", "nickname": "TestUser"})

                # Allow processing
                import time

                time.sleep(0.1)

    def test_websocket_disconnect_cleanup(self, client):
        """Test that websocket disconnect cleans up bridge"""
        initial_bridge_count = len(bridges)
        with client.websocket_connect("/ws") as websocket:
            # Verify bridge was added
            websocket.receive_json()

        # After context exit, bridge should be cleaned up
        # Note: In actual tests this might need async handling
        assert len(bridges) == initial_bridge_count


@pytest.mark.asyncio
class TestAsyncFunctionality:
    """Test async functionality"""

    @pytest.mark.asyncio
    async def test_parse_irc_names_strips_prefixes(self):
        """Test parsing NAMES reply strips @ and + prefixes from usernames"""
        bridge = IRCBridge()
        bridge.connected = True
        bridge.nickname = "TestUser"
        bridge.channel = "#vorest"
        bridge.websocket = AsyncMock(spec=WebSocket)
        bridge.irc_socket = MagicMock()

        with patch.object(
            bridge, "_send_to_client", new_callable=AsyncMock
        ) as mock_send:
            # Simulate IRC NAMES reply with @ (operator) and + (voiced) prefixes
            # Format: :server 353 nick = #channel :@user1 +user2 user3
            irc_line = ":irc.example.com 353 TestUser = #vorest :@slaughOP +voiced_user regular_user"

            # Parse this by calling the IRC message processing directly
            await bridge._process_irc_line(irc_line)

            # Check that prefixes were stripped when sending to client
            # Find the users message in the mock calls
            users_message_found = False
            for call in mock_send.call_args_list:
                message_data = call[0][0]
                if message_data.get("type") == "users":
                    users = message_data.get("users", [])
                    # Verify no @ or + prefixes remain
                    assert all(
                        not user.startswith("@") and not user.startswith("+")
                        for user in users
                    )
                    assert (
                        "slaughOP" in users
                    )  # Check that slaughOP is present (without @)
                    assert (
                        "voiced_user" in users
                    )  # Check that voiced_user is present (without +)
                    assert "regular_user" in users
                    users_message_found = True

            assert (
                users_message_found
            ), "Expected to find 'users' message type in mock calls"

    async def test_concurrent_websocket_handling(self):
        """Test handling multiple WebSocket connections"""
        bridge1 = IRCBridge()
        bridge2 = IRCBridge()

        mock_ws1 = Mock(spec=WebSocket)
        mock_ws1.send_json = AsyncMock(return_value=None)
        mock_ws2 = Mock(spec=WebSocket)
        mock_ws2.send_json = AsyncMock(return_value=None)

        bridge1.websocket = mock_ws1
        bridge2.websocket = mock_ws2

        # Send messages to both bridges concurrently
        await asyncio.gather(
            bridge1._send_to_client({"type": "test1"}),
            bridge2._send_to_client({"type": "test2"}),
        )

        mock_ws1.send_json.assert_called_once()
        mock_ws2.send_json.assert_called_once()
