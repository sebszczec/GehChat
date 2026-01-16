import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';

/// Signal Protocol-based Encryption Service for GehChat Frontend
/// Handles end-to-end encryption for private messages between Frontend users
class EncryptionService {
  // Session keys for established encrypted sessions
  // Map format: "user1_user2" -> encryption key
  final Map<String, encrypt.Key> _sessionKeys = {};

  final bool debugMode;

  EncryptionService({this.debugMode = false});

  /// Access session keys (used for external key injection)
  Map<String, encrypt.Key> get sessionKeys => _sessionKeys;

  /// Register a Frontend user for encrypted communications
  /// Returns device ID for this user
  String registerUser(String nickname) {
    final deviceId = '${nickname}_${DateTime.now().millisecondsSinceEpoch}';

    if (debugMode) {
      debugPrint(
        '[Encryption] Registered user: $nickname with device ID: $deviceId',
      );
    }

    return deviceId;
  }

  /// Establish encrypted session between two Frontend users
  /// Generates a shared encryption key for the session
  bool establishSession(String user1, String user2) {
    final sessionKey = _getSessionKey(user1, user2);

    if (!_sessionKeys.containsKey(sessionKey)) {
      // Generate a 32-byte (256-bit) key
      final key = encrypt.Key.fromSecureRandom(32);

      _sessionKeys[sessionKey] = key;

      if (debugMode) {
        debugPrint(
          '[Encryption] Established session between $user1 and $user2',
        );
      }
      return true;
    }

    if (debugMode) {
      debugPrint(
        '[Encryption] Session already exists between $user1 and $user2',
      );
    }
    return false;
  }

  /// Encrypt a message for a specific recipient
  /// Returns encrypted message data or null if recipient is IRC user (no session)
  Map<String, String>? encryptMessage(
    String sender,
    String recipient,
    String message,
  ) {
    final sessionKey = _getSessionKey(sender, recipient);

    // If no session exists, recipient is likely an IRC user
    if (!_sessionKeys.containsKey(sessionKey)) {
      if (debugMode) {
        debugPrint(
          '[Encryption] No session between $sender and $recipient - sending unencrypted',
        );
      }
      return null;
    }

    try {
      final key = _sessionKeys[sessionKey]!;
      // Generate a new random IV for each message
      final iv = encrypt.IV.fromSecureRandom(16);

      // Ensure IV has correct length
      if (iv.bytes.length != 16) {
        debugPrint('[Encryption] Invalid IV length: ${iv.bytes.length}');
        return null;
      }

      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc),
      );
      final encrypted = encrypter.encrypt(message, iv: iv);

      final encryptedData = {
        'encrypted_content': encrypted.base64,
        'iv': iv.base64,
        'is_encrypted': 'true',
      };

      if (debugMode) {
        debugPrint(
          '[Encryption] Message encrypted from $sender to $recipient (${message.length} chars -> ${encrypted.base64.length} bytes)',
        );
      }

      return encryptedData;
    } catch (e, stackTrace) {
      debugPrint('[Encryption] Error encrypting message: $e');
      debugPrint('[Encryption] Stack trace: $stackTrace');
      return null;
    }
  }

  /// Decrypt a message from a specific sender
  /// Returns decrypted message or null if decryption fails
  String? decryptMessage(
    String sender,
    String recipient,
    Map<String, dynamic> encryptedData,
  ) {
    final sessionKey = _getSessionKey(sender, recipient);

    if (!_sessionKeys.containsKey(sessionKey)) {
      debugPrint('[Encryption] No session found for decryption: $sessionKey');
      return null;
    }

    try {
      final key = _sessionKeys[sessionKey]!;
      final iv = encrypt.IV.fromBase64(encryptedData['iv'] as String);

      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc),
      );
      final decrypted = encrypter.decrypt64(
        encryptedData['encrypted_content'] as String,
        iv: iv,
      );

      if (debugMode) {
        debugPrint(
          '[Encryption] Message decrypted from $sender to $recipient (${(encryptedData['encrypted_content'] as String).length} bytes -> ${decrypted.length} chars)',
        );
      }

      return decrypted;
    } catch (e) {
      debugPrint('[Encryption] Error decrypting message: $e');
      return null;
    }
  }

  /// Check if a user is a Frontend user (has active encrypted sessions)
  bool isFrontendUser(String nickname) {
    for (final sessionKey in _sessionKeys.keys) {
      if (sessionKey.startsWith('${nickname}_') ||
          sessionKey.endsWith('_$nickname')) {
        return true;
      }
    }
    return false;
  }

  /// Get the session key identifier for two users
  /// Always returns the same key regardless of user order
  String _getSessionKey(String user1, String user2) {
    final users = [user1, user2]..sort();
    return '${users[0]}_${users[1]}';
  }

  /// Clean up all sessions for a user when they disconnect
  void cleanupUserSessions(String nickname) {
    final keysToRemove = <String>[];

    for (final key in _sessionKeys.keys) {
      if (key.startsWith('${nickname}_') || key.endsWith('_$nickname')) {
        keysToRemove.add(key);
      }
    }

    for (final key in keysToRemove) {
      _sessionKeys.remove(key);

      if (debugMode) {
        debugPrint('[Encryption] Cleaned up session: $key');
      }
    }
  }

  /// Get number of active sessions
  int get activeSessionCount => _sessionKeys.length;

  /// Dispose resources
  void dispose() {
    _sessionKeys.clear();
  }
}
