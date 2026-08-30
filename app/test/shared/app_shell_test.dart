import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/shared/nav/app_shell.dart';

Widget wrap() => const ProviderScope(
      child: MaterialApp(home: AppShell(currentIndex: 0, child: Text('body'))),
    );

void main() {
  testWidgets('shows exactly the four locked tabs in order', (tester) async {
    await tester.pumpWidget(wrap());

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Earnings'), findsOneWidget);
    expect(find.text('Docs'), findsOneWidget);
    expect(find.text('Stats'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
  });

  testWidgets('Trips is not a bottom tab — it lives in the drawer',
      (tester) async {
    await tester.pumpWidget(wrap());

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    final labels = bar.destinations
        .map((d) => (d as NavigationDestination).label)
        .toList();
    expect(labels.contains('Trips'), isFalse);
  });

  testWidgets('drawer lists Trips and the account destinations',
      (tester) async {
    await tester.pumpWidget(wrap());
    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await tester.pumpAndSettle();

    expect(find.text('Trips'), findsOneWidget);
    expect(find.text('Personal Information'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Help & Support'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
