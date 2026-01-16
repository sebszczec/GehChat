import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/irc_service.dart';
import '../screens/private_chat_screen.dart';

/// Fullscreen overlay showing list of private chats
class PrivateChatsOverlay extends StatelessWidget {
  final Map<String, List<IrcMessage>> privateChats;
  final Map<String, int> unreadCounts;
  final VoidCallback onClose;

  const PrivateChatsOverlay({
    super.key,
    required this.privateChats,
    required this.unreadCounts,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          _buildHeader(context, loc),
          Expanded(
            child: privateChats.isEmpty
                ? _buildEmptyState(context, loc)
                : _buildChatsList(context, loc),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations loc) {
    return Container(
      padding: const EdgeInsets.all(8),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: onClose,
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
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations loc) {
    return Center(
      child: Text(
        loc.noPrivateChats,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Widget _buildChatsList(BuildContext context, AppLocalizations loc) {
    final chatUsernames = privateChats.keys.toList();

    return ListView.builder(
      itemCount: chatUsernames.length,
      itemBuilder: (context, index) {
        final username = chatUsernames[index];
        final messages = privateChats[username]!;
        final unreadCount = unreadCounts[username] ?? 0;

        return _buildChatTile(context, loc, username, messages, unreadCount);
      },
    );
  }

  Widget _buildChatTile(
    BuildContext context,
    AppLocalizations loc,
    String username,
    List<IrcMessage> messages,
    int unreadCount,
  ) {
    return ListTile(
      leading: CircleAvatar(child: Text(username[0].toUpperCase())),
      title: Text(username),
      subtitle: Text(
        messages.isNotEmpty ? messages.last.content : loc.noMessagesYet,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: unreadCount > 0
          ? CircleAvatar(
              radius: 12,
              backgroundColor: Colors.red,
              child: Text(
                '$unreadCount',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            )
          : null,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PrivateChatScreen(username: username),
          ),
        );
      },
    );
  }
}
