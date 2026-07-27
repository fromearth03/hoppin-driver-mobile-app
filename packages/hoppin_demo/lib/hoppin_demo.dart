/// Deterministic demo engine for the Hoppin rider and driver apps.
///
/// Everything the demo compositions need — Wolverhampton-real seed data,
/// snapshot storage, and (in later plans) the DemoWorld simulator, fake
/// repositories, and root provider overrides.
library;

export 'src/auth/demo_auth_service.dart';
export 'src/fakes/fake_ads_repository.dart';
export 'src/fakes/fake_avatar_picker.dart';
export 'src/fakes/fake_driver_repository.dart';
export 'src/fakes/fake_payments_repository.dart';
export 'src/fakes/fake_profile_repository.dart';
export 'src/fakes/fake_rides_repository.dart';
export 'src/fakes/fake_safety_repository.dart';
export 'src/fakes/fake_support_repository.dart';
export 'src/overrides.dart';
export 'src/seed/demo_seed.dart';
export 'src/seed/fares.dart';
export 'src/seed/geo_track.dart';
export 'src/seed/history.dart';
export 'src/seed/personas.dart';
export 'src/seed/places.dart';
export 'src/storage/snapshot_store.dart';
export 'src/world/demo_script.dart';
export 'src/world/demo_world.dart';
export 'src/world/world_snapshot.dart';
