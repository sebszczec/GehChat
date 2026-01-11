import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class BatteryOptimizationService {
  static const platform = MethodChannel('com.example.geh_chat_frontend/battery');

  static Future<void> requestIgnoreBatteryOptimizations() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    
    try {
      final bool isIgnoring = await platform.invokeMethod('isIgnoringBatteryOptimizations');
      debugPrint('Is ignoring battery optimizations: $isIgnoring');
      
      if (!isIgnoring) {
        await platform.invokeMethod('requestIgnoreBatteryOptimizations');
        debugPrint('Requested to ignore battery optimizations');
      }
    } catch (e) {
      debugPrint('Error requesting battery optimization exemption: $e');
    }
  }
}
