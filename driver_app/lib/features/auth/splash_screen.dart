import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// The pre-auth landing — `Splash Screen.jpg` in Figma.
///
/// Dark navy top half with the branded illustration, white bottom half with
/// the Hoppin GO wordmark and a "Get Started" CTA that navigates to /login.
///
/// This is NOT an animated SplashScreen / native launch image — it is the
/// first interactive screen a driver sees before they have authenticated.
/// On launch the router's redirect sends signed-out visitors to /login;
/// from there, "I have an invite" flows through /reset. This screen is the
/// human-facing "you are in the right place" moment before sign-in.
class DriverSplashScreen extends StatelessWidget {
  const DriverSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Navy illustration half ──────────────────────────────────────
          Expanded(
            flex: 5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(hoppin.spacing.xl),
                    child: _SplashIllustration(colors: colors),
                  ),
                ),
              ),
            ),
          ),

          // ── White wordmark + CTA half ───────────────────────────────────
          Expanded(
            flex: 4,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  hoppin.spacing.gutter,
                  hoppin.spacing.xl,
                  hoppin.spacing.gutter,
                  hoppin.spacing.xl,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Wordmark. Flexible so the 88px logo + 44pt display type
                    // give way before the Column does: this half is a fixed
                    // 4/10 flex share, and on a short or landscape viewport the
                    // lockup plus the CTA was overflowing it by ~8px — enough
                    // to stripe the bottom of the first screen a driver sees.
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _HoppinGoLogo(colors: colors),
                            SizedBox(height: hoppin.spacing.sm),
                            Text(
                              "HOPPIN' GO",
                              style: hoppin.type.display.copyWith(
                                color: colors.accent,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: hoppin.spacing.lg),

                    // CTA — never scaled and never yielded; it is the only way
                    // off this screen.
                    HopButton.primary(
                      label: 'Get Started',
                      icon: Icons.arrow_forward,
                      onPressed: () => context.go('/login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Hoppin GO circular logo — taxi silhouette in a circle with wifi-style
/// arcs below and a pin dot at the bottom. Matches the Figma wordmark lockup.
class _HoppinGoLogo extends StatelessWidget {
  const _HoppinGoLogo({required this.colors});

  final HoppinColors colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: CustomPaint(
        painter: _LogoPainter(accent: colors.accent, onAccent: colors.onAccent),
      ),
    );
  }
}

/// Paints the circular Hoppin GO mark: outer ring → car silhouette → three
/// wifi arcs below → pin tip. Proportions match the Figma export.
class _LogoPainter extends CustomPainter {
  const _LogoPainter({required this.accent, required this.onAccent});

  final Color accent;
  final Color onAccent;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    final ringPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06;

    final fillPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.fill;

    final whitePaint = Paint()
      ..color = onAccent
      ..style = PaintingStyle.fill;

    // Outer circle ring
    canvas.drawCircle(Offset(cx, cy * 0.78), r * 0.74, ringPaint);

    // Car body — simple rounded rect in the upper half
    final carRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, cy * 0.68),
        width: size.width * 0.44,
        height: size.height * 0.22,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(carRect, fillPaint);

    // Car roof
    final roofPath = Path()
      ..moveTo(cx - size.width * 0.12, cy * 0.58)
      ..lineTo(cx - size.width * 0.06, cy * 0.45)
      ..lineTo(cx + size.width * 0.06, cy * 0.45)
      ..lineTo(cx + size.width * 0.12, cy * 0.58)
      ..close();
    canvas.drawPath(roofPath, fillPaint);

    // Wheels
    canvas.drawCircle(
      Offset(cx - size.width * 0.13, cy * 0.82),
      size.width * 0.05,
      whitePaint,
    );
    canvas.drawCircle(
      Offset(cx + size.width * 0.13, cy * 0.82),
      size.width * 0.05,
      whitePaint,
    );

    // Wifi arcs below the circle (three, narrowing toward the tip)
    final arcPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final arcTop = cy * 1.56;
    for (var i = 0; i < 3; i++) {
      final w = size.width * (0.28 - i * 0.08);
      final h = size.height * (0.10 - i * 0.025);
      arcPaint.strokeWidth = size.width * (0.055 - i * 0.01);
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(cx, arcTop - i * size.height * 0.06),
          width: w,
          height: h,
        ),
        0,
        3.14159,
        false,
        arcPaint,
      );
    }

    // Pin dot at the very bottom
    canvas.drawCircle(
      Offset(cx, size.height * 0.97),
      size.width * 0.045,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.accent != accent || old.onAccent != onAccent;
}

/// Illustration for the navy half — placeholder geometric that reads as a
/// driver-in-car-with-phone layout. Matches Figma dark-navy half silhouette.
class _SplashIllustration extends StatelessWidget {
  const _SplashIllustration({required this.colors});

  final HoppinColors colors;

  @override
  Widget build(BuildContext context) {
    // Dim white lines on dark — the Figma illustration style.
    final lineColor = colors.onAccent.withValues(alpha: 0.18);
    final accentLine = colors.onAccent.withValues(alpha: 0.60);

    return AspectRatio(
      aspectRatio: 1.2,
      child: CustomPaint(
        painter: _IllustrationPainter(
          lineColor: lineColor,
          accentLine: accentLine,
          errorColor: colors.error,
          onAccent: colors.onAccent,
        ),
      ),
    );
  }
}

/// Minimal illustration: car silhouette + phone with map pin. Matches the
/// Figma composition (driver seated, map card visible, gear icon top-left).
class _IllustrationPainter extends CustomPainter {
  const _IllustrationPainter({
    required this.lineColor,
    required this.accentLine,
    required this.errorColor,
    required this.onAccent,
  });

  final Color lineColor;
  final Color accentLine;
  final Color errorColor;
  final Color onAccent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final line = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final accent = Paint()
      ..color = accentLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final red = Paint()
      ..color = errorColor
      ..style = PaintingStyle.fill;

    final white = Paint()
      ..color = onAccent
      ..style = PaintingStyle.fill;

    // Car outline
    final carBody = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.05, h * 0.55, w * 0.62, h * 0.30),
      const Radius.circular(12),
    );
    canvas.drawRRect(carBody, line);

    // Car roof
    final roofPath = Path()
      ..moveTo(w * 0.14, h * 0.55)
      ..lineTo(w * 0.20, h * 0.36)
      ..lineTo(w * 0.52, h * 0.36)
      ..lineTo(w * 0.60, h * 0.55);
    canvas.drawPath(roofPath, line);

    // Windscreen
    final windscreen = Path()
      ..moveTo(w * 0.22, h * 0.55)
      ..lineTo(w * 0.27, h * 0.39)
      ..lineTo(w * 0.48, h * 0.39)
      ..lineTo(w * 0.55, h * 0.55);
    canvas.drawPath(windscreen, accent);

    // Driver silhouette (simple circle head + body)
    canvas.drawCircle(Offset(w * 0.30, h * 0.48), w * 0.06, line);
    canvas.drawLine(
      Offset(w * 0.30, h * 0.54),
      Offset(w * 0.30, h * 0.64),
      line,
    );

    // Wheels
    canvas.drawCircle(Offset(w * 0.18, h * 0.85), w * 0.07,
        line..color = lineColor);
    canvas.drawCircle(Offset(w * 0.54, h * 0.85), w * 0.07, line);

    // Phone / map card in the top right — red border frame
    final phoneFrame = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.58, h * 0.10, w * 0.36, h * 0.52),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      phoneFrame,
      Paint()
        ..color = errorColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Map grid lines inside phone
    for (var i = 1; i < 4; i++) {
      canvas.drawLine(
        Offset(w * 0.58, h * (0.10 + i * 0.10)),
        Offset(w * 0.94, h * (0.10 + i * 0.10)),
        accent,
      );
    }
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(w * (0.58 + i * 0.12), h * 0.10),
        Offset(w * (0.58 + i * 0.12), h * 0.52),
        accent,
      );
    }

    // Map pin on the phone
    canvas.drawCircle(Offset(w * 0.76, h * 0.24), w * 0.04, red);
    canvas.drawCircle(Offset(w * 0.76, h * 0.24), w * 0.02, white);

    // Dashed route line on the phone
    final dashPaint = Paint()
      ..color = errorColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(
        Offset(w * 0.76, h * (0.28 + i * 0.04)),
        Offset(w * 0.76, h * (0.30 + i * 0.04)),
        dashPaint,
      );
    }

    // Gear icon (top-left, very simple)
    canvas.drawCircle(Offset(w * 0.13, h * 0.14), w * 0.07,
        line..color = lineColor);
    canvas.drawCircle(Offset(w * 0.13, h * 0.14), w * 0.03, line);
  }

  @override
  bool shouldRepaint(_IllustrationPainter old) => false;
}
