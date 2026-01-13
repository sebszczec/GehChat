import 'package:flutter_test/flutter_test.dart';
import 'package:geh_chat_frontend/models/chat_state.dart';
import 'package:geh_chat_frontend/services/irc_service.dart';

void main() {
  // Initialize Flutter binding for tests that use platform channels
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatState', () {
    late ChatState chatState;
    late IrcService mockIrcService;

    setUp(() {
      mockIrcService = IrcService(
        server: 'test.server.com',
        port: 6667,
        channel: '#testchannel',
        backendUrl: 'ws://localhost:8000/ws',
      );
      chatState = ChatState(mockIrcService);
    });

    tearDown(() {
      chatState.dispose();
      mockIrcService.dispose();
    });

    test('initializes with disconnected state', () {
      expect(
        chatState.connectionState,
        equals(IrcConnectionState.disconnected),
      );
    });

    test('has empty channel messages list initially', () {
      expect(chatState.channelMessages, isEmpty);
    });

    test('has empty users list initially', () {
      expect(chatState.users, isEmpty);
    });

    test('has empty private chats map initially', () {
      expect(chatState.privateChats, isEmpty);
    });

    test('nickname getter returns irc service nickname', () {
      expect(chatState.nickname, equals(mockIrcService.nickname));
    });

    test('channel getter returns irc service channel', () {
      expect(chatState.channel, equals(mockIrcService.channel));
    });

    test('systemMessages returns only system messages', () {
      expect(chatState.systemMessages, isEmpty);
      // System messages are filtered from channelMessages
      expect(chatState.systemMessages, everyElement(isA<IrcMessage>()));
    });

    test('userMessages returns only user messages', () {
      expect(chatState.userMessages, isEmpty);
      // User messages are non-system messages from channelMessages
      expect(chatState.userMessages, everyElement(isA<IrcMessage>()));
    });

    test('activeChat is null initially (main channel)', () {
      expect(chatState.activeChat, isNull);
    });

    test('unreadCounts is empty initially', () {
      expect(chatState.unreadCounts, isEmpty);
    });
  });
}
