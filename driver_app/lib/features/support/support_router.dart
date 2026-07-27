import 'package:go_router/go_router.dart';

import 'help_support_screen.dart';
import 'support_screen.dart';
import 'ticket_screen.dart';

/// The driver's support hub route.
///
/// 🔴 EXPORTED FOR PHASE 4. The "I'm stuck" exit for a driver trapped at a
/// no-show pickup routes here — `PATCH /rides/:id/cancel` needs a `reason_id`
/// no endpoint lists (#1), so every driver cancel currently 400s and support is
/// the only real exit. Phase 4 imports this constant; it does not re-type the
/// string. Two copies of a load-bearing route WILL drift, and a drifted route
/// is a stuck driver landing on the go_router error page.
const String kDriverSupportRoute = '/support';

/// The help hub route — FAQ-shaped rows that all lead to a real ticket.
const String kDriverHelpRoute = '/help';

/// The support riblet's routes. Navigation lives in `*_router.dart` files
/// (DOCS/05); `router.dart` only spreads them.
final supportRoutes = <RouteBase>[
  GoRoute(
    path: kDriverHelpRoute,
    builder: (_, _) => const DriverHelpSupportScreen(),
  ),
  GoRoute(
    path: kDriverSupportRoute,
    builder: (_, _) => const DriverSupportScreen(),
  ),
  GoRoute(
    path: '$kDriverSupportRoute/:id',
    builder: (_, s) => DriverTicketScreen(ticketId: s.pathParameters['id']!),
  ),
];
