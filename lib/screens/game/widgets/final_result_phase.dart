import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/game/game_bloc.dart';
import '../../../blocs/game/game_event.dart';
import '../../../blocs/game/game_state.dart';
import '../../../config/enums.dart';
import '../../../config/theme.dart';
import '../../../config/tutorial_steps.dart';
import '../../../models/match.dart';
import '../../../utils/label_helpers.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/game_scaffold.dart';
import '../../../widgets/level_up_celebration.dart';
import '../../../widgets/match_widgets.dart';
import '../../../widgets/tutorial.dart';

class FinalResultPhase extends StatefulWidget {
  const FinalResultPhase({
    required this.state,
    required this.onNavigate,
    super.key,
  });

  final GameState state;
  final ValueChanged<AppSection> onNavigate;

  @override
  State<FinalResultPhase> createState() => _FinalResultPhaseState();
}

class _FinalResultPhaseState extends State<FinalResultPhase>
    with TickerProviderStateMixin {
  late final AnimationController _seq = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  late final Animation<double> _scoreOpacity = CurvedAnimation(
    parent: _seq,
    curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
  );

  late final Animation<Offset> _xpPanelSlide = Tween<Offset>(
    begin: const Offset(0, 0.6),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _seq,
    curve: const Interval(0.20, 0.45, curve: Curves.easeOutCubic),
  ));

  late final Animation<double> _xpPanelOpacity = CurvedAnimation(
    parent: _seq,
    curve: const Interval(0.20, 0.40, curve: Curves.easeOut),
  );

  late final Animation<double> _xpBarProgress = CurvedAnimation(
    parent: _seq,
    curve: const Interval(0.50, 0.85, curve: Curves.easeInOut),
  );

  late final Animation<double> _buttonsOpacity = CurvedAnimation(
    parent: _seq,
    curve: const Interval(0.90, 1.00, curve: Curves.easeOut),
  );

  late final int _oldXpIntoLevel;
  late final int _oldXpToNextLevel;
  bool _showLevelUp = false;

  static const _dirLabel = {
    PenaltyDirection.left: 'L',
    PenaltyDirection.center: 'C',
    PenaltyDirection.right: 'R',
  };

  @override
  void initState() {
    super.initState();
    final prev = widget.state.previousProgression;
    assert(prev != null, 'previousProgression must be set at finalResult phase');
    _oldXpIntoLevel = prev!.xpIntoLevel;
    _oldXpToNextLevel = prev.xpToNextLevel;

    _seq.addStatusListener((status) {
      if (status == AnimationStatus.completed &&
          mounted &&
          widget.state.hasLevelUp) {
        setState(() => _showLevelUp = true);
      }
    });
    _seq.forward();

    // Win/lose sting as the result screen appears.
    final s = widget.state;
    final won = s.penaltyKicks.isNotEmpty
        ? s.penaltyWinner == 'player'
        : s.playerScore > s.opponentScore;
    playSound(won ? SoundEffect.matchWin : SoundEffect.matchLose);
    // Peak-end beat — the result that defines how the session is remembered.
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _seq.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final wentToPenalties = state.penaltyKicks.isNotEmpty;
    final won = wentToPenalties
        ? state.penaltyWinner == 'player'
        : state.playerScore > state.opponentScore;
    final mvp = state.roundResults
        .where(
          (round) =>
              round.outcome == RoundOutcome.goal && round.playerAttacking,
        )
        .map((round) => round.attackerCard)
        .firstOrNull;

    // Running score after each round
    final List<({int p, int c})> runningScores = [];
    var pGoals = 0, cGoals = 0;
    for (final r in state.roundResults) {
      if (r.outcome == RoundOutcome.goal) {
        if (r.playerAttacking) { pGoals++; } else { cGoals++; }
      }
      runningScores.add((p: pGoals, c: cGoals));
    }

    return GameScaffold(
      title: 'Final Result',
      subtitle: '// Archive Complete',
      grain: true,
      leading: IconButton(
        onPressed: () {
          context.read<GameBloc>().add(MatchReset());
          widget.onNavigate(AppSection.home);
        },
        icon: const Icon(Icons.close),
      ),
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _seq,
            builder: (context, _) {
              final tickerT = ((_seq.value - 0.38) / 0.40).clamp(0.0, 1.0);
              final displayedXP = (state.lastMatchXP!.abs() * tickerT).round();
              final oldRatio = _oldXpIntoLevel / _oldXpToNextLevel;
              final newRatio =
                  state.progression.xpIntoLevel / state.progression.xpToNextLevel;
              final barFill =
                  (oldRatio + (newRatio - oldRatio) * _xpBarProgress.value)
                      .clamp(0.0, 1.0);

              return PhaseList(
                children: [
                  // Winner banner with fade animation
                  FadeTransition(
                    opacity: _scoreOpacity,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: won
                              ? [
                                  const Color(0xFF00E5FF).withValues(alpha: 0.15),
                                  const Color(0xFF00E5FF).withValues(alpha: 0.05),
                                ]
                              : [
                                  const Color(0xFFFF1744).withValues(alpha: 0.15),
                                  const Color(0xFFFF1744).withValues(alpha: 0.05),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: won
                              ? const Color(0xFF00E5FF)
                              : const Color(0xFFFF1744),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            won ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                            color: won
                                ? const Color(0xFF00E5FF)
                                : const Color(0xFFFF1744),
                            size: 40,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            wentToPenalties
                                ? (won
                                    ? 'YOU WIN ON PENALTIES'
                                    : 'DEFEAT ON PENALTIES')
                                : (won ? 'MATCH WON' : 'MATCH LOST'),
                            style: Cyber.display(
                              22,
                              color: won
                                  ? const Color(0xFF00E5FF)
                                  : const Color(0xFFFF1744),
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _ScorePill(
                                label: 'REGULAR',
                                score:
                                    '${state.playerScore} - ${state.opponentScore}',
                              ),
                              if (wentToPenalties) ...[
                                const SizedBox(width: 12),
                                _ScorePill(
                                  label: 'PENALTIES',
                                  score:
                                      '${state.penaltyPlayerScore} - ${state.penaltyOpponentScore}',
                                  highlight: true,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // XP panel with slide+fade animation
                  if (state.lastMatchXP != null)
                    SlideTransition(
                      position: _xpPanelSlide,
                      child: FadeTransition(
                        opacity: _xpPanelOpacity,
                        child: _XpProgressPanel(
                          xpDelta: state.lastMatchXP!,
                          displayedCount: displayedXP,
                          barFillRatio: barFill,
                          level: state.progression.playerLevel,
                          xpIntoLevel: state.progression.xpIntoLevel,
                          xpToNextLevel: state.progression.xpToNextLevel,
                        ),
                      ),
                    ),

                  // MVP card
                  if (mvp != null) ...[
                    Text(
                      'MVP',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Cyber.cyan,
                        letterSpacing: 2,
                      ),
                    ),
                    CyberPlayerCardTile(card: mvp, selected: true),
                  ],

                  // Penalty log
                  if (wentToPenalties) ...[
                    Text(
                      'PENALTY LOG',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Cyber.cyan,
                        letterSpacing: 2,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Cyber.cyan.withValues(alpha: 0.3),
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: Text('#', style: _headerStyle),
                                ),
                                Expanded(child: Text('TAKER', style: _headerStyle)),
                                SizedBox(
                                  width: 44,
                                  child: Text(
                                    'SHOOT',
                                    style: _headerStyle,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 44,
                                  child: Text(
                                    'DIVE',
                                    style: _headerStyle,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 32,
                                  child: Text('', style: _headerStyle),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFF1E3A5F)),
                          for (final kick in state.penaltyKicks)
                            _PenaltyLogRow(kick: kick, dirLabel: _dirLabel),
                        ],
                      ),
                    ),
                  ],

                  // Round log
                  _RoundLogHeader(count: state.roundResults.length),
                  if (state.roundResults.isNotEmpty)
                    _RoundGoalTrail(rounds: state.roundResults),
                  for (var i = 0; i < state.roundResults.length; i++)
                    _FinalRoundLogItem(
                      round: state.roundResults[i],
                      playerGoals: runningScores[i].p,
                      cpuGoals: runningScores[i].c,
                      index: i,
                      isLast: i == state.roundResults.length - 1,
                    ),

                  // Action buttons with fade animation
                  const SizedBox(height: 8),
                  FadeTransition(
                    opacity: _buttonsOpacity,
                    child: Column(
                      children: [
                        FilledButton.icon(
                          onPressed: () {
                            context.read<GameBloc>().add(MatchStarted());
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('PLAY AGAIN'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            context.read<GameBloc>().add(MatchReset());
                            widget.onNavigate(AppSection.home);
                          },
                          icon: const Icon(Icons.home),
                          label: const Text('HOME'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const TutorialTip(keyName: 'final', steps: finalTutorialSteps),

          // Level-up celebration overlay
          if (_showLevelUp)
            LevelUpCelebration(
              levels: widget.state.pendingLevelUps,
              onDismissed: () => setState(() => _showLevelUp = false),
            ),
        ],
      ),
    );
  }

  static final _headerStyle = Cyber.label(
    10,
    color: Colors.white38,
    weight: FontWeight.w700,
    letterSpacing: 1,
  );
}

class _XpProgressPanel extends StatelessWidget {
  const _XpProgressPanel({
    required this.xpDelta,
    required this.displayedCount,
    required this.barFillRatio,
    required this.level,
    required this.xpIntoLevel,
    required this.xpToNextLevel,
  });

  final int xpDelta;
  final int displayedCount;
  final double barFillRatio;
  final int level;
  final int xpIntoLevel;
  final int xpToNextLevel;

  @override
  Widget build(BuildContext context) {
    final isWin = xpDelta >= 0;
    final accentColor = isWin ? Cyber.cyan : const Color(0xFFFF4D6A);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Cyber.panel,
        border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // XP amount display
          Text(
            isWin ? '+$displayedCount XP' : '−$displayedCount XP',
            style: TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: accentColor,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),

          // XP bar
          CyberProgressBar(
            value: barFillRatio,
            accent: accentColor,
            height: 6,
            radius: 3,
            animate: false,
            trackColor: accentColor.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 8),

          // XP label
          Text(
            '$xpIntoLevel / $xpToNextLevel XP · LEVEL $level',
            style: Cyber.label(
              9,
              color: Cyber.muted,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({
    required this.label,
    required this.score,
    this.highlight = false,
  });
  final String label;
  final String score;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: highlight
            ? Cyber.cyan.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: highlight ? Cyber.cyan : Colors.white24),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: Cyber.label(
              10,
              color: highlight ? Cyber.cyan : Colors.white54,
              weight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            score,
            style: Cyber.display(
              20,
              color: highlight ? Cyber.cyan : Colors.white,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PenaltyLogRow extends StatelessWidget {
  const _PenaltyLogRow({required this.kick, required this.dirLabel});
  final PenaltyKick kick;
  final Map<PenaltyDirection, String> dirLabel;

  @override
  Widget build(BuildContext context) {
    final goalColor = kick.scored
        ? const Color(0xFF00E5FF)
        : const Color(0xFFFF1744);
    return Container(
      color: kick.scored
          ? const Color(0xFF00E5FF).withValues(alpha: 0.04)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${kick.kickNumber}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              kick.byPlayer ? 'YOU' : 'CPU',
              style: Cyber.label(
                12,
                color: kick.byPlayer ? Cyber.cyan : Colors.orange,
                weight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              dirLabel[kick.shootDirection]!,
              style: TextStyle(
                color: goalColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: Text(
              dirLabel[kick.diveDirection]!,
              style: const TextStyle(
                color: Colors.white38,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Icon(
              kick.scored ? Icons.check_circle : Icons.cancel,
              size: 18,
              color: goalColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundLogHeader extends StatelessWidget {
  const _RoundLogHeader({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MATCH LOG',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Cyber.cyan,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$count ROUNDS PLAYED',
          style: Cyber.label(
            10,
            color: Colors.white38,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _RoundGoalTrail extends StatelessWidget {
  const _RoundGoalTrail({required this.rounds});
  final List<RoundResult> rounds;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < rounds.length; i++)
          Expanded(
            child: _RoundGoalDot(
              hasGoal: rounds[i].outcome == RoundOutcome.goal,
              playerScored: rounds[i].playerAttacking,
              index: i,
            ),
          ),
      ],
    );
  }
}

class _RoundGoalDot extends StatelessWidget {
  const _RoundGoalDot({
    required this.hasGoal,
    required this.playerScored,
    required this.index,
  });

  final bool hasGoal;
  final bool playerScored;
  final int index;

  @override
  Widget build(BuildContext context) {
    final color = hasGoal
        ? (playerScored ? Cyber.cyan : Colors.orange)
        : Colors.white.withValues(alpha: 0.2);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 200 + index * 50),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  if (hasGoal)
                    BoxShadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FinalRoundLogItem extends StatelessWidget {
  const _FinalRoundLogItem({
    required this.round,
    required this.playerGoals,
    required this.cpuGoals,
    required this.index,
    required this.isLast,
  });

  final RoundResult round;
  final int playerGoals;
  final int cpuGoals;
  final int index;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isGoal = round.outcome == RoundOutcome.goal;
    final goalColor = isGoal
        ? (round.playerAttacking ? Cyber.cyan : Colors.orange)
        : Colors.white38;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + index * 70),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.28, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: AlwaysStoppedAnimation(value), curve: Curves.linear),
          ),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        color: isGoal
            ? (round.playerAttacking
                ? Cyber.cyan.withValues(alpha: 0.08)
                : Colors.orange.withValues(alpha: 0.08))
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(
                'R${round.round}',
                style: Cyber.label(
                  10,
                  color: Cyber.muted,
                  weight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Expanded(
              child: Text(
                round.scenario.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(
              width: 70,
              child: Text(
                outcomeLabel(round.outcome),
                style: TextStyle(
                  color: goalColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 50,
              child: Text(
                '$playerGoals - $cpuGoals',
                style: Cyber.display(
                  14,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
