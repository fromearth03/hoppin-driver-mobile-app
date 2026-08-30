import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/result.dart';
import '../../auth/data/auth_repository.dart';

/// What happened when a driver tried to register.
enum SignupOutcome {
  /// Registered as a driver. Onboarding can begin.
  driver,

  /// The account was created, but registration is closed, so the service made
  /// them a rider instead. Not an error — a real state with its own message.
  registrationClosed,

  /// Created, but no session yet: the address needs confirming by email
  /// before the role claim exists to read.
  needsEmailConfirmation,
}

class SignupState {
  final bool isBusy;
  final SignupOutcome? outcome;
  final ApiException? error;

  const SignupState({this.isBusy = false, this.outcome, this.error});
}

class SignupController extends Notifier<SignupState> {
  bool _disposed = false;

  @override
  SignupState build() {
    ref.onDispose(() => _disposed = true);
    return const SignupState();
  }

  void _emit(SignupState next) {
    if (_disposed) return;
    state = next;
  }

  /// Registers, then checks what the service actually made.
  ///
  /// An admin can close driver registration. With it closed the signup still
  /// succeeds but yields a **rider**, so asking for a driver account is never
  /// proof of holding one — the role claim on the issued token is.
  Future<Result<SignupOutcome>> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    _emit(const SignupState(isBusy: true));
    final repo = ref.read(authRepositoryProvider);

    final result = await repo.signUpDriver(
      email: email,
      password: password,
      fullName: fullName,
      phone: phone,
    );

    return result.when(
      ok: (response) {
        // No session means the project requires email confirmation; the role
        // cannot be read until they come back and sign in.
        final outcome = response.session == null
            ? SignupOutcome.needsEmailConfirmation
            : repo.currentRole == 'driver'
                ? SignupOutcome.driver
                : SignupOutcome.registrationClosed;
        _emit(SignupState(outcome: outcome));
        return Ok(outcome);
      },
      err: (e) {
        _emit(SignupState(error: e));
        return Err(e);
      },
    );
  }
}

final signupControllerProvider =
    NotifierProvider<SignupController, SignupState>(SignupController.new);
