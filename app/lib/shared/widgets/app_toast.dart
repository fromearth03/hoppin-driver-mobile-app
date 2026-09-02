import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

/// How much the driver needs to care.
enum ToastSeverity {
  /// A fact worth knowing: a trip closed, a payout landed.
  info,

  /// Money, compliance, or safety. Stays until it is dismissed, because a
  /// penalty the driver blinked past is one they will dispute a week later
  /// with no idea what it was for.
  critical,
}

/// The in-app heads-up for something that happened elsewhere.
///
/// A push notification only shows while the app is in the background; with
/// the app open, FCM hands the payload straight to the client and the driver
/// sees nothing at all. That is exactly when a penalty or a cancelled ride
/// matters most, so it is said here — over whatever screen they are on,
/// including the map.
///
/// Deliberately not a SnackBar: those queue behind one another, sit at the
/// bottom where the trip sheet already lives, and cannot be made persistent
/// without also blocking the controls underneath.
class AppToast {
  AppToast._();

  static OverlayEntry? _current;
  static Timer? _timer;

  /// Shows [title] and [body] over the current screen.
  ///
  /// Replaces whatever is already up: two of these stacked would cover the
  /// screen, and the newest news is the news.
  static void show(
    BuildContext context, {
    required String title,
    required String body,
    ToastSeverity severity = ToastSeverity.info,
    VoidCallback? onTap,
    bool haptics = true,
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    dismiss();

    if (haptics) {
      // Critical news earns a heavier knock. Both are best-effort — a
      // handset with the motor disabled must not take the toast down with
      // it.
      final feedback = severity == ToastSeverity.critical
          ? HapticFeedback.heavyImpact()
          : HapticFeedback.lightImpact();
      unawaited(feedback.catchError((_) {}));
      unawaited(SystemSound.play(SystemSoundType.alert).catchError((_) {}));
    }

    final entry = OverlayEntry(
      builder: (context) => _ToastCard(
        title: title,
        body: body,
        severity: severity,
        onTap: () {
          dismiss();
          onTap?.call();
        },
        onDismiss: dismiss,
      ),
    );
    _current = entry;
    overlay.insert(entry);

    // Info clears itself; critical waits to be acknowledged.
    if (severity == ToastSeverity.info) {
      _timer = Timer(const Duration(seconds: 4), dismiss);
    }
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _current?.remove();
    _current = null;
  }
}

class _ToastCard extends StatefulWidget {
  final String title;
  final String body;
  final ToastSeverity severity;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _ToastCard({
    required this.title,
    required this.body,
    required this.severity,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  bool get _critical => widget.severity == ToastSeverity.critical;

  @override
  Widget build(BuildContext context) {
    final accent = _critical ? AppColors.negative : AppColors.primary;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      right: 12,
      child: AnimatedBuilder(
        animation: _in,
        builder: (context, child) {
          final t = Curves.easeOutBack.transform(_in.value.clamp(0, 1));
          return Transform.translate(
            offset: Offset(0, (1 - t) * -70),
            child: Opacity(opacity: _in.value.clamp(0, 1), child: child),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: Dismissible(
            key: ValueKey(widget.title),
            direction: DismissDirection.up,
            onDismissed: (_) => widget.onDismiss(),
            child: GestureDetector(
              onTap: widget.onTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: accent.withValues(alpha: 0.45)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 18,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 38,
                          width: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _critical
                                ? Icons.warning_amber_rounded
                                : Icons.notifications_none,
                            color: accent,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.caption,
                              ),
                            ],
                          ),
                        ),
                        // Only the persistent one needs a way out; the timed
                        // one is gone before a close button is worth reaching
                        // for, and swipe-up dismisses either.
                        if (_critical)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            color: AppColors.textSecondary,
                            onPressed: widget.onDismiss,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
