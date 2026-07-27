import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/profile/driver_personal_facts.dart';
import 'package:hoppin_driver/features/profile/personal_info_screen.dart';
import 'package:hoppin_driver/features/profile/profile_screen.dart';
import 'package:hoppin_driver/features/profile/widgets/driver_profile_unavailable.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../../support/code_lines.dart';

/// 🔴 THE HONESTY ASSERTIONS FOR THE DRIVER PROFILE SURFACE (#39, PS-01).
///
/// There is no driver `GET`/`PATCH /me/profile`. The Supabase session is the
/// only source there is, and it carries exactly four facts.
///
/// The Figma draws a driver photo, a city, a **star rating**, a trip count and
/// a vehicle. Not one of those exists anywhere in the data model. The rating is
/// the dangerous one: a driver's livelihood is judged on it, and a figure
/// invented in the view is a figure they would plan their week around.
///
/// So: four fields, an unconditional rung, and a Save the driver can SEE is
/// off.
void main() {
  final dark = HoppinTheme.driverDark();

  /// Pumps a profile surface over a fact-set under test control.
  ///
  /// **Bounded pumps only. Never `pumpAndSettle`** — project convention.
  Future<void> pumpProfile(
    WidgetTester tester,
    Widget screen, {
    DriverPersonalFacts facts = const DriverPersonalFacts(
      fullName: 'Test Driver',
      email: 'driver@example.com',
      memberSince: '2025-08-14T09:00:00.000Z',
    ),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          driverPersonalFactsProvider.overrideWithValue(facts),
          authServiceProvider.overrideWithValue(_StubAuth()),
        ],
        child: MaterialApp(theme: dark, home: screen),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  String renderedText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
      .join(' \n ')
      .toLowerCase();

  group('personal information', () {
    testWidgets('renders the four session facts and nothing else',
        (tester) async {
      await pumpProfile(
        tester,
        const DriverPersonalInfoScreen(),
        facts: const DriverPersonalFacts(
          fullName: 'Test Driver',
          email: 'driver@example.com',
          phone: '+447700900000',
          memberSince: '2025-08-14T09:00:00.000Z',
        ),
      );

      expect(find.byKey(DriverPersonalInfoKeys.name), findsOneWidget);
      expect(find.byKey(DriverPersonalInfoKeys.email), findsOneWidget);
      expect(find.byKey(DriverPersonalInfoKeys.phone), findsOneWidget);
      expect(find.byKey(DriverPersonalInfoKeys.memberSince), findsOneWidget);

      // FOUR fields. Any fifth would have to come from somewhere, and there is
      // nowhere for it to come from.
      expect(
        find.byType(TextField),
        findsNWidgets(4),
        reason: 'The session carries four facts. A fifth field is invented.',
      );
    });

    testWidgets('OMITS the rows the session does not know — never a placeholder',
        (tester) async {
      await pumpProfile(
        tester,
        const DriverPersonalInfoScreen(),
        facts: const DriverPersonalFacts(email: 'driver@example.com'),
      );

      expect(
        find.byKey(DriverPersonalInfoKeys.phone),
        findsNothing,
        reason: 'A blank or dashed row reads as "you have not filled this in" '
            'when the truth is "we cannot tell you".',
      );
      expect(find.byKey(DriverPersonalInfoKeys.memberSince), findsNothing);

      final rendered = renderedText(tester);
      for (final placeholder in const ['not set', 'unknown', 'n/a']) {
        expect(
          rendered.contains(placeholder),
          isFalse,
          reason: 'Rendered the placeholder "$placeholder" for a fact we do '
              'not hold.',
        );
      }
    });

    testWidgets('🔴 Save is VISIBLE and onPressed is NULL — not a no-op closure',
        (tester) async {
      await pumpProfile(tester, const DriverPersonalInfoScreen());

      final save = find.byKey(DriverPersonalInfoKeys.save);
      expect(save, findsOneWidget, reason: 'Hiding it is not honest either — '
          'the driver must SEE that saving is off.');

      final button = tester.widget<HopButton>(save);
      expect(
        button.onPressed,
        isNull,
        reason: '🔴 An empty callback is a lie: it gives a full tap ripple over '
            'silence, indistinguishable from a working button. There is no '
            'PATCH /me/profile (#39). Null is the truth.',
      );
    });

    testWidgets('🔴 the #39 rung is mounted UNCONDITIONALLY', (tester) async {
      // Both with a full fact-set and an empty one. A rung that only appears on
      // a bad day teaches the driver that a good day exists. It does not.
      await pumpProfile(tester, const DriverPersonalInfoScreen());
      expect(find.byType(DriverProfileUnavailable), findsOneWidget);

      await pumpProfile(
        tester,
        const DriverPersonalInfoScreen(),
        facts: const DriverPersonalFacts(),
      );
      expect(
        find.byType(DriverProfileUnavailable),
        findsOneWidget,
        reason: 'The seam is not sometimes-null — it is ALWAYS null.',
      );
    });
  });

  group('the profile hub', () {
    testWidgets('routes to personal info, documents, settings, support, '
        'sign out', (tester) async {
      await pumpProfile(tester, const DriverProfileScreen());

      expect(find.byKey(DriverProfileKeys.personalRow), findsOneWidget);
      expect(find.byKey(DriverProfileKeys.documentsRow), findsOneWidget);
      expect(find.byKey(DriverProfileKeys.settingsRow), findsOneWidget);
      expect(find.byKey(DriverProfileKeys.supportRow), findsOneWidget);
      expect(find.byKey(DriverProfileKeys.signOutRow), findsOneWidget);
    });
  });

  // ── The fabrication sweep ─────────────────────────────────────────────────
  test(
    '🔴 no rating, trip count, vehicle, city or photo picker anywhere in '
    'features/profile/',
    () {
      // 🔴 COMMENT-STRIPPED. These very files DOCUMENT the refusal at length —
      // a raw grep would match the prose and go red on a correct codebase.
      final offenders = <String>[];

      // Executable fabrications only. `Icons.star` painting a rating,
      // `image_picker`, a `rating`/`tripCount`/`vehicle` symbol in code.
      final banned = <RegExp>[
        RegExp(r'\brating\b', caseSensitive: false),
        RegExp(r'\btripCount\b|\btrips_count\b|\btotalTrips\b'),
        RegExp(r'\bvehicle\b', caseSensitive: false),
        RegExp(r'\bImagePicker\b|\bimage_picker\b'),
        RegExp(r"Wolverhampton"),
      ];

      for (final src in driverSources()) {
        if (!src.path.replaceAll(r'\', '/').contains('lib/features/profile')) {
          continue;
        }
        for (var i = 0; i < src.lines.length; i++) {
          for (final pattern in banned) {
            if (pattern.hasMatch(src.lines[i])) {
              offenders.add('${src.path}:${i + 1}  ${src.lines[i].trim()}');
            }
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'The Figma draws these; the data model holds none of them. A '
            'rating invented in the view is a number a driver plans their week '
            'around:\n${offenders.join('\n')}',
      );
    },
  );
}

class _StubAuth implements AuthService {
  @override
  String? get userId => 'driver-1';

  @override
  bool get isSignedIn => true;

  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
