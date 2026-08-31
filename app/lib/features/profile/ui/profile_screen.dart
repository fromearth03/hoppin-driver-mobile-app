import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app_router.dart';
import '../../../core/api/error_codes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_loading.dart';
import '../data/models/driver_profile.dart';
import '../data/profile_repository.dart';
import '../logic/profile_controller.dart';

/// Personal information.
///
/// Name and photo are verified by the operator: `PATCH /me/profile` accepts
/// only phone and date of birth, so the name fields render read-only and the
/// avatar carries no edit affordance. The design puts a pencil badge on the
/// avatar and beside the email; neither has an endpoint, so neither is drawn.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _phone = TextEditingController();
  bool _busy = false;
  bool _seeded = false;
  String? _error;
  String? _saved;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  void _seed(DriverProfile? profile) {
    if (_seeded || profile == null) return;
    _seeded = true;
    _phone.text = profile.phoneNumber ?? '';
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
      _saved = null;
    });
    final result = await ref
        .read(profileRepositoryProvider)
        .update(phoneNumber: _phone.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);

    result.when(
      ok: (_) {
        ref.invalidate(profileProvider);
        if (mounted) setState(() => _saved = 'Saved');
      },
      err: (e) => setState(() => _error = errorCopy(e)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: AppColors.textPrimary, size: 26),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('Personal Information',
            style: AppText.title.copyWith(fontSize: 24)),
      ),
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: Text('$e', style: AppText.body)),
        data: (profile) {
          _seed(profile);
          final (first, last) = _splitName(profile?.fullName ?? '');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 66,
                          backgroundColor: AppColors.border,
                          backgroundImage: profile?.avatarUrl == null
                              ? null
                              : NetworkImage(profile!.avatarUrl!),
                          child: profile?.avatarUrl == null
                              ? const Icon(Icons.person,
                                  size: 60, color: AppColors.textSecondary)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _ReadOnlyField(label: 'First Name', value: first),
                      const SizedBox(height: 14),
                      _ReadOnlyField(label: 'Last Name', value: last),
                      const SizedBox(height: 14),
                      _ReadOnlyField(
                          label: 'Email', value: profile?.email ?? '—'),
                      const SizedBox(height: 14),
                      _EditableField(
                        label: 'Phone Number',
                        controller: _phone,
                        enabled: !_busy,
                      ),
                      const SizedBox(height: 18),
                      // The design puts this behind a chevron to Support; the
                      // row navigates there because that is the only route
                      // that can actually change a verified name or photo.
                      InkWell(
                        onTap: () => context.push(Routes.support),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 4, vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 24, color: AppColors.textPrimary),
                              SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Your full name and profile picture are '
                                  'verified. To update them, please contact '
                                  'Support',
                                  style: AppText.body,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.chevron_right,
                                  size: 24, color: AppColors.textPrimary),
                            ],
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(_error!,
                            style: AppText.body
                                .copyWith(color: AppColors.negative)),
                      ],
                      if (_saved != null) ...[
                        const SizedBox(height: 16),
                        Text(_saved!,
                            style: AppText.body
                                .copyWith(color: AppColors.positive)),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: AppButton(
                  label: 'Save',
                  busy: _busy,
                  onPressed: _save,
                  style: AppButtons.outlined().copyWith(
                    textStyle: WidgetStateProperty.all(
                      const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w500),
                    ),
                    foregroundColor:
                        WidgetStateProperty.all(AppColors.textPrimary),
                    side: WidgetStateProperty.all(BorderSide.none),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The profile endpoint returns one `full_name`. The design shows two
/// fields, so the name is split on the first space rather than inventing a
/// surname the server never sent.
(String, String) _splitName(String fullName) {
  final trimmed = fullName.trim();
  if (trimmed.isEmpty) return ('—', '—');
  final i = trimmed.indexOf(' ');
  if (i < 0) return (trimmed, '—');
  return (trimmed.substring(0, i), trimmed.substring(i + 1).trim());
}

/// The design's card field: a small grey label above the value, inside a
/// white rounded box with no visible border.
class _FieldShell extends StatelessWidget {
  final String label;
  final Widget child;
  const _FieldShell({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: AppText.caption.copyWith(
                    fontSize: 15, color: AppColors.textDisabled)),
            const SizedBox(height: 6),
            child,
          ],
        ),
      );
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => _FieldShell(
        label: label,
        child: Text(value,
            style: AppText.body
                .copyWith(fontSize: 19, fontWeight: FontWeight.w500)),
      );
}

class _EditableField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled;

  const _EditableField({
    required this.label,
    required this.controller,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) => _FieldShell(
        label: label,
        child: TextField(
          key: const Key('phone'),
          controller: controller,
          enabled: enabled,
          keyboardType: TextInputType.phone,
          style:
              AppText.body.copyWith(fontSize: 19, fontWeight: FontWeight.w500),
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      );
}
