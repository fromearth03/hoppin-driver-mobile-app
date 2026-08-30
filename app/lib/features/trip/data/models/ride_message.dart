enum MessageStatus { sent, read }

class RideMessage {
  final String id;
  final String body;
  final String senderRole;
  final MessageStatus status;
  final String? replyToId;
  final String? replyToBody;
  final DateTime createdAt;

  const RideMessage({
    required this.id,
    required this.body,
    required this.senderRole,
    required this.createdAt,
    this.status = MessageStatus.sent,
    this.replyToId,
    this.replyToBody,
  });

  bool get isMine => senderRole == 'driver';

  factory RideMessage.fromJson(Map<String, dynamic> json) {
    final reply = json['reply_to'] as Map?;
    return RideMessage(
      id: json['id'] as String,
      body: (json['body'] as String?) ?? '',
      senderRole: (json['sender_role'] as String?) ?? '',
      status: switch (json['status'] as String?) {
        'read' => MessageStatus.read,
        // Anything unrecognised is treated as merely sent — claiming a
        // message was read when we do not know is the worse error.
        _ => MessageStatus.sent,
      },
      replyToId: (json['reply_to_id'] ?? reply?['id']) as String?,
      replyToBody: reply?['body'] as String?,
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}
