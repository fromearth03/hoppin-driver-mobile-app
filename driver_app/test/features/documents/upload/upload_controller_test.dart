import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/documents/upload/document_picker.dart';
import 'package:hoppin_driver/features/documents/upload/image_downscaler.dart';
import 'package:hoppin_driver/features/documents/upload/presigned_put_gateway.dart';
import 'package:hoppin_driver/features/documents/upload/upload_providers.dart';
import 'package:hoppin_driver/features/documents/upload/upload_state.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// The three-step presigned flow, sequenced — and every way it can end.
///
/// `documentUploadUrl` → **raw PUT** → `confirmDocument` is docs/04 L166-175.
/// It has been fully typed on `DriverRepository` since the API client was
/// written and had **zero callers** until this lane. Which means every one of
/// these paths — the 503, the 400, the 500, the cancel, the over-cap file — is
/// being executed here for the first time in the project's life. None of them
/// has ever run against the real backend, and the tests below say what the
/// CLIENT does, which is all a test can say.

/// 🔴 LANE A's typedef, COPIED VERBATIM from
/// `documents/widgets/document_row.dart:14`.
///
/// It is duplicated here rather than imported because the two lanes are built in
/// separate worktrees and LANE A's file is not in this one — importing it would
/// make the lanes fail to compile independently, which is the property that lets
/// them be built in parallel at all.
///
/// The duplication is deliberate and it is load-bearing: the assignment in
/// `documentUploadRequestProvider ASSIGNS to LANE A's typedef` below is a
/// COMPILE-TIME check that this lane's seam is the shape that lane's view can
/// call. If LANE A ever changes the typedef, that test stops compiling — which
/// is exactly what should happen, and is far better than discovering it at the
/// merge.
typedef DocumentUploadRequest = Future<void> Function(String documentType);

void main() {
  final slot = (
    uploadUrl: 'https://storage.example.com/driver-docs/d-1/mot/x.jpg?sig=abc',
    key: 'driver-docs/d-1/mot_certificate/x.jpg',
    contentType: 'image/jpeg',
    urlExpiresAt: DateTime.utc(2026, 7, 14, 12, 5),
    maxBytes: kMaxDocumentBytes,
  );

  PickedDocument jpeg([int size = 4096]) => (
        bytes: List<int>.filled(size, 3),
        contentType: 'image/jpeg',
        sizeBytes: size,
      );

  ({ProviderContainer container, _Recorder log}) harness({
    PickedDocument? picked = const (
      bytes: [],
      contentType: 'image/jpeg',
      sizeBytes: 0,
    ),
    Object? uploadUrlThrows,
    Object? putThrows,
    Object? confirmThrows,
  }) {
    final log = _Recorder();
    final container = ProviderContainer(
      overrides: [
        driverRepositoryProvider.overrideWithValue(
          _Repo(log, slot,
              uploadUrlThrows: uploadUrlThrows, confirmThrows: confirmThrows),
        ),
        documentPickerProvider.overrideWithValue(_Picker(log, picked)),
        presignedPutGatewayProvider
            .overrideWithValue(_Gateway(log, throws: putThrows)),
        onDocumentUploadedProvider.overrideWithValue(() async {
          log.calls.add('refresh');
        }),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, log: log);
  }

  UploadState read(ProviderContainer c) =>
      c.read(documentUploadControllerProvider);

  Future<void> upload(ProviderContainer c, String type, {bool pdf = false}) => c
      .read(documentUploadControllerProvider.notifier)
      .upload(type, pdf: pdf);

  test('🔴 the happy path calls exactly: pick → uploadUrl → put → confirm → refresh',
      () async {
    final h = harness(picked: jpeg());

    await upload(h.container, 'mot_certificate');

    expect(
      h.log.calls,
      ['pick', 'uploadUrl', 'put', 'confirm', 'refresh'],
      reason: '🔴 THE ORDER IS THE CONTRACT. The slot is minted BETWEEN the '
          'pick and the PUT — never before the pick (we would not know the '
          'content type, and we would burn a 5-minute TTL on a driver who is '
          'still deciding), and never after the PUT (there would be nothing to '
          'PUT to).',
    );
    expect(read(h.container).phase, UploadPhase.done);
    expect(read(h.container).error, isNull);
  });

  test('the confirm carries the SAME key the slot issued', () async {
    final h = harness(picked: jpeg());
    await upload(h.container, 'mot_certificate');

    expect(h.log.confirmedKey, slot.key);
    expect(h.log.confirmedType, 'mot_certificate');
    expect(h.log.putUrl, slot.uploadUrl);
    expect(h.log.putContentType, slot.contentType,
        reason: "the SLOT's content type — what the server actually signed — "
            'not the picker\'s guess at it');
  });

  test('a cancelled pick does NOTHING: no calls, no error, no churn', () async {
    final h = harness(picked: null);

    await upload(h.container, 'dvla_license');

    expect(h.log.calls, ['pick'],
        reason: 'the driver backed out. There is no server to tell, no slot to '
            'mint, and nothing to explain.');
    expect(read(h.container).phase, UploadPhase.idle);
    expect(read(h.container).error, isNull);
  });

  test('🔴 an over-cap PDF never reaches the network', () async {
    final h = harness(
      picked: (
        bytes: List<int>.filled(12 * 1024 * 1024, 0x20),
        contentType: 'application/pdf',
        sizeBytes: 12 * 1024 * 1024,
      ),
    );

    await upload(h.container, 'insurance_policy', pdf: true);

    expect(h.log.calls, ['pick'],
        reason: '🔴 NO `uploadUrl`. Asking for a five-minute slot we already '
            'know we cannot fill wastes the TTL; PUTting the object anyway '
            'earns a 500 from the confirm step, which the driver reads as '
            '"something went wrong".');
    expect(read(h.container).phase, UploadPhase.error);
    expect(read(h.container).error, contains('10'),
        reason: 'name the cap');
    expect(read(h.container).error, contains('12'),
        reason: 'and name what they actually picked, so they can act on it');
  });

  test('an unsupported type never reaches the network either', () async {
    final h = harness(
      picked: (
        bytes: List<int>.filled(512, 1),
        contentType: 'image/heic',
        sizeBytes: 512,
      ),
    );

    await upload(h.container, 'dvla_license');

    expect(h.log.calls, ['pick']);
    expect(read(h.container).error, contains('pdf'),
        reason: "the server's own words: 'allowed: pdf, jpg, png'");
  });

  test('🔴 503 STORAGE_DISABLED → the storageDisabled phase, not an error',
      () async {
    // Object storage is OFF on the backend. This is not the driver's fault and
    // there is nothing they can do about it — a red "upload failed, try again"
    // would send them round the loop forever. LANE A shows the
    // DocumentStorageUnavailable rung against THIS phase.
    final h = harness(
      picked: jpeg(),
      uploadUrlThrows: const ApiException(
        statusCode: 503,
        message: 'document storage is not configured',
        code: 'STORAGE_DISABLED',
      ),
    );

    await upload(h.container, 'dvla_license');

    expect(h.log.calls, ['pick', 'uploadUrl'],
        reason: 'no PUT — there is nowhere to PUT to');
    expect(read(h.container).phase, UploadPhase.storageDisabled);
    expect(read(h.container).phase, isNot(UploadPhase.error),
        reason: 'a retry cannot fix a backend with storage switched off');
  });

  test('400 VALIDATION_FAILED surfaces the SERVER\'s own message', () async {
    final h = harness(
      picked: jpeg(),
      uploadUrlThrows: const ApiException(
        statusCode: 400,
        message: 'unsupported file type (allowed: pdf, jpg, png)',
        code: 'VALIDATION_FAILED',
      ),
    );

    await upload(h.container, 'dvla_license');

    expect(read(h.container).phase, UploadPhase.error);
    expect(read(h.container).error, 'unsupported file type (allowed: pdf, jpg, png)',
        reason: 'the server said exactly what is wrong. Anything we wrote '
            'instead would be a worse version of it.');
  });

  test('a 403 from the bucket is an EXPIRED LINK, in words a driver can act on',
      () async {
    final h = harness(picked: jpeg(), putThrows: const UploadFailure(403));

    await upload(h.container, 'dvla_license');

    expect(h.log.calls, ['pick', 'uploadUrl', 'put'],
        reason: 'no confirm — there is no object in the bucket to confirm');
    expect(read(h.container).phase, UploadPhase.error);
    expect(read(h.container).error, contains('again'),
        reason: 'and retrying mints a FRESH slot, which is genuinely the right '
            'move — it is exactly why the fetch lives at PUT time');
  });

  test('🔴 a 500 on confirm does NOT silently retry', () async {
    // The server re-checked the object and did not like what it found (missing,
    // empty, or over-cap). The object is ALREADY IN THE BUCKET — a silent retry
    // would upload it a second time to no purpose, and hide the fact that
    // something is genuinely wrong.
    final h = harness(
      picked: jpeg(),
      confirmThrows: const ApiException(
        statusCode: 500,
        message: 'uploaded object is empty',
        code: 'INTERNAL',
      ),
    );

    await upload(h.container, 'v5c_logbook');

    expect(h.log.calls, ['pick', 'uploadUrl', 'put', 'confirm'],
        reason: 'exactly ONE of each. No retry loop.');
    expect(h.log.calls.where((c) => c == 'put').length, 1);
    expect(read(h.container).phase, UploadPhase.error);
    expect(read(h.container).error, isNotNull);
  });

  test('the LANE A refresh fires ONLY on success', () async {
    final ok = harness(picked: jpeg());
    await upload(ok.container, 'right_to_work');
    expect(ok.log.calls, contains('refresh'));

    final bad = harness(picked: jpeg(), putThrows: const UploadFailure(500));
    await upload(bad.container, 'right_to_work');
    expect(bad.log.calls, isNot(contains('refresh')),
        reason: 'nothing changed on the server, so there is nothing to re-read '
            '— and a refresh that shows the row unchanged reads like the app '
            'lost the upload');
  });

  test('reset() returns to idle', () async {
    final h = harness(picked: jpeg());
    await upload(h.container, 'dvla_license');
    expect(read(h.container).phase, UploadPhase.done);

    h.container.read(documentUploadControllerProvider.notifier).reset();
    expect(read(h.container).phase, UploadPhase.idle);
    expect(read(h.container).error, isNull);
  });

  test('🔴 documentUploadRequestProvider ASSIGNS to LANE A\'s typedef', () async {
    // 🔴 THE ASSIGNMENT IS THE TEST. LANE A declares, in
    // `documents/widgets/document_row.dart:14`:
    //
    //     typedef DocumentUploadRequest = Future<void> Function(String documentType);
    //
    // and its row calls `onUpload(documentType)`. The typedef at the top of this
    // file is that line copied verbatim, and the `final DocumentUploadRequest
    // request = ...` below is a COMPILE-TIME proof that what this lane exposes
    // is what that lane can consume. It catches a return type that drifts to
    // `void`, a parameter that becomes `required`, and an argument that gets
    // added positionally.
    //
    // What it does NOT catch, and I checked rather than assuming: Dart's
    // function subtyping permits extra OPTIONAL NAMED parameters, so a
    // `Function(String, {bool pdf})` would also assign here and compile fine.
    // That is why the narrow signature is a discipline rather than a
    // compiler-enforced fact — and why this comment says so instead of claiming
    // a guarantee the language does not give.
    final h = harness(picked: jpeg());

    final DocumentUploadRequest request =
        h.container.read(documentUploadRequestProvider);
    await request('caz_compliance_proof');

    expect(h.log.calls, ['pick', 'uploadUrl', 'put', 'confirm', 'refresh']);
    expect(h.log.confirmedType, 'caz_compliance_proof');
  });

  test('the camera and file variants reach the same three steps', () async {
    final cam = harness(picked: jpeg());
    await cam.container.read(documentCameraUploadProvider)('dvla_license');
    expect(cam.log.calls, ['pick', 'uploadUrl', 'put', 'confirm', 'refresh']);

    final pdf = harness(
      picked: (
        bytes: List<int>.filled(2048, 0x25),
        contentType: 'application/pdf',
        sizeBytes: 2048,
      ),
    );
    await pdf.container.read(documentFileUploadProvider)('insurance_policy');
    expect(pdf.log.calls, ['pick', 'uploadUrl', 'put', 'confirm', 'refresh']);
  });

  test('every one of the eight document types round-trips', () async {
    // The vocabulary is `DriverRepository.documentTypes` — docs/04's own list.
    // A type the controller silently mishandles is a document a driver can
    // never upload, and the app would not say so.
    for (final type in DriverRepository.documentTypes) {
      final h = harness(picked: jpeg());
      await upload(h.container, type);
      expect(read(h.container).phase, UploadPhase.done, reason: type);
      expect(h.log.confirmedType, type);
    }
  });
}

class _Recorder {
  final calls = <String>[];
  String? confirmedKey;
  String? confirmedType;
  String? putUrl;
  String? putContentType;
}

class _Picker implements DocumentPicker {
  _Picker(this.log, this.doc);
  final _Recorder log;
  final PickedDocument? doc;

  @override
  Future<PickedDocument?> pickImage({bool fromCamera = false}) async {
    log.calls.add('pick');
    return doc;
  }

  @override
  Future<PickedDocument?> pickFile() async {
    log.calls.add('pick');
    return doc;
  }
}

class _Gateway implements PresignedPutGateway {
  _Gateway(this.log, {this.throws});
  final _Recorder log;
  final Object? throws;

  @override
  Future<void> put({
    required String uploadUrl,
    required List<int> bytes,
    required String contentType,
  }) async {
    log.calls.add('put');
    log.putUrl = uploadUrl;
    log.putContentType = contentType;
    if (throws != null) throw throws!;
  }
}

class _Repo implements DriverRepository {
  _Repo(this.log, this.slot, {this.uploadUrlThrows, this.confirmThrows});
  final _Recorder log;
  final DocumentUploadSlot slot;
  final Object? uploadUrlThrows;
  final Object? confirmThrows;

  @override
  Future<DocumentUploadSlot> documentUploadUrl({
    required String documentType,
    required String contentType,
  }) async {
    log.calls.add('uploadUrl');
    if (uploadUrlThrows != null) throw uploadUrlThrows!;
    return slot;
  }

  @override
  Future<DriverDocument> confirmDocument({
    required String documentType,
    required String key,
    DateTime? expiresAt,
  }) async {
    log.calls.add('confirm');
    log.confirmedKey = key;
    log.confirmedType = documentType;
    if (confirmThrows != null) throw confirmThrows!;
    return DriverDocument(
      id: 'doc-1',
      documentType: documentType,
      verificationStatus: 'pending_review',
      uploadedAt: DateTime.utc(2026, 7, 14),
      expiresAt: expiresAt,
    );
  }

  @override
  Future<List<DriverDocument>> documents() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
