import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/auth/data/auth_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockGoTrue extends Mock implements GoTrueClient {}

class _MockSupabase extends Mock implements SupabaseClient {}

class _MockDio extends Mock implements Dio {}

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
  setUpAll(() {
    registerFallbackValue(UserAttributes());
    registerFallbackValue(Options());
  });

  late _MockGoTrue auth;
  late _MockSupabase client;
  late _MockDio resetDio;
  late AuthRepository repo;

  setUp(() {
    auth = _MockGoTrue();
    client = _MockSupabase();
    resetDio = _MockDio();
    when(() => client.auth).thenReturn(auth);
    repo = AuthRepository(client, resetDio: resetDio);
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

  test('requestPasswordReset posts the raw OTP request, never signing up',
      () async {
    // The SDK helper sends the wrong (admin) template, so the repo posts
    // the raw magic-link request itself — the test pins that contract.
    when(() => resetDio.post<void>(any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
            data: any(named: 'data')))
        .thenAnswer((i) async =>
            Response<void>(requestOptions: RequestOptions(), statusCode: 200));

    final r = await repo.requestPasswordReset('d@hoppin.tech');

    expect(r.isOk, isTrue);
    final captured = verify(() => resetDio.post<void>(
          captureAny(),
          queryParameters: captureAny(named: 'queryParameters'),
          options: any(named: 'options'),
          data: captureAny(named: 'data'),
        )).captured;
    expect(captured[0], endsWith('/auth/v1/otp'));
    final query = captured[1] as Map<String, dynamic>;
    expect(query['redirect_to'], AuthRepository.passwordResetRedirect());
    final body = captured[2] as Map<String, dynamic>;
    expect(body['email'], 'd@hoppin.tech');
    expect(body['create_user'], isFalse);
  });

  test('requestPasswordReset maps 429 to TOO_MANY_ATTEMPTS', () async {
    when(() => resetDio.post<void>(any(),
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
        data: any(named: 'data'))).thenThrow(DioException(
      requestOptions: RequestOptions(),
      response: Response<void>(
          requestOptions: RequestOptions(), statusCode: 429),
    ));

    final r = await repo.requestPasswordReset('d@hoppin.tech');

    expect(r.errorOrNull!.code, 'TOO_MANY_ATTEMPTS');
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
