import 'dart:math';

import 'package:flutter/material.dart';

import '../../../config/enums.dart';
import '../../../config/theme.dart';
import '../../../utils/label_helpers.dart';


/// Reserved height for the verdict hero zone (icon row + 2-line narration).
const _kVerdictH = 120.0;

class HeadToHeadPowerMeter extends StatelessWidget {
  const HeadToHeadPowerMeter({
    required this.playerRole,
    required this.oppRole,
    required this.playerPower,
    required this.oppPower,
    required this.playerAccent,
    required this.oppAccent,
    required this.progress,
    super.key,
  });

  final String playerRole;
  final String oppRole;
  final double playerPower;
  final double oppPower;
  final Color playerAccent;
  final Color oppAccent;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final total = playerPower + oppPower;
    final playerRatio = total > 0 ? playerPower / total : 0.5;
    final oppRatio = total > 0 ? oppPower / total : 0.5;
    final winnerIsPlayer = playerPower >= oppPower;
    final winnerRole = winnerIsPlayer ? playerRole : oppRole;
    final winnerAccent = winnerIsPlayer ? playerAccent : oppAccent;
    final margin =
        (winnerIsPlayer ? playerPower - oppPower : oppPower - playerPower)
            .round();
    final marginShown = (margin * progress).round();
    final displayPlayer = (playerPower * progress).round();
    final displayOpp = (oppPower * progress).round();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _PowerLabel(
              role: playerRole,
              value: displayPlayer,
              accent: playerAccent,
            ),
            _PowerLabel(
              role: oppRole,
              value: displayOpp,
              accent: oppAccent,
              alignEnd: true,
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final playerW = (w * playerRatio * progress).clamp(0.0, w);
            final oppW = (w * oppRatio * progress).clamp(0.0, w);

            return SizedBox(
              height: 16,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Cyber.bg2,
                      border: Border.all(color: Cyber.borderSubtle),
                    ),
                    child: const SizedBox(width: double.infinity, height: 16),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: playerW,
                      height: 16,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            playerAccent.withValues(alpha: 0.55),
                            playerAccent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: oppW,
                      height: 16,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            oppAccent,
                            oppAccent.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 16,
                    color: Cyber.line.withValues(alpha: 0.8),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 18,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Transform.scale(
                scale: 0.82 + 0.18 * progress,
                child: Text(
                  margin == 0
                      ? 'DEAD EVEN'
                      : '» $winnerRole EDGE +$marginShown «',
                  maxLines: 1,
                  style:
                      Cyber.label(
                        12,
                        color: margin == 0 ? Cyber.muted : winnerAccent,
                        letterSpacing: 1.8,
                      ).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PowerLabel extends StatelessWidget {
  const _PowerLabel({
    required this.role,
    required this.value,
    required this.accent,
    this.alignEnd = false,
  });

  final String role;
  final int value;
  final Color accent;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          role,
          style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.2),
        ),
        const SizedBox(height: 2),
        Text(
          '$value',
          style: Cyber.display(
            20,
            color: accent,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ],
    );
  }
}

/// Distinct per-outcome celebration treatment for the verdict hero.
enum _Celebration { goalBurst, denied, wall, deflate, caution, alarm }

_Celebration _celebrationFor(RoundOutcome o) => switch (o) {
  RoundOutcome.goal => _Celebration.goalBurst,
  RoundOutcome.saved => _Celebration.denied,
  RoundOutcome.blocked => _Celebration.wall,
  RoundOutcome.missed => _Celebration.deflate,
  RoundOutcome.foul => _Celebration.caution,
  RoundOutcome.redCard => _Celebration.alarm,
};

/// The single focal "moment" element: a chamfered HUD plate that lands with the
/// outcome icon, label and a short narration. The only glow on the screen
/// (except the goal score-pop). Treatment varies per outcome.
class VerdictHero extends StatelessWidget {
  const VerdictHero({
    required this.outcome,
    required this.playerAttacking,
    required this.accent,
    required this.t,
    super.key,
  });

  final RoundOutcome outcome;
  final bool playerAttacking;
  final Color accent;
  final double t;

  @override
  Widget build(BuildContext context) {
    final celebration = _celebrationFor(outcome);
    final deflate = celebration == _Celebration.deflate;
    final opacity = t.clamp(0.0, 1.0);
    final dy = deflate
        ? 10 *
              (1 - opacity) // gentle settle, no lift
        : -42 * (1 - opacity); // drops in from above (back-eased overshoot)
    final glow = !deflate && t > 0.35;

    return SizedBox(
      height: _kVerdictH,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (celebration == _Celebration.goalBurst && t > 0)
            Positioned.fill(
              child: CustomPaint(painter: _BurstPainter(t, accent)),
            ),
          Positioned.fill(
            child: Opacity(
              opacity: opacity,
              child: CustomPaint(
                painter: _CornerBracketsPainter(
                  accent.withValues(alpha: deflate ? 0.3 : 0.55),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(0, dy),
            child: Opacity(
              opacity: opacity,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    accent.withValues(alpha: deflate ? 0.08 : 0.16),
                    Cyber.panel,
                  ),
                  border: Border.all(
                    color: accent.withValues(alpha: deflate ? 0.5 : 0.9),
                    width: deflate ? 1.2 : 1.6,
                  ),
                  boxShadow: glow
                      ? Cyber.glow(accent, alpha: 0.45, blur: 22)
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(outcomeIcon(outcome), color: accent, size: 30),
                          const SizedBox(width: 12),
                          Text(
                            outcomeLabel(outcome).toUpperCase(),
                            style: Cyber.display(
                              34,
                              color: accent,
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      outcomeNarration(
                        outcome,
                        playerAttacking: playerAttacking,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.body(13, color: Cyber.muted, height: 1.25),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact scoreline that reveals after the verdict and ticks the scoring side
/// up by one on a goal (with a scale-pop + glow), or reads "HELD" otherwise.
class ScoreImpactStrip extends StatelessWidget {
  const ScoreImpactStrip({
    required this.playerScore,
    required this.opponentScore,
    required this.opponentLabel,
    required this.goalScored,
    required this.scoringIsPlayer,
    required this.t,
    super.key,
  });

  final int playerScore;
  final int opponentScore;
  final String opponentLabel;
  final bool goalScored;
  final bool scoringIsPlayer;
  final double t;

  @override
  Widget build(BuildContext context) {
    final opacity = t.clamp(0.0, 1.0);
    final popped = t >= 0.45;
    final shownPlayer = goalScored && scoringIsPlayer && !popped
        ? playerScore - 1
        : playerScore;
    final shownOpp = goalScored && !scoringIsPlayer && !popped
        ? opponentScore - 1
        : opponentScore;
    final popT = ((t - 0.45) / 0.22).clamp(0.0, 1.0);
    final popScale = 1 + 0.45 * sin(popT * pi);
    final tagColor = goalScored ? Cyber.success : Cyber.muted;

    // Full-width banner spanning the content column, square edges (no chamfer).
    return Opacity(
      opacity: opacity,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Cyber.panel,
          border: const Border(
            top: BorderSide(color: Cyber.borderSubtle),
            bottom: BorderSide(color: Cyber.borderSubtle),
          ),
        ),
        child: Row(
          children: [
            Text(
              'SCORE',
              style: Cyber.label(11, color: Cyber.muted, letterSpacing: 1.6),
            ),
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ScoreCell(
                        label: 'YOU',
                        value: shownPlayer,
                        color: Cyber.cyan,
                        pop: goalScored && scoringIsPlayer ? popScale : 1,
                        glow: goalScored && scoringIsPlayer && popped,
                      ),
                      const SizedBox(width: 12),
                      Text('—', style: Cyber.display(18, color: Cyber.line)),
                      const SizedBox(width: 12),
                      _ScoreCell(
                        label: opponentLabel,
                        value: shownOpp,
                        color: Cyber.danger,
                        pop: goalScored && !scoringIsPlayer ? popScale : 1,
                        glow: goalScored && !scoringIsPlayer && popped,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tagColor.withValues(alpha: 0.12),
                border: Border.all(color: tagColor.withValues(alpha: 0.5)),
              ),
              child: Text(
                goalScored ? '+1 GOAL' : 'HELD',
                style: Cyber.label(10, color: tagColor, letterSpacing: 1.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreCell extends StatelessWidget {
  const _ScoreCell({
    required this.label,
    required this.value,
    required this.color,
    required this.pop,
    required this.glow,
  });

  final String label;
  final int value;
  final Color color;
  final double pop;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.2),
        ),
        const SizedBox(height: 2),
        Transform.scale(
          scale: pop,
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: glow ? Cyber.glow(color, alpha: 0.5) : null,
            ),
            child: Text(
              '$value',
              style: Cyber.display(
                22,
                color: color,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
        ),
      ],
    );
  }
}

/// HUD corner ticks framing the verdict zone, tinted by the outcome accent.
class _CornerBracketsPainter extends CustomPainter {
  const _CornerBracketsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const len = 18.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final w = size.width;
    final h = size.height;
    // top-left
    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, len), paint);
    // top-right
    canvas.drawLine(Offset(w, 0), Offset(w - len, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, len), paint);
    // bottom-left
    canvas.drawLine(Offset(0, h), Offset(len, h), paint);
    canvas.drawLine(Offset(0, h), Offset(0, h - len), paint);
    // bottom-right
    canvas.drawLine(Offset(w, h), Offset(w - len, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w, h - len), paint);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketsPainter old) =>
      old.color != color;
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..color = color.withValues(alpha: (1 - t).clamp(0, 1));
    final rng = Random(7);
    for (var i = 0; i < 14; i++) {
      final angle = (i / 14) * 2 * pi + rng.nextDouble();
      final dist = 90 * t * (0.6 + rng.nextDouble() * 0.6);
      final p = center + Offset(cos(angle), sin(angle)) * dist;
      final s = 5 * (1 - t) + 2;
      canvas.drawRect(Rect.fromCenter(center: p, width: s, height: s), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) =>
      old.t != t || old.color != color;
}

enum StingerKind { goal, denied }

/// Full-bleed payoff fired the instant the verdict lands: a stadium-wide
/// accent flash, a particle burst (goals only) and a chromatic "GOAL!" /
/// "DENIED!" stamp that slams in oversized and settles. Visual-only overlay —
/// it never affects layout or input, and stays empty unless its animation
/// is actually running (so reduced-motion and test timelines skip it).
class OutcomeStingerOverlay extends StatelessWidget {
  const OutcomeStingerOverlay({
    required this.kind,
    required this.accent,
    required this.animation,
    super.key,
  });

  final StingerKind? kind;
  final Color accent;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final k = kind;
    if (k == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value;
          if (t <= 0 || t >= 1) return const SizedBox.shrink();

          // Flash ramps up fast then decays; stamp slams in, holds, fades out.
          final flashIn = Curves.easeOut.transform((t / 0.16).clamp(0.0, 1.0));
          final flashOut =
              1 - Curves.easeIn.transform(((t - 0.16) / 0.6).clamp(0.0, 1.0));
          final flash = 0.4 * flashIn * flashOut;
          final slamT = Curves.easeOutCubic.transform(
            (t / 0.32).clamp(0.0, 1.0),
          );
          final fadeOut =
              1 - Curves.easeIn.transform(((t - 0.72) / 0.28).clamp(0.0, 1.0));
          final scale = 2.3 - 1.3 * slamT;
          // Chromatic aberration settles as the stamp lands.
          final aberration = 6.0 * (1 - slamT);

          final label = k == StingerKind.goal ? 'GOAL!' : 'DENIED!';
          final style = Cyber.display(54, color: accent, letterSpacing: 4)
              .copyWith(
                shadows: [
                  Shadow(color: accent.withValues(alpha: 0.8), blurRadius: 26),
                ],
              );
          final ghost = style.copyWith(shadows: const []);

          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        accent.withValues(alpha: flash),
                        accent.withValues(alpha: flash * 0.35),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
              if (k == StingerKind.goal)
                Positioned.fill(
                  child: CustomPaint(painter: _BurstPainter(t, accent)),
                ),
              Opacity(
                opacity: (slamT * fadeOut).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Stack(
                      children: [
                        Transform.translate(
                          offset: Offset(-aberration, 0),
                          child: Text(
                            label,
                            style: ghost.copyWith(
                              color: Cyber.cyan.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(aberration, 0),
                          child: Text(
                            label,
                            style: ghost.copyWith(
                              color: Cyber.magenta.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                        Text(label, style: style),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
