import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/colors.dart';

/// Avatar bytes, fetched with the caller's token. A failed fetch resolves to
/// null — the avatar falls back to its placeholder rather than surfacing an
/// error for a decoration. autoDispose so a failure is retried on the next
/// mount instead of being memoized as a grey circle for the whole session,
/// and so a long shift's rider avatars do not accumulate unbounded.
final avatarBytesProvider =
    FutureProvider.autoDispose.family<Uint8List?, String>((ref, url) async {
  final result = await ref.watch(apiClientProvider).getBytes(url);
  return result.valueOrNull;
});

/// A [CircleAvatar] for images in the private bucket.
///
/// `NetworkImage` sends no Authorization header (a browser `<img>` cannot
/// send one at all), so the private `/images/...` routes answer it 401 and
/// every avatar rendered that way is a permanent grey circle. This widget
/// pulls the bytes through [ApiClient] instead and renders them from memory.
class AuthedAvatar extends ConsumerWidget {
  final String? url;
  final double radius;
  final Color backgroundColor;
  final Widget fallback;

  const AuthedAvatar({
    super.key,
    required this.url,
    required this.radius,
    this.backgroundColor = AppColors.border,
    this.fallback =
        const Icon(Icons.person, color: AppColors.textSecondary),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = url;
    if (target == null || target.isEmpty) {
      return CircleAvatar(
          radius: radius, backgroundColor: backgroundColor, child: fallback);
    }
    final bytes = ref.watch(avatarBytesProvider(target)).valueOrNull;
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      foregroundImage: bytes == null ? null : MemoryImage(bytes),
      child: fallback,
    );
  }
}
