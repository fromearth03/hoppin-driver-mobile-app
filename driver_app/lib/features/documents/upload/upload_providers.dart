import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../documents_builder.dart';
import 'document_picker.dart';
import 'presigned_put_gateway.dart';
import 'upload_controller.dart';
import 'upload_state.dart';

/// The bare-Dio PUT rail.
///
/// 🔴 IT IS A PROVIDER OF ITS OWN, NOT A METHOD ON `apiClientProvider`, AND THAT
/// IS DELIBERATE. `ApiClient` attaches a Supabase bearer to everything it sends;
/// a bearer on a presigned URL invalidates the signature and the bucket answers
/// 403. There is no way to reach `ApiClient` from here, which is the only kind of
/// guarantee that survives the next person in a hurry.
final presignedPutGatewayProvider = Provider<PresignedPutGateway>(
  (ref) => DioPresignedPutGateway(),
);

/// Camera / gallery / files, behind the seam.
///
/// The default is the real plugin-backed picker; every test overrides it with a
/// plain Dart fake, which is how this lane adds four test files and **zero
/// MethodChannel mocks** (`plugin_isolation_test.dart`).
final documentPickerProvider = Provider<DocumentPicker>(
  (ref) => PlatformDocumentPicker(),
);

/// The 3-step orchestration.
final documentUploadControllerProvider =
    NotifierProvider<UploadController, UploadState>(UploadController.new);

/// 🔴 THE SEAM BETWEEN LANE B (this) AND LANE A (the documents surface).
///
/// A successful upload changes the Documents list — the row that read "Not
/// uploaded" now reads "Pending review". LANE A owns that list and its refresh;
/// this lane must not import it (the lanes are provably disjoint, and a compile
/// dependency across them would end that).
///
/// So: this defaults to a **no-op**, and LANE A's composition root overrides it
/// with `() => ref.read(documentsInteractorProvider.notifier).refresh()`. If
/// nobody overrides it, an upload still succeeds and the list is simply stale
/// until the next read — which is honest, and is not a crash.
final onDocumentUploadedProvider = Provider<Future<void> Function()>(
  // WIRED (wave 2) straight to the Documents riblet's own read.
  //
  // The default was `() async {}`, which is honest but stale: the upload
  // genuinely succeeds and the row still reads NOT UPLOADED until something else
  // happens to re-read. A driver who uploads their licence and watches the row
  // not change will upload it again, and then a third time.
  //
  // Wiring it HERE rather than in an override at each entrypoint is deliberate:
  // `main.dart` and `main_demo.dart` would both have to remember, and the one
  // that forgot would be silently stale. There is one correct answer, so it
  // lives with the provider.
  (ref) => () => ref.read(documentsInteractorProvider.notifier).refresh(),
);

/// Satisfies LANE A's `DocumentUploadRequest` typedef — the single call its view
/// makes to start an upload.
///
/// LANE A declares, in `documents/widgets/document_row.dart:14`:
///
///     typedef DocumentUploadRequest = Future<void> Function(String documentType);
///
/// and its row calls `onUpload(documentType)`. This provider is typed to that
/// signature EXACTLY — not a superset with optional named parameters bolted on.
///
/// To be precise about why, because the tempting version of this comment is
/// wrong and I checked: Dart's function subtyping **does** permit extra OPTIONAL
/// named parameters, so a `Function(String, {bool pdf})` would in fact assign to
/// that typedef and compile. The reason to keep the seam narrow is not the
/// compiler — it is that a seam between two independently-built lanes should
/// carry exactly the arguments the consumer passes and no more. Every optional
/// parameter here is a knob LANE A cannot see, cannot set, and will be surprised
/// by. The camera and PDF entry points are their own providers below.
///
/// LANE A reads THIS. It does not read the controller, and it does not need to
/// know that there are three steps, a bare Dio, a downscaler, or a five-minute
/// TTL behind it.
final documentUploadRequestProvider = Provider<Future<void> Function(String)>(
  (ref) => (String documentType) =>
      ref.read(documentUploadControllerProvider.notifier).upload(documentType),
);

/// The same upload, straight to the camera — a driver photographing their
/// licence, badge, or MOT certificate rather than digging out a scan.
final documentCameraUploadProvider = Provider<Future<void> Function(String)>(
  (ref) => (String documentType) => ref
      .read(documentUploadControllerProvider.notifier)
      .upload(documentType, fromCamera: true),
);

/// The same upload, from the OS file picker — the PDF of an insurance policy.
final documentFileUploadProvider = Provider<Future<void> Function(String)>(
  (ref) => (String documentType) => ref
      .read(documentUploadControllerProvider.notifier)
      .upload(documentType, pdf: true),
);
