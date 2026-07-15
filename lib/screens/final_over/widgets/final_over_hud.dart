import 'package:final_over/final_over.dart';
import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../games/final_over/final_over_game.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// The chase, read at a glance. Every widget in here is a
/// [ValueListenableBuilder] over a notifier the Flame game pushes once a frame
/// — no bloc, no rebuild storm.
class FinalOverHudBar extends StatelessWidget {
  const FinalOverHudBar({required this.game, required this.onExit, super.key});

  final FinalOverGame game;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 14, 16),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                onPressed: onExit,
                icon: const Icon(Icons.close_rounded),
                color: Cyber.muted,
                iconSize: 20,
              ),
              const _ScoreBlock(),
              const Spacer(),
              const _ChaseCluster(),
            ],
          ),
          const SizedBox(height: 8),
          const _BallStrip(),
        ],
      ),
    );
  }
}

class _ScoreBlock extends StatelessWidget {
  const _ScoreBlock();

  @override
  Widget build(BuildContext context) {
    final game = _gameOf(context);
    return AnimatedBuilder(
      animation: Listenable.merge([game.score, game.wickets, game.target]),
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${game.score.value}',
                style: Cyber.display(
                  30,
                  color: Colors.white,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              Text(
                '/${game.wickets.value}',
                style: Cyber.display(
                  17,
                  color: Cyber.muted,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          Text(
            'TARGET ${game.target.value}',
            style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1.4),
          ),
        ],
      ),
    );
  }
}

/// The one number that matters. Goes red when the required rate has passed the
/// point where a boundary an over saves you.
class _ChaseCluster extends StatelessWidget {
  const _ChaseCluster();

  @override
  Widget build(BuildContext context) {
    final game = _gameOf(context);
    return AnimatedBuilder(
      animation: Listenable.merge([
        game.runsNeeded,
        game.ballsLeft,
        game.freeHit,
        game.combo,
      ]),
      builder: (context, _) {
        final need = game.runsNeeded.value;
        final balls = game.ballsLeft.value;
        final desperate = balls > 0 && need > balls * 6;
        final color = desperate ? Cyber.danger : Colors.white;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              need <= 0 ? 'DONE' : 'NEED $need',
              style: Cyber.display(
                20,
                color: color,
                letterSpacing: 1,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            Text(
              'OFF $balls ${balls == 1 ? 'BALL' : 'BALLS'}',
              style: Cyber.label(
                8,
                color: desperate ? Cyber.danger : Cyber.muted,
                letterSpacing: 1.4,
              ),
            ),
            if (game.freeHit.value || game.combo.value > 1) ...[
              const SizedBox(height: 5),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (game.combo.value > 1)
                    CyberChip(
                      label: '×${game.combo.value} COMBO',
                      color: Cyber.magenta,
                    ),
                  if (game.combo.value > 1 && game.freeHit.value)
                    const SizedBox(width: 5),
                  if (game.freeHit.value)
                    const CyberChip(label: 'FREE HIT', color: Cyber.gold),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Six tokens, one per legal ball. The over as a strip — cricket's own HUD,
/// and the fastest way to read a chase.
class _BallStrip extends StatelessWidget {
  const _BallStrip();

  @override
  Widget build(BuildContext context) {
    final game = _gameOf(context);
    return ValueListenableBuilder<List<BallResult>>(
      valueListenable: game.history,
      builder: (context, history, _) {
        final legal = history.where((b) => b.legal).toList();
        return Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            children: [
              for (var i = 0; i < 6; i++) ...[
                _BallToken(
                  result: i < legal.length ? legal[i] : null,
                  next: i == legal.length,
                ),
                if (i < 5) const SizedBox(width: 5),
              ],
              const Spacer(),
              // Extras don't advance the over, but they happened — show them.
              for (final extra in history.where((b) => !b.legal).take(3)) ...[
                _ExtraToken(result: extra),
                const SizedBox(width: 4),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BallToken extends StatelessWidget {
  const _BallToken({required this.result, required this.next});

  final BallResult? result;
  final bool next;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final (label, color) = switch (r) {
      null => ('·', Cyber.border),
      final b when b.isWicket => ('W', Cyber.danger),
      final b when b.boundary == 6 => ('6', Cyber.gold),
      final b when b.boundary == 4 => ('4', Cyber.cyan),
      final b when b.totalRuns == 0 => ('0', Cyber.muted),
      final b => ('${b.totalRuns}', Cyber.success),
    };
    final filled = r != null;

    return ClipPath(
      clipper: const HudChamferClipper(bigCut: 5, smallCut: 2),
      child: Container(
        width: 26,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled
              ? color.withValues(alpha: 0.20)
              : Cyber.panel.withValues(alpha: 0.7),
          border: Border.all(
            // The ball about to be bowled is the live one — the only token
            // that gets a bright edge.
            color: next
                ? Cyber.cyan.withValues(alpha: 0.9)
                : color.withValues(alpha: filled ? 0.75 : 0.35),
            width: next ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: Cyber.display(
            11,
            color: filled ? color : Cyber.muted,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ),
    );
  }
}

class _ExtraToken extends StatelessWidget {
  const _ExtraToken({required this.result});
  final BallResult result;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: Cyber.amber.withValues(alpha: 0.14),
      border: Border.all(color: Cyber.amber.withValues(alpha: 0.5)),
    ),
    child: Text(
      result.extra == ExtraType.noBall ? 'NB' : 'WD',
      style: Cyber.label(7, color: Cyber.amber, letterSpacing: 0.8),
    ),
  );
}

/// OVERDRIVE charge. Banked by middling the ball; armed, it turns gold and the
/// next shot leaves the bat harder. Distinct from the *shot* power on the
/// meter, which you earn ball by ball with the backlift.
class FinalOverOverdriveRail extends StatelessWidget {
  const FinalOverOverdriveRail({required this.game, super.key});

  final FinalOverGame game;

  @override
  Widget build(BuildContext context) {
    final requirement = game.overdriveRequirement;
    return AnimatedBuilder(
      animation: Listenable.merge([game.powerSegments, game.powerArmed]),
      builder: (context, _) {
        final segments = game.powerSegments.value.clamp(0, requirement);
        final armed = game.powerArmed.value;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                armed ? 'OVERDRIVE ARMED' : 'OVERDRIVE',
                style: Cyber.label(
                  8,
                  color: armed ? Cyber.gold : Cyber.muted,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CyberProgressBar(
                  value: segments / requirement,
                  accent: armed ? Cyber.gold : Cyber.cyan,
                  height: 5,
                  animate: false,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$segments/$requirement',
                style: Cyber.label(
                  8,
                  color: Cyber.muted,
                  letterSpacing: 1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The shot meter — Hoop Duel's, on a bat. The needle is your backlift: hold a
/// swing plate and it climbs, into the lime band for a full-blooded shot and on
/// into the red if you hold too long. The engine owns every number on it, so
/// what you aim at is exactly what you are judged against.
class FinalOverShotMeter extends StatelessWidget {
  const FinalOverShotMeter({required this.game, super.key});

  final FinalOverGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ChargeMeterView?>(
      valueListenable: game.shotMeter,
      builder: (context, view, _) => AnimatedOpacity(
        opacity: view == null ? 0 : 1,
        duration: const Duration(milliseconds: 160),
        child: CyberChargeMeter(
          view:
              view ??
              const ChargeMeterView(
                progress: 0,
                perfectCenter: 0.8,
                perfectHalf: 0.1,
                goodHalf: 0.22,
              ),
        ),
      ),
    );
  }
}

/// SIX / FOUR / OUT / PERFECT. Majors land with an elastic pop and a glow —
/// this is a moment, and moments are allowed to glow.
class FinalOverStingLayer extends StatelessWidget {
  const FinalOverStingLayer({required this.game, super.key});

  final FinalOverGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FinalOverSting?>(
      valueListenable: game.sting,
      builder: (context, sting, _) {
        if (sting == null) return const SizedBox.shrink();
        return Align(
          alignment: const Alignment(0, -0.32),
          child: TweenAnimationBuilder<double>(
            key: ValueKey(sting.label),
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: sting.major ? 520 : 320),
            curve: sting.major ? Curves.easeOutBack : Curves.easeOut,
            builder: (context, t, child) => Transform.scale(
              scale: sting.major ? 1.6 - 0.6 * t : 1.0,
              child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
            ),
            child: ClipPath(
              clipper: const HudChamferClipper(bigCut: 13, smallCut: 4),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: sting.major ? 24 : 17,
                  vertical: sting.major ? 11 : 8,
                ),
                decoration: BoxDecoration(
                  color: Cyber.bg.withValues(alpha: 0.92),
                  border: Border.all(
                    color: sting.color.withValues(alpha: 0.85),
                    width: 1.4,
                  ),
                  boxShadow: sting.major
                      ? Cyber.glow(sting.color, alpha: 0.4, blur: 22)
                      : null,
                ),
                child: Text(
                  sting.label,
                  style: Cyber.display(
                    sting.major ? 22 : 14,
                    color: sting.color,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The HUD widgets are all built under the match screen, which puts the game
/// in scope via an [InheritedWidget]. Keeps the constructors from having to
/// thread `game` through six layers.
class FinalOverGameScope extends InheritedWidget {
  const FinalOverGameScope({
    required this.game,
    required super.child,
    super.key,
  });

  final FinalOverGame game;

  @override
  bool updateShouldNotify(FinalOverGameScope old) => old.game != game;
}

FinalOverGame _gameOf(BuildContext context) => context
    .dependOnInheritedWidgetOfExactType<FinalOverGameScope>()!
    .game;
