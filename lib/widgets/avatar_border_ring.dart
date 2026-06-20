import 'package:flutter/material.dart';

import '../models/avatar_border_option.dart';
import 'team_logo.dart' show buildOctagonPath;

enum AvatarBorderShape { roundedRect, octagon }

/// Wraps [child] with the equipped [border]'s ring: a 4px team-colour gradient
/// band plus a 2px raised inner edge (the "elevated" bevel). When [border] is
/// null it returns [child] untouched (no ring).
///
/// Per THE GLOW RULE the soft accent halo is opt-in via [glow] — set it only on
/// the equipped / single focal instance, never on resting catalogue tiles.
class AvatarBorderRing extends StatelessWidget {
  const AvatarBorderRing({
    required this.border,
    required this.child,
    this.shape = AvatarBorderShape.roundedRect,
    this.cornerRadius = 0,
    this.glow = false,
    super.key,
  });

  final AvatarBorderOption? border;
  final Widget child;
  final AvatarBorderShape shape;
  final double cornerRadius;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final option = border;
    if (option == null) return child;
    return CustomPaint(
      foregroundPainter: _AvatarBorderRingPainter(
        primary: option.primary,
        band: borderRingColors(option.primary),
        raised: borderRaisedEdge(option.primary),
        shape: shape,
        cornerRadius: cornerRadius,
        glow: glow,
      ),
      child: child,
    );
  }
}

class _AvatarBorderRingPainter extends CustomPainter {
  const _AvatarBorderRingPainter({
    required this.primary,
    required this.band,
    required this.raised,
    required this.shape,
    required this.cornerRadius,
    required this.glow,
  });

  final Color primary;
  final List<Color> band;
  final Color raised;
  final AvatarBorderShape shape;
  final double cornerRadius;
  final bool glow;

  Path _path(Size size, double inset) {
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    switch (shape) {
      case AvatarBorderShape.octagon:
        // Keep the chamfer proportional to the full box (not the inset rect) so
        // every layer of the ring tracks the same octagon silhouette.
        final cut = size.shortestSide * 0.15;
        return buildOctagonPath(rect, cutRatio: cut / rect.shortestSide);
      case AvatarBorderShape.roundedRect:
        return Path()
          ..addRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius)),
          );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Optional scarce halo behind the band — only when this is the live/equipped
    // instance (glow rule).
    if (glow) {
      canvas.drawPath(
        _path(size, 2),
        Paint()
          ..color = primary.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
    // 4px gradient band, stroke centred at inset 2 (covers the outer 0–4px).
    canvas.drawPath(
      _path(size, 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: band,
        ).createShader(Offset.zero & size),
    );
    // 2px raised inner edge in the lightened primary, centred at inset 5
    // (covers 4–6px) — reads as a bevel lifting the band off the avatar.
    canvas.drawPath(
      _path(size, 5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = raised,
    );
  }

  @override
  bool shouldRepaint(_AvatarBorderRingPainter old) =>
      old.primary != primary ||
      old.raised != raised ||
      old.shape != shape ||
      old.cornerRadius != cornerRadius ||
      old.glow != glow;
}
