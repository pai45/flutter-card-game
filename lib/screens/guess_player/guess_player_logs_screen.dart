import 'package:flutter/material.dart';

import '../../blocs/guess_player/guess_player_cubit.dart';
import '../../config/theme.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../utils/sound_effects.dart';

class GuessPlayerLogsScreen extends StatelessWidget {
  const GuessPlayerLogsScreen({
    required this.state,
    required this.onBack,
    required this.onOpenDay,
    super.key,
  });

  final GuessPlayerState state;
  final VoidCallback onBack;
  final ValueChanged<String> onOpenDay;

  @override
  Widget build(BuildContext context) {
    final items = state.unlockedDayKeys.reversed.toList();
    final completed = items
        .where((dayKey) => state.archive.resultsByDay[dayKey]?.won ?? false)
        .length;
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
                    Container(width: 3, height: 22, color: Cyber.magenta),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'MYSTERY LOGS',
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
                      onPressed: () {
                        playSound(SoundEffect.uiTap);
                        onBack();
                      },
                      icon: const Icon(Icons.close, color: Cyber.magenta),
                    ),
                  ],
                ),
              ),
              if (items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Row(
                    children: [
                      _LogStatBox('GUESSED', '$completed', Cyber.success),
                      const SizedBox(width: 8),
                      _LogStatBox('PLAYED', '${items.length}', Cyber.cyan),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$completionRate%',
                            style: Cyber.display(
                              24,
                              color: completed > 0
                                  ? Cyber.success
                                  : Cyber.muted,
                            ),
                          ),
                          const Text(
                            'WIN RATE',
                            style: TextStyle(
                              color: Cyber.muted,
                              fontFamily: 'Orbitron',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final dayKey = items[index];
                    final result = state.archive.resultsByDay[dayKey];
                    final isToday = dayKey == state.todayKey;

                    return _LogItem(
                      dayKey: dayKey,
                      isToday: isToday,
                      won: result?.won,
                      playerName: result?.targetPlayerName,
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
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xff0a0d18),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Cyber.borderSubtle),
      ),
      child: Column(
        children: [
          Text(value, style: Cyber.display(18, color: color)),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Cyber.muted,
              fontFamily: 'Orbitron',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogItem extends StatelessWidget {
  const _LogItem({
    required this.dayKey,
    required this.isToday,
    required this.won,
    required this.playerName,
    required this.onTap,
  });

  final String dayKey;
  final bool isToday;
  final bool? won; // null means played but not finished, or just not played
  final String? playerName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = won == true
        ? Cyber.success
        : (won == false ? Cyber.danger : Cyber.muted);
    final icon = won == true
        ? Icons.check_circle
        : (won == false ? Icons.cancel : Icons.hourglass_empty);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          playSound(SoundEffect.uiTap);
          onTap();
        },
        borderRadius: BorderRadius.zero,
        splashColor: Cyber.magenta.withValues(alpha: 0.1),
        highlightColor: Cyber.magenta.withValues(alpha: 0.05),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xff0a0d18),
            borderRadius: BorderRadius.zero,
            border: Border.all(color: Cyber.borderSubtle),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: statusColor, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          dayKey,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Orbitron',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                        if (isToday) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Cyber.magenta.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.zero,
                              border: Border.all(
                                color: Cyber.magenta.withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Text(
                              'TODAY',
                              style: TextStyle(
                                color: Cyber.magenta,
                                fontFamily: 'Orbitron',
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      playerName != null && won != null
                          ? playerName!.toUpperCase()
                          : 'MYSTERY PLAYER',
                      style: TextStyle(
                        color: playerName != null && won != null
                            ? Colors.white
                            : Cyber.muted,
                        fontFamily: 'Onest',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
