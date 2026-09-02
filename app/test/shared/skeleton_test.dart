import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/shared/widgets/skeleton.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('a skeleton line holds real height so nothing jumps when the '
      'content lands', (tester) async {
    await tester.pumpWidget(wrap(const SkeletonBox(height: 20, width: 120)));
    await tester.pump(const Duration(milliseconds: 100));

    final box = tester.getSize(find.byType(SkeletonBox));
    expect(box.height, 20);
    expect(box.width, 120);
  });

  testWidgets('the shimmer keeps moving', (tester) async {
    await tester.pumpWidget(wrap(const SkeletonBox(height: 20, width: 120)));
    await tester.pump(const Duration(milliseconds: 100));
    final first = tester.widget<Opacity>(
      find.descendant(
        of: find.byType(SkeletonBox),
        matching: find.byType(Opacity),
      ),
    ).opacity;

    await tester.pump(const Duration(milliseconds: 500));
    final later = tester.widget<Opacity>(
      find.descendant(
        of: find.byType(SkeletonBox),
        matching: find.byType(Opacity),
      ),
    ).opacity;

    // A still skeleton reads as a broken screen rather than a loading one.
    expect(first, isNot(equals(later)));
  });

  testWidgets('a card skeleton draws the shape of the row it stands in for',
      (tester) async {
    await tester.pumpWidget(wrap(const SkeletonList(rows: 3)));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SkeletonBox), findsWidgets);
  });

  testWidgets('the list stands in for exactly the rows it was asked for',
      (tester) async {
    await tester.pumpWidget(wrap(const SkeletonList(rows: 2)));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SkeletonCard), findsNWidgets(2));
  });
}
