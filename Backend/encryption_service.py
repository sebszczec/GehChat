"""
Signal Protocol-based Encryption Service for GehChat
Handles end-to-end encryption for private messages between Frontend users
"""

import json
import base64
import logging
from typing import Optional, Dict
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.backends import default_backend
import os
from datetime import datetime

logger = logging.getLogger(__name__)


class SignalProtocolService:
    """
    Simple Signal Protocol-inspired encryption for GehChat
    Handles encryption/decryption of private messages between Frontend users
    Only encrypts Frontend-to-Frontend messages, not messages from/to regular IRC users
    """

    def __init__(self):
        """Initialize encryption service"""
        # In a real implementation, this would use proper Signal Protocol library
        # For now, we use AES-256-GCM with PBKDF2 derived keys
        self.session_keys: Dict[str, bytes] = {}
        self.frontend_users: set = (
            set()
        )  # Track all Frontend users (regardless of sessions)
        self.pending_sessions: Dict[str, set] = (
            {}
        )  # user -> set of users with pending sessions
        logger.info("Signal Protocol Service initialized")

    def register_user(self, nickname: str, device_id: str = None) -> str:
        """
        Register a Frontend user for encrypted communications
        Returns a public key/device identifier
        """
        if device_id is None:
            device_id = f"{nickname}_{int(datetime.now().timestamp())}"

        # Add user to Frontend users set
        self.frontend_users.add(nickname)
        logger.debug(
            f"Registering user {nickname} with device_id {device_id} (total Frontend users: {len(self.frontend_users)})"
        )
        return device_id

    def establish_session(self, user1: str, user2: str) -> bool:
        """
        Establish encrypted session between two Frontend users
        In real Signal Protocol, this would involve complex key exchange
        For this implementation, we generate a shared session key
        """
        # Sort names to ensure consistent session key naming (matching Frontend behavior)
        users = sorted([user1, user2])
        session_key = f"{users[0]}_{users[1]}"

        # Generate 32-byte (256-bit) session key
        if session_key not in self.session_keys:
            self.session_keys[session_key] = os.urandom(32)
            logger.info(f"Established encrypted session between {user1} and {user2}")
            return True

        logger.debug(f"Session already exists between {user1} and {user2}")
        return False

    def encrypt_message(
        self, sender: str, recipient: str, message: str
    ) -> Optional[Dict[str, str]]:
        """
        Encrypt a message using the session key between sender and recipient
        Only encrypts if both users are Frontend users (session key exists)

        Returns: {
            'encrypted_content': base64_encoded_ciphertext,
            'iv': base64_encoded_iv,
            'is_encrypted': True
        } or None if session doesn't exist (IRC user communication)
        """
        # Sort names to match session key naming format
        users = sorted([sender, recipient])
        session_key = f"{users[0]}_{users[1]}"

        # If no session key exists, recipient is likely an IRC user
        # Return None to indicate message should be sent unencrypted
        if session_key not in self.session_keys:
            logger.debug(
                f"No session between {sender} and {recipient} - sending unencrypted"
            )
            return None

        try:
            key = self.session_keys[session_key]
            iv = os.urandom(16)

            cipher = Cipher(
                algorithms.AES(key), modes.CBC(iv), backend=default_backend()
            )
            encryptor = cipher.encryptor()

            # Pad message to AES block size (16 bytes)
            plaintext = message.encode("utf-8")
            block_size = 16
            padding_length = block_size - (len(plaintext) % block_size)
            padded_plaintext = plaintext + bytes([padding_length] * padding_length)

            ciphertext = encryptor.update(padded_plaintext) + encryptor.finalize()

            encrypted_data = {
                "encrypted_content": base64.b64encode(ciphertext).decode("utf-8"),
                "iv": base64.b64encode(iv).decode("utf-8"),
                "is_encrypted": True,
            }

            logger.debug(
                f"Message encrypted from {sender} to {recipient} ({len(message)} chars -> {len(ciphertext)} bytes)"
            )
            return encrypted_data

        except Exception as e:
            logger.error(
                f"Encryption error for message from {sender} to {recipient}: {e}"
            )
            return None

    def decrypt_message(
        self, sender: str, recipient: str, encrypted_data: Dict[str, str]
    ) -> Optional[str]:
        """
        Decrypt a message using the session key

        Args:
            sender: Original sender of the message
            recipient: Recipient of the message
            encrypted_data: Dict with 'encrypted_content', 'iv'

        Returns: Decrypted message or None if decryption fails
        """
        # Sort names to match session key naming format
        users = sorted([sender, recipient])
        session_key = f"{users[0]}_{users[1]}"

        if session_key not in self.session_keys:
            logger.warning(f"No session found for decryption: {session_key}")
            return None

        try:
            key = self.session_keys[session_key]
            iv = base64.b64decode(encrypted_data["iv"])
            ciphertext = base64.b64decode(encrypted_data["encrypted_content"])

            cipher = Cipher(
                algorithms.AES(key), modes.CBC(iv), backend=default_backend()
            )
            decryptor = cipher.decryptor()

            padded_plaintext = decryptor.update(ciphertext) + decryptor.finalize()

            # Remove PKCS7 padding
            padding_length = padded_plaintext[-1]
            plaintext = padded_plaintext[:-padding_length]

            logger.debug(
                f"Message decrypted from {sender} to {recipient} ({len(ciphertext)} bytes -> {len(plaintext)} chars)"
            )
            return plaintext.decode("utf-8")

        except ValueError as e:
            logger.error(
                f"Decryption verification failed for message from {sender}: {e}"
            )
            return None
        except Exception as e:
            logger.error(f"Decryption error for message from {sender}: {e}")
            return None

    def is_frontend_user(self, nickname: str) -> bool:
        """
        Check if a user is a Frontend user
        A Frontend user is one that has been registered with the encryption service
        (i.e., connected via the Flutter app, not plain IRC client)
        """
        return nickname in self.frontend_users

    def cleanup_session(self, user: str):
        """
        Clean up all sessions for a user when they disconnect
        """
        keys_to_remove = [
            key
            for key in self.session_keys.keys()
            if key.startswith(f"{user}_") or key.endswith(f"_{user}")
        ]

        for key in keys_to_remove:
            del self.session_keys[key]
            logger.info(f"Cleaned up session: {key}")
        # Remove user from Frontend users set when they disconnect
        if user in self.frontend_users:
            self.frontend_users.discard(user)
            logger.info(
                f"Removed Frontend user {user} from active users (total Frontend users: {len(self.frontend_users)})"
            )

    def get_unencrypted_frontend_users(self, for_user: str) -> list:
        """
        Get list of Frontend users that this user hasn't established encryption with yet
        Used to pro-actively setup encryption on user connect
        """
        unencrypted = []
        for other_user in self.frontend_users:
            if other_user == for_user:
                continue

            # Check if session key exists for this pair
            users = sorted([for_user, other_user])
            session_key = f"{users[0]}_{users[1]}"

            if session_key not in self.session_keys:
                unencrypted.append(other_user)

        return unencrypted

    def mark_session_confirmed(self, user: str, other_user: str):
        """Mark that a user has confirmed encryption setup with another user"""
        if user not in self.pending_sessions:
            self.pending_sessions[user] = set()

        self.pending_sessions[user].discard(other_user)
        logger.debug(f"Session confirmed: {user} <-> {other_user}")

    def add_pending_session(self, user: str, other_user: str):
        """Add a session to pending list"""
        if user not in self.pending_sessions:
            self.pending_sessions[user] = set()

        self.pending_sessions[user].add(other_user)
        logger.debug(f"Session pending: {user} <-> {other_user}")

    def has_pending_sessions(self, user: str) -> bool:
        """Check if user has any pending encryption sessions"""
        return user in self.pending_sessions and len(self.pending_sessions[user]) > 0
