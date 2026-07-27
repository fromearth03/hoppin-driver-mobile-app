// Acceptance tests for the four HoppinTheme builders. The exact-equality
// primary checks are the point: raw ColorScheme.fromSeed would re-tone the
// brand hex, so exact matches prove the hand-tuning survived.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

void main() {
  final themes = <String, ThemeData>{
    'riderLight': HoppinTheme.riderLight(),
    'riderDark': HoppinTheme.riderDark(),
    'driverLight': HoppinTheme.driverLight(),
    'driverDark': HoppinTheme.driverDark(),
  };
  final darkThemes = <String, ThemeData>{
    'riderDark': themes['riderDark']!,
    'driverDark': themes['driverDark']!,
  };

  group('hand-tuned ColorScheme', () {
    // R1 replaced the rejected Blackcab racing-green/petrol scheme with the
    // Figma navy ink — the hand-built (never seeded) scheme keeps it exact.
    test('rider light primary is exactly the Figma navy ink #181C3A', () {
      expect(
        themes['riderLight']!.colorScheme.primary,
        const Color(0xFF181C3A),
      );
    });

    test('rider dark primary is the derived navy-on-dark ink (not raw navy)',
        () {
      final primary = themes['riderDark']!.colorScheme.primary;
      expect(primary, isNot(const Color(0xFF181C3A)));
      expect(primary, const Color(0xFFC9CEE6));
    });
  });

  group('ThemeExtensions', () {
    test('every theme carries HoppinColors and HoppinMotion', () {
      for (final MapEntry(key: name, value: theme) in themes.entries) {
        expect(
          theme.extension<HoppinColors>(),
          isNotNull,
          reason: '$name is missing HoppinColors',
        );
        expect(
          theme.extension<HoppinMotion>(),
          isNotNull,
          reason: '$name is missing HoppinMotion',
        );
      }
    });
  });

  group('dark themes are cool, never pure', () {
    test('scaffold background is the cool-dark ramp #0F1220, not #000000', () {
      for (final MapEntry(key: name, value: theme) in darkThemes.entries) {
        expect(
          theme.scaffoldBackgroundColor,
          const Color(0xFF0F1220),
          reason: '$name canvas must be the derived cool-dark ramp',
        );
        expect(theme.scaffoldBackgroundColor, isNot(const Color(0xFF000000)));
      }
    });

    test('textHi is never pure white', () {
      for (final MapEntry(key: name, value: theme) in darkThemes.entries) {
        expect(
          theme.extension<HoppinColors>()!.textHi,
          isNot(const Color(0xFFFFFFFF)),
          reason: '$name textHi must not be pure white',
        );
      }
    });
  });

  group('typography wiring', () {
    test('bodyLarge uses the packaged Poppins family', () {
      for (final MapEntry(key: name, value: theme) in themes.entries) {
        expect(
          theme.textTheme.bodyLarge!.fontFamily,
          'packages/hoppin_ui/Poppins',
          reason: '$name bodyLarge must resolve to the bundled Poppins '
              '(Geist was the rejected design)',
        );
      }
    });
  });

  group('component themes', () {
    test('cards: elevation 0, radius 10, hairline border', () {
      for (final MapEntry(key: name, value: theme) in themes.entries) {
        final card = theme.cardTheme;
        expect(card.elevation, 0, reason: '$name card elevation');
        final shape = card.shape! as RoundedRectangleBorder;
        expect(
          shape.borderRadius,
          BorderRadius.circular(10),
          reason: '$name card radius',
        );
        expect(
          shape.side.color,
          theme.extension<HoppinColors>()!.hairline,
          reason: '$name card border must be the hairline token',
        );
        expect(shape.side.style, BorderStyle.solid);
      }
    });

    test('inputs speak the CONTROL radius, like every other control', () {
      // This asserted 8 — the last thing in the system on the legacy input
      // radius, which put a THIRD corner language on screens that already had
      // cards at 10 and buttons/chips at 12. It is the kind of mismatch you
      // cannot name and can always feel. Inputs are controls; they take the
      // control radius.
      for (final MapEntry(key: name, value: theme) in themes.entries) {
        final border = theme.inputDecorationTheme.border! as OutlineInputBorder;
        expect(
          border.borderRadius,
          BorderRadius.circular(HoppinRadii.control),
          reason: '$name input radius',
        );
      }
    });

    test('an input announces its own edge — it is not a hairline', () {
      // A hairline DIVIDES (a line between two things already on the page). An
      // input INVITES, and it has to declare where it starts. In dark the
      // #2A2F42 hairline against a #191D2E fill made the field something you had
      // to hunt for. The resting edge is the stronger `outline` role.
      for (final MapEntry(key: name, value: theme) in themes.entries) {
        final colors = theme.extension<HoppinColors>()!;
        final enabled =
            theme.inputDecorationTheme.enabledBorder! as OutlineInputBorder;
        expect(
          enabled.borderSide.color,
          isNot(colors.hairline),
          reason: '$name: the input edge must out-weigh a divider',
        );

        // ...and focus is unmistakable: the accent, at double weight.
        final focused =
            theme.inputDecorationTheme.focusedBorder! as OutlineInputBorder;
        expect(focused.borderSide.color, colors.accent, reason: name);
        expect(
          focused.borderSide.width,
          greaterThan(enabled.borderSide.width),
          reason: '$name: focus must be visibly heavier than rest',
        );
      }
    });

    test('FilledButton minimum height is at least 52', () {
      for (final MapEntry(key: name, value: theme) in themes.entries) {
        final minSize = theme.filledButtonTheme.style!.minimumSize!.resolve(
          const <WidgetState>{},
        )!;
        expect(
          minSize.height,
          greaterThanOrEqualTo(52),
          reason: '$name FilledButton must be thumb-sized',
        );
      }
    });
  });

  group('one semantic map, two lanes', () {
    test('rider light and driver light share surfaces AND the one navy accent',
        () {
      // v1.1 revamp: both apps resolve ONE navy accent (the driver lane
      // re-diverges in its own milestone). Previously they differed.
      final rider = themes['riderLight']!;
      final driver = themes['driverLight']!;
      expect(rider.colorScheme.surface, driver.colorScheme.surface);
      expect(rider.scaffoldBackgroundColor, driver.scaffoldBackgroundColor);
      expect(rider.colorScheme.primary, driver.colorScheme.primary);
      expect(rider.colorScheme.primary, const Color(0xFF181C3A));
    });
  });
}
