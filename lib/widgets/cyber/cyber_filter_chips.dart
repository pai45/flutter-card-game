import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../utils/sound_effects.dart';

/// A horizontal, scrollable strip of cut-corner filter chips — the leaderboard
/// sport-filter look, reused on the shop catalogue tabs (nation on AVATAR, sport
/// on BORDER / BANNER). The active chip is the single tinted/outlined element;
/// per the glow rule it doesn't glow — the rest stay calm muted outlines.
class CyberFilterChips extends StatelessWidget {
  const CyberFilterChips({
    required this.labels,
    required this.selected,
    required this.onSelect,
    this.accent = Cyber.cyan,
    this.padding = const EdgeInsets.fromLTRB(16, 10, 12, 10),
    super.key,
  });

  final List<String> labels;
  final String selected;
  final ValueChanged<String> onSelect;
  final Color accent;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (final label in labels)
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: CyberFilterChip(
                label: label,
                active: label == selected,
                accent: accent,
                onTap: () {
                  if (label == selected) return;
                  playSound(SoundEffect.uiTap);
                  onSelect(label);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class CyberFilterChip extends StatelessWidget {
  const CyberFilterChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.accent = Cyber.cyan,
    super.key,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final color = active ? accent : Cyber.muted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: ShapeDecoration(
          color: active ? accent.withValues(alpha: 0.14) : Colors.transparent,
          shape: _CutCornerBorder(
            cut: 8,
            side: BorderSide(
              color: active
                  ? accent.withValues(alpha: 0.72)
                  : Cyber.line.withValues(alpha: 0.28),
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontFamily: Cyber.displayFont,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

/// Diagonal corner-cut (top-left + bottom-right) border — the cyber chip
/// silhouette, matching the leaderboard's filter chips.
class _CutCornerBorder extends ShapeBorder {
  const _CutCornerBorder({required this.cut, this.side = BorderSide.none});

  final double cut;
  final BorderSide side;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  ShapeBorder scale(double t) =>
      _CutCornerBorder(cut: cut * t, side: side.scale(t));

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(side.width), textDirection: textDirection);

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
