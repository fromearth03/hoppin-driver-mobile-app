import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/pending_offer.dart';

/// The decision surface. A driver has ~60 seconds to answer two questions:
/// is this worth it, and how far do I drive unpaid to start it. Fare,
/// pickup ETA and trip length answer both.
///
/// It shows no rider name, photo or rating — see spec section 6.1.
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
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  static String _minutes(int seconds) => '${(seconds / 60).round()} min';

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final remaining = offer.secondsRemaining;
    final fraction =
        offer.expiresInSec == 0 ? 0.0 : remaining / offer.expiresInSec;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(offer.fare.format(), style: AppText.money),
                      if (offer.rideCategory != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _badge(offer.rideCategory!),
                        ),
                    ],
                  ),
                ),
                _countdown(remaining, fraction),
              ],
            ),
            const SizedBox(height: 16),
            _leg(Icons.trip_origin, AppColors.info, offer.pickupLabel),
            const SizedBox(height: 8),
            _leg(Icons.place, AppColors.negative, offer.dropoffLabel),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              children: [
                if (offer.pickupEtaSeconds != null)
                  Text('${_minutes(offer.pickupEtaSeconds!)} away',
                      style: AppText.caption),
                if (offer.estimatedDurationSeconds != null)
                  Text('${_minutes(offer.estimatedDurationSeconds!)} trip',
                      style: AppText.caption),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: widget.isBusy ? null : widget.onAccept,
              child: Text('Accept for ${offer.fare.format()}'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: widget.isBusy ? null : widget.onDecline,
              child: const Text('Decline'),
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _leg(IconData icon, Color color, String label) => Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style: AppText.body, overflow: TextOverflow.ellipsis)),
        ],
      );

  /// The ring is driven by the server's `expires_in_sec`, so it reflects the
  /// real window rather than a client guess.
  Widget _countdown(int remaining, double fraction) => SizedBox(
        width: 52,
        height: 52,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              strokeWidth: 4,
              backgroundColor: AppColors.border,
              color: remaining <= 10 ? AppColors.negative : AppColors.primary,
            ),
            Text('${remaining}s', style: AppText.caption),
          ],
        ),
      );
}
