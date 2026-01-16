import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/chat_state.dart';
import '../services/irc_service.dart';
import '../l10n/app_localizations.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';
import '../widgets/scroll_to_bottom_button.dart';
import '../mixins/chat_scroll_mixin.dart';

/// Screen for private chat with a specific user
class PrivateChatScreen extends StatefulWidget {
  final String username;

  const PrivateChatScreen({super.key, required this.username});

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen>
    with ChatScrollMixin {
  final TextEditingController _messageController = TextEditingController();
  ChatState? _chatState;

  @override
  void initState() {
    super.initState();
    initScrollController();
    _markAsReadAndSetActive();
  }

  void _markAsReadAndSetActive() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final chatState = context.read<ChatState>();
        chatState.markAsRead(widget.username);
        chatState.setActiveChat(widget.username);
        final messages = chatState.privateChats[widget.username] ?? [];
        previousMessageCount = messages.length;
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
    if (_chatState != null && _chatState!.activeChat == widget.username) {
      _chatState!.setActiveChat(null);
    }
    _messageController.dispose();
    disposeScrollController();
    super.dispose();
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();
    delayedScrollToBottom();

    unawaited(
      context.read<ChatState>().sendPrivateMessage(widget.username, message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final chatState = context.watch<ChatState>();
    final messages = chatState.privateChats[widget.username] ?? [];
    final isConnected =
        chatState.connectionState == IrcConnectionState.connected;

    // Trigger check for new messages
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkAndScrollForNewMessages(messages.length);
    });

    return Scaffold(
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: _buildMessagesList(loc, chatState, messages),
              ),
              MessageInput(
                controller: _messageController,
                hintText: loc.typeMessage,
                enabled: isConnected,
                onSend: _sendMessage,
              ),
            ],
          ),
          ScrollToBottomButton(
            visible: showScrollToBottomButton,
            hasNewMessages: hasNewMessages,
            onPressed: scrollToBottom,
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).primaryColor,
            child: Text(
              widget.username[0].toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Text(widget.username),
        ],
      ),
    );
  }

  Widget _buildMessagesList(
    AppLocalizations loc,
    ChatState chatState,
    List<IrcMessage> messages,
  ) {
    if (messages.isEmpty) {
      return Center(
        child: Text(
          '${loc.startPrivateChat} with ${widget.username}',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return MessageBubble(
          message: message,
          currentNickname: chatState.nickname,
          showSender: false,
        );
      },
    );
  }
}
