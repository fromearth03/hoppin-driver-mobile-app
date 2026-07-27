import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../providers.dart';
import '../repositories/profile_repository.dart';
import 'avatar_picker.dart';
import 'avatar_upload_state.dart';

/// The camera / gallery seam. Apps override this with the plugin-backed picker
/// in `main()`; tests inject a plain Dart fake. The base package deliberately
/// ships NO default — `hoppin_shared` must not depend on a platform plugin, and
/// a silent no-op default would make a missing override look like a user who
/// keeps cancelling the picker.
final avatarPickerProvider = Provider<AvatarPicker>((ref) {
  throw UnimplementedError(
    'avatarPickerProvider must be overridden with a platform picker '
    '(see PlatformAvatarPicker in each app) or a fake in tests',
  );
});

/// Pick a profile photo and upload it to `POST /me/avatar/upload`.
///
/// Serves riders and drivers alike — the server takes the identity from the
/// JWT, so there is no role branch. Screens watch this and render the returned
/// URL through `HopAvatar` (with `imageAuthHeadersProvider`, since the image
/// route is authenticated).
class AvatarUploadController extends Notifier<AvatarUploadState> {
  @override
  AvatarUploadState build() => const AvatarIdle();

  /// Seed the current photo so the widget renders it before any upload.
  void seed(String? currentUrl) => state = AvatarIdle(url: currentUrl);

  /// Pick, then upload. Safe to call repeatedly: a call made while an upload is
  /// already running is ignored rather than racing a second PUT that could land
  /// out of order and leave the older photo as the winner.
  Future<void> pickAndUpload({bool fromCamera = false}) async {
    if (state is AvatarUploading) return;

    final PickedAvatar? picked;
    try {
      picked = await ref.read(avatarPickerProvider).pickAvatar(
            fromCamera: fromCamera,
          );
    } catch (_) {
      // A denied camera/gallery permission throws from the plugin. That is not
      // an upload failure and must not read as one.
      state = const AvatarUploadFailed(
        "Couldn't open your photos. Check the app's photo permission.",
      );
      return;
    }
    // Backing out of the picker is not an error — return to where we were,
    // keeping any photo already on file.
    if (picked == null) return;

    // Refuse an oversized file HERE rather than spending the upload to be told.
    // The server's ceiling is the authority; this only avoids a doomed request.
    if (picked.bytes.length > ProfileRepository.maxAvatarBytes) {
      state = const AvatarUploadFailed(
        'That photo is larger than 8 MB. Try a smaller one.',
      );
      return;
    }

    state = const AvatarUploading();
    try {
      final url = await ref.read(profileRepositoryProvider).uploadAvatar(
            bytes: picked.bytes,
            filename: picked.filename,
          );
      // A 200 with no URL would leave the UI claiming success while showing the
      // old photo. Treat it as the failure it is.
      if (url.isEmpty) {
        state = const AvatarUploadFailed(
          "That didn't save. Please try again.",
        );
        return;
      }
      state = AvatarUploaded(url);
    } on ApiException catch (e) {
      state = AvatarUploadFailed(_messageFor(e));
    }
  }

  /// Map the server's failure onto a sentence the user can act on.
  ///
  /// `STORAGE_DISABLED` is deliberately NOT surfaced as "try again": the object
  /// store is unconfigured server-side, so retrying cannot help and telling the
  /// user to retry wastes their time on a problem only we can fix.
  static String _messageFor(ApiException e) => switch (e.code) {
        'FILE_TOO_LARGE' => 'That photo is larger than 8 MB. Try a smaller one.',
        'VALIDATION_FAILED' =>
          "That file isn't a photo we can use. Try a JPEG or PNG.",
        'STORAGE_DISABLED' =>
          "Photo uploads are unavailable right now. It's not you — we're on it.",
        _ => "That didn't save. Please try again.",
      };
}

/// The avatar upload orchestration, shared by both apps.
final avatarUploadControllerProvider =
    NotifierProvider<AvatarUploadController, AvatarUploadState>(
  AvatarUploadController.new,
);
