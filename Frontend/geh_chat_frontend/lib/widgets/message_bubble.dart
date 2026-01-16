import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/irc_service.dart';

/// A reusable widget for displaying chat message bubbles
/// Used in both MainChatScreen and PrivateChatScreen
class MessageBubble extends StatelessWidget {
  final IrcMessage message;
  final String currentNickname;
  final bool showSender;

  const MessageBubble({
    super.key,
    required this.message,
    required this.currentNickname,
    this.showSender = true,
  });

  @override
  Widget build(BuildContext context) {
    final isOwnMessage = message.sender == currentNickname;
    final formattedTime = _formatTime(message.timestamp);

    // System message style
    if (message.isSystem) {
      return _buildSystemMessage(context, formattedTime);
    }

    // Info message style (join/leave notifications with → or ←)
    if (message.sender == '→' || message.sender == '←') {
      return _buildInfoMessage(context, formattedTime);
    }

    return _buildUserMessage(context, isOwnMessage, formattedTime);
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildSystemMessage(BuildContext context, String time) {
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

  /// Build info message for join/leave notifications
  Widget _buildInfoMessage(BuildContext context, String time) {
    final isLeaving = message.sender == '←';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isLeaving
            ? Colors.orange.shade900.withValues(alpha: 0.3)
            : Colors.teal.shade900.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLeaving
              ? Colors.orange.shade700.withValues(alpha: 0.5)
              : Colors.teal.shade700.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message.sender,
            style: TextStyle(
              fontSize: 14,
              color: isLeaving ? Colors.orange.shade300 : Colors.teal.shade300,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: SelectableText(
              message.content,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade300,
                fontStyle: FontStyle.italic,
              ),
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

  Widget _buildUserMessage(
    BuildContext context,
    bool isOwnMessage,
    String time,
  ) {
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
            if (!isOwnMessage && showSender) _buildSenderName(),
            _buildMessageContent(),
            const SizedBox(height: 2),
            _buildTimeAndEncryption(isOwnMessage, time),
          ],
        ),
      ),
    );
  }

  Widget _buildSenderName() {
    return SelectableText(
      message.sender,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade300,
        fontSize: 12,
      ),
    );
  }

  Widget _buildMessageContent() {
    return Linkify(
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
    );
  }

  Widget _buildTimeAndEncryption(bool isOwnMessage, String time) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SelectableText(
          time,
          style: TextStyle(
            fontSize: 10,
            color: isOwnMessage
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.grey,
          ),
        ),
        if (message.isEncrypted) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: 'Wiadomość zaszyfrowana',
            child: Text(
              '🔒',
              style: TextStyle(fontSize: 10, color: Colors.green.shade300),
            ),
          ),
        ],
      ],
    );
  }
}
