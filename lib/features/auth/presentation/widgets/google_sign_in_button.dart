import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:priceshield/core/theme/app_theme.dart';

/// Outlined button following Google Sign-In styling with a crisp vector 'G' mark.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.loading = false,
    this.disabled = false,
    this.label = 'Continue with Google',
  });

  final VoidCallback? onPressed;
  final bool loading;
  final bool disabled;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDisabled = disabled || loading;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        key: const Key('google_sign_in_button'),
        onPressed: isDisabled ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: PriceShieldColors.text,
          side: const BorderSide(color: PriceShieldColors.border, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: PriceShieldColors.navy,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CustomPaint(painter: _GoogleLogoPainter()),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: PriceShieldColors.text,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.20;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    double rad(double deg) => deg * math.pi / 180;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Red top-left to top-right arc
    paint.color = const Color(0xffEA4335);
    canvas.drawArc(rect, rad(-145), rad(110), false, paint);

    // Yellow left arc
    paint.color = const Color(0xffFBBC05);
    canvas.drawArc(rect, rad(145), rad(70), false, paint);

    // Green bottom arc
    paint.color = const Color(0xff34A853);
    canvas.drawArc(rect, rad(35), rad(110), false, paint);

    // Blue right-bottom arc
    paint.color = const Color(0xff4285F4);
    canvas.drawArc(rect, rad(-5), rad(42), false, paint);

    // Blue horizontal crossbar of 'G'
    final barPaint = Paint()
      ..color = const Color(0xff4285F4)
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(size.width - stroke * 0.15, center.dy),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
