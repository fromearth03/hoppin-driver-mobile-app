import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/driver_profile.dart';

class ProfileRepository {
  final ApiClient _api;
  ProfileRepository(this._api);

  Future<Result<DriverProfile>> me() async {
    final r = await _api.get<Map<String, dynamic>>('/me/profile');
    return r.when(
      ok: (json) => Ok(DriverProfile.fromJson(json)),
      err: (e) => Err(e),
    );
  }

  /// Only the fields a driver may change reach the server. Name and photo
  /// are verified by the operator, so offering an edit for them would be an
  /// edit that fails.
  Future<Result<DriverProfile>> update({
    String? phoneNumber,
    String? dateOfBirth,
  }) async {
    final r = await _api.patch<Map<String, dynamic>>('/me/profile', body: {
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
    });
    return r.when(
      ok: (json) => Ok(DriverProfile.fromJson(json)),
      err: (e) => Err(e),
    );
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
    (ref) => ProfileRepository(ref.watch(apiClientProvider)));
