import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/auth/data/auth_repository.dart';
import 'package:hoppin_driver/features/auth/ui/sign_in_screen.dart';
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

Widget wrap(AuthRepository repo) => ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: SignInScreen()),
    );

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    when(() => repo.currentSession).thenReturn(null);
    when(() => repo.authStateChanges)
        .thenAnswer((_) => const Stream<AuthState>.empty());
  });

  testWidgets('offers a way to register', (tester) async {
    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    // Credentials no longer come from the company - a driver can sign
    // themselves up, and the only route in is from here.
    expect(find.byKey(const Key('go_to_sign_up')), findsOneWidget);
    expect(find.textContaining('provided by the company'), findsNothing);
  });

  testWidgets('rejects an empty email before calling the server',
      (tester) async {
    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text('Enter your email'), findsOneWidget);
    verifyNever(() => repo.signIn(any(), any()));
  });

  testWidgets('shows mapped copy for bad credentials, not the raw message',
      (tester) async {
    when(() => repo.signIn(any(), any())).thenAnswer((_) async =>
        Err(ApiException('INVALID_CREDENTIALS', 'invalid_grant sql', 400)));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('email')), 'd@hoppin.tech');
    await tester.enterText(find.byKey(const Key('password')), 'wrong');
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text('That email or password is incorrect.'), findsOneWidget);
    expect(find.textContaining('sql'), findsNothing);
  });

  testWidgets('disables the button while the call is in flight',
      (tester) async {
    // Resolves as a failure so the screen stays put — navigation on success
    // needs a router, which is exercised by the app-level tests instead.
    when(() => repo.signIn(any(), any())).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return Err(ApiException('INTERNAL', '', 500));
    });

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('email')), 'd@hoppin.tech');
    await tester.enterText(find.byKey(const Key('password')), 'pw');
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton).first);
    expect(button.onPressed, isNull);

    await tester.pumpAndSettle();
  });

  testWidgets('password is obscured', (tester) async {
    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.descendant(
        of: find.byKey(const Key('password')), matching: find.byType(TextField)));
    expect(field.obscureText, isTrue);
  });
}
