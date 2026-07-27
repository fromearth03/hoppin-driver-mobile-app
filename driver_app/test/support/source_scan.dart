import 'dart:io';

/// Strips `//` line comments and `/* … */` blocks from Dart source before a
/// grep runs over it.
///
/// 🔴 THREE SEPARATE LANES IN THIS PROJECT HAVE BEEN BITTEN BY THE SAME BUG: a
/// doc comment EXPLAINING a ban was itself matched by the grep that ENFORCES
/// the ban. The guard cried wolf, and a guard that cries wolf gets deleted —
/// and then nothing is enforced at all. Every source assertion in Phase 4 runs
/// through here first. No exceptions.
///
/// The contract, and each clause is load-bearing:
///
///  - **Real code survives.** This is the assertion that matters most. A
///    stripper that over-strips returns an empty string for every file, every
///    guard built on it sweeps NOTHING, and they all pass *vacuously* — which
///    looks exactly like a clean codebase and is the quietest way for a sweep
///    to stop sweeping.
///  - **String literals survive.** `'TextField('` inside a literal is REAL
///    source. If someone builds a widget by name from a string we want to see
///    it, so a literal is never treated as prose.
///  - **Line count is preserved.** A guard's failure message quotes
///    `path:${i + 1}`, and that number is only the true offending line if every
///    input line still has exactly one output entry. Comments are BLANKED, not
///    dropped.
String stripDartComments(String source) {
  final out = StringBuffer();
  var inBlock = false;
  var inString = false;
  var quote = '';
  var i = 0;

  while (i < source.length) {
    final c = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';

    // Newlines always survive, whatever state we are in — the line count is
    // part of the contract.
    if (c == '\n') {
      out.write('\n');
      // An unterminated string cannot span a line in valid Dart (bar a raw
      // multiline, which we do not attempt to model); reset so one stray quote
      // in a comment cannot blind the rest of the file.
      inString = false;
      i++;
      continue;
    }

    if (inBlock) {
      if (c == '*' && next == '/') {
        inBlock = false;
        i += 2;
      } else {
        i++;
      }
      continue;
    }

    if (inString) {
      out.write(c);
      if (c == r'\') {
        // Escaped char: copy it verbatim so a `\'` cannot close the string.
        if (next.isNotEmpty && next != '\n') {
          out.write(next);
          i += 2;
          continue;
        }
      } else if (c == quote) {
        inString = false;
      }
      i++;
      continue;
    }

    // Not in a comment, not in a string.
    if (c == '/' && next == '/') {
      // Line comment: swallow to end of line. The `\n` itself is written by
      // the branch above on the next pass.
      while (i < source.length && source[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && next == '*') {
      inBlock = true;
      i += 2;
      continue;
    }
    if (c == "'" || c == '"') {
      inString = true;
      quote = c;
      out.write(c);
      i++;
      continue;
    }

    out.write(c);
    i++;
  }

  return out.toString();
}

/// One Dart source file, already comment-stripped — a caller cannot forget to
/// strip.
class ScannedSource {
  ScannedSource({required this.path, required this.text});

  /// Path as found on disk, forward-slashed so a guard's `contains('/trip/')`
  /// works identically on Windows.
  final String path;

  /// The file's source with every comment blanked. Line count is preserved, so
  /// `lines[i]` is genuinely line `i + 1` of the file on disk.
  final String text;

  late final List<String> lines = text.split('\n');
}

/// Reads every `.dart` file under [dir] (default: the driver app's own `lib/`),
/// comment-stripped.
///
/// `flutter test` runs from `apps/driver`, so a relative `lib` resolves to the
/// app's source tree. A guard that gets an EMPTY list back is sweeping nothing
/// and will pass vacuously — so callers assert `isNotEmpty` first, and so does
/// this helper's own suite.
List<ScannedSource> scanDartSources([String dir = 'lib']) {
  final root = Directory(dir);
  if (!root.existsSync()) return const [];
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map(
        (f) => ScannedSource(
          path: f.path.replaceAll(r'\', '/'),
          text: stripDartComments(f.readAsStringSync()),
        ),
      )
      .toList();
}
