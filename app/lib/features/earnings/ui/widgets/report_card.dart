import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/api/error_codes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/earnings_repository.dart';
import 'earnings_card.dart';

/// Download the per-trip earnings report over a chosen date range.
///
/// The design offers a Format dropdown defaulting to PDF. The service
/// produces CSV and rejects anything else with a 400, so the control is kept
/// in place — a driver still needs to see what they are about to get — but
/// it reads CSV and has nothing else to pick.
class ReportCard extends ConsumerStatefulWidget {
  const ReportCard({super.key});

  @override
  ConsumerState<ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends ConsumerState<ReportCard> {
  late DateTimeRange _range;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month, now.day),
    );
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      // The service refuses a range longer than 366 days, so the picker
      // cannot offer a start further back than that from today — a wider
      // window would only let the driver build a request guaranteed to
      // come back as a validation error.
      firstDate: now.subtract(const Duration(days: maxReportDays)),
      lastDate: now,
      initialDateRange: _range,
    );
    if (picked != null && mounted) setState(() => _range = picked);
  }

  /// The service's own cap on a report range.
  static const maxReportDays = 366;

  Future<void> _download() async {
    setState(() => _busy = true);
    final result = await ref
        .read(earningsRepositoryProvider)
        .report(from: _range.start, to: _range.end);
    if (!mounted) return;
    setState(() => _busy = false);

    final error = result.errorOrNull;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorCopy(error))));
      return;
    }

    // The endpoint needs the bearer token, so the file cannot be handed to
    // the browser as a URL — it is fetched here and re-offered as its own
    // bytes.
    final uri = Uri.parse(
        'data:text/csv;charset=utf-8;base64,${base64Encode(utf8.encode(result.valueOrNull ?? ''))}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the report.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final label =
        '${DateFormat('d MMM').format(_range.start)} - ${DateFormat('d MMM, yyyy').format(_range.end)}';

    return EarningsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const EarningsSectionTitle('Earnings Report'),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.info,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.description,
                    size: 24, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Earnings Report',
                        style: AppText.heading.copyWith(fontSize: 17)),
                    const SizedBox(height: 2),
                    Text('Every trip in the range, with its breakdown',
                        style: AppText.caption.copyWith(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // The design draws one row, but a fixed format box and a labelled
          // Download button leave a 360px phone ~50px for the date — the one
          // value the driver chose. LayoutBuilder keeps the single row where
          // it genuinely fits and stacks the date above the actions where it
          // does not, so nothing ellipsizes or overflows.
          LayoutBuilder(builder: (context, constraints) {
            final oneRow = constraints.maxWidth >= 340;
            final date = _field(
              label: 'Date',
              child: GestureDetector(
                onTap: _pickRange,
                child: _box(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body.copyWith(fontSize: 14)),
                ),
              ),
            );
            final actions = <Widget>[
              _field(
                label: 'Format',
                child: _box(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('CSV', style: AppText.body.copyWith(fontSize: 14)),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down,
                          size: 18, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 46,
                child: FilledButton(
                  onPressed: _busy ? null : _download,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.info,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.download, size: 20),
                            SizedBox(width: 6),
                            Text('Download',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                ),
              ),
            ];
            if (oneRow) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [Expanded(child: date), const SizedBox(width: 8), ...actions],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                date,
                const SizedBox(height: 10),
                Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: actions),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _field({required String label, required Widget child}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.caption.copyWith(fontSize: 12)),
          const SizedBox(height: 6),
          child,
        ],
      );

  Widget _box({required Widget child}) => Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );
}
