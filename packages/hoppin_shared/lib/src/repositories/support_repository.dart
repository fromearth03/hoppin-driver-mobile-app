import '../api/api_client.dart';
import '../models/support_ticket.dart';

/// Support-ticket bindings — `/me/support-tickets` (docs/04). `[either]`.
/// (The legacy `POST /me/disputes` writes into the same unified model — the
/// docs say to prefer these endpoints for new work, so we only use these.)
class SupportRepository {
  SupportRepository(this._api);

  final ApiClient _api;

  /// `POST /me/support-tickets` — open a ticket. Only `subject` is required.
  Future<String> createTicket({
    required String subject,
    String? category,
    String? typeCode,
    String? priority,
    String? rideId,
    String? body,
    List<String>? tags,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/me/support-tickets',
      body: {
        'subject': subject,
        'category': ?category,
        'type_code': ?typeCode,
        'priority': ?priority,
        'ride_id': ?rideId,
        if (body != null && body.isNotEmpty) 'body': body,
        if (tags != null && tags.isNotEmpty) 'tags': tags,
      },
    );
    return res.data!['id'] as String;
  }

  /// `GET /me/support-tickets` — my tickets (`[]` when none).
  Future<List<SupportTicket>> myTickets() async {
    final res = await _api.get<List<dynamic>>('/me/support-tickets');
    return (res.data ?? [])
        .map((e) => SupportTicket.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET /me/support-tickets/:id` — one ticket + its message thread.
  Future<TicketThread> thread(String ticketId) async {
    final res =
        await _api.get<Map<String, dynamic>>('/me/support-tickets/$ticketId');
    return TicketThread.fromJson(res.data!);
  }

  /// `POST /me/support-tickets/:id/messages` — reply on the thread.
  Future<void> reply({required String ticketId, required String body}) =>
      _api.post<Map<String, dynamic>>(
        '/me/support-tickets/$ticketId/messages',
        body: {'body': body},
      );
}
