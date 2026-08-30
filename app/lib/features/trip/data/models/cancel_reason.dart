import '../../../../core/money.dart';

/// One selectable cancellation reason.
///
/// `reason_text` is server-owned prose. Two live values (`driver_declined`,
/// `offer_timeout`) are raw slugs describing system outcomes rather than
/// driver choices; the server marks those `pickable: false` and the picker
/// drops them. We never title-case a slug ourselves — that is guesswork
/// that breaks the moment a reason is added.
class CancelReason {
  final String id;
  final String text;
  final bool pickable;
  final Pence? penaltyFee;
  final int? freeCancelSeconds;

  const CancelReason({
    required this.id,
    required this.text,
    required this.pickable,
    this.penaltyFee,
    this.freeCancelSeconds,
  });

  bool get hasPenalty => (penaltyFee?.pence ?? 0) > 0;

  factory CancelReason.fromJson(Map<String, dynamic> json) => CancelReason(
        id: (json['id'] ?? json['code'] ?? '') as String,
        text: (json['reason_text'] ?? json['display_text'] ?? '') as String,
        pickable: json['pickable'] as bool? ?? true,
        // penalty_fee_pence is authoritative; penalty_fee_amount is a
        // deprecated float and is never read.
        penaltyFee: json['penalty_fee_pence'] == null
            ? null
            : Pence((json['penalty_fee_pence'] as num).toInt()),
        freeCancelSeconds: (json['free_cancel_seconds'] as num?)?.toInt(),
      );
}
