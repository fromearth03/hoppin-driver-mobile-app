import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import 'driver_personal_facts.dart';
import 'profile_router.dart';

/// Stable widget keys the profile hub exposes for tests.
abstract final class DriverProfileKeys {
  /// The screen root.
  static const root = ValueKey('driver-profile-root');

  /// Tappable profile photo — opens the camera/gallery picker.
  static const avatarEditor = ValueKey('driver-profile-avatar-editor');

  /// Route to the read-only personal-information surface.
  static const personalRow = ValueKey('driver-profile-personal-row');

  /// Route to the earnings + payouts surface.
  static const earningsRow = ValueKey('driver-profile-earnings-row');

  /// Route to the document wallet (Phase 3 built it).
  static const documentsRow = ValueKey('driver-profile-documents-row');

  /// Route to settings.
  static const settingsRow = ValueKey('driver-profile-settings-row');

  /// Route to support.
  static const supportRow = ValueKey('driver-profile-support-row');

  /// Ends the session. Genuinely bound — this one really works.
  static const signOutRow = ValueKey('driver-profile-signout-row');
}

/// **PS-01 — the Profile hub.**
///
/// A menu of routes, and a name the session genuinely carries. That is the
/// whole screen.
///
/// 🔴 **What the Figma's `Profile.jpg` draws and this hub deliberately does
/// NOT.** Every one of these is a fabrication with no field behind it anywhere
/// in the data model (see [DriverPersonalFacts]), and a profile endpoint
/// landing tomorrow would still carry none of them unless they are designed in
/// first:
///
///  * **A star rating.** The worst of the five. A driver's livelihood is judged
///    on a rating, and there is no read for one. A number invented here would
///    be a number a driver plans their week around.
///  * **A lifetime trip count.**
///  * **A vehicle card.**
///  * **A city caption.** (The rider refused the identical caption for the
///    identical reason.)
///
/// The header therefore shows the name and email the session actually holds,
/// plus the avatar, and nothing else. A hub that shows less than the frame but
/// lies about none of it is the correct hub.
///
/// ✅ **The avatar picker is no longer on that list.** It was, and the reason was
/// correct at the time: there was no avatar endpoint, so a picker would have let
/// a driver choose a photo that went nowhere. `POST /me/avatar/upload` now
/// exists and the rider sees the result on the matched-driver card mid-trip, so
/// the control is real and the photo lands.
class DriverProfileScreen extends ConsumerWidget {
  /// Creates the profile hub.
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final facts = ref.watch(driverPersonalFactsProvider);
    final avatar = ref.watch(avatarUploadControllerProvider);

    final email = _orNull(facts.email);
    final name = _orNull(facts.fullName) ?? email ?? 'Your account';

    return Scaffold(
      key: DriverProfileKeys.root,
      backgroundColor: colors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            HopTopBar(
              title: 'Profile',
              // 🔴 NEVER null — a null onBack hides the chevron entirely.
              onBack: () => context.canPop() ? context.pop() : context.go('/'),
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
                  // The header: the two facts the session genuinely holds, plus
                  // the profile photo (a real upload — see the class doc). Still
                  // no rating, no trip count, no vehicle, no city.
                  HopCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HopAvatarEditor(
                          key: DriverProfileKeys.avatarEditor,
                          name: name,
                          imageUrl: switch (avatar) {
                            AvatarIdle(:final url) => url,
                            AvatarUploaded(:final url) => url,
                            _ => null,
                          },
                          headers: ref.watch(imageAuthHeadersProvider),
                          busy: avatar is AvatarUploading,
                          error: switch (avatar) {
                            AvatarUploadFailed(:final message) => message,
                            _ => null,
                          },
                          onTap: () => ref
                              .read(avatarUploadControllerProvider.notifier)
                              .pickAndUpload(),
                        ),
                        SizedBox(height: hoppin.spacing.md),
                        Text(
                          name,
                          style: hoppin.type.section
                              .copyWith(color: colors.textHi),
                        ),
                        if (email != null) ...[
                          SizedBox(height: hoppin.spacing.xs),
                          Text(
                            email,
                            style: hoppin.type.meta
                                .copyWith(color: colors.textMid),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: hoppin.spacing.lg),

                  HopCard(
                    padding: EdgeInsets.symmetric(vertical: hoppin.spacing.sm),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HopListRow(
                          key: DriverProfileKeys.personalRow,
                          icon: Icons.person_outline,
                          label: 'Personal information',
                          divider: true,
                          onTap: () => context.go(kDriverPersonalRoute),
                        ),
                        HopListRow(
                          key: DriverProfileKeys.earningsRow,
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Earnings & payouts',
                          divider: true,
                          onTap: () => context.go('/earnings'),
                        ),
                        HopListRow(
                          key: DriverProfileKeys.documentsRow,
                          icon: Icons.folder_outlined,
                          label: 'My documents',
                          divider: true,
                          onTap: () => context.go('/documents'),
                        ),
                        HopListRow(
                          key: DriverProfileKeys.settingsRow,
                          icon: Icons.settings_outlined,
                          label: 'Settings',
                          divider: true,
                          onTap: () => context.go('/settings'),
                        ),
                        HopListRow(
                          key: DriverProfileKeys.supportRow,
                          icon: Icons.support_agent_outlined,
                          label: 'Help & support',
                          onTap: () => context.go('/support'),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: hoppin.spacing.lg),

                  // Genuinely bound. Unlike almost everything else this lane
                  // ships, this control really does what it says.
                  HopCard(
                    padding: EdgeInsets.symmetric(vertical: hoppin.spacing.sm),
                    child: _SignOutRow(
                      key: DriverProfileKeys.signOutRow,
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

/// The sign-out row, painted in the destructive role.
class _SignOutRow extends StatelessWidget {
  const _SignOutRow({required this.onTap, super.key});

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
            Icon(Icons.logout, color: colors.error, size: 22),
            SizedBox(width: hoppin.spacing.md),
            Expanded(
              child: Text(
                'Sign out',
                style: hoppin.type.bodyMedium.copyWith(color: colors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _orNull(String? raw) {
  final trimmed = raw?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}
