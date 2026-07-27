import 'dart:async';

import 'package:flutter/foundation.dart';

/// Adapts a [Stream] to a [Listenable] so go_router's `refreshListenable` can
/// re-run `redirect` whenever the stream emits.
///
/// Used with [AuthService.onAuthStateChange]: without this, go_router only
/// evaluates `redirect` on navigation events — a successful sign-in would
/// leave the user stranded on the login screen.
class StreamListenable extends ChangeNotifier {
  StreamListenable(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }
}
