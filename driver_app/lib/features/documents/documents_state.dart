import 'package:flutter/foundation.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// Where the documents surface is in its read lifecycle.
enum DocumentsPhase {
  /// The first `GET /drivers/me/documents` is in flight.
  loading,

  /// The server answered. [DocumentsState.documents] is exactly what it sent.
  ready,

  /// `503 STORAGE_DISABLED` — document storage is not configured on this
  /// deployment. Matched on the `code`, never on the bare 503 (OD-11).
  storageDisabled,

  /// The read failed. 🔴 A transport failure is IGNORANCE, not "you have no
  /// documents" — an empty wallet and an unreachable server look identical on
  /// the wire and must never look identical on the screen.
  error,
}

/// Where the rungs' forward exit (`POST /me/support-tickets`) is.
enum SupportPhase {
  /// Nothing asked.
  idle,

  /// The ticket POST is in flight.
  sending,

  /// A real ticket exists and a real person will read it.
  sent,

  /// The ticket could not be opened. The driver is TOLD — a silently-swallowed
  /// support request is a forward exit that goes nowhere.
  failed,
}

/// Immutable snapshot of the documents surface (riblet convention:
/// hand-rolled immutable + copyWith, in the [DashboardState] style).
@immutable
class DocumentsState {
  /// Creates a documents snapshot. Defaults to the pre-read [loading] phase.
  const DocumentsState({
    this.phase = DocumentsPhase.loading,
    this.documents = const [],
    this.supportPhase = SupportPhase.idle,
    this.error,
  });

  /// Where the read is.
  final DocumentsPhase phase;

  /// Where the rungs' support-ticket exit is.
  final SupportPhase supportPhase;

  /// Exactly what the server sent — its own rows, its own
  /// `verification_status` strings, in its own order. Nothing normalised,
  /// nothing bucketed, nothing upgraded.
  final List<DriverDocument> documents;

  /// Display-ready failure message from the last read, if any.
  final String? error;

  /// The newest document of [type], or null when the driver has not uploaded
  /// one.
  ///
  /// 🔴 NULL MEANS NOT UPLOADED. It does NOT mean pending, it does not mean
  /// "under review", and it certainly does not mean valid. The row renders an
  /// explicit not-uploaded affordance on this branch.
  ///
  /// `DOCS/04` L178 says the server serves newest-first and replaces on
  /// re-upload — but a correctness decision may not rest on list ORDER, which
  /// is a presentation detail the server is free to change. So sort.
  DriverDocument? documentFor(String type) {
    final matches =
        documents.where((d) => d.documentType == type).toList(growable: false)
          ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    return matches.isEmpty ? null : matches.first;
  }

  static const Object _unset = Object();

  /// copyWith with explicit null-clearing for [error]: passing `null` clears,
  /// omitting keeps.
  DocumentsState copyWith({
    DocumentsPhase? phase,
    List<DriverDocument>? documents,
    SupportPhase? supportPhase,
    Object? error = _unset,
  }) {
    return DocumentsState(
      phase: phase ?? this.phase,
      documents: documents ?? this.documents,
      supportPhase: supportPhase ?? this.supportPhase,
      error: identical(error, _unset) ? this.error : error as String?,
    );
  }
}
