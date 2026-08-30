import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/support_ticket.dart';

class SupportRepository {
  final ApiClient _api;
  SupportRepository(this._api);

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
  Future<Result<SupportTicket>> create({
    required String subject,
    required String category,
    required String ticketBody,
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
      if (rideId != null) 'ride_id': rideId,
    });
    return r.when(
      ok: (json) => Ok(SupportTicket.fromJson(json)),
      err: (e) => Err(e),
    );
  }
}

final supportRepositoryProvider = Provider<SupportRepository>(
    (ref) => SupportRepository(ref.watch(apiClientProvider)));
