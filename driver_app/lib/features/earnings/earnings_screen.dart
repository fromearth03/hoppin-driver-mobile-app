import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../../providers.dart';
import '../comms/url_launcher_gateway.dart';
import 'earnings_providers.dart';

bool _isInternalCampaignTarget(String? target) {
  if (target == null || target.isEmpty || !target.startsWith('/')) return false;
  if (target.contains('://') || target.contains('\\')) return false;
  return target == '/' ||
      target.startsWith('/earnings') ||
      target.startsWith('/profile') ||
      target.startsWith('/support') ||
      target.startsWith('/settings') ||
      target.startsWith('/notifications');
}

/// The driver's money surface — balances, today, and payout history.
///
/// WHAT IS REAL HERE. Two balances and the payout runs come from
/// `GET /drivers/me/wallet` (#47, WIRED); today's earnings, trip count and
/// online clock come from `GET /drivers/me/today` (#7). Both are rendered
/// verbatim, in pence, through [formatPence].
///
/// 🔴 WHAT IS DELIBERATELY NOT DRAWN. Scope Lock §4.2 mandates an earnings
/// breakdown of base fare, distance/time, surge, platform commission, taxes and
/// penalties, plus a payout schedule and downloadable reports. **No endpoint
/// carries any of those** — `DriverRepository.wallet` says so in terms. This
/// screen therefore discloses each missing block as a designed rung rather than
/// deriving numbers from the two balances it does have: a breakdown inferred
/// client-side is an invented breakdown, and this is a self-employed person's
/// pay. The rungs promote to live with no change to the surrounding anatomy the
/// day the endpoints ship.
class DriverEarningsScreen extends ConsumerWidget {
  /// Creates the earnings surface.
  const DriverEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final wallet = ref.watch(driverWalletProvider);
    // 🔴 Web perf: driverStatsProvider is a 1Hz stream. Watching it at THIS root
    // rebuilt the entire ListView (balances, payout setup, every unavailable
    // rung) once per second just to advance the Today card's clock. `_TodayCard`
    // now watches the stream itself, so the 1Hz rebuild is confined to it.

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            HopTopBar(
              title: 'Earnings',
              // 🔴 NEVER null — a null onBack hides the chevron and strands the
              // driver here.
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/profile'),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(driverWalletProvider),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    hoppin.spacing.gutter,
                    hoppin.spacing.md,
                    hoppin.spacing.gutter,
                    hoppin.spacing.xl,
                  ),
                  children: [
                    const _DriverCampaigns(),
                    SizedBox(height: hoppin.spacing.lg),
                    _BalancesCard(wallet: wallet),
                    SizedBox(height: hoppin.spacing.lg),
                    _PromotionBonusesCard(wallet: wallet),
                    SizedBox(height: hoppin.spacing.lg),
                    const _SectionHeader('Today'),
                    const _TodayCard(),
                    SizedBox(height: hoppin.spacing.lg),
                    const _SectionHeader('Payouts'),
                    // Setup FIRST, history second: whether money can reach a
                    // bank account at all outranks the list of times it did.
                    const _PayoutSetupCard(),
                    SizedBox(height: hoppin.spacing.md),
                    _PayoutsCard(wallet: wallet),
                    SizedBox(height: hoppin.spacing.lg),
                    const _SectionHeader('Fare breakdown'),
                    const HopCard(child: _BreakdownUnavailable()),
                    SizedBox(height: hoppin.spacing.lg),
                    const _SectionHeader('Your performance'),
                    const HopCard(child: _MetricsUnavailable()),
                    SizedBox(height: hoppin.spacing.lg),
                    const _SectionHeader('Busy areas'),
                    const HopCard(child: _HeatmapUnavailable()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromotionBonusesCard extends StatelessWidget {
  const _PromotionBonusesCard({required this.wallet});

  final AsyncValue<DriverWallet?> wallet;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final data = wallet.value;
    if (data == null || data.recentBonuses.isEmpty) {
      return HopCard(
        child: Text(
          'No promotion bonuses yet',
          style: hoppin.type.body.copyWith(color: colors.textMid),
        ),
      );
    }
    return HopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Promotion bonuses', style: hoppin.type.section.copyWith(color: colors.textHi)),
          SizedBox(height: hoppin.spacing.sm),
          for (final bonus in data.recentBonuses) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    bonus.promoCode.isEmpty ? bonus.title : '${bonus.title} (${bonus.promoCode})',
                    style: hoppin.type.body.copyWith(color: colors.textHi),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '+${formatPence(bonus.amountPence)}',
                  style: hoppin.type.body.copyWith(color: colors.success),
                ),
              ],
            ),
            if (bonus != data.recentBonuses.last) SizedBox(height: hoppin.spacing.sm),
          ],
        ],
      ),
    );
  }
}

/// Driver-targeted advertisements are shown on a real authenticated surface,
/// and engagement is reported once per rendered campaign.
class _DriverCampaigns extends ConsumerWidget {
  const _DriverCampaigns();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaigns = ref.watch(driverAdsProvider);
    final promotions = ref.watch(driverPromotionsProvider);
    final ads = campaigns.value ?? const <Ad>[];
    final promos = promotions.value ?? const <PromoOffer>[];
    if (ads.isEmpty && promos.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (promos.isNotEmpty) ...[
          const _SectionHeader('Driver promotions'),
          SizedBox(height: context.hoppin.spacing.sm),
          for (final promo in promos) ...[
            _DriverPromotionCard(promotion: promo, key: ValueKey(promo.promoCode)),
            SizedBox(height: context.hoppin.spacing.sm),
          ],
        ],
        if (ads.isNotEmpty) ...[
          const _SectionHeader('Campaigns'),
          SizedBox(height: context.hoppin.spacing.sm),
          for (final ad in ads) ...[
            _DriverCampaignCard(ad: ad, key: ValueKey(ad.id)),
            SizedBox(height: context.hoppin.spacing.sm),
          ],
        ],
      ],
    );
  }
}

class _DriverPromotionCard extends StatelessWidget {
  const _DriverPromotionCard({required this.promotion, super.key});

  final PromoOffer promotion;

  @override
  Widget build(BuildContext context) {
    final bonus = promotion.driverBonusAmount ?? promotion.discountValue;
    final details = [
      '£${bonus.toStringAsFixed(2)} bonus per eligible ride',
      if (promotion.minRideAmount != null)
        'Trips over £${promotion.minRideAmount!.toStringAsFixed(2)}',
      if (promotion.expiresAt != null)
        'Ends ${promotion.expiresAt!.day}/${promotion.expiresAt!.month}/${promotion.expiresAt!.year}',
    ].join(' · ');
    return HopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            promotion.displayTitle,
            style: context.hoppin.type.bodyMedium,
          ),
          if (promotion.description.isNotEmpty) ...[
            SizedBox(height: context.hoppin.spacing.xs),
            Text(promotion.description, style: context.hoppin.type.meta),
          ],
          SizedBox(height: context.hoppin.spacing.xs),
          Text(details, style: context.hoppin.type.labelSmall),
          SizedBox(height: context.hoppin.spacing.sm),
          Text(
            'Campaign code: ${promotion.promoCode}',
            style: context.hoppin.type.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _DriverCampaignCard extends ConsumerStatefulWidget {
  const _DriverCampaignCard({required this.ad, super.key});

  final Ad ad;

  @override
  ConsumerState<_DriverCampaignCard> createState() => _DriverCampaignCardState();
}

class _DriverCampaignCardState extends ConsumerState<_DriverCampaignCard> {
  @override
  void initState() {
    super.initState();
    ref.read(adsRepositoryProvider).reportImpression(widget.ad.id);
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;
    final target = ad.targetUrl;
    final canTap = _isInternalCampaignTarget(target);
    return HopCard(
      padding: EdgeInsets.zero,
      onTap: canTap
          ? () {
              ref.read(adsRepositoryProvider).reportClick(ad.id);
              context.go(target!);
            }
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ad.imageUrl case final image? when image.isNotEmpty)
            SizedBox(
              height: 110,
              child: Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(context.hoppin.spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ad.title, style: context.hoppin.type.bodyMedium),
                if (ad.body case final body? when body.isNotEmpty) ...[
                  SizedBox(height: context.hoppin.spacing.xs),
                  Text(body, style: context.hoppin.type.meta),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Available + pending balance — the money hero. Real, from `#47`.
class _BalancesCard extends StatelessWidget {
  const _BalancesCard({required this.wallet});

  final AsyncValue<DriverWallet?> wallet;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    // Error-first: Riverpod surfaces a failure as loading-with-error, so a
    // plain `isLoading` branch would spin forever on a dead endpoint.
    if (wallet.hasError) {
      return const HopCard(child: _WalletUnavailable());
    }
    final data = wallet.value;
    if (data == null) {
      return HopCard(
        child: wallet.isLoading
            ? Center(
                child: Padding(
                  // Token, not a magic 24 — this reserves roughly the height
                  // the loaded balances occupy so the card does not jump when
                  // the figures land.
                  padding: EdgeInsets.all(hoppin.spacing.gutter),
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : const _WalletUnavailable(),
      );
    }

    return HopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Pending payout',
            style: hoppin.type.labelSmall.copyWith(color: colors.textMid),
          ),
          SizedBox(height: hoppin.spacing.xs),
          Text(
            formatPence(data.pendingBalancePence),
            style: hoppin.type.moneyHero.copyWith(color: colors.textHi),
          ),
          SizedBox(height: hoppin.spacing.md),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Available',
                  value: formatPence(data.availableBalancePence),
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Last payout',
                  value: data.lastPayoutAt == null
                      ? '—'
                      : formatShortDateTime(data.lastPayoutAt!),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Today's earnings / trips / online clock — real, from `#7`.
///
/// Watches `driverStatsProvider` itself (a 1Hz stream) so its per-second rebuild
/// stays confined to this card rather than the whole earnings ListView.
class _TodayCard extends ConsumerWidget {
  const _TodayCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(driverStatsProvider);
    final data = stats.value;
    if (data == null) {
      // Still in flight: a quiet reserved slot, NOT the rung. Flashing "stats
      // unavailable" during a normal load tells the driver a seam is missing
      // when it may be about to answer — and then swaps it out a beat later,
      // which reads as a glitch rather than a disclosure. Matches the
      // error-first shape the balances card above already uses.
      if (stats.isLoading && !stats.hasError) {
        return HopCard(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(context.hoppin.spacing.gutter),
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
      // The dashboard's own rung — presence is authoritative elsewhere, only
      // the stats display is missing.
      return const HopCard(
        child: HopEmptyState(
          compact: true,
          headline: "Today's stats unavailable",
          supporting:
              "You're online and taking rides — your earnings and trip count "
              'will appear here once trip telemetry is switched on.',
        ),
      );
    }
    final hours = data.onlineTime.inHours;
    final minutes = data.onlineTime.inMinutes.remainder(60);
    return HopCard(
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              label: 'Earned',
              value: formatPence(data.earningsPence),
            ),
          ),
          Expanded(child: _Stat(label: 'Trips', value: '${data.tripCount}')),
          Expanded(
            child: _Stat(label: 'Online', value: '${hours}h ${minutes}m'),
          ),
        ],
      ),
    );
  }
}

/// Recent payout runs — real, from `#47`. A `failed` payout is called out in
/// the error tone: a failed payout that renders like a successful one is the
/// worst possible silence on a driver's pay.
class _PayoutsCard extends ConsumerWidget {
  const _PayoutsCard({required this.wallet});

  final AsyncValue<DriverWallet?> wallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final data = wallet.value;

    if (data == null) {
      return const HopCard(child: _WalletUnavailable());
    }
    if (data.recentPayouts.isEmpty) {
      return const HopCard(
        child: HopEmptyState(
          compact: true,
          headline: 'No payouts yet',
          supporting:
              'Completed trips build your pending balance. Payout runs will '
              'be listed here once the first one settles.',
        ),
      );
    }

    return HopCard(
      padding: EdgeInsets.symmetric(vertical: hoppin.spacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < data.recentPayouts.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: hoppin.spacing.lg,
                vertical: hoppin.spacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatPence(data.recentPayouts[i].amountPence),
                          style: hoppin.type.body
                              .copyWith(color: colors.textHi),
                        ),
                        SizedBox(height: hoppin.spacing.xs),
                        Text(
                          data.recentPayouts[i].transferredAt == null
                              ? 'Not yet transferred'
                              : formatShortDateTime(
                                  data.recentPayouts[i].transferredAt!),
                          style: hoppin.type.metaSmall
                              .copyWith(color: colors.textMid),
                        ),
                      ],
                    ),
                  ),
                  // The server's own status word, verbatim — never a coined
                  // synonym. `failed` takes the error tone.
                  StatusPill(
                    label: data.recentPayouts[i].status,
                    tone: data.recentPayouts[i].status == 'failed'
                        ? PillTone.error
                        : PillTone.neutral,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Stripe Connect payout setup — the gate on whether the balance above can
/// ever reach a bank account.
///
/// 🔴 **Three states, and collapsing any two of them lies to a driver about
/// their pay.**
///  * NOT STARTED — no Stripe account. Nothing will ever be paid out.
///  * PENDING — account exists, Stripe has not cleared payouts yet. This is
///    where a driver spends the longest, and "you're set up" here would promise
///    money that cannot move.
///  * READY — verified; payouts land.
///
/// The endpoints (`GET`/`POST /me/payout-account`) shipped on the server and had
/// ZERO callers in this app — a driver could accrue an available balance with no
/// way to say where it goes.
class _PayoutSetupCard extends ConsumerStatefulWidget {
  const _PayoutSetupCard();

  @override
  ConsumerState<_PayoutSetupCard> createState() => _PayoutSetupCardState();
}

class _PayoutSetupCardState extends ConsumerState<_PayoutSetupCard> {
  bool _busy = false;
  String? _error;

  /// Mints a FRESH hosted link and hands it to the OS.
  ///
  /// The link is single-use and short-lived, so it is requested on tap and
  /// never cached. Everything goes through [urlLauncherProvider] — the one
  /// audited path to the OS in this app.
  Future<void> _start() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res =
          await ref.read(driverRepositoryProvider).startPayoutOnboarding();
      if (!mounted) return;

      // Already verified — nothing to open. Refresh so the card catches up.
      if (res.alreadyEnabled || res.onboardingURL == null) {
        ref.invalidate(payoutStatusProvider);
        setState(() => _busy = false);
        return;
      }

      final opened = await ref
          .read(urlLauncherProvider)
          .launch(Uri.parse(res.onboardingURL!));
      if (!mounted) return;
      setState(() {
        _busy = false;
        // 🔴 A no-op launcher answers false. Say so rather than leaving the
        // driver tapping a button that appears to do nothing — the silent
        // dead end this whole card exists to remove.
        _error = opened
            ? null
            : 'We could not open the Stripe setup page on this device. Try '
                'the Hoppin driver app on your phone.';
      });
      // Returning from Stripe should re-read: the driver may now be verified.
      ref.invalidate(payoutStatusProvider);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final status = ref.watch(payoutStatusProvider);

    // Unknown state: say nothing rather than guess. Claiming "not set up" on a
    // failed read would tell a verified driver they cannot be paid.
    if (!status.hasValue) return const SizedBox.shrink();
    final s = status.requireValue;

    if (s.ready) {
      return HopCard(
        child: Row(
          children: [
            Icon(Icons.verified_outlined, size: 20, color: colors.success),
            SizedBox(width: hoppin.spacing.md),
            Expanded(
              child: Text(
                'Payouts are set up. Your balance is paid to your bank on the '
                'normal payout run.',
                style: hoppin.type.bodySmall.copyWith(color: colors.textMid),
              ),
            ),
          ],
        ),
      );
    }

    final pending = s.pendingVerification;
    return HopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                pending ? Icons.hourglass_empty : Icons.account_balance_outlined,
                size: 20,
                color: pending ? colors.warn : colors.accent,
              ),
              SizedBox(width: hoppin.spacing.md),
              Expanded(
                child: Text(
                  pending
                      ? 'Finish setting up payouts'
                      : 'Set up payouts to get paid',
                  style: hoppin.type.bodyMedium.copyWith(color: colors.textHi),
                ),
              ),
            ],
          ),
          SizedBox(height: hoppin.spacing.sm),
          Text(
            pending
                ? 'Stripe still needs to verify you before money can be paid '
                    'out. That usually means a document or bank detail is '
                    'outstanding — your earnings keep accruing meanwhile.'
                : 'Hoppin pays out through Stripe. Add your bank details and '
                    'ID once, and your balance is paid automatically.',
            style: hoppin.type.bodySmall.copyWith(color: colors.textMid),
          ),
          if (_error != null) ...[
            SizedBox(height: hoppin.spacing.sm),
            Text(
              _error!,
              style: hoppin.type.metaSmall.copyWith(color: colors.error),
            ),
          ],
          SizedBox(height: hoppin.spacing.md),
          HopButton.primary(
            key: const Key('earnings.payout.setup'),
            label: _busy
                ? 'Opening…'
                : (pending ? 'Continue setup' : 'Set up payouts'),
            onPressed: _busy ? null : _start,
          ),
        ],
      ),
    );
  }
}

/// One label/value stat cell.
class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: hoppin.type.labelSmall.copyWith(color: colors.textMid),
        ),
        SizedBox(height: hoppin.spacing.xs),
        Text(
          value,
          style: hoppin.type.numeral.copyWith(color: colors.textHi),
        ),
      ],
    );
  }
}

/// `GET /drivers/me/wallet` did not answer.
class _WalletUnavailable extends StatelessWidget {
  const _WalletUnavailable();

  @override
  Widget build(BuildContext context) {
    return const HopEmptyState(
      compact: true,
      headline: 'Balance unavailable',
      supporting:
          "We couldn't read your wallet just now. Your earnings are still "
          'recorded — pull down to try again.',
    );
  }
}

/// Scope Lock §4.2 mandates a six-line fare breakdown. Nothing serves it.
class _BreakdownUnavailable extends StatelessWidget {
  const _BreakdownUnavailable();

  @override
  Widget build(BuildContext context) {
    return const HopEmptyState(
      compact: true,
      headline: 'Per-trip breakdown not available yet',
      supporting:
          'Your balance is the settled total. The split — base fare, distance '
          'and time, surge, commission, VAT and any penalties — needs a '
          "breakdown feed we don't have yet, so we show the total rather than "
          'guess at the parts.',
    );
  }
}

/// Scope Lock §4.2 mandates driver performance metrics. No read exists.
class _MetricsUnavailable extends StatelessWidget {
  const _MetricsUnavailable();

  @override
  Widget build(BuildContext context) {
    return const HopEmptyState(
      compact: true,
      headline: 'Performance metrics not available yet',
      supporting:
          'Your rating, acceptance and completion rates are calculated from '
          'your trips, but there is no read for them yet. We would rather show '
          'nothing than a number your work is judged on that we cannot stand '
          'behind.',
    );
  }
}

/// Scope Lock §4.2 mandates a demand heatmap. No demand-zone feed exists.
class _HeatmapUnavailable extends StatelessWidget {
  const _HeatmapUnavailable();

  @override
  Widget build(BuildContext context) {
    return const HopEmptyState(
      compact: true,
      headline: 'Busy-area map not available yet',
      supporting:
          'Live demand zones need a feed that is not switched on yet. Dispatch '
          'still reaches you wherever you are — this map would only be a hint '
          'about where to wait.',
    );
  }
}

/// Quiet micro section header.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    return Padding(
      padding: EdgeInsets.only(bottom: hoppin.spacing.sm),
      child: Text(
        text.toUpperCase(),
        style: hoppin.type.labelSmall.copyWith(
          color: hoppin.colors.textMid,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
