class AppNotification {
  final String id;
  final String? type;
  final String title;
  final String ntfBody;
  final String? rideId;
  final String? deepLink;
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.createdAt,
    this.type,
    this.ntfBody = '',
    this.rideId,
    this.deepLink,
    this.read = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        type: json['type'] as String?,
        title: (json['title'] as String?) ?? '',
        ntfBody: (json['body'] as String?) ?? '',
        rideId: json['ride_id'] as String?,
        deepLink: json['deep_link'] as String?,
        // The server sends both a boolean and a timestamp; either being
        // present means read.
        read: (json['read'] as bool?) ?? (json['read_at'] != null),
        createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ??
            DateTime.now(),
      );
}

class NotificationsPage {
  final List<AppNotification> notifications;
  final String? nextCursor;
  final bool hasMore;

  const NotificationsPage({
    required this.notifications,
    this.nextCursor,
    this.hasMore = false,
  });

  factory NotificationsPage.fromJson(Map<String, dynamic> json) =>
      NotificationsPage(
        notifications: ((json['notifications'] as List?) ?? const [])
            .map((e) =>
                AppNotification.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        nextCursor: json['next_cursor'] as String?,
        hasMore: json['has_more'] as bool? ?? false,
      );
}
