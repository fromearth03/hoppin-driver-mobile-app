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

  static const _trackPadding = 4.0;
  static const _spinnerSize = 13.0;
  static const _spinnerGap = 8.0;
  static const _chipTextPadding = 16.0;

  static const _labelStyle = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  /// The chip has to hold whichever label is showing, so it is measured
  /// rather than guessed. A fixed width that fitted "Go online" clipped
  /// "Going online…" and its spinner.
  static double _chipWidth(String label, bool busy, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: _labelStyle),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final spinner = busy ? _spinnerSize + _spinnerGap : 0.0;
    return painter.width + spinner + _chipTextPadding * 2;
  }

  /// Wide enough for the longest state the pill can reach, so the track never
  /// resizes underneath the chip as it slides — a track that grew mid-animation
  /// would make the whole control jump on tap.
  static double _widestChip(bool online, TextScaler scaler) {
    final candidates = [
      _chipWidth(online ? 'Go offline' : 'Go online', false, scaler),
      _chipWidth(online ? 'Going offline…' : 'Going online…', true, scaler),
    ];
    return candidates.reduce((a, b) => a > b ? a : b);
  }

  /// Where the chip sits mid-flight: the state being moved TO, so the pill
  /// animates in the direction the driver asked for.
  bool get _shown => isBusy ? !isOnline : isOnline;

  /// The chip names what a tap would DO, not the state the driver is
  /// already in.
  ///
  /// A driver looking at a pill that reads "Offline" while they are offline
  /// learns nothing they did not know, and the one thing they need — how to
  /// change it — is unsaid. Naming the action makes the control explain
  /// itself: "Go online" is a button, "Offline" is a label.
  String get _label {
    if (isBusy) return isOnline ? 'Going offline…' : 'Going online…';
    return isOnline ? 'Go offline' : 'Go online';
  }

  /// What the driver's presence actually is, for the screen reader and for
  /// the resting state text beside the chip.
  String get _stateLabel => isOnline ? 'Online' : 'Offline';

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final chip = _widestChip(isOnline, scaler);
    // The chip slides within the track, so the track is the chip plus the
    // travel it needs. Too little travel and the two rest states look
    // identical; too much and the pill sprawls across the app bar.
    final trackWidth = chip + _chipTravel + _trackPadding * 2;
    return _build(context, chip, trackWidth);
  }

  /// How far the chip moves between offline and online.
  static const _chipTravel = 34.0;

  Widget _build(BuildContext context, double chipWidth, double trackWidth) =>
      Semantics(
        button: true,
        enabled: _enabled,
        toggled: _shown,
        // The screen reader gets the state and the action, in that order —
        // the visual chip only has room for the action.
        label: isBusy ? _label : '$_stateLabel. ${_label}',
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
              // 🔴 Sized to the longest label rather than a round number.
              // "Going online…" plus its spinner needs ~131px of chip, and a
              // 168px track left the chip overflowing its own glass: the text
              // ellipsised to "Going online…" cut short and the green pill
              // bled past the track's rounded end.
              width: trackWidth,
              height: 42,
              padding: const EdgeInsets.all(_trackPadding),
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
                  width: chipWidth,
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
                          // The chip is measured to fit this text, so an
                          // ellipsis here would mean the measurement was
                          // wrong rather than the label being too long.
                          overflow: TextOverflow.ellipsis,
                          style: _labelStyle,
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
