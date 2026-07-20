import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/guess_driver/guess_driver_cubit.dart';
import '../../config/theme.dart';
import '../../models/guess_driver.dart';
import '../../widgets/cyber/daily_mystery_widgets.dart';

class GuessDriverLogsScreen extends StatelessWidget {
  const GuessDriverLogsScreen({
    required this.state,
    required this.onBack,
    required this.onOpenDay,
    super.key,
  });

  final GuessDriverState state;
  final VoidCallback onBack;
  final Future<void> Function(String dayKey) onOpenDay;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<GuessDriverCubit>();
    final entries = [
      for (final dayKey in cubit.archiveDayKeys())
        _entryFor(
          dayKey,
          cubit.targetForDay(dayKey),
          state.archive.resultsByDay[dayKey],
        ),
    ];
    return DailyMysteryArchiveScreen(
      title: '30-DAY GRID ARCHIVE',
      subtitle: '${state.archive.wonCount} ALL-TIME WINS',
      accent: Cyber.pink,
      icon: Icons.sports_motorsports_rounded,
      entries: entries,
      wins: state.archive.wonCount,
      played: state.archive.playedCount,
      onBack: onBack,
      onOpenDay: onOpenDay,
    );
  }

  DailyMysteryArchiveEntry _entryFor(
    String dayKey,
    F1RaceCard target,
    GuessDriverDailyResult? result,
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
      prompt: '${target.trackName} · ${target.year}',
      detail: target.country,
      answer: result?.targetDriverName,
      heartsRemaining: result?.heartsRemaining,
    );
  }
}
