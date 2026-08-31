import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../shared/widgets/app_buttons.dart';
import '../../data/models/pending_offer.dart';

/// The decision surface. A driver has ~60 seconds to answer two questions:
/// is this worth it, and how far do I drive unpaid to start it. Fare,
/// distance, pickup ETA and trip length answer both.
///
/// It shows no rider name, photo or rating — see spec section 6.1. The
/// design puts a photo, a name and a "4.3 (13)" rating in a card to the left
/// of the fare, and a free-text rider "Comment" box below the map. None of
/// it is built: the offer payload carries none of those fields, and showing
/// identity before accept/decline would let acceptance be conditioned on a
/// protected characteristic. The fare panel therefore takes the full width
/// the design splits between it and the identity card.
///
/// The design also embeds a route map between the timeline and the actions.
/// The offer payload carries pickup/dropoff lat-lng but the app ships no map
/// tile source, so the block is omitted rather than faked with a picture.
class OfferCard extends StatefulWidget {
  final PendingOffer offer;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final bool isBusy;

  const OfferCard({
    super.key,
    required this.offer,
    this.onAccept,
    this.onDecline,
    this.isBusy = false,
  });

  @override
  State<OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<OfferCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      // Nothing left to count; rebuilding once a second forever would burn
      // battery on a card that can no longer change.
      if (widget.offer.hasExpired) timer.cancel();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  static String _minutes(int seconds) => '${(seconds / 60).round()} min';

  static String _miles(double miles) =>
      '${miles.toStringAsFixed(1)} miles';

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final remaining = offer.secondsRemaining;
    // The server drops a lapsed offer on its next poll, but the card is on
    // screen in between. Accepting here would fail with OFFER_EXPIRED, so
    // the button says so rather than inviting the tap.
    final expired = offer.hasExpired;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _farePanel(offer),
          const SizedBox(height: 16),
          _timelinePanel(offer),
          const SizedBox(height: 16),
          _actions(remaining, expired),
        ],
      ),
    );
  }

  /// Estimated fare above a row of two stats. The design gives the fare its
  /// own white panel with the money set larger than anything else on screen —
  /// it is the only number the accept decision turns on.
  Widget _farePanel(PendingOffer offer) => _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Text('Estimated Fare',
                      style: TextStyle(
                          fontSize: 15, color: AppColors.textSecondary)),
                ),
                if (offer.rideCategory != null) _badge(offer.rideCategory!),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(offer.fare.format(),
                  style: AppText.money.copyWith(fontSize: 34)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _stat(
                    Icons.place_outlined,
                    'Distance',
                    // Distance is `estimated_miles` off the offer. Miles, not
                    // the design's "4.7 km": the rest of the app — trip
                    // history, the earnings statement — is in miles, and one
                    // screen in kilometres would read as two different trips.
                    offer.estimatedMiles == null
                        ? null
                        : _miles(offer.estimatedMiles!),
                  ),
                ),
                Expanded(
                  child: _stat(
                    Icons.schedule,
                    'Duration',
                    offer.estimatedDurationSeconds == null
                        ? null
                        : _minutes(offer.estimatedDurationSeconds!),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  /// Pickup then dropoff, joined by the design's dashed rail. Each stop is a
  /// ring, a bold heading with the ETA beside it, and the address below in
  /// grey. Only the pickup carries an ETA — the offer has one leg timing to
  /// the pickup and one for the trip itself, not a second door-to-door ETA.
  Widget _timelinePanel(PendingOffer offer) => _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stop(
              ring: AppColors.primary,
              title: 'Pickup',
              detail: offer.pickupEtaSeconds == null
                  ? null
                  : '${_minutes(offer.pickupEtaSeconds!)} away',
              label: offer.pickupLabel,
              rail: true,
            ),
            const Padding(
              padding: EdgeInsets.only(left: 34, top: 12, bottom: 12),
              child: Divider(height: 1, color: AppColors.border),
            ),
            _stop(
              ring: AppColors.negative,
              title: 'Dropoff',
              detail: offer.estimatedDurationSeconds == null
                  ? null
                  : '${_minutes(offer.estimatedDurationSeconds!)} trip',
              label: offer.dropoffLabel,
              rail: false,
            ),
          ],
        ),
      );

  /// The countdown sits beside Accept rather than above the fare: the design
  /// pairs the two, so the driver reads "how long have I got" and "take it"
  /// in one glance. Decline is the full-width muted row underneath.
  Widget _actions(int remaining, bool expired) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(flex: 4, child: _countdownPill(remaining, expired)),
                const SizedBox(width: 12),
                Expanded(
                  flex: 6,
                  child: AppButton(
                    label: expired ? 'Offer expired' : 'Accept Ride',
                    onPressed: expired ? null : widget.onAccept,
                    busy: widget.isBusy,
                    style: AppButtons.deep(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: AppButtons.height,
            child: OutlinedButton.icon(
              onPressed: widget.isBusy ? null : widget.onDecline,
              style: AppButtons.outlined(),
              icon: const Icon(Icons.cancel_outlined, size: 20),
              label: Text(expired ? 'Dismiss' : 'Decline Ride'),
            ),
          ),
        ],
      );

  Widget _panel({required Widget child}) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      );

  Widget _badge(String category) {
    final label =
        '${category[0].toUpperCase()}${category.substring(1).replaceAll('_', ' ')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child:
          Text(label, style: AppText.caption.copyWith(color: AppColors.primary)),
    );
  }

  /// A circled icon, a grey caption and the value under it — the design's
  /// Distance/Duration pair. A null value renders an em dash rather than
  /// dropping the column, so the two stats stay on the same baseline.
  Widget _stat(IconData icon, String label, String? value) => Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value ?? '—',
                    style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _stop({
    required Color ring,
    required String title,
    required String? detail,
    required String label,
    required bool rail,
  }) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ring, width: 3),
                ),
              ),
              // The design runs a dashed rail from the pickup ring down to
              // the dropoff. A solid hairline reads the same at this size.
              if (rail)
                Container(
                  width: 1,
                  height: 26,
                  margin: const EdgeInsets.only(top: 4),
                  color: AppColors.border,
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    if (detail != null) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('•',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ),
                      Flexible(
                        child: Text(detail,
                            style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(label,
                    style: const TextStyle(
                        fontSize: 16, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      );

  /// Clock plus seconds, on the design's pale pill. The number is driven by
  /// the offer's absolute `expires_at`, so it reflects the real window rather
  /// than a client guess, and it turns red in the last ten seconds.
  Widget _countdownPill(int remaining, bool expired) => Container(
        height: AppButtons.height,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off,
                size: 24,
                color: expired || remaining <= 10
                    ? AppColors.negative
                    : AppColors.textPrimary),
            const SizedBox(width: 8),
            Text(
              '${remaining}s',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: expired || remaining <= 10
                    ? AppColors.negative
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      );
}
