import '../../../../core/money.dart';

/// One penalty against the driver's account.
///
/// Both this list and `stats.penalties_count` are ledger-sourced, so the
/// count on the Stats screen and the entries behind it cannot disagree —
/// which they did before A13 was resolved.
class Penalty {
  final String id;
  final DateTime createdAt;
  final Pence amount;
  final String displayTitle;
  final String? displayReason;
  final String? rideId;
  final bool appealable;

  const Penalty({
    required this.id,
    required this.createdAt,
    required this.amount,
    required this.displayTitle,
    this.displayReason,
    this.rideId,
    this.appealable = false,
  });

  factory Penalty.fromJson(Map<String, dynamic> json) => Penalty(
        id: json['id'] as String,
        createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ??
            DateTime.now(),
        amount: Pence((json['amount_pence'] as num?)?.toInt() ?? 0),
        displayTitle: (json['display_title'] as String?) ?? 'Penalty',
        displayReason: json['display_reason'] as String?,
        rideId: json['ride_id'] as String?,
        appealable: json['appealable'] as bool? ?? false,
      );
}

class PenaltyList {
  final List<Penalty> penalties;
  final int count;

  const PenaltyList({required this.penalties, required this.count});

  factory PenaltyList.fromJson(Map<String, dynamic> json) => PenaltyList(
        penalties: ((json['penalties'] as List?) ?? const [])
            .map((e) => Penalty.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}
