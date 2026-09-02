import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/app_router.dart';
import 'package:hoppin_driver/shared/nav/tab_transition.dart';

void main() {
  test('moving right along the tabs slides in from the right', () {
    // Home to Earnings: the driver moved along the bar, so the new screen
    // arrives from the direction they moved towards.
    expect(slideDirection(from: Routes.home, to: Routes.earnings), 1);
  });

  test('moving back along the tabs slides in from the left', () {
    expect(slideDirection(from: Routes.earnings, to: Routes.home), -1);
  });

  test('a jump across several tabs keeps its direction', () {
    expect(slideDirection(from: Routes.home, to: Routes.stats), 1);
    expect(slideDirection(from: Routes.stats, to: Routes.home), -1);
  });

  test('a screen outside the tab bar does not slide', () {
    // Trips and Settings are opened from the drawer, not the bar. Sliding
    // them along an axis they do not sit on would imply a position in a row
    // they are not part of.
    expect(slideDirection(from: Routes.home, to: Routes.trips), 0);
    expect(slideDirection(from: Routes.trips, to: Routes.home), 0);
  });

  test('arriving with no previous screen does not slide', () {
    expect(slideDirection(from: null, to: Routes.home), 0);
  });

  test('the same tab does not slide', () {
    expect(slideDirection(from: Routes.home, to: Routes.home), 0);
  });
}
