import 'package:flutter/material.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// The driver's one-tap quick replies — and the ONLY send path that survives
/// 5 mph.
///
/// 🔴 THESE STAY LIVE IN MOTION. DELIBERATELY. A cradled phone is legal to
/// touch — that is how every Uber and Bolt driver taps Accept at the wheel —
/// and a one-tap chip is a glance, not a distraction. What we remove at speed
/// is the KEYBOARD, because typing demands sustained attention and that is
/// where "driving without due care" actually lives.
///
/// Suppressing these too would leave the driver MUTE at exactly the moment
/// they most need to say "two minutes away" — and they would pick up their
/// phone and text on WhatsApp instead, which is the HANDHELD offence we were
/// trying to avoid in the first place. The safe app is the one that lets them
/// say it in one tap without leaving the cradle.
///
/// The driver's set — written for the driver's half of the conversation, not
/// the rider's.
class DriverChatTemplates extends StatelessWidget {
  /// Creates the driver's quick-reply chip row.
  const DriverChatTemplates({required this.onSend, super.key});

  /// The driver's quick replies, written for the driver's half of the
  /// conversation. Read at a junction, so each is one short line.
  static const List<String> templates = <String>[
    "I'm on my way",
    "I'm outside",
    "I've arrived",
    "I'm waiting outside — can't see you",
    'Running a few minutes late',
  ];

  /// Fired with the tapped chip's body, verbatim. The host wires this to the
  /// SAME `send` path the composer uses — never a separate endpoint, never a
  /// prefill.
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    final spacing = context.hoppin.spacing;

    return SizedBox(
      height: 44 + spacing.sm * 2,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: spacing.md,
          vertical: spacing.sm,
        ),
        itemCount: templates.length,
        separatorBuilder: (_, _) => SizedBox(width: spacing.sm),
        itemBuilder: (context, i) {
          final body = templates[i];
          return _TemplateChip(label: body, onTap: () => onSend(body));
        },
      ),
    );
  }
}

class _TemplateChip extends StatelessWidget {
  const _TemplateChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final radius = BorderRadius.circular(hoppin.radii.pill);

    return Material(
      color: colors.card,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            horizontal: hoppin.spacing.lg,
            vertical: hoppin.spacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: radius,
            // High contrast — legible in under a second at arm's length (SF-02).
            border: Border.all(color: colors.hairline),
          ),
          child: Text(
            label,
            style: hoppin.type.label.copyWith(color: colors.textHi),
          ),
        ),
      ),
    );
  }
}
