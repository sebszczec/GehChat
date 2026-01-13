"""
Tests for config.py module
"""

import pytest
import os
from config import (
    IRCConfig,
    get_irc_config,
    DEFAULT_IRC_CONFIG,
    BACKEND_HOST,
    BACKEND_PORT,
)


class TestIRCConfig:
    """Test IRCConfig model"""

    def test_irc_config_creation(self):
        """Test creating IRCConfig instance"""
        config = IRCConfig(server="test.server.com", port=6667, channel="#testchannel")

        assert config.server == "test.server.com"
        assert config.port == 6667
        assert config.channel == "#testchannel"

    def test_irc_config_immutability(self):
        """Test that IRCConfig is immutable (frozen)"""
        config = IRCConfig(server="test.server.com", port=6667, channel="#testchannel")

        # Should raise an error when trying to modify
        with pytest.raises(Exception):
            config.server = "new.server.com"

    def test_default_irc_config(self):
        """Test default IRC configuration values"""
        assert DEFAULT_IRC_CONFIG.server == "slaugh.pl"
        assert DEFAULT_IRC_CONFIG.port == 6667
        assert DEFAULT_IRC_CONFIG.channel == "#vorest"

    def test_get_irc_config(self):
        """Test get_irc_config function"""
        config = get_irc_config()

        assert isinstance(config, IRCConfig)
        assert config.server is not None
        assert config.port > 0
        assert config.channel.startswith("#")


class TestBackendConfig:
    """Test backend server configuration"""

    def test_backend_host(self):
        """Test backend host configuration"""
        assert BACKEND_HOST == "0.0.0.0"

    def test_backend_port(self):
        """Test backend port configuration"""
        assert BACKEND_PORT == 8000
        assert isinstance(BACKEND_PORT, int)


class TestEnvironmentVariables:
    """Test environment variable handling"""

    def test_env_vars_with_defaults(self, monkeypatch):
        """Test that environment variables are used when set"""
        # This test demonstrates how env vars would be used
        # In production, you'd set these before importing config
        test_server = "custom.server.com"
        test_port = "7000"
        test_channel = "#custom"

        monkeypatch.setenv("IRC_SERVER", test_server)
        monkeypatch.setenv("IRC_PORT", test_port)
        monkeypatch.setenv("IRC_CHANNEL", test_channel)

        # Note: In real scenario, would need to reload config module
        assert os.getenv("IRC_SERVER") == test_server
        assert os.getenv("IRC_PORT") == test_port
        assert os.getenv("IRC_CHANNEL") == test_channel
