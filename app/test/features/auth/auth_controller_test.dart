import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/auth/data/auth_repository.dart';
import 'package:hoppin_driver/features/auth/logic/auth_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockRepo extends Mock implements AuthRepository {}

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
  late _MockRepo repo;
  late StreamController<AuthState> events;

  setUp(() {
    repo = _MockRepo();
    events = StreamController<AuthState>.broadcast();
    when(() => repo.authStateChanges).thenAnswer((_) => events.stream);
  });

  tearDown(() => events.close());

  ProviderContainer container() {
    final c = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(c.dispose);
    return c;
  }

  test('starts signed out when the SDK has no session', () {
    when(() => repo.currentSession).thenReturn(null);

    expect(container().read(authControllerProvider), AuthStatus.signedOut);
  });

  test('starts signed in when the SDK restored a session', () {
    when(() => repo.currentSession).thenReturn(testSession());

    expect(container().read(authControllerProvider), AuthStatus.signedIn);
  });

  test('follows the SDK sign-out event', () async {
    when(() => repo.currentSession).thenReturn(testSession());
    final c = container();
    expect(c.read(authControllerProvider), AuthStatus.signedIn);

    when(() => repo.currentSession).thenReturn(null);
    events.add(const AuthState(AuthChangeEvent.signedOut, null));
    await Future<void>.delayed(Duration.zero);

    expect(c.read(authControllerProvider), AuthStatus.signedOut);
  });

  test('a token refresh keeps the driver signed in', () async {
    when(() => repo.currentSession).thenReturn(testSession());
    final c = container();

    events.add(AuthState(AuthChangeEvent.tokenRefreshed, testSession()));
    await Future<void>.delayed(Duration.zero);

    expect(c.read(authControllerProvider), AuthStatus.signedIn);
  });

  test('signIn reports success', () async {
    when(() => repo.currentSession).thenReturn(null);
    when(() => repo.signIn(any(), any()))
        .thenAnswer((_) async => Ok(testSession()));

    final c = container();
    final r = await c
        .read(authControllerProvider.notifier)
        .signIn('d@hoppin.tech', 'pw');

    expect(r.isOk, isTrue);
  });

  test('signIn surfaces the mapped failure code', () async {
    when(() => repo.currentSession).thenReturn(null);
    when(() => repo.signIn(any(), any())).thenAnswer(
        (_) async => Err(ApiException('INVALID_CREDENTIALS', '', 400)));

    final c = container();
    final r =
        await c.read(authControllerProvider.notifier).signIn('a@b.c', 'x');

    expect(r.errorOrNull!.code, 'INVALID_CREDENTIALS');
    expect(c.read(authControllerProvider), AuthStatus.signedOut);
  });

  test('signOut delegates to the repository', () async {
    when(() => repo.currentSession).thenReturn(testSession());
    when(() => repo.signOut()).thenAnswer((_) async => const Ok(null));

    final c = container();
    await c.read(authControllerProvider.notifier).signOut();

    verify(() => repo.signOut()).called(1);
  });

  test('runs the signed-in hook exactly once per sign-in', () async {
    when(() => repo.currentSession).thenReturn(null);
    when(() => repo.signIn(any(), any()))
        .thenAnswer((_) async => Ok(testSession()));

    var calls = 0;
    final c = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      onSignedInProvider.overrideWithValue(() async => calls++),
    ]);
    addTearDown(c.dispose);

    await c.read(authControllerProvider.notifier).signIn('a@b.c', 'pw');

    expect(calls, 1);
  });
}
