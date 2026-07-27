// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'support_ticket.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SupportTicket _$SupportTicketFromJson(Map<String, dynamic> json) =>
    _SupportTicket(
      id: json['id'] as String,
      subject: json['subject'] as String?,
      category: json['category'] as String?,
      typeCode: json['type_code'] as String?,
      priority: json['priority'] as String?,
      rideId: json['ride_id'] as String?,
      status: json['status'] as String? ?? 'open',
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$SupportTicketToJson(_SupportTicket instance) =>
    <String, dynamic>{
      'id': instance.id,
      'subject': instance.subject,
      'category': instance.category,
      'type_code': instance.typeCode,
      'priority': instance.priority,
      'ride_id': instance.rideId,
      'status': instance.status,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

_TicketMessage _$TicketMessageFromJson(Map<String, dynamic> json) =>
    _TicketMessage(
      id: json['id'] as String,
      ticketId: json['ticket_id'] as String?,
      authorId: json['author_id'] as String?,
      isStaff: json['is_staff'] as bool? ?? false,
      body: json['body'] as String,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$TicketMessageToJson(_TicketMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'ticket_id': instance.ticketId,
      'author_id': instance.authorId,
      'is_staff': instance.isStaff,
      'body': instance.body,
      'created_at': instance.createdAt?.toIso8601String(),
    };

_TicketThread _$TicketThreadFromJson(Map<String, dynamic> json) =>
    _TicketThread(
      ticket: SupportTicket.fromJson(json['ticket'] as Map<String, dynamic>),
      messages:
          (json['messages'] as List<dynamic>?)
              ?.map((e) => TicketMessage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <TicketMessage>[],
    );

Map<String, dynamic> _$TicketThreadToJson(_TicketThread instance) =>
    <String, dynamic>{'ticket': instance.ticket, 'messages': instance.messages};
