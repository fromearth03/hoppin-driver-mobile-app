import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../notifications/notification_feed.dart';
import '../notifications/notifications_router.dart';
import '../profile/profile_router.dart';

/// The driver app's persistent chrome: a floating [HopTopBar] (title + bell)
/// over the branch content, with sign-out in the action slot.
///
/// The driver app is single-screen — the dashboard at `/` — so there is no
/// bottom navigation bar. The shell exists to lift the chrome above the
/// scrollable dashboard body so the glass blur samples real content, and to
/// own the bell → notifications path in one place.
///
/// Layout follows the same pattern as [RiderShell]: `extendBodyBehindAppBar` +
/// `extendBody` give the body the full viewport; the bar is painted over it via
/// a [Stack]; [_ChromeInsets] injects the correct top MediaQuery padding so
/// scroll content is not permanently parked under the floating pill.
class DriverShell extends ConsumerWidget {
  const DriverShell({required this.navigationShell, super.key});

  /// The go_router shell. Single branch (dashboard at `/`).
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.hoppin.colors;

    return Scaffold(
      backgroundColor: colors.canvas,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: BackdropGroup(
        child: Stack(
          children: [
            Positioned.fill(child: _ChromeInsets(child: navigationShell)),
            Align(
              alignment: Alignment.topCenter,
              child: HopTopBar(
                title: 'Hoppin Driver',
                notificationCount:
                    ref.watch(unreadDriverNotificationCountProvider),
                onBell: () => context.push(kDriverNotificationsRoute),
                onAvatarTap: () => context.push(kDriverProfileRoute),
                avatarTooltip: 'My profile',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Injects MediaQuery top padding so scroll content clears the floating pill.
class _ChromeInsets extends StatelessWidget {
  const _ChromeInsets({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final chrome = context.hoppin.chrome;

    return MediaQuery(
      data: media.copyWith(
        padding: media.padding.copyWith(
          top: media.padding.top + chrome.scrollPaddingTop,
        ),
      ),
      child: child,
    );
  }
}

