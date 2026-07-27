import 'snapshot_store_io.dart'
    if (dart.library.js_interop) 'snapshot_store_web.dart' as impl;

/// Where the demo world persists its snapshot between page loads.
///
/// On web this is `window.sessionStorage` (per-tab, synchronous, self-clearing
/// on window close) so an F5 mid-ride resumes exactly where it was. On every
/// other platform it is an in-memory store: reload-resume is a web concept,
/// and a fresh process correctly starts a fresh demo world (keeps the Phase-7
/// Android APK build working without `package:web`).
abstract interface class SnapshotStore {
  /// The store for the compilation target: sessionStorage on web, in-memory
  /// elsewhere. Selected at compile time via conditional import.
  factory SnapshotStore.forPlatform() = impl.PlatformSnapshotStore;

  /// The last written snapshot JSON, or null when none exists.
  String? read();

  /// Persists [json] as the current snapshot, replacing any previous one.
  void write(String json);

  /// Deletes the snapshot — the explicit demo reset beat.
  void clear();
}

/// Plain in-memory [SnapshotStore]. Tests construct this explicitly; the
/// non-web platform store delegates to one.
class InMemorySnapshotStore implements SnapshotStore {
  String? _snapshot;

  @override
  String? read() => _snapshot;

  @override
  void write(String json) => _snapshot = json;

  @override
  void clear() => _snapshot = null;
}
