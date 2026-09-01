enum TicketStatus { open, pending, resolved, rejected }

class SupportTicket {
  final String id;
  final String subject;
  final String? category;
  final TicketStatus status;
  final String ticketBody;
  final String? resolutionNotes;
  final String? rideId;
  final DateTime createdAt;

  const SupportTicket({
    required this.id,
    required this.subject,
    required this.status,
    required this.createdAt,
    this.category,
    this.ticketBody = '',
    this.resolutionNotes,
    this.rideId,
  });

  bool get isResolved =>
      status == TicketStatus.resolved || status == TicketStatus.rejected;

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
        id: json['id'] as String,
        subject: (json['subject'] as String?) ?? '',
        category: json['category'] as String?,
        status: switch (json['status'] as String?) {
          'resolved' || 'closed' => TicketStatus.resolved,
          'rejected' => TicketStatus.rejected,
          'pending' || 'in_progress' => TicketStatus.pending,
          // Anything unrecognised is still open — telling a driver their
          // issue is closed when we do not know would be the worse error.
          _ => TicketStatus.open,
        },
        ticketBody: (json['body'] as String?) ?? '',
        resolutionNotes: json['resolution_notes'] as String?,
        rideId: json['ride_id'] as String?,
        createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ??
            DateTime.now(),
      );
}

/// The platform's live contact card from `GET /contacts` — admin-owned rows,
/// served blank when unset, so nothing here is ever invented client-side.
class PlatformContacts {
  final String supportEmail;
  final String supportPhone;
  final String emergencyPhone;
  final String whatsappNumber;

  const PlatformContacts({
    this.supportEmail = '',
    this.supportPhone = '',
    this.emergencyPhone = '',
    this.whatsappNumber = '',
  });

  factory PlatformContacts.fromJson(Map<String, dynamic> json) =>
      PlatformContacts(
        supportEmail: (json['support_email'] as String?) ?? '',
        supportPhone: (json['support_phone'] as String?) ?? '',
        emergencyPhone: (json['emergency_phone'] as String?) ?? '',
        whatsappNumber: (json['whatsapp_number'] as String?) ?? '',
      );
}

/// The quoted message a reply points at — body and who wrote it, enough to
/// draw the design's quote block without a second fetch.
class TicketReplyPreview {
  final String id;
  final String body;
  final bool isStaff;

  const TicketReplyPreview(
      {required this.id, required this.body, required this.isStaff});

  factory TicketReplyPreview.fromJson(Map<String, dynamic> json) =>
      TicketReplyPreview(
        id: (json['id'] as String?) ?? '',
        body: (json['body'] as String?) ?? '',
        isStaff: json['is_staff'] as bool? ?? false,
      );
}

/// One message in a ticket's conversation. `status` is only ever set on the
/// driver's own messages: 'read' once a staff read-marker passed it, 'sent'
/// otherwise — the WhatsApp receipt, computed server-side.
class TicketMessage {
  final String id;
  final String body;
  final bool isStaff;
  final DateTime createdAt;
  final String status;
  final TicketReplyPreview? replyTo;

  const TicketMessage({
    required this.id,
    required this.body,
    required this.isStaff,
    required this.createdAt,
    this.status = '',
    this.replyTo,
  });

  bool get isMine => !isStaff;
  bool get isRead => status == 'read';

  factory TicketMessage.fromJson(Map<String, dynamic> json) => TicketMessage(
        id: (json['id'] as String?) ?? '',
        body: (json['body'] as String?) ?? '',
        isStaff: json['is_staff'] as bool? ?? false,
        createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ??
            DateTime.now(),
        status: (json['status'] as String?) ?? '',
        replyTo: json['reply_to'] == null
            ? null
            : TicketReplyPreview.fromJson(
                Map<String, dynamic>.from(json['reply_to'] as Map)),
      );
}

/// A ticket with its whole conversation, as `GET /me/support-tickets/:id`
/// answers. Fetching it also marks the thread read for this driver.
class TicketThread {
  final SupportTicket ticket;
  final List<TicketMessage> messages;

  const TicketThread({required this.ticket, required this.messages});

  factory TicketThread.fromJson(Map<String, dynamic> json) => TicketThread(
        ticket: SupportTicket.fromJson(
            Map<String, dynamic>.from(json['ticket'] as Map)),
        messages: ((json['messages'] as List?) ?? const [])
            .map((e) =>
                TicketMessage.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
