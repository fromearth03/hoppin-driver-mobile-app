import 'package:go_router/go_router.dart';

import 'personal_info_screen.dart';
import 'profile_screen.dart';
import 'vehicle_details_screen.dart';
import '../promotions/driver_promotions_screen.dart';

/// The profile hub. **Exported for Lane D (14-05)** — the dashboard links here
/// rather than hard-coding the literal, so the two cannot drift.
const String kDriverProfileRoute = '/profile';

/// The read-only personal-information surface (#39).
const String kDriverPersonalRoute = '/profile/personal';

/// The authenticated driver's registered vehicle.
const String kDriverVehicleRoute = '/profile/vehicle';

/// Active driver bonus campaigns.
const String kDriverPromotionsRoute = '/profile/promotions';

/// The profile riblet's routes, spread into the driver route table.
final profileRoutes = <RouteBase>[
  GoRoute(
    path: kDriverProfileRoute,
    builder: (_, _) => const DriverProfileScreen(),
  ),
  GoRoute(
    path: kDriverPersonalRoute,
    builder: (_, _) => const DriverPersonalInfoScreen(),
  ),
  GoRoute(
    path: kDriverVehicleRoute,
    builder: (_, _) => const DriverVehicleDetailsScreen(),
  ),
  GoRoute(
    path: kDriverPromotionsRoute,
    builder: (_, _) => const DriverPromotionsScreen(),
  ),
];
