import 'package:flutter_test/flutter_test.dart';

import 'source_scan.dart';

/// 🔴 THE FILTER IS WATCHED, BECAUSE AN UNWATCHED FILTER IS HOW A SWEEP GOES
/// BLIND.
///
/// `stripDartComments()` is what every source grep in Phase 4 stands on. If it
/// were broken to return `''`, every one of those guards would pass VACUOUSLY —
/// sweeping an app full of the exact thing they forbid and reporting green.
/// Nobody would notice, because a guard that never fires looks identical to a
/// guard with nothing to find.
///
/// So the load-bearing assertion here is not "comments are blanked". It is
/// **"real code survives"**.
void main() {
  group('stripDartComments', () {
    test('🔴 REAL CODE SURVIVES — if this breaks, every sweep is blind', () {
      final stripped = stripDartComments([
        '/// we deliberately forbid TextField( on this surface',
        'const composer = TextField();',
        '/* block',
        'TextField(',
        '*/ const other = 1;',
        'someCall(); // TextField(',
      ].join('\n')).split('\n');

      expect(stripped[0].trim(), isEmpty, reason: 'doc comment must be blanked');
      expect(
        stripped[1],
        contains('TextField()'),
        reason: 'REAL CODE MUST SURVIVE — if this breaks, the sweep is blind',
      );
      expect(stripped[3].trim(), isEmpty, reason: 'block comment body blanked');
      expect(
        stripped[4],
        contains('const other'),
        reason: 'code after a block comment closes must survive',
      );
      expect(stripped[5], contains('someCall'));
      expect(stripped[5], isNot(contains('TextField')));
    });

    test('a `//` line comment containing TextField( is stripped', () {
      final stripped =
          stripDartComments('// never put a TextField( here\nfinal x = 1;');

      expect(stripped.split('\n')[0].trim(), isEmpty);
      expect(stripped, isNot(contains('TextField')));
      expect(stripped, contains('final x = 1;'));
    });

    test('a `/* … */` block containing TextField( is stripped', () {
      final stripped = stripDartComments(
        'final a = 1; /* banned: TextField(\nstill TextField( */ final b = 2;',
      );

      expect(stripped, isNot(contains('TextField')));
      expect(stripped, contains('final a = 1;'));
      expect(stripped, contains('final b = 2;'));
    });

    test('🔴 a STRING LITERAL containing TextField( is KEPT', () {
      // A literal is real source. If someone builds a widget by name from a
      // string, we want the guard to see it — prose is what we are filtering,
      // not code that happens to be quoted.
      final stripped = stripDartComments("const name = 'TextField(';");

      expect(stripped, contains("'TextField('"));
    });

    test('a `//` INSIDE a string literal is not treated as a comment', () {
      final stripped = stripDartComments("const url = 'https://x.dev/a';");

      expect(stripped, contains('https://x.dev/a'));
    });

    test('an escaped quote does not close the string early', () {
      final stripped = stripDartComments(r"const s = 'it\'s // fine';");

      expect(stripped, contains('fine'));
    });

    test('a single-line /* … */ does not swallow the rest of the file', () {
      // If the block state latched open, every later line would be blanked and
      // the sweep would go silently blind from that point down.
      final stripped = stripDartComments(
        'final a = 1; /* short */ final b = 2;\nconst banned = true;',
      );

      expect(stripped, contains('final a = 1;'));
      expect(stripped, contains('final b = 2;'));
      expect(stripped, contains('const banned = true;'));
    });

    test('output has exactly as many lines as the input', () {
      // A guard's failure quotes `path:${i + 1}` — that number is only the real
      // offending line if comments are BLANKED rather than dropped.
      expect(stripDartComments('a\nb\nc\nd').split('\n'), hasLength(4));
      expect(stripDartComments('').split('\n'), hasLength(1));
      expect(
        stripDartComments('/// prose\nfinal x = 1;\n/// more').split('\n'),
        hasLength(3),
      );
    });
  });

  group('scanDartSources', () {
    test('🔴 reads the REAL lib/ tree, and the text is already comment-free',
        () {
      final sources = scanDartSources();

      expect(
        sources,
        isNotEmpty,
        reason: 'scanDartSources() found no .dart files under lib/. Every '
            'guard built on it is now sweeping an empty set and passing '
            'vacuously.',
      );
      expect(sources.every((s) => s.path.endsWith('.dart')), isTrue);
      expect(
        sources.any((s) => s.path.endsWith('router.dart')),
        isTrue,
        reason: 'the real lib/ tree contains router.dart',
      );

      final router = sources.firstWhere((s) => s.path.endsWith('router.dart'));
      expect(
        router.text,
        isNot(contains('///')),
        reason: 'scanDartSources().text must already be comment-stripped',
      );
      expect(
        router.text,
        contains('GoRoute'),
        reason: 'REAL CODE MUST SURVIVE the strip',
      );
    });
  });
}
