import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import 'driver_deletion_via_support_notice.dart';

/// Stable widget keys the delete-account popup exposes for tests.
abstract final class DriverDeleteAccountKeys {
  /// The popup surface.
  static const sheet = ValueKey('driver-delete-account-sheet');

  /// The driver's optional free-text reason.
  static const reasonField = ValueKey('driver-delete-account-reason');

  /// Files the Art. 17 erasure ticket.
  static const confirmDelete = ValueKey('driver-delete-account-confirm');

  /// Backs out. Files nothing.
  static const cancel = ValueKey('driver-delete-account-cancel');

  /// The post-submission state. A request was FILED, not actioned.
  static const submitted = ValueKey('driver-delete-account-submitted');
}

/// 🔴 READ THIS BEFORE YOU "FIX" THIS BUTTON.
///
/// The STATE is MISSING_BE — `DELETE /me` does not exist (#43). But **the
/// ACTION THE DRIVER TAKES IS FULLY BOUND**: this files a REAL
/// `POST /me/support-tickets` under the `account_deletion` category, into a
/// real database, which a real human reads, against a real **one-month
/// statutory clock**.
///
/// **A manual erasure process is LAWFUL.** UK GDPR Art. 17 mandates the
/// OUTCOME and the DEADLINE — not an automated endpoint.
///
/// 🔴 It is lawful ONLY IF THE RUNBOOK IS OWNED. A deletion ticket nobody has
/// been told to action is WORSE than an inert button, because it manufactures
/// the APPEARANCE of compliance. (The owner field on the rider's data-rights
/// runbook is still blank. That is a live release-gate item and it is not this
/// plan's to close — but it is this plan's to not paper over.)
///
/// THREE THINGS THIS CONTROL MUST NEVER DO:
///  1. Claim the account was DELETED. It was not. A request was FILED.
///  2. Sign the driver out — that SIMULATES deletion and strands them outside
///     the very ticket they now need to follow.
///  3. Go inert "for consistency" with the other rungs. That would take a
///     WORKING Art. 17 route and BREAK it.
///
/// And it does not promise erasure: licensing and HMRC retention survive the
/// request, and for a DRIVER that retention is heavier than for a rider — a
/// private-hire operator must keep booking and driver records for a statutory
/// minimum. The copy says a request was submitted and what happens next.
///
/// The `showX(` form is what the Group C reachability grep looks for from
/// `settings_screen.dart`.
Future<void> showDriverDeleteAccountPopup(BuildContext context) {
  final colors = context.hoppin.colors;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    elevation: 0,
    backgroundColor: Colors.transparent,
    barrierColor: colors.scrim,
    builder: (_) =>
        const _DriverDeleteAccountSheet(key: DriverDeleteAccountKeys.sheet),
  );
}

/// The popup body — the disclosure, an optional reason, and ONE real action.
class _DriverDeleteAccountSheet extends ConsumerStatefulWidget {
  const _DriverDeleteAccountSheet({super.key});

  @override
  ConsumerState<_DriverDeleteAccountSheet> createState() =>
      _DriverDeleteAccountSheetState();
}

class _DriverDeleteAccountSheetState
    extends ConsumerState<_DriverDeleteAccountSheet> {
  final _reasonCtrl = TextEditingController();
  bool _busy = false;
  bool _filed = false;
  String? _error;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  /// Files ONE ticket. Exactly one — never zero (the right would go
  /// unhonoured) and never two (a duplicate statutory request that an ops team
  /// then has to disambiguate by hand). The `_busy` guard is what makes "never
  /// two" true under a double-tap.
  ///
  /// 🔴 **A FAILED legal request must FAIL LOUDLY.** A driver who taps
  /// "request account deletion", sees a spinner, and is never told the call
  /// failed will walk away believing they exercised a statutory right when
  /// nothing was filed. That is strictly worse than never offering the button —
  /// it manufactures the *appearance* of compliance.
  ///
  /// So the catch is `catch (e)`, not `on Exception` — a non-Exception
  /// throwable would otherwise escape, leave `_busy` stuck true, disable the
  /// action forever, and show no message at all. On ANY failure: clear busy,
  /// re-enable the action, and say so.
  Future<void> _file() async {
    if (_busy || _filed) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final reason = _reasonCtrl.text.trim();
    try {
      await ref.read(supportRepositoryProvider).createTicket(
            // The canonical subject. The request type rides in the subject as
            // well as the category, so ops can triage a legal request even if
            // the server never stored an unknown `category` (#75).
            subject: _kDeletionSubject,
            // 🔴 The RIDER's literal, verbatim. The same human works the same
            // queue; a driver-specific spelling is a category that gets missed.
            category: _kAccountDeletionCategory,
            body: reason.isEmpty ? null : reason,
          );
      if (!mounted) return;
      // 🔴 Stay signed in. Stay on the sheet. Show what ACTUALLY happened: a
      // request was submitted. Not that anything was deleted.
      setState(() {
        _busy = false;
        _filed = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is Exception
            ? friendlyErrorMessage(e)
            : 'We could not send your request. Nothing has been filed — '
                'please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(hoppin.radii.pillSmall),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: hoppin.spacing.gutter,
          right: hoppin.spacing.gutter,
          top: hoppin.spacing.gutter,
          bottom: MediaQuery.of(context).viewInsets.bottom + hoppin.spacing.lg,
        ),
        child: SingleChildScrollView(
          child: _filed ? _submitted(hoppin, colors) : _form(hoppin, colors),
        ),
      ),
    );
  }

  /// 🔴 The post-submission state. Every word of it is load-bearing.
  ///
  /// It reports that a REQUEST was SUBMITTED and names the one-month statutory
  /// clock. It does not say the account is gone, closed, removed, or erased —
  /// because none of that has happened. A person has not yet read the ticket.
  Widget _submitted(HoppinTokens hoppin, HoppinColors colors) {
    return Column(
      key: DriverDeleteAccountKeys.submitted,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Your request has been submitted',
          style: hoppin.type.section.copyWith(color: colors.textHi),
        ),
        SizedBox(height: hoppin.spacing.md),
        Text(
          'A support ticket is now open and a person will act on it. We will '
          'come back to you within one month.',
          style: hoppin.type.meta.copyWith(color: colors.textMid),
        ),
        SizedBox(height: hoppin.spacing.md),
        Text(
          'Nothing has changed on your account yet, and you are still signed '
          'in. Keep driving as normal until we contact you.',
          style: hoppin.type.meta.copyWith(color: colors.textMid),
        ),
        SizedBox(height: hoppin.spacing.lg),
        HopButton.secondary(
          key: DriverDeleteAccountKeys.cancel,
          label: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _form(HoppinTokens hoppin, HoppinColors colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Delete my account',
          style: hoppin.type.section.copyWith(color: colors.textHi),
        ),
        SizedBox(height: hoppin.spacing.md),

        // The #43 rung — the mount site, and the only rung in the driver app
        // that offers a working exit.
        const DriverDeletionViaSupportNotice(),
        SizedBox(height: hoppin.spacing.lg),

        TextField(
          key: DriverDeleteAccountKeys.reasonField,
          controller: _reasonCtrl,
          enabled: !_busy,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: "Tell us why, if you'd like (optional)",
            alignLabelWithHint: true,
          ),
        ),

        if (_error != null) ...[
          SizedBox(height: hoppin.spacing.md),
          HopBanner.error(message: _error!),
        ],

        SizedBox(height: hoppin.spacing.lg),

        // PS-06 — the erasure request. A REAL ticket.
        HopButton.red(
          key: DriverDeleteAccountKeys.confirmDelete,
          label: 'Request account deletion',
          onPressed: _busy ? null : _file,
        ),
        SizedBox(height: hoppin.spacing.sm),

        HopButton.ghost(
          key: DriverDeleteAccountKeys.cancel,
          label: 'Keep my account',
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// 🔴 The RIDER's category literal, reproduced verbatim.
///
/// `apps/driver` cannot import `apps/rider`, so this cannot be a shared
/// constant reference — but it MUST be the identical string. The same human
/// works the same support queue, and a category only one app spells correctly
/// is a category that gets missed. Cross-checked against
/// `apps/rider/lib/features/support/support_categories.dart`
/// (`SupportCategories.accountDeletion`). **Do not reword it.**
const String _kAccountDeletionCategory = 'account_deletion';

/// The canonical deletion subject — the belt-and-braces mitigation for the
/// undocumented wire vocabulary (#75). The request type rides in the subject
/// too, so ops can triage even if the server drops an unknown `category`.
const String _kDeletionSubject =
    'Account deletion request — right to erasure (Art. 17)';
