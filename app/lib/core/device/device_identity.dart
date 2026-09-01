import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A stable, app-generated device identity.
///
/// The backend's blacklist gate reads it from the `X-Hoppin-Device-ID`
/// header on every request, and `POST /me/device` files it (with OS and app
/// version) into the admin's Device Fingerprints screen on each sign-in.
/// It is minted once and persisted — reinstalling the app mints a new one,
/// which is the honest limit of an app-level fingerprint.
class DeviceIdentity {
  DeviceIdentity._();

  static const _key = 'hoppin_device_id';
  static String _id = '';

  /// Loaded before the first frame; every ApiClient request reads [id]
  /// synchronously after this.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_key);
      if (id == null || id.isEmpty) {
        id = _mint();
        await prefs.setString(_key, id);
      }
      _id = id;
    } catch (_) {
      // Storage unavailable (odd webviews): a per-launch id still feeds the
      // gate and the ingest, it just won't persist across launches.
      _id = _mint();
    }
  }

  static String get id => _id;

  static String get operatingSystem =>
      kIsWeb ? 'web' : defaultTargetPlatform.name;

  /// Stamped at build time; 'dev' when nobody set it.
  static const appVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

  static String _mint() {
    final r = Random.secure();
    return List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
  }
}
