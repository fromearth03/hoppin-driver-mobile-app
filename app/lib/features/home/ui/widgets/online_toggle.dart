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

  const OnlineToggle({super.key, required this.isOnline, this.onChanged});

  bool get _enabled => onChanged != null;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: _enabled,
        toggled: isOnline,
        label: isOnline ? 'Online' : 'Offline',
        child: GestureDetector(
          onTap: _enabled ? () => onChanged!(!isOnline) : null,
          child: Opacity(
            opacity: _enabled ? 1 : 0.5,
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
                    isOnline ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        isOnline ? AppColors.positive : AppColors.negative,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    isOnline ? 'Online' : 'Offline',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
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
