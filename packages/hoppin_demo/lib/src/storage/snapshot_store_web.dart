import 'package:web/web.dart' as web;

import 'snapshot_store.dart';

/// Web snapshot store over `window.sessionStorage`.
///
/// sessionStorage is per-tab (rider and driver demo windows stay isolated),
/// synchronous (restore completes before `runApp` — no async boot gap), and
/// clears itself when the window closes.
///
/// This is the only file in the package allowed to import `package:web`.
class PlatformSnapshotStore implements SnapshotStore {
  static const _key = 'hoppin_demo_world_v1';

  @override
  String? read() => web.window.sessionStorage.getItem(_key);

  @override
  void write(String json) => web.window.sessionStorage.setItem(_key, json);

  @override
  void clear() => web.window.sessionStorage.removeItem(_key);
}
