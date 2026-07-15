import 'package:flutter/material.dart';

import '../models/sport_match.dart';
import '../utils/tennis_country_map.dart';

Path buildOctagonPath(Rect rect, {double cutRatio = 0.15}) {
  final cut = rect.shortestSide * cutRatio;
  return Path()
    ..moveTo(rect.left + cut, rect.top)
    ..lineTo(rect.right - cut, rect.top)
    ..lineTo(rect.right, rect.top + cut)
    ..lineTo(rect.right, rect.bottom - cut)
    ..lineTo(rect.right - cut, rect.bottom)
    ..lineTo(rect.left + cut, rect.bottom)
    ..lineTo(rect.left, rect.bottom - cut)
    ..lineTo(rect.left, rect.top + cut)
    ..close();
}

class OctagonClipper extends CustomClipper<Path> {
  const OctagonClipper({this.cutRatio = 0.15});

  final double cutRatio;

  @override
  Path getClip(Size size) =>
      buildOctagonPath(Offset.zero & size, cutRatio: cutRatio);

  @override
  bool shouldReclip(covariant OctagonClipper oldClipper) =>
      oldClipper.cutRatio != cutRatio;
}

class OctagonBorderPainter extends CustomPainter {
  const OctagonBorderPainter({
    required this.color,
    required this.strokeWidth,
    this.cutRatio = 0.15,
    this.gradientColors,
  });

  final Color color;
  final double strokeWidth;
  final double cutRatio;

  /// When set (2+ colours), the stroke uses a top-left→bottom-right gradient
  /// instead of the flat [color] — used to reflect an equipped avatar border.
  final List<Color>? gradientColors;

  @override
  void paint(Canvas canvas, Size size) {
    if (strokeWidth <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final gradient = gradientColors;
    if (gradient != null && gradient.length >= 2) {
      paint.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradient,
      ).createShader(Offset.zero & size);
    } else {
      paint.color = color;
    }
    canvas.drawPath(
      buildOctagonPath(Offset.zero & size, cutRatio: cutRatio),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant OctagonBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.cutRatio != cutRatio ||
      !identical(oldDelegate.gradientColors, gradientColors);
}

class TeamLogo extends StatelessWidget {
  const TeamLogo({
    required this.team,
    required this.width,
    required this.height,
    this.cutBottomRight = true,
    this.sport,
    super.key,
  });

  final SportTeam team;
  final double width;
  final double height;
  final bool cutBottomRight;
  /// When [Sport.tennis], the logo shows the player's country abbreviation
  /// (e.g. "ESP") tinted with the country's primary flag colour.
  final Sport? sport;

  @override
  Widget build(BuildContext context) {
    String label = team.shortName;
    Color color = team.id == 'mc' ? const Color(0xff74acde) : team.color;

    // For tennis, resolve country abbreviation + flag colour.
    if (sport == Sport.tennis) {
      final code = TennisCountryMap.countryCodeFor(team.name);
      if (code != null) {
        label = code;
        color = TennisCountryMap.colorFor(code);
      }
    }

    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _TeamLogoPainter(label: label, color: color),
      ),
    );
  }
}

class _TeamLogoPainter extends CustomPainter {
  const _TeamLogoPainter({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final bodyHeight = size.height * 0.9;
    final shadowOffset = size.height - bodyHeight;
    final cut = size.shortestSide * 0.15;
    final bodyRect = Rect.fromLTWH(0, 0, size.width, bodyHeight);
    final bodyPath = buildOctagonPath(bodyRect, cutRatio: cut / bodyRect.shortestSide);

    canvas.drawPath(
      bodyPath.shift(Offset(0, shadowOffset)),
      Paint()..color = Color.lerp(color, Colors.black, 0.58)!,
    );
    canvas.drawPath(bodyPath, Paint()..color = color);

    final textColor = color.computeLuminance() > 0.48
        ? Colors.black
        : Colors.white;

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: textColor,
          fontFamily: 'Onest',
          fontSize: size.width * _fontScale(label),
          fontWeight: FontWeight.w700,
          height: 1,
          letterSpacing: 0,
          decoration: TextDecoration.none,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);

    final textOffset = Offset(
      (size.width - textPainter.width) / 2,
      (bodyHeight - textPainter.height) / 2 + bodyHeight * 0.055,
    );
    textPainter.paint(canvas, textOffset);
  }

  double _fontScale(String text) => switch (text.length) {
    <= 2 => 0.38,
    3 => 0.33,
    _ => 0.28,
  };

  @override
  bool shouldRepaint(covariant _TeamLogoPainter oldDelegate) =>
      oldDelegate.label != label || oldDelegate.color != color;
}
