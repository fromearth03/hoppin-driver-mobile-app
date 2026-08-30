import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result.dart';
import '../data/chat_repository.dart';
import '../data/models/ride_message.dart';

/// Polls only while the thread is open. There is no socket for the driver
/// app, and a closed thread has the ride's `chat_unread` badge instead.
class ChatController extends FamilyAsyncNotifier<List<RideMessage>, String> {
  Timer? _timer;
  bool _disposed = false;

  @override
  Future<List<RideMessage>> build(String rideId) async {
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
    });
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
    final result = await ref.read(chatRepositoryProvider).messages(rideId);
    return result.valueOrNull ?? const [];
  }

  Future<void> refresh() async {
    if (_disposed) return;
    final result = await ref.read(chatRepositoryProvider).messages(arg);
    if (_disposed) return;
    final messages = result.valueOrNull;
    if (messages != null) state = AsyncData(messages);
  }

  Future<Result<RideMessage>> send(String body, {String? replyToId}) async {
    final result = await ref
        .read(chatRepositoryProvider)
        .send(arg, body, replyToId: replyToId);
    if (!_disposed && result.isOk) await refresh();
    return result;
  }
}

final chatControllerProvider =
    AsyncNotifierProvider.family<ChatController, List<RideMessage>, String>(
        ChatController.new);
