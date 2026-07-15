import 'package:flutter/material.dart';

import 'package:final_over/app/theme.dart';
import 'widgets/arcade_button.dart';
import 'widgets/stadium_backdrop.dart';

class GameResultSummary {
  const GameResultSummary({
    required this.won,
    required this.runs,
    required this.target,
    required this.legalBalls,
    required this.wickets,
    required this.stars,
    required this.points,
    required this.objectiveLabel,
    required this.objectiveComplete,
    required this.history,
    this.reason,
  });

  final bool won;
  final int runs;
  final int target;
  final int legalBalls;
  final int wickets;
  final int stars;
  final int points;
  final String objectiveLabel;
  final bool objectiveComplete;
  final List<String> history;
  final String? reason;
}

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.summary,
    required this.onPlayAgain,
    required this.onHome,
    this.assetPackage,
  });

  final GameResultSummary summary;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;
  final String? assetPackage;

  @override
  Widget build(BuildContext context) {
    final accent = summary.won ? FinalOverPalette.green : FinalOverPalette.red;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: StadiumBackdrop(
          dim: .48,
          assetPackage: assetPackage,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 38,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        summary.won
                            ? Icons.emoji_events_rounded
                            : Icons.sports_cricket_rounded,
                        size: 68,
                        color: accent,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        summary.won ? 'VICTORY' : 'DEFEAT',
                        style: Theme.of(context).textTheme.displayLarge
                            ?.copyWith(fontSize: 48, color: accent),
                      ),
                      if (summary.reason case final reason?) ...[
                        const SizedBox(height: 8),
                        Text(
                          reason,
                          style: const TextStyle(
                            color: FinalOverPalette.muted,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: arcadePanel(),
                        child: Column(
                          children: [
                            Text(
                              '${summary.runs}/${summary.wickets}',
                              style: Theme.of(
                                context,
                              ).textTheme.displayLarge?.copyWith(fontSize: 44),
                            ),
                            Text(
                              'TARGET ${summary.target}  •  ${summary.legalBalls} LEGAL BALLS',
                              style: const TextStyle(
                                color: FinalOverPalette.muted,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(3, (index) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                  ),
                                  child: Icon(
                                    index < summary.stars
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    color: index < summary.stars
                                        ? FinalOverPalette.yellow
                                        : FinalOverPalette.muted,
                                    size: 38,
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  summary.objectiveComplete
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: summary.objectiveComplete
                                      ? FinalOverPalette.green
                                      : FinalOverPalette.muted,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    summary.objectiveLabel,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (summary.history.isNotEmpty)
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 7,
                          runSpacing: 7,
                          children: summary.history
                              .map((token) => _HistoryToken(token: token))
                              .toList(),
                        ),
                      const SizedBox(height: 24),
                      Text(
                        'POINTS ${summary.points}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: FinalOverPalette.cyan,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ArcadeButton(
                        label: 'PLAY AGAIN',
                        icon: Icons.replay_rounded,
                        onPressed: onPlayAgain,
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: onHome,
                        icon: const Icon(Icons.home_rounded),
                        label: const Text('HOME'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryToken extends StatelessWidget {
  const _HistoryToken({required this.token});
  final String token;

  @override
  Widget build(BuildContext context) {
    final wicket = token.contains('W');
    return Container(
      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        shape: token.length <= 2 ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: token.length <= 2 ? null : BorderRadius.circular(12),
        color: wicket ? FinalOverPalette.red : FinalOverPalette.deepBlue,
        border: Border.all(
          color: wicket ? FinalOverPalette.red : FinalOverPalette.cyan,
        ),
      ),
      child: Text(token, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}
