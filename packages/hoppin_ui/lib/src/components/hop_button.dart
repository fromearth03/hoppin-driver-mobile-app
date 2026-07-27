import 'package:flutter/material.dart';

import '../theme/context_extension.dart';

enum _HopButtonVariant { primary, secondary, green, red, dangerOutline, ghost }

/// The Hoppin brand button — the thumb-sized CTA of the Figma surface
/// language.
///
/// Built on raw [Material] + [InkWell] (not `FilledButton`) for exact
/// control: height 52, radius `radii.control` (12), zero elevation ever,
/// pressed state as a 6% overlay tint. Every colour resolves through
/// `context.hoppin` — nothing hardcoded.
///
/// Figma variants:
/// - [HopButton.primary] — solid navy fill, onAccent (white) label.
/// - [HopButton.secondary] — white fill, 1px navy border, navy label.
/// - [HopButton.green] — solid success fill, white label (Call).
/// - [HopButton.red] — solid error fill, white label (Cancel).
/// - [HopButton.dangerOutline] — white fill, red border, red label (SOS).
/// - [HopButton.ghost] — borderless accent-text button (tertiary actions).
class HopButton extends StatelessWidget {
  /// Solid navy fill with a white label — the primary CTA.
  const HopButton.primary({
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = true,
    super.key,
  }) : _variant = _HopButtonVariant.primary;

  /// White fill, 1px navy border, navy label — the quiet alternative.
  const HopButton.secondary({
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = true,
    super.key,
  }) : _variant = _HopButtonVariant.secondary;

  /// Solid success fill, white label — positive semantic action (Call).
  const HopButton.green({
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = true,
    super.key,
  }) : _variant = _HopButtonVariant.green;

  /// Solid error fill, white label — destructive semantic action (Cancel).
  const HopButton.red({
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = true,
    super.key,
  }) : _variant = _HopButtonVariant.red;

  /// White fill, red border, red label — the alarming outline (Emergency SOS).
  const HopButton.dangerOutline({
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = true,
    super.key,
  }) : _variant = _HopButtonVariant.dangerOutline;

  /// Borderless accent-text button — tertiary actions and sheet triggers.
  const HopButton.ghost({
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = true,
    super.key,
  }) : _variant = _HopButtonVariant.ghost;

  /// Button label, set in the Poppins button style.
  final String label;

  /// Tap handler. `null` renders the disabled state at 45% alpha.
  final VoidCallback? onPressed;

  /// Optional leading icon.
  final IconData? icon;

  /// Busy state: a spinner replaces the label and taps are swallowed.
  final bool busy;

  /// Full-width by default; `false` hugs the content.
  final bool expand;

  final _HopButtonVariant _variant;

  static const double _height = 52;
  static const double _disabledAlpha = 0.45;
  static const double _pressedTintAlpha = 0.06;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final disabled = onPressed == null;

    var background = switch (_variant) {
      _HopButtonVariant.primary => colors.accent,
      _HopButtonVariant.green => colors.success,
      _HopButtonVariant.red => colors.error,
      _HopButtonVariant.secondary || _HopButtonVariant.dangerOutline =>
        colors.card,
      _HopButtonVariant.ghost => Colors.transparent,
    };
    var foreground = switch (_variant) {
      _HopButtonVariant.primary ||
      _HopButtonVariant.green ||
      _HopButtonVariant.red =>
        colors.onAccent,
      _HopButtonVariant.secondary => colors.accent,
      _HopButtonVariant.dangerOutline => colors.error,
      _HopButtonVariant.ghost => colors.accent,
    };
    var side = switch (_variant) {
      _HopButtonVariant.secondary => BorderSide(color: colors.accent),
      _HopButtonVariant.dangerOutline => BorderSide(color: colors.error),
      _ => BorderSide.none,
    };
    if (disabled) {
      background = background.withValues(alpha: background.a * _disabledAlpha);
      foreground = foreground.withValues(alpha: _disabledAlpha);
      if (side != BorderSide.none) {
        side = side.copyWith(
          color: side.color.withValues(alpha: _disabledAlpha),
        );
      }
    }

    final radius = BorderRadius.circular(hoppin.radii.control);
    final shape = RoundedRectangleBorder(borderRadius: radius, side: side);
    final labelStyle = hoppin.type.button.copyWith(color: foreground);

    final children = busy
        ? <Widget>[
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foreground,
              ),
            ),
          ]
        : <Widget>[
            if (icon != null) ...[
              Icon(icon, size: 20, color: foreground),
              SizedBox(width: hoppin.spacing.sm),
            ],
            // 🔴 THE LABEL MUST BE ABLE TO SHRINK.
            //
            // This was a bare Text in a centred, non-shrinking Row. A button in
            // a narrow slot — three Expanded thirds on a 320pt phone, a chip in
            // a card gutter — asks the Row for more width than it is given, and
            // Flutter answers with a RenderFlex overflow stripe across the
            // control. Both apps' polish passes traced most of their overflow
            // findings back to this one line.
            //
            // Flexible + ellipsis makes the label yield instead: the button
            // still renders, still reads, still takes the tap. Truncated text
            // is a design problem; a black-and-yellow stripe over the primary
            // action is a broken screen.
            Flexible(
              child: Text(
                label,
                style: labelStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ];

    return Semantics(
      button: true,
      enabled: !disabled && !busy,
      child: SizedBox(
        height: _height,
        width: expand ? double.infinity : null,
        child: Material(
          color: background,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: disabled || busy ? null : onPressed,
            customBorder: shape,
            overlayColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.pressed)
                  ? foreground.withValues(alpha: _pressedTintAlpha)
                  : null,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hoppin.spacing.lg),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
