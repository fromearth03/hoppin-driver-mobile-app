import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import 'notification_feed.dart';

/// Which slice of the feed the segmented control is showing.
enum DriverNotificationFilter {
  /// Everything this session saw.
  all,

  /// Only the ones already read.
  read,

  /// Only the ones not yet read.
  unread,
}

/// The driver's notification centre (PS-05, Figma `Notifications.jpg`).
///
/// Shows the SESSION feed — the local driver-lifecycle events this client
/// actually saw arrive — day-sectioned, filterable, with the honest #68 history
/// disclosure pinned on every branch.
///
/// 🔴 THREE THINGS IT DELIBERATELY DOES NOT DO.
///
/// Push delivery is additive; history comes from the API. Delete-all remains
/// disabled until a server retention contract is added.
class DriverNotificationCentreScreen extends ConsumerStatefulWidget {
  /// Creates the driver notification centre.
  const DriverNotificationCentreScreen({super.key});

  @override
  ConsumerState<DriverNotificationCentreScreen> createState() =>
      _DriverNotificationCentreScreenState();
}

class _DriverNotificationCentreScreenState
    extends ConsumerState<DriverNotificationCentreScreen> {
  DriverNotificationFilter _filter = DriverNotificationFilter.all;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final feed = ref.watch(driverNotificationFeedProvider);
    final history = ref.watch(driverNotificationHistoryProvider);
    ref.listen(driverNotificationHistoryProvider, (_, next) {
      next.whenData(
        (items) => ref
            .read(driverNotificationFeedProvider.notifier)
            .mergeHistory(items),
      );
    });

    final shown = switch (_filter) {
      DriverNotificationFilter.all => feed,
      DriverNotificationFilter.read => feed.where((n) => n.read).toList(),
      DriverNotificationFilter.unread => feed.where((n) => !n.read).toList(),
    };

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HopTopBar(
              title: 'Notifications',
              // NEVER null. A null back intent HIDES the chevron entirely, and
              // this screen is reached with `context.go`, which REPLACES rather
              // than pushes — so there is nothing to pop, the button vanishes,
              // and the driver is stranded here. Pop when there is a stack;
              // otherwise fall back to the dashboard, which is home.
              onBack: () => context.canPop() ? context.pop() : context.go('/'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: hoppin.spacing.gutter,
                vertical: hoppin.spacing.sm,
              ),
              child: _FilterBar(
                value: _filter,
                onChanged: (f) => setState(() => _filter = f),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  hoppin.spacing.gutter,
                  0,
                  hoppin.spacing.gutter,
                  hoppin.spacing.xl,
                ),
                children: [
                  if (history.isLoading && feed.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ..._sections(context, shown),
                  if (history.hasError && feed.isEmpty)
                    _HistoryLoadError(
                      onRetry: () =>
                          ref.invalidate(driverNotificationHistoryProvider),
                    ),

                  SizedBox(height: hoppin.spacing.md),

                  // Deletion is intentionally not exposed until a server
                  // retention contract exists. Read-state is fully wired.
                  const HopButton.secondary(
                    label: 'Delete all notifications',
                    onPressed: null,
                  ),
                  SizedBox(height: hoppin.spacing.sm),

                  HopButton.secondary(
                    label: 'Mark all as read',
                    onPressed: () => ref
                        .read(driverNotificationFeedProvider.notifier)
                        .markAllRead(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Day-sectioned cards ("Today" / "Yesterday" / a date), newest first.
  ///
  /// Returns an EMPTY list when there is nothing — deliberately. The empty
  /// branch renders the disclosure rung and nothing else; there is no
  /// "you have nothing" copy to fall back to, because that claim is not ours
  /// to make.
  List<Widget> _sections(
    BuildContext context,
    List<DriverAppNotification> items,
  ) {
    if (items.isEmpty) return const <Widget>[];

    final hoppin = context.hoppin;
    final widgets = <Widget>[];
    String? currentSection;

    for (final n in items) {
      final section = _dayLabel(n.receivedAt);
      if (section != currentSection) {
        currentSection = section;
        widgets
          ..add(SizedBox(height: hoppin.spacing.md))
          ..add(
            Text(
              section,
              style: hoppin.type.titleSmall.copyWith(
                color: hoppin.colors.textMid,
              ),
            ),
          )
          ..add(SizedBox(height: hoppin.spacing.sm));
      }
      widgets
        ..add(_NotificationCard(notification: n))
        ..add(SizedBox(height: hoppin.spacing.sm));
    }
    return widgets;
  }

  static String _dayLabel(DateTime at) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final delta = today.difference(day).inDays;
    if (delta <= 0) return 'Today';
    if (delta == 1) return 'Yesterday';
    return '${day.day}/${day.month}/${day.year}';
  }
}

class _HistoryLoadError extends StatelessWidget {
  const _HistoryLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => HopCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notifications could not be loaded',
          style: context.hoppin.type.titleSmall,
        ),
        SizedBox(height: context.hoppin.spacing.sm),
        HopButton.secondary(label: 'Retry', onPressed: onRetry),
      ],
    ),
  );
}

/// The All / Read / Unread segmented control.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.value, required this.onChanged});

  final DriverNotificationFilter value;
  final ValueChanged<DriverNotificationFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    Widget segment(DriverNotificationFilter f, String label) {
      final selected = f == value;
      return Expanded(
        child: InkWell(
          onTap: () => onChanged(f),
          borderRadius: BorderRadius.circular(hoppin.radii.pill),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: hoppin.spacing.sm),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? colors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(hoppin.radii.pill),
            ),
            child: Text(
              label,
              style: hoppin.type.label.copyWith(
                color: selected ? colors.onAccent : colors.textMid,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(hoppin.spacing.xs),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(hoppin.radii.pill),
      ),
      child: Row(
        children: [
          segment(DriverNotificationFilter.all, 'All'),
          segment(DriverNotificationFilter.read, 'Read'),
          segment(DriverNotificationFilter.unread, 'Unread'),
        ],
      ),
    );
  }
}

/// One notification card: unread dot + title + body + dismiss icon.
class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.notification});

  final DriverAppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    return HopCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: hoppin.spacing.xs),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: notification.read ? Colors.transparent : colors.error,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: hoppin.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: hoppin.type.titleSmall.copyWith(color: colors.textHi),
                ),
                if (notification.body != null) ...[
                  SizedBox(height: hoppin.spacing.xs),
                  Text(
                    notification.body!,
                    style: hoppin.type.bodySmall.copyWith(
                      color: colors.textMid,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: hoppin.spacing.xs),
          IconButton(
            key: Key('notification-dismiss-${notification.id}'),
            onPressed: () => ref
                .read(driverNotificationFeedProvider.notifier)
                .dismiss(notification.id),
            icon: Icon(Icons.delete_outline, size: 20, color: colors.textMid),
            tooltip: 'Dismiss',
            padding: EdgeInsets.zero,
            // 44x44 is the floor, not a preference: a driver dismisses these
            // one-handed, often in a cradle. The old 32x32 box was under it and
            // sat right beside the card's own tap area, so a near-miss hit the
            // card instead of the control it was aimed at.
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ],
      ),
    );
  }
}
