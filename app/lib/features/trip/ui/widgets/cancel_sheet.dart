import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../data/cancel_reason_repository.dart';
import '../../data/models/cancel_reason.dart';

/// Reason picker, then a confirmation for any reason that carries a charge.
///
/// Returns the chosen reason id, or null if the driver backed out. Only
/// `pickable` reasons ever reach here, so no slug is displayed and none is
/// prettified client-side.
class CancelSheet extends ConsumerStatefulWidget {
  const CancelSheet({super.key});

  static Future<String?> show(BuildContext context) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const CancelSheet(),
      );

  @override
  ConsumerState<CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends ConsumerState<CancelSheet> {
  CancelReason? _selected;
  late final Future<List<CancelReason>> _reasons;

  @override
  void initState() {
    super.initState();
    _reasons = ref
        .read(cancelReasonRepositoryProvider)
        .forDriver()
        .then((r) => r.valueOrNull ?? const []);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _selected == null ? _picker() : _confirm(_selected!),
        ),
      );

  Widget _picker() => FutureBuilder<List<CancelReason>>(
        future: _reasons,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(height: 160, child: AppLoading());
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Why are you cancelling?', style: AppText.title),
              const SizedBox(height: 12),
              ...snapshot.data!.map((r) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(r.text, style: AppText.body),
                    subtitle: r.hasPenalty
                        ? Text('${r.penaltyFee!.format()} charge may apply',
                            style: AppText.caption
                                .copyWith(color: AppColors.negative))
                        : null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => setState(() => _selected = r),
                  )),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Keep the ride'),
              ),
            ],
          );
        },
      );

  Widget _confirm(CancelReason reason) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cancel this ride?', style: AppText.title),
          const SizedBox(height: 8),
          Text(reason.text, style: AppText.bodySecondary),
          if (reason.hasPenalty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.negative.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              // The exact amount, before the driver commits — this is the
              // moment they are agreeing to a charge.
              child: Text(
                'A charge of ${reason.penaltyFee!.format()} may apply to this cancellation.',
                style: AppText.body.copyWith(color: AppColors.negative),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
            onPressed: () => Navigator.of(context).pop(reason.id),
            child: const Text('Cancel ride'),
          ),
          TextButton(
            onPressed: () => setState(() => _selected = null),
            child: const Text('Back'),
          ),
        ],
      );
}
