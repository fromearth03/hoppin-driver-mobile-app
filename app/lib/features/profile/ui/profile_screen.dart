import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

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
/// The name is verified by the operator, so its fields render read-only and
/// changes go through Support. The photo is self-service — the design's
/// pencil badge on the avatar opens a picker and the image goes to
/// `POST /me/avatar/upload`. The design also puts a pencil beside the email;
/// email has no write path on `PATCH /me/profile`, so that one is not drawn.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _phone = TextEditingController();
  bool _busy = false;
  bool _uploading = false;
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

  /// Pick, upload, re-read. The picker caps the image client-side so a
  /// full-resolution phone photo does not hit the server's size limit.
  Future<void> _changePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _uploading = true;
      _error = null;
      _saved = null;
    });
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    final result = await ref.read(profileRepositoryProvider).uploadAvatar(
          bytes,
          filename: picked.name,
          contentType: picked.mimeType ?? 'image/jpeg',
        );
    if (!mounted) return;
    setState(() => _uploading = false);
    result.when(
      ok: (_) {
        ref.invalidate(profileProvider);
        setState(() => _saved = 'Photo updated');
      },
      err: (e) => setState(() => _error = errorCopy(e)),
    );
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
                        child: Stack(
                          children: [
                            CircleAvatar(
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
                            // The design's pencil badge, bottom-right on the
                            // avatar — the one photo edit the server backs.
                            Positioned(
                              right: 2,
                              bottom: 2,
                              child: Material(
                                color: AppColors.buttonPrimary,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: _uploading ? null : _changePhoto,
                                  child: Padding(
                                    padding: const EdgeInsets.all(9),
                                    child: _uploading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white),
                                          )
                                        : const Icon(Icons.edit,
                                            size: 20, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ],
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
                                  'Your full name is verified. To update it, '
                                  'please contact Support',
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
