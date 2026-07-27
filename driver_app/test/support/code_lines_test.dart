import 'package:flutter_test/flutter_test.dart';

import 'code_lines.dart';

/// 🔴 THE SANITY SUITE **IS** THE DELIVERABLE.
///
/// `codeLines()` is the filter every source-grep guard in this app stands on.
/// If it were ever broken to return `''` for every line, every one of those
/// guards would pass **vacuously** — sweeping an app full of the exact thing
/// they forbid and reporting green. Nobody would notice, because a guard that
/// never fires looks identical to a guard with nothing to find.
///
/// **A filter nobody has watched work is how a sweep quietly stops sweeping.**
///
/// So the filter is watched here, and the load-bearing assertion is not
/// "comments are blanked" — it is **"real code survives"**.
void main() {
  group('codeLines', () {
    test('🔴 REAL CODE SURVIVES — if this breaks, every sweep is blind', () {
      final stripped = codeLines([
        "/// we deliberately have no 'Create account' button",
        "const label = 'Create account';",
        '/* block',
        'Sign up',
        '*/ const other = 1;',
        'someCall(); // Sign up',
      ].join('\n'));

      expect(stripped[0].trim(), isEmpty, reason: 'doc comment must be blanked');
      expect(
        stripped[1],
        contains('Create account'),
        reason: 'REAL CODE MUST SURVIVE — if this breaks, the sweep is blind',
      );
      expect(stripped[3].trim(), isEmpty, reason: 'block comment body blanked');
      expect(
        stripped[4],
        contains('const other'),
        reason: 'code after a block comment ends must survive',
      );
      expect(stripped[5], contains('someCall'));
      expect(stripped[5], isNot(contains('Sign up')));
    });

    test('a `///` doc comment is blanked but the LINE survives as an entry', () {
      // Blanked, not dropped: a guard's failure message quotes `path:${i + 1}`,
      // and that number is only the real offending line if every input line
      // still has an output entry.
      final stripped = codeLines('/// prose\nfinal x = 1;\n/// more prose');

      expect(stripped, hasLength(3));
      expect(stripped[0].trim(), isEmpty);
      expect(stripped[1], contains('final x = 1;'));
      expect(stripped[2].trim(), isEmpty);
    });

    test('a trailing `//` comment goes, the code before it stays', () {
      final stripped = codeLines("Text('Valid'); // a comment saying Valid");

      expect(stripped.single, contains("Text('Valid')"));
      expect(stripped.single, isNot(contains('a comment saying')));
    });

    test('a `/* … */` body is blanked and code after the close survives', () {
      final stripped = codeLines(
        'final a = 1; /* banned\nstill banned\nstill banned */ final b = 2;',
      );

      expect(stripped, hasLength(3));
      expect(stripped[0], contains('final a = 1;'));
      expect(stripped[0], isNot(contains('banned')));
      expect(stripped[1].trim(), isEmpty);
      expect(stripped[2], contains('final b = 2;'));
      expect(stripped[2], isNot(contains('banned')));
    });

    test('a single-line /* … */ does not swallow the rest of the file', () {
      // The block-comment state machine must CLOSE on the same line. If it
      // latched open, every subsequent line in the file would be blanked and
      // the sweep would go silently blind from that point down.
      final stripped = codeLines(
        'final a = 1; /* short */ final b = 2;\nconst banned = true;',
      );

      expect(stripped[0], contains('final a = 1;'));
      expect(stripped[0], contains('final b = 2;'));
      expect(stripped[1], contains('const banned = true;'));
    });

    test('output has exactly as many entries as the input has lines', () {
      expect(codeLines('a\nb\nc\nd'), hasLength(4));
      expect(codeLines(''), hasLength(1));
    });
  });

  group('driverSources', () {
    test('🔴 reads the REAL lib/ tree, and the text is already comment-free',
        () {
      // `flutter test` runs from apps/driver, so a relative `lib` resolves to
      // the app's own source tree. If this ever returned empty, every guard
      // built on it would sweep NOTHING and pass.
      final sources = driverSources();

      expect(
        sources,
        isNotEmpty,
        reason:
            'driverSources() found no .dart files under lib/. Every guard '
            'built on it is now sweeping an empty set and passing vacuously.',
      );
      expect(sources.every((s) => s.path.endsWith('.dart')), isTrue);
      expect(
        sources.any((s) => s.path.replaceAll(r'\', '/').endsWith('router.dart')),
        isTrue,
        reason: 'the real lib/ tree contains router.dart',
      );

      // The text handed to a guard has ALREADY been through codeLines() — a
      // caller cannot forget to strip.
      final router = sources.firstWhere(
        (s) => s.path.replaceAll(r'\', '/').endsWith('router.dart'),
      );
      expect(router.text.split('\n'), hasLength(router.lines.length));
      expect(
        router.text,
        isNot(contains('///')),
        reason: 'driverSources().text must already be comment-stripped',
      );
    });
  });
}
