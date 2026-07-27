import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../motion_builder.dart';

/// 🔴 REMOVES A TEXT-ENTRY control from the tree while the vehicle is moving.
///
/// **NOT `IgnorePointer`. NOT `AbsorbPointer`. NOT `enabled: false`. NOT a grey
/// overlay.** A disabled `TextField` is still a `TextField`: it still exists, a
/// driver still taps at it, a caret still appears, and the interaction-budget
/// gate still finds it. It has to be **GONE**.
///
/// ─────────────────────────────────────────────────────────────────────────
/// 🔴 AND IT WRAPS **TEXT ENTRY ONLY.** It is not a "hide things while driving"
/// helper and it must never become one.
///
/// The offence in UK law is **HOLDING** the device. A cradled phone is legal,
/// and touching its screen while cradled is not the offence — taxi and PHV
/// drivers are explicitly permitted cradled use to accept bookings and take
/// calls. That is how every Uber, Bolt and FreeNow driver legally taps Accept,
/// Arrived and Start Trip at the wheel.
///
/// So **buttons, one-tap actions and template chips STAY LIVE in motion.** An
/// app that greys out "Arrived" has protected nobody: it has forced the driver
/// to pull over to do a thing the law permits, and it will be uninstalled.
/// Wrapping a button in this widget is a **defect**, and side B of
/// `motion_interaction_budget_test.dart` fails RED if you do it.
///
/// What we suppress is **TYPING** — the one interaction that demands sustained
/// attention, which is where *driving without due care* is actually lost, and
/// which for a PHV driver feeds the council's "fit and proper person" test. The
/// chat is templates-first precisely so the keyboard is never needed at speed.
/// ─────────────────────────────────────────────────────────────────────────
///
/// The [replacement] is a **designed notice, never a blank**. A control that
/// silently vanishes teaches a driver to keep prodding the empty space where it
/// was — which is *more* eyes off the road, not less. So the notice names the
/// alternative that DOES work.
class TypingLockedInMotion extends ConsumerWidget {
  const TypingLockedInMotion({
    required this.child,
    this.replacement,
    super.key,
  });

  /// The TEXT-ENTRY control. Rendered only while the vehicle is stationary.
  ///
  /// 🔴 A button does not go here. See the class doc.
  final Widget child;

  /// Shown in the child's place while moving. Defaults to
  /// [TypingUnavailableInMotion] — never to nothing.
  final Widget? replacement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The lock READS the gate; it never computes it. One instrument, one truth.
    final inMotion = ref.watch(motionInteractorProvider).inMotion;
    if (!inMotion) return child;
    return replacement ?? const TypingUnavailableInMotion();
  }
}

/// One line, one glance, no reading required (SF-02).
///
/// It names the thing that **does** work — the quick replies — because a driver
/// told only what they cannot do will go looking for it, and looking is the
/// whole hazard.
class TypingUnavailableInMotion extends StatelessWidget {
  const TypingUnavailableInMotion({super.key});

  /// The locked copy. Short enough to take in at a glance at arm's length.
  static const String message = "Use a quick reply — the keyboard's back when "
      'you stop.';

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: hoppin.spacing.md,
          vertical: hoppin.spacing.md,
        ),
        decoration: BoxDecoration(
          color: colors.raised,
          borderRadius: BorderRadius.circular(hoppin.radii.control),
          border: Border.all(color: colors.hairline),
        ),
        child: Row(
          children: [
            Icon(
              Icons.drive_eta_outlined,
              size: 20,
              color: colors.textMid,
            ),
            SizedBox(width: hoppin.spacing.sm),
            Expanded(
              child: Text(
                message,
                style: hoppin.type.label.copyWith(color: colors.textMid),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
