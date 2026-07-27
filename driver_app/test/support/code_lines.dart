import 'dart:io';

/// Blanks comment text, keeps code, and PRESERVES LINE NUMBERS.
///
/// 🔴 THE TRAP THIS CLOSES, WHICH THIS PROJECT HAS FALLEN INTO THREE TIMES.
///
/// A source guard greps `lib/` for a banned construct. The codebase, being a
/// good one, DOCUMENTS the ban at length — in doc comments, in the very files
/// the guard scans. A raw-text grep matches the prose explaining the rule and
/// goes RED on a CORRECT codebase.
///
/// A test that is red when nothing is wrong gets deleted within the month, and
/// the app is then left with NO GUARD AT ALL. That is a strictly worse outcome
/// than never writing the guard.
///
/// A comment saying "Valid" ships no badge. `Text('Valid')` does. Those are
/// what a guard must look for: **the executable ones.**
///
/// Lines are BLANKED, not dropped, so a failure message can name the real line
/// number.
///
/// This is the ONE copy. It was inline in `no_self_signup_test.dart`; three
/// more guards need it, and four copies of a filter is four chances for one of
/// them to rot into `''` unnoticed while its suite stays green.
///
/// Extracting it found a hole the inline version had shipped with: a block
/// comment that OPENED AND CLOSED ON ONE LINE truncated the line at `/*` and
/// discarded the code after `*/`. `foo(); /* note */ bar();` was swept as
/// `foo();` and `bar()` was never seen. The inline sanity test only ever closed
/// a block on a LATER line, so it never asked. That is the whole argument for
/// the suite next door: the hole was found the moment somebody watched the
/// filter work on a case it had not been watched on before.
List<String> codeLines(String text) {
  final out = <String>[];
  var inBlockComment = false;

  for (var line in text.split('\n')) {
    if (inBlockComment) {
      final end = line.indexOf('*/');
      if (end == -1) {
        out.add('');
        continue;
      }
      inBlockComment = false;
      line = line.substring(end + 2);
    }

    // Blocks may open AND close several times on one line, and code can sit
    // between and after them. The inline version of this loop truncated at the
    // first `/*` and threw away everything past the matching `*/` — so
    // `foo(); /* note */ bar();` swept `foo()` and never saw `bar()`. That is a
    // silent hole in every guard built on this, and a silent hole in a sweep is
    // indistinguishable from a clean codebase. Splice the tail back in instead.
    var blockStart = line.indexOf('/*');
    while (blockStart != -1) {
      final end = line.indexOf('*/', blockStart + 2);
      if (end == -1) {
        // Runs to end of line — the block stays open into the next line.
        inBlockComment = true;
        line = line.substring(0, blockStart);
        break;
      }
      line = line.substring(0, blockStart) + line.substring(end + 2);
      blockStart = line.indexOf('/*');
    }

    // `///` doc comments and `//` line comments alike.
    final lineStart = line.indexOf('//');
    if (lineStart != -1) line = line.substring(0, lineStart);

    out.add(line);
  }
  return out;
}

/// Every `.dart` file under [dir] (default `lib`), as (path, codeOnlyText).
///
/// The `text` has ALREADY been through [codeLines] and rejoined, so a caller
/// cannot forget to strip — which is precisely the mistake this whole helper
/// exists to make impossible. `lines` is the same content unjoined, for a
/// failure message that wants to quote `path:${i + 1}`.
///
/// Paths are relative to the package root because `flutter test` runs from
/// `apps/driver`.
List<({String path, String text, List<String> lines})> driverSources({
  String dir = 'lib',
}) {
  return Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) {
    final lines = codeLines(f.readAsStringSync());
    return (path: f.path, text: lines.join('\n'), lines: lines);
  }).toList();
}
