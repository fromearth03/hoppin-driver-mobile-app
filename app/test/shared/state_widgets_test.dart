import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/shared/widgets/app_empty_state.dart';
import 'package:hoppin_driver/shared/widgets/app_error_state.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('empty state shows its own title, not a generic one',
      (tester) async {
    await tester.pumpWidget(wrap(const AppEmptyState(
        icon: Icons.receipt_long, title: 'No cancelled trips')));

    expect(find.text('No cancelled trips'), findsOneWidget);
  });

  testWidgets('error state shows mapped copy, never the raw server message',
      (tester) async {
    await tester.pumpWidget(wrap(AppErrorState(
        error:
            ApiException('STORAGE_DISABLED', 'bucket offline: s3 500', 503))));

    expect(find.textContaining('temporarily unavailable'), findsOneWidget);
    expect(find.textContaining('s3'), findsNothing);
  });

  testWidgets('retry is offered only for retryable failures', (tester) async {
    await tester.pumpWidget(wrap(AppErrorState(
        error: ApiException('INTERNAL', '', 500), onRetry: () {})));
    expect(find.text('Try again'), findsOneWidget);

    await tester.pumpWidget(wrap(AppErrorState(
        error: ApiException('ACCOUNT_SUSPENDED', '', 403), onRetry: () {})));
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('retry fires the callback', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(wrap(AppErrorState(
        error: ApiException('INTERNAL', '', 500), onRetry: () => tapped++)));

    await tester.tap(find.text('Try again'));
    expect(tapped, 1);
  });
}
