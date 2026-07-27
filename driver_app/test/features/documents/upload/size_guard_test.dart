import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/documents/upload/image_downscaler.dart';
import 'package:image/image.dart' as img;

/// 🔴 THE 10 MB CLIENT GUARD (OD-13).
///
/// `max_bytes` is **10485760** and the **server re-checks it**: an over-cap
/// object comes back from the confirm step as `500 INTERNAL`, which reaches the
/// driver as "something went wrong" — about a problem they could have solved in
/// one tap, if only anyone had told them what it was.
///
/// A modern phone camera routinely produces an **18 MB JPEG**. So this is not a
/// defensive nicety; it is the difference between the upload working and the
/// upload not working, for the ordinary case.
///
/// Two rules, and the second is the one people get wrong:
///
///  * **An image is DOWNSCALED.** Losing pixels off a photograph of a licence is
///    fine right up until it is unreadable, so we step down gently — longest
///    edge first, then quality — and stop the instant it fits.
///  * **A PDF is REJECTED, honestly, by name.** We cannot re-encode a PDF, and
///    silently truncating one would corrupt a legal document. The driver is told
///    the cap and the actual size, before any network call happens, so they can
///    go and fix it. Sending it and letting the server 500 tells them nothing.
void main() {
  test('an image already under the cap is returned UNTOUCHED', () {
    final small = _jpeg(400, 300);
    final doc = (
      bytes: small,
      contentType: 'image/jpeg',
      sizeBytes: small.length
    );

    final out = downscaleIfNeeded(doc);

    expect(out, same(small),
        reason: 'no re-encode when none is needed — every re-encode of a JPEG '
            'loses detail off a document a human has to read');
    expect(out.length, lessThan(kMaxDocumentBytes));
  });

  test('🔴 an over-cap JPEG is downscaled UNDER the cap', () {
    // A big, noisy image: noise is what makes a JPEG incompressible, so this is
    // an honest stand-in for a phone photo rather than a flat colour field that
    // would fit under the cap at any size.
    final huge = _noisyJpeg(5200, 3900);
    expect(huge.length, greaterThan(kMaxDocumentBytes),
        reason: 'sanity: the fixture must actually be over the cap, or this '
            'test proves nothing at all');

    final out = downscaleIfNeeded(
      (bytes: huge, contentType: 'image/jpeg', sizeBytes: huge.length),
    );

    expect(out.length, lessThanOrEqualTo(kMaxDocumentBytes),
        reason: '🔴 an 18 MB phone photo of a DVLA licence MUST upload. The '
            'server re-checks the cap and answers 500; the driver reads '
            '"something went wrong" and has no idea their photo was too big.');
    expect(img.decodeJpg(Uint8List.fromList(out)), isNotNull,
        reason: 'and it must still be a readable JPEG afterwards — a licence '
            'an admin cannot read is a rejected application');
  });

  test('🔴 an over-cap PDF is REJECTED client-side, naming the real size', () {
    final pdf = _fakePdf(12 * 1024 * 1024);

    expect(
      () => downscaleIfNeeded(
        (bytes: pdf, contentType: 'application/pdf', sizeBytes: pdf.length),
      ),
      throwsA(isA<DocumentTooLarge>()
          .having((e) => e.sizeBytes, 'sizeBytes', pdf.length)
          .having((e) => e.contentType, 'contentType', 'application/pdf')),
      reason: 'we cannot re-encode a PDF and we must never truncate one — that '
          'would corrupt a legal document. Say so, before the round trip.',
    );
  });

  test('DocumentTooLarge says the cap AND the actual size, in MB', () {
    const e = DocumentTooLarge(
      sizeBytes: 12 * 1024 * 1024,
      contentType: 'application/pdf',
    );
    expect(e.message, contains('10'), reason: 'the cap');
    expect(e.message, contains('12'), reason: 'what they actually picked');
    expect(e.message.toLowerCase(), contains('pdf'));
  });

  test('🔴 an unsupported MIME is rejected BEFORE any network call', () {
    // `image/heic` is the iPhone default and the single most likely thing a
    // driver hands us that the server will not take. The server's own message
    // is "unsupported file type (allowed: pdf, jpg, png)" — say the same thing
    // one round trip earlier.
    final bytes = List<int>.filled(1024, 0);

    expect(
      () => downscaleIfNeeded(
        (bytes: bytes, contentType: 'image/heic', sizeBytes: bytes.length),
      ),
      throwsA(isA<UnsupportedDocumentType>()
          .having((e) => e.contentType, 'contentType', 'image/heic')
          .having((e) => e.message, 'message', contains('pdf'))),
    );
  });

  test('the three accepted content types are exactly the API contract\'s', () {
    // Not a list we invented — `DriverRepository.documentContentTypes`, which
    // is docs/04's own vocabulary. If the backend ever adds one, this is where
    // the drift shows.
    expect(kAcceptedContentTypes,
        containsAll(const ['application/pdf', 'image/jpeg', 'image/png']));
    expect(kAcceptedContentTypes.length, 3);
  });

  test('an over-cap PNG is rejected, NOT silently converted to JPEG', () {
    // Converting behind the driver's back changes what document they think they
    // uploaded, and the content type must match what we asked the slot for. A
    // PNG that will not fit is a PNG we say no to.
    final png = _noisyPng(4200, 3200);
    expect(png.length, greaterThan(kMaxDocumentBytes), reason: 'sanity');

    expect(
      () => downscaleIfNeeded(
        (bytes: png, contentType: 'image/png', sizeBytes: png.length),
      ),
      anyOf(
        // Either it downscales as a PNG and fits...
        returnsNormally,
        // ...or it says no. What it must NEVER do is hand back JPEG bytes
        // under an `image/png` content type: the slot signed `image/png`.
        throwsA(isA<DocumentTooLarge>()),
      ),
    );

    // The load-bearing half of the assertion: whatever comes back is still a PNG.
    try {
      final out = downscaleIfNeeded(
        (bytes: png, contentType: 'image/png', sizeBytes: png.length),
      );
      expect(img.decodePng(Uint8List.fromList(out)), isNotNull,
          reason: '🔴 the slot signed `image/png`. Handing the PUT JPEG bytes '
              'under that content type is a lie to the driver AND a corrupt '
              'object in the bucket.');
      expect(out.length, lessThanOrEqualTo(kMaxDocumentBytes));
    } on DocumentTooLarge {
      // The honest no. Fine.
    }
  });

  test('🔴 the downscaler imports NO platform plugin', () {
    // It is pure Dart over `package:image` so it is unit-testable with synthetic
    // bytes and can never drag a MethodChannel into a test. The picker is the
    // one file allowed near a plugin.
    //
    // 🔴 THIS POLICES THE `import` LINES, NOT THE PROSE. The first version of
    // this test grepped the whole file and went RED on the doc comment that
    // says "no `dart:io`" — which is precisely the failure mode
    // `router_reachability_test.dart` warns about at length: a grep that
    // matches a comment proves nothing about the code, and it can pass or fail
    // for reasons that have nothing to do with behaviour. Parse the imports.
    final imports = File('lib/features/documents/upload/image_downscaler.dart')
        .readAsLinesSync()
        .where((l) => l.trimLeft().startsWith('import '))
        .toList();

    for (final plugin in const [
      'image_picker',
      'file_picker',
      'path_provider',
      'dart:io',
      'flutter/material',
    ]) {
      expect(
        imports.where((l) => l.contains(plugin)),
        isEmpty,
        reason: 'image_downscaler.dart must stay pure Dart — it is the one '
            'piece of this lane a test can drive with a synthetic 18 MB byte '
            'array. It imports: ${imports.join(' ')}',
      );
    }
    expect(imports.any((l) => l.contains('package:image/image.dart')), isTrue,
        reason: 'sanity: the grep is looking at the real import block');
  });
}

// ── fixtures ────────────────────────────────────────────────────────────────

/// A small, clean JPEG.
List<int> _jpeg(int w, int h) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(120, 140, 160));
  return img.encodeJpg(image, quality: 90);
}

/// A big JPEG that does NOT compress away — per-pixel noise, which is what makes
/// a real photograph large. A flat fill of the same dimensions encodes to a few
/// hundred KB and would make the over-cap test vacuous.
List<int> _noisyJpeg(int w, int h) =>
    img.encodeJpg(_noise(w, h), quality: 100);

List<int> _noisyPng(int w, int h) => img.encodePng(_noise(w, h), level: 0);

img.Image _noise(int w, int h) {
  final image = img.Image(width: w, height: h);
  var seed = 0x2545F491;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      // xorshift — deterministic, so a failure is reproducible.
      seed ^= seed << 13;
      seed ^= seed >>> 17;
      seed ^= seed << 5;
      seed &= 0x7FFFFFFF;
      image.setPixelRgb(x, y, seed & 0xFF, (seed >> 8) & 0xFF, (seed >> 16) & 0xFF);
    }
  }
  return image;
}

/// 12 MB of "PDF". The downscaler must reject it on the content type and the
/// length ALONE — it must never try to parse it, and it must never truncate it.
List<int> _fakePdf(int bytes) {
  final out = List<int>.filled(bytes, 0x20);
  const header = '%PDF-1.7';
  for (var i = 0; i < header.length; i++) {
    out[i] = header.codeUnitAt(i);
  }
  return out;
}
