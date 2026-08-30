import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result.dart';
import '../data/auth_repository.dart';

enum AuthStatus { unknown, signedIn, signedOut }

/// Runs after a successful sign-in. Batch 3 overrides this to register the
/// device's FCM token; keeping it a callback means auth carries no Firebase
/// dependency of its own.
final onSignedInProvider =
    Provider<Future<void> Function()>((ref) => () async {});

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

    return repo.currentSession != null
        ? AuthStatus.signedIn
        : AuthStatus.signedOut;
  }

  Future<Result<void>> signIn(String email, String password) async {
    final result =
        await ref.read(authRepositoryProvider).signIn(email, password);
    return result.when(
      ok: (_) {
        state = AuthStatus.signedIn;
        ref.read(onSignedInProvider)();
        return const Ok(null);
      },
      err: (e) {
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

final authControllerProvider =
    NotifierProvider<AuthController, AuthStatus>(AuthController.new);
