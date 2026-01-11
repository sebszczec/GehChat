import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_state.dart';
import '../services/irc_service.dart';
import '../l10n/app_localizations.dart';

class PrivateChatScreen extends StatefulWidget {
  final String username;

  const PrivateChatScreen({super.key, required this.username});

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottomButton = false;
  DateTime? _lastUserScrollTime;
  bool _hasNewMessages = false;
  int _previousMessageCount = 0;
  ChatState? _chatState;

  @override
  void initState() {
    super.initState();
    // Mark messages as read when opening the chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final chatState = context.read<ChatState>();
        chatState.markAsRead(widget.username);
        chatState.setActiveChat(widget.username); // Set this chat as active
        final messages = chatState.privateChats[widget.username] ?? [];
        _previousMessageCount = messages.length;
      }
    });
    _scrollController.addListener(_scrollListener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Save reference to ChatState for safe access in dispose()
    _chatState = context.read<ChatState>();
  }

  @override
  void dispose() {
    // Clear active chat when leaving - using saved reference
    if (_chatState != null && _chatState!.activeChat == widget.username) {
      _chatState!.setActiveChat(null);
    }
    _messageController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      // Track user scroll
      if (_scrollController.position.isScrollingNotifier.value) {
        _lastUserScrollTime = DateTime.now();
      }

      final isAtBottom =
          _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 50;
      if (_showScrollToBottomButton == isAtBottom) {
        setState(() {
          _showScrollToBottomButton = !isAtBottom;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      setState(() {
        _hasNewMessages = false;
      });
    }
  }

  void _checkAndScrollForNewMessages(int currentMessageCount) {
    if (currentMessageCount > _previousMessageCount) {
      _previousMessageCount = currentMessageCount;

      final userScrolledRecently =
          _lastUserScrollTime != null &&
          DateTime.now().difference(_lastUserScrollTime!) <
              const Duration(seconds: 2);

      if (!userScrolledRecently) {
        // Auto-scroll to bottom for new messages
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients && mounted) {
            _scrollToBottom();
          }
        });
      } else {
        // User scrolled recently, show notification badge
        setState(() {
          _hasNewMessages = true;
        });
      }
    }
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    context.read<ChatState>().sendPrivateMessage(widget.username, message);
    _messageController.clear();

    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final chatState = context.watch<ChatState>();
    final messages = chatState.privateChats[widget.username] ?? [];

    // Trigger check for new messages
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndScrollForNewMessages(messages.length);
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
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
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Messages list
              Expanded(
                child: messages.isEmpty
                    ? Center(
                        child: Text(
                          '${loc.startPrivateChat} with ${widget.username}',
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(8),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          return _buildMessageBubble(
                            message,
                            chatState.nickname,
                          );
                        },
                      ),
              ),
              // Message input
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: loc.typeMessage,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                        enabled:
                            chatState.connectionState ==
                            IrcConnectionState.connected,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed:
                          chatState.connectionState ==
                              IrcConnectionState.connected
                          ? _sendMessage
                          : null,
                      color: Theme.of(context).primaryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Scroll to bottom button
          if (_showScrollToBottomButton)
            Positioned(
              right: 16,
              bottom: 80,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  FloatingActionButton(
                    mini: true,
                    onPressed: _scrollToBottom,
                    child: const Icon(Icons.arrow_downward),
                  ),
                  if (_hasNewMessages)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.priority_high,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(IrcMessage message, String currentNick) {
    final isOwnMessage = message.sender == currentNick;
    final time =
        '${message.timestamp.hour.toString().padLeft(2, '0')}:'
        '${message.timestamp.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isOwnMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: Colors.grey.shade700,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isOwnMessage)
              SelectableText(
                message.sender,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade300,
                  fontSize: 12,
                ),
              ),
            Linkify(
              onOpen: (link) async {
                final url = Uri.parse(link.url);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              text: message.content,
              style: const TextStyle(color: Colors.white),
              linkStyle: TextStyle(
                color: Colors.blue.shade100,
                decoration: TextDecoration.underline,
              ),
            ),
            const SizedBox(height: 2),
            SelectableText(
              time,
              style: TextStyle(
                fontSize: 10,
                color: isOwnMessage
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
