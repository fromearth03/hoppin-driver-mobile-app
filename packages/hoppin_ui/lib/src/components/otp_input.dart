import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/context_extension.dart';

/// The verification-code entry field (Figma: Verification Code).
///
/// A row of [length] rounded-square boxes (radius `radii.control`, 1px navy
/// border — lighter when empty), each holding a single digit in Poppins ~28
/// navy. `onChanged` reports the assembled code as digits are typed; entering
/// a digit advances focus, deleting an empty box retreats.
class OtpInput extends StatefulWidget {
  /// Creates an OTP input.
  const OtpInput({required this.onChanged, this.length = 5, super.key});

  /// Fired with the assembled code whenever any box changes.
  final ValueChanged<String> onChanged;

  /// Number of digit boxes — 5 per the Figma spec.
  final int length;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _nodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.length,
      (_) => TextEditingController(),
    );
    _nodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _handleChanged(int index, String value) {
    if (value.isNotEmpty && index < widget.length - 1) {
      _nodes[index + 1].requestFocus();
    }
    widget.onChanged(_controllers.map((c) => c.text).join());
  }

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < widget.length; i++) ...[
          _box(context, i),
          if (i < widget.length - 1) SizedBox(width: hoppin.spacing.sm),
        ],
      ],
    );
  }

  Widget _box(BuildContext context, int index) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final filled = _controllers[index].text.isNotEmpty;
    return SizedBox(
      width: 52,
      height: 60,
      child: TextField(
        controller: _controllers[index],
        focusNode: _nodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        showCursor: true,
        style: hoppin.type.h1.copyWith(
          color: colors.textHi,
          fontSize: 28,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: colors.card,
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(hoppin.radii.control),
            borderSide: BorderSide(
              color: filled
                  ? colors.accent
                  : colors.accent.withValues(alpha: 0.3),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(hoppin.radii.control),
            borderSide: BorderSide(color: colors.accent, width: 1.5),
          ),
        ),
        onChanged: (v) => _handleChanged(index, v),
      ),
    );
  }
}
