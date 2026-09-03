import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/shared/widgets/async_view.dart';

/// 🔴 THE SCREEN THE DRIVER IS READING MUST NOT BE THROWN AWAY.
///
/// `AsyncValue.when` routes on the CURRENT state, so a refresh over data the
/// app already holds takes the `loading` branch and the screen blanks. On a
/// polling app that is not an edge case — it is every tick. Worse, Riverpod
/// delivers a FAILED future as `AsyncLoading` carrying the error, so a
/// loading-first ladder shows a spinner that never resolves and the driver is
/// never told the call died.
///
/// AsyncView asks value-first. These are the four cases that matters in.
void main() {
  Future<void> pump(WidgetTester tester, AsyncValue<String> value) =>
      tester.pumpWidget(
        MaterialApp(
          home: AsyncView<String>(
            value: value,
            data: (v, refreshing) =>
                Text(refreshing ? '$v (refreshing)' : v, key: const Key('d')),
            loading: () => const Text('SKELETON', key: Key('l')),
            error: (e, _) => Text('ERR $e', key: const Key('e')),
          ),
        ),
      );

  testWidgets('a cold start — and only a cold start — shows the placeholder',
      (tester) async {
    await pump(tester, const AsyncLoading<String>());

    expect(find.text('SKELETON'), findsOneWidget);
  });

  testWidgets('🔴 a refresh over held data KEEPS the data', (tester) async {
    // The exact shape Riverpod produces mid-refresh: loading, with the
    // previous value still attached. This is the case that blanked screens.
    const refreshing = AsyncLoading<String>();
    await pump(tester, refreshing.copyWithPrevious(const AsyncData('trips')));

    expect(find.text('SKELETON'), findsNothing,
        reason: 'the driver was reading this — a poll may not take it away');
    expect(find.byKey(const Key('d')), findsOneWidget);
    expect(find.text('trips (refreshing)'), findsOneWidget,
        reason: 'the caller is told it is stale, so it can dim or show a bar '
            '— but the content stays on screen either way');
  });

  testWidgets('a failure with data held keeps the data, not the error',
      (tester) async {
    const failed = AsyncError<String>('offline', StackTrace.empty);
    await pump(tester, failed.copyWithPrevious(const AsyncData('trips')));

    expect(find.text('ERR offline'), findsNothing,
        reason: 'a refresh that did not land is not a reason to throw away a '
            'screenful of perfectly good content');
    expect(find.byKey(const Key('d')), findsOneWidget);
  });

  testWidgets('a failure with NOTHING held is shown, never a spinner',
      (tester) async {
    await pump(tester, const AsyncError<String>('offline', StackTrace.empty));

    expect(find.text('ERR offline'), findsOneWidget,
        reason: 'nothing to fall back on: the driver must be told it failed, '
            'not left watching a spinner that never resolves');
  });

  testWidgets('settled data renders without the refreshing flag',
      (tester) async {
    await pump(tester, const AsyncData('trips'));

    expect(find.text('trips'), findsOneWidget);
  });
}
