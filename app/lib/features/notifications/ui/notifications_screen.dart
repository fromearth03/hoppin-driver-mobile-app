import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/cursor_list.dart';
import '../data/models/app_notification.dart';
import '../logic/notifications_controller.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsControllerProvider);
    final controller = ref.read(notificationsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if ((async.value?.unreadCount ?? 0) > 0)
            TextButton(
              onPressed: controller.markAllRead,
              child: const Text('Mark all read'),
            ),
          if ((async.value?.notifications.length ?? 0) > 0)
            IconButton(
              tooltip: 'Clear all',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: controller.clearAll,
            ),
        ],
      ),
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: Text('$e', style: AppText.body)),
        data: (state) => CursorList<AppNotification>(
          items: state.notifications,
          hasMore: state.hasMore,
          isLoadingMore: state.isLoadingMore,
          onLoadMore: controller.loadMore,
          onRefresh: controller.refresh,
          emptyState: const AppEmptyState(
            icon: Icons.notifications_none,
            title: 'Nothing here yet',
            message: 'Updates about your trips and account will appear here.',
          ),
          itemBuilder: (context, n) => Dismissible(
            key: ValueKey(n.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              color: AppColors.negative,
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            onDismissed: (_) => controller.dismiss(n.id),
            child: ListTile(
              leading: Icon(
                n.read ? Icons.notifications_none : Icons.notifications_active,
                color: n.read ? AppColors.textSecondary : AppColors.primary,
              ),
              title: Text(n.title,
                  style: AppText.body.copyWith(
                      fontWeight: n.read ? FontWeight.w400 : FontWeight.w600)),
              subtitle: Text(
                '${n.ntfBody}\n${DateFormat('d MMM, HH:mm').format(n.createdAt.toLocal())}',
                style: AppText.caption,
              ),
              isThreeLine: true,
              onTap: () => controller.markRead(n.id),
            ),
          ),
        ),
      ),
    );
  }
}
