import 'package:flutter/foundation.dart';

/// A notification persisted by the ride service for one rider or driver.
@immutable
class UserNotification {
  const UserNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.rideId,
    this.deepLink,
    this.readAt,
  });

  factory UserNotification.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse(json['created_at'] as String? ?? '');
    if (createdAt == null) {
      throw const FormatException('notification created_at is invalid');
    }
    final readAt = json['read_at'] as String?;
    return UserNotification(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'alert',
      title: json['title'] as String? ?? 'Hoppin',
      body: json['body'] as String? ?? '',
      createdAt: createdAt.toLocal(),
      rideId: json['ride_id'] as String?,
      deepLink: json['deep_link'] as String?,
      readAt: readAt == null ? null : DateTime.tryParse(readAt)?.toLocal(),
    );
  }

  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? rideId;
  final String? deepLink;
  final DateTime? readAt;

  bool get isRead => readAt != null;
}
