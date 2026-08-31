import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/error_codes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../data/onboarding_repository.dart';
import '../logic/onboarding_controller.dart';
import 'widgets/expiry_field.dart';

/// The credential types the admin compliance sweep reads. One row per type —
/// saving the same type again replaces it.
const _credentialTypes = <String, String>{
  'wolverhampton_taxi_badge': 'Wolverhampton taxi badge',
  'dbs_check': 'DBS check',
  'medical_certificate': 'Medical certificate',
  'right_to_work': 'Right to work',
};

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

  /// Right to work is the one credential checked by share code rather than a
  /// certificate number, so the field only appears there.
  bool get _needsShareCode => _type == 'right_to_work';

  @override
  void dispose() {
    _number.dispose();
    _shareCode.dispose();
    super.dispose();
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
      },
      err: (e) => setState(() => _error = errorCopy(e)),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Badge and credentials'),
          actions: [
            TextButton(
              onPressed: _busy ? null : () => context.pop(),
              child: const Text('Done'),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Add each credential you hold. You can come back and add '
                    'more at any time.',
                    style: AppText.bodySecondary,
                  ),
                  const SizedBox(height: 24),
                  const Text('Type', style: AppText.caption),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    key: const Key('credential_type'),
                    initialValue: _type,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    items: [
                      for (final entry in _credentialTypes.entries)
                        DropdownMenuItem(
                            value: entry.key, child: Text(entry.value)),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _type = v ?? _type),
                  ),
                  const SizedBox(height: 16),
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
                    label: 'Expires',
                    value: _expiresAt,
                    enabled: !_busy,
                    onChanged: (d) => setState(() => _expiresAt = d),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('This is a temporary credential'),
                    value: _isTemporary,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _isTemporary = v),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!,
                        style:
                            AppText.body.copyWith(color: AppColors.negative)),
                  ],
                  if (_saved != null) ...[
                    const SizedBox(height: 16),
                    Text(_saved!,
                        style:
                            AppText.body.copyWith(color: AppColors.positive)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Save credential'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
