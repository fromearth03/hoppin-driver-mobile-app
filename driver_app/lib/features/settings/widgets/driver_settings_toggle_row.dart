import 'package:flutter/material.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// One labelled switch row on the Settings screen.
///
/// 🔴 [onChanged] is NULLABLE and defaults to null, and that default is the
/// point. Almost every switch on the driver's Settings screen has no endpoint
/// behind it, and the honest form of "this does nothing" is a switch the driver
/// can SEE is off — never `onChanged: (_) {}`, which gives a full interactive
/// response over silence and is indistinguishable from a working control.
class DriverSettingsToggleRow extends StatelessWidget {
  /// Creates a settings toggle row. Inert unless [onChanged] is supplied.
  const DriverSettingsToggleRow({
    required this.label,
    required this.value,
    this.supporting,
    this.onChanged,
    this.divider = false,
    super.key,
  });

  /// The control's label.
  final String label;

  /// The switch position.
  final bool value;

  /// Optional second line under the label.
  final String? supporting;

  /// The live callback — **null means genuinely inert**, which is the honest
  /// state for every preference with no endpoint behind it.
  final ValueChanged<bool>? onChanged;

  /// When true, draws a hairline divider beneath the row.
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final live = onChanged != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: hoppin.spacing.lg,
            vertical: hoppin.spacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: hoppin.type.bodyMedium.copyWith(
                        // A dimmed label is half the disclosure: the driver can
                        // see at a glance which rows are live.
                        color: live ? colors.textHi : colors.textMid,
                      ),
                    ),
                    if (supporting != null) ...[
                      SizedBox(height: hoppin.spacing.xs),
                      Text(
                        supporting!,
                        style:
                            hoppin.type.meta.copyWith(color: colors.textMid),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: hoppin.spacing.md),
              // Themed off the design tokens rather than left on Material's
              // defaults, which resolve from the ambient ColorScheme and do not
              // belong to this palette: on the light theme the default track
              // renders near-white on the card it sits on, so an ON switch was
              // barely distinguishable from an OFF one at a glance.
              //
              // The INERT state matters most here. `onChanged == null` is the
              // honest "no endpoint behind this" state (see the class note), so
              // it must read as unmistakably disabled rather than merely off —
              // hairline track, textMid thumb, no accent anywhere.
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: colors.onAccent,
                activeTrackColor: colors.accent,
                inactiveThumbColor: live ? colors.textMid : colors.hairline,
                inactiveTrackColor: colors.card,
                trackOutlineColor:
                    WidgetStatePropertyAll<Color>(colors.hairline),
              ),
            ],
          ),
        ),
        if (divider) Divider(height: 1, color: colors.hairline),
      ],
    );
  }
}
