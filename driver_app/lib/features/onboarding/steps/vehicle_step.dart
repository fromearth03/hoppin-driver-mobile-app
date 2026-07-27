import 'package:flutter/material.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../widgets/vehicle_registration_unavailable.dart';

/// Registration3, re-purposed — **Vehicle**. Seam **#82**.
///
/// 🔴 **THIS STEP COLLECTS NOTHING AND POSTS NOTHING, AND BOTH HALVES OF THAT
/// ARE LOAD-BEARING.**
///
/// The Figma asks for a registration plate, a make and model, an insurance
/// provider and an insurance expiry. Nothing on the backend accepts them
/// (`vehicle_registration_unavailable.dart` has the full reasoning). So:
///
/// **There is no `TextField` and no `TextFormField` on this step — and not a
/// DISABLED one either.** A greyed-out box labelled "Vehicle Reg" still tells
/// the driver *"this is where your registration plate goes, and one day it will
/// be saved"*. It will not be saved. There is nothing to save it to. What is
/// shown instead is a set of **non-interactive labelled placeholders** inside
/// the rung's frame, which reads as *"this is what we'll ask for when we can"*
/// and never as *"type here"*.
///
/// **This step fires zero network calls.** `vehicle_step_zero_calls_test.dart`
/// replaces every repository AND the `ApiClient` beneath them with fakes that
/// fail the test on any method call whatsoever, then types into every field and
/// taps every button. Zero invocations permitted.
///
/// The STRUCTURE survives — the section headers, the field rhythm, the two-up
/// pairs — so that the day `POST /drivers/me/vehicle` lands, the real inputs
/// drop straight into a layout the driver already recognises.
class VehicleStep extends StatelessWidget {
  /// Creates the vehicle step.
  const VehicleStep({
    required this.onBack,
    required this.onContinue,
    this.onContactSupport,
    super.key,
  });

  /// Back to the licence step. A pure local state transition.
  final VoidCallback onBack;

  /// Forward to the attachments step. A pure local state transition — it saves
  /// nothing, because there is nothing to save it to.
  final VoidCallback onContinue;

  /// Route to support, from the rung.
  final VoidCallback? onContactSupport;

  /// The four things Registration3 asks for, and the shape of the answers. Shown
  /// as READ-ONLY placeholders — the driver types into none of them.
  static const _fields = <({String label, String example})>[
    (label: 'Vehicle reg', example: 'WH12 ABC'),
    (label: 'Vehicle model', example: 'Toyota Prius'),
    (label: 'Vehicle insurance', example: 'Provider & policy number'),
    (label: 'Insurance expiry', example: 'dd / mm / yyyy'),
  ];

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 🔴 CONSTRUCTED UNCONDITIONALLY. Not behind an `if (vehicle == null)`:
        // there is no endpoint, so there is no state of the world in which this
        // step has real data. The seam is always-null.
        VehicleRegistrationUnavailable(onContactSupport: onContactSupport),
        SizedBox(height: hoppin.spacing.gutter),
        Text(
          "What we'll ask for when this is switched on",
          style: hoppin.type.metaSmall.copyWith(color: colors.textMid),
        ),
        SizedBox(height: hoppin.spacing.md),
        // The Registration3 rhythm, in two-up pairs — preserved as structure so
        // the wizard reads as designed and the real inputs land cleanly later.
        for (var i = 0; i < _fields.length; i += 2) ...[
          if (i > 0) SizedBox(height: hoppin.spacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _FieldPreview(field: _fields[i])),
              SizedBox(width: hoppin.spacing.lg),
              Expanded(
                child: i + 1 < _fields.length
                    ? _FieldPreview(field: _fields[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
        SizedBox(height: hoppin.spacing.xl),
        Row(
          children: [
            Expanded(
              child: HopButton.secondary(label: 'Back', onPressed: onBack),
            ),
            SizedBox(width: hoppin.spacing.lg),
            Expanded(
              child: HopButton.primary(
                label: 'Continue',
                onPressed: onContinue,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A labelled, NON-INTERACTIVE placeholder in the shape of the field that will
/// one day live here.
///
/// 🔴 Deliberately NOT a disabled `TextField`. A disabled input is still an
/// input: it has a cursor position, it has a "type here" affordance, and it
/// promises that enabling it would save something. This is a dashed outline with
/// a label and an example — it describes a future question, and it cannot be
/// mistaken for a box that is taking an answer.
class _FieldPreview extends StatelessWidget {
  const _FieldPreview({required this.field});

  final ({String label, String example}) field;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.label,
          style: hoppin.type.metaSmall.copyWith(color: colors.textMid),
        ),
        SizedBox(height: hoppin.spacing.xs),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: hoppin.spacing.md,
            vertical: hoppin.spacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(hoppin.radii.control),
            border: Border.all(color: colors.hairline),
          ),
          child: Text(
            field.example,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: hoppin.type.meta.copyWith(color: colors.textMid),
          ),
        ),
      ],
    );
  }
}
