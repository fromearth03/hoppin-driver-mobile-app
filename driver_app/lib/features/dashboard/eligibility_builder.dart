import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'eligibility_interactor.dart';
import 'eligibility_state.dart';

/// The app's clock, as a provider.
///
/// 🔴 THE LADDER MUST NEVER CALL `DateTime.now()` INLINE. A T-1d assertion that
/// passes at 23:59:58 and fails in CI at 00:00:01 is worse than no test: it
/// teaches the team to re-run the suite instead of reading it — and the rung it
/// guards is the one that decides whether a driver's GO button works tomorrow.
///
/// Defaults to `clock.now` (the project's `package:clock` convention, already
/// used by the presence and offer interactors), so `withClock` still works;
/// tests may also override this provider directly with a fixed instant.
final nowProvider = Provider<DateTime Function()>((ref) => clock.now);

/// Assembly point of the eligibility riblet (DOCS/05).
///
/// A SERVICE riblet: interactor + state + two widgets, no view, no router, no
/// route. The dashboard view watches it; nothing navigates on it.
final eligibilityInteractorProvider =
    NotifierProvider<EligibilityInteractor, EligibilityState>(
  EligibilityInteractor.new,
);
