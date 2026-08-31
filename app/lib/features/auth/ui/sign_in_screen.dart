import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app_router.dart';
import '../../../core/api/error_codes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/brand_header.dart';
import '../logic/auth_controller.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    final result = await ref
        .read(authControllerProvider.notifier)
        .signIn(_email.text, _password.text);
    if (!mounted) return;

    result.when(
      ok: (_) => context.go(Routes.home),
      err: (e) => setState(() => _error = errorCopy(e)),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        // One screen, not a scrolling page: the design fits a phone, and the
        // scroll view only exists so a keyboard cannot overflow the form.
        body: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BrandHeader(
                title: 'Login',
                subtitle: 'Login using your credentials',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 40, 26, 24),
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
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_busy,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter your email'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      // Above the password field, as the design has it: the
                      // driver reaches for this the moment the password is
                      // the problem, not after they have tried and failed.
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: _busy
                              ? null
                              : () => context.push(Routes.forgotPassword),
                          child: Text(
                            'Forgot Password',
                            style: AppText.body.copyWith(
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        key: const Key('password'),
                        label: 'Password',
                        controller: _password,
                        floatingLabel: true,
                        icon: Icons.lock_outline,
                        obscure: true,
                        revealable: true,
                        enabled: !_busy,
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Enter your password'
                            : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(_error!,
                            style: AppText.body
                                .copyWith(color: AppColors.negative)),
                      ],
                      const SizedBox(height: 32),
                      SizedBox(
                        height: 62,
                        child: FilledButton(
                          onPressed: _busy ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.buttonPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _busy
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Login',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600)),
                        ),
                      ),
                      TextButton(
                        key: const Key('go_to_sign_up'),
                        onPressed:
                            _busy ? null : () => context.go(Routes.signUp),
                        child: const Text('New driver? Create an account'),
                      ),
                      const SizedBox(height: 28),
                      const BrandFooter(),
                    ],
                  ),
                ),
              ),
            ],
          ),
            ),
          ),
        ),
      );
}
