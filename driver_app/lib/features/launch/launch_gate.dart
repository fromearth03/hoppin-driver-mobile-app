import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../comms/url_launcher_gateway.dart';

/// Wraps the whole driver app in the `MaterialApp.router` builder: the
/// operator's maintenance / force-update block from `GET /app-status`, painted
/// over EVERYTHING including login.
///
/// 🔴 Fails OPEN (see `appStatusProvider`) and — unlike the rider gate — reaches
/// the OS ONLY through [urlLauncherProvider]. `url_launcher` is deliberately not
/// a driver dependency (the never-dial safeguarding), so the "Update now" button
/// goes through the single audited gateway. The live gateway is a no-op today,
/// so the button does nothing until the external-nav launcher lands — which is
/// honest: better a button that provably launches nothing than a raw call the
/// safeguarding tests cannot see.
class LaunchGate extends ConsumerWidget {
  const LaunchGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(appStatusProvider);
    final gate = status.hasValue ? status.requireValue.gate : AppGate.ok;

    return switch (gate) {
      AppGate.maintenance => const HopLaunchBlock(
          icon: Icons.build_outlined,
          headline: "We're down for maintenance",
          body: "Hoppin is briefly offline while we make things better. "
              "Please check back shortly — you don't need to do anything.",
        ),
      AppGate.forceUpdate => HopLaunchBlock(
          icon: Icons.system_update_outlined,
          headline: 'Update required',
          body: 'This version of Hoppin Driver is no longer supported. Update '
              'to the latest version to keep driving.',
          actionLabel: 'Update now',
          onAction: () => ref
              .read(urlLauncherProvider)
              .launch(Uri.parse('https://hoppin.tech/download')),
        ),
      AppGate.updateAvailable || AppGate.ok => child,
    };
  }
}
