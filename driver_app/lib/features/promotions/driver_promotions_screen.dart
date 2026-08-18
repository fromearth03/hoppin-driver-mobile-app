import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../../providers.dart';

/// Driver-facing bonus campaigns from `GET /drivers/me/promotions`.
class DriverPromotionsScreen extends ConsumerWidget {
  const DriverPromotionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaigns = ref.watch(driverPromotionsProvider);
    final hoppin = context.hoppin;

    return Scaffold(
      backgroundColor: hoppin.colors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HopTopBar(
              title: 'Promotions',
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/profile'),
            ),
            Expanded(
              child: campaigns.hasError
                  ? const Center(child: Text('Promotions are unavailable right now.'))
                  : campaigns.isLoading
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : _CampaignList(campaigns: campaigns.value ?? const []),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampaignList extends StatelessWidget {
  const _CampaignList({required this.campaigns});

  final List<PromoOffer> campaigns;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    if (campaigns.isEmpty) {
      return const Center(
        child: HopEmptyState(
          compact: true,
          headline: 'No driver promotions right now',
          supporting: 'New bonus campaigns will appear here when they are active.',
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        hoppin.spacing.gutter,
        hoppin.spacing.md,
        hoppin.spacing.gutter,
        hoppin.spacing.xl,
      ),
      itemCount: campaigns.length,
      separatorBuilder: (_, _) => SizedBox(height: hoppin.spacing.md),
      itemBuilder: (_, index) => _CampaignCard(campaign: campaigns[index]),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({required this.campaign});

  final PromoOffer campaign;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final bonus = campaign.driverBonusAmount ?? campaign.discountValue;
    final terms = [
      if (campaign.minRideAmount != null)
        'Trips over £${campaign.minRideAmount!.toStringAsFixed(2)}',
      if (campaign.expiresAt != null)
        'Ends ${campaign.expiresAt!.day}/${campaign.expiresAt!.month}/${campaign.expiresAt!.year}',
    ].join(' · ');

    return HopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(campaign.displayTitle, style: hoppin.type.bodyMedium),
          SizedBox(height: hoppin.spacing.xs),
          Text(
            '£${bonus.toStringAsFixed(2)} bonus per eligible ride',
            style: hoppin.type.section.copyWith(color: hoppin.colors.accent),
          ),
          if (campaign.description.isNotEmpty) ...[
            SizedBox(height: hoppin.spacing.sm),
            Text(campaign.description, style: hoppin.type.meta),
          ],
          if (terms.isNotEmpty) ...[
            SizedBox(height: hoppin.spacing.sm),
            Text(terms, style: hoppin.type.labelSmall),
          ],
          SizedBox(height: hoppin.spacing.sm),
          Text('Campaign code: ${campaign.promoCode}', style: hoppin.type.labelSmall),
          SizedBox(height: hoppin.spacing.xs),
          Text(
            'Bonus is added automatically after an eligible ride completes.',
            style: hoppin.type.metaSmall,
          ),
        ],
      ),
    );
  }
}
