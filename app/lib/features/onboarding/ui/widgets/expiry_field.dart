import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';

/// A tappable date field for a document expiry.
///
/// Picks a date rather than parsing typed text: an expiry the driver mistypes
/// is one the compliance sweep silently reads as already lapsed.
class ExpiryField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final bool enabled;
  final ValueChanged<DateTime> onChanged;

  const ExpiryField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  static String format(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.caption),
          const SizedBox(height: 6),
          InkWell(
            onTap: enabled
                ? () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: value ?? now,
                      // An expiry already in the past keeps the driver
                      // non-compliant, so there is nothing useful to pick
                      // there.
                      firstDate: now,
                      lastDate: DateTime(now.year + 20),
                    );
                    if (picked != null) onChanged(picked);
                  }
                : null,
            child: InputDecorator(
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              child: Text(
                value == null ? 'Select a date' : format(value!),
                style: value == null ? AppText.bodySecondary : AppText.body,
              ),
            ),
          ),
        ],
      );
}
