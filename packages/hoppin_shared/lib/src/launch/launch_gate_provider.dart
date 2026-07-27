import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../models/app_status.dart';
import '../providers.dart';

/// The platform string `GET /app-status` expects, or null on a platform the
/// endpoint does not gate.
///
/// The server only understands `ios` / `android`. On web (the rider's shipped
/// target today) there is no store build to force-update to, so the gate is
/// simply not run — null here means "skip, treat as ok". Overridable in tests.
final launchPlatformProvider = Provider<String?>((ref) {
  if (kIsWeb) return null;
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    TargetPlatform.android => 'android',
    _ => null,
  };
});

/// The launch gate — reads `GET /app-status` ONCE and resolves the decision the
/// app-root overlay acts on (maintenance / force-update / soft-nudge / ok).
///
/// 🔴 Runs BEFORE login: the endpoint is public, and the whole point is to be
/// able to lock a broken or compromised build out of the platform entirely. It
/// is NOT autoDispose — the answer holds for the session; re-checking on every
/// widget rebuild would hammer the endpoint for a value that changes on the
/// scale of a release.
///
/// Fails OPEN: on an ungated platform, a network failure, or a timeout,
/// `appStatus` already returns [AppStatus.unknown] → gate `ok`. A launch check
/// that cannot reach the server must never strand a user on a working app.
final appStatusProvider = FutureProvider<AppStatus>((ref) async {
  final platform = ref.watch(launchPlatformProvider);
  if (platform == null) return AppStatus.unknown;
  return ref.watch(ridesRepositoryProvider).appStatus(
        platform: platform,
        version: Env.appVersion,
      );
});
