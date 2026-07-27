import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

import 'document_picker.dart';
import 'image_downscaler.dart';
import 'presigned_put_gateway.dart';
import 'upload_providers.dart';
import 'upload_state.dart';

/// The three-step presigned upload (docs/04 L166-175), sequenced ONCE, in one
/// method, in the only order that works.
///
/// `documentUploadUrl` → **raw PUT** → `confirmDocument` has been fully typed on
/// `DriverRepository` since the API client was written, and had **zero callers**.
/// This is the caller.
///
/// 🔴 **STEP 3 IS AWAITED IMMEDIATELY BEFORE STEP 4, AND THAT IS LOAD-BEARING.**
/// The slot's TTL is **five minutes**. Hoist the `documentUploadUrl()` call out
/// of this method — cache it in state, prefetch it on `build()`, memoise it "so
/// the tap feels instant" — and you get an upload that works perfectly on a
/// developer's desk and fails for the driver who opens the Documents screen,
/// reads the eight rows, goes and finds their licence in a drawer, photographs
/// it, and comes back. It fails **for the slowest and most careful drivers
/// only**, which is the worst failure distribution there is, and it fails as a
/// 403 that reads like an auth bug. `presigned_put_test.dart` asserts the gap
/// between the mint and the PUT is under one second, and that a freshly-built
/// controller has fetched **nothing**.
class UploadController extends Notifier<UploadState> {
  @override
  UploadState build() => const UploadState();

  /// Upload one compliance document.
  ///
  /// [fromCamera] takes the driver straight to the camera (a licence, a badge);
  /// otherwise the OS file picker (a PDF policy). [expiresAt] is the date the
  /// driver typed for the documents that have one (MOT, insurance, licence).
  Future<void> upload(
    String documentType, {
    bool fromCamera = false,
    bool pdf = false,
    DateTime? expiresAt,
  }) async {
    state = UploadState(phase: UploadPhase.picking, documentType: documentType);

    // ── 1. PICK ────────────────────────────────────────────────────────────
    final PickedDocument? picked;
    try {
      final picker = ref.read(documentPickerProvider);
      picked = pdf
          ? await picker.pickFile()
          : await picker.pickImage(fromCamera: fromCamera);
    } on Object {
      // The OS refused (permission denied, camera unavailable). Not a crash.
      state = _fail(documentType, "Couldn't open the camera or your files.");
      return;
    }

    if (picked == null) {
      // The driver backed out. Not an error, not a state to explain — just
      // nothing happened. No network call, no churn.
      state = const UploadState();
      return;
    }

    // ── 2. GUARD + DOWNSCALE ───────────────────────────────────────────────
    // 🔴 BEFORE any network call. An over-cap file that reaches the server comes
    // back as a `500 INTERNAL` from the confirm step — the driver reads
    // "something went wrong" about a problem they could have fixed in one tap.
    // And asking for a slot we already know we cannot fill burns five minutes of
    // TTL for nothing.
    state = state.copyWith(phase: UploadPhase.preparing);
    final List<int> body;
    try {
      body = downscaleIfNeeded(picked);
    } on DocumentTooLarge catch (e) {
      state = _fail(documentType, e.message);
      return;
    } on UnsupportedDocumentType catch (e) {
      state = _fail(documentType, e.message);
      return;
    }

    final repo = ref.read(driverRepositoryProvider);

    // ── 3. MINT THE SLOT — AT PUT TIME, NOT BEFORE ─────────────────────────
    final DocumentUploadSlot slot;
    try {
      slot = await repo.documentUploadUrl(
        documentType: documentType,
        contentType: picked.contentType,
      );
    } on ApiException catch (e) {
      state = _onApiException(documentType, e);
      return;
    } on Object {
      state = _fail(documentType,
          "Can't reach the server — check your connection and try again.");
      return;
    }

    // The server tells us its own cap on every slot. Trust IT over our constant:
    // if the backend ever tightens it, the client must not keep cheerfully
    // uploading objects the confirm step will 500 on.
    if (body.length > slot.maxBytes) {
      state = _fail(
        documentType,
        DocumentTooLarge(
          sizeBytes: body.length,
          contentType: picked.contentType,
        ).message,
      );
      return;
    }

    // ── 4. THE RAW PUT ─────────────────────────────────────────────────────
    // Bare Dio. No bearer. `slot.contentType` — what the server SIGNED — not
    // our own guess at it: if it normalised the type, it signed the normalised
    // one, and the PUT must echo exactly that.
    state = state.copyWith(phase: UploadPhase.uploading);
    try {
      await ref.read(presignedPutGatewayProvider).put(
            uploadUrl: slot.uploadUrl,
            bytes: body,
            contentType: slot.contentType,
          );
    } on UploadFailure catch (e) {
      // 🔴 `e` carries a STATUS AND NOTHING ELSE. Never a URI, never a Dio
      // object. The presigned URL is a five-minute write credential and this
      // message is a string that gets shown, logged, screenshotted, and pasted
      // into a support ticket.
      state = _fail(documentType, _putFailureMessage(e.statusCode));
      return;
    } on Object {
      state = _fail(documentType, "Upload failed. Please try again.");
      return;
    }

    // ── 5. CONFIRM ─────────────────────────────────────────────────────────
    state = state.copyWith(phase: UploadPhase.confirming);
    try {
      await repo.confirmDocument(
        documentType: documentType,
        key: slot.key, // the SAME key step 1 issued
        expiresAt: expiresAt,
      );
    } on ApiException catch (e) {
      // A `500 INTERNAL` here means the object is missing, empty, or over-cap —
      // the server re-checked and did not like what it found. We do NOT retry:
      // the object is already in the bucket, and a silent retry would upload it
      // again to no purpose.
      state = _onApiException(documentType, e);
      return;
    } on Object {
      state = _fail(documentType,
          "Uploaded, but we couldn't confirm it. Please try again.");
      return;
    }

    // ── 6. DONE. DROP THE BYTES. ───────────────────────────────────────────
    // `body` and `picked` are locals; they die with this method. Nothing is
    // written to state, nothing is cached, nothing is persisted. The app is a
    // conduit for a criminal-record check, never the store of record.
    state = UploadState(phase: UploadPhase.done, documentType: documentType);

    // Tell whoever is showing the list that it changed. Defaults to a no-op;
    // LANE A's documents riblet overrides it with its own refresh.
    await ref.read(onDocumentUploadedProvider)();
  }

  /// Back to a clean slate — the view calls this when it has shown the error or
  /// the success and the driver has moved on.
  void reset() => state = const UploadState();

  UploadState _fail(String documentType, String message) => UploadState(
        phase: UploadPhase.error,
        documentType: documentType,
        error: message,
      );

  UploadState _onApiException(String documentType, ApiException e) {
    if (e.code == 'STORAGE_DISABLED') {
      // Object storage is off on the backend. Not the driver's fault and not
      // something they can retry their way out of — the Documents surface shows
      // the `DocumentStorageUnavailable` rung instead of an error.
      return UploadState(
        phase: UploadPhase.storageDisabled,
        documentType: documentType,
        error: e.message,
      );
    }
    // `VALIDATION_FAILED` says "invalid document type" or "unsupported file
    // type (allowed: pdf, jpg, png)". Both are better than anything we would
    // write, so we show the server's own words. `friendlyErrorMessage` passes an
    // ApiException's message straight through for exactly this reason.
    return _fail(documentType, friendlyErrorMessage(e));
  }

  /// What the DRIVER reads when the bucket says no.
  ///
  /// 🔴 Built from a STATUS CODE. Never from the exception's `toString()`, never
  /// by interpolating anything the gateway handed back — the gateway hands back
  /// an `int` precisely so that there is nothing here to leak.
  String _putFailureMessage(int statusCode) => switch (statusCode) {
        // The signature did not validate, or the slot expired mid-upload.
        // Retrying mints a FRESH slot, which is genuinely the right move — and
        // it is why the fetch lives at PUT time.
        403 => 'That upload link expired. Please try again.',
        0 => "Can't reach the server — check your connection and try again.",
        _ => 'Upload failed. Please try again.',
      };
}
