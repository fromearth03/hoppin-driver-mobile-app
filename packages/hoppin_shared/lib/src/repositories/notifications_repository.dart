import '../api/api_client.dart';
import '../models/user_notification.dart';

/// Durable rider/driver notification history and read-state operations.
class NotificationsRepository {
  NotificationsRepository(this._api);

  final ApiClient _api;

  Future<List<UserNotification>> list({int limit = 50}) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/me/notifications',
      query: {'limit': limit},
    );
    final raw = response.data?['notifications'];
    if (raw is! List) return const <UserNotification>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(UserNotification.fromJson)
        .toList(growable: false);
  }

  Future<void> markRead(String id) async {
    await _api.patch<Map<String, dynamic>>('/me/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _api.post<Map<String, dynamic>>('/me/notifications/read-all');
  }
}
