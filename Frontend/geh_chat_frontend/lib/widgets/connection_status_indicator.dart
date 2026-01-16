import 'package:flutter/material.dart';
import '../services/irc_service.dart';
import '../l10n/app_localizations.dart';

/// Widget showing the current connection status indicator
class ConnectionStatusIndicator extends StatelessWidget {
  final IrcConnectionState state;
  final Animation<double>? blinkAnimation;

  const ConnectionStatusIndicator({
    super.key,
    required this.state,
    this.blinkAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final statusData = _getStatusData(loc);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIcon(statusData),
            const SizedBox(width: 4),
            Text(
              statusData.text,
              style: TextStyle(fontSize: 12, color: statusData.color),
            ),
          ],
        ),
      ),
    );
  }

  _StatusData _getStatusData(AppLocalizations loc) {
    switch (state) {
      case IrcConnectionState.connected:
        return _StatusData(
          icon: Icons.circle,
          color: Colors.green,
          text: loc.connected,
        );
      case IrcConnectionState.joiningChannel:
        return _StatusData(
          icon: Icons.circle,
          color: Colors.blue,
          text: 'Łączę z serwerem',
        );
      case IrcConnectionState.connecting:
        return _StatusData(
          icon: Icons.circle,
          color: Colors.orange,
          text: loc.connecting,
        );
      case IrcConnectionState.error:
        return _StatusData(
          icon: Icons.error,
          color: Colors.red,
          text: loc.connectionError,
        );
      case IrcConnectionState.disconnected:
        return _StatusData(
          icon: Icons.circle,
          color: Colors.grey,
          text: loc.disconnected,
        );
    }
  }

  Widget _buildIcon(_StatusData data) {
    Widget iconWidget = Icon(data.icon, size: 12, color: data.color);

    // Blinking animation for joiningChannel state
    if (state == IrcConnectionState.joiningChannel && blinkAnimation != null) {
      return AnimatedBuilder(
        animation: blinkAnimation!,
        builder: (context, child) {
          return Opacity(
            opacity: 0.3 + (blinkAnimation!.value * 0.7),
            child: Icon(data.icon, size: 12, color: data.color),
          );
        },
      );
    }

    return iconWidget;
  }
}

class _StatusData {
  final IconData icon;
  final Color color;
  final String text;

  _StatusData({required this.icon, required this.color, required this.text});
}
