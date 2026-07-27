/// One picked profile photo: the bytes and the filename to send.
///
/// No path is retained. The bytes live in memory for one upload and are dropped
/// when it returns — the app is a conduit, not the store of record.
typedef PickedAvatar = ({
  List<int> bytes,
  String filename,
});

/// The camera / gallery seam for a profile photo.
///
/// An ABSTRACTION for the same reason the driver app's `DocumentPicker` is one:
/// `image_picker` is a platform plugin, and a plugin in the call path means a
/// test needs a MethodChannel mock. There is not one in this repository, and
/// there does not need to be — tests inject a plain Dart fake through
/// `avatarPickerProvider`.
abstract class AvatarPicker {
  /// Camera or gallery. Null when the user backed out.
  Future<PickedAvatar?> pickAvatar({bool fromCamera = false});
}
