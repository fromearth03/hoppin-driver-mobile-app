import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/error_codes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../data/onboarding_repository.dart';
import '../logic/onboarding_controller.dart';

class LicenseScreen extends ConsumerStatefulWidget {
  const LicenseScreen({super.key});

  @override
  ConsumerState<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends ConsumerState<LicenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _license = TextEditingController();
  final _address = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _license.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    final result = await ref.read(onboardingRepositoryProvider).saveLicense(
          licenseNumber: _license.text,
          address: _address.text,
        );
    if (!mounted) return;

    result.when(
      ok: (_) {
        ref.read(onboardingControllerProvider.notifier).refresh();
        context.pop();
      },
      err: (e) => setState(() => _error = e.code == 'LICENSE_TAKEN'
          // The generic copy would say "something went wrong", which sends
          // the driver to support over a typo they can fix themselves.
          ? 'That licence number is already registered to another account.'
          : errorCopy(e)),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Driving licence')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'As printed on your DVLA licence.',
                    style: AppText.bodySecondary,
                  ),
                  const SizedBox(height: 24),
                  AppTextField(
                    key: const Key('license_number'),
                    label: 'Licence number',
                    controller: _license,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter your licence number'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    key: const Key('address'),
                    label: 'Home address',
                    controller: _address,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter your home address'
                        : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!,
                        style:
                            AppText.body.copyWith(color: AppColors.negative)),
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
                        : const Text('Save'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
