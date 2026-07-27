import 'package:go_router/go_router.dart';

import 'earnings_screen.dart';

/// The driver's money surface. Reached from the profile hub; renders its own
/// HopTopBar so it sits OUTSIDE the dashboard shell branch.
const String kDriverEarningsRoute = '/earnings';

/// The earnings riblet's routes, spread into the driver route table.
final earningsRoutes = <RouteBase>[
  GoRoute(
    path: kDriverEarningsRoute,
    builder: (_, _) => const DriverEarningsScreen(),
  ),
];
