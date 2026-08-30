import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/onboarding_status.dart';

class OnboardingRepository {
  final ApiClient _api;
  OnboardingRepository(this._api);

  /// The application's progress. Polled by the "under review" screen until an
  /// admin approves, since approval happens elsewhere with no push to wait on.
  Future<Result<DriverOnboarding>> status() async {
    final r = await _api.get<Map<String, dynamic>>('/drivers/me/onboarding');
    return r.when(
      ok: (json) => Ok(DriverOnboarding.fromJson(json)),
      err: (e) => Err(e),
    );
  }

  /// Licence number and home address. Licence numbers are globally unique,
  /// so a clash comes back as `LICENSE_TAKEN` rather than a generic failure.
  Future<Result<void>> saveLicense({
    required String licenseNumber,
    String? address,
  }) async {
    final r = await _api.patch<dynamic>('/drivers/me/onboarding', body: {
      'license_number': licenseNumber.trim(),
      if (address != null) 'address': address.trim(),
    });
    return r.when(ok: (_) => const Ok(null), err: (e) => Err(e));
  }

  /// One row per credential type — posting the same type again updates it.
  /// The admin compliance sweep reads these, so a driver cannot become
  /// compliant without them.
  Future<Result<void>> saveCredential({
    required String type,
    required String number,
    String? shareCode,
    bool isTemporary = false,
    DateTime? expiresAt,
  }) async {
    final r = await _api.post<dynamic>('/drivers/me/credentials', body: {
      'type': type,
      'number': number.trim(),
      if (shareCode != null && shareCode.trim().isNotEmpty)
        'share_code': shareCode.trim(),
      'is_temporary': isTemporary,
      // The server parses a plain ISO date and rejects a full timestamp.
      if (expiresAt != null) 'expires_at': _isoDate(expiresAt),
    });
    return r.when(ok: (_) => const Ok(null), err: (e) => Err(e));
  }

  Future<Result<List<Map<String, dynamic>>>> credentials() async {
    final r = await _api.get<Map<String, dynamic>>('/drivers/me/credentials');
    return r.when(
      ok: (json) => Ok(((json['credentials'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList()),
      err: (e) => Err(e),
    );
  }

  /// Vehicle plus its compliance dates. The compliance sweep reads the MOT
  /// and insurance expiries, so they travel with the vehicle itself.
  Future<Result<void>> saveVehicle({
    required String make,
    required String model,
    required String licensePlate,
    required String color,
    required int year,
    required int passengerCapacity,
    String? insuranceProvider,
    DateTime? insuranceExpiry,
    DateTime? motExpiry,
    bool? cazCompliant,
  }) async {
    final r = await _api.post<dynamic>('/drivers/me/vehicle', body: {
      'make': make.trim(),
      'model': model.trim(),
      'license_plate': licensePlate.trim(),
      'color': color.trim(),
      'year': year,
      'passenger_capacity': passengerCapacity,
      if (insuranceProvider != null && insuranceProvider.trim().isNotEmpty)
        'insurance_provider': insuranceProvider.trim(),
      if (insuranceExpiry != null)
        'insurance_expiry': _isoDate(insuranceExpiry),
      if (motExpiry != null) 'mot_expiry': _isoDate(motExpiry),
      if (cazCompliant != null) 'caz_compliant': cazCompliant,
    });
    return r.when(ok: (_) => const Ok(null), err: (e) => Err(e));
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
    (ref) => OnboardingRepository(ref.watch(apiClientProvider)));
