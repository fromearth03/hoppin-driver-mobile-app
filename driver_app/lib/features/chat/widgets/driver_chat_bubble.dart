import 'package:flutter/material.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// One message in the driver's thread. `mine` is the driver's own message
/// (`m.senderId == authServiceProvider.userId`) — aligned right; the rider's is
/// aligned left. Laid out from `Home - Active Trip (chat).jpg`.
class DriverChatBubble extends StatelessWidget {
  /// Creates a chat bubble for [message]. [mine] is true when the driver sent
  /// it.
  const DriverChatBubble({required this.message, required this.mine, super.key});

  /// The message this bubble renders.
  final RideMessage message;

  /// True when the driver is the sender — aligns and colours it as the driver's
  /// side of the conversation.
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = mine
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.body, style: theme.textTheme.bodyMedium),
            if (message.createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  formatTime(message.createdAt!),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
