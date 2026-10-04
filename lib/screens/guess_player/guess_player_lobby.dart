import 'package:flutter/material.dart';

import '../../blocs/guess_player/guess_player_cubit.dart';
import '../../config/sport_modules.dart';
import '../../models/sport_match.dart';
import '../../widgets/cyber/cyber_widgets.dart';

/// Maps the sport's daily record and archive into the shared case dossier.
class GuessPlayerLobby extends StatelessWidget {
  const GuessPlayerLobby({
    required this.sport,
    required this.state,
    required this.resetLabel,
    required this.ctaLabel,
    required this.onOpenToday,
    required this.onOpenLogs,
    super.key,
  });

  final Sport sport;
  final GuessPlayerState state;
  final String resetLabel;
  final String ctaLabel;
  final VoidCallback onOpenToday;
  final VoidCallback onOpenLogs;

  @override
  Widget build(BuildContext context) {
    final archive = state.archive;
    final record = archive.resultsByDay[state.currentDayKey];
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
    final averageAttempts = archive.averageAttempts;

    return DailyCaseLobby(
      dayKey: state.currentDayKey,
      sportLabel: sport.name.toUpperCase(),
      sportIcon: sportModuleFor(sport).icon,
      sportAccent: sportModuleFor(sport).accent,
      title: 'GUESS THE PLAYER',
      description:
          'Follow $clueCount career signals to identify the player. '
          'Fewer guesses earn more XP.',
      status: status,
      resourceLabel: completed ? '+$reward XP EARNED' : 'UP TO +$reward XP',
      resetLabel: resetLabel,
      ctaLabel: switch (ctaLabel) {
        'RESUME' => 'RESUME CASE',
        'REVIEW' => 'REVIEW RESULT',
        _ => 'PLAY TODAY',
      },
      metrics: [
        DailyCaseMetric(
          'SOLVE STREAK',
          '${archive.solveStreak(state.currentDayKey)}',
        ),
        DailyCaseMetric('WIN RATE', '${(archive.winRate * 100).round()}%'),
        DailyCaseMetric(
          'AVG TRIES',
          averageAttempts == 0 ? '—' : averageAttempts.toStringAsFixed(1),
        ),
      ],
      solvedCount: archive.solvedCount,
      playedCount: archive.completedCount,
      onOpenToday: onOpenToday,
      onOpenLogs: onOpenLogs,
      actionKey: const ValueKey('guess-player-today'),
      archiveKey: const ValueKey('guess-player-archive'),
    );
  }
}
