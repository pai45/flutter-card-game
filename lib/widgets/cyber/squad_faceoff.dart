import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/cards.dart';
import '../../utils/label_helpers.dart';
import 'cyber_widgets.dart';

/// A two-squad face-off: one side's five cards above a glowing VS, the other
/// below, with a staggered fade-and-rise reveal driven by [reveal]. Extracted
/// from the penalty-shootout lineup so other modes (Football Chess kickoff) can
/// reuse the same compact card DNA + VS medallion.
class SquadFaceoff extends StatelessWidget {
  const SquadFaceoff({
    required this.reveal,
    required this.topLabel,
    required this.topSquad,
    required this.topAccent,
    required this.bottomLabel,
    required this.bottomSquad,
    required this.bottomAccent,
    this.showTopPips = false,
    super.key,
  });

  /// 0→1 controller; the top squad slides in first, the VS stamps, then the
  /// bottom squad answers.
  final Animation<double> reveal;
  final String topLabel;
  final List<PlayerCard> topSquad;
  final Color topAccent;
  final String bottomLabel;
  final List<PlayerCard> bottomSquad;
  final Color bottomAccent;

  /// Kick-order pips under the top row (used by the shootout).
  final bool showTopPips;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),
        _FaceoffRow(
          label: topLabel,
          accent: topAccent,
          shooters: topSquad,
          reveal: reveal,
          startBase: 0,
          labelOnTop: true,
          showPips: showTopPips,
        ),
        const SizedBox(height: 16),
        _VsDivider(reveal: reveal),
        const SizedBox(height: 16),
        _FaceoffRow(
          label: bottomLabel,
          accent: bottomAccent,
          shooters: bottomSquad,
          reveal: reveal,
          startBase: 0.52,
          labelOnTop: false,
          showPips: false,
        ),
      ],
    );
  }
}

/// One squad's row: a header (label + avg rating), the cards facing the VS, and
/// optional kick-order pips.
class _FaceoffRow extends StatelessWidget {
  const _FaceoffRow({
    required this.label,
    required this.accent,
    required this.shooters,
    required this.reveal,
    required this.startBase,
    required this.labelOnTop,
    required this.showPips,
  });

  final String label;
  final Color accent;
  final List<PlayerCard> shooters;
  final Animation<double> reveal;
  final double startBase;
  final bool labelOnTop;
  final bool showPips;

  double _avgRating() {
    if (shooters.isEmpty) return 0;
    final total = shooters.fold<int>(0, (sum, c) => sum + c.rating);
    return total / shooters.length;
  }

  @override
  Widget build(BuildContext context) {
    final header = Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Cyber.label(11, color: accent, letterSpacing: 2),
          ),
        ),
        const SizedBox(width: 12),
        Text('AVG', style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.4)),
        const SizedBox(width: 5),
        Text(
          '${_avgRating().round()}',
          style: Cyber.display(
            14,
            color: accent,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ],
    );

    final cards = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < shooters.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _Reveal(
              listenable: reveal,
              start: _cardStart(i),
              end: _cardEnd(i),
              child: FaceoffCard(card: shooters[i], accent: accent),
            ),
          ),
        ],
      ],
    );

    final pips = Row(
      children: [
        for (var i = 0; i < shooters.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Center(
              child: Text(
                '${i + 1}',
                style: Cyber.label(
                  10,
                  color: i == shooters.length - 1 ? Cyber.gold : Cyber.muted,
                  letterSpacing: 1,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
          ),
        ],
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (labelOnTop) ...[header, const SizedBox(height: 8)],
        cards,
        if (showPips) ...[const SizedBox(height: 6), pips],
        if (!labelOnTop) ...[const SizedBox(height: 8), header],
      ],
    );
  }

  double _cardStart(int i) => (startBase + i * 0.05).clamp(0.0, 0.85);
  double _cardEnd(int i) => (_cardStart(i) + 0.30).clamp(0.0, 1.0);
}

/// Compact face-off card — portrait, tier foil, corner-cut chamfer, rating chip,
/// gold keeper tag — sized to fit five-across. Public so board-style modes
/// (Duel Board arena slots) can reuse the same compact card DNA.
class FaceoffCard extends StatelessWidget {
  const FaceoffCard({required this.card, required this.accent, super.key});

  final PlayerCard card;
  final Color accent;

  static const _clipper = HudChamferClipper(bigCut: 9, smallCut: 4.5);

  @override
  Widget build(BuildContext context) {
    final tier = tierColor(card.tier);
    final isKeeper = card.isGoalkeeper;
    final chipColor = isKeeper ? Cyber.gold : accent;

    return AspectRatio(
      aspectRatio: 0.64,
      child: Stack(
        children: [
          ClipPath(
            clipper: _clipper,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      tier.withValues(alpha: 0.16),
                      Cyber.panel,
                    ),
                  ),
                ),
                Positioned(
                  left: 2,
                  right: 2,
                  top: 2,
                  bottom: 17,
                  child: card.hasPortrait
                      ? Image.asset(
                          card.resolvedPortraitAsset!,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          errorBuilder: (_, _, _) => _fallback(tier),
                        )
                      : _fallback(tier),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    color: Colors.black.withValues(alpha: 0.62),
                    child: Text(
                      '${card.rating}',
                      style: Cyber.display(
                        12,
                        color: chipColor,
                        letterSpacing: 0.2,
                      ).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                if (isKeeper)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      color: Cyber.gold.withValues(alpha: 0.85),
                      child: Text(
                        'GK',
                        style:
                            Cyber.label(8, color: Cyber.bg, letterSpacing: 1),
                      ),
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 17,
                    alignment: Alignment.center,
                    color: Colors.black.withValues(alpha: 0.66),
                    child: Text(
                      card.shortName.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.label(
                        8.5,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter:
                    _FaceoffCardBorder(color: tier.withValues(alpha: 0.55)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback(Color tier) => DecoratedBox(
    decoration: BoxDecoration(
      color: Color.alphaBlend(tier.withValues(alpha: 0.16), Cyber.panel),
    ),
    child: Center(
      child: Icon(card.icon, color: tier.withValues(alpha: 0.85), size: 24),
    ),
  );
}

class _FaceoffCardBorder extends CustomPainter {
  const _FaceoffCardBorder({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = FaceoffCard._clipper.buildPath(size);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _FaceoffCardBorder old) => old.color != color;
}

/// The focal VS: a gold medallion that stamps in over a fading rule — the one
/// element on the face-off that glows.
class _VsDivider extends StatelessWidget {
  const _VsDivider({required this.reveal});

  final Animation<double> reveal;

  @override
  Widget build(BuildContext context) {
    final pop = CurvedAnimation(
      parent: reveal,
      curve: const Interval(0.40, 0.68, curve: Curves.easeOutBack),
    );
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Cyber.gold.withValues(alpha: 0.5)],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ScaleTransition(
            scale: pop,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
              decoration: BoxDecoration(
                color: Cyber.bg,
                border: Border.all(color: Cyber.gold, width: 1.5),
                boxShadow: Cyber.glow(Cyber.gold),
              ),
              child: Text('VS', style: Cyber.display(20, color: Cyber.gold)),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Cyber.gold.withValues(alpha: 0.5), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Fade + rise reveal gated to an [Interval] of the shared face-off controller.
class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.listenable,
    required this.start,
    required this.end,
    required this.child,
  });

  final Animation<double> listenable;
  final double start;
  final double end;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final anim = CurvedAnimation(
      parent: listenable,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (_, child) => Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - anim.value) * 16),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
