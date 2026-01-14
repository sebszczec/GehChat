import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show PlatformDispatcher;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'services/irc_service.dart';
import 'services/notification_service.dart';
import 'services/battery_optimization_service.dart';
import 'models/chat_state.dart';
import 'screens/connection_screen.dart';
import 'screens/main_chat_screen.dart';
import 'screens/private_chat_screen.dart';
import 'l10n/app_localizations.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
ChatState? _globalChatState;

// Global IRC service that persists even when UI is destroyed - using WebSocket
final IrcService _globalIrcService = IrcService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up global error handler for unhandled exceptions
  FlutterError.onError = (FlutterErrorDetails details) {
    // Log the error
    debugPrint('FlutterError: ${details.exceptionAsString()}');

    // Show error notification if it's a connection error
    final errorStr = details.exceptionAsString().toLowerCase();
    if (errorStr.contains('websocket') ||
        errorStr.contains('connection') ||
        errorStr.contains('socket')) {
      // These errors are handled by IrcService, just log them
      debugPrint(
        'WebSocket/Connection error (handled by IrcService): $details',
      );
      // Don't rethrow - this error is handled
      return;
    } else {
      // For other errors, let Flutter handle it
      FlutterError.dumpErrorToConsole(details);
    }
  };

  // Set up handler for errors outside of Flutter
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Platform error: $error');
    if (error.toString().toLowerCase().contains('websocket') ||
        error.toString().toLowerCase().contains('connection') ||
        error.toString().toLowerCase().contains('socket')) {
      // WebSocket errors are expected and handled
      debugPrint('WebSocket error suppressed: $error');
      return true; // Return true to indicate the error is handled
    }
    return false;
  };

  final notificationService = NotificationService();
  await notificationService.initialize();

  // Request to ignore battery optimizations (important for background operation)
  await BatteryOptimizationService.requestIgnoreBatteryOptimizations();

  // Set up notification tap handler
  notificationService.onNotificationTap = (username, isPrivate) {
    debugPrint('Notification tapped: username=$username, isPrivate=$isPrivate');

    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('No context available for notification tap');
      return;
    }

    // Wait a moment for app to fully resume if needed
    Future.delayed(const Duration(milliseconds: 300), () {
      final navigator = navigatorKey.currentState;
      if (navigator == null) {
        debugPrint('Navigator state is null');
        return;
      }

      try {
        if (isPrivate && username != null) {
          // Navigate to private chat
          debugPrint('Navigating to private chat: $username');
          navigator.push(
            MaterialPageRoute(
              builder: (context) => PrivateChatScreen(username: username),
            ),
          );
        } else {
          // Navigate to main chat screen
          debugPrint('Navigating to main chat');

          // Check if we're already on main chat
          bool isOnMainChat = false;
          navigator.popUntil((route) {
            if (route.settings.name == 'MainChatScreen') {
              isOnMainChat = true;
            }
            return true; // Stop at first check
          });

          if (!isOnMainChat) {
            // Push or replace with main chat
            if (_globalChatState?.connectionState ==
                IrcConnectionState.connected) {
              debugPrint('Connected - navigating to MainChatScreen');
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const MainChatScreen(),
                  settings: const RouteSettings(name: 'MainChatScreen'),
                ),
                (route) => false, // Remove all previous routes
              );
            } else {
              debugPrint(
                'Not connected - connection state: ${_globalChatState?.connectionState}',
              );
            }
          }
        }
      } catch (e) {
        debugPrint('Error handling notification tap: $e');
      }
    });
  };

  // Hide Android navigation buttons (immersive mode)
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [SystemUiOverlay.top],
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('App lifecycle state: $state');

    // Update ChatState with current lifecycle state for notification logic
    _globalChatState?.setAppLifecycleState(state);

    // Keep connection alive in all states
    // The persistent notification and auto-reconnect will handle disconnections
    if (state == AppLifecycleState.paused) {
      debugPrint('App paused - connection should stay alive');
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('App resumed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        // Use global IRC service to maintain connection even when UI is destroyed
        _globalChatState = ChatState(_globalIrcService);
        return _globalChatState!;
      },
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'IRC Chat',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en', ''), Locale('pl', '')],
        home: const ConnectionScreen(),
      ),
    );
  }
}
