import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/gate/data/models/app_status.dart';

void main() {
  test('reads the gate the service actually sent', () {
    final s = AppStatus.fromJson(const {
      'platform': 'android',
      'minimum_required_version': '2.1.0',
      'latest_version': '2.4.0',
      'maintenance_mode': true,
      'update_available': true,
      'force_update_required': true,
    });

    expect(s.maintenanceMode, isTrue);
    expect(s.forceUpdateRequired, isTrue);
    expect(s.latestVersion, '2.4.0');
  });

  test('an unconfigured platform gates nothing', () {
    // The handler answers `{"platform":"android"}` with nothing else when no
    // config row exists. Reading a missing flag as true would lock every
    // driver out of the app.
    final s = AppStatus.fromJson(const {'platform': 'android'});

    expect(s.maintenanceMode, isFalse);
    expect(s.forceUpdateRequired, isFalse);
    expect(s.updateAvailable, isFalse);
  });

  test('maintenance outranks a forced update', () {
    // Both can be armed at once. Telling a driver to go and update from a
    // store while the service is down would send them somewhere that cannot
    // help.
    final s = AppStatus.fromJson(const {
      'maintenance_mode': true,
      'force_update_required': true,
    });

    expect(s.blocks, isTrue);
    expect(s.gate, AppGate.maintenance);
  });

  test('a forced update blocks on its own', () {
    final s = AppStatus.fromJson(const {'force_update_required': true});

    expect(s.blocks, isTrue);
    expect(s.gate, AppGate.forceUpdate);
  });

  test('an optional update never blocks', () {
    // update_available is a nudge, not a gate: a driver mid-shift must not be
    // stopped from working because a nicer build exists.
    final s = AppStatus.fromJson(const {'update_available': true});

    expect(s.blocks, isFalse);
    expect(s.gate, AppGate.none);
  });
}
