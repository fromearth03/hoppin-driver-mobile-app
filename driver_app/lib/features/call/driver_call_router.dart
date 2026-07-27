import 'package:go_router/go_router.dart';

import 'driver_call_screen.dart';

/// The driver call surface's route — `/trip/:id/call` (OT-11).
///
/// Spread into the app's route table from `router.dart`. The call surface is
/// BUILT, REACHABLE and INERT: it renders the four Figma frames and dials
/// nothing. 15-03 wires the Call control on the runner card that reaches here.
final driverCallRoutes = <RouteBase>[
  GoRoute(
    path: '/trip/:id/call',
    builder: (_, state) =>
        DriverCallScreen(rideId: state.pathParameters['id']!),
  ),
];
