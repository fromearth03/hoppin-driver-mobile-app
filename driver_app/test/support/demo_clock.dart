// Riverpod 3 exports the Override type from misc.dart, not the main barrel.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:hoppin_demo/hoppin_demo.dart';
import 'package:hoppin_driver/features/dashboard/eligibility_builder.dart';

/// 🔴 THE DEMO RUNS ON THE DEMO'S CLOCK. USE THIS IN EVERY DEMO-COMPOSITION TEST.
///
/// Every demo document derives from [DemoSeed.anchor] (30 Jun 2026). The seeded
/// MOT certificate expires `anchor + 20 days` — drawn that way deliberately, to
/// stage the renewal-REMINDER beat on the dashboard.
///
/// Eligibility, correctly, compares documents against `nowProvider`. Left on the
/// wall clock, that made the reminder a real **expiry** on 20 Jul 2026: the
/// compliance gate did exactly its job, refused to let the driver go online, and
/// every demo test that taps GO died — reporting missing dashboard text, which
/// points nowhere near documents or clocks. `driver_loop_test` and
/// `offer_takeover_router_test` both went red on the same day for the same
/// reason and cost hours to trace.
///
/// The general shape, worth recognising elsewhere: **a fixture whose validity is
/// time-RELATIVE over data that is date-ABSOLUTE carries a fuse**, and it goes
/// off far from its cause.
///
/// This lives in one helper rather than nine copies so the next demo test gets
/// it by construction. `main_demo.dart` pins the same seam for the running app.
///
/// Usage:
/// ```dart
/// await tester.pumpWidget(ProviderScope(
///   overrides: [
///     ...driverDemoOverrides(world),
///     demoClockOverride,          // ← keeps the demo in its own time
///   ],
///   child: const DriverApp(),
/// ));
/// ```
final Override demoClockOverride =
    nowProvider.overrideWithValue(() => DemoSeed.anchor);
