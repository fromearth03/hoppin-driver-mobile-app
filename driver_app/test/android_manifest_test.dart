import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 🔴 THE MANIFEST IS THE CONTRACT WITH ANDROID, AND IT FAILS AT RUNTIME.
///
/// Everything in this phase — the 20-second heartbeat surviving a locked screen,
/// the driver staying in the dispatch pool through an 8-hour shift — rests on
/// eight `<uses-permission>` lines and one `<service>` attribute in an XML file
/// no Dart test would otherwise ever look at.
///
/// **And getting it wrong does not fail the build.** It compiles. It installs.
/// It runs. And then, on Android 14, the moment the driver taps GO,
/// `startForeground()` throws a `MissingForegroundServiceTypeException` and the
/// process dies — on the exact devices our drivers actually own, in the exact
/// moment they are trying to start earning. On Android 10-13 it is quieter and
/// worse: no crash, no error, the service starts, and the OS simply never
/// delivers a background location update. The driver locks their phone, the
/// heartbeat starves, and the admin drops them from the pool five minutes later.
///
/// A green Dart suite over a manifest that says nothing is exactly the shape of
/// failure this project has been bitten by before. So the manifest is asserted,
/// line by line, and every assertion carries the consequence of its absence.
///
/// This file was written the day the manifest stopped being the stock
/// `flutter create` scaffold — which, until v3.0 Phase 2, is precisely what it
/// was: **zero `<uses-permission>`, zero `<service>`.**
void main() {
  late String manifest;
  late String appGradle;

  setUpAll(() {
    manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    appGradle = File('android/app/build.gradle.kts').readAsStringSync();
  });

  bool declares(String permission) =>
      manifest.contains('android.permission.$permission');

  group('permissions', () {
    test('INTERNET — without it nothing reaches the API at all', () {
      expect(declares('INTERNET'), isTrue,
          reason: 'no INTERNET permission means POST /drivers/me/location and '
              'POST /drivers/me/online both fail. The app is inert.');
    });

    test('ACCESS_FINE_LOCATION — the heartbeat has no payload without it', () {
      expect(declares('ACCESS_FINE_LOCATION'), isTrue,
          reason: 'the heartbeat carries a coordinate. No FINE grant, no fix, '
              'no ping — and the driver is dropped from the dispatch pool in 5 '
              'minutes.');
    });

    test('ACCESS_COARSE_LOCATION — Android 12+ lets the driver grant only this',
        () {
      expect(declares('ACCESS_COARSE_LOCATION'), isTrue,
          reason: 'Android 12+ offers the driver an "Approximate" option in the '
              'system dialog. An app that has not DECLARED coarse gets nothing '
              'at all when they pick it. A ~1-3km fix is a bad fix, but it is '
              'an HONEST bad fix and it is still a fix — the alternative is '
              'silence.');
    });

    test(
        '🔴 ACCESS_BACKGROUND_LOCATION — the permission this entire phase '
        'exists for', () {
      expect(declares('ACCESS_BACKGROUND_LOCATION'), isTrue,
          reason: '🔴 WITHOUT THIS THE FOREGROUND SERVICE STILL RUNS AND ANDROID '
              'STILL DELIVERS NOTHING. It is a SEPARATE, second-stage grant '
              '(Android 10 / API 29) that cannot be bundled with the foreground '
              'request and, on Android 11+, cannot be prompted for at all — the '
              'driver must be walked to the Settings app. Undeclared, the '
              'upgrade path does not exist and every driver on this app is a '
              'foreground-only driver whose shift dies at the lock screen. '
              'See seam #85 / BackgroundLocationLimitedNotice.');
    });

    test('FOREGROUND_SERVICE — the service cannot start without it', () {
      expect(declares('FOREGROUND_SERVICE'), isTrue,
          reason: 'startForeground() throws a SecurityException without it.');
    });

    test(
        '🔴 FOREGROUND_SERVICE_LOCATION — Android 14 THROWS without it',
        () {
      expect(declares('FOREGROUND_SERVICE_LOCATION'), isTrue,
          reason: '🔴 ANDROID 14 (API 34) HARD REQUIREMENT. A foreground service '
              'that accesses location must hold this permission AND declare a '
              'matching foregroundServiceType. Missing either half and '
              'startForeground() throws — the app DIES the instant the driver '
              'taps GO. Not a warning. Not a lint. A crash, in production, at '
              'the exact moment a driver tries to start earning.');
    });

    test('POST_NOTIFICATIONS — Android 13+ made the notification a grant', () {
      expect(declares('POST_NOTIFICATIONS'), isTrue,
          reason: 'Android 13 (API 33) made notifications a runtime permission. '
              'The foreground service\'s PERSISTENT NOTIFICATION is the OS\'s '
              'contract for keeping our isolate alive with the screen off — so '
              'this is not a push nicety, it is part of the shift itself.');
    });

    test('WAKE_LOCK — Doze turns a 20s heartbeat into a several-minute one', () {
      expect(declares('WAKE_LOCK'), isTrue,
          reason: 'across an 8-hour shift with the screen off, Doze will stretch '
              'the 20-second cadence until it misses the server\'s 5-minute '
              'presence window — and a dropped driver does not know they were '
              'dropped.');
    });
  });

  group('🔴 the typed foreground service', () {
    test('a <service> is declared at all', () {
      expect(manifest.contains('<service'), isTrue,
          reason: 'until Phase 2 this manifest was the stock `flutter create` '
              'scaffold: ZERO uses-permission, ZERO service. A driver app with '
              'no foreground service cannot hold a shift.');
    });

    test('🔴 foregroundServiceType="location" is declared', () {
      expect(
        RegExp(r'android:foregroundServiceType\s*=\s*"location"')
            .hasMatch(manifest),
        isTrue,
        reason: '🔴 THE ANDROID-14 CONTRACT, THE OTHER HALF. The permission '
            'above and this attribute must BOTH be present, and they must AGREE. '
            'Declaring FOREGROUND_SERVICE_LOCATION without this attribute is the '
            'same crash as declaring neither: startForeground() throws '
            'MissingForegroundServiceTypeException and the process dies on GO. '
            'It must also match the Dart side\'s '
            '`serviceTypes: [ForegroundServiceTypes.location]`.',
      );
    });

    test('the service is NOT exported', () {
      expect(
        RegExp(r'<service[\s\S]*?android:exported\s*=\s*"false"')
            .hasMatch(manifest),
        isTrue,
        reason: 'nothing outside this app may start a driver\'s shift.',
      );
    });

    test(
        '🔴 stopWithTask="false" — swiping the app away does NOT clock a driver '
        'off', () {
      expect(
        RegExp(r'<service[\s\S]*?android:stopWithTask\s*=\s*"false"')
            .hasMatch(manifest),
        isTrue,
        reason: '🔴 A DRIVER WHO SWIPES THE APP OUT OF RECENTS HAS NOT CLOCKED '
            'OFF. Only "Go offline" does that, because only "Go offline" calls '
            'POST /drivers/me/offline. If the service died on task-removal, the '
            'driver would stay in the SERVER\'S pool with no heartbeat — '
            'online, undispatchable, and told nothing. That is the precise bug '
            'this whole milestone exists to delete, rebuilt in a different '
            'place.',
      );
    });
  });

  group('gradle', () {
    test('🔴 the EFFECTIVE minSdk is at least 23 (flutter_foreground_task)', () {
      // 🔴 THIS ASSERTS THE FLOOR, NOT THE SPELLING — and that distinction cost
      // me an hour, so it is worth writing down.
      //
      // The first version of this test asserted the literal `minSdk = 23` in
      // build.gradle.kts. It went RED on the very next `flutter build`, because
      // the Flutter gradle tooling REWRITES a hardcoded literal back to
      // `flutter.minSdkVersion` automatically. A "pin" that silently reverts is
      // worse than no pin, because it is believed.
      //
      // So we resolve what the app ACTUALLY compiles against: either an explicit
      // literal, or Flutter's own default (read from the SDK, not from memory).
      // If Flutter ever drops its default below 23, this goes RED and names the
      // plugin that broke — which is the thing we actually care about.
      final literal =
          RegExp(r'minSdk\s*=\s*(\d+)').firstMatch(appGradle)?.group(1);

      int? effective = literal == null ? null : int.tryParse(literal);

      if (effective == null) {
        // `minSdk = flutter.minSdkVersion` — go and read what that actually IS,
        // from the SDK on this machine. Walk up from the running Dart binary
        // (`<flutter>/bin/cache/dart-sdk/bin/dart`) until the Flutter SDK root
        // appears, rather than hardcoding a depth the SDK layout is free to
        // change.
        const relative =
            'packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt';
        File? ext;
        var dir = File(Platform.resolvedExecutable).parent;
        for (var i = 0; i < 8; i++) {
          final candidate = File('${dir.path}/$relative');
          if (candidate.existsSync()) {
            ext = candidate;
            break;
          }
          if (dir.parent.path == dir.path) break; // hit the filesystem root
          dir = dir.parent;
        }

        expect(ext, isNotNull,
            reason: 'could not locate FlutterExtension.kt to resolve '
                '`flutter.minSdkVersion`. If the Flutter SDK layout has moved, '
                'FIX THIS LOOKUP — do not delete the assertion. The floor is the '
                'point, not the mechanism for finding it.');
        final m = RegExp(r'minSdkVersion:\s*Int\s*=\s*(\d+)')
            .firstMatch(ext!.readAsStringSync());
        expect(m, isNotNull,
            reason: 'could not parse `flutter.minSdkVersion` out of '
                'FlutterExtension.kt');
        effective = int.parse(m!.group(1)!);
      }

      expect(
        effective,
        greaterThanOrEqualTo(23),
        reason: '🔴 flutter_foreground_task REQUIRES API 23 (Marshmallow), and '
            'firebase_messaging requires 21+. Below 23 the foreground service — '
            'the entire point of this phase — does not exist, and a driver who '
            'locks their phone is dropped from the dispatch pool in 5 minutes '
            'with no warning. The effective minSdk resolved to $effective. If '
            'that is because Flutter lowered its default, PIN IT explicitly here '
            'and accept that `flutter build` will fight you.',
      );
    });

    test('a release signing config exists', () {
      expect(appGradle.contains('signingConfigs'), isTrue,
          reason: 'a Play upload needs a real keystore. See '
              'apps/driver/README.md for the documented release command; the '
              'keystore itself is gitignored and lives in android/key.properties.');
    });

    test(
        '🔴 google-services.json is NOT committed (a fabricated credential '
        'record would be worse than none)', () {
      expect(
        File('android/app/google-services.json').existsSync(),
        isFalse,
        reason: '🔴 A PLACEHOLDER google-services.json IN THE REPO IS A '
            'FABRICATED CREDENTIAL RECORD. The build would succeed, '
            'firebase_core would "initialise", and every token request would '
            'fail against a Firebase project that does not exist — a green '
            'build that LIES about being push-capable. Absent the file, '
            'build.gradle.kts skips the google-services plugin, main.dart\'s '
            'guarded initializeApp() fails softly, and the app boots on '
            'NoopDriverFcmGateway, which reports the gate honestly. The real '
            'file is gitignored; google-services.json.example documents the '
            'shape.',
      );
      expect(
        File('android/app/google-services.json.example').existsSync(),
        isTrue,
        reason: 'the template must exist, or nobody can wire push without '
            'guessing.',
      );
    });
  });

  test('🔴 the WEB target is GONE (D1)', () {
    expect(
      Directory('web').existsSync(),
      isFalse,
      reason: '🔴 D1, AND IT IS NOT A PREFERENCE. A browser tab CANNOT hold a '
          'driver\'s shift. Geolocation is not exposed to '
          'ServiceWorkerGlobalScope — the only web context that survives a '
          'backgrounded tab — and the W3C declined to spec it. Chrome freezes '
          'hidden tabs and clamps their timers to ~1/min. iOS Safari suspends '
          'watchPosition when backgrounded. The server drops a driver after 5 '
          'minutes without a ping. There is no web mitigation for that: not a '
          'hard one, NONE. Leaving a web/ directory here would leave a '
          'buildable target that silently drops every driver who uses it.',
    );
  });
}
