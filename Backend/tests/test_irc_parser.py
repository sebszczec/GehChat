"""
Tests for IRC Parser module
"""

import pytest
from irc_parser import (
    parse_irc_line,
    extract_sender_from_prefix,
    parse_names_list,
    parse_privmsg,
    extract_ping_server,
    is_end_of_motd,
    is_names_reply,
    is_end_of_names,
    ParsedIRCMessage,
    IRCPrivateMessage,
)


class TestParseIRCLine:
    """Tests for parse_irc_line function"""

    def test_parse_with_prefix(self):
        """Test parsing line with prefix"""
        result = parse_irc_line(":nick!user@host PRIVMSG #channel :Hello")

        assert result is not None
        assert result.prefix == "nick!user@host"
        assert result.command == "PRIVMSG"
        assert result.params == ["#channel", ":Hello"]

    def test_parse_without_prefix(self):
        """Test parsing line without prefix"""
        result = parse_irc_line("PING :server.name")

        assert result is not None
        assert result.prefix == ""
        assert result.command == "PING"
        assert result.params == [":server.name"]

    def test_parse_invalid_line(self):
        """Test parsing invalid line returns None"""
        result = parse_irc_line("X")

        assert result is None

    def test_parse_numeric_command(self):
        """Test parsing numeric IRC command"""
        result = parse_irc_line(":server 353 nick = #channel :user1 user2")

        assert result is not None
        assert result.command == "353"


class TestExtractSenderFromPrefix:
    """Tests for extract_sender_from_prefix function"""

    def test_extract_from_full_prefix(self):
        """Test extracting nick from full prefix"""
        sender = extract_sender_from_prefix("nick!user@host")

        assert sender == "nick"

    def test_extract_from_simple_prefix(self):
        """Test extracting nick from simple prefix"""
        sender = extract_sender_from_prefix("nick")

        assert sender == "nick"


class TestParseNamesList:
    """Tests for parse_names_list function"""

    def test_parse_names_strips_prefixes(self):
        """Test parsing NAMES list strips @ and + prefixes"""
        line = ":server 353 nick = #channel :@operator +voiced regular"
        users = parse_names_list(line)

        assert "operator" in users
        assert "voiced" in users
        assert "regular" in users
        assert not any(u.startswith("@") or u.startswith("+") for u in users)

    def test_parse_names_empty(self):
        """Test parsing empty NAMES list"""
        line = ":server 353 nick = #channel"
        users = parse_names_list(line)

        assert users == []


class TestParsePrivmsg:
    """Tests for parse_privmsg function"""

    def test_parse_plain_message(self):
        """Test parsing plain text message"""
        result = parse_privmsg(
            "sender!user@host",
            ["#channel"],
            ":sender!user@host PRIVMSG #channel :Hello world",
        )

        assert result.sender == "sender"
        assert result.target == "#channel"
        assert result.content == "Hello world"
        assert result.is_encrypted is False
        assert result.encrypted_data is None

    def test_parse_encrypted_message(self):
        """Test parsing encrypted JSON message"""
        encrypted_json = '{"encrypted_content": "abc123", "iv": "xyz789"}'
        line = f":sender!user@host PRIVMSG user :{encrypted_json}"

        result = parse_privmsg("sender!user@host", ["user"], line)

        assert result.is_encrypted is True
        assert result.encrypted_data is not None
        assert result.encrypted_data["encrypted_content"] == "abc123"
        assert result.encrypted_data["iv"] == "xyz789"

    def test_parse_private_message(self):
        """Test parsing private message to user"""
        result = parse_privmsg(
            "sender!user@host",
            ["recipient"],
            ":sender!user@host PRIVMSG recipient :Private message",
        )

        assert result.target == "recipient"


class TestExtractPingServer:
    """Tests for extract_ping_server function"""

    def test_extract_server_name(self):
        """Test extracting server name from PING"""
        server = extract_ping_server("PING :irc.server.net")

        assert server == "irc.server.net"

    def test_extract_empty_server(self):
        """Test extracting from PING without colon"""
        server = extract_ping_server("PING server")

        assert server == ""


class TestCommandChecks:
    """Tests for IRC command type checking functions"""

    def test_is_end_of_motd_376(self):
        """Test 376 is end of MOTD"""
        assert is_end_of_motd("376") is True

    def test_is_end_of_motd_422(self):
        """Test 422 is end of MOTD (MOTD not found)"""
        assert is_end_of_motd("422") is True

    def test_is_not_end_of_motd(self):
        """Test other commands are not end of MOTD"""
        assert is_end_of_motd("353") is False

    def test_is_names_reply(self):
        """Test 353 is NAMES reply"""
        assert is_names_reply("353") is True
        assert is_names_reply("366") is False

    def test_is_end_of_names(self):
        """Test 366 is end of NAMES"""
        assert is_end_of_names("366") is True
        assert is_end_of_names("353") is False
