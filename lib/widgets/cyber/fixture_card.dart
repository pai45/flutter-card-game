import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// Shared "fixture card" look extracted from the match prediction card so the
/// pick market cards read as the same hardware family: a neutral dark-navy
/// panel with a vertical gradient body, a square top edge carrying a centred
/// status notch, chamfered bottom corners, and a hard (un-blurred) drop shadow
/// that follows the same silhouette.
// ── Palette ───────────────────────────────────────────────────────────────────
const kFixtureBase = Color(0xff141c2b);
const kFixtureTop = Color(0xff1b2336);
const kFixtureBottom = Color(0xff121a28);
const kFixtureBorder = Color(0xff2a3550);
const kFixtureShadow = Color(0xff04060b);
const kFixtureStripDark = Color(0xff0f1826);
const kFixtureStripBlue = Color(0xff173a5e);
const kFixtureTimeGold = Color(0xffc8a45a);

// Top-centre notch geometry (shared by the card shape + the tag overlay).
const double kFixtureNotchFloor = 96;
const double kFixtureNotchDepth = 22;
const double kFixtureNotchSlope = 12;

/// A composed fixture card: hard drop shadow, the clipped/bordered silhouette,
/// a gradient [body], an optional [bottomStrip] flush to the bottom chamfer,
/// and an optional [tag] that sits inside the top notch reading against the
/// page background.
class FixtureCardFrame extends StatelessWidget {
  const FixtureCardFrame({
    required this.body,
    this.tag,
    this.bodyFooter,
    this.bottomStrip,
    this.onTap,
    super.key,
  });

  final Widget body;
  final Widget? tag;
  final Widget? bodyFooter;
  final Widget? bottomStrip;
  final VoidCallback? onTap;

  bool get _notched => tag != null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: FixtureCardShadowPainter(notched: _notched),
            ),
          ),
          Material(
            color: kFixtureBase,
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            shape: FixtureCardShape(
              cut: 12,
              notchWidth: _notched ? kFixtureNotchFloor : 0,
              notchDepth: _notched ? kFixtureNotchDepth : 0,
              notchSlope: _notched ? kFixtureNotchSlope : 0,
              side: const BorderSide(color: kFixtureBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [kFixtureTop, kFixtureBottom],
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      14,
                      _notched ? 28 : 14,
                      14,
                      12,
                    ),
                    child: body,
                  ),
                ),
                ?bodyFooter,
                ?bottomStrip,
              ],
            ),
          ),
          if (tag != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: kFixtureNotchDepth,
              child: Center(child: tag),
            ),
        ],
      ),
    );
  }
}

/// A full-width bottom strip whose chamfered corners match the card. [focal]
/// switches to the brighter blue fill + cyan top hairline used for CTAs.
class FixtureCardStrip extends StatelessWidget {
  const FixtureCardStrip({
    required this.child,
    this.focal = false,
    this.topBorder,
    super.key,
  });

  final Widget child;
  final bool focal;
  final Color? topBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: focal ? kFixtureStripBlue : kFixtureStripDark,
        border: Border(
          top: BorderSide(
            color:
                topBorder ??
                (focal
                    ? Cyber.cyan.withValues(alpha: 0.28)
                    : Colors.white.withValues(alpha: 0.06)),
          ),
        ),
      ),
      child: child,
    );
  }
}

/// Square-top (with optional centre notch), chamfered-bottom silhouette.
class FixtureCardShape extends ShapeBorder {
  const FixtureCardShape({
    this.cut = 12,
    this.notchWidth = 0,
    this.notchDepth = 0,
    this.notchSlope = 0,
    this.side = BorderSide.none,
  });

  final double cut;
  final double notchWidth;
  final double notchDepth;
  final double notchSlope;
  final BorderSide side;

  Path _build(Rect r) =>
      fixtureCardPath(r, cut, notchWidth, notchDepth, notchSlope);

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _build(rect.deflate(side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _build(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    canvas.drawPath(
      _build(rect.deflate(side.width / 2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = side.width
        ..color = side.color,
    );
  }

  @override
  ShapeBorder scale(double t) => FixtureCardShape(
    cut: cut * t,
    notchWidth: notchWidth * t,
    notchDepth: notchDepth * t,
    notchSlope: notchSlope * t,
    side: side.scale(t),
  );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) => this;

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) => this;
}

/// The card silhouette path: square top with a centred trapezoidal notch and
/// chamfered bottom corners. Shared by [FixtureCardShape] and the shadow.
Path fixtureCardPath(
  Rect r,
  double cut,
  double notchWidth,
  double notchDepth,
  double notchSlope,
) {
  final path = Path()..moveTo(r.left, r.top);
  if (notchWidth > 0 && notchDepth > 0) {
    final cx = r.center.dx;
    final half = notchWidth / 2;
    path
      ..lineTo(cx - half - notchSlope, r.top)
      ..lineTo(cx - half, r.top + notchDepth)
      ..lineTo(cx + half, r.top + notchDepth)
      ..lineTo(cx + half + notchSlope, r.top);
  }
  return path
    ..lineTo(r.right, r.top)
    ..lineTo(r.right, r.bottom - cut)
    ..lineTo(r.right - cut, r.bottom)
    ..lineTo(r.left + cut, r.bottom)
    ..lineTo(r.left, r.bottom - cut)
    ..close();
}

/// A hard (un-blurred) drop shadow: the silhouette filled solid and shifted
/// straight down for an embossed feel.
class FixtureCardShadowPainter extends CustomPainter {
  const FixtureCardShadowPainter({required this.notched});

  final bool notched;

  @override
  void paint(Canvas canvas, Size size) {
    final path = fixtureCardPath(
      Offset.zero & size,
      12,
      notched ? kFixtureNotchFloor : 0,
      notched ? kFixtureNotchDepth : 0,
      notched ? kFixtureNotchSlope : 0,
    ).shift(const Offset(0, 6));
    canvas.drawPath(path, Paint()..color = kFixtureShadow);
  }

  @override
  bool shouldRepaint(covariant FixtureCardShadowPainter old) =>
      old.notched != notched;
}
