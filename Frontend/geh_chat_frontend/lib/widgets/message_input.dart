import 'package:flutter/material.dart';

/// A reusable widget for message input with send button
class MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool enabled;
  final VoidCallback onSend;
  final Color? sendButtonColor;

  const MessageInput({
    super.key,
    required this.controller,
    required this.hintText,
    required this.enabled,
    required this.onSend,
    this.sendButtonColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              controller: controller,
              decoration: InputDecoration(
                hintText: hintText,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              onSubmitted: (_) => onSend(),
              enabled: enabled,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: enabled ? onSend : null,
            color: sendButtonColor ?? Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }
}
