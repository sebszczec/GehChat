// GehChat Frontend Configuration
// Configuration for backend WebSocket connection

class BackendConfig {
  // Backend WebSocket server configuration
  // Using 127.0.0.1 (loopback) instead of localhost for direct IP connection
  static const String defaultHost = '127.0.0.1';
  static const int defaultPort = 8000;

  /// Get WebSocket URL for backend connection
  static String getWebSocketUrl(String host, int port) {
    return 'ws://$host:$port/ws';
  }

  /// Get backend API base URL
  static String getApiBaseUrl(String host, int port) {
    return 'http://$host:$port';
  }

  /// Get IRC configuration from backend
  static String getIrcConfigUrl(String host, int port) {
    return 'http://$host:$port/api/irc-config';
  }
}
