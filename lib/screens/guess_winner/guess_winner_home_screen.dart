import 'package:flutter/material.dart';

import '../../blocs/guess_winner/guess_winner_cubit.dart';
import '../../config/theme.dart';
import '../../widgets/cyber/daily_mystery_widgets.dart';
import '../../widgets/cyber/sport_signal_painters.dart';

class GuessWinnerHomeScreen extends StatelessWidget {
  const GuessWinnerHomeScreen({
    required this.state,
    required this.onBack,
    required this.onOpenToday,
    required this.onOpenLogs,
    required this.onRetry,
    this.now,
    super.key,
  });

  final GuessWinnerState state;
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
        ? 'REVIEW TODAY\'S FINAL'
        : state.activeDayKey == state.todayKey && state.guesses.isNotEmpty
        ? 'RESUME CHALLENGE'
        : 'PLAY TODAY\'S FINAL';
    return DailyMysteryLanding(
      title: 'WINNER FILE',
      subtitle: 'GUESS THE WINNER',
      systemLabel: 'COURT ARCHIVE // ONLINE',
      systemCode: 'SYS://SLAM_INTEL v1.0',
      heroTitle: 'ENCRYPTED CHAMPION',
      heroDescription:
          'Identify the Grand Slam winner before all ten lives are gone.',
      dayKey: state.todayKey,
      accent: Cyber.lime,
      secondaryAccent: Cyber.cyan,
      icon: Icons.sports_tennis_rounded,
      backdropPainter: const TennisMysterySignalPainter(),
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
