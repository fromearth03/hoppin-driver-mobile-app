import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import '../../home/data/driver_status_repository.dart';
import '../data/auth_repository.dart';

enum AuthStatus { unknown, signedIn, signedOut }

/// Runs after a successful sign-in. Batch 3 overrides this to register the
/// device's FCM token; keeping it a callback means auth carries no Firebase
/// dependency of its own.
final onSignedInProvider = Provider<Future<void> Function()>(
  (ref) => () async {},
);

/// Mirrors the Supabase SDK's auth state into Riverpod.
///
/// The SDK restores a stored session during `Supabase.initialize` and
/// refreshes tokens on its own schedule, emitting `onAuthStateChange` each
/// time. Subscribing means the app never has to decide when a token is
/// stale — a question it would answer worse than the SDK does.
class AuthController extends Notifier<AuthStatus> {
  @override
  AuthStatus build() {
    final repo = ref.watch(authRepositoryProvider);

    final subscription = repo.authStateChanges.listen((_) {
      state = repo.currentSession != null
          ? AuthStatus.signedIn
          : AuthStatus.signedOut;
    });
    ref.onDispose(subscription.cancel);

    final signedIn = repo.currentSession != null;
    // A driver whose session was restored from storage never passes through
    // signIn, so they would never claim the session row and every request
    // would 401 SESSION_REPLACED. Claim it here too.
    //
    // Read the client up front: deferring the read would reach for a
    // container that may already be gone by the time the future runs.
    if (signedIn) {
      final api = ref.read(apiClientProvider);
      unawaited(repo.claimSession(api));
    }
    return signedIn ? AuthStatus.signedIn : AuthStatus.signedOut;
  }

  Future<Result<void>> signIn(String email, String password) async {
    final result = await ref
        .read(authRepositoryProvider)
        .signIn(email, password);
    return await result.when(
      ok: (_) async {
        state = AuthStatus.signedIn;
        // Claim the one session the service allows for this account before
        // anything else calls it, or every request 401s SESSION_REPLACED
        // against whichever session held the row before.
        await ref
            .read(authRepositoryProvider)
            .claimSession(ref.read(apiClientProvider));
        // A typed sign-in starts the shift OFF. Only an app relaunch
        // mid-shift resumes an online presence (HomeController.build) — a
        // driver entering their password is starting fresh, and inheriting
        // "online" from a previous session would have them dispatchable
        // before they ever saw the toggle. Best-effort: a failure leaves
        // the server state as it was, which Home then reflects honestly.
        await ref
            .read(driverStatusRepositoryProvider)
            .goOffline()
            .catchError((_) => const Ok(null));
        ref.read(onSignedInProvider)();
        return const Ok(null);
      },
      err: (e) async {
        state = AuthStatus.signedOut;
        return Err(e);
      },
    );
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = AuthStatus.signedOut;
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthStatus>(
  AuthController.new,
);
