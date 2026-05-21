import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/game/game_bloc.dart';
import '../../../blocs/game/game_event.dart';
import '../../../blocs/game/game_state.dart';
import '../../../config/enums.dart';
import '../../../config/theme.dart';
import '../../../config/tutorial_steps.dart';
import '../../../models/match.dart';
import '../../../utils/label_helpers.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/game_scaffold.dart';
import '../../../widgets/match_widgets.dart';
import '../../../widgets/tutorial.dart';

class FinalResultPhase extends StatelessWidget {
  const FinalResultPhase({
    required this.state,
    required this.onNavigate,
    super.key,
  });

  final GameState state;
  final ValueChanged<AppSection> onNavigate;

  static const _dirLabel = {
    PenaltyDirection.left: 'L',
    PenaltyDirection.center: 'C',
    PenaltyDirection.right: 'R',
  };

  @override
  Widget build(BuildContext context) {
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

    return GameScaffold(
      title: 'Final Result',
      subtitle: '// Archive Complete',
      leading: IconButton(
        onPressed: () {
          context.read<GameBloc>().add(MatchReset());
          onNavigate(AppSection.home);
        },
        icon: const Icon(Icons.close),
      ),
      child: Stack(
        children: [
          PhaseList(
            children: [
              // -- Winner banner ------------------------------------------
              Container(
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
                    // Scores row
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

              // -- MVP card -----------------------------------------------
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

              // -- Penalty kick-by-kick log -------------------------------
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
                      // Header row
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

              // -- Round log ---------------------------------------------
              Text(
                'ROUND LOG',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Cyber.cyan,
                  letterSpacing: 2,
                ),
              ),
              for (final round in state.roundResults)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: Cyber.cyan.withValues(alpha: 0.2),
                    child: Text(
                      '${round.round}',
                      style: const TextStyle(color: Cyber.cyan, fontSize: 12),
                    ),
                  ),
                  title: Text(
                    '${round.scenario.title}: ${outcomeLabel(round.outcome)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  subtitle: Text(
                    round.playerAttacking ? 'You attacked' : 'You defended',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ),

              // -- Action buttons -----------------------------------------
              const SizedBox(height: 8),
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
                  onNavigate(AppSection.home);
                },
                icon: const Icon(Icons.home),
                label: const Text('HOME'),
              ),
            ],
          ),
          const TutorialTip(keyName: 'final', steps: finalTutorialSteps),
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
          // Shoot direction chip
          _DirChip(
            label: dirLabel[kick.shootDirection]!,
            color: Colors.white70,
          ),
          const SizedBox(width: 4),
          const Text(
            'vs',
            style: TextStyle(color: Colors.white30, fontSize: 10),
          ),
          const SizedBox(width: 4),
          // Dive direction chip
          _DirChip(
            label: dirLabel[kick.diveDirection]!,
            color: Colors.orange.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 8),
          // Result icon
          SizedBox(
            width: 32,
            child: Icon(
              kick.scored ? Icons.check_circle : Icons.cancel,
              color: goalColor,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _DirChip extends StatelessWidget {
  const _DirChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: Cyber.label(11, color: color, weight: FontWeight.w700),
      ),
    );
  }
}
