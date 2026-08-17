import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// Stable widget keys the reset landing exposes for tests.
abstract final class DriverResetKeys {
  static const backToSignIn = ValueKey('driver-reset-back-to-sign-in');
}

/// Password-reset / invite landing. The emailed Supabase link opens `/reset`
/// with a temporary recovery session; this form writes the new password onto
/// it. No contact-support dead end — if the link is stale, request a new one
/// from sign-in.
class DriverResetLandingScreen extends ConsumerStatefulWidget {
  const DriverResetLandingScreen({super.key});

  @override
  ConsumerState<DriverResetLandingScreen> createState() =>
      _DriverResetLandingScreenState();
}

class _DriverResetLandingScreenState
    extends ConsumerState<DriverResetLandingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final auth = ref.read(authServiceProvider);
      await hoppinEstablishResetSession(alreadySignedIn: auth.isSignedIn);
      await auth.updatePassword(_passwordCtrl.text);
      hoppinMarkResetConsumed(passwordUpdated: true);
      if (!mounted) return;
      context.go(auth.isSignedIn ? '/' : '/login');
    } on Object catch (e) {
      if (hoppinPasswordAlreadySet(e)) {
        hoppinMarkResetConsumed(passwordUpdated: true);
        if (!mounted) return;
        final auth = ref.read(authServiceProvider);
        context.go(auth.isSignedIn ? '/' : '/login');
        return;
      }
      if (mounted) setState(() => _error = hoppinResetErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final type = hoppin.type;
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
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Set a new password',
                        textAlign: TextAlign.center, style: type.headline),
                    SizedBox(height: hoppin.spacing.sm),
                    Text(
                      'Choose a new password for your Hoppin driver account.',
                      textAlign: TextAlign.center,
                      style: type.body.copyWith(color: colors.textMid),
                    ),
                    SizedBox(height: hoppin.spacing.xl),
                    if (_error != null) ...[
                      HopBanner.error(message: _error!),
                      SizedBox(height: hoppin.spacing.md),
                    ],
                    TextFormField(
                      controller: _passwordCtrl,
                      enabled: !_busy,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.length < 8)
                          ? 'At least 8 characters'
                          : null,
                      decoration: InputDecoration(
                        labelText: 'New password',
                        helperText: 'At least 8 characters',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmCtrl,
                      enabled: !_busy,
                      obscureText: _obscureConfirm,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) => (v != _passwordCtrl.text)
                          ? 'Passwords do not match'
                          : null,
                      decoration: InputDecoration(
                        labelText: 'Confirm new password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                          icon: Icon(_obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          tooltip: _obscureConfirm
                              ? 'Show password'
                              : 'Hide password',
                        ),
                      ),
                    ),
                    SizedBox(height: hoppin.spacing.gutter),
                    HopButton.primary(
                      label: 'Set new password',
                      onPressed: _busy ? null : _submit,
                      busy: _busy,
                    ),
                    SizedBox(height: hoppin.spacing.sm),
                    HopButton.ghost(
                      key: DriverResetKeys.backToSignIn,
                      label: 'Back to sign in',
                      onPressed: _busy
                          ? null
                          : () {
                              hoppinMarkResetConsumed();
                              context.go('/login');
                            },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
