// HopTopBar — a FLOATING FROSTED PILL. Left back chevron + title. Right bell
// with a red count badge + a CONCENTRIC circular avatar with onAvatarTap.
// Both rider themes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '_pump.dart';

/// The PAINTED pill, not the widget's outer box.
///
/// `getRect(HopGlass)` would include the floating margin — the air the pill is
/// suspended in — and every concentric measurement below would then be off by
/// exactly that margin while still looking arithmetically tidy. The
/// `BackdropFilter` sits inside the clip, so its rect IS the frosted stadium.
Rect pillRect(WidgetTester tester) =>
    tester.getRect(find.byType(BackdropFilter).first);

void main() {
  // ── 🔴 THE CONCENTRIC AVATAR ────────────────────────────────────────────
  //
  // The avatar must be a perfect circle nested inside the pill's curvature: the
  // two arcs share a centre-line and the gap between them is uniform all the
  // way round, so the avatar reads as CUT FROM THE SAME ARC rather than dropped
  // on top of it.
  //
  //   pillRadius   = barHeight / 2               = 32
  //   avatarRadius = avatarSize / 2              = 24
  //   avatarInset  = pillRadius − avatarRadius   =  8   ← uniform, every side
  //
  // The point of pinning this is that it is an IDENTITY, not three numbers that
  // happen to look right today. Somebody will change the bar height. If the
  // inset were hardcoded at 8, concentricity would break SILENTLY and the
  // result would look almost-right — which is worse than looking wrong, because
  // nobody files a bug against almost-right. So the test asserts the
  // RELATIONSHIP, and the geometry derives every number from the other two:
  // neither can drift without dragging the other with it.
  group('the avatar is CONCENTRIC with the pill', () {
    test('pillRadius − avatarRadius == avatarInset (the identity)', () {
      expect(
        HoppinChrome.pillRadius - HoppinChrome.avatarRadius,
        HoppinChrome.avatarInset,
        reason:
            'This equality IS concentricity. If it fails, the avatar is no '
            'longer nested in the pill arc — it is a circle sitting on a bar.',
      );
    });

    test('the pill is a TRUE pill — its radius is half its height', () {
      expect(
        HoppinChrome.pillRadius,
        HoppinChrome.barHeight / 2,
        reason:
            'A fixed corner radius is a rounded rectangle, and a rounded '
            'rectangle has no arc for the avatar to be concentric WITH.',
      );
      expect(
        HoppinChrome.avatarSize,
        lessThan(HoppinChrome.barHeight),
        reason: 'the avatar must fit inside the pill with air left over',
      );
    });

    testWidgets('the gap is uniform on the top, bottom AND trailing edges', (
      tester,
    ) async {
      await pumpChrome(
        tester,
        riderThemes['riderLight']!,
        HopTopBar(title: 'Book Ride', onAvatarTap: () {}),
      );

      // Measure the REAL painted geometry, not the constants — a padding typo
      // satisfies the arithmetic above and still puts the circle off-centre.
      final pill = pillRect(tester);
      final avatar = tester.getRect(find.byKey(const Key('hop_top_bar_avatar')));

      final inset = HoppinChrome.avatarInset;
      const tolerance = 0.5; // sub-pixel layout rounding

      expect(
        avatar.top - pill.top,
        closeTo(inset, tolerance),
        reason: 'gap above the avatar',
      );
      expect(
        pill.bottom - avatar.bottom,
        closeTo(inset, tolerance),
        reason: 'gap below the avatar',
      );
      expect(
        pill.right - avatar.right,
        closeTo(inset, tolerance),
        reason:
            'gap outboard of the avatar — this is the one that gets eyeballed '
            'and left at 12 or 16, which breaks the ring',
      );

      // ...and the two arcs share a centre-line.
      expect(avatar.center.dy, closeTo(pill.center.dy, tolerance));
      expect(avatar.size, const Size.square(HoppinChrome.avatarSize));
      expect(pill.height, closeTo(HoppinChrome.barHeight, tolerance));
    });
  });

  for (final MapEntry(key: name, value: theme) in riderThemes.entries) {
    final colors = colorsOf(theme);

    testWidgets('the bar is a FLOATING pane of GLASS ($name)', (tester) async {
      await pumpChrome(
        tester,
        theme,
        HopTopBar(title: 'Book Ride', onAvatarTap: () {}),
      );

      // It used to be an opaque `colors.card` Material welded to the top of the
      // page. It is a detached frosted pill now, and every word of that is
      // load-bearing:

      // FROSTED — a real BackdropFilter, so content genuinely blurs THROUGH it.
      // A translucent fill with nothing live behind it is the classic fake: it
      // photographs fine and it is not glass.
      expect(
        find.descendant(
          of: find.byType(HopTopBar),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );

      // TRANSLUCENT — the fill is a token, and its alpha is the whole point.
      final decorations = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(HopTopBar),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .toList();
      expect(decorations.map((d) => d.color), contains(colors.glass));
      expect(
        colors.glass.a,
        lessThan(1.0),
        reason:
            'an opaque glass fill makes the blur behind it a pure cost with no '
            'visible effect',
      );

      // FLOATING — detached from the left, right AND top edges of the screen
      // (it hovers over the content; it is not welded to the frame)...
      final screen = tester.getRect(find.byType(MaterialApp));
      final pill = pillRect(tester);
      expect(pill.left, greaterThan(screen.left));
      expect(pill.right, lessThan(screen.right));
      expect(
        pill.top - screen.top,
        greaterThanOrEqualTo(HoppinChrome.pillMargin),
        reason:
            'the pill is connected to the top of the page. It must FLOAT below '
            'it — margins on the left, the right and above.',
      );

      // ...and it CASTS, because a floating thing that does not cast is a
      // sticker.
      expect(
        decorations.any((d) => d.boxShadow?.isNotEmpty ?? false),
        isTrue,
      );
    });

    testWidgets('renders title + back chevron; back fires ($name)', (
      tester,
    ) async {
      var backs = 0;
      await pumpChrome(
        tester,
        theme,
        HopTopBar(
          title: 'Book Ride',
          onBack: () => backs++,
          onAvatarTap: () {},
        ),
      );
      expect(find.text('Book Ride'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      await tester.tap(find.byIcon(Icons.chevron_left));
      expect(backs, 1);
    });

    testWidgets('bell shows a red count badge ($name)', (tester) async {
      await pumpChrome(
        tester,
        theme,
        HopTopBar(
          title: 'Payments',
          notificationCount: 2,
          onAvatarTap: () {},
        ),
      );
      expect(find.byIcon(Icons.notifications_none), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      // The badge fill is the red error role.
      final badgeColors = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(HopTopBar),
              matching: find.byType(Container),
            ),
          )
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.color)
          .toList();
      expect(badgeColors, contains(colors.error));
    });

    testWidgets('avatar tap fires the profile intent ($name)', (tester) async {
      var avatarTaps = 0;
      await pumpChrome(
        tester,
        theme,
        HopTopBar(title: 'My Profile', onAvatarTap: () => avatarTaps++),
      );
      await tester.tap(find.byKey(const Key('hop_top_bar_avatar')));
      expect(avatarTaps, 1);
    });
  }
}
