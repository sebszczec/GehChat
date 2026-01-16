import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'irc_service.dart';
import 'irc_translations.dart';

/// Handles WebSocket connection lifecycle for IrcService
/// Responsible for connecting, error handling, and stream management
class IrcConnectionManager {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  final bool Function() getDebugMode;
  final void Function(IrcConnectionState) updateConnectionState;
  final void Function(String) addSystemMessage;
  final void Function(dynamic) onMessageReceived;

  IrcConnectionManager({
    required this.getDebugMode,
    required this.updateConnectionState,
    required this.addSystemMessage,
    required this.onMessageReceived,
  });

  /// Get the WebSocket channel
  WebSocketChannel? get channel => _channel;

  /// Check if connected
  bool get isConnected => _isConnected;

  /// Set connection status
  set isConnected(bool value) => _isConnected = value;

  /// Check if current locale is Polish
  bool get _isPolish {
    final locale = kIsWeb ? 'en' : Platform.localeName.toLowerCase();
    return locale.startsWith('pl');
  }

  /// Connect to backend WebSocket
  Future<bool> connect(String backendUrl) async {
    try {
      updateConnectionState(IrcConnectionState.connecting);
      addSystemMessage(
        '${IrcTranslations.get('connecting', isPolish: _isPolish)} $backendUrl...',
      );

      // Validate URL format
      try {
        Uri.parse(backendUrl);
      } catch (e) {
        _isConnected = false;
        updateConnectionState(IrcConnectionState.error);
        addSystemMessage(
          '${IrcTranslations.get('invalid_backend_url', isPolish: _isPolish)}$backendUrl',
        );
        return false;
      }

      // Connect to backend WebSocket with timeout
      WebSocketChannel? newChannel;
      try {
        // Use timeout to catch connection refused errors early
        // 15 seconds for slower mobile networks (Android emulator: 10.0.2.2)
        newChannel =
            await Future.value(
              WebSocketChannel.connect(Uri.parse(backendUrl)),
            ).timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException(
                  'WebSocket connection timeout',
                  const Duration(seconds: 15),
                );
              },
            );
      } catch (e) {
        _isConnected = false;
        updateConnectionState(IrcConnectionState.error);
        _handleConnectionError(e);
        return false;
      }

      // Attach stream listener
      if (!_attachStreamListener(newChannel)) {
        return false;
      }

      _channel = newChannel;
      _isConnected = true;
      updateConnectionState(IrcConnectionState.joiningChannel);
      return true;
    } catch (e, stackTrace) {
      _isConnected = false;
      updateConnectionState(IrcConnectionState.error);
      _handleConnectionError(e);
      debugPrint('Connection error: $e\n$stackTrace');
      return false;
    }
  }

  /// Attach listener to WebSocket stream
  bool _attachStreamListener(WebSocketChannel channel) {
    try {
      channel.stream.listen(
        (data) {
          try {
            onMessageReceived(data);
          } catch (e, stackTrace) {
            debugPrint('Error handling backend message: $e\n$stackTrace');
          }
        },
        onError: (dynamic error, StackTrace? stackTrace) {
          _handleStreamError(error, stackTrace);
        },
        onDone: () {
          _handleStreamDone();
        },
        cancelOnError: false,
      );
      return true;
    } catch (e, stackTrace) {
      _isConnected = false;
      updateConnectionState(IrcConnectionState.error);
      _handleConnectionError(e);
      debugPrint('Error attaching WebSocket listener: $e\n$stackTrace');
      return false;
    }
  }

  /// Handle stream errors
  void _handleStreamError(dynamic error, StackTrace? stackTrace) {
    try {
      debugPrint('WebSocket stream error: $error\nStackTrace: $stackTrace');

      try {
        _isConnected = false;
      } catch (_) {}

      try {
        updateConnectionState(IrcConnectionState.error);
      } catch (_) {}

      try {
        _handleConnectionError(error);
      } catch (_) {}
    } catch (e) {
      debugPrint('Error in onError handler: $e');
    }
  }

  /// Handle stream completion
  void _handleStreamDone() {
    try {
      _isConnected = false;
      addSystemMessage(
        IrcTranslations.get('disconnected', isPolish: _isPolish),
      );
      updateConnectionState(IrcConnectionState.disconnected);
    } catch (e) {
      debugPrint('Error in onDone handler: $e');
    }
  }

  /// Handle and display user-friendly connection error messages
  void _handleConnectionError(dynamic error) {
    try {
      String errorMessage = IrcTranslations.get(
        'connection_error',
        isPolish: _isPolish,
      );

      final errorStr = error.toString().toLowerCase();

      if (errorStr.contains('connection refused')) {
        errorMessage = IrcTranslations.get(
          'connection_refused',
          isPolish: _isPolish,
        );
      } else if (errorStr.contains('timeout') ||
          errorStr.contains('timed out')) {
        errorMessage = IrcTranslations.get(
          'connection_timeout',
          isPolish: _isPolish,
        );
      } else if (errorStr.contains('network') ||
          errorStr.contains('unreachable') ||
          errorStr.contains('no route')) {
        errorMessage = IrcTranslations.get(
          'network_error',
          isPolish: _isPolish,
        );
      } else if (errorStr.contains('socket') || errorStr.contains('errno')) {
        // Parse socket errors for more details
        errorMessage = 'Connection failed: $error';
      }

      addSystemMessage(errorMessage);
    } catch (e) {
      debugPrint('Error handling connection error: $e');
    }
  }

  /// Disconnect from backend
  void disconnect() {
    try {
      _channel?.sink.close();
    } catch (e) {
      debugPrint('Error closing WebSocket sink: $e');
    }

    _channel = null;
    _isConnected = false;
  }

  /// Send data to backend
  void send(String data) {
    if (_channel != null && _isConnected) {
      try {
        _channel!.sink.add(data);
      } catch (e) {
        debugPrint('Error sending to backend: $e');
      }
    }
  }
}
