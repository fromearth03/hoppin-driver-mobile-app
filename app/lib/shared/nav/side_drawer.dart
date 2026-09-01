import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_router.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../features/profile/data/models/driver_profile.dart';
import '../../features/profile/logic/profile_controller.dart';
import '../widgets/authed_avatar.dart';

/// The side navigation from the design: a rounded white panel that stops
/// short of the right edge, a tappable profile header above a hairline, a
/// stack of icon rows separated by inset rules, and Logout pinned to the
/// bottom.
///
/// The design lists a "Payment Methods" row. Every `/me/payment-methods`
/// route is rider-only in the ride service — a driver is paid through Stripe
/// Connect, which lives on the Payouts screen — so the row is omitted rather
/// than drawn onto an endpoint that would reject them.
///
/// The design's "Ride History" is this app's Trips, so the row keeps its
/// position in the list and takes the name the rest of the app uses.
class SideDrawer extends ConsumerWidget {
  final VoidCallback? onLogout;

  const SideDrawer({super.key, this.onLogout});

  /// The design leaves a strip of the screen showing to the right of the
  /// panel, so the drawer is narrower than Flutter's 304pt default.
  static const widthFraction = 0.86;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).valueOrNull;

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
                padding: EdgeInsets.zero,
                // No rules between rows — the design separates them with
                // breathing room alone, and hairlines here read as clutter.
                children: [
                  _item(context, Icons.person_outline, 'Personal Information',
                      Routes.personalInfo),
                  _item(context, Icons.history, 'Trips', Routes.trips),
                  _item(context, Icons.receipt_long_outlined, 'Statement',
                      Routes.statement),
                  _item(context, Icons.account_balance_outlined, 'Payouts',
                      Routes.payouts),
                  _item(context, Icons.notifications_none, 'Notifications',
                      Routes.notifications),
                  _item(context, Icons.support_agent_outlined, 'Help & Support',
                      Routes.support),
                  _item(context, Icons.settings_outlined, 'Settings',
                      Routes.settings),
                  _item(context, Icons.delete_outline, 'Delete account',
                      Routes.deleteAccount,
                      color: AppColors.negative),
                ],
              ),
            ),
            _Row(
              icon: Icons.logout,
              label: 'Logout',
              onTap: onLogout,
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
  }) =>
      _Row(
        icon: icon,
        label: label,
        color: color,
        onTap: () => _go(context, route),
      );
}

/// One navigation row: a 26pt outline icon on the left gutter, the label at
/// the design's size, and the whole row tappable at a comfortable height.
class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  const _Row({
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(31, 19, 20, 19),
          child: Row(
            children: [
              Icon(icon, size: 25, color: color ?? AppColors.textPrimary),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  label,
                  style: AppText.heading.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: color ?? AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
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
