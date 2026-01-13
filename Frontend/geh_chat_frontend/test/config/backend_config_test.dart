import 'package:flutter_test/flutter_test.dart';
import 'package:geh_chat_frontend/config/backend_config.dart';

void main() {
  group('BackendConfig', () {
    test('has correct default host', () {
      expect(BackendConfig.defaultHost, equals('127.0.0.1'));
    });

    test('has correct default port', () {
      expect(BackendConfig.defaultPort, equals(8000));
    });

    test('generates correct WebSocket URL', () {
      const host = '127.0.0.1';
      const port = 8000;

      final wsUrl = BackendConfig.getWebSocketUrl(host, port);

      expect(wsUrl, equals('ws://127.0.0.1:8000/ws'));
    });

    test('generates correct WebSocket URL with custom host and port', () {
      const host = '192.168.1.100';
      const port = 9000;

      final wsUrl = BackendConfig.getWebSocketUrl(host, port);

      expect(wsUrl, equals('ws://192.168.1.100:9000/ws'));
    });

    test('generates correct API base URL', () {
      const host = '127.0.0.1';
      const port = 8000;

      final apiUrl = BackendConfig.getApiBaseUrl(host, port);

      expect(apiUrl, equals('http://127.0.0.1:8000'));
    });

    test('generates correct API base URL with custom host and port', () {
      const host = 'backend.example.com';
      const port = 3000;

      final apiUrl = BackendConfig.getApiBaseUrl(host, port);

      expect(apiUrl, equals('http://backend.example.com:3000'));
    });

    test('generates correct IRC config URL', () {
      const host = '127.0.0.1';
      const port = 8000;

      final configUrl = BackendConfig.getIrcConfigUrl(host, port);

      expect(configUrl, equals('http://127.0.0.1:8000/api/irc-config'));
    });

    test('generates correct IRC config URL with custom values', () {
      const host = 'localhost';
      const port = 5000;

      final configUrl = BackendConfig.getIrcConfigUrl(host, port);

      expect(configUrl, equals('http://localhost:5000/api/irc-config'));
    });
  });
}
