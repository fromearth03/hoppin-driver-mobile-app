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
