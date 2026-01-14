import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/chat_state.dart';
import '../services/irc_service.dart';
import '../l10n/app_localizations.dart';
import '../services/connection_settings_service.dart';
import '../config/backend_config.dart';
import 'main_chat_screen.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final TextEditingController _serverController = TextEditingController(
    text: BackendConfig.defaultHost,
  );
  final TextEditingController _portController = TextEditingController(
    text: BackendConfig.defaultPort.toString(),
  );
  final TextEditingController _nicknameController = TextEditingController();
  bool _isConnecting = false;
  bool _isAborted = false;
  bool _debugMode = false;
  StreamSubscription<IrcConnectionState>? _connectionStateSubscription;
  Timer? _connectionSuccessTimer;

  @override
  void initState() {
    super.initState();
    // Check if already connected and navigate or load settings
    _checkConnectionAndNavigate();

    // Listen to connection state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final chatState = context.read<ChatState>();
        _connectionStateSubscription = chatState.connectionStateStream.listen((
          state,
        ) {
          if (mounted) {
            if (_isConnecting) {
              if (state == IrcConnectionState.error ||
                  state == IrcConnectionState.disconnected) {
                // Connection failed - reset the connecting flag
                _connectionSuccessTimer?.cancel();
                setState(() {
                  _isConnecting = false;
                });

                // Show error message to user only if not aborted
                if (!_isAborted) {
                  _showConnectionErrorMessage(chatState);
                }
                _isAborted = false; // Reset abort flag
              } else if (state == IrcConnectionState.connected) {
                // Connection successful - cancel timer and navigate
                _connectionSuccessTimer?.cancel();
                setState(() {
                  _isConnecting = false;
                });

                // Save settings on successful connection only if not aborted
                if (!_isAborted) {
                  _saveConnectionSettingsAndNavigate(chatState);
                }
                _isAborted = false; // Reset abort flag
              }
            }
          }
        });
      }
    });
  }

  void _showConnectionErrorMessage(ChatState chatState) {
    // Get the last system message which contains the error
    final systemMessages = chatState.systemMessages;
    String errorMessage = AppLocalizations.of(context).connectionFailed;

    if (systemMessages.isNotEmpty) {
      // Find the last error-related message
      for (int i = systemMessages.length - 1; i >= 0; i--) {
        final msg = systemMessages[i].content.toLowerCase();
        if (msg.contains('error') ||
            msg.contains('refused') ||
            msg.contains('timeout') ||
            msg.contains('connection') ||
            msg.contains('network')) {
          errorMessage = systemMessages[i].content;
          break;
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  Future<void> _saveConnectionSettingsAndNavigate(ChatState chatState) async {
    try {
      // Save settings on successful connection
      await ConnectionSettingsService.saveSettings(
        ConnectionSettings(
          server: _serverController.text.trim(),
          port: int.parse(_portController.text.trim()),
          channel: chatState.channel,
          nickname: _nicknameController.text.trim(),
        ),
      );

      // Also save nickname separately so it persists even if other settings are cleared
      await ConnectionSettingsService.saveLastNickname(
        _nicknameController.text.trim(),
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const MainChatScreen(),
            settings: const RouteSettings(name: 'MainChatScreen'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  // Load saved settings to show in UI
  Future<void> _checkConnectionAndNavigate() async {
    if (!mounted) return;

    final chatState = context.read<ChatState>();

    // Load saved settings to show in UI (but never auto-connect)
    final savedSettings = await ConnectionSettingsService.loadSettings();

    if (savedSettings != null) {
      // Populate fields with saved settings (user must click Connect manually)
      _serverController.text = savedSettings.server;
      _portController.text = savedSettings.port.toString();
      _nicknameController.text = savedSettings.nickname;
    } else {
      // If no full settings, still try to load last used nickname
      final lastNickname = await ConnectionSettingsService.loadLastNickname();
      if (lastNickname != null && lastNickname.isNotEmpty) {
        _nicknameController.text = lastNickname;
      } else {
        // Generate random nickname only if no nickname was ever saved
        _nicknameController.text = chatState.generateRandomNickname();
      }
    }
  }

  @override
  void dispose() {
    _serverController.dispose();
    _portController.dispose();
    _nicknameController.dispose();
    _connectionStateSubscription?.cancel();
    _connectionSuccessTimer?.cancel();
    super.dispose();
  }

  bool _isValidIpOrDomain(String server) {
    // IPv4 pattern - matches any IP address format with 4 octets
    final ipv4Pattern = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');

    // Hostname/domain pattern (alphanumeric, dots, hyphens)
    final domainPattern = RegExp(
      r'^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$',
    );

    // localhost is always valid
    if (server.toLowerCase() == 'localhost' || server == '127.0.0.1') {
      return true;
    }

    // Check if it's a valid IPv4 (including special IPs like 10.0.2.2 for Android emulator)
    if (ipv4Pattern.hasMatch(server)) {
      final parts = server.split('.');
      // For IPv4, we accept any value 0-255 in each octet
      // This includes special IPs like 10.0.2.2 (Android emulator gateway)
      for (var part in parts) {
        final num = int.tryParse(part);
        if (num == null || num < 0 || num > 255) {
          return false;
        }
      }
      return true;
    }

    // Check if it's a valid domain/hostname
    if (domainPattern.hasMatch(server)) {
      return true;
    }

    return false;
  }

  Future<void> _connect() async {
    if (_isConnecting) return;

    final server = _serverController.text.trim();
    final portStr = _portController.text.trim();
    final nickname = _nicknameController.text.trim();

    if (server.isEmpty || portStr.isEmpty || nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).pleaseFillAllFields),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Validate IP address or domain
    if (!_isValidIpOrDomain(server)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).invalidIpAddress),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final port = int.tryParse(portStr);
    if (port == null || port < 1 || port > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).invalidPortNumber),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    try {
      // Fetch IRC configuration from backend with timeout
      String channel = '#vorest'; // Default channel

      try {
        final ircConfigUrl = BackendConfig.getIrcConfigUrl(server, port);

        final response = await http
            .get(Uri.parse(ircConfigUrl))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final config = json.decode(response.body);
          channel = config['channel'] ?? '#vorest';
        } else {
          // If config fetch fails, use default channel and continue
          // This allows connection on Android emulator where config fetch might fail
          // but WebSocket connection might still work
          debugPrint(
            'Warning: Failed to fetch IRC config: ${response.statusCode}, using default channel',
          );
        }
      } on SocketException catch (e) {
        // For Android emulator (10.0.2.2), HTTP might fail but WebSocket could work
        // Try to connect anyway with default channel
        debugPrint(
          'Warning: Socket error fetching config: $e, attempting connection with default channel',
        );
      } on TimeoutException catch (_) {
        // HTTP request timeout - try with default channel anyway
        debugPrint(
          'Warning: HTTP config fetch timeout, attempting connection with default channel',
        );
      } catch (e) {
        // Any other error - try with default channel
        debugPrint(
          'Warning: Error fetching IRC config: $e, attempting connection with default channel',
        );
      }

      if (!mounted) return;

      final chatState = context.read<ChatState>();

      // Start connection asynchronously - don't wait for it to complete
      // The connectionStateStream listener will handle navigation
      chatState
          .connectWithSettings(
            server: server,
            port: port,
            channel: channel,
            nickname: nickname,
            debugMode: _debugMode,
          )
          .catchError((e) {
            // Catch any synchronous errors from connectWithSettings
            if (mounted) {
              debugPrint('Connection error: $e');
              setState(() {
                _isConnecting = false;
              });
              // Disconnect if connection failed
              chatState.disconnect();
            }
          });

      // Start a timer waiting for connection success
      // If user clicks Abort, this timer will be cancelled
      _connectionSuccessTimer = Timer.periodic(const Duration(milliseconds: 100), (
        timer,
      ) {
        // Timer just waits - actual navigation happens via connectionStateStream listener
        // This timer will be cancelled when connection succeeds/fails or user clicks Abort
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context).connectionFailed}: $e',
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _generateNewNickname() {
    final chatState = context.read<ChatState>();
    setState(() {
      _nicknameController.text = chatState.generateRandomNickname();
    });
  }

  void _abortConnection() {
    final chatState = context.read<ChatState>();

    // Mark connection as aborted to prevent error messages
    _isAborted = true;

    // Cancel the connection success timer
    _connectionSuccessTimer?.cancel();

    // Disconnect from IRC service
    chatState.disconnect();

    setState(() {
      _isConnecting = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).connectionAborted),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(loc.appTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 32),
                Text(
                  loc.welcomeToGehChat,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  loc.configureConnectionSettings,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                TextField(
                  controller: _serverController,
                  decoration: InputDecoration(
                    labelText: loc.backendServer,
                    prefixIcon: const Icon(Icons.dns),
                    border: const OutlineInputBorder(),
                    hintText: 'localhost',
                  ),
                  enabled: !_isConnecting,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _portController,
                  decoration: InputDecoration(
                    labelText: loc.backendPort,
                    prefixIcon: const Icon(Icons.numbers),
                    border: const OutlineInputBorder(),
                    hintText: '8000',
                  ),
                  keyboardType: TextInputType.number,
                  enabled: !_isConnecting,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nicknameController,
                        decoration: InputDecoration(
                          labelText: loc.nickname,
                          prefixIcon: const Icon(Icons.person),
                          border: const OutlineInputBorder(),
                        ),
                        enabled: !_isConnecting,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _isConnecting ? null : _generateNewNickname,
                      icon: const Icon(Icons.refresh),
                      tooltip: loc.generateNewNickname,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                CheckboxListTile(
                  title: Text(loc.debugLogLevel),
                  subtitle: Text(
                    loc.showAllIrcMessages,
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: _debugMode,
                  onChanged: _isConnecting
                      ? null
                      : (value) {
                          setState(() {
                            _debugMode = value ?? false;
                          });
                        },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 8),
                if (_isConnecting)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _abortConnection,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.red,
                          ),
                          child: Text(
                            loc.abort,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  ElevatedButton(
                    onPressed: _connect,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      loc.connect,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
