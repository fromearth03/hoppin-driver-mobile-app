import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/launch/launch_gate.dart';
import 'router.dart';
import 'theme.dart';

/// Theme mode of the app shell. Live builds follow the platform until the
/// driver chooses; the demo entrypoint composes [DriverThemeModeController.forced]
/// at the root ProviderScope when a `?theme=` query param pins a mode — a
/// provider-level seam, same pattern as loginPrefillProvider. Views never
/// branch on demo mode.
///
/// It became SETTABLE for the Settings screen's theme toggle, which is the one
/// genuinely working control on that surface. A toggle wired to a local bool
/// that the shell never watches would be exactly the false-persistence signal
/// the rest of that screen exists to refuse.
final themeModeProvider =
    NotifierProvider<DriverThemeModeController, ThemeMode>(
  DriverThemeModeController.new,
);

/// The session store behind [themeModeProvider].
///
/// 🔴 **Session-scoped, and honestly labelled as such.** There is no
/// persistence package in this repo by deliberate ruling, so the choice dies on
/// relaunch. The settings rung says so rather than letting the driver discover
/// it.
class DriverThemeModeController extends Notifier<ThemeMode> {
  /// The live controller — follows the platform until the driver says
  /// otherwise.
  DriverThemeModeController() : _forced = null;

  /// A pinned controller. DEMO composition only.
  DriverThemeModeController.forced(ThemeMode mode) : _forced = mode;

  final ThemeMode? _forced;

  @override
  ThemeMode build() => _forced ?? ThemeMode.system;

  /// Applies [mode] for the rest of the session.
  void set(ThemeMode mode) {
    if (_forced != null) return;
    state = mode;
  }
}

/// Root widget for the driver app.
class DriverApp extends ConsumerWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(driverRouterProvider);
    return MaterialApp.router(
      title: 'Hoppin Driver',
      debugShowCheckedModeBanner: false,
      theme: hoppinDriverLightTheme,
      darkTheme: hoppinDriverDarkTheme,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
      // Operator launch gate over every route (login included). Fails open.
      builder: (context, child) =>
          LaunchGate(child: child ?? const SizedBox.shrink()),
    );
  }
}
