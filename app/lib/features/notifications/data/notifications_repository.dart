import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/app_notification.dart';

/// The notification centre.
///
/// This endpoint is the history — the list is never assembled from received
/// pushes, because a push dropped by an OEM battery manager would then leave
/// a permanent hole in it.
class NotificationsRepository {
  final ApiClient _api;
  NotificationsRepository(this._api);

  Future<Result<NotificationsPage>> page(
      {String? cursor, int limit = 50}) async {
    final r = await _api.get<Map<String, dynamic>>('/me/notifications', query: {
      'limit': limit,
      if (cursor != null) 'cursor': cursor,
    });
    return r.when(
      ok: (json) => Ok(NotificationsPage.fromJson(json)),
      err: (e) => Err(e),
    );
  }

  Future<Result<void>> markRead(String id) async {
    final r = await _api.patch<dynamic>('/me/notifications/$id/read');
    return r.when(ok: (_) => const Ok(null), err: (e) => Err(e));
  }

  Future<Result<void>> markAllRead() async {
    final r = await _api.post<dynamic>('/me/notifications/read-all');
    return r.when(ok: (_) => const Ok(null), err: (e) => Err(e));
  }

  Future<Result<void>> dismiss(String id) async {
    final r = await _api.delete<dynamic>('/me/notifications/$id');
    return r.when(ok: (_) => const Ok(null), err: (e) => Err(e));
  }

  Future<Result<void>> clearAll() async {
    final r = await _api.delete<dynamic>('/me/notifications');
    return r.when(ok: (_) => const Ok(null), err: (e) => Err(e));
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
    (ref) => NotificationsRepository(ref.watch(apiClientProvider)));
