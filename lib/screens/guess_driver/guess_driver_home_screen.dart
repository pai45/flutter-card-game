import 'package:flutter/material.dart';

import '../../blocs/guess_driver/guess_driver_cubit.dart';
import '../../config/theme.dart';
import '../../widgets/cyber/daily_mystery_widgets.dart';
import '../../widgets/cyber/sport_signal_painters.dart';

class GuessDriverHomeScreen extends StatelessWidget {
  const GuessDriverHomeScreen({
    required this.state,
    required this.onBack,
    required this.onOpenToday,
    required this.onOpenLogs,
    required this.onRetry,
    this.now,
    super.key,
  });

  final GuessDriverState state;
  final VoidCallback onBack;
  final VoidCallback onOpenToday;
  final VoidCallback onOpenLogs;
  final VoidCallback onRetry;
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    final archive = state.archive;
    final todayResult = archive.resultsByDay[state.todayKey];
    final ctaLabel = todayResult != null
        ? 'REVIEW TODAY\'S RACE'
        : state.activeDayKey == state.todayKey && state.guesses.isNotEmpty
        ? 'RESUME CHALLENGE'
        : 'PLAY TODAY\'S RACE';
    return DailyMysteryLanding(
      title: 'DAILY GRID FILE',
      subtitle: 'GUESS THE DRIVER',
      systemLabel: 'PIT WALL // SIGNAL LIVE',
      systemCode: 'SYS://RACE_INTEL v1.0',
      heroTitle: 'CLASSIFIED DRIVER',
      heroDescription:
          'Decode the race winner before all ten lives leave the grid.',
      dayKey: state.todayKey,
      accent: Cyber.pink,
      secondaryAccent: Cyber.cyan,
      icon: Icons.sports_motorsports_rounded,
      backdropPainter: const F1MysterySignalPainter(accent: Cyber.pink),
      streak: archive.winStreak(state.todayKey),
      winRate: archive.winRate,
      bestHearts: archive.bestHeartsRemaining,
      wins: archive.wonCount,
      played: archive.playedCount,
      ctaLabel: ctaLabel,
      loadStatus: state.loadStatus,
      errorMessage: state.errorMessage,
      now: now,
      onBack: onBack,
      onOpenToday: onOpenToday,
      onOpenLogs: onOpenLogs,
      onRetry: onRetry,
    );
  }
}
