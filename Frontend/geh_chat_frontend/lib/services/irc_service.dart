import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'encryption_service.dart';

class IrcService {
  WebSocketChannel? _channel;
  Timer? _keepaliveTimer;
  String server;
  int port;
  String? _nickname;
  String channel;

  // Backend WebSocket URL
  String backendUrl;

  // Encryption service for private messages
  late EncryptionService _encryptionService;

  final StreamController<IrcMessage> _messageController =
      StreamController<IrcMessage>.broadcast();
  final StreamController<List<String>> _usersController =
      StreamController<List<String>>.broadcast();
  final StreamController<IrcConnectionState> _connectionStateController =
      StreamController<IrcConnectionState>.broadcast();

  Stream<IrcMessage> get messages => _messageController.stream;
  Stream<List<String>> get users => _usersController.stream;
  Stream<IrcConnectionState> get connectionState =>
      _connectionStateController.stream;

  final List<String> _channelUsers = [];
  bool _isConnected = false;
  bool debugMode = false;

  // Translation maps for system messages
  static final Map<String, Map<String, String>> _translations = {
    'connecting': {'en': 'Connecting to backend', 'pl': 'Łączenie z backendem'},
    'connected': {'en': 'Connected to server!', 'pl': 'Połączono z serwerem!'},
    'using_nickname': {'en': 'Using nickname:', 'pl': 'Używany nick:'},
    'sent_auth': {
      'en': 'Connecting to IRC server...',
      'pl': 'Łączenie z serwerem IRC...',
    },
    'joining_channel': {'en': 'Joining channel', 'pl': 'Dołączanie do kanału'},
    'joined_channel': {
      'en': 'Successfully joined channel!',
      'pl': 'Pomyślnie dołączono do kanału!',
    },
    'active_users': {'en': 'Active users:', 'pl': 'Aktywni użytkownicy:'},
    'joined': {'en': 'joined the channel', 'pl': 'dołączył do kanału'},
    'left': {'en': 'left the channel', 'pl': 'opuścił kanał'},
    'quit': {'en': 'quit', 'pl': 'rozłączył się'},
    'disconnected': {
      'en': 'Disconnected from server',
      'pl': 'Rozłączono z serwerem',
    },
    'connection_error': {
      'en': 'Connection error occurred',
      'pl': 'Wystąpił błąd połączenia',
    },
    'connection_refused': {
      'en': 'Connection refused - Backend is not running or unreachable',
      'pl': 'Połączenie odrzucone - Backend nie działa lub jest niedostępny',
    },
    'connection_timeout': {
      'en': 'Connection timeout - Backend is taking too long to respond',
      'pl': 'Timeout połączenia - Backend zbyt długo nie odpowiada',
    },
    'invalid_backend_url': {
      'en': 'Invalid backend URL: ',
      'pl': 'Błędny adres backendu: ',
    },
    'network_error': {
      'en': 'Network error - Check your internet connection',
      'pl': 'Błąd sieciowy - Sprawdź swoje połączenie internetowe',
    },
  };

  IrcService({String? server, int? port, String? channel, String? backendUrl})
    : server = server ?? 'slaugh.pl',
      port = port ?? 6667,
      channel = channel ?? '#vorest',
      backendUrl = backendUrl ?? 'ws://localhost:8000/ws' {
    _encryptionService = EncryptionService(debugMode: debugMode);
  }

  String get nickname => _nickname ?? '';

  // Get translated message
  String _t(String key, {String? suffix}) {
    final locale = kIsWeb ? 'en' : Platform.localeName.toLowerCase();
    final isPolish = locale.startsWith('pl');
    final lang = isPolish ? 'pl' : 'en';
    final translation =
        _translations[key]?[lang] ?? _translations[key]?['en'] ?? key;
    return suffix != null ? '$translation $suffix' : translation;
  }

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
  /// Returns true if the user has active encryption sessions (is a Frontend user)
  /// Returns false if the user is a regular IRC user
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

  Future<void> connect({String? customNickname}) async {
    // Wrap entire connection in a zone with error handler
    // to catch any async exceptions that might escape
    await runZoned(
      () async {
        try {
          _connectionStateController.add(IrcConnectionState.connecting);
          _addSystemMessage('${_t('connecting')} $backendUrl...');

          // Validate URL format
          try {
            Uri.parse(backendUrl);
          } catch (e) {
            _isConnected = false;
            _connectionStateController.add(IrcConnectionState.error);
            _addSystemMessage('${_t('invalid_backend_url')}$backendUrl');
            return;
          }

          // Connect to backend WebSocket with timeout
          WebSocketChannel? channel;
          try {
            // Use timeout to catch connection refused errors early
            channel =
                await Future.value(
                  WebSocketChannel.connect(Uri.parse(backendUrl)),
                ).timeout(
                  const Duration(seconds: 5),
                  onTimeout: () {
                    throw TimeoutException(
                      'WebSocket connection timeout',
                      const Duration(seconds: 5),
                    );
                  },
                );
          } catch (e) {
            _isConnected = false;
            _connectionStateController.add(IrcConnectionState.error);
            _handleConnectionError(e);
            return;
          }

          // IMPORTANT: Attach listener IMMEDIATELY to catch any connection errors
          // This must be done BEFORE setting _isConnected = true
          try {
            channel.stream.listen(
              (data) {
                try {
                  _handleBackendMessage(data);
                } catch (e, stackTrace) {
                  debugPrint('Error handling backend message: $e\n$stackTrace');
                }
              },
              onError: (dynamic error, StackTrace? stackTrace) {
                // This callback MUST NOT throw any exceptions
                try {
                  debugPrint(
                    'WebSocket stream error: $error\nStackTrace: $stackTrace',
                  );

                  // Attempt to mark as disconnected
                  try {
                    _isConnected = false;
                  } catch (_) {}

                  // Attempt to add error state
                  try {
                    if (!_connectionStateController.isClosed) {
                      _connectionStateController.add(IrcConnectionState.error);
                    }
                  } catch (_) {}

                  // Attempt to show error message
                  try {
                    _handleConnectionError(error);
                  } catch (_) {}
                } catch (e) {
                  // If anything goes wrong, just log it and move on
                  debugPrint('Error in onError handler: $e');
                }
              },
              onDone: () {
                try {
                  _isConnected = false;
                  _addSystemMessage(_t('disconnected'));
                  if (!_connectionStateController.isClosed) {
                    _connectionStateController.add(
                      IrcConnectionState.disconnected,
                    );
                  }
                } catch (e) {
                  debugPrint('Error in onDone handler: $e');
                }
              },
              cancelOnError:
                  false, // Continue listening even if there's an error
            );
          } catch (e, stackTrace) {
            // Catch any errors during listener attachment
            try {
              _isConnected = false;
              if (!_connectionStateController.isClosed) {
                _connectionStateController.add(IrcConnectionState.error);
              }
              _handleConnectionError(e);
              debugPrint('Error attaching WebSocket listener: $e\n$stackTrace');
            } catch (e2) {
              debugPrint('Error in error handler: $e2');
            }
            return;
          }

          // Now that listener is attached, mark as connected
          _channel = channel;
          _isConnected = true;
          _connectionStateController.add(IrcConnectionState.joiningChannel);

          // Generate nickname
          _nickname = customNickname ?? generateFriendlyNickname();
          _addSystemMessage('${_t('using_nickname')} $_nickname');

          // Register this Frontend user for encryption
          final deviceId = _encryptionService.registerUser(_nickname!);
          if (debugMode) {
            _addSystemMessage('Registered for encrypted messaging: $deviceId');
          }

          // Send connect command to backend
          // is_frontend_user: true indicates this is a Frontend user supporting encryption
          _sendToBackend({
            'type': 'connect',
            'nickname': _nickname,
            'is_frontend_user': true,
          });

          _addSystemMessage(_t('sent_auth'));
        } catch (e, stackTrace) {
          _isConnected = false;
          _connectionStateController.add(IrcConnectionState.error);
          _handleConnectionError(e);
          debugPrint('Connection error: $e\n$stackTrace');
        }
      },
      onError: (dynamic error, StackTrace stackTrace) {
        // Zone-level error handler - catches any async errors that escape
        debugPrint('Zone error caught: $error\nStackTrace: $stackTrace');
        try {
          _isConnected = false;
          if (!_connectionStateController.isClosed) {
            _connectionStateController.add(IrcConnectionState.error);
          }
          _handleConnectionError(error);
        } catch (e) {
          debugPrint('Error in zone error handler: $e');
        }
      },
    );
  }

  /// Handle and display user-friendly connection error messages
  void _handleConnectionError(dynamic error) {
    try {
      String errorMessage = _t('connection_error');

      final errorStr = error.toString().toLowerCase();

      if (errorStr.contains('connection refused')) {
        errorMessage = _t('connection_refused');
      } else if (errorStr.contains('timeout') ||
          errorStr.contains('timed out')) {
        errorMessage = _t('connection_timeout');
      } else if (errorStr.contains('network') ||
          errorStr.contains('unreachable') ||
          errorStr.contains('no route')) {
        errorMessage = _t('network_error');
      } else if (errorStr.contains('socket') || errorStr.contains('errno')) {
        // Parse socket errors for more details
        errorMessage = 'Connection failed: $error';
      }

      _addSystemMessage(errorMessage);
    } catch (e) {
      debugPrint('Error handling connection error: $e');
    }
  }

  void _onMessageReceived(String data) {
    _handleBackendMessage(data);
  }

  Future<void> _handleBackendMessage(dynamic data) async {
    try {
      final message = jsonDecode(data);
      final type = message['type'];

      if (debugMode) {
        _addSystemMessage('[RECV] $type: ${message['content'] ?? ''}');
      }

      switch (type) {
        case 'connected':
          _addSystemMessage(message['content'] ?? 'Connected to backend');
          break;

        case 'system':
          _addSystemMessage(message['content'] ?? '');
          break;

        case 'message':
          var content = message['content'] ?? '';
          final isEncrypted = message['is_encrypted'] ?? false;
          final sender = message['sender'] ?? 'Unknown';
          final target = message['target'] ?? channel;
          final isPrivate = message['is_private'] ?? false;

          // If message is encrypted, try to decrypt it
          if (isEncrypted && isPrivate && _nickname != null) {
            final encryptedData = message['encrypted_data'];
            if (encryptedData != null) {
              // Try to decrypt with existing session
              var decrypted = _encryptionService.decryptMessage(
                sender,
                _nickname!,
                encryptedData,
              );

              // If decryption failed (no session), request session key from backend
              if (decrypted == null) {
                if (debugMode) {
                  _addSystemMessage(
                    '[Encryption] No session with $sender - requesting session key...',
                  );
                }

                // Request session key from backend
                _sendToBackend({'type': 'get_session_key', 'from': sender});

                // Retry decryption multiple times with delays
                // Total wait time: (100ms + 150ms) * 10 = 2.5 seconds for first message
                // This ensures Backend has time to establish session and send key
                for (int retry = 0; retry < 10; retry++) {
                  // Longer initial wait for first message, shorter for retries
                  final delay = retry == 0
                      ? const Duration(milliseconds: 100)
                      : const Duration(milliseconds: 150);

                  await Future.delayed(delay);
                  decrypted = _encryptionService.decryptMessage(
                    sender,
                    _nickname!,
                    encryptedData,
                  );
                  if (decrypted != null) {
                    if (debugMode) {
                      _addSystemMessage(
                        '[Encryption] Session key received after retry $retry',
                      );
                    }
                    break;
                  }
                }
              }

              if (decrypted != null) {
                content = decrypted;
                if (debugMode) {
                  _addSystemMessage(
                    '[Encryption] Decrypted message from $sender',
                  );
                }
              } else {
                if (debugMode) {
                  _addSystemMessage(
                    '[Encryption] Failed to decrypt message from $sender - saving encrypted',
                  );
                }
                content = '[Encrypted message - unable to decrypt]';
              }
            }
          }

          _messageController.add(
            IrcMessage(
              sender: sender,
              content: content,
              target: target,
              timestamp: DateTime.now(),
              isPrivate: isPrivate,
              isEncrypted: isEncrypted && isPrivate,
            ),
          );
          break;

        case 'users':
          final users = (message['users'] as List?)?.cast<String>() ?? [];
          _channelUsers.clear();
          _channelUsers.addAll(users);
          _usersController.add(List.from(_channelUsers));

          if (users.isNotEmpty) {
            final usersList = users.join(', ');
            _addSystemMessage('${_t('active_users')} $usersList');
          }

          // Mark as fully connected
          _connectionStateController.add(IrcConnectionState.connected);
          _addSystemMessage(_t('joined_channel'));
          break;

        case 'join':
          final user = message['user'];
          if (user != null && !_channelUsers.contains(user)) {
            _channelUsers.add(user);
            _usersController.add(List.from(_channelUsers));
            _addSystemMessage('$user ${_t('joined')}');
          }
          break;

        case 'setup_encryption':
          // Backend instructing this client to setup encryption with specific users
          final users = message['users'] as List<dynamic>?;
          if (users != null && _nickname != null) {
            if (debugMode) {
              _addSystemMessage(
                '[Encryption] Backend instructing to setup encryption with: ${users.join(", ")}',
              );
            }

            // Establish local encryption sessions for each user
            for (final user in users) {
              final userName = user as String;
              _encryptionService.establishSession(_nickname!, userName);

              // Notify Backend that we've established our local session
              _sendToBackend({
                'type': 'encryption_session_ready',
                'with': userName,
              });

              if (debugMode) {
                _addSystemMessage(
                  '[Encryption] Established local session with $userName',
                );
              }
            }
          }
          break;

        case 'session_key':
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
              _encryptionService.sessionKeys[sessionKey] = key;

              if (debugMode) {
                _addSystemMessage(
                  '[Encryption] Received session key from $from',
                );
              }
            } catch (e) {
              if (debugMode) {
                _addSystemMessage(
                  '[Encryption] Failed to process session key from $from: $e',
                );
              }
            }
          }
          break;

        case 'part':
        case 'quit':
          final user = message['user'];
          if (user != null) {
            _channelUsers.remove(user);
            _usersController.add(List.from(_channelUsers));
            final action = type == 'part' ? _t('left') : _t('quit');
            _addSystemMessage('$user $action');
          }
          break;

        case 'error':
          _addSystemMessage('Error: ${message['content']}');
          break;

        case 'disconnected':
          _isConnected = false;
          _connectionStateController.add(IrcConnectionState.disconnected);
          _addSystemMessage(_t('disconnected'));
          break;
      }
    } catch (e) {
      debugPrint('Error handling backend message: $e');
    }
  }

  void _sendToBackend(Map<String, dynamic> data) {
    if (_channel != null && _isConnected) {
      try {
        _channel!.sink.add(jsonEncode(data));
        if (debugMode) {
          _addSystemMessage('[SEND] ${data['type']}: ${data['content'] ?? ''}');
        }
      } catch (e) {
        debugPrint('Error sending to backend: $e');
      }
    }
  }

  Future<void> sendMessage(String message, {String? target}) async {
    if (!_isConnected || _nickname == null) return;

    var recipient = target ?? channel;

    // Remove @ prefix if present (IRC doesn't accept @ in nicknames)
    if (recipient.startsWith('@')) {
      recipient = recipient.substring(1);
    }

    // Check if this is a private message (not to channel)
    final isPrivateMessage = recipient != channel;

    if (isPrivateMessage) {
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
          // Send encrypted
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
          // Message encrypt failed - don't send
          debugPrint(
            '[IrcService] Encryption failed for message to $recipient',
          );
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

  Future<void> sendPrivateMessage(String recipient, String message) async {
    await sendMessage(message, target: recipient);
  }

  void establishSessionWithUser(String otherUser) {
    if (_nickname != null) {
      _encryptionService.establishSession(_nickname!, otherUser);
      _sendToBackend({'type': 'establish_session', 'other_user': otherUser});
    }
  }

  void disconnect() {
    if (!_isConnected) return;

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

    try {
      _channel?.sink.close();
    } catch (e) {
      debugPrint('Error closing WebSocket sink: $e');
    }

    _channel = null;
    _isConnected = false;
    _channelUsers.clear();
    _usersController.add([]);
    _connectionStateController.add(IrcConnectionState.disconnected);
    _addSystemMessage(_t('disconnected'));
  }

  void startKeepaliveTimer() {
    stopKeepaliveTimer();
    _keepaliveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected && _channel != null) {
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

enum IrcConnectionState {
  disconnected,
  connecting,
  joiningChannel,
  connected,
  error,
}
