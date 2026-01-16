import 'package:flutter/material.dart';

/// Mixin providing scroll management functionality for chat screens
/// Handles auto-scrolling, scroll-to-bottom button, and new message detection
mixin ChatScrollMixin<T extends StatefulWidget> on State<T> {
  late ScrollController scrollController;
  bool showScrollToBottomButton = false;
  DateTime? lastUserScrollTime;
  bool hasNewMessages = false;
  int previousMessageCount = 0;

  /// Initialize the scroll controller and listener
  void initScrollController() {
    scrollController = ScrollController();
    scrollController.addListener(_scrollListener);
  }

  /// Dispose the scroll controller
  void disposeScrollController() {
    scrollController.removeListener(_scrollListener);
    scrollController.dispose();
  }

  void _scrollListener() {
    if (scrollController.hasClients) {
      // Track user scroll
      if (scrollController.position.isScrollingNotifier.value) {
        lastUserScrollTime = DateTime.now();
      }

      final isAtBottom =
          scrollController.position.pixels >=
          scrollController.position.maxScrollExtent - 50;

      if (showScrollToBottomButton == isAtBottom) {
        setState(() {
          showScrollToBottomButton = !isAtBottom;
        });
      }
    }
  }

  /// Scroll to the bottom of the list
  void scrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      setState(() {
        hasNewMessages = false;
      });
    }
  }

  /// Check if we should auto-scroll for new messages
  void checkAndScrollForNewMessages(int currentMessageCount) {
    if (currentMessageCount > previousMessageCount) {
      previousMessageCount = currentMessageCount;

      final userScrolledRecently =
          lastUserScrollTime != null &&
          DateTime.now().difference(lastUserScrollTime!) <
              const Duration(seconds: 2);

      if (!userScrolledRecently) {
        // Auto-scroll to bottom for new messages
        Future.delayed(const Duration(milliseconds: 100), () {
          if (scrollController.hasClients && mounted) {
            scrollToBottom();
          }
        });
      } else {
        // User scrolled recently, show notification badge
        setState(() {
          hasNewMessages = true;
        });
      }
    }
  }

  /// Delayed scroll to bottom (for after sending a message)
  void delayedScrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), scrollToBottom);
  }
}
