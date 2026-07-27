import 'package:go_router/go_router.dart';

import 'reset_landing_screen.dart';

/// The password-reset deep-link landing (#49).
///
/// 🔴 Reachable while **SIGNED OUT** — `router.dart` allowlists it in the
/// redirect. A driver clicking a reset link is by definition not signed in.
const String kDriverResetRoute = '/reset';

/// The auth riblet's routes, spread into the driver route table.
final authRoutes = <RouteBase>[
  GoRoute(
    path: kDriverResetRoute,
    builder: (_, _) => const DriverResetLandingScreen(),
  ),
];
