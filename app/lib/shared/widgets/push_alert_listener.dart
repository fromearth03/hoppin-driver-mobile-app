import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_router.dart';
import '../../core/push/push_alerts.dart';
import '../../features/profile/data/notification_settings.dart';
import 'app_toast.dart';

/// Turns a parked push alert into a toast.
///
/// Sits in the shell's stack so it is mounted under every screen, and draws
/// nothing itself — the toast goes into the overlay, above the map, the trip
/// sheet and anything else the driver happens to be looking at.
class PushAlertListener extends ConsumerStatefulWidget {
  const PushAlertListener({super.key});

  @override
  ConsumerState<PushAlertListener> createState() => _PushAlertListenerState();
}

class _PushAlertListenerState extends ConsumerState<PushAlertListener> {
  @override
  void initState() {
    super.initState();
    // Reads the stored buzz-or-not choice before the first alert can land,
    // so it is never answered from the default.
    ref.read(notificationHapticsProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<Object?>(pushAlertProvider, (_, next) {
      if (next == null) return;
      final alert = next as dynamic;

      // Post-frame: showing an overlay entry during a build that is still
      // running throws, and this fires from a provider write.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        AppToast.show(
          context,
          title: alert.title as String,
          body: alert.body as String,
          severity:
              (alert.critical as bool) ? ToastSeverity.critical : ToastSeverity.info,
          haptics: ref.read(notificationHapticsProvider),
          onTap: () {
            // A ride alert opens the ride it is about; everything else opens
            // the list where the full text lives.
            final rideId = alert.rideId as String?;
            if (rideId != null && rideId.isNotEmpty) {
              context.go('${Routes.trip}/$rideId');
            } else {
              context.go(Routes.notifications);
            }
          },
        );
        ref.read(pushAlertProvider.notifier).consume();
      });
    });

    return const SizedBox.shrink();
  }
}
