import 'package:flutter/material.dart';

import '../../blocs/guess_player/guess_player_cubit.dart';
import '../../config/sport_modules.dart';
import '../../config/theme.dart';
import '../../models/sport_match.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';

/// The Cricket lobby is the first full-screen use of the sport-access kit.
/// All numbers come from the current daily record and the sport archive.
class CricketGuessPlayerLobby extends StatelessWidget {
  const CricketGuessPlayerLobby({
    required this.state,
    required this.resetLabel,
    required this.ctaLabel,
    required this.onOpenToday,
    required this.onOpenLogs,
    super.key,
  });

  final GuessPlayerState state;
  final String resetLabel;
  final String ctaLabel;
  final VoidCallback onOpenToday;
  final VoidCallback onOpenLogs;

  @override
  Widget build(BuildContext context) {
    final archive = state.archive;
    final record = archive.resultsByDay[state.currentDayKey];
    final streak = archive.solveStreak(state.currentDayKey);
    final winRate = (archive.winRate * 100).round();
    final averageAttempts = archive.averageAttempts;
    final completed = record?.completed ?? false;
    final status = completed
        ? record!.won
              ? 'SOLVED TODAY'
              : 'CASE CLOSED'
        : (record?.startedAtEpochMs ?? 0) > 0
        ? 'IN PROGRESS'
        : 'NEW CASE';
    final reward = completed ? record!.xpEarned : state.potentialXp;
    final clueCount =
        state.puzzle?.clues.length ?? GuessPlayerCubit.maxAttempts;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CyberKitSection(
                  label: 'TODAY\'S CASE',
                  count: state.currentDayKey,
                ),
                const SizedBox(height: 16),
                ChamferedActionSurface(
                  clipper: const HudChamferClipper(
                    bigCut: CyberKit.cut,
                    smallCut: 0,
                  ),
                  borderColor: Cyber.cyan.withValues(
                    alpha: CyberKit.borderAlpha,
                  ),
                  child: ColoredBox(
                    color: Cyber.panel,
                    child: Padding(
                      padding: const EdgeInsets.all(CyberKit.inset),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CyberSportEmblem(
                                icon: sportModuleFor(Sport.cricket).icon,
                                accent: sportModuleFor(Sport.cricket).accent,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'CRICKET // DAILY INTEL',
                                      style: Cyber.label(
                                        9,
                                        color: Cyber.cyan,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'GUESS THE PLAYER',
                                      style: Cyber.display(
                                        18,
                                        color: AppTheme.whiteColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Follow $clueCount career signals to identify the player. '
                            'Fewer guesses earn more XP.',
                            style: Cyber.bodyFor(
                              context,
                              14,
                              color: Cyber.muted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              CyberStatusBadge(label: status),
                              CyberStatusBadge(
                                label: completed
                                    ? '+$reward XP EARNED'
                                    : 'UP TO +$reward XP',
                                tone: CyberStatusTone.reward,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(height: 1, color: Cyber.line),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                size: 16,
                                color: Cyber.muted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'NEXT CASE IN',
                                  style: Cyber.label(
                                    9,
                                    color: Cyber.muted,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              Text(
                                resetLabel,
                                style: Cyber.display(12, color: Cyber.cyan)
                                    .copyWith(
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                CyberActionButton(
                  key: const ValueKey('cricket-guess-player-today'),
                  label: switch (ctaLabel) {
                    'RESUME' => 'RESUME CASE',
                    'REVIEW' => 'REVIEW RESULT',
                    _ => 'PLAY TODAY',
                  },
                  icon: Icons.arrow_forward_rounded,
                  tapSound: SoundEffect.playMatch,
                  onPressed: onOpenToday,
                ),
                const SizedBox(height: 28),
                const CyberKitSection(label: 'YOUR RECORD'),
                const SizedBox(height: 12),
                ChamferedActionSurface(
                  clipper: const HudChamferClipper(
                    bigCut: CyberKit.smallCut,
                    smallCut: 0,
                  ),
                  borderColor: Cyber.line,
                  child: ColoredBox(
                    color: Cyber.card,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _Metric(
                              label: 'SOLVE STREAK',
                              value: '$streak',
                            ),
                          ),
                          const _MetricDivider(),
                          Expanded(
                            child: _Metric(
                              label: 'WIN RATE',
                              value: '$winRate%',
                            ),
                          ),
                          const _MetricDivider(),
                          Expanded(
                            child: _Metric(
                              label: 'AVG TRIES',
                              value: averageAttempts == 0
                                  ? '—'
                                  : averageAttempts.toStringAsFixed(1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const CyberKitSection(label: 'CAREER ARCHIVE'),
                const SizedBox(height: 8),
                Text(
                  '${archive.solvedCount} SOLVED / '
                  '${archive.completedCount} PLAYED',
                  style: Cyber.bodyFor(context, 12, color: Cyber.muted),
                ),
                const SizedBox(height: 12),
                CyberActionButton(
                  key: const ValueKey('cricket-guess-player-archive'),
                  label: 'OPEN 30-DAY ARCHIVE',
                  variant: CyberActionVariant.secondary,
                  icon: Icons.history_rounded,
                  onPressed: onOpenLogs,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Cyber.label(9, color: Cyber.muted, letterSpacing: 0.5),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: Cyber.display(
              17,
              color: AppTheme.whiteColor,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
      ),
    ],
  );
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 54,
    margin: const EdgeInsets.symmetric(horizontal: 10),
    color: Cyber.line,
  );
}
