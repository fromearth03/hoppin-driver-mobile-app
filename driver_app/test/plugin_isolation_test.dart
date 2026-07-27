import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/notifications/driver_fcm_gateway.dart';
import 'package:hoppin_driver/features/presence/shift_service.dart';

/// 🔴 THE PLUGIN-ISOLATION CONTRACT, AS A MACHINE ASSERTION.
///
/// **The rule:** the ABSTRACTION is pure Dart; the IMPLEMENTATION is app-local.
/// `geolocator`, `permission_handler`, `flutter_foreground_task`, `firebase_*` —
/// none of them may appear in `packages/` (`hoppin_shared`, `hoppin_ui`,
/// `hoppin_demo`), and each is confined to exactly one file inside
/// `apps/driver/lib`.
///
/// **Why it is worth a test rather than a code-review promise:**
///
///  1. **The shared packages are consumed by BOTH apps.** A platform plugin that
///     leaks into `hoppin_shared` drags an Android/iOS-only dependency into the
///     rider's WEB build, and the failure surfaces as an opaque compile error in
///     someone else's milestone.
///  2. **It is what keeps `flutter test` off a MethodChannel.** Every location
///     call goes through `DriverLocationService`; every foreground-service call
///     through `DriverShiftService`; every push call through
///     `DriverFcmGateway`. Tests inject a plain Dart fake and drive every
///     failure path. **There is not one MethodChannel mock in this repository**,
///     and there does not need to be — but that property is only true as long as
///     no widget, interactor, or test can reach a plugin directly. This test is
///     what makes it structurally true rather than currently true.
///  3. **A leak is silent.** Nothing fails. The suite stays green. It is exactly
///     the shape of every defect this project has paid for.
void main() {
  Iterable<({String path, String text})> dartFilesUnder(String dir) sync* {
    final d = Directory(dir);
    if (!d.existsSync()) return;
    for (final f in d.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      // Generated code (freezed/json) never imports a platform plugin, and its
      // `.g.dart` line noise is not ours to police.
      if (f.path.endsWith('.g.dart') || f.path.endsWith('.freezed.dart')) {
        continue;
      }
      yield (path: f.path.replaceAll(r'\', '/'), text: f.readAsStringSync());
    }
  }

  /// The shared packages, from the driver app's working directory.
  const sharedRoots = [
    '../../packages/hoppin_shared/lib',
    '../../packages/hoppin_ui/lib',
    '../../packages/hoppin_demo/lib',
  ];

  const isolatedPlugins = {
    'geolocator': 'location fixes',
    'permission_handler': 'OS permissions',
    'flutter_foreground_task': 'the Android foreground service',
    'firebase_core': 'push',
    'firebase_messaging': 'push',
  };

  group('🔴 no platform plugin reaches packages/', () {
    for (final entry in isolatedPlugins.entries) {
      test('`package:${entry.key}` appears NOWHERE in packages/', () {
        final needle = "package:${entry.key}";
        final leaks = <String>[];
        for (final root in sharedRoots) {
          for (final f in dartFilesUnder(root)) {
            if (f.text.contains(needle)) leaks.add(f.path);
          }
        }
        expect(
          leaks,
          isEmpty,
          reason:
              '`${entry.key}` (${entry.value}) leaked into the SHARED packages:\n'
              '  ${leaks.join('\n  ')}\n\n'
              'The shared packages are consumed by the RIDER too, which is a WEB '
              'build — an Android-only plugin in hoppin_shared breaks a '
              'milestone that is not yours, and it breaks it as an opaque '
              'compile error. The abstraction is pure Dart and lives in the app; '
              'the implementation is app-local. Move it.',
        );
      });
    }
  });

  group('each plugin is confined to ONE implementation file in apps/driver', () {
    /// The single file each plugin is allowed to live in. Anything else
    /// importing it means a widget, an interactor, or a test can reach the
    /// platform directly — and the seam has stopped being a seam.
    const confinement = <String, String>{
      'geolocator': 'lib/features/location/location_service.dart',
      'flutter_foreground_task':
          'lib/features/presence/android_shift_service.dart',
      'firebase_messaging':
          'lib/features/notifications/firebase_driver_fcm_gateway.dart',
      // firebase_core is imported by main.dart too — the one guarded
      // `Firebase.initializeApp()`. Nothing else.
      'firebase_core': 'lib/main.dart',
    };

    for (final entry in confinement.entries) {
      test('`package:${entry.key}` is imported only by ${entry.value}', () {
        final needle = "package:${entry.key}";
        final importers = dartFilesUnder('lib')
            .where((f) => f.text.contains(needle))
            .map((f) => f.path)
            .toList()
          ..sort();

        expect(
          importers,
          [entry.value],
          reason:
              'Exactly ONE file may import `${entry.key}`, and it is '
              '${entry.value}. Found: ${importers.join(', ')}.\n\n'
              'Every extra importer is a place a widget or an interactor can '
              'reach the platform without going through the seam — and the '
              'moment that happens, a test of that code needs a MethodChannel '
              'mock. There is not one in this repository. Keep it that way: put '
              'the call behind DriverLocationService / DriverShiftService / '
              'DriverFcmGateway and inject a fake.',
        );
      });
    }

    test('permission_handler is not imported ANYWHERE in the driver app', () {
      // It is a declared dependency (pinned to the rider's version so the ONE
      // shared workspace lockfile resolves), but the driver reaches OS
      // permissions through geolocator's own API. A second permissions plugin
      // in the call path is a second source of truth about the same grant.
      final importers = dartFilesUnder('lib')
          .where((f) => f.text.contains('package:permission_handler'))
          .map((f) => f.path)
          .toList();
      expect(importers, isEmpty,
          reason: 'the driver reads permissions through geolocator. Two '
              'permission plugins answering the same question is two answers.');
    });
  });

  test('🔴 the DEFAULT seams are the honest no-ops, not the platform impls', () {
    // This is what makes "no MethodChannel mocks anywhere" structurally true:
    // every test that does not explicitly override these providers gets an
    // object that cannot touch a platform channel — and that object reports the
    // TRUTH (`false`, `null`), never an optimistic guess.
    const shift = NoopDriverShiftService();
    const fcm = NoopDriverFcmGateway();

    expect(shift, isA<DriverShiftService>(),
        reason: 'the no-op satisfies the seam');
    expect(fcm, isA<DriverFcmGateway>(), reason: 'the no-op satisfies the seam');

    expectLater(shift.start(), completion(isFalse),
        reason: '🔴 THE NO-OP MUST REPORT `false` AND MEAN IT. A `true` here — '
            '"well, in production it would work" — is exactly the comfortable '
            'lie this project exists to delete: it would let a test assert '
            'background protection that the test platform cannot possibly '
            'provide, and the assertion would be worthless.');
    expectLater(fcm.token(), completion(isNull),
        reason: 'no Firebase project means NO TOKEN. A fabricated one, '
            'registered against a real driver, files a device that can never be '
            'reached as one that can.');
  });
}
