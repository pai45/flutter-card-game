import 'package:flutter/material.dart';

import '../../blocs/guess_player/guess_player_cubit.dart';
import '../../config/theme.dart';
import '../../models/guess_player.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';

class GuessPlayerLogsScreen extends StatelessWidget {
  const GuessPlayerLogsScreen({
    required this.state,
    required this.onBack,
    required this.onOpenDay,
    super.key,
  });

  final GuessPlayerState state;
  final VoidCallback onBack;
  final Future<bool> Function(String dayKey) onOpenDay;

  @override
  Widget build(BuildContext context) {
    final currentDate =
        DateTime.tryParse(state.currentDayKey) ?? DateTime.now();
    final days = [
      for (var index = 0; index < GuessPlayerCubit.archiveWindowDays; index++)
        guessPlayerDayKey(currentDate.subtract(Duration(days: index))),
    ];
    final records = days
        .map((day) => state.archive.resultsByDay[day])
        .whereType<GuessPlayerDayRecord>()
        .where(
          (record) =>
              record.status != GuessPlayerResultStatus.inProgress &&
              record.status != GuessPlayerResultStatus.expired,
        )
        .toList();
    final solved = records.where((record) => record.effectiveWon).length;
    final rate = records.isEmpty ? 0.0 : solved / records.length;

    return GameScaffold(
      title: '30-DAY INTEL ARCHIVE',
      subtitle: '${state.archive.solvedCount} ALL-TIME SOLVES',
      leading: IconButton(
        tooltip: 'Back to mystery home',
        onPressed: () {
          playSound(SoundEffect.uiTap);
          onBack();
        },
        icon: const Icon(Icons.arrow_back, color: Cyber.cyan),
      ),
      rightSlot: const Icon(
        Icons.storage_rounded,
        color: Cyber.magenta,
        size: 21,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: CyberPanel(
                accent: Cyber.magenta,
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _ArchiveMetric(
                          label: 'SOLVED',
                          value: '$solved',
                          accent: Cyber.success,
                        ),
                        const _MetricDivider(),
                        _ArchiveMetric(
                          label: 'PLAYED',
                          value: '${records.length}',
                          accent: Cyber.cyan,
                        ),
                        const _MetricDivider(),
                        _ArchiveMetric(
                          label: 'WIN RATE',
                          value: '${(rate * 100).round()}%',
                          accent: Cyber.gold,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    CyberProgressBar(
                      value: rate,
                      accent: rate > 0 ? Cyber.success : Cyber.muted,
                      height: 7,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 700 ? 4 : 2;
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    childAspectRatio: columns == 2 ? 1.28 : 1.15,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: days.length,
                  itemBuilder: (context, index) {
                    final dayKey = days[index];
                    return _ArchiveCard(
                      dayKey: dayKey,
                      isToday: dayKey == state.currentDayKey,
                      record: state.archive.resultsByDay[dayKey],
                      onTap: () async {
                        playSound(SoundEffect.uiTap);
                        await onOpenDay(dayKey);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchiveMetric extends StatelessWidget {
  const _ArchiveMetric({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Cyber.display(17, color: accent).copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 3),
          Text(label, style: Cyber.label(8, color: Cyber.muted)),
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 32,
    color: Cyber.borderSubtle,
  );
}

class _ArchiveCard extends StatelessWidget {
  const _ArchiveCard({
    required this.dayKey,
    required this.isToday,
    required this.record,
    required this.onTap,
  });

  final String dayKey;
  final bool isToday;
  final GuessPlayerDayRecord? record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _statusFor(record, isToday);
    final tappable =
        isToday ||
        (record != null &&
            record!.status != GuessPlayerResultStatus.expired &&
            record!.status != GuessPlayerResultStatus.inProgress);
    final accent = switch (status) {
      _ArchiveStatus.solved => Cyber.success,
      _ArchiveStatus.failed => Cyber.danger,
      _ArchiveStatus.live => Cyber.magenta,
      _ArchiveStatus.missed => Cyber.muted,
    };
    final icon = switch (status) {
      _ArchiveStatus.solved => Icons.check_circle_rounded,
      _ArchiveStatus.failed => Icons.cancel_rounded,
      _ArchiveStatus.live => Icons.radar_rounded,
      _ArchiveStatus.missed => Icons.lock_clock_rounded,
    };
    final label = switch (status) {
      _ArchiveStatus.solved => 'SOLVED',
      _ArchiveStatus.failed => 'MISSED',
      _ArchiveStatus.live => isToday ? 'TODAY · LIVE' : 'IN PROGRESS',
      _ArchiveStatus.missed => 'NO SIGNAL',
    };

    return Semantics(
      button: tappable,
      label: '${_formatDate(dayKey)}, $label',
      child: InkWell(
        onTap: tappable ? onTap : null,
        child: CyberPanel(
          accent: isToday ? Cyber.magenta : Cyber.border,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(11),
                  color: Color.alphaBlend(
                    accent.withValues(alpha: status == _ArchiveStatus.missed
                        ? 0.02
                        : 0.07),
                    Cyber.panel,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, color: accent, size: 18),
                          const Spacer(),
                          if (isToday)
                            Text(
                              'TODAY',
                              style: Cyber.label(7.5, color: Cyber.magenta),
                            ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Text(
                        _formatDate(dayKey),
                        style: Cyber.display(
                          12.5,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        label,
                        style: Cyber.label(8, color: accent),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                constraints: const BoxConstraints(minHeight: 30),
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 7,
                ),
                color: Cyber.bg2,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _detail(record, status),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Cyber.label(7.5, color: Cyber.muted),
                      ),
                    ),
                    if (tappable)
                      Icon(
                        Icons.chevron_right,
                        color: accent,
                        size: 15,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ArchiveStatus { solved, failed, live, missed }

_ArchiveStatus _statusFor(GuessPlayerDayRecord? record, bool isToday) {
  if (record == null) return isToday ? _ArchiveStatus.live : _ArchiveStatus.missed;
  if (record.effectiveWon) return _ArchiveStatus.solved;
  return switch (record.status) {
    GuessPlayerResultStatus.inProgress => isToday
        ? _ArchiveStatus.live
        : _ArchiveStatus.missed,
    GuessPlayerResultStatus.lost ||
    GuessPlayerResultStatus.gaveUp ||
    GuessPlayerResultStatus.legacy => _ArchiveStatus.failed,
    GuessPlayerResultStatus.expired => _ArchiveStatus.missed,
    GuessPlayerResultStatus.won => _ArchiveStatus.solved,
  };
}

String _detail(
  GuessPlayerDayRecord? record,
  _ArchiveStatus status,
) {
  if (record == null || status == _ArchiveStatus.missed) return 'PAST DAYS LOCKED';
  if (record.legacy) return 'LEGACY LOG';
  if (status == _ArchiveStatus.live) {
    return record.startedAtEpochMs == 0
        ? 'PLAY MYSTERY'
        : '${record.attemptsRemaining} TRIES LEFT';
  }
  return '${record.score} PTS · +${record.xpEarned} XP';
}

String _formatDate(String key) {
  final date = DateTime.tryParse(key);
  if (date == null) return key;
  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  return '${months[date.month - 1]} ${date.day}';
}
