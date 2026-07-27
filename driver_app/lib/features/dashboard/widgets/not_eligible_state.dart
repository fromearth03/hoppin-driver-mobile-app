import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// The `403 NOT_ELIGIBLE` landing. 🔴 IT NEVER GUESSES.
///
/// 🔴 READ THIS BEFORE YOU "IMPROVE" THE COPY.
///
/// `POST /drivers/me/online` returns `403 NOT_ELIGIBLE` for **compliance** (a
/// document is missing or lapsed) **OR restriction OR suspension**. Three
/// completely different situations, needing three completely different actions
/// from the driver — behind ONE indistinguishable code. The server does not
/// currently tell us which (the sub-code ask is relayed under #30).
///
/// The tempting change — the one that LOOKS helpful and IS a defect — is to
/// bolt a cause onto the refusal: to tell the driver their compliance paperwork
/// is the problem, because that is the most *likely* of the three.
///
/// If that driver was actually SUSPENDED, that sentence sends them to re-upload
/// a licence that was never the problem. They will do it. Twice. Then they will
/// ring support furious about the wrong thing, and support will have to unpick
/// a story THE APP INVENTED — while the real problem sits untouched and the
/// driver loses a day's earnings to it. **Any string mapped from NOT_ELIGIBLE
/// is a defect**, and `not_eligible_never_guessed_test.dart` will fail the
/// moment you add one.
///
/// (The tempting sentence is never spelled out literally in this file. The
/// phase gate greps `lib/` for it, and a docstring EXPLAINING the prohibition
/// must not be what trips the gate — the same trap Wave 0 hit with `SEAM(#`.)
///
/// So:
///   • [reason] non-null → render the SERVER'S sentence. Verbatim. It knows.
///   • [reason] null     → say, plainly, that we cannot tell them why.
///
/// **Admitting ignorance is a FEATURE.** And either way there is a REAL route
/// to a human — a BOUND `POST /me/support-tickets` opened right here, without
/// leaving the screen — because a block with no way forward is half a message.
class NotEligibleState extends ConsumerStatefulWidget {
  /// Creates the 403 NOT_ELIGIBLE landing rung.
  const NotEligibleState({this.reason, super.key});

  /// The server's own words, or null. 🔴 NEVER a fallback sentence.
  final String? reason;

  @override
  ConsumerState<NotEligibleState> createState() => _NotEligibleStateState();
}

class _NotEligibleStateState extends ConsumerState<NotEligibleState> {
  bool _opening = false;
  bool _opened = false;
  String? _ticketError;

  /// The exit. A BOUND `POST /me/support-tickets` — a real ticket a real human
  /// reads, opened without navigating anywhere (the driver app has no support
  /// route, and this lane does not add one).
  ///
  /// 🔴 THE SUBJECT NAMES THE CODE, NOT A CAUSE. `NOT_ELIGIBLE` is what we
  /// actually know. Support can look the driver up and see which of the three
  /// things it was — which is exactly the thing the app cannot do.
  Future<void> _openTicket() async {
    if (_opening || _opened) return;
    setState(() {
      _opening = true;
      _ticketError = null;
    });
    try {
      await ref.read(supportRepositoryProvider).createTicket(
            subject: 'Cannot go online (NOT_ELIGIBLE)',
            category: 'account',
            body: widget.reason ?? 'The app was given no reason.',
          );
      if (!mounted) return;
      setState(() {
        _opening = false;
        _opened = true;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _opening = false;
        _ticketError = friendlyErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    // 🔴 THE SERVER'S SENTENCE, OR AN HONEST ADMISSION. There is no third
    // branch, and there must never be one.
    final supporting = widget.reason ??
        "The app can't tell you why. Get in touch and a person will check your "
            'account.';

    return HopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "You can't go online right now",
            style: hoppin.type.titleSmall.copyWith(color: colors.textHi),
          ),
          SizedBox(height: hoppin.spacing.xs),
          Text(
            supporting,
            style: hoppin.type.bodySmall.copyWith(color: colors.textMid),
          ),
          if (_ticketError != null) ...[
            SizedBox(height: hoppin.spacing.sm),
            Text(
              _ticketError!,
              style: hoppin.type.bodySmall.copyWith(color: colors.error),
            ),
          ],
          SizedBox(height: hoppin.spacing.md),
          if (_opened)
            Text(
              "We've opened a ticket for you. A person will be in touch.",
              key: const Key('not-eligible-support'),
              style: hoppin.type.bodySmall.copyWith(color: colors.success),
            )
          else
            HopButton.secondary(
              key: const Key('not-eligible-support'),
              label: 'Get in touch',
              busy: _opening,
              onPressed: _openTicket,
            ),
        ],
      ),
    );
  }
}
