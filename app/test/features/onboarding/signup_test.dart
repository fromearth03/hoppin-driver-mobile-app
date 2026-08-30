import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/auth/data/auth_repository.dart';
import 'package:hoppin_driver/features/onboarding/logic/signup_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockAuthRepo extends Mock implements AuthRepository {}

class FakeAuthResponse extends Fake implements AuthResponse {
  FakeAuthResponse(this._session);
  final Session? _session;
  @override
  Session? get session => _session;
}

class FakeSession extends Fake implements Session {}

void main() {
  late MockAuthRepo repo;

  setUp(() => repo = MockAuthRepo());

  ProviderContainer container() {
    final c = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(c.dispose);
    return c;
  }

  Future<Result<SignupOutcome>> signUp(ProviderContainer c) =>
      c.read(signupControllerProvider.notifier).signUp(
            email: 'sam@example.com',
            password: 'hunter2hunter2',
            fullName: 'Sam Ali',
            phone: '07700900000',
          );

  test('registers with signup_role, never role', () async {
    when(() => repo.signUpDriver(
        email: any(named: 'email'),
        password: any(named: 'password'),
        fullName: any(named: 'fullName'),
        phone: any(named: 'phone'))).thenAnswer(
      (_) async => Ok(FakeAuthResponse(FakeSession())),
    );
    when(() => repo.currentRole).thenReturn('driver');

    final r = await signUp(container());

    expect(r.valueOrNull, SignupOutcome.driver);
  });

  test('a closed registration is reported, not mistaken for a driver',
      () async {
    when(() => repo.signUpDriver(
        email: any(named: 'email'),
        password: any(named: 'password'),
        fullName: any(named: 'fullName'),
        phone: any(named: 'phone'))).thenAnswer(
      (_) async => Ok(FakeAuthResponse(FakeSession())),
    );
    // Registration closed: the service creates a rider rather than an orphan
    // account, so the role claim is the only honest signal.
    when(() => repo.currentRole).thenReturn('rider');

    final r = await signUp(container());

    expect(r.valueOrNull, SignupOutcome.registrationClosed);
  });

  test('an unreadable role is never treated as a driver', () async {
    when(() => repo.signUpDriver(
        email: any(named: 'email'),
        password: any(named: 'password'),
        fullName: any(named: 'fullName'),
        phone: any(named: 'phone'))).thenAnswer(
      (_) async => Ok(FakeAuthResponse(FakeSession())),
    );
    when(() => repo.currentRole).thenReturn(null);

    final r = await signUp(container());

    expect(r.valueOrNull, isNot(SignupOutcome.driver));
  });

  test('no session means the address still needs confirming', () async {
    when(() => repo.signUpDriver(
        email: any(named: 'email'),
        password: any(named: 'password'),
        fullName: any(named: 'fullName'),
        phone: any(named: 'phone'))).thenAnswer(
      (_) async => Ok(FakeAuthResponse(null)),
    );

    final r = await signUp(container());

    expect(r.valueOrNull, SignupOutcome.needsEmailConfirmation);
    // The role claim does not exist yet, so it must not be consulted.
    verifyNever(() => repo.currentRole);
  });

  test('surfaces a rejected signup as an error', () async {
    when(() => repo.signUpDriver(
            email: any(named: 'email'),
            password: any(named: 'password'),
            fullName: any(named: 'fullName'),
            phone: any(named: 'phone')))
        .thenAnswer((_) async =>
            Err(ApiException('AUTH_FAILED', 'User already registered', 400)));

    final c = container();
    final r = await signUp(c);

    expect(r.isOk, isFalse);
    expect(c.read(signupControllerProvider).error, isNotNull);
  });
}
