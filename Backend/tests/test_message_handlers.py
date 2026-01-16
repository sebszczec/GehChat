"""
Tests for Message Handlers module
"""

import pytest
from unittest.mock import Mock, AsyncMock, patch, MagicMock
from fastapi.websockets import WebSocket

from message_handlers import (
    handlers,
    handle_connect,
    handle_message,
    handle_disconnect,
    handle_establish_session,
    handle_get_session_key,
    handle_encryption_session_ready,
    set_encryption_service,
)
from encryption_service import SignalProtocolService


@pytest.fixture
def encryption_service():
    """Create encryption service for tests"""
    service = SignalProtocolService()
    set_encryption_service(service)
    return service


@pytest.fixture
def mock_bridge(encryption_service):
    """Create mock IRC bridge"""
    from irc_bridge import IRCBridge

    bridge = IRCBridge(encryption_service)
    bridge.websocket = AsyncMock(spec=WebSocket)
    bridge.connected = True
    bridge.nickname = "TestUser"
    bridge.channel = "#vorest"
    bridge.is_frontend_user = True
    bridge.send_to_client = AsyncMock()
    bridge.send_irc_raw = Mock()
    bridge.connect_to_irc = AsyncMock()
    bridge.disconnect = AsyncMock()

    return bridge


class TestHandlerRegistry:
    """Tests for MessageHandlerRegistry"""

    @pytest.mark.asyncio
    async def test_dispatch_known_type(self, mock_bridge):
        """Test dispatching to known message type"""
        result = await handlers.dispatch(
            mock_bridge, {"type": "message", "content": "test", "target": "#vorest"}
        )

        assert result is True

    @pytest.mark.asyncio
    async def test_dispatch_unknown_type(self, mock_bridge):
        """Test dispatching to unknown message type returns False"""
        result = await handlers.dispatch(mock_bridge, {"type": "unknown_type"})

        assert result is False


class TestHandleConnect:
    """Tests for connect handler"""

    @pytest.mark.asyncio
    async def test_connect_calls_irc_connect(self, mock_bridge):
        """Test connect handler calls connect_to_irc"""
        data = {"type": "connect", "nickname": "NewUser"}

        await handle_connect(mock_bridge, data)

        mock_bridge.connect_to_irc.assert_called_once()
        call_args = mock_bridge.connect_to_irc.call_args[0]
        assert call_args[3] == "NewUser"  # nickname

    @pytest.mark.asyncio
    async def test_connect_uses_default_nickname(self, mock_bridge):
        """Test connect handler uses default nickname if not provided"""
        data = {"type": "connect"}

        await handle_connect(mock_bridge, data)

        call_args = mock_bridge.connect_to_irc.call_args[0]
        assert call_args[3] == "GehUser"  # default nickname


class TestHandleMessage:
    """Tests for message handler"""

    @pytest.mark.asyncio
    async def test_message_to_channel(self, mock_bridge):
        """Test sending message to channel"""
        data = {"type": "message", "target": "#vorest", "content": "Hello!"}

        await handle_message(mock_bridge, data)

        mock_bridge.send_irc_raw.assert_called_once_with("PRIVMSG #vorest :Hello!")

    @pytest.mark.asyncio
    async def test_message_strips_at_prefix(self, mock_bridge):
        """Test message handler strips @ prefix from target"""
        data = {"type": "message", "target": "@user", "content": "Hi!"}

        await handle_message(mock_bridge, data)

        mock_bridge.send_irc_raw.assert_called_once_with("PRIVMSG user :Hi!")

    @pytest.mark.asyncio
    async def test_message_not_connected(self, mock_bridge):
        """Test message handler does nothing when not connected"""
        mock_bridge.connected = False
        data = {"type": "message", "target": "#vorest", "content": "Hello!"}

        await handle_message(mock_bridge, data)

        mock_bridge.send_irc_raw.assert_not_called()


class TestHandleDisconnect:
    """Tests for disconnect handler"""

    @pytest.mark.asyncio
    async def test_disconnect_calls_cleanup(self, mock_bridge, encryption_service):
        """Test disconnect handler calls bridge.disconnect"""
        data = {"type": "disconnect"}

        await handle_disconnect(mock_bridge, data)

        mock_bridge.disconnect.assert_called_once()


class TestHandleEstablishSession:
    """Tests for establish_session handler"""

    @pytest.mark.asyncio
    async def test_establish_session(self, mock_bridge, encryption_service):
        """Test establish session creates encryption session"""
        data = {"type": "establish_session", "other_user": "OtherUser"}

        await handle_establish_session(mock_bridge, data)

        mock_bridge.send_to_client.assert_called()
        call_args = mock_bridge.send_to_client.call_args[0][0]
        assert call_args["type"] == "session_established"


class TestHandleGetSessionKey:
    """Tests for get_session_key handler"""

    @pytest.mark.asyncio
    async def test_get_session_key(self, mock_bridge, encryption_service):
        """Test get session key returns key"""
        # First establish a session
        encryption_service.establish_session("FromUser", "TestUser")

        data = {"type": "get_session_key", "from": "FromUser"}

        await handle_get_session_key(mock_bridge, data)

        mock_bridge.send_to_client.assert_called()
        call_args = mock_bridge.send_to_client.call_args[0][0]
        assert call_args["type"] == "session_key"
        assert "key" in call_args


class TestHandleEncryptionSessionReady:
    """Tests for encryption_session_ready handler"""

    @pytest.mark.asyncio
    async def test_session_ready_sends_key(self, mock_bridge, encryption_service):
        """Test session ready handler sends session key"""
        data = {"type": "encryption_session_ready", "with": "OtherUser"}

        await handle_encryption_session_ready(mock_bridge, data)

        mock_bridge.send_to_client.assert_called()
        call_args = mock_bridge.send_to_client.call_args[0][0]
        assert call_args["type"] == "session_key"
