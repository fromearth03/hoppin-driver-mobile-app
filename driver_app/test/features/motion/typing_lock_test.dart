import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/motion/motion_builder.dart';
import 'package:hoppin_driver/features/motion/widgets/typing_locked_in_motion.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// 🔴 THE LOCK **REMOVES**. It does not disable.
///
/// A disabled `TextField` is still a `TextField`: it exists in the tree, a
/// driver still taps at it, a caret still appears, and the interaction-budget
/// gate still finds it. "Greyed out" is not "gone", and only "gone" takes the
/// keyboard off the windscreen.
///
/// And the other half, which is the half people skip: **the lock is for TEXT
/// ENTRY ONLY.** It is not a general "hide things while driving" tool. Buttons
/// and template chips stay live at speed — a cradled phone is legal to touch.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool inMotion,
    required Widget child,
    Widget? replacement,
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        motionInteractorProvider.overrideWith(() => _PinnedMotion(inMotion)),
      ],
      child: MaterialApp(
        theme: theme ?? HoppinTheme.driverDark(),
        home: Scaffold(
          body: TypingLockedInMotion(
            replacement: replacement,
            child: child,
          ),
        ),
      ),
    ));
    // Bounded pumps only — the driver app has live polling providers and
    // settle-detection never terminates.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('STOPPED: the composer is present and usable', (tester) async {
    await pump(
      tester,
      inMotion: false,
      child: const TextField(key: ValueKey('composer')),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(TypingUnavailableInMotion), findsNothing);
  });

  testWidgets(
      '🔴 IN MOTION: the TextField is GONE FROM THE TREE — not disabled, not '
      'ignored, GONE', (tester) async {
    await pump(
      tester,
      inMotion: true,
      child: const TextField(key: ValueKey('composer')),
    );

    expect(
      find.byType(TextField),
      findsNothing,
      reason: 'the TextField still exists in the tree. A disabled TextField is '
          'still a TextField — it draws a caret when a moving driver taps it.',
    );
    expect(find.byKey(const ValueKey('composer')), findsNothing);

    // No pointer-blocking dodge. Scoped to the LOCK'S OWN SUBTREE: Flutter's
    // own Scaffold and AnimatedSwitcher plant IgnorePointers of their own all
    // over the tree, and a global findsNothing here would be asserting
    // something about the framework rather than about us.
    //
    // (The real enforcement is the source grep in
    // motion_interaction_budget_test.dart, which sweeps features/motion for
    // IgnorePointer / AbsorbPointer / `enabled: false`. This is the tree-level
    // corroboration of it.)
    final lock = find.byType(TypingLockedInMotion);
    expect(
      find.descendant(of: lock, matching: find.byType(IgnorePointer)),
      findsNothing,
      reason: 'the lock is pointer-blocking its child instead of removing it. '
          'An ignored TextField is STILL a TextField.',
    );
    expect(
      find.descendant(of: lock, matching: find.byType(AbsorbPointer)),
      findsNothing,
    );
  });

  testWidgets(
      '🔴 IN MOTION: the replacement is a DESIGNED NOTICE, never a blank',
      (tester) async {
    // A control that silently vanishes teaches a driver to keep prodding the
    // empty space where it was. That is MORE eyes off the road, not less.
    await pump(tester, inMotion: true, child: const TextField());

    expect(find.byType(TypingUnavailableInMotion), findsOneWidget);
    expect(
      find.text(TypingUnavailableInMotion.message),
      findsOneWidget,
      reason: 'the notice must NAME the alternative that works',
    );
  });

  testWidgets('the notice names the QUICK REPLY — the thing that does work',
      (tester) async {
    await pump(tester, inMotion: true, child: const TextField());

    expect(
      TypingUnavailableInMotion.message.toLowerCase(),
      contains('quick reply'),
      reason: 'templates-first is the WHOLE reason the keyboard is never '
          'needed at speed. A driver told only what they cannot do will go '
          'looking for it, and looking is the hazard.',
    );
    expect(
      TypingUnavailableInMotion.message.toLowerCase(),
      contains('when you stop'),
      reason: 'the notice must promise the keyboard BACK — a gate that never '
          'opens is a deletion, and the driver must know it is a gate',
    );
  });

  testWidgets('a caller-supplied replacement wins over the default',
      (tester) async {
    await pump(
      tester,
      inMotion: true,
      child: const TextField(),
      replacement: const Text('custom'),
    );

    expect(find.text('custom'), findsOneWidget);
    expect(find.byType(TypingUnavailableInMotion), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('🔴 the gate OPENS: the composer returns the moment they stop',
      (tester) async {
    // A gate that never opens is not a gate; it is a deletion.
    final container = ProviderContainer(
      overrides: [
        motionInteractorProvider.overrideWith(_LiveMotion.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: HoppinTheme.driverDark(),
        home: const Scaffold(
          body: TypingLockedInMotion(child: TextField()),
        ),
      ),
    ));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget, reason: 'starts stopped');

    (container.read(motionInteractorProvider.notifier) as _LiveMotion).setMoving(true);
    await tester.pump();
    expect(find.byType(TextField), findsNothing, reason: 'pulled away');

    (container.read(motionInteractorProvider.notifier) as _LiveMotion).setMoving(false);
    await tester.pump();
    expect(
      find.byType(TextField),
      findsOneWidget,
      reason: '🔴 THE DRIVER HAS STOPPED AND THE KEYBOARD MUST COME BACK',
    );
  });

  testWidgets('renders in BOTH themes — the notice is legible either way',
      (tester) async {
    for (final theme in [HoppinTheme.driverDark(), HoppinTheme.driverLight()]) {
      await pump(
        tester,
        inMotion: true,
        child: const TextField(),
        theme: theme,
      );

      expect(find.byType(TypingUnavailableInMotion), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

/// The gate, pinned — the lock READS the gate, it never computes it.
class _PinnedMotion extends MotionInteractor {
  _PinnedMotion(this._inMotion);

  final bool _inMotion;

  @override
  MotionState build() => MotionState(inMotion: _inMotion);
}

/// A drivable gate: the test flips it and watches the tree follow.
class _LiveMotion extends MotionInteractor {
  @override
  MotionState build() => const MotionState();

  void setMoving(bool moving) =>
      state = state.copyWith(inMotion: moving, speedMps: moving ? 13.4 : 0.0);
}
