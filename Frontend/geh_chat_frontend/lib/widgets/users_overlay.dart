import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../screens/private_chat_screen.dart';

/// Fullscreen overlay showing list of users in the channel
class UsersOverlay extends StatelessWidget {
  final List<String> users;
  final String currentNickname;
  final VoidCallback onClose;
  final void Function(String username) onStartPrivateChat;
  final bool Function(String username) hasEncryptedSession;

  const UsersOverlay({
    super.key,
    required this.users,
    required this.currentNickname,
    required this.onClose,
    required this.onStartPrivateChat,
    required this.hasEncryptedSession,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final filteredUsers = users
        .where((user) => user != currentNickname)
        .toList();

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          _buildHeader(context, loc, filteredUsers.length),
          Expanded(
            child: ListView.builder(
              itemCount: filteredUsers.length,
              itemBuilder: (context, index) {
                final user = filteredUsers[index];
                return _buildUserTile(context, user);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations loc, int count) {
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
            tooltip: loc.hideUsers,
          ),
          Expanded(
            child: Text(
              '${loc.users} ($count)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(BuildContext context, String user) {
    final isEncrypted = hasEncryptedSession(user);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).primaryColor,
        child: Text(
          user[0].toUpperCase(),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(user),
      trailing: isEncrypted
          ? Tooltip(
              message: AppLocalizations.of(context).encryptedConnection,
              child: Icon(Icons.lock, size: 20, color: Colors.green[600]),
            )
          : null,
      onTap: () {
        onStartPrivateChat(user);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PrivateChatScreen(username: user),
          ),
        );
      },
    );
  }
}
