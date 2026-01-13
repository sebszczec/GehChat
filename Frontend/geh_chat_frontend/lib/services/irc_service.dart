import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class IrcService {
  WebSocketChannel? _channel;
  Timer? _keepaliveTimer;
  String server;
  int port;
  String? _nickname;
  String channel;

  // Backend WebSocket URL
  String backendUrl;

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
  };

  IrcService({String? server, int? port, String? channel, String? backendUrl})
    : server = server ?? 'slaugh.pl',
      port = port ?? 6667,
      channel = channel ?? '#vorest',
      backendUrl = backendUrl ?? 'ws://localhost:8000/ws';

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
  }

  void _addSystemMessage(String content) {
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

  Future<void> connect({String? customNickname}) async {
    try {
      _connectionStateController.add(IrcConnectionState.connecting);
      _addSystemMessage('${_t('connecting')} $backendUrl...');

      // Connect to backend WebSocket
      _channel = WebSocketChannel.connect(Uri.parse(backendUrl));

      _isConnected = true;
      _connectionStateController.add(IrcConnectionState.joiningChannel);

      // Generate nickname
      _nickname = customNickname ?? _generateFriendlyNickname();
      _addSystemMessage('${_t('using_nickname')} $_nickname');

      // Listen to backend messages
      _channel!.stream.listen(
        _handleBackendMessage,
        onError: (error) {
          _isConnected = false;
          _addSystemMessage(_t('connection_error'));
          _connectionStateController.add(IrcConnectionState.error);
          _messageController.addError(error);
        },
        onDone: () {
          _isConnected = false;
          _addSystemMessage(_t('disconnected'));
          _connectionStateController.add(IrcConnectionState.disconnected);
        },
      );

      // Send connect command to backend
      // Only nickname is sent - IRC server config comes from backend
      _sendToBackend({'type': 'connect', 'nickname': _nickname});

      _addSystemMessage(_t('sent_auth'));
    } catch (e) {
      _isConnected = false;
      _connectionStateController.add(IrcConnectionState.error);
      _addSystemMessage('Connection failed: $e');
      rethrow;
    }
  }

  void _handleBackendMessage(dynamic data) {
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
          _messageController.add(
            IrcMessage(
              sender: message['sender'] ?? 'Unknown',
              content: message['content'] ?? '',
              target: message['target'] ?? channel,
              timestamp: DateTime.now(),
              isPrivate: message['is_private'] ?? false,
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

  void sendMessage(String message, {String? target}) {
    if (!_isConnected) return;

    var recipient = target ?? channel;

    // Remove @ prefix if present (IRC doesn't accept @ in nicknames)
    if (recipient.startsWith('@')) {
      recipient = recipient.substring(1);
    }

    _sendToBackend({
      'type': 'message',
      'target': recipient,
      'content': message,
    });
  }

  void sendPrivateMessage(String recipient, String message) {
    sendMessage(message, target: recipient);
  }

  void requestUserList() {
    // User list is automatically received from backend
  }

  void disconnect() {
    if (!_isConnected) return;

    _sendToBackend({'type': 'disconnect'});

    _stopKeepaliveTimer();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _channelUsers.clear();
    _usersController.add([]);
    _connectionStateController.add(IrcConnectionState.disconnected);
    _addSystemMessage(_t('disconnected'));
  }

  void _startKeepaliveTimer() {
    _stopKeepaliveTimer();
    _keepaliveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected && _channel != null) {
        _sendToBackend({'type': 'ping'});
        debugPrint('Sent keepalive PING');
      }
    });
  }

  void _stopKeepaliveTimer() {
    _keepaliveTimer?.cancel();
    _keepaliveTimer = null;
  }

  String _generateFriendlyNickname() {
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
    return _generateFriendlyNickname();
  }

  void dispose() {
    disconnect();
    _stopKeepaliveTimer();
    _messageController.close();
    _usersController.close();
    _connectionStateController.close();
  }
}

class IrcMessage {
  final String sender;
  final String content;
  final String target;
  final DateTime timestamp;
  final bool isPrivate;
  final bool isSystem;

  IrcMessage({
    required this.sender,
    required this.content,
    required this.target,
    required this.timestamp,
    this.isPrivate = false,
    this.isSystem = false,
  });
}

enum IrcConnectionState {
  disconnected,
  connecting,
  joiningChannel,
  connected,
  error,
}
