import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/auth/data/auth_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockGoTrue extends Mock implements GoTrueClient {}

class _MockSupabase extends Mock implements SupabaseClient {}

Session testSession() => Session(
      accessToken: 'jwt',
      tokenType: 'bearer',
      user: User(
        id: 'u1',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      ),
    );

void main() {
  setUpAll(() => registerFallbackValue(UserAttributes()));

  late _MockGoTrue auth;
  late _MockSupabase client;
  late AuthRepository repo;

  setUp(() {
    auth = _MockGoTrue();
    client = _MockSupabase();
    when(() => client.auth).thenReturn(auth);
    repo = AuthRepository(client);
  });

  test('signIn returns the SDK session', () async {
    when(() => auth.signInWithPassword(
            email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async => AuthResponse(session: testSession()));

    final r = await repo.signIn('d@hoppin.tech', 'pw');

    expect(r.isOk, isTrue);
    expect(r.valueOrNull!.accessToken, 'jwt');
  });

  test('bad credentials map to INVALID_CREDENTIALS', () async {
    when(() => auth.signInWithPassword(
            email: any(named: 'email'), password: any(named: 'password')))
        .thenThrow(
            const AuthException('Invalid login credentials', statusCode: '400'));

    final r = await repo.signIn('d@hoppin.tech', 'wrong');

    expect(r.errorOrNull!.code, 'INVALID_CREDENTIALS');
  });

  test('rate limiting maps to TOO_MANY_ATTEMPTS', () async {
    when(() => auth.signInWithPassword(
            email: any(named: 'email'), password: any(named: 'password')))
        .thenThrow(const AuthException('rate limit', statusCode: '429'));

    final r = await repo.signIn('d@hoppin.tech', 'pw');

    expect(r.errorOrNull!.code, 'TOO_MANY_ATTEMPTS');
  });

  test('an expired recovery link maps to EXPIRED_LINK', () async {
    when(() => auth.updateUser(any()))
        .thenThrow(const AuthException('token has expired', statusCode: '401'));

    final r = await repo.updatePassword('newpassword1');

    expect(r.errorOrNull!.code, 'EXPIRED_LINK');
  });

  test('a null session on success is still a failure', () async {
    when(() => auth.signInWithPassword(
            email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async => AuthResponse());

    final r = await repo.signIn('d@hoppin.tech', 'pw');

    expect(r.errorOrNull!.code, 'AUTH_FAILED');
  });

  test('a network failure maps to INTERNAL and is retryable', () async {
    when(() => auth.signInWithPassword(
            email: any(named: 'email'), password: any(named: 'password')))
        .thenThrow(Exception('SocketException: failed host lookup'));

    final r = await repo.signIn('d@hoppin.tech', 'pw');

    expect(r.errorOrNull!.code, 'INTERNAL');
    expect(r.errorOrNull!.isRetryable, isTrue);
  });

  test('requestPasswordReset succeeds', () async {
    when(() => auth.resetPasswordForEmail(any(),
        redirectTo: any(named: 'redirectTo'))).thenAnswer((_) async {});

    final r = await repo.requestPasswordReset('d@hoppin.tech');

    expect(r.isOk, isTrue);
  });

  test('signOut succeeds even when the server rejects the call', () async {
    when(() => auth.signOut())
        .thenThrow(const AuthException('already gone', statusCode: '401'));

    final r = await repo.signOut();

    // Local sign-out is what matters; a failed server call must not strand
    // the driver in a signed-in state.
    expect(r.isOk, isTrue);
  });
}
