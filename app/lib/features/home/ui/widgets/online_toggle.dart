import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';

/// The design's segmented presence pill: a grey track holding one sliding
/// chip — red "Offline" resting left, green "Online" resting right. One tap
/// flips it. (Replaces a Material [Switch] beside a text label, which was
/// the design system's shape but not this design's.)
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
            child: Container(
              width: 168,
              height: 42,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(30),
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
      );
}
