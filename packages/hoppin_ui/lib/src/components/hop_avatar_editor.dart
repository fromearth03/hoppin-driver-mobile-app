import 'package:flutter/material.dart';

import '../theme/context_extension.dart';
import 'hop_avatar.dart';

/// A [HopAvatar] the user can tap to replace, with a camera badge and an
/// in-place busy state.
///
/// Purely presentational — it owns no upload logic and knows nothing about
/// Riverpod. The screen wires [onTap] to the avatar controller and passes the
/// current [imageUrl]/[busy]/[error], which keeps this widget testable without
/// a container and reusable by both apps.
class HopAvatarEditor extends StatelessWidget {
  const HopAvatarEditor({
    required this.name,
    this.imageUrl,
    this.headers,
    this.onTap,
    this.busy = false,
    this.error,
    this.size = 96,
    super.key,
  });

  /// Display name, for the initials fallback.
  final String name;

  /// Current photo URL, or null when the user has none.
  final String? imageUrl;

  /// Auth headers for [imageUrl] — the image route is authenticated.
  final Map<String, String>? headers;

  /// Opens the picker. Null disables the control.
  final VoidCallback? onTap;

  /// An upload is in flight: the badge becomes a spinner and taps are ignored,
  /// so a second pick cannot race the first.
  final bool busy;

  /// A failure message shown beneath the avatar. Null when there is none.
  final String? error;

  final double size;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final interactive = onTap != null && !busy;

    return Column(
      children: [
        Semantics(
          button: true,
          label: busy
              ? 'Uploading your profile photo'
              : (imageUrl == null || imageUrl!.isEmpty
                  ? 'Add a profile photo'
                  : 'Change your profile photo'),
          child: InkWell(
            onTap: interactive ? onTap : null,
            customBorder: const CircleBorder(),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                HopAvatar(
                  name: name,
                  imageUrl: imageUrl,
                  headers: headers,
                  size: size,
                ),
                // The badge is what makes the avatar read as EDITABLE. Without
                // it a tappable photo is indistinguishable from a static one.
                Container(
                  width: size * 0.32,
                  height: size * 0.32,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.card, width: 2),
                  ),
                  child: busy
                      ? Padding(
                          padding: EdgeInsets.all(size * 0.07),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onAccent,
                          ),
                        )
                      : Icon(
                          Icons.camera_alt,
                          size: size * 0.16,
                          color: colors.onAccent,
                        ),
                ),
              ],
            ),
          ),
        ),
        if (error != null) ...[
          SizedBox(height: hoppin.spacing.sm),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: hoppin.type.meta.copyWith(color: colors.error),
          ),
        ],
      ],
    );
  }
}
