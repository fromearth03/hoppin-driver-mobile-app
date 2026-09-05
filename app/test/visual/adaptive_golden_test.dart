import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/theme/colors.dart';
import 'package:hoppin_driver/features/earnings/ui/widgets/report_card.dart';
import 'package:hoppin_driver/features/home/data/models/driver_today.dart';
import 'package:hoppin_driver/features/home/ui/widgets/today_tiles.dart';
import 'package:hoppin_driver/features/stats/ui/widgets/stat_tile.dart';

/// The widgets that have actually broken on unexpected screen widths, pinned
/// at the narrowest phone we could be demoed on (320) and the widest common
/// one (430). A layout that ellipsizes here is fine; one that overflows or
/// letter-stacks fails the build.
///
/// Run with `flutter test --update-goldens test/visual/adaptive_golden_test.dart`.
void main() {
  Future<void> capture(
    WidgetTester tester,
    Widget child,
    String name,
    double width,
  ) async {
    tester.view.physicalSize = Size(width, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
        home: Scaffold(
          backgroundColor: AppColors.background,
          body: SingleChildScrollView(child: child),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  const today = DriverToday(
    earnings: Pence(4230),
    tripCount: 5,
    onlineTime: Duration(hours: 13, minutes: 42),
  );

  Widget statGrid() => Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // Takes the extent from the tile itself, exactly as the stats
          // screen does. A hardcoded number here drifted from production and
          // the goldens then pinned a layout the app had stopped using.
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: StatTile.heightFor(context),
          ),
          children: const [
            StatTile(
              icon: Icons.check_rounded,
              tint: AppColors.positive,
              label: 'Acceptance Rate',
              value: '96%',
            ),
            StatTile(
              icon: Icons.close_rounded,
              tint: AppColors.statRed,
              label: 'Cancellation Rate',
              value: '4%',
              note: '2 you cancelled',
            ),
          ],
        ),
      ));

  for (final width in const [320.0, 430.0]) {
    final w = width.toInt();

    testWidgets('earnings report card at $w', (tester) async {
      await capture(tester, const Padding(
        padding: EdgeInsets.all(8),
        child: ReportCard(),
      ), 'adaptive_report_$w', width);
    });

    testWidgets('today tiles at $w', (tester) async {
      await capture(
          tester, const TodayTiles(today: today), 'adaptive_today_$w', width);
    });

    testWidgets('stat tiles at $w', (tester) async {
      await capture(tester, statGrid(), 'adaptive_stats_$w', width);
    });
  }
}
