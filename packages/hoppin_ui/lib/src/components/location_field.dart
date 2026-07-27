import 'package:flutter/material.dart';

import '../theme/context_extension.dart';

/// The From/To pickup-dropoff field (Figma: Book Ride).
///
/// One white card (`radii.control`). A From row (navy ring bullet) and a To
/// row (red ring bullet) joined by a vertical dashed hairline connector. Each
/// row is a label over its value with a trailing edit affordance; tapping a
/// row fires its edit callback.
class LocationField extends StatelessWidget {
  /// Creates a From/To location field.
  const LocationField({
    required this.fromLabel,
    required this.fromValue,
    required this.toLabel,
    required this.toValue,
    this.onEditFrom,
    this.onEditTo,
    super.key,
  });

  /// "From" caption.
  final String fromLabel;

  /// Pickup value text.
  final String fromValue;

  /// "To" caption.
  final String toLabel;

  /// Dropoff value text.
  final String toValue;

  /// Fired when the From row is tapped.
  final VoidCallback? onEditFrom;

  /// Fired when the To row is tapped.
  final VoidCallback? onEditTo;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    return Material(
      color: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(hoppin.radii.control),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: hoppin.spacing.lg,
          vertical: hoppin.spacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _row(
              context,
              ringColor: colors.accent,
              label: fromLabel,
              value: fromValue,
              onTap: onEditFrom,
            ),
            _connector(context),
            _row(
              context,
              ringColor: colors.error,
              label: toLabel,
              value: toValue,
              onTap: onEditTo,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required Color ringColor,
    required String label,
    required String value,
    required VoidCallback? onTap,
  }) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: hoppin.spacing.xs),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ringColor, width: 3),
              ),
            ),
            SizedBox(width: hoppin.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: hoppin.type.meta.copyWith(color: colors.textMid),
                  ),
                  Text(
                    value,
                    style:
                        hoppin.type.bodyLarge.copyWith(color: colors.textHi),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.edit_outlined, size: 18, color: colors.textMid),
          ],
        ),
      ),
    );
  }

  /// The vertical dashed hairline joining the two rings.
  Widget _connector(BuildContext context) {
    final colors = context.hoppin.colors;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: SizedBox(
        height: 16,
        width: 2,
        child: CustomPaint(painter: _DashedLinePainter(colors.hairline)),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const dash = 3.0;
    const gap = 3.0;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, y + dash), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
