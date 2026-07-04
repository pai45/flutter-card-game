import 'package:flutter/material.dart';

import '../../blocs/guess_player/guess_player_cubit.dart';
import '../../config/theme.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../shop/widgets/shop_card.dart';

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
                            child: Container(color: Cyber.success),
                          ),
                        if (items.length - completed > 0)
                          Expanded(
                            flex: items.length - completed,
                            child: Container(color: Cyber.magenta),
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
                    'No mystery logs yet.',
                    style: TextStyle(color: Cyber.muted, fontSize: 12),
                  ),
                ),
              Expanded(
                child: items.isEmpty
                    ? const SizedBox.shrink()
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 1.15,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final dayKey = items[index];
                          final result = state.archive.resultsByDay[dayKey];
                          final isToday = dayKey == state.todayKey;

                          return _LogItem(
                            dayKey: dayKey,
                            isToday: isToday,
                            won: result?.won,
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
    required this.onTap,
  });

  final String dayKey;
  final bool isToday;
  final bool? won; // null means played but not finished, or just not played
  final VoidCallback onTap;

  String _formatDate(String key) {
    final date = DateTime.tryParse(key);
    if (date == null) return key;
    final months = [
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final accent = won == true
        ? Cyber.success
        : (won == false ? Cyber.danger : Cyber.magenta);
    final icon = won == true
        ? Icons.check_circle
        : (won == false ? Icons.cancel : Icons.hourglass_empty);
    final status = won == true ? 'GUESSED' : (won == false ? 'MISSED' : 'OPEN');
    final action = won == null ? 'PLAY MYSTERY' : 'CHECK ANSWER';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        playSound(SoundEffect.uiTap);
        onTap();
      },
      child: ShopCardFrame(
        accent: accent,
        elevated: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color.lerp(Cyber.panel, accent, 0.045),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: accent, size: 18),
                        const Spacer(),
                        Text(
                          isToday ? 'TODAY' : (won == null ? 'OPEN' : 'DONE'),
                          style: Cyber.label(8.5, color: accent),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _formatDate(dayKey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.display(14, color: Colors.white),
                    ),
                    const Spacer(),
                    Text(
                      status,
                      style: Cyber.label(
                        8.5,
                        color: Cyber.muted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              height: 32,
              color: Colors.black.withValues(alpha: 0.88),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                action,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Cyber.label(9, color: accent, letterSpacing: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
