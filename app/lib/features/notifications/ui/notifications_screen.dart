import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/nav/app_shell.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/cursor_list.dart';
import '../data/models/app_notification.dart';
import '../logic/notifications_controller.dart';

/// Which slice of the centre is on screen. The endpoint has no read filter,
/// so this filters the page already loaded rather than refetching.
enum NotificationFilter { all, read, unread }

final notificationFilterProvider =
    StateProvider<NotificationFilter>((ref) => NotificationFilter.all);

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsControllerProvider);
    final controller = ref.read(notificationsControllerProvider.notifier);
    final filter = ref.watch(notificationFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleSpacing: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back,
                    color: AppColors.textPrimary, size: 26),
                onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.home),
              )
            : null,
        title: Text('Notifications', style: AppText.title.copyWith(fontSize: 24)),
        actions: [
          if ((async.value?.unreadCount ?? 0) > 0)
            TextButton(
              onPressed: controller.markAllRead,
              child: Text('Mark all read',
                  style: AppText.caption.copyWith(color: AppColors.primary)),
            ),
        ],
      ),
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: Text('$e', style: AppText.body)),
        data: (state) {
          final visible = switch (filter) {
            NotificationFilter.all => state.notifications,
            NotificationFilter.read =>
              state.notifications.where((n) => n.read).toList(),
            NotificationFilter.unread =>
              state.notifications.where((n) => !n.read).toList(),
          };

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    16, 4, 16, AppShell.bottomClearance),
                child: _FilterBar(
                  value: filter,
                  onChanged: (f) =>
                      ref.read(notificationFilterProvider.notifier).state = f,
                ),
              ),
              Expanded(
                child: CursorList<AppNotification>(
                  items: visible,
                  hasMore: state.hasMore,
                  isLoadingMore: state.isLoadingMore,
                  onLoadMore: controller.loadMore,
                  onRefresh: controller.refresh,
                  emptyState: const AppEmptyState(
                    icon: Icons.notifications_none,
                    title: 'Nothing here yet',
                    message:
                        'Updates about your trips and account will appear here.',
                  ),
                  itemBuilder: (context, n) {
                    final i = visible.indexOf(n);
                    final previous = i > 0 ? visible[i - 1] : null;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // The design heads each day's run with its date. The
                        // header is drawn only when the day changes, so a
                        // single day's feed carries one "Today" and no repeats.
                        if (previous == null ||
                            !_sameDay(previous.createdAt, n.createdAt))
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                            child: Text(_dayLabel(n.createdAt),
                                style: AppText.title.copyWith(fontSize: 20)),
                          ),
                        _NotificationTile(
                          notification: n,
                          onTap: () => controller.markRead(n.id),
                          onDismissed: () => controller.dismiss(n.id),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The three-way pill from the design: the selected segment is a filled
/// indigo capsule, the rest sit on white with a hairline between them.
class _FilterBar extends StatelessWidget {
  final NotificationFilter value;
  final ValueChanged<NotificationFilter> onChanged;

  const _FilterBar({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(27),
        ),
        child: Row(
          children: [
            _segment(NotificationFilter.all, 'All'),
            _separator(NotificationFilter.all, NotificationFilter.read),
            _segment(NotificationFilter.read, 'Read'),
            _separator(NotificationFilter.read, NotificationFilter.unread),
            _segment(NotificationFilter.unread, 'Unread'),
          ],
        ),
      );

  Widget _segment(NotificationFilter f, String label) {
    final selected = f == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(f),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.textPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(27),
          ),
          child: Text(
            label,
            style: AppText.body.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  /// The design draws a hairline only between two unselected segments — the
  /// filled capsule supplies its own edge.
  Widget _separator(NotificationFilter a, NotificationFilter b) => SizedBox(
        width: 1,
        height: 26,
        child: ColoredBox(
          color: (value == a || value == b)
              ? Colors.transparent
              : AppColors.border,
        ),
      );
}

bool _sameDay(DateTime a, DateTime b) {
  final x = a.toLocal();
  final y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

/// "Today" and "Yesterday" read better than a date the driver has to work
/// out; anything older gets the date itself.
String _dayLabel(DateTime when) {
  final now = DateTime.now();
  if (_sameDay(when, now)) return 'Today';
  if (_sameDay(when, now.subtract(const Duration(days: 1)))) {
    return 'Yesterday';
  }
  return DateFormat('d MMMM').format(when.toLocal());
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismissed,
  });

  /// The accent stripe down the left edge.
  ///
  /// The design gives each row its own colour — indigo for a trip, orange for
  /// an expiring document, green for a rating. The service writes only two
  /// values into `type`: `trip` and `system`. There is no document, rating,
  /// payout or penalty type, so the other three colours have nothing to key
  /// off and are not invented; everything that is not a trip is `system` and
  /// takes the neutral stripe.
  Color get _accent => switch (notification.type) {
        'trip' => AppColors.textPrimary,
        _ => AppColors.info,
      };

  @override
  Widget build(BuildContext context) => Dismissible(
        key: ValueKey(notification.id),
        direction: DismissDirection.endToStart,
        background: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: AppColors.negative,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        onDismissed: (_) => onDismissed(),
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 6, child: ColoredBox(color: _accent)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification.title,
                            style: AppText.body.copyWith(
                              fontSize: 18,
                              fontWeight: notification.read
                                  ? FontWeight.w500
                                  : FontWeight.w600,
                            ),
                          ),
                          if (notification.ntfBody.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(notification.ntfBody,
                                style: AppText.bodySecondary),
                          ],
                          const SizedBox(height: 4),
                          // Time only: the day is already the group header
                          // above, so repeating the date on every row would
                          // be noise.
                          Text(
                            DateFormat('HH:mm')
                                .format(notification.createdAt.toLocal()),
                            style: AppText.caption
                                .copyWith(color: AppColors.textDisabled),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
