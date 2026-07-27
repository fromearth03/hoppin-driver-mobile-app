import 'package:flutter/material.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// Registration2, re-purposed — **Licences & Certificates**.
///
/// 🔴 **THE FIGMA ASKS FOR SIXTEEN THINGS HERE THAT THE BACKEND DOES NOT WANT.**
/// Registration2 draws eight licence NUMBERS (National ID, National Insurance,
/// Badge, DBS, Driver Licence, Digital Tachograph, CPC, Medical Card) each with
/// an EXPIRY DATE beside it. Then Registration4 — the very next frame — asks the
/// driver to UPLOAD those same eight things as documents.
///
/// Only the second one is real. `POST /drivers/me/documents/upload-url` +
/// `POST /drivers/me/documents` take a **file**, its **type** and an optional
/// **expiry**. There is no endpoint that takes a licence NUMBER, and there never
/// was: a number typed into a box on Registration2 has nowhere to go.
///
/// Building those sixteen fields would mean asking a driver to key in their DBS
/// certificate number and their tachograph card number and their National
/// Insurance number — sixteen fields of careful, tedious, error-prone data
/// entry, every character of which the app would then throw away. And because
/// the step would tick over to "Vehicle" afterwards, they would have every
/// reason to think it had landed.
///
/// So this step does not collect anything. It explains that the licences are
/// captured as documents — which is TRUE, and which WORKS TODAY — and sends the
/// driver to the surface that actually does it.
class LicenceStep extends StatelessWidget {
  /// Creates the licence step.
  const LicenceStep({
    required this.onBack,
    required this.onContinue,
    required this.onOpenDocuments,
    super.key,
  });

  /// Back to the personal step.
  final VoidCallback onBack;

  /// Forward to the vehicle step.
  final VoidCallback onContinue;

  /// Out to `/documents` — where licences are really captured.
  final VoidCallback onOpenDocuments;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'We capture your licences as photos or PDFs of the documents '
          'themselves — not as typed-in numbers. It saves you keying in a dozen '
          'reference numbers, and our team can check the real thing.',
          style: hoppin.type.meta.copyWith(color: colors.textMid),
        ),
        SizedBox(height: hoppin.spacing.gutter),
        HopCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your driving licence',
                style: hoppin.type.bodyMedium.copyWith(color: colors.textHi),
              ),
              SizedBox(height: hoppin.spacing.sm),
              Text(
                'Upload a clear photo of your DVLA licence, along with your '
                'badge, DBS and the rest of your certificates. You can add its '
                'expiry date as you upload it.',
                style: hoppin.type.meta.copyWith(color: colors.textMid),
              ),
              SizedBox(height: hoppin.spacing.lg),
              HopButton.secondary(
                label: 'Upload your licence',
                onPressed: onOpenDocuments,
              ),
            ],
          ),
        ),
        SizedBox(height: hoppin.spacing.xl),
        _StepNav(onBack: onBack, onContinue: onContinue),
      ],
    );
  }
}

/// Previous / Next, as the Figma places them.
class _StepNav extends StatelessWidget {
  const _StepNav({required this.onBack, required this.onContinue});

  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    return Row(
      children: [
        Expanded(
          child: HopButton.secondary(label: 'Back', onPressed: onBack),
        ),
        SizedBox(width: hoppin.spacing.lg),
        Expanded(
          child: HopButton.primary(label: 'Continue', onPressed: onContinue),
        ),
      ],
    );
  }
}
