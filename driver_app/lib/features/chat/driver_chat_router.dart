import 'package:go_router/go_router.dart';

import 'driver_chat_builder.dart';

/// ALL chat navigation lives in this file (riblet rule, DOCS/05).
///
/// The Chat control that reaches this route is wired by 15-03 onto the trip
/// runner card — a ONE-TAP, unwrapped button (it stays live in motion; it is not
/// text entry). This lane exports the route; 15-03 wires the entry point.
final driverChatRoutes = <RouteBase>[
  GoRoute(
    path: '/trip/:id/chat',
    builder: (_, state) =>
        DriverChatRiblet(rideId: state.pathParameters['id']!),
  ),
];
