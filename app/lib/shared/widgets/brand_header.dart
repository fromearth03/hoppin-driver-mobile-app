import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';

/// The indigo gradient panel every unauthenticated screen opens with.
///
/// The bottom-right corner is rounded and the rest square, which is the
/// shape the brand uses to point down into the form beneath it.
class BrandHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;

  /// The share of the viewport the panel takes. The design gives it ~40% of
  /// a 932pt artboard above the form; expressed as a fraction so a shorter
  /// screen shrinks the panel instead of pushing the form out of sight.
  final double heightFactor;

  /// Floor for the fraction, so the title never crushes on a small device.
  static const _minHeight = 260.0;

  const BrandHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.heightFactor = 0.42,
  });

  @override
  Widget build(BuildContext context) => Container(
        height: (MediaQuery.sizeOf(context).height * heightFactor)
            .clamp(_minHeight, 420.0),
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomLeft,
            colors: [AppColors.primaryLight, AppColors.primaryDark],
          ),
          borderRadius: BorderRadius.only(
            bottomRight: Radius.circular(96),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 8, 26, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (onBack != null)
                  Material(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onBack,
                      child: const SizedBox(
                        height: 40,
                        width: 40,
                        child: Icon(Icons.arrow_back,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 44,
                    height: 1.1,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}

/// The wordmark that closes every unauthenticated screen.
class BrandFooter extends StatelessWidget {
  const BrandFooter({super.key});

  @override
  Widget build(BuildContext context) => const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_on, color: AppColors.accent, size: 30),
          SizedBox(width: 6),
          Text(
            'Hoppin’ Go',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      );
}
