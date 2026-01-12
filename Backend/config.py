"""
GehChat Backend Configuration
Configuration file for IRC server settings
"""
import os
from pydantic import BaseModel
from typing import Optional


class IRCConfig(BaseModel):
    """IRC Server configuration"""
    server: str
    port: int
    channel: str
    
    class Config:
        frozen = True  # Make it immutable


# Default IRC server configuration
DEFAULT_IRC_CONFIG = IRCConfig(
    server=os.getenv("IRC_SERVER", "slaugh.pl"),
    port=int(os.getenv("IRC_PORT", "6667")),
    channel=os.getenv("IRC_CHANNEL", "#vorest")
)


# Backend server configuration
BACKEND_HOST = os.getenv("BACKEND_HOST", "0.0.0.0")
BACKEND_PORT = int(os.getenv("BACKEND_PORT", "8000"))


def get_irc_config() -> IRCConfig:
    """Get IRC configuration"""
    return DEFAULT_IRC_CONFIG
