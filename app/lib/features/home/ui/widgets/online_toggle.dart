import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';

/// The design's segmented presence pill: a frosted-glass track holding one
/// sliding chip — red "Offline" resting left, green "Online" resting right.
/// One tap flips it. The track is glass (translucent white over a backdrop
/// blur) because the pill floats over the home content and the design keeps
/// what is behind it readable through it.
class OnlineToggle extends StatelessWidget {
  final bool isOnline;
  final ValueChanged<bool>? onChanged;

  /// True while the presence change is in flight.
  ///
  /// Going online is a round trip — and on a cold start it waits on a GPS
  /// fix behind it — so the pill can sit in the old position for seconds.
  /// A driver who reads that as "the tap missed" taps again, and the second
  /// tap is the one that flips them straight back. Busy is therefore louder
  /// than the blocked state: dimmer, spinning, and naming the direction of
  /// travel rather than the presence it has not reached yet.
  final bool isBusy;

  const OnlineToggle({
    super.key,
    required this.isOnline,
    this.onChanged,
    this.isBusy = false,
  });

  bool get _enabled => onChanged != null && !isBusy;

  /// Where the chip sits mid-flight: the state being moved TO, so the pill
  /// animates in the direction the driver asked for.
  bool get _shown => isBusy ? !isOnline : isOnline;

  String get _label {
    if (isBusy) return isOnline ? 'Going offline…' : 'Going online…';
    return isOnline ? 'Online' : 'Offline';
  }

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: _enabled,
        toggled: _shown,
        label: _label,
        child: GestureDetector(
          onTap: _enabled ? () => onChanged!(!isOnline) : null,
          child: Opacity(
            // Busy reads as unmistakably inert; merely blocked stays
            // legible, because the list beside it explains itself.
            opacity: isBusy ? 0.35 : (_enabled ? 1 : 0.5),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
              width: 168,
              height: 42,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textPrimary.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment:
                    _shown ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: isBusy ? 122 : 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _shown ? AppColors.positive : AppColors.negative,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isBusy) ...[
                        const SizedBox(
                          height: 13,
                          width: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          _label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
