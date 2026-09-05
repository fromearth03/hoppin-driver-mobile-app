import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/home/logic/home_controller.dart';
import 'package:hoppin_driver/shared/nav/app_shell.dart';
import 'package:hoppin_driver/shared/widgets/app_ambience.dart';
import 'package:hoppin_driver/shared/widgets/app_glass.dart';
import 'package:hoppin_driver/shared/widgets/glass_card.dart';

class _Quiet extends HomeController {
  @override
  Future<HomeState> build() async => const HomeState();
}

void main() {
  testWidgets('the shell lays down the ambient ground', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [homeControllerProvider.overrideWith(_Quiet.new)],
      child: const MaterialApp(
        home: AppShell(currentIndex: 0, currentPath: '/', child: Text('x')),
      ),
    ));
    expect(find.byType(AppAmbience), findsOneWidget);
  });

  testWidgets('a GlassCard really renders glass', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: GlassCard(child: Text('inside'))),
    ));
    expect(find.byType(AppGlass), findsOneWidget);
    expect(find.text('inside'), findsOneWidget);
  });

  testWidgets('reduced transparency drops the blur, keeps the content',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(highContrast: true),
        child: Scaffold(body: GlassCard(child: Text('inside'))),
      ),
    ));
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('inside'), findsOneWidget);
  });
}
