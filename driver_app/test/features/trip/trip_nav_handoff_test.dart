import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/trip/trip_nav_handoff.dart';

import '../../support/source_scan.dart';

/// OT-16 — external turn-by-turn nav goes through the ONE gateway, never a raw
/// launch. The recorder only sees what goes through `urlLauncherProvider`; a
/// raw launch would be a hole in the guarantee.
void main() {
  test('the hand-off launches through urlLauncherProvider, not a raw call',
      () async {
    final launcher = _RecordingLauncher();
    final container = ProviderContainer(
      overrides: [urlLauncherProvider.overrideWithValue(launcher)],
    );
    addTearDown(container.dispose);

    final handled = await launchNavHandoff(
      container.read(_refProvider),
      destLat: 52.5876,
      destLng: -2.1268,
    );

    expect(launcher.launched, hasLength(1),
        reason: 'the nav hand-off did not go through the gateway');
    final uri = launcher.launched.single;
    expect(uri.host, 'www.google.com');
    expect(uri.queryParameters['destination'], '52.5876,-2.1268');
    // The live gateway is a no-op that answers false — honest, never a fake.
    expect(handled, isFalse);
  });

  test('buildNavHandoffUrl is the cross-platform Google Maps directions form',
      () {
    final uri = buildNavHandoffUrl(destLat: 1.5, destLng: -2.5);
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/dir/');
    expect(uri.queryParameters['api'], '1');
    // Decoded back from the URL-encoded comma — the destination pair round-trips.
    expect(uri.queryParameters['destination'], '1.5,-2.5');
    expect(uri.queryParameters['travelmode'], 'driving');
  });

  test('source: no RAW launchUrl anywhere under features/trip', () {
    // The gateway is the only launch path. A raw `launchUrl(` would dodge the
    // recorder and break the "everything goes through the gateway" guarantee.
    final offenders = <String>[];
    for (final source in scanDartSources()
        .where((s) => s.path.contains('/features/trip/'))) {
      for (var i = 0; i < source.lines.length; i++) {
        if (RegExp(r'\blaunchUrl\s*\(').hasMatch(source.lines[i])) {
          offenders.add('${source.path}:${i + 1}  ${source.lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: '🔴 a raw launchUrl bypasses the gateway:\n'
            '${offenders.join('\n')}');
  });
}

/// Exposes the container's own [Ref] so [launchNavHandoff] (which takes a Ref)
/// can be driven from a test.
final _refProvider = Provider<Ref>((ref) => ref);

class _RecordingLauncher implements UrlLauncher {
  final launched = <Uri>[];

  @override
  Future<bool> launch(Uri uri) async {
    launched.add(uri);
    return false;
  }
}
