import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app_router.dart';
import '../../../core/api/error_codes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../data/onboarding_repository.dart';
import '../logic/onboarding_controller.dart';
import 'widgets/expiry_field.dart';
import 'widgets/wizard_scaffold.dart';

/// The credential types the admin compliance sweep reads. One row per type —
/// saving the same type again replaces it.
const _credentialTypes = <String, String>{
  'wolverhampton_taxi_badge': 'Wolverhampton taxi badge',
  'dbs_check': 'DBS check',
  'medical_certificate': 'Medical certificate',
  'right_to_work': 'Right to work',
};

/// Step 2 of 4: the licences and certificates an admin checks.
///
/// The design's two states are both here: the empty state is the form, and
/// the "Uploaded Multiple Document List" state is the saved list above it,
/// which fills in as each credential is stored.
class CredentialsScreen extends ConsumerStatefulWidget {
  const CredentialsScreen({super.key});

  @override
  ConsumerState<CredentialsScreen> createState() => _CredentialsScreenState();
}

class _CredentialsScreenState extends ConsumerState<CredentialsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _shareCode = TextEditingController();
  String _type = _credentialTypes.keys.first;
  DateTime? _expiresAt;
  bool _isTemporary = false;
  bool _busy = false;
  String? _error;
  String? _saved;

  /// The credentials already stored, so the driver can see what is done.
  /// Empty until the first load lands, which is the design's empty state.
  List<Map<String, dynamic>> _existing = const [];

  /// Right to work is the one credential checked by share code rather than a
  /// certificate number, so the field only appears there.
  bool get _needsShareCode => _type == 'right_to_work';

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _number.dispose();
    _shareCode.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final result = await ref.read(onboardingRepositoryProvider).credentials();
    if (!mounted) return;
    result.when(
      ok: (rows) => setState(() => _existing = rows),
      // A failed list is not worth an error banner: the form below still
      // works, and the driver came here to add, not to read.
      err: (_) {},
    );
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _saved = null;
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    final result = await ref.read(onboardingRepositoryProvider).saveCredential(
          type: _type,
          number: _number.text,
          shareCode: _needsShareCode ? _shareCode.text : null,
          isTemporary: _isTemporary,
          expiresAt: _expiresAt,
        );
    if (!mounted) return;

    result.when(
      ok: (_) {
        ref.read(onboardingControllerProvider.notifier).refresh();
        // Most drivers have several of these, so stay put and confirm rather
        // than bouncing back to the checklist after every one.
        setState(() {
          _saved = '${_credentialTypes[_type]} saved.';
          _number.clear();
          _shareCode.clear();
          _expiresAt = null;
          _isTemporary = false;
        });
        _loadExisting();
      },
      err: (e) => setState(() => _error = errorCopy(e)),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => WizardScaffold(
        title: 'Licenses & Certificates',
        step: 2,
        card: true,
        onBack: _busy ? null : () => context.pop(),
        actions: WizardActions(
          busy: _busy,
          onBack: _busy ? null : () => context.pop(),
          onContinue: _busy ? null : _submit,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._savedList(),
              DropdownButtonFormField<String>(
                key: const Key('credential_type'),
                initialValue: _type,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                isExpanded: true,
                items: [
                  for (final entry in _credentialTypes.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged:
                    _busy ? null : (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: 24),
              const Text('Document Details', style: AppText.title),
              const SizedBox(height: 6),
              const Text(
                'Enter your reference details as printed on the certificate.',
                style: AppText.bodySecondary,
              ),
              const SizedBox(height: 20),
              AppTextField(
                key: const Key('credential_number'),
                label: 'Reference number',
                controller: _number,
                enabled: !_busy,
                textCapitalization: TextCapitalization.characters,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter the reference number'
                    : null,
              ),
              if (_needsShareCode) ...[
                const SizedBox(height: 16),
                AppTextField(
                  key: const Key('share_code'),
                  label: 'Share code',
                  controller: _shareCode,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter your share code'
                      : null,
                ),
              ],
              const SizedBox(height: 16),
              ExpiryField(
                key: const Key('credential_expiry'),
                label: 'Expiry date',
                value: _expiresAt,
                enabled: !_busy,
                onChanged: (d) => setState(() => _expiresAt = d),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter the expiry date as shown on your certificate',
                style: AppText.caption,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('This is a temporary credential',
                    style: AppText.body),
                value: _isTemporary,
                onChanged:
                    _busy ? null : (v) => setState(() => _isTemporary = v),
              ),
              // The design puts an "Upload Document" drop zone here, and a
              // Preview list beneath it. Uploads are not part of a
              // credential: POST /drivers/me/credentials takes a type, a
              // number, a share code, a temporary flag and an expiry, and
              // nothing else. Files go through the documents flow, which has
              // its own presign + confirm pair, so this step links there
              // rather than growing a drop zone that has nowhere to post to.
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('go_to_documents'),
                onPressed: _busy ? null : () => context.push(Routes.documents),
                icon: const Icon(Icons.file_upload_outlined, size: 20),
                label: const Text('Upload your documents'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!,
                    style: AppText.body.copyWith(color: AppColors.negative)),
              ],
              if (_saved != null) ...[
                const SizedBox(height: 16),
                Text(_saved!,
                    style: AppText.body.copyWith(color: AppColors.positive)),
              ],
            ],
          ),
        ),
      );

  /// The design's filled state: one card per credential already stored, each
  /// showing what the service actually holds for it.
  List<Widget> _savedList() {
    if (_existing.isEmpty) return const [];
    return [
      const Text('Saved credentials', style: AppText.title),
      const SizedBox(height: 6),
      const Text('These are already with us.', style: AppText.bodySecondary),
      const SizedBox(height: 16),
      for (final row in _existing) ...[
        _SavedCredentialCard(row: row),
        const SizedBox(height: 12),
      ],
      const SizedBox(height: 12),
    ];
  }
}

class _SavedCredentialCard extends StatelessWidget {
  final Map<String, dynamic> row;

  const _SavedCredentialCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final type = (row['type'] as String?) ?? '';
    final number = (row['number'] as String?) ?? '';
    final expiry = (row['expires_at'] as String?) ?? '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.badge_outlined,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(_credentialTypes[type] ?? type,
                    style: AppText.heading),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.positive.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 16, color: AppColors.positive),
                const SizedBox(width: 6),
                Text('Saved',
                    style:
                        AppText.caption.copyWith(color: AppColors.positive)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _field('Reference number', number)),
              const SizedBox(width: 12),
              Expanded(
                  child: _field(
                      'Expiry date', expiry.isEmpty ? 'Not set' : expiry)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.caption),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body),
          ),
        ],
      );
}
