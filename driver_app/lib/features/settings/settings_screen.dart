import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../../app.dart';
import 'widgets/delete_account_popup.dart';
import 'widgets/driver_settings_prefs_unavailable.dart';
import 'widgets/driver_settings_toggle_row.dart';

/// Stable widget keys the Settings screen exposes for tests.
abstract final class DriverSettingsKeys {
  /// The screen root.
  static const root = ValueKey('driver-settings-root');

  /// The ONE genuinely working control on this screen.
  static const themeToggle = ValueKey('driver-settings-theme-toggle');

  /// Route to the notification centre.
  static const notificationsRow = ValueKey('driver-settings-notifications-row');

  /// The red route to the Art. 17 erasure request.
  static const deleteAccountRow = ValueKey('driver-settings-delete-row');

  /// Ends the session. Genuinely bound.
  static const signOutRow = ValueKey('driver-settings-signout-row');
}

/// **PS-02 — driver Settings.** A screen full of controls; exactly ONE works.
///
/// This is the lane's hardest honesty test. Settings is where a driver most
/// expects a control to *do* something, and almost nothing here can: there is
/// no driver preferences endpoint, and there is deliberately no local cache to
/// fake one with. So every unbacked switch ships **visible and inert**
/// (`onChanged: null` — never an empty closure), under a single screen-level
/// [DriverSettingsPrefsUnavailable] rung.
///
/// 🔴 **ONE rung for the screen, not eight.** Eight identical rungs is noise,
/// and noise is how a disclosure gets ignored.
///
/// **What is LIVE:** the **theme**. Client-side, genuinely works, applies
/// immediately, and it is an **ADDITION** the Figma omits — truth here means
/// *adding* a control, not only removing them. 🔴 Dark is the driver's PRIMARY
/// theme (SF-02), not a courtesy: they use this at night, in a cradle,
/// one-handed, in the rain, with sun on the screen. It is session-scoped
/// because no persistence package exists by ruling, and the rung says so.
///
/// 🔴 **The security toggle the Figma draws is OMITTED, not seamed.** The frame
/// renders it ON — advertising that the app or its payments are protected by a
/// passcode. **No such feature exists anywhere in this codebase.** A switch
/// rendered ON claiming a protection that does not exist is a **SECURITY LIE**,
/// materially worse than a merely broken preference, and there is **no honest
/// rung for it**: you cannot disclose your way out of telling someone their
/// money is guarded when it is not. Disabled-but-ON still reads as a live
/// guarantee, so it is not drawn at all. The rider omitted it for the same
/// reason. It is named in the release-gate report so the decision is visible
/// rather than silently made.
///
/// This screen writes NOTHING. The only write in this lane is the deletion
/// ticket, and it happens in the popup.
class DriverSettingsScreen extends ConsumerWidget {
  /// Creates the driver settings screen.
  const DriverSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    final themeMode = ref.watch(themeModeProvider);
    final platformDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final isDark = switch (themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => platformDark,
    };

    return Scaffold(
      key: DriverSettingsKeys.root,
      backgroundColor: colors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            HopTopBar(
              title: 'Settings',
              // 🔴 NEVER null — a null onBack hides the chevron and strands
              // the driver on a leaf screen.
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/profile'),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  hoppin.spacing.gutter,
                  hoppin.spacing.md,
                  hoppin.spacing.gutter,
                  hoppin.spacing.xl,
                ),
                children: [
                  // ── The preferences rung. ONE for the whole screen, pinned
                  // above the toggle groups.
                  const DriverSettingsPrefsUnavailable(),
                  SizedBox(height: hoppin.spacing.lg),

                  // ── Appearance — the one group that entirely works.
                  const _GroupLabel('Appearance'),
                  HopCard(
                    padding: EdgeInsets.symmetric(vertical: hoppin.spacing.sm),
                    child: DriverSettingsToggleRow(
                      key: DriverSettingsKeys.themeToggle,
                      label: 'Dark mode',
                      supporting: 'Applies right away. Resets when you reopen '
                          'the app.',
                      value: isDark,
                      // LIVE. It writes the real theme provider the whole app
                      // watches — not a local bool that pretends to.
                      onChanged: (on) => ref
                          .read(themeModeProvider.notifier)
                          .set(on ? ThemeMode.dark : ThemeMode.light),
                    ),
                  ),
                  SizedBox(height: hoppin.spacing.lg),

                  // ── Notifications — every one of these is inert. The design
                  // is real; the backend is not. They ship at their Figma
                  // default positions so the screen reads correctly and
                  // nothing is claimed.
                  const _GroupLabel('Notifications'),
                  HopCard(
                    padding: EdgeInsets.symmetric(vertical: hoppin.spacing.sm),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DriverSettingsToggleRow(
                          label: 'Ride offer alerts',
                          value: true,
                          divider: true,
                        ),
                        DriverSettingsToggleRow(
                          label: 'Email notifications',
                          value: true,
                          divider: true,
                        ),
                        DriverSettingsToggleRow(
                          label: 'Chat & message sounds',
                          value: true,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: hoppin.spacing.lg),

                  // ── Everything else is a ROUTE, not a switch. A route
                  // either resolves or it does not; there is nothing to fake.
                  const _GroupLabel('Account'),
                  HopCard(
                    padding: EdgeInsets.symmetric(vertical: hoppin.spacing.sm),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HopListRow(
                          key: DriverSettingsKeys.notificationsRow,
                          icon: Icons.notifications_none,
                          label: 'Notifications',
                          divider: true,
                          onTap: () => context.go('/notifications'),
                        ),
                        // 🔴 NO "Privacy notice" ROW. The Figma draws one; the
                        // driver app has NO `/legal/*` routes and no lane in
                        // this phase builds them. A row that drops the driver
                        // on the route-not-found screen is worse than an absent
                        // row — the rider app shipped seven such targets behind
                        // a green suite and every one of them was a dead end.
                        // Support is the working route to anything we hold.
                        //
                        // The route out. Art. 17 is not honoured by a right you
                        // have to know to look for, so it is findable, at the
                        // bottom, in the destructive role.
                        _DestructiveRow(
                          key: DriverSettingsKeys.deleteAccountRow,
                          icon: Icons.delete_outline,
                          label: 'Delete my account',
                          onTap: () => showDriverDeleteAccountPopup(context),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: hoppin.spacing.lg),

                  HopCard(
                    padding: EdgeInsets.symmetric(vertical: hoppin.spacing.sm),
                    child: _DestructiveRow(
                      key: DriverSettingsKeys.signOutRow,
                      icon: Icons.logout,
                      label: 'Sign out',
                      onTap: () => ref.read(authServiceProvider).signOut(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A group heading above a card of controls.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    return Padding(
      padding: EdgeInsets.only(
        left: hoppin.spacing.sm,
        bottom: hoppin.spacing.sm,
      ),
      child: Text(
        label,
        style: hoppin.type.bodyMedium.copyWith(color: hoppin.colors.textMid),
      ),
    );
  }
}

/// A row painted in the destructive role. [HopListRow] paints its icon in the
/// accent role; these routes must READ as destructive.
class _DestructiveRow extends StatelessWidget {
  const _DestructiveRow({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: hoppin.spacing.lg,
          vertical: hoppin.spacing.md,
        ),
        child: Row(
          children: [
            Icon(icon, color: colors.error, size: 22),
            SizedBox(width: hoppin.spacing.md),
            Expanded(
              child: Text(
                label,
                style: hoppin.type.bodyMedium.copyWith(color: colors.error),
              ),
            ),
            Icon(Icons.chevron_right, color: colors.error, size: 22),
          ],
        ),
      ),
    );
  }
}
