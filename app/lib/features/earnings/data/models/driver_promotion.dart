import '../../../../core/money.dart';

/// A live bonus campaign, from `GET /drivers/me/promotions`.
///
/// The endpoint returns the shared promo record, most of which describes the
/// rider's discount — the code, the percentage off, the minimum spend. None
/// of that is the driver's business. Only [bonus] is: what they are paid for
/// completing a qualifying trip.
class DriverPromotion {
  final String title;
  final String description;

  /// What the driver earns on a qualifying trip. Null when the campaign pays
  /// the rider a discount and the driver nothing — those are filtered out
  /// rather than shown as a bonus of nothing.
  final Pence? bonus;
  final DateTime? expiresAt;

  const DriverPromotion({
    required this.title,
    this.description = '',
    this.bonus,
    this.expiresAt,
  });

  factory DriverPromotion.fromJson(Map<String, dynamic> json) {
    // Amounts on the promo record are pounds, like the rest of this table.
    final amount = (json['driver_bonus_amount'] as num?)?.toDouble();
    return DriverPromotion(
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      bonus: amount == null ? null : Pence.fromPounds(amount),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.tryParse(json['expires_at'] as String),
    );
  }

  /// Whether this campaign actually pays the driver anything.
  bool get paysDriver => bonus != null && !bonus!.isZero;
}
