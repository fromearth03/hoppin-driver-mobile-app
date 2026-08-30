import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app_router.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

class SideDrawer extends StatelessWidget {
  /// Wired to sign-out in Batch 2, once an auth controller exists.
  final VoidCallback? onLogout;

  const SideDrawer({super.key, this.onLogout});

  @override
  Widget build(BuildContext context) => Drawer(
        backgroundColor: AppColors.surface,
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 12),
              _item(context, Icons.person_outline, 'Personal Information',
                  Routes.personalInfo),
              _item(context, Icons.route_outlined, 'Trips', Routes.trips),
              _item(context, Icons.notifications_none, 'Notifications',
                  Routes.notifications),
              _item(context, Icons.help_outline, 'Help & Support',
                  Routes.support),
              _item(context, Icons.settings_outlined, 'Settings',
                  Routes.settings),
              const Divider(height: 32, color: AppColors.border),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.negative),
                title: Text('Log out',
                    style: AppText.body.copyWith(color: AppColors.negative)),
                onTap: onLogout,
              ),
            ],
          ),
        ),
      );

  Widget _item(
          BuildContext context, IconData icon, String label, String route) =>
      ListTile(
        leading: Icon(icon, color: AppColors.textSecondary),
        title: Text(label, style: AppText.body),
        onTap: () {
          Navigator.of(context).pop();
          context.go(route);
        },
      );
}
