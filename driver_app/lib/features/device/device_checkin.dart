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
        return;
      } on ApiException catch (error) {
        if (error.statusCode >= 400 && error.statusCode < 500) return;
      } catch (_) {
        // Retry transient network and server failures below.
      }
      await Future<void>.delayed(Duration(seconds: attempt + 1));
    }
  } catch (_) {}
}
