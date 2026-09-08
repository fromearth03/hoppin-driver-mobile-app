import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/device/shift_service.dart';
import 'package:hoppin_driver/features/home/logic/location_reporter.dart';

/// The location beat is only as good as the process it runs in.
///
/// Android stops a backgrounded app within minutes — sooner on Xiaomi, Oppo
/// and Samsung builds — and the beat dies with it. The driver's phone still
/// says "online", so they wait for offers that cannot arrive. A foreground
/// service is what keeps the process alive, and it has to be tied to the same
/// online/offline switch the beat is, or the two drift apart.
class _FakeShift implements ShiftService {
  int starts = 0;
  int stops = 0;
  bool canPost = true;
  bool startSucceeds = true;

  @override
  Future<bool> canPostNotification() async => canPost;

  @override
  Future<bool> start() async {
    starts++;
    return startSucceeds;
  }

  @override
  Future<void> stop() async => stops++;
}

void main() {
  /// A real Ref from a real container. The reporter only reaches through it
  /// inside a beat, and no beat runs here — start() needs a live geolocation
  /// channel a unit test does not have.
  late ProviderContainer container;
  late Ref ref;

  setUp(() {
    container = ProviderContainer();
    final probe = Provider<Ref>((r) => r);
    ref = container.read(probe);
    addTearDown(container.dispose);
  });

  test('the reporter takes a shift service it can be given a double for', () {
    final shift = _FakeShift();
    // Constructing with an injected service is what makes the wiring testable
    // at all; a hard dependency on the plugin would need a live platform.
    expect(() => LocationReporter(ref, shift: shift), returnsNormally);
  });

  test('stopping the reporter stops the service', () async {
    final shift = _FakeShift();
    LocationReporter(ref, shift: shift).stop();

    // stop() is deliberately fire-and-forget so going offline feels instant,
    // so the call is made synchronously even though it completes later.
    await Future<void>.delayed(Duration.zero);
    expect(shift.stops, 1,
        reason: 'a service left running after the driver goes offline keeps '
            'a notification on their screen and a wake lock on their phone');
  });

  test('a service that will not start does not block going offline', () async {
    final shift = _FakeShift()..startSucceeds = false;
    final reporter = LocationReporter(ref, shift: shift);

    reporter.stop();
    await Future<void>.delayed(Duration.zero);

    expect(shift.stops, 1);
  });
}

