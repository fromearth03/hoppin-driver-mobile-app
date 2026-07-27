import 'package:flutter/material.dart';

import '../theme/context_extension.dart';

/// A circular profile photo with an initials fallback layered underneath.
///
/// Why this exists as a component rather than an `Image.network` at each call
/// site: profile photos are served by `GET /api/v1/images/*path`, which is an
/// **authenticated** route — the object store behind it is private and nothing
/// is world-readable. A bare `Image.network` sends no `Authorization` header,
/// so it 401s, and because the error path falls back to initials the failure is
/// invisible: it renders exactly like a driver who never set a photo. Passing
/// [headers] through to [NetworkImage] is what makes the image load at all.
///
/// The initials sit UNDER the photo, so the slot is never blank — they show
/// while the image loads and stay if it fails.
class HopAvatar extends StatelessWidget {
  const HopAvatar({
    required this.name,
    this.imageUrl,
    this.headers,
    this.size = 48,
    super.key,
  });

  /// Display name the initials are derived from. May be empty.
  final String name;

  /// Absolute image URL, or null/empty when the user has no photo.
  final String? imageUrl;

  /// Auth headers for [imageUrl] — `{'Authorization': 'Bearer <jwt>'}`.
  ///
  /// Omitting these on a `/api/v1/images/…` URL yields a silent 401 that looks
  /// like "no photo set".
  final Map<String, String>? headers;

  final double size;

  /// Up to two initials: first letter of the first and last name parts. Falls
  /// back to a person glyph when there is no usable name (rather than showing
  /// a stray "?" that reads as an error).
  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final url = imageUrl?.trim() ?? '';
    final initials = _initials;

    final initialsLayer = Center(
      child: initials.isEmpty
          ? Icon(Icons.person_outline, size: size * 0.5, color: colors.accent)
          : Text(
              initials,
              style: hoppin.type.body.copyWith(
                // Scale with the avatar so one component serves a 32px list row
                // and a 64px profile header without a second set of tokens.
                fontSize: size * 0.36,
                color: colors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
    );

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.accentSubtle,
        shape: BoxShape.circle,
        // A hairline accent ring lifts the chip off the surface so it reads as
        // an intentional avatar, never an empty placeholder.
        border: Border.all(color: colors.accent.withValues(alpha: 0.24)),
      ),
      child: url.isEmpty
          ? initialsLayer
          : Image(
              image: NetworkImage(url, headers: headers),
              fit: BoxFit.cover,
              width: size,
              height: size,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : initialsLayer,
              errorBuilder: (context, _, _) => initialsLayer,
            ),
    );
  }
}
