import 'dart:math';

import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../games/tennis/tennis_game.dart';
import '../../../models/tennis.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

class TennisHud extends StatelessWidget {
  const TennisHud({required this.game, required this.onPause, super.key});

  final TennisGame game;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _ModeTag(config: game.config),
                const Spacer(),
                _HudButton(
                  icon: Icons.pause_rounded,
                  semanticLabel: 'Pause match',
                  onTap: onPause,
                ),
              ],
            ),
            const SizedBox(height: 7),
            if (game.config.mode == TennisMode.quickMatch ||
                game.config.mode == TennisMode.tournament ||
                (game.config.mode == TennisMode.training &&
                    game.config.trainingLesson == 8))
              _MatchScoreboard(game: game)
            else
              _PracticeScoreboard(game: game),
            const SizedBox(height: 7),
            _ServeMeter(game: game),
          ],
        ),
      ),
    );
  }
}

class TennisStatusRails extends StatelessWidget {
  const TennisStatusRails({required this.game, super.key});

  final TennisGame game;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([game.stamina01, game.focus01]),
      builder: (context, _) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          padding: const EdgeInsets.fromLTRB(11, 8, 11, 9),
          decoration: BoxDecoration(
            color: Cyber.bg.withValues(alpha: 0.84),
            border: Border.all(color: Cyber.border.withValues(alpha: 0.72)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _Meter(
                  label: 'STAMINA',
                  value: game.stamina01.value,
                  color: Cyber.cyan,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _Meter(
                  label: game.engine.focusPointActive
                      ? 'FOCUS ACTIVE'
                      : 'FOCUS',
                  value: game.engine.focusPointActive ? 1 : game.focus01.value,
                  color: Cyber.lime,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class TennisStingLayer extends StatelessWidget {
  const TennisStingLayer({required this.game, super.key});

  final TennisGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TennisSting?>(
      valueListenable: game.sting,
      builder: (context, sting, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: sting == null
              ? const SizedBox.shrink()
              : Align(
                  key: ValueKey(sting.id),
                  alignment: const Alignment(0, -0.28),
                  child: IgnorePointer(
                    child: ClipPath(
                      clipper: const HudChamferClipper(bigCut: 13, smallCut: 4),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: sting.major ? 24 : 17,
                          vertical: sting.major ? 11 : 8,
                        ),
                        color: Cyber.bg.withValues(alpha: 0.9),
                        child: Text(
                          sting.label,
                          style: Cyber.display(
                            sting.major ? 19 : 14,
                            color: sting.color,
                            letterSpacing: 1.8,
                          ),
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

class _ModeTag extends StatelessWidget {
  const _ModeTag({required this.config});

  final TennisMatchConfig config;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const HudChamferClipper(bigCut: 7, smallCut: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        color: Cyber.panel.withValues(alpha: 0.9),
        child: Text(
          config.mode == TennisMode.training
              ? 'TRAINING // ${config.trainingLesson}'
              : config.mode.label,
          style: Cyber.display(9, color: Cyber.cyan, letterSpacing: 1),
        ),
      ),
    );
  }
}

class _MatchScoreboard extends StatelessWidget {
  const _MatchScoreboard({required this.game});

  final TennisGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TennisScoreState>(
      valueListenable: game.score,
      builder: (context, score, _) {
        final player = tennisPlayerById(game.config.playerId);
        final opponent = tennisPlayerById(game.config.opponentId);
        return ClipPath(
          clipper: const HudChamferClipper(bigCut: 12, smallCut: 4),
          child: Container(
            color: Cyber.bg.withValues(alpha: 0.92),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
            child: Column(
              children: [
                _ScoreRow(
                  name: opponent.name.toUpperCase(),
                  serving: score.currentServer == 1,
                  games: score.opponentGames,
                  points: score.pointLabel(1),
                  accent: Cyber.amber,
                ),
                const Divider(height: 9, color: Cyber.border),
                _ScoreRow(
                  name: player.name.toUpperCase(),
                  serving: score.currentServer == 0,
                  games: score.playerGames,
                  points: score.pointLabel(0),
                  accent: Cyber.cyan,
                ),
                if (score.isDeuce || score.tieBreak)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      score.tieBreak ? 'TIEBREAK' : 'DEUCE',
                      style: Cyber.display(8, color: Cyber.lime),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.name,
    required this.serving,
    required this.games,
    required this.points,
    required this.accent,
  });

  final String name;
  final bool serving;
  final int games;
  final String points;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: serving ? Cyber.lime : Cyber.border,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Cyber.display(10, color: Colors.white),
          ),
        ),
        Text('$games', style: Cyber.display(18, color: accent)),
        const SizedBox(width: 18),
        SizedBox(
          width: 43,
          child: Text(
            points,
            textAlign: TextAlign.right,
            style: Cyber.display(16, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _PracticeScoreboard extends StatelessWidget {
  const _PracticeScoreboard({required this.game});

  final TennisGame game;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        game.practiceScore,
        game.ballsRemaining,
        game.lessonProgress,
        game.elapsedTenths,
        game.rally,
      ]),
      builder: (context, _) {
        final mode = game.config.mode;
        late String primary;
        late String secondary;
        if (mode == TennisMode.endlessRally) {
          primary = '${game.practiceScore.value} RETURNS';
          secondary = 'PACE +2% EVERY 5';
        } else if (mode == TennisMode.targetPractice) {
          primary = '${game.practiceScore.value} PTS';
          final remaining = max(0, 90 - game.elapsedTenths.value ~/ 10);
          secondary = '${game.ballsRemaining.value} BALLS / ${remaining}s';
        } else {
          primary = 'LESSON ${game.config.trainingLesson}';
          secondary = '${game.lessonProgress.value} ACTIONS COMPLETE';
        }
        return ClipPath(
          clipper: const HudChamferClipper(bigCut: 12, smallCut: 4),
          child: Container(
            color: Cyber.bg.withValues(alpha: 0.92),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Text(primary, style: Cyber.display(15, color: Cyber.lime)),
                const Spacer(),
                Text(secondary, style: Cyber.display(8, color: Cyber.muted)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ServeMeter extends StatelessWidget {
  const _ServeMeter({required this.game});

  final TennisGame game;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([game.phase, game.serveMeter]),
      builder: (context, _) {
        final visible =
            game.phase.value == TennisMatchPhase.preServe ||
            game.phase.value == TennisMatchPhase.serving;
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 140),
          opacity: visible ? 1 : 0,
          child: Container(
            width: 182,
            padding: const EdgeInsets.fromLTRB(9, 6, 9, 7),
            color: Cyber.bg.withValues(alpha: 0.82),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          game.engine.serveNumber == 1
                              ? '1ST SERVE'
                              : '2ND SERVE',
                          style: Cyber.display(8, color: Cyber.muted),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          'RELEASE IN GREEN',
                          style: Cyber.display(7, color: Cyber.lime),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Stack(
                  children: [
                    Container(height: 5, color: Cyber.border),
                    Positioned(
                      left: 122,
                      width: 26,
                      child: Container(
                        height: 5,
                        color: Cyber.lime.withValues(alpha: 0.48),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: game.serveMeter.value,
                      child: Container(height: 5, color: Cyber.cyan),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: Cyber.display(8, color: Cyber.muted)),
            const Spacer(),
            Text(
              '${(value * 100).round()}%',
              style: Cyber.display(8, color: color),
            ),
          ],
        ),
        const SizedBox(height: 5),
        CyberProgressBar(
          value: value,
          accent: color,
          height: 5,
          animate: false,
        ),
      ],
    );
  }
}

class _HudButton extends StatelessWidget {
  const _HudButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 36,
          decoration: BoxDecoration(
            color: Cyber.panel.withValues(alpha: 0.9),
            border: Border.all(color: Cyber.cyan.withValues(alpha: 0.46)),
          ),
          child: Icon(icon, color: Cyber.cyan, size: 21),
        ),
      ),
    );
  }
}
