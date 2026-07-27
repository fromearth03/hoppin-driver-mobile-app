import 'package:hoppin_shared/hoppin_shared.dart';

/// The SOS surface — safety is deliberately off-script (nothing scripted
/// raises a panic), so this fake serves constants only and holds no world.
class FakeSafetyRepository implements SafetyRepository {
  const FakeSafetyRepository();

  /// Accepts the panic and returns a fixed event id — the demo never renders
  /// the admin side, so the id only needs to be shaped like the live one.
  @override
  Future<String> raiseSos({
    String? rideId,
    double? lat,
    double? lng,
    String? note,
    String? liveShareUrl,
  }) async =>
      'c4000000-0000-4000-8000-000000000001';

  @override
  Future<List<SosEvent>> myEvents() async => const [];
}
