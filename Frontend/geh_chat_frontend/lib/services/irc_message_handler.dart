import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'encryption_service.dart';
import 'irc_service.dart';

/// Handles incoming backend messages for IrcService
/// Responsible for parsing and processing different message types
class IrcMessageHandler {
  final EncryptionService encryptionService;
  final String channel;
  final bool debugMode;
  final void Function(String) addSystemMessage;
  final void Function(IrcMessage) addMessage;
  final void Function(List<String>) updateUsers;
  final void Function(IrcConnectionState) updateConnectionState;
  final void Function(Map<String, dynamic>) sendToBackend;

  String? _nickname;
  final List<String> channelUsers = [];

  IrcMessageHandler({
    required this.encryptionService,
    required this.channel,
    required this.debugMode,
    required this.addSystemMessage,
    required this.addMessage,
    required this.updateUsers,
    required this.updateConnectionState,
    required this.sendToBackend,
  });

  /// Set the current user's nickname
  void setNickname(String? nickname) {
    _nickname = nickname;
  }

  /// Get current nickname
  String? get nickname => _nickname;

  /// Handle incoming message from backend
  Future<void> handle(dynamic data) async {
    try {
      final message = jsonDecode(data);
      final type = message['type'];

      if (debugMode) {
        addSystemMessage('[RECV] $type: ${message['content'] ?? ''}');
      }

      switch (type) {
        case 'connected':
          _handleConnected(message);
          break;

        case 'system':
          _handleSystem(message);
          break;

        case 'message':
          await _handleMessage(message);
          break;

        case 'users':
          _handleUsers(message);
          break;

        case 'join':
          _handleJoin(message);
          break;

        case 'setup_encryption':
          _handleSetupEncryption(message);
          break;

        case 'session_key':
          _handleSessionKey(message);
          break;

        case 'part':
        case 'quit':
          _handleLeave(message, type);
          break;

        case 'error':
          _handleError(message);
          break;

        case 'disconnected':
          _handleDisconnected();
          break;
      }
    } catch (e) {
      debugPrint('Error handling backend message: $e');
    }
  }

  void _handleConnected(Map<String, dynamic> message) {
    addSystemMessage(message['content'] ?? 'Connected to backend');
  }

  void _handleSystem(Map<String, dynamic> message) {
    addSystemMessage(message['content'] ?? '');
  }

  Future<void> _handleMessage(Map<String, dynamic> message) async {
    var content = message['content'] ?? '';
    final isEncrypted = message['is_encrypted'] ?? false;
    final sender = message['sender'] ?? 'Unknown';
    final target = message['target'] ?? channel;
    final isPrivate = message['is_private'] ?? false;

    // If message is encrypted, try to decrypt it
    if (isEncrypted && isPrivate && _nickname != null) {
      content = await _decryptMessageContent(message, sender, content);
    }

    addMessage(
      IrcMessage(
        sender: sender,
        content: content,
        target: target,
        timestamp: DateTime.now(),
        isPrivate: isPrivate,
        isEncrypted: isEncrypted && isPrivate,
      ),
    );
  }

  Future<String> _decryptMessageContent(
    Map<String, dynamic> message,
    String sender,
    String fallbackContent,
  ) async {
    final encryptedData = message['encrypted_data'];
    if (encryptedData == null) {
      return fallbackContent;
    }

    // Try to decrypt with existing session
    var decrypted = encryptionService.decryptMessage(
      sender,
      _nickname!,
      encryptedData,
    );

    // If decryption failed (no session), request session key from backend
    if (decrypted == null) {
      if (debugMode) {
        addSystemMessage(
          '[Encryption] No session with $sender - requesting session key...',
        );
      }

      // Request session key from backend
      sendToBackend({'type': 'get_session_key', 'from': sender});

      // Retry decryption multiple times with delays
      decrypted = await _retryDecryption(sender, encryptedData);
    }

    if (decrypted != null) {
      if (debugMode) {
        addSystemMessage('[Encryption] Decrypted message from $sender');
      }
      return decrypted;
    } else {
      if (debugMode) {
        addSystemMessage(
          '[Encryption] Failed to decrypt message from $sender - saving encrypted',
        );
      }
      return '[Encrypted message - unable to decrypt]';
    }
  }

  Future<String?> _retryDecryption(
    String sender,
    Map<String, dynamic> encryptedData,
  ) async {
    // Retry decryption multiple times with delays
    // Total wait time: (100ms + 150ms) * 10 = 2.5 seconds for first message
    for (int retry = 0; retry < 10; retry++) {
      final delay = retry == 0
          ? const Duration(milliseconds: 100)
          : const Duration(milliseconds: 150);

      await Future.delayed(delay);
      final decrypted = encryptionService.decryptMessage(
        sender,
        _nickname!,
        encryptedData,
      );
      if (decrypted != null) {
        if (debugMode) {
          addSystemMessage(
            '[Encryption] Session key received after retry $retry',
          );
        }
        return decrypted;
      }
    }
    return null;
  }

  void _handleUsers(Map<String, dynamic> message) {
    final users = (message['users'] as List?)?.cast<String>() ?? [];
    channelUsers.clear();
    channelUsers.addAll(users);
    updateUsers(List.from(channelUsers));

    if (users.isNotEmpty) {
      final usersList = users.join(', ');
      addSystemMessage('Active users: $usersList');
    }

    // Mark as fully connected
    updateConnectionState(IrcConnectionState.connected);
    addSystemMessage('Successfully joined channel!');
  }

  void _handleJoin(Map<String, dynamic> message) {
    final user = message['user'];
    if (user != null && !channelUsers.contains(user)) {
      channelUsers.add(user);
      updateUsers(List.from(channelUsers));
      addSystemMessage('$user joined the channel');
    }
  }

  void _handleSetupEncryption(Map<String, dynamic> message) {
    // Backend instructing this client to setup encryption with specific users
    final users = message['users'] as List<dynamic>?;
    if (users != null && _nickname != null) {
      if (debugMode) {
        addSystemMessage(
          '[Encryption] Backend instructing to setup encryption with: ${users.join(", ")}',
        );
      }

      // Establish local encryption sessions for each user
      for (final user in users) {
        final userName = user as String;
        encryptionService.establishSession(_nickname!, userName);

        // Notify Backend that we've established our local session
        sendToBackend({'type': 'encryption_session_ready', 'with': userName});

        if (debugMode) {
          addSystemMessage(
            '[Encryption] Established local session with $userName',
          );
        }
      }
    }
  }

  void _handleSessionKey(Map<String, dynamic> message) {
    // Received session key from backend
    final from = message['from'] as String?;
    final keyB64 = message['key'] as String?;
    if (from != null && keyB64 != null && _nickname != null) {
      try {
        // Decode base64 key
        final keyBytes = base64.decode(keyB64);
        final key = encrypt.Key(keyBytes);

        // Store in encryption service
        final sessionKey = _getSessionKeyName(from, _nickname!);
        encryptionService.sessionKeys[sessionKey] = key;

        if (debugMode) {
          addSystemMessage('[Encryption] Received session key from $from');
        }
      } catch (e) {
        if (debugMode) {
          addSystemMessage(
            '[Encryption] Failed to process session key from $from: $e',
          );
        }
      }
    }
  }

  void _handleLeave(Map<String, dynamic> message, String type) {
    final user = message['user'];
    if (user != null) {
      channelUsers.remove(user);
      updateUsers(List.from(channelUsers));
      final action = type == 'part' ? 'left the channel' : 'quit';
      addSystemMessage('$user $action');
    }
  }

  void _handleError(Map<String, dynamic> message) {
    addSystemMessage('Error: ${message['content']}');
  }

  void _handleDisconnected() {
    updateConnectionState(IrcConnectionState.disconnected);
    addSystemMessage('Disconnected from server');
  }

  String _getSessionKeyName(String user1, String user2) {
    final users = [user1, user2]..sort();
    return '${users[0]}_${users[1]}';
  }
}
