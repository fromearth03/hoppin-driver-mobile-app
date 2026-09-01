import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/error_codes.dart';
import '../../../../core/result.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../shared/widgets/app_buttons.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../earnings/data/earnings_repository.dart';
import '../../../earnings/data/models/ride_earnings.dart';
import '../../data/models/ride.dart';
import '../../data/trip_repository.dart';

/// What the driver sees the moment a trip completes: what they earned, and
/// the one thing they are asked to do before taking the next job.
///
/// Both halves are server-backed — `GET /rides/:id/earnings` for the money
/// and `POST /rides/:id/rating` for the score. Neither is invented here: a
/// summary the app computed itself could disagree with the payout the driver
/// is actually paid.
class TripSummary extends ConsumerStatefulWidget {
  final Ride ride;
  final VoidCallback onDone;

  const TripSummary({super.key, required this.ride, required this.onDone});

  @override
  ConsumerState<TripSummary> createState() => _TripSummaryState();
}

class _TripSummaryState extends ConsumerState<TripSummary> {
  int _score = 0;
  bool _sending = false;
  final _feedback = TextEditingController();

  /// The design's quick-tag chips. The rating handler has no tags field, so
  /// chosen tags are folded into `comments` at send time — the one field the
  /// server actually reads. ("Quite" in the frame is a typo for "Quiet".)
  static const _tags = ['Clean', 'Polite', 'Quiet', 'Ready on Time'];
  final Set<String> _chosenTags = {};

  @override
  void dispose() {
    _feedback.dispose();
    super.dispose();
  }

  /// Rating is optional. A driver who just wants the next job must not be
  /// held on this screen — the handler needs a 1–5 score, so an unrated trip
  /// is simply not sent rather than sent as a zero it would reject.
  Future<void> _finish() async {
    if (_score == 0) {
      widget.onDone();
      return;
    }
    setState(() => _sending = true);
    final comments = [
      if (_chosenTags.isNotEmpty)
        _tags.where(_chosenTags.contains).join(', '),
      if (_feedback.text.trim().isNotEmpty) _feedback.text.trim(),
    ].join('. ');
    final result = await ref
        .read(tripRepositoryProvider)
        .rate(widget.ride.id, score: _score, comments: comments);
    if (!mounted) return;
    setState(() => _sending = false);

    result.when(
      ok: (_) => widget.onDone(),
      // A rating that failed to save must not strand the driver on a
      // finished trip; they are told, and the screen still lets them go.
      err: (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorCopy(e))));
        widget.onDone();
      },
    );
  }

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.background,
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: _TitlePill(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  children: [
                    _EarningsCard(rideId: widget.ride.id),
                    const SizedBox(height: 16),
                    _ratingCard(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: AppButton(
                  label: 'Ready for Next Request',
                  busy: _sending,
                  onPressed: _finish,
                  style: AppButtons.primary().copyWith(
                    backgroundColor:
                        const WidgetStatePropertyAll(AppColors.accent),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _ratingCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              // The rider's name is already loaded from rider-context; a
              // rating prompt with no name in it is a form, not a question.
              widget.ride.rider == null
                  ? 'Rate Passenger'
                  : 'Rate Passenger: ${widget.ride.rider!.fullName}',
              style: AppText.heading.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              children: List.generate(5, (i) {
                final filled = i < _score;
                return IconButton(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                  iconSize: 44,
                  icon: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: filled ? AppColors.gold : AppColors.textDisabled,
                  ),
                  tooltip: '${i + 1} star${i == 0 ? '' : 's'}',
                  onPressed: () => setState(() => _score = i + 1),
                );
              }),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.map(_tagChip).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _feedback,
              maxLines: 4,
              maxLength: 250,
              style: AppText.body,
              decoration: InputDecoration(
                hintText: 'Leave optional feedback....',
                hintStyle: AppText.body.copyWith(color: AppColors.textDisabled),
                counterText: '',
                contentPadding: const EdgeInsets.all(14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.accent),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _tagChip(String tag) {
    final chosen = _chosenTags.contains(tag);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(
          () => chosen ? _chosenTags.remove(tag) : _chosenTags.add(tag)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: chosen
              ? AppColors.accent.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: chosen ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Text(
          tag,
          style: AppText.body.copyWith(
            color: chosen ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _TitlePill extends StatelessWidget {
  const _TitlePill();

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Text('Finish Ride - Ride Summary',
              style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary)),
        ),
      );
}

/// The money half of the summary, read straight from the service.
class _EarningsCard extends ConsumerStatefulWidget {
  final String rideId;

  const _EarningsCard({required this.rideId});

  @override
  ConsumerState<_EarningsCard> createState() => _EarningsCardState();
}

class _EarningsCardState extends ConsumerState<_EarningsCard> {
  /// Held in state rather than created in build: a Future rebuilt on every
  /// frame would re-request the breakdown each time the rating stars change.
  late final Future<Result<RideEarnings>> _earnings =
      ref.read(earningsRepositoryProvider).rideEarnings(widget.rideId);

  @override
  Widget build(BuildContext context) {
    // The design paints these figures over the trip's map. That is decorative
    // and costs legibility on a small screen, so the numbers get a solid card
    // and the route is left on the trip screen behind it.
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: FutureBuilder<Result<RideEarnings>>(
        future: _earnings,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(height: 140, child: AppLoading());
          }
          final result = snapshot.data!;
          final earnings = result.valueOrNull;
          if (earnings == null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Earning Summary', style: AppText.title),
                const SizedBox(height: 10),
                // Settlement can lag the completion by moments. Saying so is
                // honest; a £0.00 total would read as an unpaid trip.
                Text(errorCopy(result.errorOrNull!), style: AppText.body),
                const SizedBox(height: 6),
                const Text("It'll appear in your earnings shortly.",
                    style: AppText.caption),
              ],
            );
          }
          return _breakdown(earnings);
        },
      ),
    );
  }

  Widget _breakdown(RideEarnings earnings) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Earning Summary', style: AppText.title),
          const SizedBox(height: 12),
          // `lines` already ends with Net, which the design draws large as
          // "Total Earned". Everything before it is a component row.
          ...earnings.lines.take(earnings.lines.length - 1).map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(line.label, style: AppText.body)),
                      Text(line.amount.format(), style: AppText.body),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Expanded(child: Text('Total Earned', style: AppText.title)),
              Text(earnings.net.format(), style: AppText.money),
            ],
          ),
          // The design also prints "Payment Method: Cash". Nothing on
          // `GET /rides/:id` or `/rides/:id/earnings` carries the rail — the
          // only payment_method_id in the service belongs to the rider's saved
          // cards. Stating "Cash" would be a guess about who owes the driver
          // money, so the row is omitted.
        ],
      );
}
