import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import 'driver_personal_facts.dart';
import 'widgets/driver_profile_unavailable.dart';

/// Stable widget keys the personal-info screen exposes for tests.
abstract final class DriverPersonalInfoKeys {
  /// The always-visible, always-off Save control.
  static const save = ValueKey('driver.personal.save');

  /// The four rows the session genuinely carries.
  static const name = ValueKey('driver.personal.name');

  /// The account's own identifier.
  static const email = ValueKey('driver.personal.email');

  /// Rendered ONLY when the session knows it.
  static const phone = ValueKey('driver.personal.phone');

  /// Rendered ONLY when the session knows it.
  static const memberSince = ValueKey('driver.personal.member_since');
}

/// **PS-01 — Personal Information, on gap #39.**
///
/// A driver must be able to SEE what we hold about them. That is a transparency
/// obligation, not a nicety. But there is **no driver `GET /me/profile` and no
/// `PATCH /me/profile`** — there never has been — so they must never be led to
/// believe they can change any of it here.
///
/// The screen therefore does three things and nothing else:
///
/// 1. It CONSTRUCTS [DriverProfileUnavailable] **unconditionally**, at the top.
///    The seam is not "sometimes null"; it is ALWAYS null. There is no branch
///    to hang the disclosure on, and pretending there is one would be theatre.
/// 2. It renders the four facts the session genuinely carries — and omits any
///    row it does not know, rather than filling it with a placeholder.
/// 3. It shows the Save button the Figma promises, VISIBLE and at full size,
///    with `onPressed: null`.
///
/// 🔴 On (3): an empty callback is a lie; a null one is the truth. A no-op
/// closure gives a full tap ripple over silence — the driver taps, the UI
/// acknowledges, nothing happens. A disabled control the driver can SEE is off
/// is the honest form.
///
/// 🔴 What this screen refuses to draw, against the Figma frame: a photo
/// picker, a city caption, a star rating, a lifetime trip count, a vehicle
/// card. See [DriverPersonalFacts] for why each one is a fabrication.
///
/// There is no interactor. This screen has nothing to do. That is the point.
class DriverPersonalInfoScreen extends ConsumerWidget {
  /// Creates the read-only personal-information surface.
  const DriverPersonalInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final facts = ref.watch(driverPersonalFactsProvider);

    // Supabase hands back an empty string as readily as a null for a phone the
    // account never had. A blank row is exactly as misleading as a dashed one,
    // so both collapse to "we do not know".
    final phone = _orNull(facts.phone);
    final email = _orNull(facts.email);
    final name = _orNull(facts.fullName) ?? email ?? 'Your account';
    final memberSince = _formatMemberSince(facts.memberSince);

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HopTopBar(
              title: 'Personal Information',
              // 🔴 NEVER null. A null onBack hides the chevron and strands the
              // driver on a leaf screen.
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/profile'),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: hoppin.spacing.gutter,
                  vertical: hoppin.spacing.lg,
                ),
                children: [
                  // The #39 rung. Unconditional — see the class doc.
                  const DriverProfileUnavailable(),
                  SizedBox(height: hoppin.spacing.lg),

                  // Only the facts the session actually holds. A row we cannot
                  // fill is a row we do not draw.
                  HopCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ReadOnlyField(
                          fieldKey: DriverPersonalInfoKeys.name,
                          label: 'Full Name',
                          value: name,
                        ),
                        if (email != null) ...[
                          SizedBox(height: hoppin.spacing.md),
                          _ReadOnlyField(
                            fieldKey: DriverPersonalInfoKeys.email,
                            label: 'Email',
                            value: email,
                          ),
                        ],
                        if (phone != null) ...[
                          SizedBox(height: hoppin.spacing.md),
                          _ReadOnlyField(
                            fieldKey: DriverPersonalInfoKeys.phone,
                            label: 'Contact',
                            value: phone,
                          ),
                        ],
                        if (memberSince != null) ...[
                          SizedBox(height: hoppin.spacing.md),
                          _ReadOnlyField(
                            fieldKey: DriverPersonalInfoKeys.memberSince,
                            label: 'Driving with Hoppin since',
                            value: memberSince,
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: hoppin.spacing.lg),
                ],
              ),
            ),

            // The Figma's CTA. Visible, full size, and OFF — because there is
            // no `PATCH /me/profile` behind it. A no-op callback would still
            // ripple; null does not.
            //
            // PINNED here, outside the scroll view. An inert control the driver
            // has to scroll to discover is a poor disclosure — the whole point
            // is that they SEE it is off, without hunting for it.
            Padding(
              padding: EdgeInsets.fromLTRB(
                hoppin.spacing.gutter,
                hoppin.spacing.sm,
                hoppin.spacing.gutter,
                hoppin.spacing.lg,
              ),
              child: const HopButton.primary(
                key: DriverPersonalInfoKeys.save,
                label: 'Save Changes',
                onPressed: null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Collapses the empty string to null. Supabase returns `''` as freely as it
/// returns `null` for a field the account never had, and a blank value must not
/// become a blank row.
String? _orNull(String? raw) {
  final trimmed = raw?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

const _months = <String>[
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Renders the session's account-creation timestamp as "August 2025".
///
/// Returns null when the value is missing or unparseable — an unreadable date
/// is not a date, and a row we cannot fill is a row we do not draw.
String? _formatMemberSince(String? iso) {
  final raw = _orNull(iso);
  if (raw == null) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  return '${_months[parsed.month - 1]} ${parsed.year}';
}

/// One labelled, unmistakably non-editable field.
///
/// A real [TextField] so it reads as a form field the way the Figma draws it —
/// but `readOnly` and `enabled: false`, with no cursor and no keyboard. A field
/// a driver can type into is a promise that the text goes somewhere. It does
/// not.
class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.fieldKey,
    required this.label,
    required this.value,
  });

  final Key fieldKey;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: hoppin.type.meta.copyWith(color: colors.textMid),
        ),
        SizedBox(height: hoppin.spacing.xs),
        TextField(
          key: fieldKey,
          controller: TextEditingController(text: value),
          readOnly: true,
          enabled: false,
          showCursor: false,
          style: hoppin.type.bodyLarge.copyWith(color: colors.textHi),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: colors.canvas,
            contentPadding: EdgeInsets.symmetric(
              horizontal: hoppin.spacing.md,
              vertical: hoppin.spacing.sm,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(hoppin.radii.input),
              borderSide: BorderSide(color: colors.hairline),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(hoppin.radii.input),
              borderSide: BorderSide(color: colors.hairline),
            ),
          ),
        ),
      ],
    );
  }
}
