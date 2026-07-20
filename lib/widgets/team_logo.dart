import 'package:flutter/material.dart';

import '../data/team_palettes.dart';
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
    // Colours come from the shared team database (fill + contrast-checked label
    // + accent edge), which also covers teams the ESPN sweep never saw.
    TeamPalette palette = paletteForTeam(team, sport: sport);

    // For tennis, resolve nationality: a real flag image when the feed
    // carries one (ESPN's athlete.flag.href), else a flag-emoji badge tinted
    // with the country's colour, else a neutral globe.
    if (sport == Sport.tennis) {
      final code = TennisCountryMap.countryCodeFor(team.name);
      if (code != null) {
        palette = derivePalette(TennisCountryMap.colorFor(code));
        label = TennisCountryMap.flagEmojiFor(code) ?? code;
      } else {
        label = '🌐';
      }
      final flagUrl = team.flagUrl;
      if (flagUrl != null) {
        return _TennisFlagBadge(
          url: flagUrl,
          width: width,
          height: height,
          palette: palette,
          fallbackLabel: label,
        );
      }
    }

    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _TeamLogoPainter(label: label, palette: palette),
      ),
    );
  }
}

/// A real flag image (network-fetched) clipped to the shared octagon badge
/// shape, with the same accent edge the code-drawn badges use. Falls back to
/// the emoji/colour badge if the image fails to load.
class _TennisFlagBadge extends StatelessWidget {
  const _TennisFlagBadge({
    required this.url,
    required this.width,
    required this.height,
    required this.palette,
    required this.fallbackLabel,
  });

  final String url;
  final double width;
  final double height;
  final TeamPalette palette;
  final String fallbackLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ClipPath(
        clipper: const OctagonClipper(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: palette.primary),
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => CustomPaint(
                painter: _TeamLogoPainter(label: fallbackLabel, palette: palette),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                widthFactor: 1,
                heightFactor: 0.11,
                child: ColoredBox(color: palette.secondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamLogoPainter extends CustomPainter {
  const _TeamLogoPainter({required this.label, required this.palette});

  final String label;
  final TeamPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final color = palette.primary;
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

    // Secondary accent edge: a flat band along the bottom of the badge, clipped
    // to the octagon so it inherits the chamfer. Badges are persistent chrome,
    // so this never glows — it reads as a club colour, not as "live".
    final accentHeight = bodyHeight * 0.11;
    canvas.save();
    canvas.clipPath(bodyPath);
    canvas.drawRect(
      Rect.fromLTWH(0, bodyHeight - accentHeight, size.width, accentHeight),
      Paint()..color = palette.secondary,
    );
    canvas.restore();

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: palette.text,
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

    // Centre the label in the space above the accent band, keeping the small
    // optical nudge the badge has always had.
    final labelBand = bodyHeight - accentHeight;
    final textOffset = Offset(
      (size.width - textPainter.width) / 2,
      (labelBand - textPainter.height) / 2 + labelBand * 0.04,
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
      oldDelegate.label != label ||
      oldDelegate.palette.primary != palette.primary ||
      oldDelegate.palette.text != palette.text ||
      oldDelegate.palette.secondary != palette.secondary;
}
