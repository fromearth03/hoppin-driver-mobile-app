enum DocumentStatus { pending, approved, rejected, expired, missing }

/// One of the eight document types the platform recognises.
///
/// `uploadable: false` marks an operator-run check (the NR3S background
/// check): the driver can see its status but cannot act on it, so the card
/// shows no upload affordance.
class DocumentType {
  final String code;
  final String label;
  final bool uploadable;
  final bool expires;

  const DocumentType({
    required this.code,
    required this.label,
    this.uploadable = true,
    this.expires = false,
  });

  factory DocumentType.fromJson(Map<String, dynamic> json) {
    final code = (json['code'] ?? json['document_type'] ?? '') as String;
    return DocumentType(
      code: code,
      label: (json['label'] as String?) ?? _humanise(code),
      uploadable: json['uploadable'] as bool? ?? true,
      expires: json['expires'] as bool? ?? false,
    );
  }

  /// Only ever applied to a closed server enum, where title-casing is safe.
  static String _humanise(String code) => code
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

class DriverDocument {
  final String id;
  final String documentType;
  final DocumentStatus status;
  final DateTime? uploadedAt;
  final DateTime? expiresAt;

  /// Written by an admin when they reject. Rendered verbatim — the reason a
  /// driver cannot fix a rejection is not knowing what was wrong with it.
  final String? rejectionReason;

  const DriverDocument({
    required this.id,
    required this.documentType,
    required this.status,
    this.uploadedAt,
    this.expiresAt,
    this.rejectionReason,
  });

  static const _expiryWarning = Duration(days: 30);

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool get isExpiringSoon =>
      expiresAt != null &&
      !isExpired &&
      expiresAt!.difference(DateTime.now()) < _expiryWarning;

  /// True when the driver has something to do about it. Pending review is
  /// deliberately excluded: there is nothing to act on while we check.
  bool get needsAction =>
      status == DocumentStatus.rejected ||
      status == DocumentStatus.expired ||
      status == DocumentStatus.missing;

  factory DriverDocument.fromJson(Map<String, dynamic> json) {
    final expiresAt = json['expires_at'] == null
        ? null
        : DateTime.tryParse(json['expires_at'] as String);
    final raw = (json['verification_status'] as String?) ?? '';
    var status = switch (raw) {
      'approved' || 'verified' => DocumentStatus.approved,
      'rejected' => DocumentStatus.rejected,
      'expired' => DocumentStatus.expired,
      // Anything unrecognised reads as pending: claiming a document is
      // approved when we do not know would be the dangerous error.
      _ => DocumentStatus.pending,
    };
    if (status == DocumentStatus.approved &&
        expiresAt != null &&
        DateTime.now().isAfter(expiresAt)) {
      status = DocumentStatus.expired;
    }

    return DriverDocument(
      id: (json['id'] as String?) ?? '',
      documentType: (json['document_type'] as String?) ?? '',
      status: status,
      uploadedAt: json['uploaded_at'] == null
          ? null
          : DateTime.tryParse(json['uploaded_at'] as String),
      expiresAt: expiresAt,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }
}

/// A type paired with the driver's upload for it, if there is one. Every
/// known type gets a slot so the grid shows gaps rather than hiding them.
class DocumentSlot {
  final DocumentType type;
  final DriverDocument? document;

  const DocumentSlot({required this.type, this.document});

  DocumentStatus get status => document?.status ?? DocumentStatus.missing;
  bool get needsAction => document?.needsAction ?? true;
}
