import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// Stable widget keys the reset landing exposes for tests.
abstract final class DriverResetKeys {
  /// The BOUND exit — a human can reset the password today.
  static const contactSupport = ValueKey('driver-reset-contact-support');

  /// For the driver who still knows their current password.
  static const backToSignIn = ValueKey('driver-reset-back-to-sign-in');
}

/// The #49 GATED state. 🔴 NEVER A FAKE PASSWORD FORM.
///
/// The Supabase reset redirect lands on a URL with **no page behind it**. So a
/// "New Password" form on this path would take a driver's new password and
/// post it **nowhere**. They would see a tick, close the app, and be locked out
/// of their livelihood tomorrow morning — and they would not know why.
///
/// So there is no form. There is an honest, designed state that says the reset
/// link is not yet working, and it offers **two real exits**: contact support
/// (BOUND — a human can reset it), and back to sign-in.
///
/// The Figma's `New Password.jpg` frame is exactly the form we are refusing to
/// draw.
///
/// 🔴 This route must be reachable while **SIGNED OUT** — a driver clicking a
/// reset link is by definition not signed in. `router.dart` allowlists it in
/// the redirect for exactly that reason. Without the allowance the honest
/// gated state is never seen, and the driver is bounced to the very login they
/// cannot get past.
///
/// Body-swaps to the real reset entry point with zero view changes when #49
/// lands (the Supabase redirect config).
class DriverResetLandingScreen extends StatelessWidget {
  /// Creates the #49 gated password-reset landing.
  const DriverResetLandingScreen({super.key});

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Names the situation honestly. No form, no field, nothing
                  // that could take a password.
                  const HopEmptyState(
                    headline: "This reset link isn't active yet",
                    supporting:
                        "Setting a new password from an email link isn't "
                        'switched on yet. Nothing you type here could reach '
                        'us, so we are not going to ask you to type it. If '
                        "you're locked out, support can reset your password "
                        'today — usually the same working day.',
                  ),
                  SizedBox(height: hoppin.spacing.lg),

                  // 🔴 The exits. A disclosure that STRANDS the driver is only
                  // half-honest, and this driver may be unable to work until
                  // they are back in.
                  HopButton.primary(
                    key: DriverResetKeys.contactSupport,
                    label: 'Contact support',
                    onPressed: () => context.go('/support'),
                  ),
                  SizedBox(height: hoppin.spacing.sm),
                  HopButton.ghost(
                    key: DriverResetKeys.backToSignIn,
                    label: 'Back to sign in',
                    onPressed: () => context.go('/login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
