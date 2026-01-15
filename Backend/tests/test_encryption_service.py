"""
Tests for Signal Protocol Encryption Service
"""

import pytest
import json
from encryption_service import SignalProtocolService


class TestSignalProtocolService:
    """Test Signal Protocol encryption service"""

    @pytest.fixture
    def encryption_service(self):
        """Create a new encryption service instance for each test"""
        return SignalProtocolService()

    def test_register_user(self, encryption_service):
        """Test user registration"""
        device_id = encryption_service.register_user("user1")
        assert device_id is not None
        assert "user1" in device_id

    def test_establish_session(self, encryption_service):
        """Test establishing encrypted session between two users"""
        result = encryption_service.establish_session("user1", "user2")
        assert result is True

        # Establishing again should return False
        result = encryption_service.establish_session("user1", "user2")
        assert result is False

    def test_encrypt_message_no_session(self, encryption_service):
        """Test encryption returns None when no session exists"""
        result = encryption_service.encrypt_message("user1", "user2", "Hello")
        assert result is None

    def test_encrypt_message_with_session(self, encryption_service):
        """Test encryption with established session"""
        encryption_service.establish_session("user1", "user2")

        encrypted = encryption_service.encrypt_message("user1", "user2", "Hello World")

        assert encrypted is not None
        assert "encrypted_content" in encrypted
        assert "iv" in encrypted
        assert encrypted["is_encrypted"] is True
        assert encrypted["encrypted_content"] != "Hello World"

    def test_decrypt_message(self, encryption_service):
        """Test decryption"""
        encryption_service.establish_session("user1", "user2")

        original_message = "Hello World"
        encrypted = encryption_service.encrypt_message(
            "user1", "user2", original_message
        )

        decrypted = encryption_service.decrypt_message("user1", "user2", encrypted)

        assert decrypted == original_message

    def test_decrypt_message_no_session(self, encryption_service):
        """Test decryption fails when no session exists"""
        encrypted_data = {
            "encrypted_content": "dGVzdA==",  # base64 "test"
            "nonce": "dGVzdA==",
            "tag": "dGVzdA==",
        }

        result = encryption_service.decrypt_message("user1", "user2", encrypted_data)
        assert result is None

    def test_is_frontend_user_with_session(self, encryption_service):
        """Test Frontend user detection after registration"""
        assert encryption_service.is_frontend_user("user1") is False

        # Register user1 as Frontend user
        encryption_service.register_user("user1")
        assert encryption_service.is_frontend_user("user1") is True

        # user2 is still not registered
        assert encryption_service.is_frontend_user("user2") is False

        # Register user2
        encryption_service.register_user("user2")
        assert encryption_service.is_frontend_user("user2") is True

    def test_is_frontend_user_without_registration(self, encryption_service):
        """Test user without registration is not a Frontend user"""
        assert encryption_service.is_frontend_user("random_user") is False

        # Register the user
        encryption_service.register_user("random_user")
        assert encryption_service.is_frontend_user("random_user") is True

    def test_cleanup_session(self, encryption_service):
        """Test session cleanup removes user from Frontend users"""
        encryption_service.register_user("user1")
        encryption_service.register_user("user2")
        encryption_service.register_user("user3")

        encryption_service.establish_session("user1", "user2")
        encryption_service.establish_session("user1", "user3")

        assert encryption_service.is_frontend_user("user1") is True
        assert encryption_service.is_frontend_user("user2") is True
        assert encryption_service.is_frontend_user("user3") is True

        encryption_service.cleanup_session("user1")

        # user1 should be removed from Frontend users
        assert encryption_service.is_frontend_user("user1") is False
        # user2 and user3 should still be Frontend users (they're still registered)
        assert encryption_service.is_frontend_user("user2") is True
        assert encryption_service.is_frontend_user("user3") is True

    def test_encrypt_decrypt_roundtrip(self, encryption_service):
        """Test full encryption/decryption cycle"""
        encryption_service.establish_session("alice", "bob")

        test_messages = [
            "Hello Bob",
            "This is a longer message with special chars: ąęćńłóż",
            "Numbers: 123456789",
            "a",  # Single character
        ]

        for original in test_messages:
            encrypted = encryption_service.encrypt_message("alice", "bob", original)
            assert encrypted is not None

            decrypted = encryption_service.decrypt_message("alice", "bob", encrypted)
            assert decrypted == original

    def test_bidirectional_encryption(self, encryption_service):
        """Test encryption works in both directions"""
        encryption_service.establish_session("user1", "user2")

        # user1 -> user2
        msg1 = encryption_service.encrypt_message("user1", "user2", "Hello from user1")
        assert msg1 is not None

        dec1 = encryption_service.decrypt_message("user1", "user2", msg1)
        assert dec1 == "Hello from user1"

        # user2 -> user1
        msg2 = encryption_service.encrypt_message("user2", "user1", "Hello from user2")
        assert msg2 is not None

        dec2 = encryption_service.decrypt_message("user2", "user1", msg2)
        assert dec2 == "Hello from user2"

    def test_session_isolation(self, encryption_service):
        """Test that different sessions don't interfere"""
        encryption_service.establish_session("user1", "user2")
        encryption_service.establish_session("user3", "user4")

        msg1 = encryption_service.encrypt_message("user1", "user2", "Message 1-2")
        msg2 = encryption_service.encrypt_message("user3", "user4", "Message 3-4")

        # Encrypted messages should be different
        assert msg1["encrypted_content"] != msg2["encrypted_content"]

        # Decrypt should work correctly
        dec1 = encryption_service.decrypt_message("user1", "user2", msg1)
        assert dec1 == "Message 1-2"

        dec2 = encryption_service.decrypt_message("user3", "user4", msg2)
        assert dec2 == "Message 3-4"
