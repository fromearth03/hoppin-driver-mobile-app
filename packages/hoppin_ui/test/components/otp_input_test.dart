// OtpInput — Figma spec: 5 rounded-square boxes (radius control), single
// digit each, 1px navy border; onChanged reports the assembled code. Both
// rider themes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '_pump.dart';

void main() {
  for (final MapEntry(key: name, value: theme) in riderThemes.entries) {
    testWidgets('renders exactly 5 boxes ($name)', (tester) async {
      await pumpComponent(tester, theme, OtpInput(onChanged: (_) {}));
      expect(find.byType(EditableText), findsNWidgets(5));
    });

    testWidgets('typing across boxes assembles the code ($name)',
        (tester) async {
      String? code;
      await pumpComponent(
        tester,
        theme,
        OtpInput(onChanged: (v) => code = v),
      );
      final fields = find.byType(EditableText);
      await tester.enterText(fields.at(0), '1');
      await tester.pump();
      await tester.enterText(fields.at(1), '2');
      await tester.pump();
      await tester.enterText(fields.at(2), '3');
      await tester.pump();
      await tester.enterText(fields.at(3), '4');
      await tester.pump();
      await tester.enterText(fields.at(4), '5');
      await tester.pump();
      expect(code, '12345');
    });
  }
}
