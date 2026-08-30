import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/driver_preferences.dart';

class PreferencesRepository {
  final ApiClient _api;
  PreferencesRepository(this._api);

  Future<Result<DriverPreferences>> load() async {
    final r = await _api.get<Map<String, dynamic>>('/me/preferences');
    return r.when(
      ok: (json) => Ok(DriverPreferences.fromJson(
          Map<String, dynamic>.from((json['preferences'] as Map?) ?? const {}))),
      err: (e) => Err(e),
    );
  }

  Future<Result<void>> save(DriverPreferences prefs) async {
    // The handler binds the body itself as the patch map. A `preferences`
    // envelope would be read as one unknown key and 400 the whole save.
    final r = await _api.patch<dynamic>('/me/preferences',
        body: prefs.toJson());
    return r.when(ok: (_) => const Ok(null), err: (e) => Err(e));
  }
}

final preferencesRepositoryProvider = Provider<PreferencesRepository>(
    (ref) => PreferencesRepository(ref.watch(apiClientProvider)));
