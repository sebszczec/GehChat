"""
IRC Protocol Parser for GehChat
Handles parsing and processing of IRC protocol messages
"""

import json
import logging
from dataclasses import dataclass
from typing import Optional, List, Dict, Any

logger = logging.getLogger(__name__)


@dataclass
class ParsedIRCMessage:
    """Parsed IRC protocol message"""

    prefix: str
    command: str
    params: List[str]
    raw: str


@dataclass
class IRCPrivateMessage:
    """Parsed PRIVMSG data"""

    sender: str
    target: str
    content: str
    is_encrypted: bool
    encrypted_data: Optional[Dict[str, Any]]


def parse_irc_line(line: str) -> Optional[ParsedIRCMessage]:
    """
    Parse a raw IRC protocol line into structured components

    Args:
        line: Raw IRC protocol line

    Returns:
        ParsedIRCMessage with prefix, command, and params, or None if invalid
    """
    parts = line.split(" ")
    if len(parts) < 2:
        return None

    if parts[0].startswith(":"):
        prefix = parts[0][1:]
        command = parts[1]
        params = parts[2:]
    else:
        prefix = ""
        command = parts[0]
        params = parts[1:]

    return ParsedIRCMessage(prefix=prefix, command=command, params=params, raw=line)


def extract_sender_from_prefix(prefix: str) -> str:
    """
    Extract nickname from IRC prefix (nick!user@host format)

    Args:
        prefix: IRC prefix like "nick!user@host"

    Returns:
        Just the nickname part
    """
    return prefix.split("!")[0] if "!" in prefix else prefix


def parse_names_list(line: str) -> List[str]:
    """
    Parse NAMES reply (353) to extract user list
    Removes IRC operator prefixes (@ for ops, + for voiced)

    Args:
        line: Raw NAMES reply line

    Returns:
        List of cleaned nicknames
    """
    users = line.split(":", 2)[2].split() if line.count(":") >= 2 else []
    # Remove @ and + prefixes from IRC usernames
    return [user.lstrip("@+") for user in users if user.lstrip("@+")]


def parse_privmsg(prefix: str, params: List[str], line: str) -> IRCPrivateMessage:
    """
    Parse PRIVMSG command into structured data
    Detects if message is encrypted JSON from Frontend user

    Args:
        prefix: IRC prefix (sender info)
        params: Command parameters (target)
        line: Full raw line for extracting message content

    Returns:
        IRCPrivateMessage with parsed data
    """
    sender = extract_sender_from_prefix(prefix)
    target = params[0] if params else ""
    message = line.split(":", 2)[2] if line.count(":") >= 2 else ""

    # Check if message is encrypted JSON from Frontend user
    is_encrypted = False
    encrypted_data = None
    content = message

    try:
        if message.startswith("{") and "encrypted_content" in message:
            encrypted_obj = json.loads(message)
            if "encrypted_content" in encrypted_obj and "iv" in encrypted_obj:
                is_encrypted = True
                encrypted_data = encrypted_obj
                content = "[Encrypted message]"
                logger.debug(f"Parsed encrypted message from {sender} to {target}")
    except (json.JSONDecodeError, ValueError):
        # Message is not JSON - treat as plain text
        pass

    return IRCPrivateMessage(
        sender=sender,
        target=target,
        content=content,
        is_encrypted=is_encrypted,
        encrypted_data=encrypted_data,
    )


def extract_ping_server(line: str) -> str:
    """
    Extract server name from PING command

    Args:
        line: PING command line

    Returns:
        Server name to respond with in PONG
    """
    return line.split(":", 1)[1] if ":" in line else ""


def is_end_of_motd(command: str) -> bool:
    """
    Check if command indicates end of MOTD

    Args:
        command: IRC numeric command

    Returns:
        True if 376 (End of MOTD) or 422 (MOTD not found)
    """
    return command in ("376", "422")


def is_names_reply(command: str) -> bool:
    """Check if command is NAMES reply (353)"""
    return command == "353"


def is_end_of_names(command: str) -> bool:
    """Check if command is end of NAMES (366)"""
    return command == "366"
