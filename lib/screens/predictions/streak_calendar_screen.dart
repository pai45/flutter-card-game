import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/prediction/prediction_cubit.dart';
import '../../blocs/prediction/prediction_state.dart';
import '../../config/theme.dart';
import '../../models/match.dart';
import '../../models/prediction.dart';
import '../../models/sport_match.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../match_history/match_history_pages.dart';
import '../shop/shop_screen.dart' show CoinIcon;
import 'match_prediction_screen.dart';

void showStreakCalendar(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const StreakCalendarScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class StreakCalendarScreen extends StatefulWidget {
  const StreakCalendarScreen({super.key});

  @override
  State<StreakCalendarScreen> createState() => _StreakCalendarScreenState();
}

class _StreakCalendarScreenState extends State<StreakCalendarScreen> {
  _StreakTab _tab = _StreakTab.matches;
  late DateTime _selectedDay;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _selectedDay = _initialSelectedDay(context);
    _visibleMonth = DateTime(_selectedDay.year, _selectedDay.month);
  }

  @override
  Widget build(BuildContext context) {
    final history = context.select<GameBloc, List<MatchHistoryEntry>>(
      (bloc) => bloc.state.matchHistory,
    );
    final predictionState = context.watch<PredictionCubit>().state;
    final picks = _buildPickEvents(predictionState);
    final matchDays = _groupMatchesByDay(history);
    final pickDays = _groupPicksByDay(picks);
    final selectedMatches = matchDays[_dayKey(_selectedDay)] ?? const [];
    final selectedPicks = pickDays[_dayKey(_selectedDay)] ?? const [];
    final selectedCount = selectedMatches.length + selectedPicks.length;

    return Scaffold(
      backgroundColor: Cyber.bg,
      body: Stack(
        children: [
          const Positioned.fill(
            child: CyberPlainBackground(child: SizedBox.expand()),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StreakHero(
                  streak: _currentWinStreak(history),
                  onBack: () => Navigator.pop(context),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                  child: _CalendarHeader(
                    month: _visibleMonth,
                    onPrevious: () => _shiftMonth(-1),
                    onNext: () => _shiftMonth(1),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: _MonthGrid(
                    visibleMonth: _visibleMonth,
                    selectedDay: _selectedDay,
                    matchDays: matchDays.keys.toSet(),
                    pickDays: pickDays.keys.toSet(),
                    onSelect: (day) {
                      playSound(SoundEffect.uiTap);
                      setState(() {
                        _selectedDay = day;
                        _visibleMonth = DateTime(day.year, day.month);
                      });
                    },
                  ),
                ),
                const SizedBox(height: 14),
                _StreakTabs(
                  active: _tab,
                  matchCount: selectedMatches.length,
                  pickCount: selectedPicks.length,
                  onSelect: (tab) {
                    playSound(SoundEffect.uiTap);
                    setState(() => _tab = tab);
                  },
                ),
                Expanded(
                  child: _tab == _StreakTab.matches
                      ? _MatchEventsList(
                          day: _selectedDay,
                          events: selectedMatches,
                          selectedCount: selectedCount,
                        )
                      : _PickEventsList(
                          day: _selectedDay,
                          events: selectedPicks,
                          selectedCount: selectedCount,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _shiftMonth(int delta) {
    playSound(SoundEffect.uiTap);
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }
}

class _StreakHero extends StatelessWidget {
  const _StreakHero({required this.streak, required this.onBack});

  final int streak;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 188,
      child: Stack(
        children: [
          Positioned(
            left: 2,
            top: 4,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 104,
                  height: 104,
                  child: Lottie.asset(
                    'assets/animations/streak_animation.json',
                    fit: BoxFit.contain,
                    repeat: true,
                    frameRate: FrameRate.max,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatInt(streak),
                  style: const TextStyle(
                    color: Color(0xffffea00),
                    fontFamily: Cyber.displayFont,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    height: 0.95,
                    letterSpacing: 0,
                    fontFeatures: [FontFeature.tabularFigures()],
                    shadows: [
                      Shadow(color: Color(0x99000000), offset: Offset(0, 3)),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  streak == 1 ? 'Day' : 'Days',
                  style: Cyber.label(
                    10,
                    color: const Color(0xffffea00),
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          _monthName(month.month).toUpperCase(),
          style: Cyber.display(20, letterSpacing: 0),
        ),
        const Spacer(),
        _MonthButton(icon: Icons.chevron_left, onTap: onPrevious),
        const SizedBox(width: 6),
        _MonthButton(icon: Icons.chevron_right, onTap: onNext),
      ],
    );
  }
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 32,
        height: 28,
        child: Icon(icon, color: Cyber.cyan, size: 22),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.visibleMonth,
    required this.selectedDay,
    required this.matchDays,
    required this.pickDays,
    required this.onSelect,
  });

  final DateTime visibleMonth;
  final DateTime selectedDay;
  final Set<DateTime> matchDays;
  final Set<DateTime> pickDays;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(visibleMonth.year, visibleMonth.month);
    final gridStart = first.subtract(Duration(days: first.weekday - 1));
    final days = [
      for (var i = 0; i < 42; i++) gridStart.add(Duration(days: i)),
    ];

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: days.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (context, index) {
            final day = days[index];
            final key = _dayKey(day);
            return _DayCell(
              day: day,
              inMonth: day.month == visibleMonth.month,
              selected: _sameDay(day, selectedDay),
              hasMatches: matchDays.contains(key),
              hasPicks: pickDays.contains(key),
              onTap: () => onSelect(day),
            );
          },
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.selected,
    required this.hasMatches,
    required this.hasPicks,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool selected;
  final bool hasMatches;
  final bool hasPicks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasEvents = hasMatches || hasPicks;
    final fill = selected
        ? const Color(0xff69e4ff)
        : hasMatches && hasPicks
        ? const Color(0xff166b6d)
        : hasPicks
        ? const Color(0xff114d38)
        : hasMatches
        ? const Color(0xff145c73)
        : Colors.transparent;
    final textColor = selected
        ? Colors.black
        : inMonth
        ? Colors.white
        : Cyber.muted.withValues(alpha: 0.55);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill.withValues(alpha: inMonth || selected ? 1 : 0.42),
          border: Border.all(
            color: selected
                ? const Color(0xffa6f2ff)
                : hasEvents
                ? Cyber.cyan.withValues(alpha: 0.18)
                : Cyber.line.withValues(alpha: 0.1),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                color: textColor,
                fontFamily: Cyber.bodyFont,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                height: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (hasMatches && hasPicks && !selected)
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Cyber.lime,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StreakTabs extends StatelessWidget {
  const _StreakTabs({
    required this.active,
    required this.matchCount,
    required this.pickCount,
    required this.onSelect,
  });

  final _StreakTab active;
  final int matchCount;
  final int pickCount;
  final ValueChanged<_StreakTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xff0e1320),
        border: Border(
          top: BorderSide(color: Cyber.line.withValues(alpha: 0.4)),
          bottom: BorderSide(color: Cyber.line.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: [
          _StreakTabButton(
            tab: _StreakTab.matches,
            active: active == _StreakTab.matches,
            count: matchCount,
            onTap: () => onSelect(_StreakTab.matches),
          ),
          _StreakTabButton(
            tab: _StreakTab.picks,
            active: active == _StreakTab.picks,
            count: pickCount,
            onTap: () => onSelect(_StreakTab.picks),
          ),
        ],
      ),
    );
  }
}

class _StreakTabButton extends StatelessWidget {
  const _StreakTabButton({
    required this.tab,
    required this.active,
    required this.count,
    required this.onTap,
  });

  final _StreakTab tab;
  final bool active;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = tab == _StreakTab.matches ? Cyber.violet : Cyber.lime;
    final ink = active ? color : color.withValues(alpha: 0.34);
    final asset = tab == _StreakTab.matches
        ? 'assets/icons/match.svg'
        : 'assets/icons/pick.svg';
    final label = tab == _StreakTab.matches ? 'MY MATCHES' : 'MY PICKS';

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                asset,
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(ink, BlendMode.srcIn),
              ),
              const SizedBox(width: 8),
              Text(
                '$label ${count > 0 ? count : ''}'.trim(),
                style: Cyber.label(12, color: ink, letterSpacing: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchEventsList extends StatelessWidget {
  const _MatchEventsList({
    required this.day,
    required this.events,
    required this.selectedCount,
  });

  final DateTime day;
  final List<MatchHistoryEntry> events;
  final int selectedCount;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return _EmptyDay(
        day: day,
        selectedCount: selectedCount,
        message: 'No matches played on this day.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      itemCount: events.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final entry = events[index];
        return _StreakMatchCard(
          entry: entry,
          onTap: () => showMatchHistoryDetail(context, entry),
        );
      },
    );
  }
}

class _PickEventsList extends StatelessWidget {
  const _PickEventsList({
    required this.day,
    required this.events,
    required this.selectedCount,
  });

  final DateTime day;
  final List<_PickEvent> events;
  final int selectedCount;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return _EmptyDay(
        day: day,
        selectedCount: selectedCount,
        message: 'No picks submitted on this day.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      itemCount: events.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final event = events[index];
        return _StreakPickCard(
          event: event,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MatchPredictionScreen(match: event.match),
            ),
          ),
        );
      },
    );
  }
}

class _StreakMatchCard extends StatelessWidget {
  const _StreakMatchCard({required this.entry, required this.onTap});

  final MatchHistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = switch (entry.resultLabel) {
      'Victory' => Cyber.success,
      'Defeat' => Cyber.danger,
      _ => Cyber.amber,
    };
    final stripLabel = switch (entry.resultLabel) {
      'Victory' => 'WON',
      'Defeat' => 'LOST',
      _ => 'DRAW',
    };
    final stamp = _parseLocal(entry.timestampIso);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xff11192c),
          border: Border.all(color: const Color(0xff243654)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        _compactDate(stamp),
                        style: Cyber.body(10, color: Cyber.muted),
                      ),
                      const Spacer(),
                      Text(
                        _timeLabel(stamp),
                        style: Cyber.body(10, color: Cyber.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.deckName.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Cyber.body(
                            13,
                            weight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      _ScorePair(entry: entry),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _MiniStat(
                        label: 'ROUNDS',
                        value: '${entry.rounds.length}',
                      ),
                      const SizedBox(width: 18),
                      if (entry.xpEarned != null)
                        _MiniStat(
                          label: 'XP',
                          value: entry.xpEarned! >= 0
                              ? '+${entry.xpEarned}'
                              : '${entry.xpEarned}',
                        ),
                      const Spacer(),
                      const Icon(
                        Icons.open_in_full,
                        color: Cyber.cyan,
                        size: 15,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              height: 34,
              alignment: Alignment.center,
              color: accent.withValues(alpha: 0.28),
              child: Text(
                stripLabel,
                style: Cyber.label(10, color: accent, letterSpacing: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakPickCard extends StatelessWidget {
  const _StreakPickCard({required this.event, required this.onTap});

  final _PickEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = switch (event.prediction.status) {
      PredictionStatus.settled when event.prediction.rewardEarned > 0 => (
        label: 'WON',
        color: Cyber.lime,
      ),
      PredictionStatus.settled => (label: 'LOST', color: Cyber.danger),
      PredictionStatus.locked => (label: 'LOCKED', color: Cyber.gold),
      PredictionStatus.open => (label: 'PENDING', color: Cyber.cyan),
    };

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xff11192c),
          border: Border.all(color: const Color(0xff243654)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        _predictionTimestampLabel(event.prediction.submittedAt),
                        style: Cyber.body(10, color: Cyber.muted),
                      ),
                      const Spacer(),
                      Text(
                        event.leagueLabel,
                        style: Cyber.body(10, color: Cyber.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _TeamLine(
                    team: event.match.home,
                    score: event.match.homeScore,
                  ),
                  const SizedBox(height: 8),
                  _TeamLine(
                    team: event.match.away,
                    score: event.match.awayScore,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _MiniStat(
                        label: 'PICKS',
                        value: '${event.prediction.answers.length}',
                      ),
                      const SizedBox(width: 18),
                      if (event.prediction.status == PredictionStatus.settled)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CoinIcon(size: 14),
                            const SizedBox(width: 5),
                            Text(
                              '${event.prediction.rewardEarned}',
                              style: Cyber.display(
                                13,
                                color: event.prediction.rewardEarned > 0
                                    ? Cyber.lime
                                    : Cyber.danger,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        )
                      else
                        _MiniStat(
                          label: 'KICKOFF',
                          value: _kickoffScheduleLabel(event.match.kickoff),
                        ),
                      const Spacer(),
                      const Icon(
                        Icons.open_in_full,
                        color: Cyber.cyan,
                        size: 15,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              height: 34,
              alignment: Alignment.center,
              color: status.color.withValues(alpha: 0.24),
              child: Text(
                status.label,
                style: Cyber.label(10, color: status.color, letterSpacing: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamLine extends StatelessWidget {
  const _TeamLine({required this.team, required this.score});

  final SportTeam team;
  final String? score;

  @override
  Widget build(BuildContext context) {
    final light = team.color.computeLuminance() > 0.55;
    return Row(
      children: [
        Container(
          width: 28,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: team.color),
          child: Text(
            team.shortName,
            style: TextStyle(
              color: light ? const Color(0xff111827) : Colors.white,
              fontFamily: Cyber.displayFont,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            team.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Cyber.body(13, weight: FontWeight.w800),
          ),
        ),
        if (score != null)
          Text(
            score!,
            style: Cyber.body(12, color: Cyber.muted, weight: FontWeight.w700),
          ),
      ],
    );
  }
}

class _ScorePair extends StatelessWidget {
  const _ScorePair({required this.entry});

  final MatchHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${entry.playerScore}',
          style: Cyber.display(18, color: Cyber.cyan),
        ),
        Text(
          ' - ',
          style: Cyber.display(14, color: Cyber.muted, letterSpacing: 0),
        ),
        Text(
          '${entry.opponentScore}',
          style: Cyber.display(18, color: Cyber.danger),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1),
        ),
        const SizedBox(height: 4),
        Text(value, style: Cyber.body(11, weight: FontWeight.w800)),
      ],
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({
    required this.day,
    required this.selectedCount,
    required this.message,
  });

  final DateTime day;
  final int selectedCount;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xff11192c),
          border: Border.all(color: const Color(0xff243654)),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_busy, color: Cyber.cyan, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selectedCount == 0
                    ? '${_fullDate(day)} has no recorded events.'
                    : message,
                style: Cyber.body(13, color: Cyber.muted, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _StreakTab { matches, picks }

class _PickEvent {
  const _PickEvent({
    required this.match,
    required this.prediction,
    required this.leagueLabel,
  });

  final SportMatch match;
  final UserPrediction prediction;
  final String leagueLabel;
}

DateTime _initialSelectedDay(BuildContext context) {
  final history = context.read<GameBloc>().state.matchHistory;
  if (history.isNotEmpty) {
    final stamp = _parseLocal(history.first.timestampIso);
    if (stamp != null) return _dayKey(stamp);
  }
  final predictions = context.read<PredictionCubit>().state.predictions.values;
  if (predictions.isNotEmpty) {
    final latest = predictions.toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return _dayKey(latest.first.submittedAt.toLocal());
  }
  return _dayKey(DateTime.now());
}

int _currentWinStreak(List<MatchHistoryEntry> history) {
  var streak = 0;
  for (final match in history) {
    if (match.resultLabel == 'Victory') {
      streak++;
      continue;
    }
    break;
  }
  return streak;
}

List<_PickEvent> _buildPickEvents(PredictionState state) {
  final events = <_PickEvent>[];
  for (final prediction in state.predictions.values) {
    final match = state.fixtures
        .where((fixture) => fixture.id == prediction.matchId)
        .firstOrNull;
    if (match == null) continue;
    final league = state.leagueFor(match.leagueId);
    events.add(
      _PickEvent(
        match: match,
        prediction: prediction,
        leagueLabel: league?.shortCode ?? match.leagueId.toUpperCase(),
      ),
    );
  }
  events.sort(
    (a, b) => b.prediction.submittedAt.compareTo(a.prediction.submittedAt),
  );
  return events;
}

Map<DateTime, List<MatchHistoryEntry>> _groupMatchesByDay(
  List<MatchHistoryEntry> history,
) {
  final grouped = <DateTime, List<MatchHistoryEntry>>{};
  for (final entry in history) {
    final stamp = _parseLocal(entry.timestampIso);
    if (stamp == null) continue;
    grouped.putIfAbsent(_dayKey(stamp), () => []).add(entry);
  }
  return grouped;
}

Map<DateTime, List<_PickEvent>> _groupPicksByDay(List<_PickEvent> picks) {
  final grouped = <DateTime, List<_PickEvent>>{};
  for (final event in picks) {
    grouped
        .putIfAbsent(_dayKey(event.prediction.submittedAt.toLocal()), () => [])
        .add(event);
  }
  return grouped;
}

DateTime? _parseLocal(String timestampIso) =>
    DateTime.tryParse(timestampIso)?.toLocal();

DateTime _dayKey(DateTime date) => DateTime(date.year, date.month, date.day);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _monthName(int month) => switch (month) {
  1 => 'January',
  2 => 'February',
  3 => 'March',
  4 => 'April',
  5 => 'May',
  6 => 'June',
  7 => 'July',
  8 => 'August',
  9 => 'September',
  10 => 'October',
  11 => 'November',
  _ => 'December',
};

String _compactDate(DateTime? date) {
  if (date == null) return 'Unknown date';
  return '${date.day}, ${_monthName(date.month).substring(0, 3).toUpperCase()}';
}

String _fullDate(DateTime date) =>
    '${_monthName(date.month)} ${date.day}, ${date.year}';

String _timeLabel(DateTime? date) {
  if (date == null) return 'Unknown time';
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _predictionTimestampLabel(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute, ${local.day} ${_shortMonth(local.month).toUpperCase()}';
}

String _kickoffScheduleLabel(DateTime kickoff) {
  final local = kickoff.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  final day = local.day;
  return '$hour:$minute, $day${_daySuffix(day)} ${_shortMonth(local.month)}';
}

String _shortMonth(int month) => _monthName(month).substring(0, 3);

String _daySuffix(int day) {
  if (day >= 11 && day <= 13) return 'th';
  return switch (day % 10) {
    1 => 'st',
    2 => 'nd',
    3 => 'rd',
    _ => 'th',
  };
}

String _formatInt(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final fromEnd = raw.length - i;
    buffer.write(raw[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}
