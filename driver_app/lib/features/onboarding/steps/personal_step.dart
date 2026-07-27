import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// Registration1, re-purposed — **Personal Information**.
///
/// 🔴 **THE FIGMA DRAWS A PASSWORD FIELD HERE, AND THAT FIELD IS THE PROOF THAT
/// THESE FRAMES WERE DESIGNED FOR A FLOW WE DO NOT HAVE.** A driver setting a
/// password on step 1 of 4 is a driver creating an account. `DOCS/04` forbids
/// it: an admin provisions the driver, the platform emails a set-password
/// invite, and the driver is ALREADY SIGNED IN by the time they see this screen.
/// So there is no password field, no email field, and no "create account".
///
/// 🔴 **AND THERE ARE NO EDITABLE FIELDS AT ALL, BECAUSE THERE IS NOWHERE TO
/// SAVE THEM.** There is no driver profile endpoint (#39) — no `GET`, no
/// `PATCH`. The Supabase session's own metadata is the ONLY identity store the
/// app has. Drawing a text box labelled "First Name" over a value the app cannot
/// write would tell the driver to correct their name, accept the correction, and
/// discard it. The rider app shipped exactly that mistake — a hardcoded
/// placeholder name and city rendered to every real user — until Wave 0 found
/// it.
///
/// So this step shows the driver **what the platform actually knows about them**,
/// says plainly **who to talk to if it is wrong**, and asks for nothing. That is
/// the whole honest content of Registration1 under the real contract.
class PersonalStep extends ConsumerWidget {
  /// Creates the personal-information step.
  const PersonalStep({required this.onContinue, super.key});

  /// Advance to the licence step.
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final auth = ref.watch(authServiceProvider);

    // Exactly what the session carries, and nothing invented. A value the
    // session does not hold is NOT KNOWABLE — it is omitted, never dashed.
    // "We cannot tell you" is not "you have not filled this in", and a dashed
    // row says the second while meaning the first.
    final rows = <({String label, String value})>[
      if (auth.fullName case final name? when name.trim().isNotEmpty)
        (label: 'Name', value: name),
      if (auth.email case final email? when email.isNotEmpty)
        (label: 'Email', value: email),
      if (auth.phone case final phone? when phone.isNotEmpty)
        (label: 'Phone', value: phone),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'This is what we have on file for you. Your details were set up by '
          'the Hoppin team when your account was created.',
          style: hoppin.type.meta.copyWith(color: colors.textMid),
        ),
        SizedBox(height: hoppin.spacing.gutter),
        if (rows.isEmpty)
          // The session carries no name, no email and no phone. Rare, but real,
          // and the honest answer is to say so rather than render an empty card.
          const HopEmptyState(
            compact: true,
            headline: 'Your details are with our team',
            supporting:
                "We don't have your name or contact details on this device. "
                'Your operator holds them — get in touch if anything needs '
                'changing.',
          )
        else
          HopCard(
            child: Column(
              children: [
                for (final (index, row) in rows.indexed) ...[
                  if (index > 0) SizedBox(height: hoppin.spacing.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 88,
                        child: Text(
                          row.label,
                          style: hoppin.type.meta.copyWith(
                            color: colors.textMid,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          row.value,
                          style: hoppin.type.bodyMedium.copyWith(
                            color: colors.textHi,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        SizedBox(height: hoppin.spacing.lg),
        // The honest disclosure, in the driver's terms: not "there is no
        // PATCH /me/profile" but "we cannot change this from the app, and here
        // is who can".
        Text(
          "These details can't be changed from the app. If something here is "
          'wrong, contact the Hoppin team and we\'ll update it for you.',
          style: hoppin.type.metaSmall.copyWith(color: colors.textMid),
        ),
        SizedBox(height: hoppin.spacing.xl),
        HopButton.primary(label: 'Continue', onPressed: onContinue),
      ],
    );
  }
}
