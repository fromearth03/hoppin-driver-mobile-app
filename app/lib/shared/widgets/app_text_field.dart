import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

/// A form field.
///
/// Two shapes, because the design uses two. The default stacks a small grey
/// label above the box, which is what the in-app forms use. [floatingLabel]
/// notches the label into the border and puts an icon inside — the shape the
/// signed-out screens use.
class AppTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool enabled;
  final String? hint;
  final TextCapitalization textCapitalization;

  /// Notches the label into the outline instead of stacking it above.
  final bool floatingLabel;

  /// Shown inside the field, before the text.
  final IconData? icon;

  /// Adds the eye toggle. Only meaningful with [obscure].
  final bool revealable;

  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.enabled = true,
    this.hint,
    this.textCapitalization = TextCapitalization.none,
    this.floatingLabel = false,
    this.icon,
    this.revealable = false,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;

  OutlineInputBorder _outline([Color color = AppColors.border, double w = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(widget.floatingLabel ? 16 : 12),
        borderSide: BorderSide(color: color, width: w),
      );

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      keyboardType: widget.keyboardType,
      textCapitalization: widget.textCapitalization,
      validator: widget.validator,
      enabled: widget.enabled,
      style: AppText.body,
      decoration: InputDecoration(
        hintText: widget.hint ?? (widget.floatingLabel ? widget.label : null),
        hintStyle: AppText.body.copyWith(color: AppColors.textDisabled),
        labelText: widget.floatingLabel ? widget.label : null,
        labelStyle: AppText.body.copyWith(color: AppColors.textPrimary),
        floatingLabelBehavior:
            widget.floatingLabel ? FloatingLabelBehavior.always : null,
        prefixIcon: widget.icon == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 18, right: 12),
                child: Icon(widget.icon, color: AppColors.textSecondary),
              ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: widget.revealable
            ? IconButton(
                icon: Icon(
                  _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : null,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: EdgeInsets.symmetric(
            horizontal: 16, vertical: widget.floatingLabel ? 22 : 14),
        border: _outline(),
        enabledBorder: _outline(),
        focusedBorder: _outline(AppColors.primary, 2),
      ),
    );

    if (widget.floatingLabel) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppText.caption),
        const SizedBox(height: 6),
        field,
      ],
    );
  }
}
