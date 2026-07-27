import 'package:hoppin_shared/hoppin_shared.dart';

/// The demo camera/gallery. Returns a tiny synthetic image so the avatar flow
/// runs end to end with no plugin, no permission prompt and no real photo.
///
/// Why it must exist: `avatarPickerProvider` throws by default (a missing
/// override is a wiring bug, not a user who cancelled), so without this the
/// first tap on the avatar in demo mode would crash rather than demonstrate the
/// feature.
class FakeAvatarPicker implements AvatarPicker {
  const FakeAvatarPicker();

  /// A 1×1 transparent PNG. Real bytes with a real PNG header, so anything that
  /// inspects the format sees a valid image — but nothing that looks like a
  /// photograph of a person, which the demo has no right to invent.
  static const _onePixelPng = <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ];

  @override
  Future<PickedAvatar?> pickAvatar({bool fromCamera = false}) async =>
      (bytes: _onePixelPng, filename: 'demo-avatar.png');
}
