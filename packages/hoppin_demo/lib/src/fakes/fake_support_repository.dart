import 'package:hoppin_shared/hoppin_shared.dart';

/// The support-ticket surface — support is off-script, so this fake serves
/// constants only and holds no world.
class FakeSupportRepository implements SupportRepository {
  const FakeSupportRepository();

  /// Accepts the ticket and returns a fixed id (the demo never lists it).
  @override
  Future<String> createTicket({
    required String subject,
    String? category,
    String? typeCode,
    String? priority,
    String? rideId,
    String? body,
    List<String>? tags,
  }) async =>
      'c3000000-0000-4000-8000-000000000001';

  @override
  Future<List<SupportTicket>> myTickets() async => const [];

  @override
  Future<TicketThread> thread(String ticketId) =>
      throw UnsupportedError('Not part of the demo');

  @override
  Future<void> reply({required String ticketId, required String body}) async {}
}
