/// One bookable vehicle class — `GET /vehicle-types`.
///
/// The row the booking selector needs: a REAL `id` to send as
/// `vehicle_category_id`, plus the seats/bags a rider chooses on. Sourced from
/// admin's `vehicle_categories` table, active rows only, cheapest first.
///
/// This is the read the rider app's hardcoded class list was waiting for. The
/// endpoint is named `/vehicle-types`; the app's placeholder comment called it
/// `GET /vehicle-categories`, which is why it went unwired after it shipped.
class VehicleType {
  const VehicleType({
    required this.id,
    required this.name,
    this.seats = 0,
    this.bags = 0,
    this.priceMultiplier = 1.0,
  });

  factory VehicleType.fromJson(Map<String, dynamic> json) {
    return VehicleType(
      id: (json['id'] as String?)?.trim() ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      seats: (json['seats'] as num?)?.toInt() ?? 0,
      bags: (json['bags'] as num?)?.toInt() ?? 0,
      priceMultiplier: (json['price_multiplier'] as num?)?.toDouble() ?? 1.0,
    );
  }

  /// The `vehicle_category_id` sent when booking. Never null here — a class
  /// with no id could not be booked, so the repository drops those rows.
  final String id;
  final String name;

  /// 0 means the admin left it unset. Render the capacity line only when known
  /// rather than printing "0 seats", which reads as a broken product.
  final int seats;
  final int bags;

  /// Relative price vs the base tariff (1.0 = standard). The real fare still
  /// comes from `POST /rides/estimate`; this only orders the list.
  final double priceMultiplier;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'seats': seats,
        'bags': bags,
        'price_multiplier': priceMultiplier,
      };

  @override
  bool operator ==(Object other) =>
      other is VehicleType &&
      other.id == id &&
      other.name == name &&
      other.seats == seats &&
      other.bags == bags &&
      other.priceMultiplier == priceMultiplier;

  @override
  int get hashCode => Object.hash(id, name, seats, bags, priceMultiplier);
}
