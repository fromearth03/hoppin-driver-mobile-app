import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app_router.dart';
import '../../../core/api/error_codes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../logic/signup_controller.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _notice = null;
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    final result = await ref.read(signupControllerProvider.notifier).signUp(
          email: _email.text,
          password: _password.text,
          fullName: _name.text,
          phone: _phone.text,
        );
    if (!mounted) return;

    result.when(
      ok: (outcome) {
        switch (outcome) {
          case SignupOutcome.driver:
            context.go(Routes.onboarding);
          case SignupOutcome.needsEmailConfirmation:
            setState(() => _notice =
                'Check your email to confirm your address, then sign in.');
          case SignupOutcome.registrationClosed:
            // The account exists, but it is a rider account. Saying so is the
            // only honest option: sending them into driver onboarding would
            // fail on every call.
            setState(() => _notice =
                'Driver registration is closed at the moment. Your account '
                'was created — contact support to be set up as a driver.');
        }
      },
      err: (e) => setState(() => _error = errorCopy(e)),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Create account')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Drive with Hoppin', style: AppText.display),
                  const SizedBox(height: 8),
                  const Text(
                    'Create your account, then complete a few checks. An '
                    'admin approves every driver before their first trip.',
                    style: AppText.bodySecondary,
                  ),
                  const SizedBox(height: 32),
                  AppTextField(
                    key: const Key('name'),
                    label: 'Full name',
                    controller: _name,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter your full name'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    key: const Key('email'),
                    label: 'Email',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_busy,
                    hint: 'you@example.com',
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return 'Enter your email';
                      // Deliberately loose: the confirmation email is the
                      // real check, and a clever pattern only ever rejects
                      // addresses that turn out to be valid.
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    key: const Key('phone'),
                    label: 'Mobile number',
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    enabled: !_busy,
                    hint: '07700 900000',
                    validator: (v) => (v == null || v.trim().length < 7)
                        ? 'Enter your mobile number'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    key: const Key('password'),
                    label: 'Password',
                    controller: _password,
                    obscure: true,
                    enabled: !_busy,
                    validator: (v) => (v == null || v.length < 8)
                        ? 'Use at least 8 characters'
                        : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!,
                        style:
                            AppText.body.copyWith(color: AppColors.negative)),
                  ],
                  if (_notice != null) ...[
                    const SizedBox(height: 16),
                    Text(_notice!, style: AppText.body),
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
                        : const Text('Create account'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => context.go(Routes.signIn),
                    child: const Text('I already have an account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
