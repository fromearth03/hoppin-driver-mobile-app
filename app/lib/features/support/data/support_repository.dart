import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/support_ticket.dart';

/// One selectable issue reason, as the server defines it.
class ComplaintType {
  final String code;
  final String label;
  const ComplaintType(this.code, this.label);
}

class SupportRepository {
  final ApiClient _api;
  SupportRepository(this._api);

  /// The issue reasons the server will accept. `type_code` is validated
  /// against a table — an unknown or retired code is a 400 — so the list is
  /// fetched rather than hardcoded here, where it would drift.
  Future<Result<List<ComplaintType>>> complaintTypes() async {
    final r = await _api.get<Map<String, dynamic>>('/complaint-types');
    return r.when(
      ok: (json) => Ok(((json['complaint_types'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map((e) => ComplaintType(
                (e['code'] as String?) ?? '',
                (e['label'] as String?) ?? (e['code'] as String?) ?? '',
              ))
          .where((c) => c.code.isNotEmpty)
          .toList()),
      err: (e) => Err(e),
    );
  }

  Future<Result<List<SupportTicket>>> tickets() async {
    final r = await _api.get<dynamic>('/me/support-tickets');
    return r.when(
      ok: (data) {
        final list = data is Map
            ? ((data['tickets'] as List?) ?? const [])
            : (data as List? ?? const []);
        return Ok(list
            .map((e) =>
                SupportTicket.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList());
      },
      err: (e) => Err(e),
    );
  }

  /// `ledgerEntryId` is set when the ticket is a dispute raised from a
  /// statement row, so support sees exactly which charge is contested.
  ///
  /// The endpoint has no field for it — an unknown key is dropped silently,
  /// which is how disputes were reaching support with nothing identifying
  /// the charge. It goes into the body instead, which is stored and read by
  /// a human. Move it to a real field if the service ever grows one.
  /// `typeCode` is the server's validated reason vocabulary, from
  /// [complaintTypes]. `category` is a free-text column with no whitelist, so
  /// it carries the same value for the benefit of the admin views that read it.
  Future<Result<SupportTicket>> create({
    required String subject,
    required String category,
    required String ticketBody,
    String? typeCode,
    String? rideId,
    String? ledgerEntryId,
  }) async {
    final body = ledgerEntryId == null
        ? ticketBody
        : '$ticketBody\n\nDisputed statement entry: $ledgerEntryId';
    final r =
        await _api.post<Map<String, dynamic>>('/me/support-tickets', body: {
      'subject': subject,
      'category': category,
      'body': body,
      if (typeCode != null) 'type_code': typeCode,
      if (rideId != null) 'ride_id': rideId,
    });
    return r.when(
      ok: (json) => Ok(SupportTicket.fromJson(json)),
      err: (e) => Err(e),
    );
  }

  /// The platform contact card. Public read — email, phone, emergency and
  /// WhatsApp numbers the admin panel maintains, blank when unset.
  Future<Result<PlatformContacts>> contacts() async {
    final r = await _api.get<Map<String, dynamic>>('/contacts');
    return r.when(
      ok: (json) => Ok(PlatformContacts.fromJson(json)),
      err: (e) => Err(e),
    );
  }

  /// One ticket with its whole conversation. The server also marks the
  /// thread read for this driver as a side effect of the fetch.
  Future<Result<TicketThread>> thread(String id) async {
    final r = await _api.get<Map<String, dynamic>>('/me/support-tickets/$id');
    return r.when(
      ok: (json) => Ok(TicketThread.fromJson(json)),
      err: (e) => Err(e),
    );
  }

  /// Sends the driver's message into the ticket. [replyToId] quotes an
  /// earlier message, mirroring the ride chat's reply mechanic.
  Future<Result<void>> reply(String id, String body,
      {String? replyToId}) async {
    final r = await _api
        .post<Map<String, dynamic>>('/me/support-tickets/$id/messages', body: {
      'body': body,
      if (replyToId != null) 'reply_to_id': replyToId,
    });
    return r.when(ok: (_) => const Ok(null), err: (e) => Err(e));
  }
}

final supportRepositoryProvider = Provider<SupportRepository>(
    (ref) => SupportRepository(ref.watch(apiClientProvider)));
