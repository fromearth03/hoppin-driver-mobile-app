/// Test-only tile suppression sentinel for driver tests that render HopMap.
///
/// Passing any non-null value as HopMap's tileProvider suppresses the
/// MapLibreMap platform view so tests run headlessly with no tile HTTP.
/// The type is Object? to match HopMap's seam definition.
library;

/// Sentinel value that suppresses the MapLibreMap platform view under test.
/// Inject via the mapTileProvider override in driver widget tests.
const Object noNetworkTileProvider = 'no-network';

/// Class-form sentinel for tests that instantiate the seam
/// (e.g. `mapTileProvider.overrideWithValue(NoNetworkTileProvider())`).
/// Any non-null instance suppresses the MapLibreMap platform view.
class NoNetworkTileProvider {
  const NoNetworkTileProvider();
}
