import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/shootout/shootout_bloc.dart';
import '../../../blocs/shootout/shootout_event.dart';
import '../../../blocs/shootout/shootout_state.dart';
import '../../../config/theme.dart';
import '../../../models/cards.dart';
import '../../../utils/label_helpers.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/match_widgets.dart';

/// Pre-shootout face-off: both five-man squads square up across a glowing VS.
class ShootoutLineupPhase extends StatefulWidget {
  const ShootoutLineupPhase({
    required this.state,
    required this.onQuit,
    super.key,
  });

  final ShootoutState state;
  final VoidCallback onQuit;

  @override
  State<ShootoutLineupPhase> createState() => _ShootoutLineupPhaseState();
}

class _ShootoutLineupPhaseState extends State<ShootoutLineupPhase>
    with SingleTickerProviderStateMixin {
  // Drives the staggered face-off reveal: your squad slides in, the VS stamps,
  // then the CPU squad answers — all off this single controller.
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );

  @override
  void initState() {
    super.initState();
    // Tension cue under the face-off reveal.
    playSound(SoundEffect.riser);
    _reveal.forward();
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MatchPhaseScaffold(
      title: 'PENALTY SHOOTOUT',
      subtitle: '// Face-Off',
      onQuit: widget.onQuit,
      // No score yet — it begins on the kick screen. Clean HUD backdrop here.
      showStadium: false,
      // Centre the face-off in the page rather than top-aligning it.
      centerContent: true,
      bottomAction: CyberCtaButton(
        label: 'BEGIN SHOOTOUT',
        primary: true,
        onPressed: () => context.read<ShootoutBloc>().add(ShootoutStarted()),
      ),
      children: [
        _FaceoffStage(state: widget.state, reveal: _reveal),
      ],
    );
  }
}

/// Composes the two squads and the focal VS into one face-off column.
class _FaceoffStage extends StatelessWidget {
  const _FaceoffStage({required this.state, required this.reveal});

  final ShootoutState state;
  final Animation<double> reveal;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),
        _FaceoffRow(
          label: 'YOUR SQUAD',
          accent: Cyber.cyan,
          shooters: state.playerShooters,
          reveal: reveal,
          startBase: 0,
          labelOnTop: true,
          showPips: true,
        ),
        const SizedBox(height: 16),
        _VsDivider(reveal: reveal),
        const SizedBox(height: 16),
        _FaceoffRow(
          label: 'CPU SQUAD',
          accent: Cyber.amber,
          shooters: state.cpuShooters,
          reveal: reveal,
          startBase: 0.52,
          labelOnTop: false,
          showPips: false,
        ),
      ],
    );
  }
}

/// One squad's row: a header (label + avg rating), five cards facing the VS,
/// and — for the player side — the kick-order pips.
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
        Text(label, style: Cyber.label(11, color: accent, letterSpacing: 2)),
        const Spacer(),
        Text('AVG', style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.4)),
        const SizedBox(width: 5),
        Text(
          '${_avgRating().round()}',
          style: Cyber.display(14, color: accent).copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
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
              child: _FaceoffCard(card: shooters[i], accent: accent),
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
                style:
                    Cyber.label(
                      10,
                      color: i == shooters.length - 1 ? Cyber.gold : Cyber.muted,
                      letterSpacing: 1,
                    ).copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
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

/// Compact face-off card — reuses the card DNA (portrait, tier fill, corner-cut
/// chamfer, rating chip, gold keeper) but sizes itself to fit five-across.
class _FaceoffCard extends StatelessWidget {
  const _FaceoffCard({required this.card, required this.accent});

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
                // Tier-graded foil fill (no glow — always-on secondary element).
                DecoratedBox(
                  decoration: BoxDecoration(gradient: Cyber.panelGradient(tier)),
                ),
                // Portrait — leaves a strip for the nameplate.
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
                // Rating chip.
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    color: Colors.black.withValues(alpha: 0.62),
                    child: Text(
                      '${card.rating}',
                      style: Cyber.display(12, color: chipColor, letterSpacing: 0.2)
                          .copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                  ),
                ),
                // GK tag for the keeper (kick #5).
                if (isKeeper)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      color: Cyber.gold.withValues(alpha: 0.85),
                      child: Text(
                        'GK',
                        style: Cyber.label(8, color: Cyber.bg, letterSpacing: 1),
                      ),
                    ),
                  ),
                // Nameplate.
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
          // Chamfered tier edge traced over the clip so the border follows the
          // corner-cut instead of a plain rectangle.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _FaceoffCardBorder(
                  color: tier.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback(Color tier) => DecoratedBox(
    decoration: BoxDecoration(gradient: Cyber.panelGradient(tier)),
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
    final path = _FaceoffCard._clipper.buildPath(size);
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

/// The focal VS: a gold medallion that stamps in over a fading rule. This is the
/// one element on the screen that glows (face-off "moment").
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
