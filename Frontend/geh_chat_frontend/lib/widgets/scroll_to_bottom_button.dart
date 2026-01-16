import 'package:flutter/material.dart';

/// A floating action button that appears when user scrolls up
/// Shows a badge if there are new messages
class ScrollToBottomButton extends StatelessWidget {
  final bool visible;
  final bool hasNewMessages;
  final VoidCallback onPressed;

  const ScrollToBottomButton({
    super.key,
    required this.visible,
    required this.hasNewMessages,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }

    return Positioned(
      right: 16,
      bottom: 80,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          FloatingActionButton(
            mini: true,
            onPressed: onPressed,
            child: const Icon(Icons.arrow_downward),
          ),
          if (hasNewMessages)
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
    );
  }
}
