import 'package:freezed_annotation/freezed_annotation.dart';

part 'support_ticket.freezed.dart';
part 'support_ticket.g.dart';

/// A support ticket / complaint — `/me/support-tickets` (docs/04). The list
/// shape isn't exhaustively documented, so non-essential fields are nullable
/// and unknown keys are ignored.
@freezed
abstract class SupportTicket with _$SupportTicket {
  const factory SupportTicket({
    required String id,
    String? subject,
    String? category,
    @JsonKey(name: 'type_code') String? typeCode,
    String? priority,
    @JsonKey(name: 'ride_id') String? rideId,
    @Default('open') String status,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _SupportTicket;

  factory SupportTicket.fromJson(Map<String, dynamic> json) =>
      _$SupportTicketFromJson(json);
}

/// One message in a ticket thread — `GET /me/support-tickets/:id`.
@freezed
abstract class TicketMessage with _$TicketMessage {
  const factory TicketMessage({
    required String id,
    @JsonKey(name: 'ticket_id') String? ticketId,
    @JsonKey(name: 'author_id') String? authorId,
    @JsonKey(name: 'is_staff') @Default(false) bool isStaff,
    required String body,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _TicketMessage;

  factory TicketMessage.fromJson(Map<String, dynamic> json) =>
      _$TicketMessageFromJson(json);
}

/// `GET /me/support-tickets/:id` → `{ ticket: {…}, messages: [...] }`.
@freezed
abstract class TicketThread with _$TicketThread {
  const factory TicketThread({
    required SupportTicket ticket,
    @Default(<TicketMessage>[]) List<TicketMessage> messages,
  }) = _TicketThread;

  factory TicketThread.fromJson(Map<String, dynamic> json) =>
      _$TicketThreadFromJson(json);
}
