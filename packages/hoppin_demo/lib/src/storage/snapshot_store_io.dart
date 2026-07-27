import 'snapshot_store.dart';

/// Non-web snapshot store: in-memory only.
///
/// Reload-resume is a web concept (F5 keeps the tab's sessionStorage alive);
/// off web a fresh process correctly starts a fresh demo world, so an
/// in-memory store is the right behavior — and it keeps the Phase-7 Android
/// APK target compiling without `package:web`.
class PlatformSnapshotStore implements SnapshotStore {
  final InMemorySnapshotStore _delegate = InMemorySnapshotStore();

  @override
  String? read() => _delegate.read();

  @override
  void write(String json) => _delegate.write(json);

  @override
  void clear() => _delegate.clear();
}
