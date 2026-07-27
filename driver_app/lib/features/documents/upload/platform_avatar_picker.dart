import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:image_picker/image_picker.dart';

/// The live profile-photo picker. **The only file on the avatar path that
/// touches a plugin** — everything downstream takes bytes through the
/// [AvatarPicker] seam, matching the isolation the document upload path already
/// follows (`plugin_isolation_test.dart`).
///
/// It lives HERE rather than under `features/profile/` on purpose:
/// `profile_screen_test.dart` asserts that the whole profile directory is free
/// of `image_picker` (and of rating/tripCount/vehicle symbols), so the plugin
/// belongs with the other plugin-touching upload code.
class PlatformAvatarPicker implements AvatarPicker {
  PlatformAvatarPicker({ImagePicker? images}) : _images = images ?? ImagePicker();

  final ImagePicker _images;

  @override
  Future<PickedAvatar?> pickAvatar({bool fromCamera = false}) async {
    final file = await _images.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      // A cheap first cut at the server's 8 MB ceiling. Advisory only — the
      // controller still checks the real byte length before uploading.
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    // Original bytes: the server's re-encode is what strips EXIF.
    return (bytes: bytes, filename: file.name);
  }
}
