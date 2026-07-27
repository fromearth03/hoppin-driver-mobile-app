import 'package:go_router/go_router.dart';

import 'notification_centre_screen.dart';

/// The notification centre route.
///
/// EXPORTED so the dashboard lane can link to it without re-typing the string.
/// A drifted route constant is a bell that lands the driver on the go_router
/// error page.
const String kDriverNotificationsRoute = '/notifications';

/// The notification riblet's routes. Navigation lives in `*_router.dart` files
/// (DOCS/05); `router.dart` only spreads them.
final notificationsRoutes = <RouteBase>[
  GoRoute(
    path: kDriverNotificationsRoute,
    builder: (_, _) => const DriverNotificationCentreScreen(),
  ),
];
