import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/basketball/basketball_cubit.dart';
import '../../../blocs/basketball/basketball_state.dart';
import '../../../config/theme.dart';
import '../../../games/basketball/basketball_engine.dart';
import '../../../games/basketball/basketball_game.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// Top HUD bar: exit · MY score — half clock / shot clock — CPU score, with
/// heat meters under each score. Clocks/meters ride the game's
/// [ValueNotifier]s (never bloc state @60fps); the half label is the one
/// coarse read from the cubit.
class BasketballHudBar extends StatelessWidget {
  const BasketballHudBar({
    required this.game,
    required this.onExit,
    super.key,
  });

  final BasketballGame game;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Cyber.bg.withValues(alpha: 0.94),
            Cyber.bg.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: onExit,
            icon: const Icon(Icons.close, color: Cyber.muted, size: 20),
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ScoreBlock(
                  label: 'YOU',
                  accent: Cyber.cyan,
                  score: game.scorePlayer,
                  heat: game.heatPlayer,
                  heatActive: game.heatActivePlayer,
                  possession: game.possession,
                  team: 0,
                ),
                const SizedBox(width: 14),
                _ClockCluster(game: game),
                const SizedBox(width: 14),
                _ScoreBlock(
                  label: 'CPU',
                  accent: Cyber.magenta,
                  score: game.scoreCpu,
                  heat: game.heatCpu,
                  heatActive: game.heatActiveCpu,
                  possession: game.possession,
                  team: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }
}

class _ScoreBlock extends StatelessWidget {
  const _ScoreBlock({
    required this.label,
    required this.accent,
    required this.score,
    required this.heat,
    required this.heatActive,
    required this.possession,
    required this.team,
  });

  final String label;
  final Color accent;
  final ValueListenable<int> score;
  final ValueListenable<double> heat;
  final ValueListenable<bool> heatActive;
  final ValueListenable<int> possession;
  final int team;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<int>(
              valueListenable: possession,
              builder: (context, holder, _) => AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: holder == team ? 1 : 0,
                child: Icon(
                  Icons.sports_basketball,
                  size: 10,
                  color: Cyber.amber,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1.6),
            ),
          ],
        ),
        const SizedBox(height: 2),
        ValueListenableBuilder<int>(
          valueListenable: score,
          builder: (context, value, _) => Text(
            '$value',
            style: Cyber.display(26, color: accent).copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: 52,
          child: ValueListenableBuilder<bool>(
            valueListenable: heatActive,
            builder: (context, active, _) => ValueListenableBuilder<double>(
              valueListenable: heat,
              builder: (context, value, _) => CyberProgressBar(
                value: active ? 1 : value,
                accent: active ? Cyber.gold : accent,
                height: 4,
                radius: 2,
                animate: false,
                trackColor: accent.withValues(alpha: 0.14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ClockCluster extends StatelessWidget {
  const _ClockCluster({required this.game});

  final BasketballGame game;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BlocBuilder<BasketballCubit, BasketballState>(
          buildWhen: (p, c) => p.halfIndex != c.halfIndex,
          builder: (context, state) => Text(
            switch (state.halfIndex) {
              0 => '1ST HALF',
              1 => '2ND HALF',
              _ => 'OVERTIME',
            },
            style: Cyber.label(
              8,
              color: state.halfIndex >= 2 ? Cyber.gold : Cyber.muted,
              letterSpacing: 1.8,
            ),
          ),
        ),
        const SizedBox(height: 2),
        BlocBuilder<BasketballCubit, BasketballState>(
          buildWhen: (p, c) => p.halfIndex != c.halfIndex,
          builder: (context, state) => state.halfIndex >= 2
              ? Text(
                  'SUDDEN DEATH',
                  style: Cyber.display(14, color: Cyber.gold, letterSpacing: 1.5),
                )
              : ValueListenableBuilder<int>(
                  valueListenable: game.halfClockTenths,
                  builder: (context, tenths, _) {
                    final seconds = tenths / 10;
                    final danger = seconds <= 10;
                    return Text(
                      seconds >= 10
                          ? '0:${seconds.floor().toString().padLeft(2, '0')}'
                          : seconds.toStringAsFixed(1),
                      style: Cyber.display(
                        20,
                        color: danger ? Cyber.danger : Colors.white,
                      ).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 3),
        ValueListenableBuilder<int>(
          valueListenable: game.shotClockSeconds,
          builder: (context, clock, _) {
            final danger = clock <= 3;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: Cyber.bg.withValues(alpha: 0.6),
                border: Border.all(
                  color: (danger ? Cyber.danger : Cyber.gold).withValues(
                    alpha: 0.55,
                  ),
                ),
              ),
              child: Text(
                'SHOT $clock',
                style: Cyber.label(
                  8.5,
                  color: danger ? Cyber.danger : Cyber.gold,
                  letterSpacing: 1.2,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stamina rail (sits just above the control deck)
// ---------------------------------------------------------------------------

class BasketballStaminaRail extends StatelessWidget {
  const BasketballStaminaRail({required this.game, super.key});

  final BasketballGame game;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            'STAMINA',
            style: Cyber.label(7.5, color: Cyber.muted, letterSpacing: 1.6),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ValueListenableBuilder<double>(
              valueListenable: game.stamina01,
              builder: (context, value, _) => CyberProgressBar(
                value: value,
                accent: value < 0.3 ? Cyber.danger : Cyber.success,
                height: 5,
                radius: 2,
                animate: false,
                trackColor: Cyber.success.withValues(alpha: 0.12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shot meter — anchored above the action pad while a shot is gathering
// ---------------------------------------------------------------------------

class BasketballShotMeter extends StatelessWidget {
  const BasketballShotMeter({required this.game, super.key});

  final BasketballGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ShotMeterView?>(
      valueListenable: game.meter,
      builder: (context, view, _) {
        if (view == null) return const SizedBox.shrink();
        return SizedBox(
          width: 26,
          height: 150,
          child: CustomPaint(painter: _ShotMeterPainter(view)),
        );
      },
    );
  }
}

class _ShotMeterPainter extends CustomPainter {
  _ShotMeterPainter(this.view);

  final ShotMeterView view;

  @override
  void paint(Canvas canvas, Size size) {
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width / 2 - 5, 0, 10, size.height),
      const Radius.circular(2),
    );
    canvas.drawRRect(
      track,
      Paint()..color = Cyber.bg.withValues(alpha: 0.75),
    );
    canvas.drawRRect(
      track,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Cyber.border,
    );

    double y(double frac) => size.height * (1 - frac.clamp(0.0, 1.0));

    // Good window (wider, dimmer) behind the perfect band.
    final goodTop = y(view.perfectCenter + view.perfectHalf + view.goodHalf);
    final goodBottom = y(view.perfectCenter - view.perfectHalf - view.goodHalf);
    canvas.drawRect(
      Rect.fromLTRB(size.width / 2 - 5, goodTop, size.width / 2 + 5, goodBottom),
      Paint()..color = Cyber.cyan.withValues(alpha: 0.22),
    );
    // Perfect band.
    final perfectTop = y(view.perfectCenter + view.perfectHalf);
    final perfectBottom = y(view.perfectCenter - view.perfectHalf);
    canvas.drawRect(
      Rect.fromLTRB(
        size.width / 2 - 5,
        perfectTop,
        size.width / 2 + 5,
        perfectBottom,
      ),
      Paint()..color = Cyber.lime.withValues(alpha: 0.85),
    );

    // Progress needle.
    final needleY = y(view.progress);
    canvas.drawRect(
      Rect.fromLTRB(
        size.width / 2 - 5,
        needleY,
        size.width / 2 + 5,
        size.height,
      ),
      Paint()..color = Cyber.gold.withValues(alpha: 0.45),
    );
    canvas.drawLine(
      Offset(0, needleY),
      Offset(size.width, needleY),
      Paint()
        ..color = Cyber.gold
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_ShotMeterPainter oldDelegate) =>
      oldDelegate.view.progress != view.progress ||
      oldDelegate.view.perfectCenter != view.perfectCenter ||
      oldDelegate.view.perfectHalf != view.perfectHalf;
}

// ---------------------------------------------------------------------------
// Sting banners (PERFECT RELEASE / ANKLE BREAKER / …)
// ---------------------------------------------------------------------------

class BasketballStingLayer extends StatelessWidget {
  const BasketballStingLayer({required this.game, super.key});

  final BasketballGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BasketballSting?>(
      valueListenable: game.sting,
      builder: (context, sting, _) {
        if (sting == null) return const SizedBox.shrink();
        final major = sting.major;
        return Align(
          alignment: Alignment(0, major ? -0.34 : -0.5),
          child: TweenAnimationBuilder<double>(
            key: ValueKey(sting.id),
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: major ? 1600 : 1100),
            builder: (context, t, child) {
              final appear = (t * 5).clamp(0.0, 1.0);
              final fade = t > 0.72 ? (1 - (t - 0.72) / 0.28) : 1.0;
              return Opacity(
                // Clamped: binary-float fade math can dip below 0 at t == 1.
                opacity: (appear * fade).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: major
                      ? 1.6 - 0.6 * Curves.easeOutBack.transform(appear)
                      : 1.0,
                  child: Transform.translate(
                    offset: Offset(0, (1 - appear) * 8),
                    child: child,
                  ),
                ),
              );
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: major ? 18 : 10,
                vertical: major ? 8 : 4,
              ),
              decoration: BoxDecoration(
                color: Cyber.bg.withValues(alpha: 0.82),
                border: Border.all(
                  color: sting.color.withValues(alpha: 0.8),
                  width: major ? 1.6 : 1,
                ),
                boxShadow: major
                    ? Cyber.glow(sting.color, alpha: 0.4)
                    : null,
              ),
              child: Text(
                sting.label,
                style: Cyber.display(
                  major ? 18 : 11,
                  color: sting.color,
                  letterSpacing: major ? 2.4 : 1.4,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
