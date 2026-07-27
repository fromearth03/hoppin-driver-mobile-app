/// One publicly-available promotion from `GET /promotions`.
///
/// 🔴 **This is the CAMPAIGN CATALOGUE, not the rider's wallet.** The server
/// filters by `is_active AND audience='rider'` and the campaign window — it does
/// NOT filter by who is asking. So these are offers that EXIST and are open to
/// riders; they are not codes this rider personally holds or has been granted.
/// There is no `GET /me/promos`, so the wallet remains unknowable and must keep
/// saying so. Presenting this list as "your codes" would be the same class of
/// lie, just sourced from a real endpoint.
///
/// Every field here is server data, so a code or an expiry rendered from one is
/// a FACT — unlike the invented strings the Figma frame drew.
class PromoOffer {
  const PromoOffer({
    required this.promoCode,
    required this.title,
    required this.description,
    required this.discountType,
    required this.discountValue,
    this.maxDiscountCap,
    this.minRideAmount,
    this.newUsersOnly = false,
    this.expiresAt,
  });

  factory PromoOffer.fromJson(Map<String, dynamic> json) {
    return PromoOffer(
      promoCode: (json['promo_code'] as String?)?.trim() ?? '',
      title: (json['title'] as String?)?.trim() ?? '',
      description: (json['description'] as String?)?.trim() ?? '',
      discountType: (json['discount_type'] as String?)?.trim() ?? '',
      discountValue: (json['discount_value'] as num?)?.toDouble() ?? 0,
      maxDiscountCap: (json['max_discount_cap'] as num?)?.toDouble(),
      minRideAmount: (json['min_ride_amount'] as num?)?.toDouble(),
      newUsersOnly: json['new_users_only'] as bool? ?? false,
      expiresAt: _parseDate(json['expires_at']),
    );
  }

  /// `expires_at` arrives as `::text` from Postgres, so it may be a date or a
  /// full timestamp. An unparseable value becomes null rather than throwing —
  /// an offer with an unreadable date is still a usable offer.
  static DateTime? _parseDate(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }

  final String promoCode;
  final String title;
  final String description;

  /// `percentage` | `fixed_amount` (the server's `discount_type` enum).
  final String discountType;
  final double discountValue;

  /// Ceiling on a percentage discount, in pounds. Null when uncapped.
  final double? maxDiscountCap;

  /// Minimum fare the offer applies to, in pounds. Null when there is none.
  final double? minRideAmount;
  final bool newUsersOnly;
  final DateTime? expiresAt;

  /// The offer in one line — "20% off" / "£5 off". Falls back to the raw code
  /// when the discount type is one this build does not recognise, so a new
  /// server-side type degrades to something true rather than to "0% off".
  String get headline => switch (discountType) {
        'percentage' => '${_trim(discountValue)}% off',
        'fixed_amount' => '£${_trim(discountValue)} off',
        _ => promoCode,
      };

  /// The display title, falling back to the headline when the admin left it
  /// blank (the column is nullable and COALESCEd to '' server-side).
  String get displayTitle => title.isNotEmpty ? title : headline;

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  Map<String, dynamic> toJson() => {
        'promo_code': promoCode,
        'title': title,
        'description': description,
        'discount_type': discountType,
        'discount_value': discountValue,
        'max_discount_cap': maxDiscountCap,
        'min_ride_amount': minRideAmount,
        'new_users_only': newUsersOnly,
        'expires_at': expiresAt?.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      other is PromoOffer &&
      other.promoCode == promoCode &&
      other.title == title &&
      other.description == description &&
      other.discountType == discountType &&
      other.discountValue == discountValue &&
      other.maxDiscountCap == maxDiscountCap &&
      other.minRideAmount == minRideAmount &&
      other.newUsersOnly == newUsersOnly &&
      other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(promoCode, title, description, discountType,
      discountValue, maxDiscountCap, minRideAmount, newUsersOnly, expiresAt);
}
