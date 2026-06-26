import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/avatar_option.dart';
import '../../../models/sport_match.dart';
import '../../../widgets/team_logo.dart';

/// Octagon-clipped player (or team) avatar used on ranked rows and podiums.
/// Shows a deterministic face for a display [name] (or a [team] crest), with an
/// optional equipped-frame ring ([frameColors]). Shared by the leaderboard and
/// the friends arena so a rival looks identical wherever they appear.
class RivalAvatar extends StatelessWidget {
  const RivalAvatar({
    required this.name,
    required this.size,
    this.highlight = false,
    this.ring,
    this.team,
    this.frameColors,
    super.key,
  });

  final String name;
  final double size;
  final bool highlight;
  final Color? ring;
  final SportTeam? team;

  /// The equipped avatar frame's gradient, drawn as the octagon ring. Set only
  /// for the user's own row so their cosmetic reflects on the board.
  final List<Color>? frameColors;

  @override
  Widget build(BuildContext context) {
    final hasFrame = frameColors != null && frameColors!.length >= 2;

    if (team != null) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: TeamLogo(
                team: team!,
                width: size,
                height: size,
                cutBottomRight: false,
              ),
            ),
            if (hasFrame)
              CustomPaint(
                painter: OctagonBorderPainter(
                  color: Cyber.cyan,
                  strokeWidth: 4,
                  gradientColors: frameColors,
                ),
              ),
          ],
        ),
      );
    }

    final color = ring ?? (highlight ? Cyber.cyan : Cyber.line);
    final avatar = avatarForName(name);
    final borderWidth = hasFrame ? 4.0 : (highlight ? 2.0 : 1.2);
    final borderColor = color.withValues(alpha: highlight ? 0.9 : 0.42);

    return SizedBox(
      width: size,
      height: size,
      child: ClipPath(
        clipper: const OctagonClipper(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Cyber.panel),
            Image.asset(
              avatar.assetPath,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
            CustomPaint(
              painter: OctagonBorderPainter(
                color: borderColor,
                strokeWidth: borderWidth,
                gradientColors: hasFrame ? frameColors : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chamfered (top-left / bottom-right cut) surface decoration shared by ranked
/// rows, podium tiles and the friends-arena rows. Keeps one silhouette across
/// the HUD "hardware" family.
ShapeDecoration cutCornerDecoration({
  required Color color,
  Color borderColor = Colors.transparent,
  double borderWidth = 1,
  double cut = 14,
}) {
  return ShapeDecoration(
    color: color,
    shape: CutCornerBorder(
      cut: cut,
      side: BorderSide(color: borderColor, width: borderWidth),
    ),
  );
}

class CutCornerBorder extends ShapeBorder {
  const CutCornerBorder({required this.cut, this.side = BorderSide.none});

  final double cut;
  final BorderSide side;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  ShapeBorder scale(double t) {
    return CutCornerBorder(cut: cut * t, side: side.scale(t));
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return getOuterPath(rect.deflate(side.width), textDirection: textDirection);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final safeCut = cut.clamp(0, rect.shortestSide / 2).toDouble();
    return Path()
      ..moveTo(rect.left + safeCut, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.bottom - safeCut)
      ..lineTo(rect.right - safeCut, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top + safeCut)
      ..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width <= 0) return;
    final paint = side.toPaint()..style = PaintingStyle.stroke;
    canvas.drawPath(getOuterPath(rect, textDirection: textDirection), paint);
  }
}
