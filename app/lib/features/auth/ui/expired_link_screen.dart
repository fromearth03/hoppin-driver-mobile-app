import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/brand_header.dart';

/// A dead password-reset link.
///
/// The design draws this as "We're Almost There" over a loading ring. It is
/// not loading — the link is finished, and a spinner that never resolves is
/// the one thing a driver must not be shown here. The chrome is the design's;
/// the words say what actually happened and what fixes it.
/// The design's ring, drawn as a static arc.
class _RingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = (size.shortestSide - 10) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = AppColors.border;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.butt
      ..color = AppColors.primary;

    canvas.drawCircle(centre, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -1.5708, // twelve o'clock
      4.5239, // ~72% of the circle, as the design draws it
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ExpiredLinkScreen extends StatelessWidget {
  const ExpiredLinkScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BrandHeader(
                    title: 'Link Expired',
                    subtitle:
                        'Password reset links are valid for a short time. '
                        'Request a new one and it will arrive in a moment.',
                    onBack: () => context.go(Routes.signIn),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(26, 48, 26, 24),
                    child: Column(
                      children: [
                        // The design's ring, static and captioned — it marks
                        // the state rather than implying work in progress.
                        SizedBox(
                          height: 200,
                          width: 200,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Painted, not a progress indicator. The
                              // design's ring is the right shape here, but
                              // anything that can spin says "working" — and
                              // nothing is working; the link is dead.
                              CustomPaint(
                                size: const Size(200, 200),
                                painter: _RingPainter(),
                              ),
                              Text(
                                'EXPIRED',
                                style: AppText.body.copyWith(
                                  letterSpacing: 4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 48),
                        AppButton(
                          label: 'Try Again',
                          style: AppButtons.deep(),
                          onPressed: () => context.go(Routes.forgotPassword),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => context.go(Routes.signIn),
                          child: const Text('Back to Sign In'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
