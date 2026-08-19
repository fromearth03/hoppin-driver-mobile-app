import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

import 'driver_fcm_gateway.dart';

/// One notification shown by the driver client, from history or live delivery.
@immutable
class DriverAppNotification {
  /// Creates a session notification.
  const DriverAppNotification({
    required this.id,
    required this.title,
    required this.receivedAt,
    this.body,
    this.read = false,
    this.rideId,
  });

  /// Builds one from a push. The id is LOCAL — the backend issues none, because
  /// there is no notification record endpoint (#68).
  factory DriverAppNotification.fromPush(
    DriverPushMessage m, {
    required String id,
  }) => DriverAppNotification(
    id: m.notificationId ?? id,
    title: m.title ?? 'Hoppin',
    body: m.body,
    receivedAt: m.sentAt ?? DateTime.now(),
    rideId: m.rideId,
  );

  factory DriverAppNotification.fromHistory(UserNotification n) =>
      DriverAppNotification(
        id: n.id,
        title: n.title,
        body: n.body.isEmpty ? null : n.body,
        receivedAt: n.createdAt,
        read: n.isRead,
        rideId: n.rideId,
      );

  /// Server id for history records, or a local id for a live event.
  final String id;

  /// The headline shown on the card.
  final String title;

  /// The supporting line.
  final String? body;

  /// When this client saw it.
  final DateTime receivedAt;

  /// Read state returned by the server for history, or local state for a live
  /// event until the next history refresh.
  final bool read;

  /// The trip this is about, when it is about one.
  final String? rideId;

  /// Returns a copy with [read] flipped.
  DriverAppNotification copyWith({bool? read}) => DriverAppNotification(
    id: id,
    title: title,
    body: body,
    receivedAt: receivedAt,
    read: read ?? this.read,
    rideId: rideId,
  );
}

/// The driver's notification feed.
///
/// SESSION-LOCAL BY NECESSITY. There is no `GET /me/notifications` (#68), so the
/// only notifications this client can HONESTLY show are the ones it saw arrive.
/// It is fed by:
///
///   (a) `DriverFcmGateway.onMessage()` — real pushes. **Empty today**: the
///       backend has no FCM credentials (#15/#16), so it cannot send.
///   (b) local driver-lifecycle events (an offer arriving, a document status
///       change surfacing on a poll) — which is what makes the centre non-empty
///       at all today.
///
/// 🔴 NOT PERSISTED. A relaunch empties it, and that is CORRECT — a local store
/// pretending to be server history is exactly the fake-as-live the no-holes rule
/// forbids, and it would diverge permanently from the server the day the history
/// endpoint ships.
final driverNotificationFeedProvider =
    NotifierProvider<DriverNotificationFeed, List<DriverAppNotification>>(
      DriverNotificationFeed.new,
    );

/// The unread count that a bell badge would read from.
///
/// 🔴 A **REAL** count over the real feed. Over the live no-op gateway it is
/// `0`, and `HopTopBar` hides the badge at 0. **There is no constant anywhere.**
/// A hardcoded `notificationCount: 2` shipped a permanent fake unread badge on
/// every rider screen once, and Wave 0 deleted it — a badge over a handler that
/// cannot fire is a promise the platform cannot keep.
final unreadDriverNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(driverNotificationFeedProvider).where((n) => !n.read).length;
});

/// The session store behind [driverNotificationFeedProvider].
class DriverNotificationFeed extends Notifier<List<DriverAppNotification>> {
  /// The live feed — starts empty and listens to the gateway.
  DriverNotificationFeed() : _seed = null;

  /// A pre-seeded feed. TEST/DEMO composition only — it deliberately does NOT
  /// subscribe to the gateway, so nothing arrives behind a test's back.
  DriverNotificationFeed.seeded(List<DriverAppNotification> seed)
    : _seed = seed;

  final List<DriverAppNotification>? _seed;
  int _counter = 0;
  bool _historyMerged = false;

  @override
  List<DriverAppNotification> build() {
    final seed = _seed;
    if (seed != null) return List<DriverAppNotification>.unmodifiable(seed);

    // Foreground pushes land here. Empty on the live no-op default (today),
    // which is why the centre's cold start renders the #68 rung rather than a
    // list — and why the unread count is an honest 0.
    final sub = ref.watch(driverFcmGatewayProvider).onMessage().listen(add);
    ref.onDispose(sub.cancel);

    return const <DriverAppNotification>[];
  }

  /// Records a push that arrived. Newest first.
  void add(DriverPushMessage m) {
    final n = DriverAppNotification.fromPush(m, id: 'local-${_counter++}');
    state = <DriverAppNotification>[n, ...state];
  }

  /// Merges durable history without duplicating live records.
  void mergeHistory(List<UserNotification> history) {
    if (_historyMerged && history.isEmpty) return;
    _historyMerged = true;
    final byId = <String, DriverAppNotification>{
      for (final item in state) item.id: item,
    };
    for (final item in history) {
      byId[item.id] = DriverAppNotification.fromHistory(item);
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    state = List<DriverAppNotification>.unmodifiable(merged);
  }

  /// Records a local driver-lifecycle event — an offer arriving, a document
  /// status change seen on a poll. This is what makes the centre non-empty
  /// today, while delivery is gated.
  void addLocal({required String title, String? body, String? rideId}) {
    state = <DriverAppNotification>[
      DriverAppNotification(
        id: 'local-${_counter++}',
        title: title,
        body: body,
        receivedAt: DateTime.now(),
        rideId: rideId,
      ),
      ...state,
    ];
  }

  /// Marks every notification read locally and persists the same action.
  void markAllRead() {
    state = <DriverAppNotification>[
      for (final n in state) n.read ? n : n.copyWith(read: true),
    ];
    try {
      unawaited(
        ref
            .read(notificationsRepositoryProvider)
            .markAllRead()
            .catchError((_) {}),
      );
    } on Object {
      // A local/demo composition may not have an authenticated API client.
      // The local state change still remains useful in that mode.
    }
  }

  /// Removes one session notification by [id]. Session-local only — there is no
  /// server record to delete (#68), so this is the one per-item action that is
  /// honest to enable.
  void dismiss(String id) {
    state = <DriverAppNotification>[
      for (final n in state)
        if (n.id != id) n,
    ];
  }
}

/// Loads the driver's durable notification history when the centre is opened.
final driverNotificationHistoryProvider =
    FutureProvider.autoDispose<List<UserNotification>>((ref) {
      return ref.watch(notificationsRepositoryProvider).list();
    });
