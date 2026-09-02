import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_router.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../features/profile/data/models/driver_profile.dart';
import '../../features/profile/logic/profile_controller.dart';
import '../../features/profile/ui/widgets/logout_dialog.dart';
import '../widgets/authed_avatar.dart';

/// The side navigation from the design: a rounded white panel that stops
/// short of the right edge, a tappable profile header above a hairline, a
/// stack of icon rows separated by inset rules, and Logout pinned to the
/// bottom.
///
/// "Payment Methods" is where a driver manages being paid — Stripe Connect,
/// not the rider's cards. It takes that name because it is the one a driver
/// looks for; "Payouts" described the money's direction rather than the
/// thing they came to change.
///
/// The design's "Ride History" is this app's Trips, so the row keeps its
/// position in the list and takes the name the rest of the app uses.
class SideDrawer extends ConsumerWidget {
  final VoidCallback? onLogout;

  /// The route the driver is on, so the matching row can say so.
  ///
  /// Passed in rather than read from GoRouterState: the shell already knows
  /// it, and reaching for the router here would make the drawer unbuildable
  /// anywhere without one — including in tests, where it threw outright.
  final String? currentPath;

  const SideDrawer({super.key, this.onLogout, this.currentPath});

  /// The design leaves a strip of the screen showing to the right of the
  /// panel, so the drawer is narrower than Flutter's 304pt default.
  static const widthFraction = 0.86;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).valueOrNull;
    // Which row the driver is already on. Without it every row looked
    // equally available, and the drawer gave no clue where they were.
    final here = currentPath;

    return Drawer(
      backgroundColor: AppColors.surface,
      width: MediaQuery.sizeOf(context).width * widthFraction,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProfileHeader(
              profile: profile,
              onTap: () => _go(context, Routes.personalInfo),
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 10),
                // Two groups under quiet labels. Nine flat rows made the
                // driver read every one to find the money; work and money
                // are different errands and now look like it.
                //
                // Personal Information and Settings are not here: both are
                // reached from the Settings screen and its gear on Home, and
                // a second door only made the drawer a longer way round.
                // Delete account is not a destination either — it belongs
                // where the driver manages their account, not one mis-tap
                // from Trips.
                children: [
                  const _GroupLabel('Your work'),
                  _item(context, Icons.history, 'Trips', Routes.trips,
                      here: here),
                  _item(context, Icons.support_agent_outlined,
                      'Help & Support', Routes.support,
                      here: here),
                  _item(context, Icons.notifications_none, 'Notifications',
                      Routes.notifications,
                      here: here),
                  const SizedBox(height: 14),
                  const _GroupLabel('Your money'),
                  _item(context, Icons.receipt_long_outlined, 'Statement',
                      Routes.statement,
                      here: here),
                  _item(context, Icons.account_balance_outlined,
                      'Payment Methods', Routes.payouts,
                      here: here),
                ],
              ),
            ),
            _Row(
              icon: Icons.logout,
              label: 'Logout',
              // The design's "Are you logging out?" dialog stands between
              // the tap and the sign-out — one mis-tap here otherwise dumps
              // a working driver back to the sign-in screen.
              onTap: () => showLogoutDialog(context, ref),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  static void _go(BuildContext context, String route) {
    Navigator.of(context).pop();
    // push, not go: these screens live one step deeper than the tab the
    // driver was on, and the app bar's back arrow only exists when there
    // is somewhere to pop back to.
    context.push(route);
  }

  Widget _item(
    BuildContext context,
    IconData icon,
    String label,
    String route, {
    Color? color,
    String? here,
  }) =>
      _Row(
        icon: icon,
        label: label,
        color: color,
        selected: here == route,
        onTap: () => _go(context, route),
      );
}

/// One navigation row: the icon in a soft tile, the label beside it, and a
/// chevron saying the row leads somewhere.
///
/// The row the driver is already on is filled and tinted rather than merely
/// bolded — a drawer of nine identical rows told them what the app contains
/// but never where they were standing in it.
class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;
  final bool selected;

  const _Row({
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.primary;
    final ink = color ?? AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected
            ? tint.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  height: 38,
                  width: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: selected ? 0.16 : 0.07),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 20, color: tint),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: AppText.heading.copyWith(
                      fontSize: 17,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: selected
                      ? tint
                      : AppColors.textSecondary.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Name, photo and rating, all from `GET /me/profile`. While the request is
/// in flight the row keeps its height and shows placeholders, so opening the
/// drawer never shifts the list underneath it.
class _ProfileHeader extends StatelessWidget {
  final DriverProfile? profile;
  final VoidCallback onTap;

  const _ProfileHeader({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile?.avatarUrl;
    final name = profile?.fullName ?? '';
    final rating = profile?.rating;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(31, 30, 20, 30),
        child: Row(
          children: [
            AuthedAvatar(
              url: avatarUrl,
              radius: 26,
              backgroundColor: AppColors.background,
              fallback: const Icon(Icons.person,
                  size: 30, color: AppColors.textDisabled),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: AppText.title.copyWith(fontSize: 24),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // The server sends null until the driver's first rating, so
                  // an unrated driver gets no stars rather than five empty
                  // ones the design has no state for.
                  if (rating != null) _Rating(profile!),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 26, color: AppColors.textPrimary),
          ],
        ),
      ),
    );
  }
}

/// Five stars filled to the driver's score, then the score and the count —
/// "4.31 (150)" in the design.
class _Rating extends StatelessWidget {
  final DriverProfile profile;

  const _Rating(this.profile);

  @override
  Widget build(BuildContext context) {
    final rating = profile.rating ?? 0;
    return Row(
      children: [
        for (var i = 1; i <= 5; i++)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Icon(
              rating >= i - 0.25 ? Icons.star : Icons.star_border,
              size: 17,
              color: AppColors.gold,
            ),
          ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '${rating.toStringAsFixed(2)} (${profile.ratingCount})',
            style: AppText.body.copyWith(fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// A quiet heading over a group of rows. Small, spaced and secondary — it
/// orients without competing with the destinations under it.
class _GroupLabel extends StatelessWidget {
  final String text;

  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(26, 8, 20, 6),
        child: Text(
          text.toUpperCase(),
          style: AppText.caption.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: AppColors.textSecondary,
          ),
        ),
      );
}
