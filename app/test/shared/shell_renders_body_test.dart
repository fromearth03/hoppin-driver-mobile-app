import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/home/logic/home_controller.dart';
import 'package:hoppin_driver/shared/nav/app_shell.dart';
import 'package:hoppin_driver/shared/nav/tab_transition.dart';
import 'package:hoppin_driver/shared/widgets/revalidate_on_visit.dart';
import 'package:hoppin_driver/shared/widgets/scroll_edge_blur.dart';

/// The real authed tree, in the order `app.dart` composes it:
///
///   AppShell( Stack > Positioned.fill > TabSwitcher > ScrollEdgeBlur >
///             RevalidateOnVisit > <screen> )
///
/// The driver reported the bottom nav rendering over an otherwise empty
/// screen, on every tab, immediately after signing in — the login screen
/// itself was fine, and it sits outside this shell.
void main() {
  // The shell's OfferBanner watches the home controller, which would fire a
  // real request and leave a pending timer. This test is about layout, so the
  // controller is held in a state that never calls out.
  Widget shell(Widget screen) => ProviderScope(
        overrides: [
          homeControllerProvider.overrideWith(_QuietHome.new),
        ],
        child: MaterialApp(
          home: AppShell(
            currentIndex: 0,
            currentPath: '/',
            child: TabSwitcher(
              path: '/',
              child: ScrollEdgeBlur(
                child: RevalidateOnVisit(
                  revalidate: (_) {},
                  child: screen,
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('a screen inside the shell is given height to fill',
      (tester) async {
    late BoxConstraints seen;

    await tester.pumpWidget(shell(
      LayoutBuilder(builder: (context, constraints) {
        seen = constraints;
        return const SizedBox.shrink();
      }),
    ));

    expect(seen.maxHeight, greaterThan(0),
        reason: 'screen laid out with no height — this is the blank body');
  });

  testWidgets('a list screen inside the shell shows its rows', (tester) async {
    await tester.pumpWidget(shell(
      ListView(
        children: const [
          SizedBox(height: 40, child: Text('ROW ONE')),
          SizedBox(height: 40, child: Text('ROW TWO')),
        ],
      ),
    ));
    await tester.pump();

    expect(find.text('ROW ONE'), findsOneWidget);
    expect(tester.getSize(find.byType(ListView)).height, greaterThan(0));
  });
}

class _QuietHome extends HomeController {
  @override
  Future<HomeState> build() async => const HomeState();
}
