import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../../audio/offer_chime.dart';

// This block renders only when DEMO_MODE is explicitly enabled at build time.
// Production builds must never pass --dart-define=DEMO_MODE=true.
const _demoModeEnabled = bool.fromEnvironment('DEMO_MODE', defaultValue: false);
const _demoEmail = String.fromEnvironment('DEMO_DRIVER_EMAIL', defaultValue: '');
const _demoPassword = String.fromEnvironment('DEMO_DRIVER_PASSWORD', defaultValue: '');

/// Driver sign-in — the petrol-navy lane's front door.
///
/// Drivers are provisioned by an admin and set their password from an emailed
/// invite — they can NOT self-register (docs/04 · Riders vs drivers), so this
/// screen deliberately has no sign-up. On success the router's
/// refreshListenable sees the auth event and redirects to the dashboard.
///
/// Surface language (05-05): canvas background, Geist display wordmark
/// lockup, themed r8/hairline inputs, HopButton CTAs, HopBanner states.
class DriverLoginScreen extends ConsumerStatefulWidget {
  const DriverLoginScreen({super.key});

  @override
  ConsumerState<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends ConsumerState<DriverLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _busy = false;
  bool _obscurePassword = true;
  bool _submitted = false;
  bool _prefilled = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    final prefill = ref.read(loginPrefillProvider);
    if (prefill != null) {
      _emailCtrl.text = prefill.email;
      _passwordCtrl.text = prefill.password;
      _prefilled = true;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // The Sign in tap is the session's first click — prime the offer chime
    // on it (Chrome gesture unlock, DRIVER-02). Fire-and-forget: OfferChime
    // swallows every error, so this can never block or fail the sign-in.
    unawaited(ref.read(offerChimeProvider).prime());
    setState(() {
      _submitted = true;
      _error = null;
      _notice = null;
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    try {
      final auth = ref.read(authServiceProvider);
      await auth.signInWithPassword(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
          );
      // Only drivers belong in the driver app. Any non-driver account (rider,
      // admin, or role-less) is signed straight back out with guidance — this
      // mirrors the backend driverOnly() gate. Strict by design: drivers are
      // always admin-provisioned with role='driver', so a missing role is NOT
      // a driver and must not be let in.
      if (auth.role != AppRole.driver) {
        await auth.signOut();
        if (mounted) {
          setState(() => _error =
              'This is not a driver account. Please use the Hoppin Rider app.');
        }
        return;
      }
      // Router redirect handles navigation via onAuthStateChange.
    } on Exception catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: hoppin.spacing.gutter,
              vertical: hoppin.spacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  autovalidateMode: _submitted
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The wordmark lockup: Hoppin in Geist display over a
                      // wide-tracked DRIVER lane label in the petrol accent.
                      Text(
                        'Hoppin',
                        textAlign: TextAlign.center,
                        style: hoppin.type.display.copyWith(
                          color: colors.textHi,
                        ),
                      ),
                      SizedBox(height: hoppin.spacing.xs),
                      Text(
                        'DRIVER',
                        textAlign: TextAlign.center,
                        style: hoppin.type.labelSmall.copyWith(
                          color: colors.accent,
                          letterSpacing: 4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: hoppin.spacing.md),
                      Text(
                        'Sign in to start driving',
                        textAlign: TextAlign.center,
                        style: hoppin.type.bodySmall.copyWith(
                          color: colors.textMid,
                        ),
                      ),
                      SizedBox(height: hoppin.spacing.xl),
                      if (_error != null) ...[
                        HopBanner.error(message: _error!),
                        SizedBox(height: hoppin.spacing.lg),
                      ],
                      if (_notice != null) ...[
                        HopBanner.notice(message: _notice!),
                        SizedBox(height: hoppin.spacing.lg),
                      ],
                      TextFormField(
                        controller: _emailCtrl,
                        enabled: !_busy,
                        validator: validateEmail,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                      ),
                      SizedBox(height: hoppin.spacing.lg),
                      TextFormField(
                        controller: _passwordCtrl,
                        enabled: !_busy,
                        validator: (v) => validatePassword(v),
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: colors.textMid,
                            ),
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                          ),
                        ),
                      ),
                      SizedBox(height: hoppin.spacing.gutter),
                      HopButton.primary(
                        label: 'Sign in',
                        busy: _busy,
                        onPressed: _submit,
                      ),
                      if (_demoModeEnabled && _demoEmail.isNotEmpty) ...[
                        SizedBox(height: hoppin.spacing.sm),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () {
                                  _emailCtrl.text = _demoEmail;
                                  _passwordCtrl.text = _demoPassword;
                                  setState(() {});
                                },
                          style: TextButton.styleFrom(
                            foregroundColor: colors.textMid,
                            textStyle: hoppin.type.labelSmall,
                          ),
                          child: const Text('Auto-fill (demo)'),
                        ),
                      ],
                      if (_prefilled) ...[
                        SizedBox(height: hoppin.spacing.md),
                        // Demo seam (DEMO-05): quiet, production-invisible —
                        // renders only when a prefill override seeded the form.
                        Text(
                          'Demo credentials pre-filled — just tap Sign in.',
                          textAlign: TextAlign.center,
                          style: hoppin.type.labelSmall.copyWith(
                            color: colors.textMid,
                          ),
                        ),
                      ],
                      SizedBox(height: hoppin.spacing.md),
                      HopButton.ghost(
                        label: 'Forgot password?',
                        // 🔴 Routes to the #49 GATED landing rather than
                        // sending an email straight away. The reset redirect
                        // lands on a URL with no page behind it, so an email
                        // sent from here delivers a link that dead-ends. The
                        // landing says so honestly and offers the route that
                        // actually works — support, where a human can reset it.
                        onPressed: _busy ? null : () => context.go('/reset'),
                      ),
                      SizedBox(height: hoppin.spacing.gutter),
                      // Drivers can't self-register — set expectations here.
                      const HopBanner.notice(
                        message: 'Driver accounts are created by the '
                            'Hoppin team. New driver? Use the emailed '
                            'invite to set your password, then sign in '
                            'here.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
