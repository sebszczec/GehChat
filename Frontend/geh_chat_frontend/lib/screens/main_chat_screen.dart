import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_state.dart';
import '../services/irc_service.dart';
import '../l10n/app_localizations.dart';
import 'private_chat_screen.dart';
import 'connection_screen.dart';

class MainChatScreen extends StatefulWidget {
  const MainChatScreen({super.key});

  @override
  State<MainChatScreen> createState() => _MainChatScreenState();
}

class _MainChatScreenState extends State<MainChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showUsers = false;
  bool _showPrivateChats = false;
  bool _showScrollToBottomButton = false;
  DateTime? _lastUserScrollTime;
  bool _hasNewMessages = false;
  int _previousMessageCount = 0;
  late AnimationController _blinkController;
  ChatState? _chatState;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _scrollController.addListener(_scrollListener);
    // Schedule initial scroll after first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final chatState = context.read<ChatState>();
        _previousMessageCount = chatState.channelMessages.length;
        // Set main channel as active chat
        chatState.setActiveChat(null);
      }
    });
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
    if (_chatState != null) {
      _chatState!.setActiveChat(null);
    }
    _messageController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _blinkController.dispose();
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

  void _checkAndScrollForNewMessages() {
    final chatState = context.read<ChatState>();
    if (chatState.channelMessages.length > _previousMessageCount) {
      _previousMessageCount = chatState.channelMessages.length;

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

    context.read<ChatState>().sendChannelMessage(message);
    _messageController.clear();

    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _showUserOptions(BuildContext context, String username) {
    final loc = AppLocalizations.of(context);
    final chatState = context.read<ChatState>();

    // Don't show options for own username
    if (username == chatState.nickname) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat),
              title: Text(loc.startPrivateChat),
              onTap: () {
                Navigator.pop(context);
                chatState.startPrivateChat(username);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PrivateChatScreen(username: username),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final chatState = context.watch<ChatState>();

    // Trigger check for new messages
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndScrollForNewMessages();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(chatState.channel),
        actions: [
          // Disconnect button
          IconButton(
            icon: const Icon(Icons.power_settings_new),
            onPressed: () async {
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
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ConnectionScreen(),
                  ),
                );
              }
            },
            tooltip: loc.disconnect,
          ),
          // Connection status indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: _buildConnectionStatus(chatState.connectionState, loc),
            ),
          ),
          // Users toggle button
          Stack(
            children: [
              IconButton(
                icon: Icon(_showUsers ? Icons.people : Icons.people_outline),
                onPressed: () {
                  setState(() {
                    _showUsers = !_showUsers;
                    if (_showUsers) {
                      _showPrivateChats = false;
                    }
                  });
                },
              ),
              if (chatState.users
                      .where((user) => user != chatState.nickname).isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${chatState.users.where((user) => user != chatState.nickname).length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Private chats indicator
          if (chatState.privateChats.isNotEmpty)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.message),
                  onPressed: () {
                    setState(() {
                      _showPrivateChats = !_showPrivateChats;
                      if (_showPrivateChats) {
                        _showUsers = false;
                      }
                    });
                  },
                ),
                if (chatState.getUnreadChatsCount() > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${chatState.getUnreadChatsCount()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: Stack(
        children: [
          // Main chat area
          Column(
            children: [
              // Messages list
              Expanded(
                child: chatState.channelMessages.isEmpty
                    ? Center(
                        child: Text(
                          chatState.connectionState ==
                                  IrcConnectionState.connected
                              ? '${loc.mainChannel} (#vorest)'
                              : loc.connecting,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(8),
                        itemCount: chatState.channelMessages.length,
                        itemBuilder: (context, index) {
                          final message = chatState.channelMessages[index];
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
          // Users fullscreen overlay
          if (_showUsers)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.1),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () {
                            setState(() {
                              _showUsers = false;
                            });
                          },
                          tooltip: loc.hideUsers,
                        ),
                        Expanded(
                          child: Text(
                            '${loc.users} (${chatState.users.length})',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: chatState.users
                          .where((user) => user != chatState.nickname)
                          .length,
                      itemBuilder: (context, index) {
                        final filteredUsers = chatState.users
                            .where((user) => user != chatState.nickname)
                            .toList();
                        final user = filteredUsers[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).primaryColor,
                            child: Text(
                              user[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(user),
                          onTap: () {
                            chatState.startPrivateChat(user);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PrivateChatScreen(username: user),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          // Private chats fullscreen overlay
          if (_showPrivateChats)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.1),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () {
                            setState(() {
                              _showPrivateChats = false;
                            });
                          },
                          tooltip: loc.hidePrivateChats,
                        ),
                        Expanded(
                          child: Text(
                            loc.privateChats,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: chatState.privateChats.isEmpty
                        ? Center(
                            child: Text(
                              loc.noPrivateChats,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          )
                        : ListView.builder(
                            itemCount: chatState.privateChats.length,
                            itemBuilder: (context, index) {
                              final username = chatState.privateChats.keys
                                  .elementAt(index);
                              final messages =
                                  chatState.privateChats[username]!;
                              final unreadCount =
                                  chatState.unreadCounts[username] ?? 0;

                              return ListTile(
                                leading: CircleAvatar(
                                  child: Text(username[0].toUpperCase()),
                                ),
                                title: Text(username),
                                subtitle: Text(
                                  messages.isNotEmpty
                                      ? messages.last.content
                                      : loc.noMessagesYet,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: unreadCount > 0
                                    ? CircleAvatar(
                                        radius: 12,
                                        backgroundColor: Colors.red,
                                        child: Text(
                                          '$unreadCount',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                          ),
                                        ),
                                      )
                                    : null,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          PrivateChatScreen(username: username),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          // Scroll to bottom button
          if (_showScrollToBottomButton && !_showUsers && !_showPrivateChats)
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

  Widget _buildConnectionStatus(
    IrcConnectionState state,
    AppLocalizations loc,
  ) {
    IconData icon;
    Color color;
    String text;

    switch (state) {
      case IrcConnectionState.connected:
        icon = Icons.circle;
        color = Colors.green;
        text = loc.connected;
        break;
      case IrcConnectionState.joiningChannel:
        icon = Icons.circle;
        color = Colors.blue;
        text = 'Łączę z serwerem';
        break;
      case IrcConnectionState.connecting:
        icon = Icons.circle;
        color = Colors.orange;
        text = loc.connecting;
        break;
      case IrcConnectionState.error:
        icon = Icons.error;
        color = Colors.red;
        text = loc.connectionError;
        break;
      case IrcConnectionState.disconnected:
        icon = Icons.circle;
        color = Colors.grey;
        text = loc.disconnected;
        break;
    }

    // Animacja migania dla stanu joiningChannel
    Widget iconWidget = Icon(icon, size: 12, color: color);
    if (state == IrcConnectionState.joiningChannel) {
      iconWidget = AnimatedBuilder(
        animation: _blinkController,
        builder: (context, child) {
          return Opacity(
            opacity: 0.3 + (_blinkController.value * 0.7),
            child: Icon(icon, size: 12, color: color),
          );
        },
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconWidget,
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  Widget _buildMessageBubble(IrcMessage message, String currentNick) {
    final isOwnMessage = message.sender == currentNick;
    final time =
        '${message.timestamp.hour.toString().padLeft(2, '0')}:'
        '${message.timestamp.minute.toString().padLeft(2, '0')}';

    // System message style
    if (message.isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: SelectableText(
                message.content,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            SelectableText(
              time,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

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
                final uri = Uri.parse(link.url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
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
