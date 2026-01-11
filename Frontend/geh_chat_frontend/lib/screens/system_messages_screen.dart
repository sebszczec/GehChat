import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_state.dart';
import '../services/irc_service.dart';
import '../l10n/app_localizations.dart';

class SystemMessagesScreen extends StatefulWidget {
  const SystemMessagesScreen({super.key});

  @override
  State<SystemMessagesScreen> createState() => _SystemMessagesScreenState();
}

class _SystemMessagesScreenState extends State<SystemMessagesScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Scroll to bottom after first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final chatState = context.watch<ChatState>();
    final systemMessages = chatState.systemMessages;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(loc.systemMessages),
      ),
      body: systemMessages.isEmpty
          ? Center(
              child: Text(
                loc.noSystemMessages,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: systemMessages.length,
              itemBuilder: (context, index) {
                final message = systemMessages[index];
                return _buildSystemMessageItem(message);
              },
            ),
    );
  }

  Widget _buildSystemMessageItem(IrcMessage message) {
    final time =
        '${message.timestamp.hour.toString().padLeft(2, '0')}:'
        '${message.timestamp.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              message.content,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade300),
            ),
          ),
          const SizedBox(width: 8),
          SelectableText(
            time,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
