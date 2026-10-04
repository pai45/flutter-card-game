import 'dart:async';

import 'package:flutter/material.dart';

import '../../blocs/guess_driver/guess_driver_cubit.dart';
import '../../config/theme.dart';
import '../../models/daily_mystery.dart';
import '../../models/sport_match.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import '../leaderboard/widgets/game_leaderboard_button.dart';

class GuessDriverHomeScreen extends StatefulWidget {
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
  State<GuessDriverHomeScreen> createState() => _GuessDriverHomeScreenState();
}

class _GuessDriverHomeScreenState extends State<GuessDriverHomeScreen> {
  Timer? _ticker;
  Duration _untilReset = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateCountdown(),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _updateCountdown() {
    final now = (widget.now ?? DateTime.now)();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    if (!mounted) return;
    setState(() => _untilReset = tomorrow.difference(now));
  }

  @override
  Widget build(BuildContext context) => GameScaffold(
    title: 'MOTORSPORT',
    subtitle: 'GUESS THE DRIVER',
    leading: IconButton(
      tooltip: 'Back to games',
      onPressed: () {
        playSound(SoundEffect.uiTap);
        widget.onBack();
      },
      icon: const Icon(Icons.arrow_back, color: Cyber.cyan),
    ),
    rightSlot: const GameLeaderboardButton(
      sport: Sport.motorsport,
      mode: GameMode.mystery,
      accent: Cyber.cyan,
    ),
    child: _body(),
  );

  Widget _body() {
    final state = widget.state;
    if (state.loadStatus == DailyMysteryLoadStatus.loading) {
      return const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(color: Cyber.cyan, strokeWidth: 2),
        ),
      );
    }
    if (state.loadStatus == DailyMysteryLoadStatus.error) {
      return CyberNoDataState(
        icon: Icons.sync_problem_rounded,
        title: 'INTEL LINK FAILED',
        message: state.errorMessage ?? 'The daily mystery could not be loaded.',
        accent: Cyber.danger,
        actionLabel: 'RETRY LINK',
        actionIcon: Icons.refresh,
        onAction: widget.onRetry,
      );
    }

    final archive = state.archive;
    final result = archive.resultsByDay[state.todayKey];
    final resumable =
        result == null &&
        state.activeDayKey == state.todayKey &&
        state.guesses.isNotEmpty;
    final status = result != null
        ? result.won
              ? 'SOLVED TODAY'
              : 'CASE CLOSED'
        : resumable
        ? 'IN PROGRESS'
        : 'NEW CASE';
    final hearts =
        result?.heartsRemaining ??
        (resumable ? state.remainingHearts : GuessDriverCubit.maxHearts);

    return DailyCaseLobby(
      dayKey: state.todayKey,
      sportLabel: 'MOTORSPORT',
      sportIcon: Icons.sports_motorsports_rounded,
      sportAccent: Cyber.pink,
      title: 'GUESS THE DRIVER',
      description:
          'Decode the race winner from the year, circuit and clues '
          'before all ten hearts leave the grid.',
      status: status,
      resourceLabel: '$hearts HEARTS ${result == null ? 'TO SOLVE' : 'LEFT'}',
      resourceTone: CyberStatusTone.available,
      resetLabel: _formatCountdown(_untilReset),
      ctaLabel: result != null
          ? 'REVIEW TODAY\'S RACE'
          : resumable
          ? 'RESUME CHALLENGE'
          : 'PLAY TODAY\'S RACE',
      metrics: [
        DailyCaseMetric('WIN STREAK', '${archive.winStreak(state.todayKey)}'),
        DailyCaseMetric('WIN RATE', '${(archive.winRate * 100).round()}%'),
        DailyCaseMetric('BEST HEARTS', '${archive.bestHeartsRemaining}'),
      ],
      solvedCount: archive.wonCount,
      playedCount: archive.playedCount,
      archiveLabel: 'RACE ARCHIVE',
      onOpenToday: widget.onOpenToday,
      onOpenLogs: widget.onOpenLogs,
      actionKey: const ValueKey('guess-driver-today'),
      archiveKey: const ValueKey('guess-driver-archive'),
    );
  }
}

String _formatCountdown(Duration value) {
  final hours = value.inHours.toString().padLeft(2, '0');
  final minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
