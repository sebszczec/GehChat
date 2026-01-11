import 'package:flutter/services.dart';

class ForegroundServiceManager {
  static const MethodChannel _channel =
      MethodChannel('com.example.geh_chat_frontend/service');

  static Future<void> startForegroundService() async {
    try {
      await _channel.invokeMethod('startForegroundService');
    } catch (e) {
      print('Failed to start foreground service: $e');
    }
  }

  static Future<void> stopForegroundService() async {
    try {
      await _channel.invokeMethod('stopForegroundService');
    } catch (e) {
      print('Failed to stop foreground service: $e');
    }
  }

  static Future<bool> isServiceRunning() async {
    try {
      final bool isRunning = await _channel.invokeMethod('isServiceRunning');
      return isRunning;
    } catch (e) {
      print('Failed to check foreground service status: $e');
      return false;
    }
  }
}