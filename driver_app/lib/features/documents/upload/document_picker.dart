import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

/// One picked document: the bytes, the MIME type, and the original size.
///
/// 🔴 NO PATH IS RETAINED AND NO PREVIEW IS CACHED. The bytes live in memory for
/// the duration of one upload and are dropped the moment it returns. The app is
/// never the store of record for a DVLA licence or an NR3S criminal-record
/// check — it is a conduit. (`pii_discipline_test.dart` asserts that nothing
/// under `upload/` can reach a filesystem, a key-value store, or a database.)
typedef PickedDocument = ({
  List<int> bytes,
  String contentType,
  int sizeBytes,
});

/// The camera / gallery / files seam.
///
/// It is an ABSTRACTION for the same reason `DriverLocationService` and
/// `DriverShiftService` are: `image_picker` and `file_picker` are platform
/// plugins, and a plugin in the call path of an interactor means a test of that
/// interactor needs a MethodChannel mock. **There is not one MethodChannel mock
/// in this repository** (`plugin_isolation_test.dart`), and there does not need
/// to be — every upload test injects a plain Dart fake through
/// `documentPickerProvider`.
abstract class DocumentPicker {
  /// Camera or gallery — a photograph of a licence, a badge, a certificate.
  /// Null when the driver backed out.
  Future<PickedDocument?> pickImage({bool fromCamera = false});

  /// The OS file picker — a PDF of an insurance policy or an MOT certificate.
  /// Null when the driver backed out.
  Future<PickedDocument?> pickFile();
}

/// The live picker. **The ONLY file in the upload path that touches a plugin.**
class PlatformDocumentPicker implements DocumentPicker {
  PlatformDocumentPicker({ImagePicker? images}) : _images = images ?? ImagePicker();

  final ImagePicker _images;

  @override
  Future<PickedDocument?> pickImage({bool fromCamera = false}) async {
    final file = await _images.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      // A first, cheap cut at the 10 MB cap — the OS re-encodes before we ever
      // see the bytes, so the common case never reaches the downscaler at all.
      // It is NOT the guard: `imageQuality` is advisory, several Android OEM
      // camera stacks ignore it, and the guard has to be a fact. See
      // `image_downscaler.dart`.
      imageQuality: 85,
      maxWidth: 2400,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    return (
      bytes: bytes,
      contentType: _contentTypeOf(file.name, file.mimeType),
      sizeBytes: bytes.length,
    );
  }

  @override
  Future<PickedDocument?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      // Bytes, never a path: `withData` is what makes this work identically on
      // Android and (should it ever return) the web, and it is what keeps the
      // document out of a temp file we would then have to remember to delete.
      withData: true,
    );
    final picked = result?.files.singleOrNull;
    final bytes = picked?.bytes;
    if (picked == null || bytes == null) return null;

    return (
      bytes: bytes,
      contentType: _contentTypeOf(picked.name, null),
      sizeBytes: bytes.length,
    );
  }

  /// The document's MIME type, from the plugin if it gave us one and from the
  /// extension otherwise.
  ///
  /// Deliberately NOT sniffed from the magic bytes: the server signs the
  /// content type we *ask* for, and the PUT must echo exactly that. Guessing a
  /// type we then have to reconcile with what the slot came back with is one
  /// more way to break the signature. An unrecognised type falls through as-is
  /// and `image_downscaler.dart` rejects it by name.
  static String _contentTypeOf(String name, String? reported) {
    if (reported != null && reported.isNotEmpty) return reported;
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => 'application/octet-stream',
    };
  }
}
