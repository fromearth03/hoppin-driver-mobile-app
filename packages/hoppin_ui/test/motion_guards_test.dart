// Motion guards — a permanent source sweep locking the performance rules
// (driver-ux-motion §5 globals) into the suite. Same pattern as hoppin_demo's
// wall-clock guard: read every lib/ source and assert the banned patterns never
// land. This test is the regression lock for Phase 6 and beyond — do not delete
// or weaken it.
//
// 🔴 THE RULES OUTLIVED THEIR ORIGINAL REASON. These bans were written for the
// WEB frame budget (saveLayer jank, Skia's blur divergence). Web was dropped on
// 2026-07-16 — both apps are iOS + Android now — and the bans STAND anyway,
// because the web was never the only reason for them:
//
//   - One blur site is a design rule before it is a perf rule. Two hand-rolled
//     blurs drift apart and start reading as two different materials; that is
//     true on any platform, and it is why the exemption is a FILE.
//   - A saveLayer is still the most expensive thing in a frame on a mid-range
//     Android, and "blur wherever it's needed" is still an unbounded number of
//     them that nobody is counting.
//   - An animated sigma still re-rasterises the backdrop every frame.
//
// So do not relax these because the web caveat expired. If one is ever genuinely
// wrong for native, argue it on native's terms and change the RULE — do not let
// it rot into a comment that no longer matches the code.
//
// The rules, as enforced:
// 1. Blur is CONTAINED, not free. saveLayer-backed filters are the single
//    worst web jank source, so `BackdropFilter` / `ImageFilter.blur` /
//    `MaskFilter` remain banned in every file but ONE — `hop_glass.dart`, the
//    single frosted-chrome primitive (see the exemption's own note below).
//    Nothing else in the package may blur, and the blurred surface may not
//    animate its sigma.
// 2. No Opacity widget in components — FadeTransition and paint colour
//    alpha are the sanctioned fades (Opacity forces a saveLayer per frame
//    when animated).
// 3. Every looping animator (any component that calls `.repeat(`) sits
//    inside a RepaintBoundary so its frames never repaint the tree.
// 4. No wall-clock reads: time enters via package:clock only.
// 5. No inline Duration literals in component animation code — every
//    duration is a HoppinMotion token (or a caller-supplied parameter).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<File> dartFilesUnder(String path) {
  final files = Directory(path)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
  expect(files, isNotEmpty, reason: 'sweep found no sources under $path');
  return files;
}

/// A file's CODE, with comments stripped.
///
/// These sweeps grep source TEXT, and source text includes prose. Without this,
/// a file that merely EXPLAINS why blur is banned trips the ban — the guard
/// punishes the one thing you most want people to write down, and the only way
/// to get green is to stop documenting the rule. (`shell_chrome_test` in the
/// rider app learned this the hard way: two screens were falsely accused of
/// shipping `onBack: null` because their comments quoted the bug verbatim while
/// explaining it.) A guard reads code, not commentary.
String codeOf(File f) => f
    .readAsStringSync()
    .replaceAll(RegExp(r'^\s*///.*$', multiLine: true), '')
    .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '')
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');

void main() {
  // Split every banned literal so this file can never match itself in a
  // broader sweep (the hoppin_demo guard convention).
  const backdropFilter = 'Backdrop' 'Filter';
  const imageFilterBlur = 'ImageFilter' '.blur';
  // Composing is how you smuggle a blur past a sweep that only greps for
  // `.blur` — the compose sits at the call site and the blur hides behind a
  // local. Banned by the same rule, for the same reason.
  const imageFilterCompose = 'ImageFilter' '.compose';
  const maskFilter = 'Mask' 'Filter';
  const opacityWidget = 'Opacity' '(';
  const wallClock = 'DateTime.now' '()';
  const repeatCall = '.repeat' '(';
  const repaintBoundary = 'Repaint' 'Boundary';
  const durationLiterals = <String>[
    'Duration' '(milliseconds',
    'Duration' '(seconds',
    'Duration' '(minutes',
    'Duration' '(microseconds',
  ];

  /// 🔴 THE ONE FILE ALLOWED TO BLUR — and why the ban did not simply lose.
  ///
  /// This rule started life as a BLANKET ban, and it was right to: a blur is a
  /// saveLayer, a saveLayer is the most expensive thing in a frame, and a
  /// codebase where any component may reach for one ends up with blurs it
  /// cannot account for.
  ///
  /// The frosted chrome (the floating top pill, the anchored bottom nav) needs a
  /// real `BackdropFilter` — a translucent fill with no live blur behind it is
  /// not glass, it is a tinted box, and it is the single most common way this
  /// style is faked. So the ban is NARROWED rather than lifted, and narrowed to
  /// the smallest thing that can hold it: ONE primitive, [HopGlass], which both
  /// bars are built from. That buys the material at a cost that can be stated
  /// exactly — two saveLayers, on fixed geometry, that never resize and never
  /// animate their sigma — instead of an unbounded number nobody is counting.
  ///
  /// The exemption is a FILE, not a pattern, on purpose. "Blur is allowed where
  /// it's needed" is not a rule, it is the absence of one; the next component
  /// that wants a soft edge would qualify, and the budget would go the way it
  /// always goes. If a second surface ever genuinely needs glass, it composes
  /// [HopGlass] — it does not earn its own line here.
  const glassPrimitive = 'hop_glass.dart';

  group('motion guards (web performance rules — permanent)', () {
    test('no blur primitives under lib/ — except the one glass primitive', () {
      var sawTheExemptFile = false;

      for (final file in dartFilesUnder('lib')) {
        final source = codeOf(file);
        if (file.uri.pathSegments.last == glassPrimitive) {
          sawTheExemptFile = true;
          continue;
        }
        for (final banned in [
          backdropFilter,
          imageFilterBlur,
          imageFilterCompose,
          maskFilter,
        ]) {
          expect(
            source.contains(banned),
            isFalse,
            reason: '${file.path} contains $banned — a blur is a saveLayer, and '
                'the budget for those is spent. The ONE exception is '
                '$glassPrimitive, which is where this material is defined. If '
                'this surface needs frosted glass, COMPOSE HopGlass (pick a '
                'HopGlassTier); do not open a second blur site — two '
                'hand-rolled blurs drift apart and read as two materials.',
          );
        }
      }

      expect(
        sawTheExemptFile,
        isTrue,
        reason: 'The exemption names a file that no longer exists. Either the '
            'glass primitive was renamed (point this at the new name) or it '
            'was deleted (then DELETE the exemption and restore the blanket '
            'ban) — do not leave a dead licence to blur lying around.',
      );
    });

    test('the glass primitive blurs at a CONSTANT sigma, never an animated one',
        () {
      // The saveLayer is affordable because its geometry is fixed: the backdrop
      // rasterises once and stays cached. An animated sigma re-rasterises it
      // every frame and hands the budget exactly the bill the blanket ban
      // existed to prevent.
      final glass = dartFilesUnder('lib/src/components')
          .singleWhere((f) => f.uri.pathSegments.last == glassPrimitive);
      final source = codeOf(glass);

      for (final animator in const ['Animation<', 'Tween', 'AnimatedBuilder']) {
        expect(
          source.contains(animator),
          isFalse,
          reason: '${glass.path} animates its blur ($animator). The sigma is a '
              'token constant (HoppinChrome.blurSigma) precisely so the '
              'backdrop rasterises once and stays cached.',
        );
      }
    });

    test('no Opacity widget under lib/src/components', () {
      for (final file in dartFilesUnder('lib/src/components')) {
        expect(
          codeOf(file).contains(opacityWidget),
          isFalse,
          reason: '${file.path} constructs an Opacity widget — use '
              'FadeTransition or paint colour alpha',
        );
      }
    });

    test('every looping animator sits inside a RepaintBoundary', () {
      final loopers = dartFilesUnder('lib/src/components')
          .where((f) => codeOf(f).contains(repeatCall))
          .toList();
      expect(
        loopers,
        isNotEmpty,
        reason: 'the six signature animators include repeating loops — an '
            'empty sweep means the sweep itself broke',
      );
      for (final file in loopers) {
        expect(
          codeOf(file).contains(repaintBoundary),
          isTrue,
          reason: '${file.path} repeats an animation without a '
              'RepaintBoundary around the loop',
        );
      }
    });

    test('no wall-clock reads anywhere under lib/', () {
      for (final file in dartFilesUnder('lib')) {
        expect(
          codeOf(file).contains(wallClock),
          isFalse,
          reason: '${file.path} reads the wall clock — time enters via '
              'package:clock only',
        );
      }
    });

    test('no inline Duration literals under lib/src/components', () {
      for (final file in dartFilesUnder('lib/src/components')) {
        final source = codeOf(file);
        for (final banned in durationLiterals) {
          expect(
            source.contains(banned),
            isFalse,
            reason: '${file.path} inlines a $banned) literal — animation '
                'durations come from HoppinMotion tokens',
          );
        }
      }
    });
  });
}
