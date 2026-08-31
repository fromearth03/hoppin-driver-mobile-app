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

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    // The SDK exchanged the emailed link for a recovery session on open,
    // so updating the password needs no token passed by hand.
    final result =
        await ref.read(authRepositoryProvider).updatePassword(_password.text);
    if (!mounted) return;

    result.when(
      ok: (_) => context.go(Routes.signIn),
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
              const BrandHeader(
                title: 'Reset Password',
                subtitle:
                    'Enter your new password (must be at least 8 characters)',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 56, 26, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        key: const Key('password'),
                        label: 'Set New Password',
                        controller: _password,
                        floatingLabel: true,
                        icon: Icons.lock_outline,
                        hint: 'Enter your New Password',
                        obscure: true,
                        revealable: true,
                        enabled: !_busy,
                        validator: (v) => (v == null || v.length < 8)
                            ? 'Use at least 8 characters'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      AppTextField(
                        key: const Key('confirm'),
                        label: 'Confirm New Password',
                        controller: _confirm,
                        floatingLabel: true,
                        icon: Icons.lock_outline,
                        hint: 'Confirm your New Password',
                        obscure: true,
                        revealable: true,
                        enabled: !_busy,
                        validator: (v) =>
                            v != _password.text ? "Passwords don't match" : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 20),
                        Text(_error!,
                            style: AppText.body
                                .copyWith(color: AppColors.negative)),
                      ],
                      const SizedBox(height: 28),
                      AppButton(
                        label: 'Reset Password',
                        busy: _busy,
                        onPressed: _submit,
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
