import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../models/chat_state.dart';
import '../l10n/app_localizations.dart';
import '../services/connection_settings_service.dart';
import 'main_chat_screen.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final TextEditingController _serverController = TextEditingController(
    text: 'localhost',
  );
  final TextEditingController _portController = TextEditingController(
    text: '8000',
  );
  final TextEditingController _channelController = TextEditingController(
    text: '#vorest',
  );
  final TextEditingController _nicknameController = TextEditingController();
  bool _isConnecting = false;
  bool _debugMode = false;

  @override
  void initState() {
    super.initState();
    // Check if already connected and navigate or load settings
    _checkConnectionAndNavigate();
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
      _channelController.text = savedSettings.channel;
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
    _channelController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_isConnecting) return;

    // WebSocket now works on Web platform too!
    // No need to block Web anymore

    final server = _serverController.text.trim();
    final portStr = _portController.text.trim();
    final channel = _channelController.text.trim();
    final nickname = _nicknameController.text.trim();

    if (server.isEmpty ||
        portStr.isEmpty ||
        channel.isEmpty ||
        nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).pleaseFillAllFields),
          duration: const Duration(seconds: 2),
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
      final chatState = context.read<ChatState>();
      await chatState.connectWithSettings(
        server: server,
        port: port,
        channel: channel,
        nickname: nickname,
        debugMode: _debugMode,
      );

      // Save settings on successful connection
      await ConnectionSettingsService.saveSettings(
        ConnectionSettings(
          server: server,
          port: port,
          channel: channel,
          nickname: nickname,
        ),
      );
      
      // Also save nickname separately so it persists even if other settings are cleared
      await ConnectionSettingsService.saveLastNickname(nickname);

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
                    labelText: loc.server,
                    prefixIcon: const Icon(Icons.dns),
                    border: const OutlineInputBorder(),
                  ),
                  enabled: !_isConnecting,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _portController,
                  decoration: InputDecoration(
                    labelText: loc.port,
                    prefixIcon: const Icon(Icons.numbers),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  enabled: !_isConnecting,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _channelController,
                  decoration: InputDecoration(
                    labelText: loc.channel,
                    prefixIcon: const Icon(Icons.tag),
                    border: const OutlineInputBorder(),
                    hintText: loc.channelHint,
                  ),
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
                ElevatedButton(
                  onPressed: _isConnecting ? null : _connect,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isConnecting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(loc.connect, style: const TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
