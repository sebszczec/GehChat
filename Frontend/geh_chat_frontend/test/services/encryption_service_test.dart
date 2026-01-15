import 'package:flutter_test/flutter_test.dart';
import 'package:geh_chat_frontend/services/encryption_service.dart';

void main() {
  group('EncryptionService', () {
    late EncryptionService encryptionService;

    setUp(() {
      encryptionService = EncryptionService(debugMode: false);
    });

    tearDown(() {
      encryptionService.dispose();
    });

    test('registerUser returns device ID', () {
      final deviceId = encryptionService.registerUser('user1');
      expect(deviceId, isNotNull);
      expect(deviceId, contains('user1'));
    });

    test('establishSession creates encryption key', () {
      final result = encryptionService.establishSession('user1', 'user2');
      expect(result, isTrue);

      // Establishing again should return false
      final result2 = encryptionService.establishSession('user1', 'user2');
      expect(result2, isFalse);
    });

    test('encryptMessage returns null without session', () {
      final encrypted = encryptionService.encryptMessage(
        'user1',
        'user2',
        'Hello',
      );
      expect(encrypted, isNull);
    });

    test('encryptMessage encrypts with session', () {
      encryptionService.establishSession('user1', 'user2');

      final encrypted = encryptionService.encryptMessage(
        'user1',
        'user2',
        'Hello World',
      );

      expect(encrypted, isNotNull);
      expect(encrypted!.containsKey('encrypted_content'), isTrue);
      expect(encrypted.containsKey('iv'), isTrue);
      expect(encrypted['is_encrypted'], equals('true'));
      expect(encrypted['encrypted_content'], isNotEmpty);
    });

    test('decryptMessage returns original message', () {
      encryptionService.establishSession('user1', 'user2');

      const originalMessage = 'Hello World';
      final encrypted = encryptionService.encryptMessage(
        'user1',
        'user2',
        originalMessage,
      );

      final decrypted = encryptionService.decryptMessage(
        'user1',
        'user2',
        encrypted!,
      );

      expect(decrypted, equals(originalMessage));
    });

    test('decryptMessage returns null without session', () {
      final encryptedData = {'encrypted_content': 'dGVzdA==', 'iv': 'dGVzdA=='};

      final result = encryptionService.decryptMessage(
        'user1',
        'user2',
        encryptedData,
      );
      expect(result, isNull);
    });

    test('isFrontendUser detects users with sessions', () {
      expect(encryptionService.isFrontendUser('user1'), isFalse);

      encryptionService.establishSession('user1', 'user2');

      expect(encryptionService.isFrontendUser('user1'), isTrue);
      expect(encryptionService.isFrontendUser('user2'), isTrue);
    });

    test('cleanupUserSessions removes all sessions', () {
      encryptionService.establishSession('user1', 'user2');
      encryptionService.establishSession('user1', 'user3');

      expect(encryptionService.isFrontendUser('user1'), isTrue);

      encryptionService.cleanupUserSessions('user1');

      expect(encryptionService.isFrontendUser('user1'), isFalse);
      expect(encryptionService.isFrontendUser('user2'), isFalse);
      expect(encryptionService.isFrontendUser('user3'), isFalse);
    });

    test('encryptDecrypt roundtrip with various messages', () {
      encryptionService.establishSession('alice', 'bob');

      final testMessages = [
        'Hello Bob',
        'Message with numbers: 123456789',
        'Special chars: !@#\$%^&*()',
        'a', // Single character (minimum valid message)
      ];

      for (final original in testMessages) {
        if (original.isEmpty) continue; // Skip empty messages

        final encrypted = encryptionService.encryptMessage(
          'alice',
          'bob',
          original,
        );
        expect(encrypted, isNotNull);

        final decrypted = encryptionService.decryptMessage(
          'alice',
          'bob',
          encrypted!,
        );
        expect(decrypted, equals(original));
      }
    });

    test('bidirectional encryption works', () {
      encryptionService.establishSession('user1', 'user2');

      // user1 -> user2
      final msg1 = encryptionService.encryptMessage(
        'user1',
        'user2',
        'Hello from user1',
      );
      expect(msg1, isNotNull);

      final dec1 = encryptionService.decryptMessage('user1', 'user2', msg1!);
      expect(dec1, equals('Hello from user1'));

      // user2 -> user1
      final msg2 = encryptionService.encryptMessage(
        'user2',
        'user1',
        'Hello from user2',
      );
      expect(msg2, isNotNull);

      final dec2 = encryptionService.decryptMessage('user2', 'user1', msg2!);
      expect(dec2, equals('Hello from user2'));
    });

    test('multiple sessions are isolated', () {
      encryptionService.establishSession('user1', 'user2');
      encryptionService.establishSession('user3', 'user4');

      final msg1 = encryptionService.encryptMessage(
        'user1',
        'user2',
        'Message 1-2',
      );
      final msg2 = encryptionService.encryptMessage(
        'user3',
        'user4',
        'Message 3-4',
      );

      expect(msg1, isNotNull);
      expect(msg2, isNotNull);

      final dec1 = encryptionService.decryptMessage('user1', 'user2', msg1!);
      final dec2 = encryptionService.decryptMessage('user3', 'user4', msg2!);

      expect(dec1, equals('Message 1-2'));
      expect(dec2, equals('Message 3-4'));
    });

    test('activeSessionCount returns correct count', () {
      // Initial count should be 0
      expect(encryptionService.activeSessionCount, equals(0));

      // After establishing first session, count increases
      encryptionService.establishSession('user1', 'user2');
      expect(encryptionService.activeSessionCount, equals(1));

      // After establishing second session
      encryptionService.establishSession('user1', 'user3');
      expect(encryptionService.activeSessionCount, equals(2));
    });
  });
}
