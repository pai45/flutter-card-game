import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/football_chess/football_chess_cubit.dart';
import '../../../blocs/football_chess/football_chess_state.dart';
import '../../../blocs/game/game_bloc.dart';
import '../../../config/theme.dart';
import '../../../models/cards.dart';
import '../../../models/football_chess.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// Full-time screen for 5v5 Football Chess, modelled on the Pitch Duel result
/// phase: a sequenced reveal — outcome banner → giant scoreline → XP count-up →
/// MVP → goal timeline — over a fixed PLAY AGAIN / EXIT dock.
class FootballChessResult extends StatefulWidget {
  const FootballChessResult({
    required this.match,
    required this.awardedXp,
    required this.onExit,
    required this.onPlayAgain,
    super.key,
  });

  final ChessMatch match;
  final int awardedXp;
  final VoidCallback onExit;
  final VoidCallback onPlayAgain;

  @override
  State<FootballChessResult> createState() => _FootballChessResultState();
}

class _FootballChessResultState extends State<FootballChessResult>
    with SingleTickerProviderStateMixin {
  late final AnimationController _seq = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  late final Animation<double> _banner = CurvedAnimation(
    parent: _seq,
    curve: const Interval(0.0, 0.22, curve: Curves.easeOut),
  );
  late final Animation<double> _score = CurvedAnimation(
    parent: _seq,
    curve: const Interval(0.12, 0.38, curve: Curves.easeOutBack),
  );
  late final Animation<double> _xpPanel = CurvedAnimation(
    parent: _seq,
    curve: const Interval(0.30, 0.52, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    _seq.forward();
  }

  @override
  void dispose() {
    _seq.dispose();
    super.dispose();
  }

  PlayerCard? _mvp() {
    final counts = <String, int>{};
    for (final g in widget.match.goals) {
      if (g.byPlayer) counts[g.scorerShortName] = (counts[g.scorerShortName] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    final topName =
        counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    for (final c in widget.match.playerSquad) {
      if (c.shortName == topName) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    final won = m.playerWon;
    final draw = m.isDraw;
    final accent = won
        ? Cyber.gold
        : draw
        ? Cyber.amber
        : Cyber.danger;
    final verdict = won
        ? 'VICTORY'
        : draw
        ? 'DRAW'
        : 'DEFEAT';
    final prog = context.watch<GameBloc>().state.progression;
    final mvp = _mvp();

    return Positioned.fill(
      child: Container(
        color: Cyber.bg.withValues(alpha: 0.94),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: AnimatedBuilder(
                  animation: _seq,
                  builder: (context, _) {
                    final xpT = ((_seq.value - 0.38) / 0.40).clamp(0.0, 1.0);
                    final shownXp = (widget.awardedXp * xpT).round();
                    final barFill = (prog.xpToNextLevel == 0
                            ? 0.0
                            : prog.xpIntoLevel / prog.xpToNextLevel) *
                        xpT;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                      child: Column(
                        children: [
                          FadeTransition(
                            opacity: _banner,
                            child: _OutcomeBanner(
                              verdict: verdict,
                              accent: accent,
                              won: won,
                              draw: draw,
                            ),
                          ),
                          const SizedBox(height: 18),
                          ScaleTransition(
                            scale: _score,
                            child: _Scoreline(
                              you: m.playerScore,
                              opp: m.opponentScore,
                            ),
                          ),
                          const SizedBox(height: 18),
                          FadeTransition(
                            opacity: _xpPanel,
                            child: SlideTransition(
                              position: Tween(
                                begin: const Offset(0, 0.4),
                                end: Offset.zero,
                              ).animate(_xpPanel),
                              child: _XpPanel(
                                shownXp: shownXp,
                                barFill: barFill.clamp(0.0, 1.0),
                                level: prog.playerLevel,
                                into: prog.xpIntoLevel,
                                span: prog.xpToNextLevel,
                              ),
                            ),
                          ),
                          if (mvp != null) ...[
                            const SizedBox(height: 18),
                            Text(
                              'MVP',
                              style: Cyber.label(12, color: Cyber.gold, letterSpacing: 2),
                            ),
                            const SizedBox(height: 8),
                            CyberPlayerCardTile(card: mvp, selected: true),
                          ],
                          const SizedBox(height: 18),
                          _GoalTimeline(goals: m.goals, opponentName: m.opponentName),
                        ],
                      ),
                    );
                  },
                ),
              ),
              _Dock(onExit: widget.onExit, onPlayAgain: widget.onPlayAgain),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutcomeBanner extends StatelessWidget {
  const _OutcomeBanner({
    required this.verdict,
    required this.accent,
    required this.won,
    required this.draw,
  });

  final String verdict;
  final Color accent;
  final bool won;
  final bool draw;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent, width: 1.5),
        boxShadow: Cyber.glow(accent),
      ),
      child: Column(
        children: [
          Icon(
            draw
                ? Icons.balance
                : won
                ? Icons.emoji_events
                : Icons.sentiment_dissatisfied,
            color: accent,
            size: 34,
          ),
          const SizedBox(height: 6),
          Text(verdict, style: Cyber.display(34, color: accent, letterSpacing: 3)),
        ],
      ),
    );
  }
}

class _Scoreline extends StatelessWidget {
  const _Scoreline({required this.you, required this.opp});

  final int you;
  final int opp;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('$you', style: Cyber.display(64, color: Cyber.cyan)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('-', style: Cyber.display(44, color: Cyber.muted)),
        ),
        Text('$opp', style: Cyber.display(64, color: Cyber.magenta)),
      ],
    );
  }
}

class _XpPanel extends StatelessWidget {
  const _XpPanel({
    required this.shownXp,
    required this.barFill,
    required this.level,
    required this.into,
    required this.span,
  });

  final int shownXp;
  final double barFill;
  final int level;
  final int into;
  final int span;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Cyber.panel.withValues(alpha: 0.85),
        border: Border.all(color: Cyber.violet.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '+$shownXp XP',
            style: TextStyle(
              fontFamily: Cyber.displayFont,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: Cyber.violet,
            ),
          ),
          const SizedBox(height: 12),
          CyberProgressBar(
            value: barFill,
            accent: Cyber.violet,
            height: 6,
            radius: 3,
            animate: false,
            trackColor: Cyber.violet.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 8),
          Text(
            '$into / $span XP · LEVEL $level',
            style: Cyber.label(9, color: Cyber.muted, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

class _GoalTimeline extends StatelessWidget {
  const _GoalTimeline({required this.goals, required this.opponentName});

  final List<ChessGoal> goals;
  final String opponentName;

  String _time(double atClock) {
    final elapsed = (FootballChessCubit.kMatchSeconds - atClock)
        .clamp(0, FootballChessCubit.kMatchSeconds)
        .ceil();
    return "${elapsed ~/ 60}'${(elapsed % 60).toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GOAL LOG',
          style: Cyber.label(12, color: Cyber.cyan, letterSpacing: 2),
        ),
        const SizedBox(height: 8),
        if (goals.isEmpty)
          Text(
            'NO GOALS — A TENSE STALEMATE.',
            style: Cyber.label(10, color: Cyber.muted, letterSpacing: 1),
          )
        else
          for (var i = 0; i < goals.length; i++)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 260 + i * 70),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset((1 - t) * 20, 0),
                  child: child,
                ),
              ),
              child: _GoalRow(goal: goals[i], opponentName: opponentName, time: _time(goals[i].atClock)),
            ),
      ],
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.goal,
    required this.opponentName,
    required this.time,
  });

  final ChessGoal goal;
  final String opponentName;
  final String time;

  @override
  Widget build(BuildContext context) {
    final color = goal.byPlayer ? Cyber.cyan : Cyber.magenta;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      color: color.withValues(alpha: 0.07),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${goal.scorerShortName.toUpperCase()} · ${goal.byPlayer ? 'YOU' : opponentName.toUpperCase()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.label(10, color: Colors.white, letterSpacing: 0.8),
            ),
          ),
          Text(
            time,
            style: Cyber.display(13, color: color)
                .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}

class _Dock extends StatelessWidget {
  const _Dock({required this.onExit, required this.onPlayAgain});

  final VoidCallback onExit;
  final VoidCallback onPlayAgain;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: CyberCtaButton(
              label: 'EXIT',
              onPressed: () {
                playSound(SoundEffect.uiTap);
                onExit();
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CyberCtaButton(
              label: 'PLAY AGAIN',
              primary: true,
              onPressed: () {
                playSound(SoundEffect.playMatch);
                onPlayAgain();
              },
            ),
          ),
        ],
      ),
    );
  }
}
