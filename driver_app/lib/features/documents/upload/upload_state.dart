import 'package:flutter/foundation.dart';

/// Where one document upload has got to.
///
/// `idle → picking → preparing → uploading → confirming → done`, with two exits:
/// `error` (anything went wrong, and we say what) and `storageDisabled` (the
/// backend answered `503 STORAGE_DISABLED` — object storage is off, this is not
/// the driver's fault and there is nothing they can do about it).
enum UploadPhase {
  idle,
  picking,
  preparing,
  uploading,
  confirming,
  done,
  storageDisabled,
  error,
}

/// The upload's state, and NOTHING ELSE.
///
/// 🔴 THERE IS NO DOCUMENT-CONTENT FIELD HERE, AND THERE NEVER WILL BE.
///
/// No `Uint8List`. No preview. No thumbnail. No cached image. The documents this
/// app carries are photographs of a **DVLA licence**, a **right-to-work
/// document**, and an **NR3S background check** — and the last of those reveals
/// **criminal-record information**, which is UK GDPR **Article 10** data, the
/// most tightly regulated category that exists.
///
/// State is not a private place. It survives a hot reload. A devtools inspector
/// dumps it. A crash reporter serialises it. An error boundary prints it. The
/// picked file exists as a **local variable inside one method** and dies when
/// that method returns — that is not fussiness, it is the only design in which
/// none of the above can leak a licence.
///
/// `pii_discipline_test.dart` asserts, against this file's source, that the
/// words `bytes`, `preview`, `thumbnail`, `Uint8List` and `List<int>` do not
/// appear in it. If you are here to add one: don't.
@immutable
class UploadState {
  const UploadState({
    this.phase = UploadPhase.idle,
    this.documentType,
    this.error,
  });

  final UploadPhase phase;

  /// Which of the eight compliance document types is in flight — so the
  /// Documents list can show the spinner on the right row.
  final String? documentType;

  /// What to tell the driver. 🔴 NEVER the presigned URL: it is a five-minute
  /// write credential to our storage bucket, and an error message is a string
  /// that gets shown, logged, screenshotted and pasted into a support ticket.
  final String? error;

  bool get busy => switch (phase) {
        UploadPhase.picking ||
        UploadPhase.preparing ||
        UploadPhase.uploading ||
        UploadPhase.confirming =>
          true,
        _ => false,
      };

  UploadState copyWith({
    UploadPhase? phase,
    String? documentType,
    String? error,
  }) =>
      UploadState(
        phase: phase ?? this.phase,
        documentType: documentType ?? this.documentType,
        error: error,
      );

  @override
  String toString() =>
      'UploadState(${phase.name}, documentType: $documentType, error: $error)';

  @override
  bool operator ==(Object other) =>
      other is UploadState &&
      other.phase == phase &&
      other.documentType == documentType &&
      other.error == error;

  @override
  int get hashCode => Object.hash(phase, documentType, error);
}
