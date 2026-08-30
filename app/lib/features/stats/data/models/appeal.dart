enum AppealStatus { underReview, approved, rejected }

/// A driver's challenge to a compliance decision.
///
/// `reviewNote` is the admin's reason, mandatory on both approve and reject.
/// It is rendered verbatim as the outcome — an appeal answered with silence
/// is the problem this field exists to solve.
class Appeal {
  final String id;
  final String? documentType;
  final String reason;
  final AppealStatus status;
  final String? reviewNote;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  const Appeal({
    required this.id,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.documentType,
    this.reviewNote,
    this.reviewedAt,
  });

  bool get isResolved =>
      status == AppealStatus.approved || status == AppealStatus.rejected;

  factory Appeal.fromJson(Map<String, dynamic> json) => Appeal(
        id: json['id'] as String,
        documentType: json['document_type'] as String?,
        reason: (json['reason'] as String?) ?? '',
        status: switch (json['status'] as String?) {
          'approved' || 'upheld' => AppealStatus.approved,
          'rejected' || 'denied' => AppealStatus.rejected,
          // Anything else is still in flight; claiming a decision we do not
          // have would be worse than saying it is under review.
          _ => AppealStatus.underReview,
        },
        reviewNote: json['review_note'] as String?,
        reviewedAt: json['reviewed_at'] == null
            ? null
            : DateTime.tryParse(json['reviewed_at'] as String),
        createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ??
            DateTime.now(),
      );
}
