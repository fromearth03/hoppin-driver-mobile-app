import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/ride_message.dart';

class ChatRepository {
  final ApiClient _api;
  ChatRepository(this._api);

  /// Reading the thread also clears the ride's `chat_unread` badge server-side.
  Future<Result<List<RideMessage>>> messages(String rideId) async {
    final r = await _api.get<dynamic>('/rides/$rideId/messages');
    return r.when(
      ok: (data) {
        final list = data is Map
            ? ((data['messages'] as List?) ?? const [])
            : (data as List? ?? const []);
        return Ok(list
            .map((e) =>
                RideMessage.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList());
      },
      err: (e) => Err(e),
    );
  }

  Future<Result<RideMessage>> send(String rideId, String body,
      {String? replyToId}) async {
    final r = await _api.post<Map<String, dynamic>>(
      '/rides/$rideId/messages',
      body: {
        'body': body,
        if (replyToId != null) 'reply_to_id': replyToId,
      },
    );
    return r.when(
      ok: (json) => Ok(RideMessage.fromJson(json)),
      err: (e) => Err(e),
    );
  }
}

final chatRepositoryProvider =
    Provider<ChatRepository>((ref) => ChatRepository(ref.watch(apiClientProvider)));
