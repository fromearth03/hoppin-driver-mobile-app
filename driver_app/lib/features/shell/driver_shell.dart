import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../notifications/driver_fcm_gateway.dart';
import '../notifications/driver_push_registration.dart';
import '../notifications/notification_feed.dart';
import '../notifications/notifications_router.dart';
import '../profile/profile_router.dart';
import '../device/device_checkin.dart';

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
            const _FcmTokenBinder(),
            Positioned.fill(child: _ChromeInsets(child: navigationShell)),
            Align(
              alignment: Alignment.topCenter,
              child: HopTopBar(
                title: 'Hoppin Driver',
                notificationCount: ref.watch(
                  unreadDriverNotificationCountProvider,
                ),
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

class _FcmTokenBinder extends ConsumerStatefulWidget {
  const _FcmTokenBinder();

  @override
  ConsumerState<_FcmTokenBinder> createState() => _FcmTokenBinderState();
}

class _FcmTokenBinderState extends ConsumerState<_FcmTokenBinder> {
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<DriverPushMessage>? _openedSub;
  StreamSubscription<String>? _tokenSub;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authServiceProvider);
    _authSub = auth.onAuthStateChange.listen((_) {
      if (auth.isSignedIn) {
        unawaited(checkInDriverDevice(ref.read(profileRepositoryProvider)));
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (auth.isSignedIn) {
        unawaited(checkInDriverDevice(ref.read(profileRepositoryProvider)));
      }
      final gateway = ref.read(driverFcmGatewayProvider);
      if (gateway is NoopDriverFcmGateway) return;
      unawaited(
        registerDriverDeviceToken(
          gateway: gateway,
          profiles: ref.read(profileRepositoryProvider),
          isWeb: kIsWeb,
          platform: defaultTargetPlatform,
        ),
      );
      unawaited(gateway.initialMessage().then(_wakeFromPush));
      _openedSub = gateway.onMessageOpened().listen(_wakeFromPush);
      _tokenSub = gateway.onTokenRefresh().listen((token) {
        unawaited(
          ref
              .read(profileRepositoryProvider)
              .registerDeviceToken(
                fcmToken: token,
                deviceOs:
                    driverContractDeviceOs(
                      isWeb: kIsWeb,
                      platform: defaultTargetPlatform,
                    ) ??
                    (kIsWeb ? 'web' : 'android'),
              ),
        );
      });
    });
  }

  void _wakeFromPush(DriverPushMessage? msg) {
    if (msg == null || !mounted) return;
    ref.read(driverNotificationFeedProvider.notifier).add(msg);
    // Offer takeover is attached from the 1s poll on `/`. Deep-link `/offer`
    // without RideOffer extra redirects home anyway — go home and let poll win.
    final link = msg.deepLink;
    if (link == '/offer' || link == null || link.isEmpty) {
      context.go('/');
      return;
    }
    if (link.startsWith('/') && !link.contains('://')) {
      context.go(
        link.startsWith('/trip') || link == '/' || link.startsWith('/chat')
            ? link
            : '/',
      );
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _openedSub?.cancel();
    _tokenSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
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
