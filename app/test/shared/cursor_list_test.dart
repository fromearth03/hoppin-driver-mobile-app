import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/shared/widgets/cursor_list.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders each item', (tester) async {
    await tester.pumpWidget(wrap(CursorList<String>(
      items: const ['a', 'b', 'c'],
      itemBuilder: (_, item) => Text(item),
    )));

    expect(find.text('a'), findsOneWidget);
    expect(find.text('c'), findsOneWidget);
  });

  testWidgets('shows the empty state instead of a blank screen',
      (tester) async {
    await tester.pumpWidget(wrap(CursorList<String>(
      items: const [],
      itemBuilder: (_, item) => Text(item),
      emptyState: const Text('No cancelled trips'),
    )));

    expect(find.text('No cancelled trips'), findsOneWidget);
  });

  testWidgets('offers load-more only when there is another page',
      (tester) async {
    await tester.pumpWidget(wrap(CursorList<String>(
      items: const ['a'],
      hasMore: true,
      onLoadMore: () {},
      itemBuilder: (_, item) => Text(item),
    )));
    expect(find.text('Load more'), findsOneWidget);

    await tester.pumpWidget(wrap(CursorList<String>(
      items: const ['a'],
      itemBuilder: (_, item) => Text(item),
    )));
    expect(find.text('Load more'), findsNothing);
  });

  testWidgets('load-more fires once and then shows progress', (tester) async {
    var calls = 0;
    await tester.pumpWidget(wrap(CursorList<String>(
      items: const ['a'],
      hasMore: true,
      onLoadMore: () => calls++,
      itemBuilder: (_, item) => Text(item),
    )));

    await tester.tap(find.text('Load more'));
    expect(calls, 1);

    await tester.pumpWidget(wrap(CursorList<String>(
      items: const ['a'],
      hasMore: true,
      isLoadingMore: true,
      onLoadMore: () => calls++,
      itemBuilder: (_, item) => Text(item),
    )));
    // A second tap while the page is in flight would duplicate the request.
    expect(find.text('Load more'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders a header above the list', (tester) async {
    await tester.pumpWidget(wrap(CursorList<String>(
      items: const ['a'],
      header: const Text('Balance'),
      itemBuilder: (_, item) => Text(item),
    )));

    expect(find.text('Balance'), findsOneWidget);
  });
}
