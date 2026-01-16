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
import '../utils/network_validator.dart';
import 'main_chat_screen.dart';

/// Screen for configuring and initiating connection to the IRC backend
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
    _loadSavedSettings();
    _setupConnectionStateListener();
  }

  void _loadSavedSettings() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _checkConnectionAndNavigate();
    });
  }

  void _setupConnectionStateListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final chatState = context.read<ChatState>();
        _connectionStateSubscription = chatState.connectionStateStream.listen(
          _handleConnectionStateChange,
        );
      }
    });
  }

  void _handleConnectionStateChange(IrcConnectionState state) {
    if (!mounted || !_isConnecting) return;

    if (state == IrcConnectionState.error ||
        state == IrcConnectionState.disconnected) {
      _handleConnectionFailed();
    } else if (state == IrcConnectionState.connected) {
      _handleConnectionSuccess();
    }
  }

  void _handleConnectionFailed() {
    _connectionSuccessTimer?.cancel();
    setState(() => _isConnecting = false);

    if (!_isAborted) {
      _showConnectionErrorMessage();
    }
    _isAborted = false;
  }

  void _handleConnectionSuccess() {
    _connectionSuccessTimer?.cancel();
    setState(() => _isConnecting = false);

    if (!_isAborted) {
      _saveConnectionSettingsAndNavigate();
    }
    _isAborted = false;
  }

  void _showConnectionErrorMessage() {
    final chatState = context.read<ChatState>();
    final systemMessages = chatState.systemMessages;
    String errorMessage = AppLocalizations.of(context).connectionFailed;

    if (systemMessages.isNotEmpty) {
      for (int i = systemMessages.length - 1; i >= 0; i--) {
        final msg = systemMessages[i].content.toLowerCase();
        if (_isErrorMessage(msg)) {
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
            onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
    }
  }

  bool _isErrorMessage(String msg) {
    return msg.contains('error') ||
        msg.contains('refused') ||
        msg.contains('timeout') ||
        msg.contains('connection') ||
        msg.contains('network');
  }

  Future<void> _saveConnectionSettingsAndNavigate() async {
    try {
      final chatState = context.read<ChatState>();

      await ConnectionSettingsService.saveSettings(
        ConnectionSettings(
          server: _serverController.text.trim(),
          port: int.parse(_portController.text.trim()),
          channel: chatState.channel,
          nickname: _nicknameController.text.trim(),
        ),
      );

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

  Future<void> _checkConnectionAndNavigate() async {
    if (!mounted) return;

    final chatState = context.read<ChatState>();
    final savedSettings = await ConnectionSettingsService.loadSettings();

    if (savedSettings != null) {
      _serverController.text = savedSettings.server;
      _portController.text = savedSettings.port.toString();
      _nicknameController.text = savedSettings.nickname;
    } else {
      final lastNickname = await ConnectionSettingsService.loadLastNickname();
      if (lastNickname != null && lastNickname.isNotEmpty) {
        _nicknameController.text = lastNickname;
      } else {
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

  Future<void> _connect() async {
    if (_isConnecting) return;

    final loc = AppLocalizations.of(context);
    final server = _serverController.text.trim();
    final portStr = _portController.text.trim();
    final nickname = _nicknameController.text.trim();

    // Validate inputs
    if (!_validateInputs(loc, server, portStr, nickname)) {
      return;
    }

    final port = NetworkValidator.parsePort(portStr)!;

    setState(() => _isConnecting = true);

    try {
      final channel = await _fetchIrcConfig(server, port);
      if (!mounted) return;

      _startConnection(server, port, channel, nickname);
    } catch (e) {
      _handleConnectError(e);
    }
  }

  bool _validateInputs(
    AppLocalizations loc,
    String server,
    String portStr,
    String nickname,
  ) {
    if (server.isEmpty || portStr.isEmpty || nickname.isEmpty) {
      _showSnackBar(loc.pleaseFillAllFields);
      return false;
    }

    if (!NetworkValidator.isValidIpOrDomain(server)) {
      _showSnackBar(loc.invalidIpAddress, isError: true);
      return false;
    }

    if (!NetworkValidator.isValidPort(portStr)) {
      _showSnackBar(loc.invalidPortNumber);
      return false;
    }

    return true;
  }

  void _showSnackBar(String message, {bool isError = false, int seconds = 2}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: seconds),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  Future<String> _fetchIrcConfig(String server, int port) async {
    String channel = '#vorest';

    try {
      final ircConfigUrl = BackendConfig.getIrcConfigUrl(server, port);
      final response = await http
          .get(Uri.parse(ircConfigUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final config = json.decode(response.body);
        channel = config['channel'] ?? '#vorest';
      } else {
        debugPrint(
          'Warning: Failed to fetch IRC config: ${response.statusCode}',
        );
      }
    } on SocketException catch (e) {
      debugPrint('Warning: Socket error fetching config: $e');
    } on TimeoutException catch (_) {
      debugPrint('Warning: HTTP config fetch timeout');
    } catch (e) {
      debugPrint('Warning: Error fetching IRC config: $e');
    }

    return channel;
  }

  void _startConnection(
    String server,
    int port,
    String channel,
    String nickname,
  ) {
    final chatState = context.read<ChatState>();

    chatState
        .connectWithSettings(
          server: server,
          port: port,
          channel: channel,
          nickname: nickname,
          debugMode: _debugMode,
        )
        .catchError((e) {
          if (mounted) {
            debugPrint('Connection error: $e');
            setState(() => _isConnecting = false);
            chatState.disconnect();
          }
        });

    _connectionSuccessTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) {},
    );
  }

  void _handleConnectError(dynamic e) {
    if (mounted) {
      setState(() => _isConnecting = false);
      _showSnackBar(
        '${AppLocalizations.of(context).connectionFailed}: $e',
        isError: true,
        seconds: 3,
      );
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

    _isAborted = true;
    _connectionSuccessTimer?.cancel();
    chatState.disconnect();

    setState(() => _isConnecting = false);

    _showSnackBar(AppLocalizations.of(context).connectionAborted);
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
                _buildHeader(loc),
                const SizedBox(height: 48),
                _buildServerInput(loc),
                const SizedBox(height: 16),
                _buildPortInput(loc),
                const SizedBox(height: 16),
                _buildNicknameInput(loc),
                const SizedBox(height: 24),
                _buildDebugCheckbox(loc),
                const SizedBox(height: 8),
                _buildConnectButton(loc),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations loc) {
    return Column(
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
      ],
    );
  }

  Widget _buildServerInput(AppLocalizations loc) {
    return TextField(
      controller: _serverController,
      decoration: InputDecoration(
        labelText: loc.backendServer,
        prefixIcon: const Icon(Icons.dns),
        border: const OutlineInputBorder(),
        hintText: 'localhost',
      ),
      enabled: !_isConnecting,
    );
  }

  Widget _buildPortInput(AppLocalizations loc) {
    return TextField(
      controller: _portController,
      decoration: InputDecoration(
        labelText: loc.backendPort,
        prefixIcon: const Icon(Icons.numbers),
        border: const OutlineInputBorder(),
        hintText: '8000',
      ),
      keyboardType: TextInputType.number,
      enabled: !_isConnecting,
    );
  }

  Widget _buildNicknameInput(AppLocalizations loc) {
    return Row(
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
    );
  }

  Widget _buildDebugCheckbox(AppLocalizations loc) {
    return CheckboxListTile(
      title: Text(loc.debugLogLevel),
      subtitle: Text(
        loc.showAllIrcMessages,
        style: const TextStyle(fontSize: 12),
      ),
      value: _debugMode,
      onChanged: _isConnecting
          ? null
          : (value) => setState(() => _debugMode = value ?? false),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _buildConnectButton(AppLocalizations loc) {
    if (_isConnecting) {
      return ElevatedButton(
        onPressed: _abortConnection,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.red,
        ),
        child: Text(
          loc.abort,
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
      );
    }

    return ElevatedButton(
      onPressed: _connect,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Text(loc.connect, style: const TextStyle(fontSize: 16)),
    );
  }
}
