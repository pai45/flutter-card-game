import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/guess_winner/guess_winner_cubit.dart';
import '../../config/theme.dart';
import '../../models/guess_winner.dart';
import '../../widgets/cyber/daily_mystery_widgets.dart';

class GuessWinnerLogsScreen extends StatelessWidget {
  const GuessWinnerLogsScreen({
    required this.state,
    required this.onBack,
    required this.onOpenDay,
    super.key,
  });

  final GuessWinnerState state;
  final VoidCallback onBack;
  final Future<void> Function(String dayKey) onOpenDay;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<GuessWinnerCubit>();
    final entries = [
      for (final dayKey in cubit.archiveDayKeys())
        _entryFor(
          dayKey,
          cubit.targetForDay(dayKey),
          state.archive.resultsByDay[dayKey],
        ),
    ];
    return DailyMysteryArchiveScreen(
      title: '30-DAY COURT ARCHIVE',
      subtitle: '${state.archive.wonCount} ALL-TIME WINS',
      accent: Cyber.lime,
      icon: Icons.emoji_events_rounded,
      entries: entries,
      wins: state.archive.wonCount,
      played: state.archive.playedCount,
      onBack: onBack,
      onOpenDay: onOpenDay,
    );
  }

  DailyMysteryArchiveEntry _entryFor(
    String dayKey,
    GrandSlamCard target,
    GuessWinnerDailyResult? result,
  ) {
    final status = result == null
        ? dayKey == state.todayKey
              ? DailyMysteryArchiveStatus.live
              : DailyMysteryArchiveStatus.noEntry
        : result.won
        ? DailyMysteryArchiveStatus.won
        : DailyMysteryArchiveStatus.lost;
    return DailyMysteryArchiveEntry(
      dayKey: dayKey,
      status: status,
      prompt: '${target.tournament} · ${target.year}',
      detail: target.category,
      answer: result?.targetWinnerName,
      heartsRemaining: result?.heartsRemaining,
    );
  }
}
