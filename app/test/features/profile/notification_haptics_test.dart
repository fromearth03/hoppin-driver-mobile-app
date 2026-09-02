import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/profile/data/notification_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('alerts buzz until the driver says otherwise', () async {
    // A driver who misses a penalty toast because their handset stayed
    // silent is worse off than one mildly annoyed by a buzz.
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(notificationHapticsProvider.notifier).load();

    expect(c.read(notificationHapticsProvider), isTrue);
  });

  test('the choice outlives the app', () async {
    final first = ProviderContainer();
    await first.read(notificationHapticsProvider.notifier).load();
    await first.read(notificationHapticsProvider.notifier).set(false);
    first.dispose();

    final second = ProviderContainer();
    addTearDown(second.dispose);
    await second.read(notificationHapticsProvider.notifier).load();

    expect(second.read(notificationHapticsProvider), isFalse);
  });
}
