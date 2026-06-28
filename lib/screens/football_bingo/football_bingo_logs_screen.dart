import 'package:flutter/material.dart';

import '../../blocs/football_bingo/football_bingo_state.dart';
import '../../config/theme.dart';
import '../../data/football_bingo_puzzles.dart';
import '../../models/football_bingo.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/cyber/fixture_card.dart';

class FootballBingoLogsScreen extends StatelessWidget {
  const FootballBingoLogsScreen({
    required this.state,
    required this.onBack,
    required this.onOpenDay,
    super.key,
  });

  final FootballBingoState state;
  final VoidCallback onBack;
  final ValueChanged<String> onOpenDay;

  @override
  Widget build(BuildContext context) {
    final items = state.unlockedDayKeys.reversed.toList();
    final completed = items
        .where(
          (dayKey) => state.archive.progressByDay[dayKey]?.completed ?? false,
        )
        .length;
    final totalSolved = items.fold<int>(
      0,
      (sum, dayKey) =>
          sum +
          (state.archive.progressByDay[dayKey]?.solvedCellIds.length ?? 0),
    );
    final completionRate = items.isEmpty
        ? 0
        : (completed / items.length * 100).round();

    return Scaffold(
      backgroundColor: Cyber.bg,
      body: CyberBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 8, 0),
                child: Row(
                  children: [
                    Container(width: 3, height: 22, color: Cyber.amber),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'BINGO LOGS',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Orbitron',
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.close, color: Cyber.cyan),
                    ),
                  ],
                ),
              ),
              if (items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Row(
                    children: [
                      _LogStatBox('DONE', '$completed', Cyber.lime),
                      const SizedBox(width: 8),
                      _LogStatBox(
                        'OPEN',
                        '${items.length - completed}',
                        Cyber.cyan,
                      ),
                      const SizedBox(width: 8),
                      _LogStatBox('CELLS', '$totalSolved', Cyber.amber),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$completionRate%',
                            style: Cyber.display(
                              24,
                              color: completed > 0 ? Cyber.lime : Cyber.muted,
                            ),
                          ),
                          const Text(
                            'CLEAR RATE',
                            style: TextStyle(
                              color: Cyber.muted,
                              fontFamily: 'Orbitron',
                              fontSize: 9,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: ClipRRect(
                  child: SizedBox(
                    height: 4,
                    child: Row(
                      children: [
                        if (completed > 0)
                          Expanded(
                            flex: completed,
                            child: Container(color: Cyber.lime),
                          ),
                        if (items.length - completed > 0)
                          Expanded(
                            flex: items.length - completed,
                            child: Container(color: Cyber.cyan),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 14),
                  child: Text(
                    'No bingo logs yet.',
                    style: TextStyle(color: Cyber.muted, fontSize: 12),
                  ),
                ),
              Expanded(
                child: items.isEmpty
                    ? const SizedBox.shrink()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final dayKey = items[index];
                          final progress = state.archive.progressByDay[dayKey]!;
                          return _BingoLogTile(
                            dayKey: dayKey,
                            progress: progress,
                            puzzle: footballBingoPuzzleFor(progress.puzzleId),
                            onTap: () => onOpenDay(dayKey),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogStatBox extends StatelessWidget {
  const _LogStatBox(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xff111827),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: Cyber.display(15, color: color)),
          const SizedBox(height: 2),
          Text(label, style: Cyber.label(7, color: Cyber.muted)),
        ],
      ),
    );
  }
}

class _BingoLogTile extends StatelessWidget {
  const _BingoLogTile({
    required this.dayKey,
    required this.progress,
    required this.puzzle,
    required this.onTap,
  });

  final String dayKey;
  final FootballBingoProgress progress;
  final FootballBingoPuzzle puzzle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = progress.completed;
    final accent = done ? Cyber.lime : Cyber.cyan;
    return FixtureCardFrame(
      onTap: onTap,
      tag: FixtureTagText(text: done ? 'DONE' : 'VIEW', color: accent),
      bodyPadding: const EdgeInsets.fromLTRB(14, 30, 14, 12),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            dayKey,
            style: Cyber.label(
              9,
              color: Cyber.muted.withValues(alpha: 0.85),
              letterSpacing: 1.2,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  border: Border.all(color: accent.withValues(alpha: 0.45)),
                ),
                child: Icon(Icons.grid_view, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  puzzle.title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.display(14, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${progress.solvedCellIds.length}/9',
                style: Cyber.display(
                  16,
                  color: accent,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
        ],
      ),
      bottomStrip: FixtureCardStrip(
        topBorder: accent.withValues(alpha: 0.25),
        child: Row(
          children: [
            Icon(
              done ? Icons.verified : Icons.visibility,
              color: accent,
              size: 14,
            ),
            const SizedBox(width: 7),
            Text(
              done ? 'COMPLETED GRID' : 'ANSWER KEY',
              style: Cyber.label(9, color: accent, letterSpacing: 0.9),
            ),
            const Spacer(),
            Text(
              'DAILY LOG',
              style: Cyber.label(9, color: Cyber.muted, letterSpacing: 0.9),
            ),
          ],
        ),
      ),
    );
  }
}
