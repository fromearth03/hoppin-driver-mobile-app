import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Camera or gallery. A driver photographing a licence at the roadside wants
/// the camera first; one who already has a scan wants the library.
class UploadSheet {
  static Future<XFile?> pick(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return null;
    return ImagePicker().pickImage(source: source, imageQuality: 85);
  }
}
