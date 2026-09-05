import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/device/device_identity.dart';
import 'core/push/push_service.dart';

/// Injected at build time:
///   flutter run --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only. Every screen is laid out as a phone column and nothing is
  // designed for a landscape driver — rotating produced a broken screen, not
  // a wide one. The Android manifest locks this too; this covers iOS and any
  // platform that ignores the manifest.
  //
  // TODO: lift once landscape has a real layout of its own.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await DeviceIdentity.init();
  await PushService.boot();

  await Supabase.initialize(
    url: _supabaseUrl,
    // `anonKey` is the deprecated name for the publishable key.
    publishableKey: _supabaseAnonKey,
    // The SDK persists the session and refreshes it before expiry, which is
    // why the app keeps no token of its own.
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  _warmMapRenderer();

  runApp(const ProviderScope(child: HoppinDriverApp()));
}

/// Starts the Google Maps renderer while the app is still booting.
///
/// The first map in a session pays for initialising the native renderer, and
/// that first map is the one under a live trip — the driver watches a grey
/// rectangle at the exact moment they need the road. Asking for the newer
/// renderer here moves that cost into the launch, where nothing is waiting
/// on it.
///
/// Deliberately not awaited, and deliberately swallowing failures: a handset
/// that cannot honour the request simply gets whatever renderer it has, which
/// is slower to appear but perfectly correct. Nothing about launching the app
/// may depend on this.
void _warmMapRenderer() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    // Ignoring the result on purpose: whatever renderer the handset ends up
    // with, the map still draws. Only the warm-up is opportunistic.
    GoogleMapsFlutterAndroid()
        .initializeWithRenderer(AndroidMapRenderer.latest)
        .ignore();
  } catch (_) {
    // No maps plugin on this build — the trip screen still works.
  }
}
