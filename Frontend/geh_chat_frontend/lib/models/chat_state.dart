import 'package:flutter/material.dart';
import 'dart:async';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/irc_service.dart';
import '../services/notification_service.dart';
import '../services/foreground_service_manager.dart';
import '../services/connection_settings_service.dart';

class ChatState extends ChangeNotifier {
  final IrcService _ircService;
  final NotificationService _notificationService = NotificationService();
  final List<IrcMessage> _channelMessages = [];
  final Map<String, List<IrcMessage>> _privateChats = {};
  final Map<String, int> _unreadCounts =
      {}; // Tracks unread message count per chat
  List<String> _users = [];
  IrcConnectionState _connectionState = IrcConnectionState.disconnected;
  Timer? _reconnectTimer;
  bool _shouldAutoReconnect = false;
  bool _wasConnected = false;
  String? _activeChat; // null = main channel, username = private chat
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  bool _disposed = false;

  ChatState(this._ircService) {
    _ircService.messages.listen(_handleMessage);
    _ircService.users.listen(_handleUsers);
    _ircService.connectionState.listen(_handleConnectionState);
  }

  // Public method for auto-reconnecting with saved settings
  Future<bool> tryAutoConnect() async {
    try {
      final savedSettings = await ConnectionSettingsService.loadSettings();
      
      if (savedSettings != null) {
        debugPrint('Auto-connecting with saved settings: ${savedSettings.server}:${savedSettings.port} #${savedSettings.channel} as ${savedSettings.nickname}');
        
        // Connect automatically in background
        await connectWithSettings(
          server: savedSettings.server,
          port: savedSettings.port,
          channel: savedSettings.channel,
          nickname: savedSettings.nickname,
          debugMode: false,
        );
        
        debugPrint('Auto-connect successful!');
        return true;
      } else {
        debugPrint('No saved settings found - waiting for manual connection');
        return false;
      }
    } catch (e) {
      debugPrint('Auto-connect failed: $e');
      return false;
    }
  }

  List<IrcMessage> get channelMessages => _channelMessages;
  Map<String, List<IrcMessage>> get privateChats => _privateChats;
  Map<String, int> get unreadCounts => _unreadCounts;
  List<String> get users => _users;
  IrcConnectionState get connectionState => _connectionState;
  String get nickname => _ircService.nickname;
  String get channel => _ircService.channel;
  String? get activeChat => _activeChat;

  void setAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
  }

  void _handleMessage(IrcMessage message) {
    if (message.isSystem) {
      // System messages always go to channel
      _channelMessages.add(message);
    } else if (message.isPrivate) {
      // For private messages, use the other person's nickname as the key
      final chatKey = message.sender == _ircService.nickname
          ? message.target
          : message.sender;

      if (!_privateChats.containsKey(chatKey)) {
        _privateChats[chatKey] = [];
      }
      _privateChats[chatKey]!.add(message);

      // Increment unread count for messages from others
      if (message.sender != _ircService.nickname) {
        // Show notification if: app is in background OR user is on different chat
        final isAppInForeground = _appLifecycleState == AppLifecycleState.resumed;
        final shouldNotify = !isAppInForeground || _activeChat != chatKey;
        
        if (shouldNotify) {
          _unreadCounts[chatKey] = (_unreadCounts[chatKey] ?? 0) + 1;

          _notificationService.showMessageNotification(
            sender: message.sender,
            message: message.content,
            isPrivate: true,
          );
        } else if (_activeChat == chatKey) {
          // User is viewing this chat - mark as read immediately
          _unreadCounts[chatKey] = 0;
        }
      }
    } else {
      _channelMessages.add(message);

      // Show notification for channel messages from others
      // If app is in background OR user is on different chat (private chat)
      if (message.sender != _ircService.nickname) {
        final isAppInForeground = _appLifecycleState == AppLifecycleState.resumed;
        final shouldNotify = !isAppInForeground || _activeChat != null;
        
        if (shouldNotify) {
          _notificationService.showMessageNotification(
            sender: message.sender,
            message: message.content,
            isPrivate: false,
          );
        }
      }
    }
    notifyListeners();
  }

  void _handleUsers(List<String> users) {
    _users = users;
    notifyListeners();
  }

  void _handleConnectionState(IrcConnectionState state) {
    _connectionState = state;

    // Show/hide persistent notification based on connection state
    if (state == IrcConnectionState.connected) {
      _wasConnected = true;
      _shouldAutoReconnect = true;
      _stopReconnectTimer();
      _notificationService.showPersistentNotification();
    } else if (state == IrcConnectionState.disconnected ||
        state == IrcConnectionState.error) {
      _notificationService.hidePersistentNotification();
      // Connection lost - no auto-reconnect
    }

    notifyListeners();
  }

  void _startReconnectTimer() {
    _stopReconnectTimer();
    debugPrint('Starting auto-reconnect timer...');
    _reconnectTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_connectionState != IrcConnectionState.connected &&
          _connectionState != IrcConnectionState.connecting &&
          _connectionState != IrcConnectionState.joiningChannel) {
        debugPrint('Attempting to reconnect...');
        try {
          await _ircService.connect();
        } catch (e) {
          debugPrint('Reconnect attempt failed: $e');
        }
      }
    });
  }

  void _stopReconnectTimer() {
    if (_reconnectTimer != null) {
      debugPrint('Stopping auto-reconnect timer');
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    }
  }

  Future<void> connect() async {
    await _ircService.connect();
  }

  Future<void> connectWithSettings({
    required String server,
    required int port,
    required String channel,
    required String nickname,
    bool debugMode = false,
  }) async {
    _ircService.updateSettings(
      newServer: server,
      newPort: port,
      newChannel: channel,
    );
    _ircService.debugMode = debugMode;
    await _ircService.connect(customNickname: nickname);
  }

  String generateRandomNickname() {
    return _ircService.generateRandomNickname();
  }

  void sendChannelMessage(String message) {
    _ircService.sendMessage(message);
  }

  void sendPrivateMessage(String recipient, String message) {
    _ircService.sendPrivateMessage(recipient, message);
  }

  void startPrivateChat(String username) {
    if (!_privateChats.containsKey(username)) {
      _privateChats[username] = [];
      notifyListeners();
    }
  }

  void markAsRead(String username) {
    _unreadCounts[username] = 0;
    notifyListeners();
  }

  void setActiveChat(String? chat) {
    _activeChat = chat;
    // Mark as read when opening chat
    if (chat != null) {
      _unreadCounts[chat] = 0;
    }
    // Use scheduleMicrotask to avoid calling notifyListeners during widget disposal
    Future.microtask(() {
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  int getUnreadChatsCount() {
    return _unreadCounts.values.where((count) => count > 0).length;
  }

  void disconnect() {
    _shouldAutoReconnect = false;
    _wasConnected = false;
    _stopReconnectTimer();
    _ircService.disconnect();
    _notificationService.hidePersistentNotification();
    
    // Clear saved settings on manual disconnect
    ConnectionSettingsService.clearSettings();
    debugPrint('Connection settings cleared');
    
    _channelMessages.clear();
    _privateChats.clear();
    _unreadCounts.clear();
    _users.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    // Mark as disposed to prevent further notifyListeners calls
    _disposed = true;
    // Clean up everything when ChatState is disposed
    _stopReconnectTimer();
    _ircService.disconnect();
    _notificationService.hidePersistentNotification();
    debugPrint('ChatState disposed - app closing');
    super.dispose();
  }
}
