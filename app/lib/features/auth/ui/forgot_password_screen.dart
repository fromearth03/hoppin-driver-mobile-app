import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/error_codes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../data/auth_repository.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    final result =
        await ref.read(authRepositoryProvider).requestPasswordReset(_email.text);
    if (!mounted) return;

    result.when(
      ok: (_) => setState(() => _sent = true),
      err: (e) => setState(() => _error = errorCopy(e)),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Forgot password')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Reset your password', style: AppText.title),
                  const SizedBox(height: 8),
                  const Text(
                    "Enter your email and we'll send you a link to set a new password.",
                    style: AppText.bodySecondary,
                  ),
                  const SizedBox(height: 24),
                  AppTextField(
                    key: const Key('email'),
                    label: 'Email',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_busy && !_sent,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter your email'
                        : null,
                  ),
                  if (_sent) ...[
                    const SizedBox(height: 16),
                    // Deliberately does not confirm whether the address is
                    // registered — that would let anyone enumerate accounts.
                    Text(
                      'If that email is registered, a reset link is on its way.',
                      style: AppText.body.copyWith(color: AppColors.positive),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!,
                        style: AppText.body.copyWith(color: AppColors.negative)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: (_busy || _sent) ? null : _submit,
                    child: const Text('Send reset link'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
