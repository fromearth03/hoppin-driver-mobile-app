import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/error_codes.dart';
import '../../../../core/result.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../shared/widgets/app_buttons.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../data/cancel_reason_repository.dart';
import '../../data/models/cancel_reason.dart';

/// Reason picker, then a confirmation for any reason that carries a charge.
///
/// Returns the chosen reason id, or null if the driver backed out. Only
/// `pickable` reasons ever reach here, so no slug is displayed and none is
/// prettified client-side.
class CancelSheet extends ConsumerStatefulWidget {
  /// Seconds left in the free-cancellation window, when the caller knows it.
  /// Drives the "Cancelling now won't affect your rating" footer the design
  /// prints under the button — shown only while it is actually true.
  final int? freeCancelRemaining;

  const CancelSheet({super.key, this.freeCancelRemaining});

  static Future<String?> show(BuildContext context, {int? freeCancelRemaining}) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.background,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        builder: (_) => CancelSheet(freeCancelRemaining: freeCancelRemaining),
      );

  @override
  ConsumerState<CancelSheet> createState() => _CancelSheetState();
}

/// The red fill the design gives the cancel action. Built off the shared
/// primary style so the radius, height and type stay the design system's;
/// only the colour is the screen's own, because this is the one destructive
/// button in the app.
///
/// Disabled has to be restated too — `AppButtons.primary()` sets a lilac
/// `disabledBackgroundColor`, so a button with no reason chosen would sit
/// there in the wrong hue and change colour on the first tap.
final _dangerStyle = AppButtons.primary().copyWith(
  backgroundColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.disabled)
        ? AppColors.negative.withValues(alpha: 0.4)
        : AppColors.negative,
  ),
);

class _CancelSheetState extends ConsumerState<CancelSheet> {
  CancelReason? _selected;
  bool _confirming = false;
  late final Future<Result<List<CancelReason>>> _reasons;

  @override
  void initState() {
    super.initState();
    // The Result is kept rather than flattened to an empty list: a driver
    // who cannot load reasons must be told, not shown a question with no
    // answers at the moment they need to cancel.
    _reasons = ref.read(cancelReasonRepositoryProvider).forDriver();
  }

  bool get _isFree =>
      widget.freeCancelRemaining != null && widget.freeCancelRemaining! > 0;

  @override
  Widget build(BuildContext context) => Container(
        // The sheet carries its own ground rather than relying on the modal
        // route's, so it looks the same wherever it is embedded.
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // The grab handle the design draws at the top of the sheet.
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                height: 5,
                width: 78,
                decoration: BoxDecoration(
                  color: AppColors.textDisabled,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: _confirming && _selected != null
                      ? _confirm(_selected!)
                      : _picker(),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _header() => Row(
        children: [
          const Expanded(child: Text('Cancel Ride', style: AppText.display)),
          IconButton(
            icon: const Icon(Icons.cancel_outlined,
                color: AppColors.textSecondary),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Keep the ride',
          ),
        ],
      );

  Widget _picker() => FutureBuilder<Result<List<CancelReason>>>(
        future: _reasons,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(height: 160, child: AppLoading());
          }
          final result = snapshot.data!;
          final reasons = result.valueOrNull;
          // An empty picker under a question the driver cannot answer is
          // worse than an error: they are trying to cancel and cannot see
          // why they are stuck.
          if (reasons == null) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(),
                const SizedBox(height: 4),
                Text(errorCopy(result.errorOrNull!), style: AppText.body),
                const SizedBox(height: 16),
                AppOutlinedButton(
                  label: 'Keep the ride',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const Text('Why are you cancelling the ride?',
                  style: AppText.body),
              const SizedBox(height: 14),
              ...reasons.map(_reasonRow),
              // The design puts a free-text "Add any additional details
              // (option) 0/250" box here. `cancelRideBody` accepts only
              // reason_id, canceled_by_user_id and actor_type — an extra
              // field is silently dropped, so a driver would type an
              // explanation nobody would ever read. Omitted on purpose.
              const SizedBox(height: 10),
              AppButton(
                label: 'Cancel Ride',
                style: _dangerStyle,
                onPressed: _selected == null
                    ? null
                    : () => setState(() => _confirming = true),
              ),
              // The design's footer reads "Canceling now won't effect your
              // raiting". That is not what the free window does. Per
              // `gracedPenalty`, `free_cancel_seconds` waives the cancellation
              // FEE — nothing more. The cancellation still lands in
              // `driver_stats`, where `CancellationRate` is driver-at-fault
              // cancellations over accepted trips and `CompletionRate` counts
              // completions over the same. Promising an untouched rating would
              // talk a driver into a cancellation that does count against them.
              if (_isFree) ...[
                const SizedBox(height: 10),
                const SizedBox(
                  width: double.infinity,
                  child: Text(
                    'No cancellation fee if you cancel now. '
                    'It still counts towards your cancellation rate.',
                    textAlign: TextAlign.center,
                    style: AppText.caption,
                  ),
                ),
              ],
            ],
          );
        },
      );

  /// One radio row. The chosen reason gets the design's tinted, outlined
  /// treatment; the rest stay quiet.
  Widget _reasonRow(CancelReason reason) {
    final chosen = _selected?.id == reason.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _selected = reason),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: chosen
                ? AppColors.accent.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: chosen ? AppColors.accent : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                chosen
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: chosen ? AppColors.accent : AppColors.textDisabled,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reason.text,
                      style: AppText.body.copyWith(
                        fontSize: 16,
                        color: chosen
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    // The charge is named on the row itself, not only behind
                    // the confirmation — the driver picks with it in view.
                    if (reason.hasPenalty && !_isFree)
                      Text('${reason.penaltyFee!.format()} charge may apply',
                          style: AppText.caption
                              .copyWith(color: AppColors.negative)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _confirm(CancelReason reason) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cancel this ride?', style: AppText.title),
          const SizedBox(height: 8),
          Text(reason.text, style: AppText.bodySecondary),
          if (reason.hasPenalty && !_isFree) ...[
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
          AppButton(
            label: 'Cancel ride',
            style: _dangerStyle,
            onPressed: () => Navigator.of(context).pop(reason.id),
          ),
          const SizedBox(height: 8),
          AppOutlinedButton(
            label: 'Back',
            onPressed: () => setState(() => _confirming = false),
          ),
        ],
      );
}
