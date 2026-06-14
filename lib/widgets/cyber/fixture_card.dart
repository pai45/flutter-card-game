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
const kFixtureStripGold = Color(0xff3c2e08);
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
    this.bodyPadding,
    this.onTap,
    super.key,
  });

  final Widget body;
  final Widget? tag;
  final Widget? bodyFooter;
  final Widget? bottomStrip;
  final EdgeInsetsGeometry? bodyPadding;
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
                    padding:
                        bodyPadding ??
                        EdgeInsets.fromLTRB(14, _notched ? 28 : 14, 14, 12),
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
/// switches to the brighter blue fill + cyan top hairline used for CTAs, while
/// [fill] overrides the background outright (e.g. the dark-gold reveal strip).
class FixtureCardStrip extends StatelessWidget {
  const FixtureCardStrip({
    required this.child,
    this.focal = false,
    this.fill,
    this.topBorder,
    super.key,
  });

  final Widget child;
  final bool focal;
  final Color? fill;
  final Color? topBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: fill ?? (focal ? kFixtureStripBlue : kFixtureStripDark),
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

/// Notch tag text: constrained to the notch floor (96px) and scaled down to
/// fit so labels like `UNRESOLVED` / `CLOSES 23H` never overflow the trapezoid.
class FixtureTagText extends StatelessWidget {
  const FixtureTagText({
    required this.text,
    required this.color,
    this.fontSize = 12,
    super.key,
  });

  final String text;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 92),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          style: Cyber.body(fontSize, color: color, weight: FontWeight.w700)
              .copyWith(
                letterSpacing: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        ),
      ),
    );
  }
}

/// A self-animating pulsing LIVE tag for the notch: a glowing red dot plus a
/// red label. Visuals mirror the pick market card's live status tag.
class FixtureLiveTag extends StatefulWidget {
  const FixtureLiveTag({required this.label, super.key});

  final String label;

  @override
  State<FixtureLiveTag> createState() => _FixtureLiveTagState();
}

class _FixtureLiveTagState extends State<FixtureLiveTag>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) => Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Cyber.danger,
              boxShadow: Cyber.glow(
                Cyber.danger,
                alpha: 0.45 + 0.4 * _pulse.value,
                blur: 7,
                spread: 0,
              ),
            ),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          widget.label,
          style: Cyber.body(12.5, color: Cyber.danger, weight: FontWeight.w800)
              .copyWith(
                letterSpacing: 0.8,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        ),
      ],
    );
  }
}

/// Paints the octagon-cut team-badge silhouette: a hard darker base shifted
/// down (the "logo" drop) under the solid color face, plus a subtle edge.
/// Hoisted verbatim from the pick market card so any fixture-family widget can
/// render the held-outcome badge.
class FixtureBadgePainter extends CustomPainter {
  const FixtureBadgePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final bodyHeight = size.height - 5;
    final cut = size.shortestSide * 0.16;
    final rect = Rect.fromLTWH(0, 0, size.width, bodyHeight);
    final body = _octagon(rect, cut);

    canvas.drawPath(
      body.shift(const Offset(0, 5)),
      Paint()..color = Color.lerp(color, Colors.black, 0.58)!,
    );
    canvas.drawPath(body, Paint()..color = color);
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.16),
    );
  }

  Path _octagon(Rect r, double cut) => Path()
    ..moveTo(r.left + cut, r.top)
    ..lineTo(r.right - cut, r.top)
    ..lineTo(r.right, r.top + cut)
    ..lineTo(r.right, r.bottom - cut)
    ..lineTo(r.right - cut, r.bottom)
    ..lineTo(r.left + cut, r.bottom)
    ..lineTo(r.left, r.bottom - cut)
    ..lineTo(r.left, r.top + cut)
    ..close();

  @override
  bool shouldRepaint(covariant FixtureBadgePainter old) => old.color != color;
}
