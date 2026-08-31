import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app_router.dart';
import '../../../core/api/error_codes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../logic/signup_controller.dart';
import 'widgets/wizard_scaffold.dart';

/// Step 1 of 4: who the driver is.
///
/// The design splits the name into First and Last. The service takes one
/// `full_name`, so the two boxes are joined on submit rather than the field
/// being collapsed into one — the layout is the design's, the payload is the
/// service's.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _email, _phone, _password]) {
      c.dispose();
    }
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
          fullName: '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim(),
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
  Widget build(BuildContext context) => WizardScaffold(
        title: 'Personal Information',
        step: 1,
        onBack: _busy ? null : () => context.go(Routes.signIn),
        actions: AppButton(
          key: const Key('wizard_continue'),
          label: 'Next',
          busy: _busy,
          onPressed: _busy ? null : _submit,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      key: const Key('first_name'),
                      label: 'First Name',
                      controller: _firstName,
                      floatingLabel: true,
                      enabled: !_busy,
                      hint: 'John',
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter your first name'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AppTextField(
                      key: const Key('last_name'),
                      label: 'Last Name',
                      controller: _lastName,
                      floatingLabel: true,
                      enabled: !_busy,
                      hint: 'Smith',
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter your last name'
                          : null,
                    ),
                  ),
                ],
              ),
              // The design puts a "Date of Birth" field here. Nothing in the
              // service stores one: signup takes email, password, full_name
              // and phone, and the onboarding PATCH takes only a licence
              // number and an address. A box that discards what the driver
              // types is worse than no box, so it is left out.
              const SizedBox(height: 26),
              AppTextField(
                key: const Key('email'),
                label: 'Email',
                controller: _email,
                floatingLabel: true,
                keyboardType: TextInputType.emailAddress,
                enabled: !_busy,
                // The design's mock shows a phone number in the email box.
                // Kept as an address, since that is what the field takes.
                hint: 'you@example.com',
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Enter your email';
                  // Deliberately loose: the confirmation email is the real
                  // check, and a clever pattern only ever rejects addresses
                  // that turn out to be valid.
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 26),
              AppTextField(
                key: const Key('phone'),
                label: 'Phone Number',
                controller: _phone,
                floatingLabel: true,
                keyboardType: TextInputType.phone,
                enabled: !_busy,
                hint: '+44 123 345 6789',
                validator: (v) => (v == null || v.trim().length < 7)
                    ? 'Enter your mobile number'
                    : null,
              ),
              const SizedBox(height: 26),
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
              if (_error != null) ...[
                const SizedBox(height: 20),
                Text(_error!,
                    style: AppText.body.copyWith(color: AppColors.negative)),
              ],
              if (_notice != null) ...[
                const SizedBox(height: 20),
                Text(_notice!, style: AppText.body),
              ],
              const SizedBox(height: 8),
              TextButton(
                key: const Key('go_to_sign_in'),
                onPressed: _busy ? null : () => context.go(Routes.signIn),
                child: const Text('I already have an account'),
              ),
            ],
          ),
        ),
      );
}
