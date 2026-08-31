import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app_router.dart';
import '../../../core/api/error_codes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/brand_header.dart';
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
    final result = await ref
        .read(authRepositoryProvider)
        .requestPasswordReset(_email.text);
    if (!mounted) return;

    result.when(
      ok: (_) => setState(() => _sent = true),
      err: (e) => setState(() => _error = errorCopy(e)),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BrandHeader(
                title: 'Forgot Password',
                subtitle: 'Securely recover access to your account.',
                onBack: () => context.pop(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 56, 26, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        key: const Key('email'),
                        label: 'Email',
                        controller: _email,
                        floatingLabel: true,
                        icon: Icons.mail_outline,
                        hint: 'abc@hoppins.com',
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_busy && !_sent,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter your email'
                            : null,
                      ),
                      if (_sent) ...[
                        const SizedBox(height: 20),
                        // Deliberately says "if an account exists": confirming
                        // which addresses are registered would let anyone
                        // enumerate the platform's drivers.
                        Text(
                          'If an account exists for that address, a reset '
                          'link is on its way.',
                          style: AppText.body
                              .copyWith(color: AppColors.positive),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 20),
                        Text(_error!,
                            style: AppText.body
                                .copyWith(color: AppColors.negative)),
                      ],
                      const SizedBox(height: 28),
                      AppOutlinedButton(
                        label: 'Reset Password',
                        busy: _busy,
                        onPressed: _sent ? null : _submit,
                      ),
                      const SizedBox(height: 20),
                      AppButton(
                        label: 'Back to Sign In',
                        style: AppButtons.muted(),
                        onPressed:
                            _busy ? null : () => context.go(Routes.signIn),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
