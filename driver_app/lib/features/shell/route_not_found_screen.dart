import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// The router's `errorBuilder` target — what a driver sees when navigation lands
/// on a path the route table does not contain.
///
/// **Why this screen exists.** Until Phase 2 the driver app had NO
/// `errorBuilder`, so go_router fell back to its own default: a bare grey page
/// reading "Page not found" above a raw exception dump, in a shipped app that a
/// driver uses in a moving car.
///
/// 🔴 **AND PHASE 2 IS THE PHASE THAT TURNS PUSH ON.** Deep links and FCM push
/// payloads carry paths from OUTSIDE the binary — no amount of route hygiene
/// inside `lib/` can constrain them, and the backend has published no push-event
/// schema at all (#15/#16), so the `deep_link` field is an ASSUMPTION. A single
/// stale or malformed path from the server and the driver is staring at a stack
/// trace instead of their next fare. The rider app learned this the expensive
/// way: seven live `context.go` targets resolved to nothing and every one of them
/// dropped the rider on that exception page, behind a green suite.
///
/// The driver's routes all currently resolve — `router_reachability_test.dart`
/// proves it against the REAL route table. This screen is what stands behind the
/// next one that does not.
///
/// It deliberately does NOT print the failed path or the exception. A driver can
/// do nothing with either, and showing internals to a user is the same category
/// of mistake as the default page it replaces.
class DriverRouteNotFoundScreen extends StatelessWidget {
  /// Creates the driver's designed not-found screen.
  const DriverRouteNotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    return Scaffold(
      backgroundColor: hoppin.colors.canvas,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(hoppin.spacing.gutter),
            child: HopEmptyState(
              headline: 'We could not open that page',
              supporting:
                  'That link does not point anywhere in the app. Nothing has '
                  'gone wrong with your shift or any trip — if you were online, '
                  'you still are. Head back and carry on.',
              actionLabel: 'Back to dashboard',
              // `go`, not `pop`: the failed navigation may BE the first route (a
              // cold-start push tap), in which case there is nothing beneath to
              // pop to and a pop would strand the driver here — a dead end
              // inside the dead-end screen.
              onAction: () => context.go('/'),
            ),
          ),
        ),
      ),
    );
  }
}
