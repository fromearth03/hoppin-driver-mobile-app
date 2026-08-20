import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<String>? _androidInstallationIdFuture;

Future<String> _androidInstallationId() {
  return _androidInstallationIdFuture ??= _loadAndroidInstallationId();
}

Future<String> _loadAndroidInstallationId() async {
  const key = 'hoppin_device_fingerprint_v2';
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(key)?.trim();
  if (existing != null && existing.isNotEmpty) return existing;

  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  final id =
      'android-install-${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  await prefs.setString(key, id);
  return id;
}

/// Records the app/device identity after authentication. Returns a displayable
/// message only for a definitive server rejection; transient telemetry errors
/// stay non-blocking.
Future<String?> checkInDriverDevice(ProfileRepository profiles) async {
  try {
    final info = DeviceInfoPlugin();
    var id = 'web-${defaultTargetPlatform.name}';
    var os = 'web';
    var emulator = false;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final data = await info.androidInfo;
      // AndroidDeviceInfo.id is Build.ID, shared by every emulator/device on
      // the same system image. Use a persistent per-install ID instead.
      id = await _androidInstallationId();
      os = 'android';
      emulator = !data.isPhysicalDevice;
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final data = await info.iosInfo;
      id = data.identifierForVendor ?? data.model;
      os = 'ios';
      emulator = !data.isPhysicalDevice;
    }
    if (id.trim().isEmpty) return null;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await profiles.registerDeviceFingerprint(
          deviceHardwareId: id,
          operatingSystem: os,
          appVersion: const String.fromEnvironment(
            'APP_VERSION',
            defaultValue: '0.1.0+1',
          ),
          isEmulator: emulator,
        );
        return null;
      } on ApiException catch (error) {
        if (error.statusCode >= 400 && error.statusCode < 500) {
          return friendlyErrorMessage(error);
        }
      } catch (_) {
        // Retry transient network and server failures below.
      }
      await Future<void>.delayed(Duration(seconds: attempt + 1));
    }
  } catch (_) {}
  return null;
}
