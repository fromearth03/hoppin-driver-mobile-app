import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_driver/features/shell/route_not_found_screen.dart';
import 'package:hoppin_driver/router.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🔴 EVERY NAVIGATION TARGET IN `lib/` MUST RESOLVE AGAINST THE REAL ROUTE
/// TABLE — asked of the ROUTER, never of the source.
///
/// **This is prophylactic here, and it is deliberately not waiting for a bug.**
/// The driver's routes all currently resolve; nothing in `lib/` is dead today.
/// The rider app's did too, right up until they did not — Phase 12's honesty
/// audit found SEVEN live `context.go` targets that pointed at routes
/// `router.dart` did not contain (the four Profile-hub rows, both legal links,
/// and a `/wallet` quick-link that had never existed at all). Every one of them
/// dropped the rider on go_router's raw exception page.
///
/// **The suite was green throughout, and it was green BECAUSE OF HOW IT WAS
/// WRITTEN.** Three test files hand-built a throwaway `GoRouter` containing
/// exactly the `GoRoute` production was missing, then asserted the screen
/// rendered at it. A test that builds its own router proves its own router
/// works. It cannot, even in principle, see that the app's router lacks the
/// route — and it READS like integration coverage, which makes it worse than a
/// bare-harness test, not better.
///
/// The other near-miss is worth naming because it looks like this check and is
/// not: a rider test asserted its legal routes by GREPPING the screen's own
/// source for the string `/legal/privacy`. It passed. The path was in the
/// source; it just did not resolve anywhere.
///
/// So this file asks `router.configuration.findMatch` — go_router's own
/// resolver, the same code that decides at runtime whether a driver sees a
/// screen or a stack trace — against the REAL `driverRouterProvider`. It builds
/// no router of its own, and it must never be allowed to.
void main() {
  /// Every string literal passed to `context.go(...)` / `context.push(...)` in
  /// `lib/`, with its file and line, so a failure names the call site.
  ///
  /// Deliberately literal-only. A computed target (`'/trip/$rideId'`) cannot be
  /// resolved statically; the interpolated ones are pinned explicitly below.
  /// Better to check exactly what we CAN check than to half-check everything
  /// with a regex that lies.
  final navTargets = <({String path, String file, int line})>[];

  setUpAll(() {
    final callPattern = RegExp(
      r"""(?:context|GoRouterHelper\([^)]*\))\.(?:go|push|replace|pushReplacement)\(\s*'([^'$]+)'""",
    );
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final m in callPattern.allMatches(lines[i])) {
          navTargets.add((path: m.group(1)!, file: file.path, line: i + 1));
        }
      }
    }
  });

  /// The real router, built exactly as the app builds it.
  GoRouter buildRouter() {
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(_RoutingOnlyAuthService()),
      ],
    );
    addTearDown(container.dispose);
    return container.read(driverRouterProvider);
  }

  bool resolves(GoRouter router, String path) =>
      router.configuration.findMatch(Uri.parse(path)).routes.isNotEmpty;

  test(
      '🔴 every context.go/push literal in lib/ resolves against the REAL route '
      'table', () {
    final router = buildRouter();
    final dead = navTargets.where((t) => !resolves(router, t.path)).toList();

    expect(
      dead,
      isEmpty,
      reason:
          'These navigation targets exist in apps/driver/lib but NOT in the '
          'router. Each one drops the DRIVER on go_router\'s error page — '
          'mid-shift, in a moving car.\n\n'
          '${dead.map((t) => '  ${t.file}:${t.line} → ${t.path}').join('\n')}\n\n'
          'This is the check the rider app did not have. Seven such targets '
          'shipped there behind a green suite, because three test files built '
          'their OWN GoRouter containing exactly the route production lacked.\n\n'
          'If you are here because you added a route: add it to router.dart. Do '
          'NOT add it to a test-local router.',
    );
  });

  test('the parameterised routes resolve for a representative id', () {
    // The literal sweep skips interpolated targets (`'/trip/$rideId'`) by
    // design — a static check cannot resolve them. They are not thereby exempt,
    // so they are pinned here. Adding a new `/x/:id` route means adding a line
    // here; that friction is the point.
    final router = buildRouter();
    for (final path in const ['/trip/ride-1']) {
      expect(resolves(router, path), isTrue,
          reason: '$path must resolve — it is reached by interpolation '
              '(`/trip/\$rideId`), which the literal sweep cannot see');
    }
  });

  test('the driver app\'s three real surfaces are in the REAL route table', () {
    // Named explicitly, not merely covered by the sweep. The sweep only proves
    // that *what lib/ asks for* resolves — delete the only `context.go('/offer')`
    // and the route with it, and the sweep goes green on an app with no offer
    // surface at all. These three are owed regardless of who links to them.
    final router = buildRouter();
    for (final path in const ['/', '/offer', '/login']) {
      expect(resolves(router, path), isTrue,
          reason: 'the driver app has a screen for $path. A screen with no route '
              'is not shipped — it is dead code.');
    }
  });

  test('sanity: the resolver can actually say NO', () {
    final router = buildRouter();
    expect(resolves(router, '/this-route-does-not-exist'), isFalse,
        reason: 'if the resolver said yes to everything, every assertion above '
            'would be vacuous');
    expect(router.configuration.topRedirect, isNotNull,
        reason: 'sanity: the router under test is the real one');
  });

  testWidgets(
      '🔴 an unresolvable path RENDERS a designed screen, not an exception dump',
      (tester) async {
    // 🔴 THIS PUMPS THE REAL ROUTER AT A BAD PATH. It does NOT grep
    // `router.dart` for the string "errorBuilder", and the difference is not
    // pedantry — I tried the grep first and it PASSED with the errorBuilder
    // deleted, because the word also appears in the comment above it. That is
    // the exact failure mode the rider's own test file warns about: a rider test
    // once "proved" its legal routes by grepping a screen's source for
    // `/legal/privacy`. It passed. The path was in the source; it just did not
    // resolve anywhere.
    //
    // A guard you have not watched fail is not a guard. This one fails: delete
    // the errorBuilder from router.dart and it goes RED, because go_router
    // renders its own grey "Page not found" + raw exception instead.
    //
    // Why it matters MORE for the driver than it did for the rider: Phase 2 is
    // the phase that turns push ON. FCM payloads carry `deep_link` values from
    // OUTSIDE the binary, against a schema the backend has never published
    // (#15/#16). No amount of route hygiene inside lib/ can constrain a path the
    // server sends. Only a designed screen can make it survivable.
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(_RoutingOnlyAuthService()),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(driverRouterProvider);

    router.go('/a-push-payload-pointed-here-and-it-does-not-exist');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: HoppinTheme.driverDark(),
          routerConfig: router,
        ),
      ),
    );
    // Bounded pumps — never pumpAndSettle.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 350));
    }

    expect(
      find.byType(DriverRouteNotFoundScreen),
      findsOneWidget,
      reason: 'router.dart must set an errorBuilder pointing at '
          'DriverRouteNotFoundScreen. Without one, go_router renders its own '
          'default: a grey page reading "Page not found" over a RAW EXCEPTION '
          'DUMP — in a shipped app, to a driver in a moving car.',
    );
    expect(
      find.text('Back to dashboard'),
      findsOneWidget,
      reason: 'a designed dead end that offers no way out is still a dead end. '
          'It must `go`, not `pop`: the failed navigation may BE the first route '
          '(a cold-start push tap), in which case there is nothing beneath to '
          'pop to and a pop would strand the driver inside the dead-end screen.',
    );
  });
}

/// The router reads exactly two things off [AuthService]: `isSignedIn` (the
/// redirect) and `onAuthStateChange` (the refresh listenable). Everything else
/// throws, so that a future router change which quietly starts depending on more
/// of the auth surface fails loudly here instead of silently passing.
class _RoutingOnlyAuthService implements AuthService {
  @override
  bool get isSignedIn => true;

  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'router_reachability_test drives ONLY the route table. The router '
        'reached for ${invocation.memberName} — if that is deliberate, add it '
        'to this fake explicitly.',
      );
}
