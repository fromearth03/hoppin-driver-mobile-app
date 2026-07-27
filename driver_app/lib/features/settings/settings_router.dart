import 'package:go_router/go_router.dart';

import 'settings_screen.dart';

/// The settings surface. **Exported for Lane D (14-05)** — the dashboard links
/// here rather than hard-coding the literal, so the two cannot drift.
const String kDriverSettingsRoute = '/settings';

/// The settings riblet's routes, spread into the driver route table.
final settingsRoutes = <RouteBase>[
  GoRoute(
    path: kDriverSettingsRoute,
    builder: (_, _) => const DriverSettingsScreen(),
  ),
];
