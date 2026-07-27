import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'motion_interactor.dart';
import 'motion_state.dart';

export 'motion_interactor.dart';
export 'motion_state.dart';

/// Assembly point of the motion riblet (DOCS/05) — a SERVICE riblet: the
/// interactor's provider and nothing else. No view, no router, no route.
///
/// 🔴 **THE SINGLE SOURCE OF TRUTH FOR THE INTERACTION BUDGET.** Every lane in
/// Phase 4 reads `inMotion` from HERE. No lane computes its own speed, and no
/// lane opens its own GPS subscription — the number rides along on the fix the
/// presence heartbeat is already taking.
///
/// 🔴 **THE RULE, SO NO LANE RE-INVENTS THE BAN:** wrap the composer, never the
/// buttons. A cradled phone is legal to touch — that is how every Uber driver
/// taps Accept at the wheel — so template chips and one-tap actions **stay live
/// at speed**. Only TYPING is suppressed. `motion_interaction_budget_test.dart`
/// fails RED **both ways**: if a TextField survives at speed, and if a button
/// does not.
///
/// Not autoDispose, and deliberately so: the gate is app-wide, it is read from
/// several riblets at once, and a gate that tore itself down between readers
/// would re-enter its honest `inMotion: false` default at exactly the moments
/// the driver is moving fastest between screens.
final motionInteractorProvider =
    NotifierProvider<MotionInteractor, MotionState>(MotionInteractor.new);
