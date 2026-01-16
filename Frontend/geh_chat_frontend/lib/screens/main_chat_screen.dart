import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_state.dart';
import '../services/irc_service.dart';
import '../l10n/app_localizations.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';
import '../widgets/scroll_to_bottom_button.dart';
import '../widgets/users_overlay.dart';
import '../widgets/private_chats_overlay.dart';
import '../widgets/connection_status_indicator.dart';
import '../mixins/chat_scroll_mixin.dart';
import 'connection_screen.dart';
import 'system_messages_screen.dart';

/// Main chat screen showing channel messages
class MainChatScreen extends StatefulWidget {
  const MainChatScreen({super.key});

  @override
  State<MainChatScreen> createState() => _MainChatScreenState();
}

class _MainChatScreenState extends State<MainChatScreen>
    with SingleTickerProviderStateMixin, ChatScrollMixin {
  final TextEditingController _messageController = TextEditingController();
  bool _showUsers = false;
  bool _showPrivateChats = false;
  late AnimationController _blinkController;
  ChatState? _chatState;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    initScrollController();
    _initializeChat();
  }

  void _initializeChat() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final chatState = context.read<ChatState>();
        previousMessageCount = chatState.userMessages.length;
        chatState.setActiveChat(null);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chatState = context.read<ChatState>();
  }

  @override
  void dispose() {
    if (_chatState != null) {
      _chatState!.setActiveChat(null);
    }
    _messageController.dispose();
    disposeScrollController();
    _blinkController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    context.read<ChatState>().sendChannelMessage(message);
    _messageController.clear();
    delayedScrollToBottom();
  }

  void _toggleUsers() {
    setState(() {
      _showUsers = !_showUsers;
      if (_showUsers) _showPrivateChats = false;
    });
  }

  void _togglePrivateChats() {
    setState(() {
      _showPrivateChats = !_showPrivateChats;
      if (_showPrivateChats) _showUsers = false;
    });
  }

  Future<void> _confirmDisconnect() async {
    final loc = AppLocalizations.of(context);
    final chatState = context.read<ChatState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.disconnect),
        content: Text(loc.confirmDisconnect),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.no),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.yes),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      chatState.disconnect();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ConnectionScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final chatState = context.watch<ChatState>();

    // Trigger check for new messages
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkAndScrollForNewMessages(chatState.userMessages.length);
    });

    return Scaffold(
      appBar: _buildAppBar(loc, chatState),
      body: Stack(
        children: [
          _buildMainContent(loc, chatState),
          if (_showUsers)
            UsersOverlay(
              users: chatState.users,
              currentNickname: chatState.nickname,
              onClose: () => setState(() => _showUsers = false),
              onStartPrivateChat: chatState.startPrivateChat,
            ),
          if (_showPrivateChats)
            PrivateChatsOverlay(
              privateChats: chatState.privateChats,
              unreadCounts: chatState.unreadCounts,
              onClose: () => setState(() => _showPrivateChats = false),
            ),
          if (!_showUsers && !_showPrivateChats)
            ScrollToBottomButton(
              visible: showScrollToBottomButton,
              hasNewMessages: hasNewMessages,
              onPressed: scrollToBottom,
            ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(AppLocalizations loc, ChatState chatState) {
    return AppBar(
      title: Text(chatState.channel),
      actions: [
        _buildSystemMessagesButton(loc),
        _buildDisconnectButton(loc),
        ConnectionStatusIndicator(
          state: chatState.connectionState,
          blinkAnimation: _blinkController,
        ),
        _buildUsersButton(chatState),
        if (chatState.privateChats.isNotEmpty)
          _buildPrivateChatsButton(chatState),
      ],
    );
  }

  Widget _buildSystemMessagesButton(AppLocalizations loc) {
    return IconButton(
      icon: const Icon(Icons.info_outline),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SystemMessagesScreen()),
        );
      },
      tooltip: loc.systemMessages,
    );
  }

  Widget _buildDisconnectButton(AppLocalizations loc) {
    return IconButton(
      icon: const Icon(Icons.power_settings_new),
      onPressed: _confirmDisconnect,
      tooltip: loc.disconnect,
    );
  }

  Widget _buildUsersButton(ChatState chatState) {
    final otherUsersCount = chatState.users
        .where((user) => user != chatState.nickname)
        .length;

    return Stack(
      children: [
        IconButton(
          icon: Icon(_showUsers ? Icons.people : Icons.people_outline),
          onPressed: _toggleUsers,
        ),
        if (otherUsersCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: _buildBadge(otherUsersCount.toString(), Colors.green),
          ),
      ],
    );
  }

  Widget _buildPrivateChatsButton(ChatState chatState) {
    final unreadCount = chatState.getUnreadChatsCount();

    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.message),
          onPressed: _togglePrivateChats,
        ),
        if (unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: _buildBadge(unreadCount.toString(), Colors.red),
          ),
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMainContent(AppLocalizations loc, ChatState chatState) {
    final isConnected =
        chatState.connectionState == IrcConnectionState.connected;

    return Column(
      children: [
        Expanded(child: _buildMessagesList(loc, chatState)),
        MessageInput(
          controller: _messageController,
          hintText: loc.typeMessage,
          enabled: isConnected,
          onSend: _sendMessage,
        ),
      ],
    );
  }

  Widget _buildMessagesList(AppLocalizations loc, ChatState chatState) {
    if (chatState.userMessages.isEmpty) {
      return Center(
        child: Text(
          chatState.connectionState == IrcConnectionState.connected
              ? '${loc.mainChannel} (#vorest)'
              : loc.connecting,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: chatState.userMessages.length,
      itemBuilder: (context, index) {
        final message = chatState.userMessages[index];
        return MessageBubble(
          message: message,
          currentNickname: chatState.nickname,
        );
      },
    );
  }
}
