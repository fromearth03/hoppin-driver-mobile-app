import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  runApp(const ProviderScope(child: HoppinDriverApp()));
}
