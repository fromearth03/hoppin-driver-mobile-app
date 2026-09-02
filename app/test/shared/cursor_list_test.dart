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

  testWidgets('fetches the next page as the end comes into view',
      (tester) async {
    var calls = 0;
    final controller = ScrollController();
    await tester.pumpWidget(wrap(CursorList<String>(
      items: List.generate(30, (i) => 'row $i'),
      hasMore: true,
      onLoadMore: () => calls++,
      scrollController: controller,
      itemBuilder: (_, item) => SizedBox(height: 80, child: Text(item)),
    )));
    await tester.pump();

    // Nothing asked for while the driver is at the top.
    expect(calls, 0);

    controller.jumpTo(controller.position.maxScrollExtent - 100);
    await tester.pump();

    // Reaching the end fetched the next page without the driver having to
    // find and tap a button.
    expect(calls, 1);
  });

  testWidgets('does not fetch twice for one approach to the end',
      (tester) async {
    var calls = 0;
    final controller = ScrollController();
    Widget build({required bool loading}) => wrap(CursorList<String>(
          items: List.generate(30, (i) => 'row $i'),
          hasMore: true,
          isLoadingMore: loading,
          onLoadMore: () => calls++,
          scrollController: controller,
          itemBuilder: (_, item) => SizedBox(height: 80, child: Text(item)),
        ));

    await tester.pumpWidget(build(loading: false));
    await tester.pump();
    controller.jumpTo(controller.position.maxScrollExtent - 100);
    await tester.pump();
    expect(calls, 1);

    // A page already in flight must not be requested again by the next
    // scroll frame — that is how a cursor list double-posts and duplicates
    // rows.
    await tester.pumpWidget(build(loading: true));
    controller.jumpTo(controller.position.maxScrollExtent - 40);
    await tester.pump();

    expect(calls, 1);
  });

  testWidgets('the last page never asks for another', (tester) async {
    var calls = 0;
    final controller = ScrollController();
    await tester.pumpWidget(wrap(CursorList<String>(
      items: List.generate(30, (i) => 'row $i'),
      onLoadMore: () => calls++,
      scrollController: controller,
      itemBuilder: (_, item) => SizedBox(height: 80, child: Text(item)),
    )));
    await tester.pump();

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();

    expect(calls, 0);
  });
}
