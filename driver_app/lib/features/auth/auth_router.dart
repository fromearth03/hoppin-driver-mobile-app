import 'package:go_router/go_router.dart';

import 'reset_landing_screen.dart';

/// Password-reset / invite landing. Allowlisted while signed-out so the
/// emailed link can open the set-password form.
const String kDriverResetRoute = '/reset';

/// The auth riblet's routes, spread into the driver route table.
final authRoutes = <RouteBase>[
  GoRoute(
    path: kDriverResetRoute,
    builder: (_, _) => const DriverResetLandingScreen(),
  ),
];
