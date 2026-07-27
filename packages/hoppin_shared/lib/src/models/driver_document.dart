import 'package:freezed_annotation/freezed_annotation.dart';

part 'driver_document.freezed.dart';
part 'driver_document.g.dart';

/// One driver compliance document — the row shape both
/// `POST /drivers/me/documents` (confirm, 201) and `GET /drivers/me/documents`
/// serve (docs/04). A fresh confirm always lands as `pending_review`; admin
/// review moves it on from there. `expires_at` is null for documents without
/// an expiry.
@freezed
abstract class DriverDocument with _$DriverDocument {
  const factory DriverDocument({
    required String id,
    @JsonKey(name: 'document_type') required String documentType,
    @JsonKey(name: 'verification_status') required String verificationStatus,
    @JsonKey(name: 'uploaded_at') required DateTime uploadedAt,
    @JsonKey(name: 'expires_at') DateTime? expiresAt,
  }) = _DriverDocument;

  factory DriverDocument.fromJson(Map<String, dynamic> json) =>
      _$DriverDocumentFromJson(json);
}
