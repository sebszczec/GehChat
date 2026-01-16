import 'package:shared_preferences/shared_preferences.dart';

class ConnectionSettings {
  final String server;
  final int port;
  final String channel;
  final String nickname;

  ConnectionSettings({
    required this.server,
    required this.port,
    required this.channel,
    required this.nickname,
  });

  Map<String, dynamic> toMap() {
    return {
      'server': server,
      'port': port,
      'channel': channel,
      'nickname': nickname,
    };
  }

  factory ConnectionSettings.fromMap(Map<String, dynamic> map) {
    return ConnectionSettings(
      server: map['server'] as String,
      port: map['port'] as int,
      channel: map['channel'] as String,
      nickname: map['nickname'] as String,
    );
  }
}

class ConnectionSettingsService {
  static const String _keyServer = 'irc_server';
  static const String _keyPort = 'irc_port';
  static const String _keyChannel = 'irc_channel';
  static const String _keyNickname = 'irc_nickname';
  static const String _keyHasSavedSettings = 'has_saved_settings';
  static const String _keyShouldAutoConnect = 'should_auto_connect';

  /// Save connection settings
  static Future<void> saveSettings(ConnectionSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServer, settings.server);
    await prefs.setInt(_keyPort, settings.port);
    await prefs.setString(_keyChannel, settings.channel);
    await prefs.setString(_keyNickname, settings.nickname);
    await prefs.setBool(_keyHasSavedSettings, true);
  }

  /// Load saved connection settings (only if auto-connect is expected)
  static Future<ConnectionSettings?> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final hasSaved = prefs.getBool(_keyHasSavedSettings) ?? false;
    if (!hasSaved) {
      return null;
    }

    final server = prefs.getString(_keyServer);
    final port = prefs.getInt(_keyPort);
    final channel = prefs.getString(_keyChannel);
    final nickname = prefs.getString(_keyNickname);

    if (server == null || port == null || channel == null || nickname == null) {
      return null;
    }

    return ConnectionSettings(
      server: server,
      port: port,
      channel: channel,
      nickname: nickname,
    );
  }

  /// Load last used server and port (always returns values if stored, ignores hasSavedSettings flag)
  static Future<({String? server, int? port})> loadLastServerAndPort() async {
    final prefs = await SharedPreferences.getInstance();
    return (server: prefs.getString(_keyServer), port: prefs.getInt(_keyPort));
  }

  /// Check if there are saved settings
  static Future<bool> hasSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasSavedSettings) ?? false;
  }

  /// Clear saved settings
  static Future<void> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyServer);
    await prefs.remove(_keyPort);
    await prefs.remove(_keyChannel);
    await prefs.remove(_keyNickname);
    await prefs.remove(_keyHasSavedSettings);
    await prefs.remove(_keyShouldAutoConnect);
  }

  /// Enable auto-connect (called after successful manual connection)
  static Future<void> enableAutoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShouldAutoConnect, true);
  }

  /// Disable auto-connect (preserves server settings but prevents auto-reconnect)
  static Future<void> disableAutoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShouldAutoConnect, false);
    await prefs.setBool(_keyHasSavedSettings, false);
  }

  /// Check if user has enabled auto-connect
  static Future<bool> shouldAutoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyShouldAutoConnect) ?? false;
  }

  /// Save last used nickname separately (persists even after clearing full settings)
  static Future<void> saveLastNickname(String nickname) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNickname, nickname);
  }

  /// Load last used nickname
  static Future<String?> loadLastNickname() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyNickname);
  }
}
