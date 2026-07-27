import 'package:flutter/material.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// The DRIVER-ONLY incoming-call frame — `Home - Active trip (incoming call)`.
///
/// 🔴 The rider surface has NO incoming frame: a rider is never called BY a
/// driver in this product. The Figma ships this one for the driver, and it needs
/// ANSWER and DECLINE controls the rider frames do not have — both INERT, both
/// driven by the never-dial fake.
///
/// It renders the two large call-affordance buttons at Figma fidelity and
/// disables both. Answer to a real number is the single most tempting — and most
/// dangerous — control in the product, so it is the one most deliberately dead.
class IncomingCallFrame extends StatelessWidget {
  /// Creates the incoming-call control pair (answer / decline), both inert.
  const IncomingCallFrame({super.key});

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    return Row(
      key: const Key('call.incoming.controls'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _IncomingAction(
          controlKey: Key('call.action.decline'),
          icon: Icons.call_end,
          tooltip: 'Decline (unavailable — no call is incoming)',
          destructive: true,
        ),
        SizedBox(width: hoppin.spacing.xl),
        const _IncomingAction(
          controlKey: Key('call.action.answer'),
          icon: Icons.call,
          tooltip: 'Answer (unavailable — masked calling is not live)',
        ),
      ],
    );
  }
}

/// One inert incoming-call affordance. `onTap` is deliberately absent: there is
/// no call to answer and no call to decline, and a live-looking control that
/// silently does nothing is the exact dead-end the no-holes rule forbids.
class _IncomingAction extends StatelessWidget {
  const _IncomingAction({
    required this.controlKey,
    required this.icon,
    required this.tooltip,
    this.destructive = false,
  });

  final Key controlKey;
  final IconData icon;
  final String tooltip;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final onNavy = hoppin.colors.onAccent;
    final fill = destructive
        ? hoppin.colors.error.withValues(alpha: 0.45)
        : hoppin.colors.success.withValues(alpha: 0.45);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: false,
        label: tooltip,
        child: Container(
          key: controlKey,
          width: 72,
          height: 72,
          decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
          child: Icon(icon, size: 30, color: onNavy.withValues(alpha: 0.55)),
        ),
      ),
    );
  }
}
