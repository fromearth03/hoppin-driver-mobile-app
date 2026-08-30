import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_loading.dart';
import '../logic/profile_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Personal information')),
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: Text('$e', style: AppText.body)),
        data: (profile) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.border,
                  backgroundImage: profile?.avatarUrl == null
                      ? null
                      : NetworkImage(profile!.avatarUrl!),
                  child: profile?.avatarUrl == null
                      ? const Icon(Icons.person,
                          size: 40, color: AppColors.textSecondary)
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              _field('Full name', profile?.fullName ?? '—'),
              _field('Email', profile?.email ?? '—'),
              _field('Phone', profile?.phoneNumber ?? '—'),
              _field('Date of birth', profile?.dateOfBirth ?? '—'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                // Name and photo are verified by the operator, so an edit here
                // would fail — this points at the route that actually works.
                child: const Text(
                  'Your name and photo are verified by your operator. Contact support to change them.',
                  style: AppText.caption,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppText.caption),
            const SizedBox(height: 4),
            Text(value, style: AppText.body),
          ],
        ),
      );
}
