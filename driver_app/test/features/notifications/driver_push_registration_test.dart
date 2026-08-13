import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/notifications/driver_fcm_gateway.dart';
import 'package:hoppin_driver/features/notifications/driver_push_registration.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// 🔴 PUSH REGISTRATION IS **BOUND**. PUSH DELIVERY IS **GATED**. THE TWO ARE
/// NOT THE SAME THING, AND THIS FILE ONLY PROVES THE FIRST.
///
/// **What these tests DO prove:** that when this app has a real token and a real
/// platform, it posts `{fcm_token, device_os: "android"}` to
/// `POST /me/device-tokens` — and that when it does NOT, it posts **nothing**
/// and invents **nothing**.
///
/// **What NO test here — or anywhere — may pretend to prove:** that a push ever
/// ARRIVES. Delivery is blocked on the backend's `FCM_CREDENTIALS_FILE` (#15/#16)
/// and on a push-event schema that has never been published. That is a
/// **HUMAN-VERIFY** gate against a live `:8080`, and it is recorded as one in
/// `apps/driver/README.md`. A green test named "push works" would be a lie about
/// a subsystem the server half of which does not exist.
///
/// **The #69 correction, which this file is the proof of:** gap #69 has been read
/// across the project as "push is blocked". It never blocked the driver. The
/// `device_os` validator accepts `{ios, android}` and rejects only `"web"` — so
/// it blocks the RIDER, which ships web and (correctly) refuses to send a false
/// `"android"` to get past it. **Going Android UNBLOCKS driver registration.**
void main() {
  group('device_os — the value the contract will actually accept', () {
    test('Android → "android" (BOUND; #69 does NOT block the driver)', () {
      expect(
        driverContractDeviceOs(isWeb: false, platform: TargetPlatform.android),
        'android',
        reason: '🔴 THE WHOLE POINT OF THE ANDROID PIVOT. `device_os` validates '
            'against {ios, android}. "android" is a value the contract ALREADY '
            'accepts — so driver token registration is BOUND today, and #69 (a '
            'web-only rejection) has never blocked it.',
      );
    });

    test('web → "web". NOT "android"', () {
      expect(
        driverContractDeviceOs(isWeb: true, platform: TargetPlatform.android),
        'web',
        reason: 'Chrome-on-Android still reports TargetPlatform.android. The '
            'platform is the BROWSER, so we send "web", never a fake "android".',
      );
    });

    test('a desktop dev run registers nothing', () {
      for (final p in const [
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      ]) {
        expect(driverContractDeviceOs(isWeb: false, platform: p), isNull,
            reason: '$p has no contract value. A dev running the driver app on '
                'a laptop must not file their laptop as a driver\'s phone.');
      }
    });
  });

  group('registration', () {
    test('a real token on Android is POSTed with device_os: "android"', () async {
      final profiles = _RecordingProfiles();
      final result = await registerDriverDeviceToken(
        gateway: _Gateway(
          permission: DriverFcmPermission.granted,
          fcmToken: 'a-real-fcm-token',
        ),
        profiles: profiles,
        isWeb: false,
        platform: TargetPlatform.android,
      );

      expect(result, DriverTokenRegistration.registered,
          reason: 'this path is BOUND and it really works');
      expect(profiles.registrations, hasLength(1),
          reason: 'exactly one POST /me/device-tokens');
      expect(profiles.registrations.single.token, 'a-real-fcm-token',
          reason: 'the REAL token, not a placeholder');
      expect(profiles.registrations.single.os, 'android',
          reason: 'the value the contract accepts');
    });

    test('🔴 permission DENIED → nothing is sent, and nothing is invented',
        () async {
      final profiles = _RecordingProfiles();
      final result = await registerDriverDeviceToken(
        gateway: _Gateway(permission: DriverFcmPermission.denied),
        profiles: profiles,
        isWeb: false,
        platform: TargetPlatform.android,
      );

      expect(result, DriverTokenRegistration.gatedNoToken,
          reason: 'the honest state — the driver said no');
      expect(profiles.registrations, isEmpty,
          reason: '🔴 A FABRICATED TOKEN REGISTERED AGAINST A REAL DRIVER FILES '
              'A DEVICE THAT CAN NEVER BE REACHED AS ONE THAT CAN. Dispatch '
              'would then believe it can push this driver an offer. Send '
              'nothing.');
    });

    test('🔴 no token from the OS → nothing is sent', () async {
      final profiles = _RecordingProfiles();
      final result = await registerDriverDeviceToken(
        gateway: _Gateway(
          permission: DriverFcmPermission.granted,
          fcmToken: null,
        ),
        profiles: profiles,
        isWeb: false,
        platform: TargetPlatform.android,
      );

      expect(result, DriverTokenRegistration.gatedNoToken,
          reason: 'permission granted but no Firebase project compiled in — the '
              'default state of this repo today (no google-services.json)');
      expect(profiles.registrations, isEmpty,
          reason: 'a null token means we have nothing to register. We register '
              'nothing.');
    });

    test('web posts device_os: "web"', () async {
      final profiles = _RecordingProfiles();
      final result = await registerDriverDeviceToken(
        gateway: _Gateway(
          permission: DriverFcmPermission.granted,
          fcmToken: 'a-real-fcm-token',
        ),
        profiles: profiles,
        isWeb: true,
        platform: TargetPlatform.android,
      );

      expect(result, DriverTokenRegistration.registered);
      expect(profiles.registrations, hasLength(1));
      expect(profiles.registrations.single.os, 'web');
      expect(profiles.registrations.single.token, 'a-real-fcm-token');
    });

    test('a FAILED registration must never block the shift', () async {
      final result = await registerDriverDeviceToken(
        gateway: _Gateway(
          permission: DriverFcmPermission.granted,
          fcmToken: 'a-real-fcm-token',
        ),
        profiles: _ThrowingProfiles(),
        isWeb: false,
        platform: TargetPlatform.android,
      );

      expect(result, DriverTokenRegistration.gatedNoToken,
          reason: 'it degrades to the honest gated state — it does NOT throw. '
              'Presence, dispatch and the heartbeat are entirely independent of '
              'push; a driver blocked from working because a notification token '
              'would not register would be an absurd defect.');
    });
  });
}

/// A scripted push gateway. Note the absence of a firebase mock: every push call
/// goes through `DriverFcmGateway`, so a test injects a plain Dart object.
class _Gateway implements DriverFcmGateway {
  _Gateway({required this.permission, this.fcmToken});

  final DriverFcmPermission permission;
  final String? fcmToken;

  @override
  Future<DriverFcmPermission> requestPermission() async => permission;

  @override
  Future<String?> token() async => fcmToken;

  // Registration is what this suite is about; delivery is GATED (#15/#16) and
  // nothing arrives. An empty stream is the honest stand-in.
  @override
  Stream<DriverPushMessage> onMessage() => const Stream.empty();
}

class _RecordingProfiles implements ProfileRepository {
  final List<({String token, String os})> registrations = [];

  @override
  Future<void> registerDeviceToken({
    required String fcmToken,
    required String deviceOs,
  }) async {
    registrations.add((token: fcmToken, os: deviceOs));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'push registration must not call ${invocation.memberName}',
      );
}

class _ThrowingProfiles implements ProfileRepository {
  @override
  Future<void> registerDeviceToken({
    required String fcmToken,
    required String deviceOs,
  }) async =>
      throw const ApiException(statusCode: 503, message: 'down');

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'push registration must not call ${invocation.memberName}',
      );
}
