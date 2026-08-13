import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../presence/presence_builder.dart';
import '../presence/widgets/background_location_limited_notice.dart';
import '../presence/widgets/location_unavailable_banner.dart';
import 'dashboard_builder.dart';
import 'dashboard_state.dart';
import 'eligibility_builder.dart';
import 'eligibility_state.dart';
import 'widgets/document_expiry_ladder.dart';
import 'widgets/not_eligible_state.dart';
import 'widgets/seam_unavailable_states.dart';

/// Dumb render layer of the dashboard riblet (DOCS/05): state in via
/// `ref.watch(dashboardInteractorProvider)`, intents out via `.notifier`.
/// No repository calls, no navigation, no timers, no demo branches —
/// hoppin_ui components and tokens carry every surface.
///
/// Layout (dark-first; one dominant surface + thin chrome): a thin brand
/// row up top, a large ambient status canvas with the pulsating GO button
/// at its centre, and the earnings tile anchored at the bottom.
class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    // 🔴 RE-ASK THE OS ON EVERY RESUME. A driver can revoke background location
    // from the Settings app mid-shift — and Android pushes us NO event when they
    // do. Nor does it tell us when an OEM battery manager kills the foreground
    // service. So a cached "you're covered" belief survives exactly the user
    // action that falsified it, and the app would keep drawing a confident
    // ONLINE badge over a shift that now dies at the lock screen.
    //
    // This is also the path back from the #85 rung's "Fix in settings" tap: the
    // driver leaves for Settings, flips "Allow all the time", and comes back —
    // and the banner disappears because we asked again, not because we guessed.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.read(presenceInteractorProvider.notifier).refreshCoverage();
      },
    );
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    // 🔴 Web performance: DO NOT watch the whole state at this root. The
    // earnings tile renders `onlineTime`, which ticks every second while online
    // — a root `ref.watch(dashboardInteractorProvider)` here would rebuild the
    // WHOLE column (GoButton + presence + eligibility, the expensive half) once
    // per second just to advance a clock two widgets down. Each child watches
    // the interactor itself and is rebuilt only when a field IT renders changes.
    // (`DashboardState` now has value equality, so an unchanged tick is a no-op
    // for every watcher regardless.)
    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            hoppin.spacing.gutter,
            hoppin.spacing.sm,
            hoppin.spacing.gutter,
            hoppin.spacing.gutter,
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _StatusCanvas()),
              _EarningsTile(),
            ],
          ),
        ),
      ),
    );
  }
}

/// The ambient status canvas: headline per phase, the GO button centred,
/// and — only while online — the quiet 'Go offline' text affordance below
/// (caption-weight, never symmetrical with GO).
class _StatusCanvas extends ConsumerWidget {
  const _StatusCanvas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    // Narrowed watch: the canvas renders per-PHASE (headline, GO state, the
    // offline text). It does NOT render earnings or the online clock, so it
    // must not rebuild when only those tick. `.select` on `phase` alone keeps
    // GoButton + the presence/eligibility watches below off the 1Hz path.
    final phase = ref.watch(
      dashboardInteractorProvider.select((s) => s.phase),
    );
    // The other two fields the canvas renders — the last-intent error banner and
    // the GO button's busy state. Each is its own narrowed watch, so the canvas
    // rebuilds only when one of these three actually changes, never on an
    // earnings/clock tick.
    final error = ref.watch(
      dashboardInteractorProvider.select((s) => s.error),
    );
    final transitioning = ref.watch(
      dashboardInteractorProvider.select((s) => s.transitioning),
    );
    final showsOnline = phase == DashboardPhase.online ||
        phase == DashboardPhase.goingOffline;

    // The heartbeat. Watching the presence riblet is what BUILDS it, and
    // building it is what arms the 5-second `POST /drivers/me/location` timer
    // the moment the dashboard phase goes online. Before this line existed,
    // `heartbeat()` had zero callers in the entire app and every driver
    // silently fell out of the dispatch pool five minutes into their shift.
    final presence = ref.watch(presenceInteractorProvider);

    // Seam #84 (device). The driver is ONLINE and NOT REACHABLE — no OS
    // location means no heartbeat means dispatch drops them. The confident
    // "You're online / Finding trips nearby" read is a LIE in this state, so it
    // is replaced, not merely decorated: the pill drops to neutral, the copy
    // tells the truth, and the banner gives a route to OS settings.
    final noFix = showsOnline && presence.locationUnavailable;

    // Seam #85 (device, Phase 2). The driver has FOREGROUND-ONLY coverage: they
    // ARE dispatchable, right now, with the app on screen — and their shift dies
    // the moment they lock the phone.
    //
    // 🔴 THIS IS WHY THE ONLINE READ IS SPLIT THREE WAYS, NOT TWO. The old
    // binary (online / no-fix) had no way to say "you are working, and there is
    // a cliff two seconds away", so it would have shown this driver the same
    // confident green "On duty · Finding trips nearby" it shows a fully-covered
    // one. That badge is the lie: it says *you are earning* to a driver who is
    // about to stop earning without noticing. So the pill drops out of success
    // tone, the supporting line names the condition (keep the app open), and the
    // banner explains the consequence and offers the real fix.
    //
    // It is deliberately NOT an error state and it does NOT stop them driving.
    // This is a working driver on a reduced device — not a broken one.
    final limited = showsOnline && !noFix && presence.foregroundOnly;

    // The FRONT DOOR of the shift. The ladder is BOUND — it reads the real
    // `expires_at` off `GET /drivers/me/documents` — and the 403 landing is
    // deliberately honest about what it does not know.
    final eligibility = ref.watch(eligibilityInteractorProvider);

    // Center + shrink-wrapped scroll view: the canvas stays vertically
    // centred when it fits and degrades to a scroll instead of an overflow
    // stripe under short viewports (never a RenderFlex overflow on stage).
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (error != null) ...[
              HopBanner.error(message: error),
              SizedBox(height: hoppin.spacing.lg),
            ],
            if (noFix) ...[
              const LocationUnavailableBanner(),
              SizedBox(height: hoppin.spacing.lg),
            ],
            if (limited) ...[
              const BackgroundLocationLimitedNotice(),
              SizedBox(height: hoppin.spacing.lg),
            ],
            // 🔴 The un-guessed 403. The server's own sentence, or an honest
            // admission that the app cannot tell them why — plus a real route
            // to a human, either way.
            if (eligibility.phase == EligibilityPhase.notEligible) ...[
              NotEligibleState(reason: eligibility.notEligibleReason),
              SizedBox(height: hoppin.spacing.lg),
            ],
            // 🔴 The ladder. It NAMES the document, days before the driver
            // could ever have found out by tapping GO in a car park at 5am.
            if (eligibility.expiries.isNotEmpty) ...[
              DocumentExpiryLadder(expiries: eligibility.expiries),
              SizedBox(height: hoppin.spacing.lg),
            ],
            // The composed status read: a quiet pill names the pool state
            // so the idle canvas is a designed state, never bare text.
            Center(
              child: switch ((showsOnline, noFix, limited)) {
                // Online but unreachable: NEVER the success pill. A green "On
                // duty" over a driver dispatch cannot see is the exact lie the
                // #84 rung exists to delete.
                (true, true, _) => const StatusPill(
                    label: 'Not receiving trips',
                    dot: true,
                  ),
                // Online, dispatchable, and one lock-screen away from not being.
                // NOT the success pill either — the green tone is the app's way
                // of saying "nothing to think about", and there is something to
                // think about.
                (true, false, true) => const StatusPill(
                    label: 'On duty · app must stay open',
                    dot: true,
                  ),
                (true, false, false) => const StatusPill(
                    label: 'On duty',
                    tone: PillTone.success,
                    dot: true,
                  ),
                _ => const StatusPill(label: 'Off duty', dot: true),
              },
            ),
            SizedBox(height: hoppin.spacing.md),
            Text(
              switch ((showsOnline, noFix, limited)) {
                (true, true, _) => 'Dispatch cannot reach you',
                (true, false, true) => "You're online",
                (true, false, false) => "You're online",
                _ => 'Ready to drive?',
              },
              textAlign: TextAlign.center,
              style: hoppin.type.headline.copyWith(color: colors.textHi),
            ),
            SizedBox(height: hoppin.spacing.sm),
            Text(
              switch ((showsOnline, noFix, limited)) {
                (true, true, _) =>
                  'No trips will be offered until location is on',
                // The one sentence that decides whether this driver earns
                // tonight. "Finding trips nearby" would be true right now and
                // false in ten seconds, which is the worst kind of true.
                (true, false, true) =>
                  'Trips stop if you lock your phone or switch apps',
                (true, false, false) => 'Finding trips nearby',
                _ => 'Go online to start receiving trips',
              },
              textAlign: TextAlign.center,
              style: hoppin.type.bodySmall.copyWith(color: colors.textMid),
            ),
            SizedBox(height: hoppin.spacing.xl),
            Center(
              child: GoButton(
                online: showsOnline,
                busy: transitioning,
                // 🔴 DISABLED ONLY ON A REAL, READ, EXPIRED DOCUMENT. Never on
                // a failed read (that is IGNORANCE — see
                // EligibilityInteractor.refresh), never on a last-day document
                // (they can legally work today), never on a null `expires_at`.
                // The SERVER is the authority on eligibility; this is us
                // telling the driver BY NAME, FIRST, so they never find out in
                // a car park. And it is never disabled without the rung above
                // it naming exactly which document, and when it lapsed.
                onPressed: eligibility.blocksGoOnline
                    ? null
                    : () => ref
                        .read(dashboardInteractorProvider.notifier)
                        .goOnline(),
              ),
            ),
            SizedBox(height: hoppin.spacing.lg),
            // The slot is always reserved so GO never jumps when the quiet
            // affordance appears.
            SizedBox(
              height: 48,
              child: showsOnline
                  ? Center(
                      child: TextButton(
                        onPressed: () => ref
                            .read(dashboardInteractorProvider.notifier)
                            .goOffline(),
                        style: TextButton.styleFrom(
                          foregroundColor: colors.textMid,
                          textStyle: hoppin.type.bodySmall,
                        ),
                        child: const Text('Go offline'),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// The earnings tile: 'Today' label, the trio (MoneyTicker total, trips,
/// online time), a thin positive-framing goal bar — plus the absorb
/// choreography (driver-ux-motion §5 'Earnings tile absorb'), driven
/// purely by `state.recentEarnedPence != null`:
///
/// - on landing the tile tint flashes accentSubtle and decays over
///   tintPulse (400ms, colour-only) — the immediate acknowledgment,
/// - after tileAbsorbDelay (300ms — the driver lands FIRST, then
///   witnesses the number move) the MoneyTicker ticks up over
///   tileAbsorbTick (700ms), seeded with fromPence so a remount
///   mid-absorb still renders the tick-up visibly (W2),
/// - the '+£x.xx' chip rises 16px and fades over chipRise (600ms,
///   ease-out; transform + colour-alpha, no Opacity widget) alongside the
///   tick — the celebration number visibly becomes the dashboard number.
///
/// One controller carries the whole choreography (delay + chip window);
/// the delay and tint land as Interval heads on it.
class _EarningsTile extends ConsumerStatefulWidget {
  const _EarningsTile();

  @override
  ConsumerState<_EarningsTile> createState() => _EarningsTileState();
}

class _EarningsTileState extends ConsumerState<_EarningsTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _absorb;
  CurvedAnimation? _chipT;
  CurvedAnimation? _tintT;
  bool _mountKicked = false;

  /// Today-goal constant (positive framing only — the bar just fills, no
  /// nagging copy anywhere). £60 is an honest reachable day target.
  static const int _dailyGoalPence = 6000;

  static const double _chipRisePx = 16;

  @override
  void initState() {
    super.initState();
    // Duration-less in initState; tokens resolve in didChangeDependencies
    // (05-02 controller convention). Resting value 1 == choreography done.
    _absorb = AnimationController(vsync: this, value: 1);
    // The absorb beat fires when recentEarnedPence flips to a new non-null.
    // This used to live in didUpdateWidget off `widget.state`; now the tile
    // watches the interactor itself (perf: the parent no longer rebuilds it on
    // every tick), so the trigger moves to a narrowed listen on that one field.
    ref.listenManual(
      dashboardInteractorProvider.select((s) => s.recentEarnedPence),
      (prev, next) {
        if (next != null && next != prev) _absorb.forward(from: 0);
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = context.hoppin.motion;
    // One controller spans delay + chip window (§5 absorb): the tint
    // decays from landing as the acknowledgment; the chip waits out
    // tileAbsorbDelay and rises alongside the delayed tick-up.
    final total = motion.tileAbsorbDelay + motion.chipRise;
    _absorb.duration = total;
    final delayFrac =
        motion.tileAbsorbDelay.inMicroseconds / total.inMicroseconds;
    final tintFrac = (motion.tintPulse.inMicroseconds / total.inMicroseconds)
        .clamp(0.0, 1.0);
    _chipT?.dispose();
    _tintT?.dispose();
    _chipT = CurvedAnimation(
      parent: _absorb,
      curve: Interval(delayFrac, 1, curve: Curves.easeOut),
    );
    _tintT = CurvedAnimation(
      parent: _absorb,
      curve: Interval(0, tintFrac, curve: Curves.easeOut),
    );
    if (!_mountKicked) {
      _mountKicked = true;
      // Mounted mid-absorb (e.g. a remount during the beat): play it.
      if (ref.read(dashboardInteractorProvider).recentEarnedPence != null) {
        _absorb.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _chipT?.dispose();
    _tintT?.dispose();
    _absorb.dispose();
    super.dispose();
  }

  String _money(int pence) => '£${(pence / 100).toStringAsFixed(2)}';

  String _formatOnlineTime(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final motion = hoppin.motion;
    // This tile DOES render the live online clock, so it legitimately rebuilds
    // on the 1Hz tick — that is correct and cheap (one small card). The perf win
    // is structural: it now watches the interactor directly instead of being
    // handed `state` by the parent, so its 1Hz rebuild no longer drags
    // `_StatusCanvas` (GoButton + presence + eligibility) along with it.
    final state = ref.watch(dashboardInteractorProvider);
    final earned = state.recentEarnedPence;
    final progress =
        (state.earningsPence / _dailyGoalPence).clamp(0.0, 1.0).toDouble();

    final trioStyle = hoppin.type.numeralCaption.copyWith(
      color: colors.textMid,
    );

    // Seam #7 (SEAMED — no driver-telemetry endpoint). The driver is IN the
    // dispatch pool (presence is authoritative from goOnline()'s 200, never
    // from telemetry), but `todayStats()` answers null forever on live, so the
    // trio has nothing honest to show. Rather than a blank slot — or, worse,
    // "£0.00 · 0 trips · 0h 00m" passed off as the day's real takings — the
    // tile shows the designed DriverStatsUnavailable rung. Reachable on live
    // the moment GO lands.
    final statsSeamed = !state.statsReady &&
        (state.phase == DashboardPhase.online ||
            state.phase == DashboardPhase.goingOffline);

    return HopCard(
      padding: EdgeInsets.zero,
      child: AnimatedBuilder(
        animation: _absorb,
        // Colour-only tint layer: accentSubtle flashes on absorb and
        // decays back to the card surface — never a layout animation.
        builder: (context, child) => Container(
          color: colors.accentSubtle.withValues(alpha: 1 - _tintT!.value),
          padding: EdgeInsets.all(hoppin.spacing.lg),
          child: child,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Today',
                  style: hoppin.type.label.copyWith(color: colors.textMid),
                ),
                const Spacer(),
                if (earned != null)
                  _AbsorbChip(t: _chipT!, label: '+${_money(earned)}'),
              ],
            ),
            SizedBox(height: hoppin.spacing.sm),
            if (state.statsReady)
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  MoneyTicker(
                    pence: state.earningsPence,
                    fromPence: earned == null
                        ? null
                        : state.earningsPence - earned,
                    duration: motion.tileAbsorbTick,
                    // §5: land first, then witness the tick-up — the
                    // celebration number becomes the dashboard number.
                    delay: motion.tileAbsorbDelay,
                  ),
                  SizedBox(width: hoppin.spacing.lg),
                  Text('${state.tripCount} trips', style: trioStyle),
                  SizedBox(width: hoppin.spacing.md),
                  Text(_formatOnlineTime(state.onlineTime), style: trioStyle),
                ],
              )
            else if (statsSeamed)
              // Online, dispatchable, but the telemetry seam (#7) answers
              // null: the designed rung says so honestly, in the tile's own
              // slot. No goal bar under it — a 0%-filled bar next to "stats
              // unavailable" would be the same zero-as-truth lie.
              const DriverStatsUnavailable()
            else
              // Offline before any telemetry: a real zeroed summary — the
              // driver simply has no trips today yet. Reads as a clean start,
              // never a broken placeholder.
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '£0.00',
                    style: hoppin.type.moneyTitle.copyWith(
                      color: colors.textMid,
                    ),
                  ),
                  SizedBox(width: hoppin.spacing.lg),
                  Text('0 trips', style: trioStyle),
                  SizedBox(width: hoppin.spacing.md),
                  Text('0h 0m', style: trioStyle),
                ],
              ),
            if (!statsSeamed) ...[
              SizedBox(height: hoppin.spacing.md),
              _GoalBar(progress: progress),
            ],
          ],
        ),
      ),
    );
  }
}

/// The '+£x.xx' delta chip: rises [_EarningsTileState._chipRisePx] and
/// fades via colour alpha along [t] — transform + paint-alpha only, inside
/// its own RepaintBoundary.
class _AbsorbChip extends StatelessWidget {
  const _AbsorbChip({required this.t, required this.label});

  final Animation<double> t;
  final String label;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: t,
        builder: (context, _) {
          final v = t.value;
          return Transform.translate(
            offset: Offset(0, -_EarningsTileState._chipRisePx * v),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: hoppin.spacing.sm,
                vertical: 2,
              ),
              decoration: ShapeDecoration(
                color: colors.successSubtle.withValues(alpha: 1 - v),
                shape: const StadiumBorder(),
              ),
              child: Text(
                label,
                style: hoppin.type.numeralCaption.copyWith(
                  color: colors.success.withValues(alpha: 1 - v),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Thin today-goal progress: hairline track, success-role fill. Positive
/// framing only — the bar fills, no copy nags.
class _GoalBar extends StatelessWidget {
  const _GoalBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.hoppin.colors;
    return Container(
      height: 4,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: colors.hairline,
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        widthFactor: progress,
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.success,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
