import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';

class IrcService {
  Socket? _socket;
  Timer? _keepaliveTimer;
  String server;
  int port;
  String? _nickname;
  String channel;

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

  IrcService({String? server, int? port, String? channel})
    : server = server ?? 'slaugh.pl',
      port = port ?? 6667,
      channel = channel ?? '#vorest';

  String get nickname => _nickname ?? '';

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
      _addSystemMessage('Connecting to $server:$port...');

      _socket = await Socket.connect(server, port);
      
      // Enable TCP keepalive to prevent connection from being killed in background
      _socket!.setOption(SocketOption.tcpNoDelay, true);
      
      _isConnected = true;
      _connectionStateController.add(IrcConnectionState.joiningChannel);
      _addSystemMessage('Connected to server!');

      // Start keepalive timer - send PING every 30 seconds
      _startKeepaliveTimer();

      // Generate random friendly nickname if not provided
      _nickname = customNickname ?? _generateFriendlyNickname();
      _addSystemMessage('Using nickname: $_nickname');

      // Send IRC handshake
      _sendRaw('NICK $_nickname');
      _sendRaw('USER $_nickname 0 * :$_nickname');
      _addSystemMessage('Sent authentication to server...');

      // Listen to server messages
      _socket!.listen(
        _handleServerData,
        onError: (error) {
          _isConnected = false;
          _connectionStateController.add(IrcConnectionState.error);
          _messageController.addError(error);
        },
        onDone: () {
          _isConnected = false;
          _connectionStateController.add(IrcConnectionState.disconnected);
        },
      );

      // Channel join will happen after MOTD ends (376 or 422)
    } catch (e) {
      _isConnected = false;
      _connectionStateController.add(IrcConnectionState.error);
      rethrow;
    }
  }

  void joinChannel() {
    if (_isConnected) {
      _addSystemMessage('Joining channel $channel...');
      _sendRaw('JOIN $channel');
    }
  }

  void sendMessage(String message, {String? target}) {
    if (!_isConnected) return;

    final recipient = target ?? channel;
    _sendRaw('PRIVMSG $recipient :$message');

    // Add own message to stream
    _messageController.add(
      IrcMessage(
        sender: _nickname!,
        content: message,
        target: recipient,
        timestamp: DateTime.now(),
        isPrivate: target != null && target != channel,
      ),
    );
  }

  void sendPrivateMessage(String recipient, String message) {
    sendMessage(message, target: recipient);
  }

  void requestUserList() {
    if (_isConnected) {
      _sendRaw('NAMES $channel');
    }
  }

  void _sendRaw(String message) {
    if (_socket != null) {
      _socket!.write('$message\r\n');
      if (debugMode) {
        _addSystemMessage('[SEND] $message');
      }
    }
  }

  void _startKeepaliveTimer() {
    _stopKeepaliveTimer();
    _keepaliveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected && _socket != null) {
        _sendRaw('PING :keepalive');
        debugPrint('Sent keepalive PING');
      }
    });
  }

  void _stopKeepaliveTimer() {
    _keepaliveTimer?.cancel();
    _keepaliveTimer = null;
  }

  void _handleServerData(List<int> data) {
    final message = utf8.decode(data).trim();
    final lines = message.split('\r\n');

    for (var line in lines) {
      if (line.isEmpty) continue;
      _processIrcLine(line);
    }
  }

  void _processIrcLine(String line) {
    if (debugMode) {
      _addSystemMessage('[RECV] $line');
    }

    // Handle PING
    if (line.startsWith('PING')) {
      final server = line.substring(5);
      _sendRaw('PONG $server');
      return;
    }

    // Parse IRC message
    final parts = line.split(' ');
    if (parts.length < 2) return;

    final command = parts[1];

    switch (command) {
      case '376': // RPL_ENDOFMOTD
      case '422': // ERR_NOMOTD
        // MOTD ended, now join the channel
        _addSystemMessage('Received end of MOTD, joining channel...');
        joinChannel();
        break;
      case 'PRIVMSG':
        _handlePrivMsg(line);
        break;
      case '353': // NAMES reply
        _handleNamesReply(line);
        break;
      case '366': // End of NAMES
        _usersController.add(List.from(_channelUsers));
        // Now we're truly connected and on the channel
        _connectionStateController.add(IrcConnectionState.connected);
        _addSystemMessage('Successfully joined channel!');
        break;
      case 'JOIN':
        _handleJoin(line);
        break;
      case 'PART':
      case 'QUIT':
        _handlePartOrQuit(line);
        break;
      case 'NICK':
        _handleNickChange(line);
        break;
    }
  }

  void _handlePrivMsg(String line) {
    // Format: :nick!user@host PRIVMSG target :message
    final senderMatch = RegExp(r'^:([^!]+)').firstMatch(line);
    if (senderMatch == null) return;

    final sender = senderMatch.group(1)!;
    final parts = line.split(' ');
    if (parts.length < 4) return;

    final target = parts[2];
    final messageStart = line.indexOf(':', 1) + 1;
    if (messageStart <= 0 || messageStart >= line.length) return;

    final content = line.substring(messageStart);
    final isPrivate = target == _nickname;

    _messageController.add(
      IrcMessage(
        sender: sender,
        content: content,
        target: isPrivate ? sender : target,
        timestamp: DateTime.now(),
        isPrivate: isPrivate,
      ),
    );
  }

  void _handleNamesReply(String line) {
    // Format: :server 353 nick = #channel :nick1 nick2 nick3
    final parts = line.split(':');
    if (parts.length < 3) return;

    final users = parts[2].split(' ');
    for (var user in users) {
      final cleanUser = user.replaceAll(RegExp(r'^[@+]'), '').trim();
      if (cleanUser.isNotEmpty && !_channelUsers.contains(cleanUser)) {
        _channelUsers.add(cleanUser);
      }
    }
  }

  void _handleJoin(String line) {
    final nickMatch = RegExp(r'^:([^!]+)').firstMatch(line);
    if (nickMatch != null) {
      final nick = nickMatch.group(1)!;
      if (!_channelUsers.contains(nick)) {
        _channelUsers.add(nick);
        _usersController.add(List.from(_channelUsers));
      }
      // If it's our own join, request the full user list
      if (nick == _nickname) {
        _addSystemMessage('Successfully joined $channel!');
        requestUserList();
      }
    }
  }

  void _handlePartOrQuit(String line) {
    final nickMatch = RegExp(r'^:([^!]+)').firstMatch(line);
    if (nickMatch != null) {
      final nick = nickMatch.group(1)!;
      _channelUsers.remove(nick);
      _usersController.add(List.from(_channelUsers));
    }
  }

  void _handleNickChange(String line) {
    // Format: :oldnick!user@host NICK :newnick
    final oldNickMatch = RegExp(r'^:([^!]+)').firstMatch(line);
    final newNickMatch = RegExp(r'NICK :(.+)').firstMatch(line);

    if (oldNickMatch != null && newNickMatch != null) {
      final oldNick = oldNickMatch.group(1)!;
      final newNick = newNickMatch.group(1)!;

      final index = _channelUsers.indexOf(oldNick);
      if (index != -1) {
        _channelUsers[index] = newNick;
        _usersController.add(List.from(_channelUsers));
      }
    }
  }

  String generateRandomNickname() {
    return _generateFriendlyNickname();
  }

  String _generateFriendlyNickname() {
    final adjectives = [
      'Happy',
      'Sunny',
      'Bright',
      'Swift',
      'Clever',
      'Gentle',
      'Brave',
      'Calm',
      'Lucky',
      'Wise',
      'Noble',
      'Kind',
      'Bold',
      'Quick',
      'Smart',
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
      'Panda',
      'Deer',
      'Falcon',
      'Raven',
      'Dragon',
      'Phoenix',
      'Lynx',
    ];

    final random = Random();
    final adjective = adjectives[random.nextInt(adjectives.length)];
    final noun = nouns[random.nextInt(nouns.length)];
    final number = random.nextInt(1000);

    return '$adjective$noun$number';
  }

  void disconnect() {
    if (_isConnected) {
      _stopKeepaliveTimer();
      _sendRaw('QUIT :Goodbye!');
      _socket?.close();
      _isConnected = false;
      _channelUsers.clear();
      _connectionStateController.add(IrcConnectionState.disconnected);
    }
  }

  void dispose() {
    _stopKeepaliveTimer();
    disconnect();
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
    required this.isPrivate,
    this.isSystem = false,
  });
}

enum IrcConnectionState { disconnected, connecting, joiningChannel, connected, error }
