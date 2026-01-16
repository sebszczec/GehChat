import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'encryption_service.dart';
import 'irc_connection_manager.dart';
import 'irc_message_handler.dart';
import 'irc_translations.dart';

/// Main IRC Service for GehChat Frontend
/// Handles WebSocket communication with the backend server
class IrcService {
  // Connection configuration
  String server;
  int port;
  String channel;
  String backendUrl;

  // Services
  late EncryptionService _encryptionService;
  late IrcConnectionManager _connectionManager;
  late IrcMessageHandler _messageHandler;

  // Timers
  Timer? _keepaliveTimer;

  // State
  String? _nickname;
  bool debugMode = false;

  // Stream controllers
  final StreamController<IrcMessage> _messageController =
      StreamController<IrcMessage>.broadcast();
  final StreamController<List<String>> _usersController =
      StreamController<List<String>>.broadcast();
  final StreamController<IrcConnectionState> _connectionStateController =
      StreamController<IrcConnectionState>.broadcast();

  // Public streams
  Stream<IrcMessage> get messages => _messageController.stream;
  Stream<List<String>> get users => _usersController.stream;
  Stream<IrcConnectionState> get connectionState =>
      _connectionStateController.stream;

  // Getters
  String get nickname => _nickname ?? '';

  IrcService({String? server, int? port, String? channel, String? backendUrl})
      : server = server ?? 'slaugh.pl',
        port = port ?? 6667,
        channel = channel ?? '#vorest',
        backendUrl = backendUrl ?? 'ws://localhost:8000/ws' {
    _encryptionService = EncryptionService(debugMode: debugMode);
    _initializeManagers();
  }

  void _initializeManagers() {
    _connectionManager = IrcConnectionManager(
      getDebugMode: () => debugMode,
      updateConnectionState: (state) {
        if (!_connectionStateController.isClosed) {
          _connectionStateController.add(state);
        }
      },
      addSystemMessage: _addSystemMessage,
      onMessageReceived: (data) => _messageHandler.handle(data),
    );

    _messageHandler = IrcMessageHandler(
      encryptionService: _encryptionService,
      channel: channel,
      debugMode: debugMode,
      addSystemMessage: _addSystemMessage,
      addMessage: (msg) {
        if (!_messageController.isClosed) {
          _messageController.add(msg);
        }
      },
      updateUsers: (users) {
        if (!_usersController.isClosed) {
          _usersController.add(users);
        }
      },
      updateConnectionState: (state) {
        if (!_connectionStateController.isClosed) {
          _connectionStateController.add(state);
        }
      },
      sendToBackend: _sendToBackend,
    );
  }

  /// Check if current locale is Polish
  bool get _isPolish {
    final locale = kIsWeb ? 'en' : Platform.localeName.toLowerCase();
    return locale.startsWith('pl');
  }

  /// Update connection settings
  void updateSettings({String? newServer, int? newPort, String? newChannel}) {
    if (newServer != null) server = newServer;
    if (newPort != null) port = newPort;
    if (newChannel != null) channel = newChannel;

    // Rebuild backendUrl if server or port changed
    if (newServer != null || newPort != null) {
      backendUrl = 'ws://$server:$port/ws';
      debugPrint('Updated backend URL to: $backendUrl');
    }
  }

  /// Check if a user is a Frontend user by querying the backend
  Future<bool> checkIsFrontendUser(String nickname) async {
    try {
      final httpUrl = backendUrl
          .replaceAll('ws://', 'http://')
          .replaceAll('wss://', 'https://')
          .replaceAll('/ws', '/api/is-frontend-user/$nickname');

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(httpUrl));
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final isFrontend = json['is_frontend_user'] as bool? ?? false;

        if (debugMode) {
          debugPrint(
            '[Frontend Check] User $nickname is Frontend user: $isFrontend',
          );
        }

        return isFrontend;
      }

      return false;
    } catch (e) {
      if (debugMode) {
        debugPrint(
          '[Frontend Check] Error checking if $nickname is frontend user: $e',
        );
      }
      return false;
    }
  }

  void _addSystemMessage(String content) {
    try {
      if (!_messageController.isClosed) {
        _messageController.add(
          IrcMessage(
            sender: 'System',
            content: content,
            target: channel,
            timestamp: DateTime.now(),
            isPrivate: false,
            isSystem: true,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding system message: $e');
    }
  }

  /// Connect to the IRC backend
  Future<void> connect({String? customNickname}) async {
    await runZoned(
      () async {
        final success = await _connectionManager.connect(backendUrl);
        if (!success) return;

        // Generate nickname
        _nickname = customNickname ?? generateFriendlyNickname();
        _messageHandler.setNickname(_nickname);
        _addSystemMessage(
          '${IrcTranslations.get('using_nickname', isPolish: _isPolish)} $_nickname',
        );

        // Register this Frontend user for encryption
        final deviceId = _encryptionService.registerUser(_nickname!);
        if (debugMode) {
          _addSystemMessage('Registered for encrypted messaging: $deviceId');
        }

        // Send connect command to backend
        _sendToBackend({
          'type': 'connect',
          'nickname': _nickname,
          'is_frontend_user': true,
        });

        _addSystemMessage(
          IrcTranslations.get('sent_auth', isPolish: _isPolish),
        );
      },
      onError: (dynamic error, StackTrace stackTrace) {
        debugPrint('Zone error caught: $error\nStackTrace: $stackTrace');
        try {
          _connectionManager.isConnected = false;
          if (!_connectionStateController.isClosed) {
            _connectionStateController.add(IrcConnectionState.error);
          }
        } catch (e) {
          debugPrint('Error in zone error handler: $e');
        }
      },
    );
  }

  void _sendToBackend(Map<String, dynamic> data) {
    if (_connectionManager.isConnected) {
      try {
        _connectionManager.send(jsonEncode(data));
        if (debugMode) {
          _addSystemMessage('[SEND] ${data['type']}: ${data['content'] ?? ''}');
        }
      } catch (e) {
        debugPrint('Error sending to backend: $e');
      }
    }
  }

  /// Send a message to a channel or private user
  Future<void> sendMessage(String message, {String? target}) async {
    if (!_connectionManager.isConnected || _nickname == null) return;

    var recipient = target ?? channel;

    // Remove @ prefix if present (IRC doesn't accept @ in nicknames)
    if (recipient.startsWith('@')) {
      recipient = recipient.substring(1);
    }

    // Check if this is a private message (not to channel)
    final isPrivateMessage = recipient != channel;

    if (isPrivateMessage) {
      await _sendPrivateMessage(recipient, message);
    } else {
      // Public channel message - always unencrypted
      _sendToBackend({
        'type': 'message',
        'target': recipient,
        'content': message,
        'is_encrypted': false,
      });
    }
  }

  Future<void> _sendPrivateMessage(String recipient, String message) async {
    // Check if recipient is a Frontend user
    final isFrontendUser = await checkIsFrontendUser(recipient);

    if (isFrontendUser) {
      // Check if encryption session with recipient exists
      final sessionKey = _getSessionKeyName(_nickname!, recipient);

      // If no encryption session, cannot send message - Backend must setup first
      if (!_encryptionService.sessionKeys.containsKey(sessionKey)) {
        if (debugMode) {
          _addSystemMessage(
            '[Encryption] Cannot send to $recipient - encryption session not ready',
          );
        }
        return;
      }

      // Encrypt and send message
      final encryptedData = _encryptionService.encryptMessage(
        _nickname!,
        recipient,
        message,
      );

      if (encryptedData != null) {
        _sendToBackend({
          'type': 'message',
          'target': recipient,
          'content': message,
          'is_encrypted': true,
          'encrypted_data': encryptedData,
        });

        if (debugMode) {
          _addSystemMessage(
            '[Encryption] Encrypted message sent to $recipient',
          );
        }
      } else {
        debugPrint('[IrcService] Encryption failed for message to $recipient');
      }
    } else {
      // Recipient is IRC user - send plain, never encrypt
      _sendToBackend({
        'type': 'message',
        'target': recipient,
        'content': message,
        'is_encrypted': false,
      });

      if (debugMode) {
        _addSystemMessage(
          '[Encryption] Message to $recipient sent unencrypted (IRC user)',
        );
      }
    }
  }

  Future<void> sendPrivateMessage(String recipient, String message) async {
    await sendMessage(message, target: recipient);
  }

  void establishSessionWithUser(String otherUser) {
    if (_nickname != null) {
      _encryptionService.establishSession(_nickname!, otherUser);
      _sendToBackend({'type': 'establish_session', 'other_user': otherUser});
    }
  }

  /// Disconnect from the IRC backend
  void disconnect() {
    if (!_connectionManager.isConnected) return;

    try {
      _sendToBackend({'type': 'disconnect'});
    } catch (e) {
      debugPrint('Error sending disconnect message: $e');
    }

    // Clean up encryption sessions
    if (_nickname != null) {
      _encryptionService.cleanupUserSessions(_nickname!);
    }

    stopKeepaliveTimer();
    _connectionManager.disconnect();
    _messageHandler.channelUsers.clear();

    if (!_usersController.isClosed) {
      _usersController.add([]);
    }
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(IrcConnectionState.disconnected);
    }

    _addSystemMessage(
      IrcTranslations.get('disconnected', isPolish: _isPolish),
    );
  }

  void startKeepaliveTimer() {
    stopKeepaliveTimer();
    _keepaliveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_connectionManager.isConnected) {
        _sendToBackend({'type': 'ping'});
        debugPrint('Sent keepalive PING');
      }
    });
  }

  void stopKeepaliveTimer() {
    _keepaliveTimer?.cancel();
    _keepaliveTimer = null;
  }

  String generateFriendlyNickname() {
    final adjectives = [
      'Happy',
      'Swift',
      'Brave',
      'Clever',
      'Gentle',
      'Noble',
      'Wise',
      'Kind',
    ];
    final nouns = [
      'Fox',
      'Wolf',
      'Bear',
      'Eagle',
      'Lion',
      'Tiger',
      'Hawk',
      'Owl',
    ];

    final random = DateTime.now().millisecondsSinceEpoch;
    final adj = adjectives[random % adjectives.length];
    final noun = nouns[(random ~/ adjectives.length) % nouns.length];
    final num = (random % 1000).toString().padLeft(3, '0');

    return '$adj$noun$num';
  }

  String generateRandomNickname() {
    return generateFriendlyNickname();
  }

  void dispose() {
    disconnect();
    stopKeepaliveTimer();
    _encryptionService.dispose();
    _messageController.close();
    _usersController.close();
    _connectionStateController.close();
  }

  String _getSessionKeyName(String user1, String user2) {
    final users = [user1, user2]..sort();
    return '${users[0]}_${users[1]}';
  }
}

/// Represents an IRC message
class IrcMessage {
  final String sender;
  final String content;
  final String target;
  final DateTime timestamp;
  final bool isPrivate;
  final bool isSystem;
  final bool isEncrypted;

  IrcMessage({
    required this.sender,
    required this.content,
    required this.target,
    required this.timestamp,
    this.isPrivate = false,
    this.isSystem = false,
    this.isEncrypted = false,
  });
}

/// IRC connection states
enum IrcConnectionState {
  disconnected,
  connecting,
  joiningChannel,
  connected,
  error,
}
