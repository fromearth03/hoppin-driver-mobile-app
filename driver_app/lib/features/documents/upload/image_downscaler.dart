import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'document_picker.dart';

/// The cap, from the API contract (docs/04): `max_bytes` is **10485760**.
///
/// It is ALSO returned on every slot (`DocumentUploadSlot.maxBytes`), and the
/// controller re-checks against *that* value after minting one. This constant is
/// the PRE-guard: we refuse to spend a five-minute slot on a file we already
/// know is too big.
const int kMaxDocumentBytes = 10485760;

/// The three content types the presigned flow accepts — `DriverRepository`'s own
/// `documentContentTypes`, which is docs/04's vocabulary, not ours.
const List<String> kAcceptedContentTypes = [
  'application/pdf',
  'image/jpeg',
  'image/png',
];

/// The file is bigger than the cap and cannot be brought under it.
///
/// 🔴 THE MESSAGE IS THE WHOLE POINT. The server re-checks the cap and answers
/// `500 INTERNAL`, which the driver reads as "something went wrong" — about a
/// problem they could have fixed themselves in one tap, if anyone had told them
/// what it was. Name the cap, name the actual size, and say it BEFORE the round
/// trip.
class DocumentTooLarge implements Exception {
  const DocumentTooLarge({required this.sizeBytes, required this.contentType});

  final int sizeBytes;
  final String contentType;

  String get _kind => contentType == 'application/pdf' ? 'PDFs' : 'Images';

  String get message => '$_kind must be under '
      '${_mb(kMaxDocumentBytes)} MB — this one is ${_mb(sizeBytes)} MB. '
      '${contentType == 'application/pdf' ? 'Try a smaller scan, or photograph the document instead.' : 'Try photographing it again from a little further back.'}';

  @override
  String toString() => message;
}

/// The picked file is not one of [kAcceptedContentTypes].
///
/// The server's own words are "unsupported file type (allowed: pdf, jpg, png)".
/// We say the same thing one round trip earlier — `image/heic` (the iPhone
/// default) is the single most likely thing a driver hands us.
class UnsupportedDocumentType implements Exception {
  const UnsupportedDocumentType(this.contentType);

  final String contentType;

  String get message =>
      "That file type isn't supported — please use a pdf, jpg or png.";

  @override
  String toString() => message;
}

/// Returns bytes **guaranteed under [kMaxDocumentBytes]**, or throws.
///
/// * Under the cap already → the ORIGINAL bytes, untouched. Every re-encode of a
///   JPEG loses detail off a document a human being has to read and approve.
/// * An over-cap **image** → downscaled: longest edge first, then quality, and
///   we stop the instant it fits. A licence photo that is merely *smaller* is
///   still a licence; one that never uploads is nothing.
/// * An over-cap **PDF** → [DocumentTooLarge]. We cannot re-encode a PDF, and
///   truncating one would corrupt a legal document.
/// * Anything else → [UnsupportedDocumentType], before a single byte moves.
///
/// 🔴 PURE DART. No plugin, no filesystem, no `dart:io` — which is what makes it
/// drivable from a unit test with a synthetic 18 MB byte array, and what keeps a
/// MethodChannel mock out of this repository (`plugin_isolation_test.dart`).
List<int> downscaleIfNeeded(PickedDocument doc) {
  if (!kAcceptedContentTypes.contains(doc.contentType)) {
    throw UnsupportedDocumentType(doc.contentType);
  }

  if (doc.bytes.length <= kMaxDocumentBytes) return doc.bytes;

  if (doc.contentType == 'application/pdf') {
    // No re-encode exists that we could honestly perform here.
    throw DocumentTooLarge(
      sizeBytes: doc.bytes.length,
      contentType: doc.contentType,
    );
  }

  final source = img.decodeImage(Uint8List.fromList(doc.bytes));
  if (source == null) {
    // It claimed to be a JPEG/PNG and it will not decode. We are not going to
    // guess; the server would reject it anyway.
    throw UnsupportedDocumentType(doc.contentType);
  }

  final isJpeg = doc.contentType == 'image/jpeg';

  // 🔴 THE CONTENT TYPE IS PRESERVED, ALWAYS. A PNG comes back a PNG.
  //
  // Re-encoding a PNG as a JPEG would fit more of them under the cap — and it
  // would be a lie twice over: the slot signs `image/png` (so the PUT's
  // Content-Type must still say `image/png`, and now the bytes would not match
  // it), and the driver would have uploaded a different file from the one they
  // chose. If a PNG will not fit as a PNG, we say no.
  List<int> encode(img.Image image, int quality) => isJpeg
      ? img.encodeJpg(image, quality: quality)
      : img.encodePng(image, level: 9);

  // Longest edge first — resolution is what a 12-megapixel sensor is spending
  // the bytes on, and a licence is perfectly legible at 1400px on its long side.
  // Then quality, gently, and only for JPEG (PNG is lossless; `quality` means
  // nothing to it, so its only lever is the edge).
  const edges = [2400, 1800, 1400, 1000, 800];
  final qualities = isJpeg ? const [85, 75, 65] : const [100];

  final longest =
      source.width > source.height ? source.width : source.height;

  for (final edge in edges) {
    // Never UPSCALE to hit a step — that would grow the file.
    if (edge >= longest) continue;
    final resized = source.width >= source.height
        ? img.copyResize(source, width: edge)
        : img.copyResize(source, height: edge);

    for (final quality in qualities) {
      final out = encode(resized, quality);
      if (out.length <= kMaxDocumentBytes) return out;
    }
  }

  // A last pass at the smallest edge is already covered above; if nothing in the
  // ladder fit, this file genuinely cannot be brought under the cap without
  // destroying the document.
  throw DocumentTooLarge(
    sizeBytes: doc.bytes.length,
    contentType: doc.contentType,
  );
}

String _mb(int bytes) {
  final mb = bytes / (1024 * 1024);
  // 10485760 → "10", 12582912 → "12", 10.4 MB → "10.4". Never "10.000000".
  return mb == mb.roundToDouble()
      ? mb.round().toString()
      : mb.toStringAsFixed(1);
}
