/// A seeded cancellation reason from `GET /cancellation-reasons`. The `id` is
/// the real DB uuid that `PATCH /rides/:id/cancel` validates `reason_id`
/// against — the app must send one of these, never a fabricated placeholder.
class CancellationReasonOption {
  const CancellationReasonOption({
    required this.id,
    required this.reasonText,
    required this.appliesPenaltyFee,
    required this.actorType,
  });

  final String id;
  final String reasonText;
  final bool appliesPenaltyFee;

  /// "rider" or "driver" — who this reason is offered to.
  final String actorType;

  factory CancellationReasonOption.fromJson(Map<String, dynamic> json) =>
      CancellationReasonOption(
        id: json['id'] as String,
        reasonText: (json['reason_text'] as String?) ?? '',
        appliesPenaltyFee: (json['applies_penalty_fee'] as bool?) ?? false,
        actorType: (json['actor_type'] as String?) ?? 'rider',
      );
}
