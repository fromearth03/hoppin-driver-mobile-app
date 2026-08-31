import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/driver_stats.dart';

/// The design's header card: a calendar glyph, the window's name, the dates
/// it covers, and a chevron that opens the picker.
///
/// The dates are the service's own `from`/`to` — it resolves the window in
/// the driver's timezone and owns where a week starts, so computing a range
/// here could disagree with the figures shown underneath. Until the first
/// response arrives there is no range to print, and the line is left out
/// rather than filled with a guess.
class PeriodCard extends StatelessWidget {
  final StatsPeriod period;
  final DateTime? from;
  final DateTime? to;
  final ValueChanged<StatsPeriod> onChanged;

  const PeriodCard({
    super.key,
    required this.period,
    required this.onChanged,
    this.from,
    this.to,
  });

  String? get _range {
    if (from == null || to == null) return null;
    final f = from!.toLocal();
    final t = to!.toLocal();
    final day = DateFormat('d MMM');
    return f.year == t.year
        ? '${day.format(f)} - ${day.format(t)}, ${t.year}'
        : '${DateFormat('d MMM y').format(f)} - ${DateFormat('d MMM y').format(t)}';
  }

  Future<void> _pick(BuildContext context) async {
    final chosen = await showModalBottomSheet<StatsPeriod>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            for (final option in StatsPeriod.values)
              ListTile(
                title: Text(option.label, style: AppText.body),
                trailing: option == period
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.of(sheet).pop(option),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen != null) onChanged(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final range = _range;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _pick(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.calendar_month_outlined,
                  size: 30, color: AppColors.textPrimary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(period.label, style: AppText.title.copyWith(fontSize: 20)),
                    if (range != null) ...[
                      const SizedBox(height: 1),
                      Text(range, style: AppText.bodySecondary),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down,
                  color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
