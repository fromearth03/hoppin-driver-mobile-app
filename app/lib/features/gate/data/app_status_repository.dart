import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/app_status.dart';

/// This build's version, as the gate compares it.
///
/// Kept beside the call that sends it rather than read from the package at
/// runtime: the value has to match `pubspec.yaml`, and a constant that is
/// wrong is found by a grep, while a plugin that fails to answer on some
/// handset silently reports an empty version — which the service reads as
/// "older than every floor" and would force-update the whole fleet.
const appVersion = '0.1.0';

class AppStatusRepository {
  final ApiClient _api;
  AppStatusRepository(this._api);

  /// Reads the launch gate. Public — deliberately callable before sign-in,
  /// because maintenance has to be sayable to someone who cannot log in.
  Future<Result<AppStatus>> read() async {
    final r = await _api.get<Map<String, dynamic>>(
      '/app-status',
      query: {
        'platform': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
        'version': appVersion,
      },
    );
    return r.when(
      ok: (json) => Ok(AppStatus.fromJson(json)),
      err: (e) => Err(e),
    );
  }
}

final appStatusRepositoryProvider = Provider<AppStatusRepository>(
    (ref) => AppStatusRepository(ref.watch(apiClientProvider)));
