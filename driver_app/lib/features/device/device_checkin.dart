import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// Records the app/device identity after authentication. Failure is silent to
/// the driver because this telemetry must never block dispatch or safety UI.
Future<void> checkInDriverDevice(ProfileRepository profiles) async {
  try {
    final info = DeviceInfoPlugin();
    var id = 'web-${defaultTargetPlatform.name}';
    var os = 'web';
    var emulator = false;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final data = await info.androidInfo;
      id = data.id.isNotEmpty ? data.id : data.model;
      os = 'android';
      emulator = !data.isPhysicalDevice;
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final data = await info.iosInfo;
      id = data.identifierForVendor ?? data.model;
      os = 'ios';
      emulator = !data.isPhysicalDevice;
    }
    if (id.trim().isEmpty) return;
    await profiles.registerDeviceFingerprint(
      deviceHardwareId: id,
      operatingSystem: os,
      appVersion: const String.fromEnvironment(
        'APP_VERSION',
        defaultValue: '0.1.0+1',
      ),
      isEmulator: emulator,
    );
  } catch (_) {}
}
