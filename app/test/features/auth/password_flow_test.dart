import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/auth/data/auth_repository.dart';
import 'package:hoppin_driver/features/auth/ui/expired_link_screen.dart';
import 'package:hoppin_driver/features/auth/ui/forgot_password_screen.dart';
import 'package:hoppin_driver/features/auth/ui/reset_password_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements AuthRepository {}

Widget wrap(AuthRepository repo, Widget child) => ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(home: child),
    );

void main() {
  late _MockRepo repo;
  setUp(() => repo = _MockRepo());

  group('ForgotPasswordScreen', () {
    testWidgets('confirms without revealing whether the email exists',
        (tester) async {
      when(() => repo.requestPasswordReset(any()))
          .thenAnswer((_) async => const Ok(null));

      await tester.pumpWidget(wrap(repo, const ForgotPasswordScreen()));
      await tester.enterText(find.byKey(const Key('email')), 'd@hoppin.tech');
      await tester.ensureVisible(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('If an account exists for that address'), findsOneWidget);
    });

    testWidgets('surfaces rate limiting', (tester) async {
      when(() => repo.requestPasswordReset(any())).thenAnswer(
          (_) async => Err(ApiException('TOO_MANY_ATTEMPTS', '', 429)));

      await tester.pumpWidget(wrap(repo, const ForgotPasswordScreen()));
      await tester.enterText(find.byKey(const Key('email')), 'd@hoppin.tech');
      await tester.ensureVisible(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Too many attempts'), findsOneWidget);
    });
  });

  group('ResetPasswordScreen', () {
    testWidgets('requires eight characters', (tester) async {
      await tester.pumpWidget(wrap(repo, const ResetPasswordScreen()));

      await tester.enterText(find.byKey(const Key('password')), 'short');
      await tester.enterText(find.byKey(const Key('confirm')), 'short');
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('Use at least 8 characters'), findsOneWidget);
      verifyNever(() => repo.updatePassword(any()));
    });

    testWidgets('requires the two entries to match', (tester) async {
      await tester.pumpWidget(wrap(repo, const ResetPasswordScreen()));

      await tester.enterText(find.byKey(const Key('password')), 'password123');
      await tester.enterText(find.byKey(const Key('confirm')), 'password124');
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text("Passwords don't match"), findsOneWidget);
    });

    testWidgets('an expired token shows the expired-link message',
        (tester) async {
      when(() => repo.updatePassword(any()))
          .thenAnswer((_) async => Err(ApiException('EXPIRED_LINK', '', 401)));

      await tester.pumpWidget(wrap(repo, const ResetPasswordScreen()));
      await tester.enterText(find.byKey(const Key('password')), 'password123');
      await tester.enterText(find.byKey(const Key('confirm')), 'password123');
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('link has expired'), findsOneWidget);
    });
  });

  group('ExpiredLinkScreen', () {
    testWidgets('reads as a failure, not as loading', (tester) async {
      await tester.pumpWidget(wrap(repo, const ExpiredLinkScreen()));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining(RegExp('expired', caseSensitive: false)),
          findsWidgets);
      expect(find.text('Try Again'), findsOneWidget);
    });
  });
}
