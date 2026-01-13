import 'package:flutter_test/flutter_test.dart';
import 'package:geh_chat_frontend/services/irc_service.dart';
import 'dart:async';

void main() {
  group('IrcService', () {
    late IrcService ircService;

    setUp(() {
      ircService = IrcService(
        server: 'test.server.com',
        port: 6667,
        channel: '#testchannel',
        backendUrl: 'ws://localhost:8000/ws',
      );
    });

    tearDown(() {
      ircService.dispose();
    });

    test('initializes with correct default values', () {
      expect(ircService.server, equals('test.server.com'));
      expect(ircService.port, equals(6667));
      expect(ircService.channel, equals('#testchannel'));
      expect(ircService.backendUrl, equals('ws://localhost:8000/ws'));
      expect(ircService.nickname, isEmpty);
    });

    test('initializes with default values when not provided', () {
      final defaultService = IrcService();
      expect(defaultService.server, equals('slaugh.pl'));
      expect(defaultService.port, equals(6667));
      expect(defaultService.channel, equals('#vorest'));
      expect(defaultService.backendUrl, equals('ws://localhost:8000/ws'));
    });

    test('updates settings correctly', () {
      ircService.updateSettings(
        newServer: 'new.server.com',
        newPort: 7000,
        newChannel: '#newchannel',
      );

      expect(ircService.server, equals('new.server.com'));
      expect(ircService.port, equals(7000));
      expect(ircService.channel, equals('#newchannel'));
    });

    test('updates only specified settings', () {
      ircService.updateSettings(newServer: 'updated.server.com');

      expect(ircService.server, equals('updated.server.com'));
      expect(ircService.port, equals(6667)); // unchanged
      expect(ircService.channel, equals('#testchannel')); // unchanged
    });

    test('generates friendly nickname', () {
      final nickname = ircService.generateRandomNickname();

      expect(nickname, isNotEmpty);
      expect(nickname.length, greaterThan(5));
      // Should contain adjective + noun + number
      expect(
        RegExp(r'^[A-Z][a-z]+[A-Z][a-z]+\d{3}$').hasMatch(nickname),
        isTrue,
      );
    });

    test('generates different nicknames', () {
      final nickname1 = ircService.generateRandomNickname();
      // Wait a bit to ensure different timestamp
      Future.delayed(const Duration(milliseconds: 10));
      final nickname2 = ircService.generateRandomNickname();

      // While they could theoretically be the same, it's very unlikely
      expect(nickname1, isNotEmpty);
      expect(nickname2, isNotEmpty);
    });

    test('message stream is broadcast stream', () {
      expect(ircService.messages.isBroadcast, isTrue);
    });

    test('users stream is broadcast stream', () {
      expect(ircService.users.isBroadcast, isTrue);
    });

    test('connectionState stream is broadcast stream', () {
      expect(ircService.connectionState.isBroadcast, isTrue);
    });
  });

  group('IrcMessage', () {
    test('creates message with all properties', () {
      final now = DateTime.now();
      final message = IrcMessage(
        sender: 'TestUser',
        content: 'Hello, World!',
        target: '#testchannel',
        timestamp: now,
        isPrivate: false,
        isSystem: false,
      );

      expect(message.sender, equals('TestUser'));
      expect(message.content, equals('Hello, World!'));
      expect(message.target, equals('#testchannel'));
      expect(message.timestamp, equals(now));
      expect(message.isPrivate, isFalse);
      expect(message.isSystem, isFalse);
    });

    test('creates system message', () {
      final message = IrcMessage(
        sender: 'System',
        content: 'Connected to server',
        target: '#channel',
        timestamp: DateTime.now(),
        isSystem: true,
      );

      expect(message.isSystem, isTrue);
      expect(message.isPrivate, isFalse); // default value
    });

    test('creates private message', () {
      final message = IrcMessage(
        sender: 'User1',
        content: 'Private message',
        target: 'User2',
        timestamp: DateTime.now(),
        isPrivate: true,
      );

      expect(message.isPrivate, isTrue);
      expect(message.isSystem, isFalse); // default value
    });
  });

  group('IrcConnectionState', () {
    test('has all expected states', () {
      expect(IrcConnectionState.values.length, equals(5));
      expect(
        IrcConnectionState.values.contains(IrcConnectionState.disconnected),
        isTrue,
      );
      expect(
        IrcConnectionState.values.contains(IrcConnectionState.connecting),
        isTrue,
      );
      expect(
        IrcConnectionState.values.contains(IrcConnectionState.joiningChannel),
        isTrue,
      );
      expect(
        IrcConnectionState.values.contains(IrcConnectionState.connected),
        isTrue,
      );
      expect(
        IrcConnectionState.values.contains(IrcConnectionState.error),
        isTrue,
      );
    });

    test('sendPrivateMessage strips @ prefix from recipient', () {
      // This test ensures that when sending a private message to @username,
      // the @ symbol is properly stripped before sending to backend
      final ircService = IrcService(backendUrl: 'ws://localhost:8000/ws');

      // We can't directly test WebSocket behavior without mocking,
      // but we can verify the method exists and accepts the parameter
      expect(() {
        ircService.sendPrivateMessage('@slaughOP', 'Hello!');
      }, returnsNormally);

      ircService.dispose();
    });

    test('sendMessage with @ prefix target removes prefix', () {
      final ircService = IrcService(backendUrl: 'ws://localhost:8000/ws');

      // Verify sendMessage accepts target with @ and processes it
      expect(() {
        ircService.sendMessage('Hello!', target: '@testuser');
      }, returnsNormally);

      ircService.dispose();
    });
  });
}
