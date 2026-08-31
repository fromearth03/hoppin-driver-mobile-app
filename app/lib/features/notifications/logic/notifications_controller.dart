import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../data/models/app_notification.dart';
import '../data/notifications_repository.dart';

class NotificationsState {
  final List<AppNotification> notifications;
  final String? nextCursor;
  final bool isLoadingMore;
  final ApiException? error;

  /// The server's count across the whole feed. Counting the loaded pages
  /// instead would under-report the moment there is more than one page.
  final int unreadCount;

  const NotificationsState({
    this.notifications = const [],
    this.nextCursor,
    this.isLoadingMore = false,
    this.error,
    this.unreadCount = 0,
  });

  bool get hasMore => nextCursor != null;

  NotificationsState copyWith({
    List<AppNotification>? notifications,
    String? nextCursor,
    bool? isLoadingMore,
    ApiException? error,
    int? unreadCount,
    bool clearCursor = false,
  }) =>
      NotificationsState(
        notifications: notifications ?? this.notifications,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: error ?? this.error,
        unreadCount: unreadCount ?? this.unreadCount,
      );
}

class NotificationsController extends AsyncNotifier<NotificationsState> {
  bool _disposed = false;

  @override
  Future<NotificationsState> build() async {
    ref.onDispose(() => _disposed = true);
    return _fetch();
  }

  NotificationsState get _current => state.value ?? const NotificationsState();

  void _emit(NotificationsState next) {
    if (_disposed) return;
    state = AsyncData(next);
  }

  Future<NotificationsState> _fetch() async {
    final result = await ref.read(notificationsRepositoryProvider).page();
    return result.when(
      ok: (page) => NotificationsState(
        notifications: page.notifications,
        nextCursor: page.nextCursor,
        unreadCount: page.unreadCount,
      ),
      err: (e) => NotificationsState(error: e),
    );
  }

  Future<void> refresh() async {
    final next = await _fetch();
    _emit(next);
  }

  Future<void> loadMore() async {
    final cursor = _current.nextCursor;
    if (cursor == null || _current.isLoadingMore) return;

    _emit(_current.copyWith(isLoadingMore: true));
    final result =
        await ref.read(notificationsRepositoryProvider).page(cursor: cursor);
    if (_disposed) return;
    result.when(
      ok: (page) => _emit(_current.copyWith(
        notifications: [..._current.notifications, ...page.notifications],
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        isLoadingMore: false,
        unreadCount: page.unreadCount,
      )),
      err: (e) => _emit(_current.copyWith(isLoadingMore: false, error: e)),
    );
  }

  Future<void> markRead(String id) async {
    await ref.read(notificationsRepositoryProvider).markRead(id);
    if (_disposed) return;
    await refresh();
  }

  Future<void> markAllRead() async {
    await ref.read(notificationsRepositoryProvider).markAllRead();
    if (_disposed) return;
    await refresh();
  }

  Future<void> dismiss(String id) async {
    await ref.read(notificationsRepositoryProvider).dismiss(id);
    if (_disposed) return;
    await refresh();
  }

  Future<void> clearAll() async {
    await ref.read(notificationsRepositoryProvider).clearAll();
    if (_disposed) return;
    await refresh();
  }
}

final notificationsControllerProvider =
    AsyncNotifierProvider<NotificationsController, NotificationsState>(
        NotificationsController.new);
