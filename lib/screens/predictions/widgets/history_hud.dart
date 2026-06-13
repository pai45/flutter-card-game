import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// Shared chrome for the two history screens (My Matches / My Picks): the back
/// header, the matte HUD telemetry stat cells, and the cut-corner filter chips.
/// Everything here is matte — the glowing focal element lives on the cards.

/// Back button + accent title, merged from the two identical `_HistoryHeader`s.
class HistoryHeaderBar extends StatelessWidget {
  const HistoryHeaderBar({
    required this.title,
    required this.accent,
    required this.onBack,
    super.key,
  });

  final String title;
  final Color accent;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.display(19, color: accent, letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }
}

/// Symmetric four-corner cut-corner outline (copy of the leaderboard chip
/// border), used by the stat cells and filter chips here.
class CutChipBorder extends ShapeBorder {
  const CutChipBorder({required this.cut, this.side = BorderSide.none});

  final double cut;
  final BorderSide side;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  ShapeBorder scale(double t) =>
      CutChipBorder(cut: cut * t, side: side.scale(t));

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(side.width), textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final c = cut.clamp(0, rect.shortestSide / 2).toDouble();
    return Path()
      ..moveTo(rect.left + c, rect.top)
      ..lineTo(rect.right - c, rect.top)
      ..lineTo(rect.right, rect.top + c)
      ..lineTo(rect.right, rect.bottom - c)
      ..lineTo(rect.right - c, rect.bottom)
      ..lineTo(rect.left + c, rect.bottom)
      ..lineTo(rect.left, rect.bottom - c)
      ..lineTo(rect.left, rect.top + c)
      ..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    canvas.drawPath(
      getOuterPath(rect.deflate(side.width / 2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = side.width
        ..color = side.color,
    );
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) => this;

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) => this;
}

/// A matte HUD telemetry cell: cut-corner panel, left-aligned UPPERCASE label
/// over a large tabular value. No glow, no colored fills.
class HistoryStatCell extends StatelessWidget {
  const HistoryStatCell({
    required this.label,
    required this.value,
    required this.accent,
    this.valueColor,
    super.key,
  });

  final String label;
  final String value;
  final Color accent;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: ShapeDecoration(
        color: const Color(0xff111b30),
        shape: CutChipBorder(
          cut: 10,
          side: BorderSide(color: Cyber.line.withValues(alpha: 0.3)),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Cyber.label(
              8,
              color: accent.withValues(alpha: 0.9),
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Cyber.display(20, color: valueColor ?? Colors.white)
                  .copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A cut-corner filter chip with a trailing count. Matte: tinted fill + accent
/// border when active, otherwise transparent over a faint hairline.
class HistoryFilterChip extends StatelessWidget {
  const HistoryFilterChip({
    required this.label,
    required this.count,
    required this.active,
    required this.accent,
    required this.onTap,
    super.key,
  });

  final String label;
  final int count;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: ShapeDecoration(
          color: active ? accent.withValues(alpha: 0.14) : Colors.transparent,
          shape: CutChipBorder(
            cut: 8,
            side: BorderSide(
              color: active
                  ? accent.withValues(alpha: 0.72)
                  : Cyber.line.withValues(alpha: 0.28),
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: active ? accent : Cyber.muted,
                fontFamily: Cyber.displayFont,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: Cyber.label(
                9,
                color: (active ? accent : Cyber.muted).withValues(alpha: 0.7),
                letterSpacing: 0.4,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
