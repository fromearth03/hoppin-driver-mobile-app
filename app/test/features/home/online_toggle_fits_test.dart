import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/home/ui/widgets/online_toggle.dart';

/// The busy pill overflowed its own track on a real handset: "Going online…"
/// plus its spinner needed more chip than the fixed 168px track allowed.
///
/// The label sits in a `Flexible` with `TextOverflow.ellipsis`, so Flutter
/// truncates it *gracefully* — no overflow exception is thrown and the widget
/// tree looks healthy. The only way to catch this is to measure: the painted
/// text must be as wide as the same string laid out unconstrained, and the
/// chip must fit inside its track.
void main() {
  Widget host(Widget child) => MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(height: 56, child: Center(child: child)),
          ),
        ),
      );

  /// What the string needs when nothing constrains it.
  double naturalWidth(String s, TextStyle style) {
    final p = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return p.width;
  }

  testWidgets('busy shows a spinner and no words', (tester) async {
    await tester.pumpWidget(host(
      const OnlineToggle(isOnline: false, isBusy: true),
    ));
    await tester.pump();

    // The words and the trailing ellipsis said nothing the spinner does not,
    // and the ellipsis read as truncated text rather than as motion.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('Going'), findsNothing);
    expect(find.textContaining('…'), findsNothing);
  });

  testWidgets('the resting label is painted in full, not ellipsised',
      (tester) async {
    await tester.pumpWidget(host(
      OnlineToggle(isOnline: false, onChanged: (_) {}),
    ));
    await tester.pump();

    final finder = find.text('Go online');
    final style = tester.widget<Text>(finder).style!;
    expect(tester.getSize(finder).width,
        greaterThanOrEqualTo(naturalWidth('Go online', style) - 0.5));
  });

  testWidgets('going offline is painted in full too', (tester) async {
    await tester.pumpWidget(host(
      OnlineToggle(isOnline: true, onChanged: (_) {}),
    ));
    await tester.pump();

    final finder = find.text('Go offline');
    final style = tester.widget<Text>(finder).style!;
    expect(tester.getSize(finder).width,
        greaterThanOrEqualTo(naturalWidth('Go offline', style) - 0.5));
  });

  testWidgets('the chip fits within its track in every state', (tester) async {
    for (final online in [false, true]) {
      for (final busy in [false, true]) {
        await tester.pumpWidget(host(
          OnlineToggle(isOnline: online, isBusy: busy, onChanged: (_) {}),
        ));
        await tester.pump();

        final containers = find.byType(Container);
        final track = tester.getSize(containers.first);
        final chip = tester.getSize(containers.last);

        expect(chip.width, lessThanOrEqualTo(track.width),
            reason: 'chip escapes the track (online=$online busy=$busy)');
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('the track does not resize between rest and busy', (tester) async {
    await tester.pumpWidget(host(
      const OnlineToggle(isOnline: false, onChanged: null),
    ));
    await tester.pump();
    final resting = tester.getSize(find.byType(Container).first).width;

    await tester.pumpWidget(host(
      const OnlineToggle(isOnline: false, isBusy: true),
    ));
    await tester.pump();
    final busy = tester.getSize(find.byType(Container).first).width;

    // A track that grew when the label changed would make the control jump
    // sideways under the driver's finger.
    expect(busy, resting);
  });

  testWidgets('a larger text scale still paints the label in full',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: Scaffold(
          body: Center(
            child: OnlineToggle(isOnline: false, onChanged: (_) {}),
          ),
        ),
      ),
    ));
    await tester.pump();

    final finder = find.text('Go online');
    final style = tester.widget<Text>(finder).style!;
    final needed = TextPainter(
      text: TextSpan(text: 'Go online', style: style),
      textDirection: TextDirection.ltr,
      textScaler: const TextScaler.linear(1.3),
    )..layout();

    expect(tester.getSize(finder).width,
        greaterThanOrEqualTo(needed.width - 0.5));
  });
}
