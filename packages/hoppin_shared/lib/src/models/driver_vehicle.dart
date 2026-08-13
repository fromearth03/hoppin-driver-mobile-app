import 'package:flutter/foundation.dart';

/// The vehicle registered to the authenticated driver.
///
/// This is the response shape of `GET /drivers/me/vehicle`. Insurance details
/// are factual fields only; they do not describe compliance or approval state.
@immutable
class DriverVehicle {
  const DriverVehicle({
    required this.id,
    required this.make,
    required this.model,
    required this.licensePlate,
    required this.color,
    required this.passengerCapacity,
    required this.insuranceProvider,
    this.year,
    this.insuranceExpiry,
  });

  factory DriverVehicle.fromJson(Map<String, dynamic> json) {
    return DriverVehicle(
      id: json['id'] as String,
      make: json['make'] as String,
      model: json['model'] as String,
      year: (json['year'] as num?)?.toInt(),
      licensePlate: json['license_plate'] as String,
      color: json['color'] as String? ?? '',
      passengerCapacity: (json['passenger_capacity'] as num).toInt(),
      insuranceProvider: json['insurance_provider'] as String? ?? '',
      insuranceExpiry: switch (json['insurance_expiry']) {
        final String value when value.isNotEmpty => DateTime.tryParse(value),
        _ => null,
      },
    );
  }

  final String id;
  final String make;
  final String model;
  final int? year;
  final String licensePlate;
  final String color;
  final int passengerCapacity;
  final String insuranceProvider;
  final DateTime? insuranceExpiry;
}
