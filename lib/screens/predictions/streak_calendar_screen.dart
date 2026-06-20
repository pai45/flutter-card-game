import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/game/game_state.dart';
import '../../blocs/picks/picks_cubit.dart';
import '../../blocs/prediction/prediction_cubit.dart';
import '../../config/theme.dart';
import '../../models/match.dart';
import '../../models/picks.dart';
import '../../models/prediction.dart';
import '../../models/sport_match.dart';
import '../../models/streak.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/streak_widgets.dart';

void showStreakCalendar(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: StreakTheme.standardDuration,
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
  late DateTime _selectedDay = dateOnly(DateTime.now());
  late DateTime _visibleMonth = DateTime(_selectedDay.year, _selectedDay.month);
  _StreakPageTab _tab = _StreakPageTab.streaks;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      buildWhen: (previous, current) => previous.streak != current.streak,
      builder: (context, state) {
        final streak = state.streak;
        return Scaffold(
          backgroundColor: StreakTheme.background,
          body: Stack(
            children: [
              const Positioned.fill(
                child: CyberPlainBackground(child: SizedBox.expand()),
              ),
              SafeArea(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _StreakPageHeader(
                        onBack: () => Navigator.of(context).pop(),
                      ),
                    ),
                    SliverPadding(
                      padding: StreakTheme.heroSectionPadding,
                      sliver: SliverToBoxAdapter(
                        child: _StreakHero(streak: streak),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _StreakTabs(
                        active: _tab,
                        onSelect: (tab) => setState(() => _tab = tab),
                      ),
                    ),
                    SliverPadding(
                      padding: StreakTheme.tabContentPadding,
                      sliver: SliverToBoxAdapter(
                        child: AnimatedSwitcher(
                          duration: StreakTheme.standardDuration,
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: KeyedSubtree(
                            key: ValueKey(_tab),
                            child: _tabContent(streak),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tabContent(StreakSnapshot streak) => switch (_tab) {
    _StreakPageTab.streaks => _CategorySummary(streak: streak),
    _StreakPageTab.calendar => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeading(
          title: 'ACTIVITY CALENDAR',
          subtitle: 'Tap a day to review your activity.',
        ),
        const SizedBox(height: StreakTheme.space10),
        _CalendarPanel(
          streak: streak,
          visibleMonth: _visibleMonth,
          selectedDay: _selectedDay,
          onPrevious: () => _shiftMonth(-1),
          onNext: () => _shiftMonth(1),
          onSelect: (day) {
            playSound(SoundEffect.uiTap);
            setState(() => _selectedDay = day);
          },
        ),
        const SizedBox(height: StreakTheme.space16),
        _DayActivityPanel(
          day: _selectedDay,
          activities: streak.activitiesOn(_selectedDay),
        ),
      ],
    ),
    _StreakPageTab.milestones => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeading(
          title: 'STREAK MILESTONES',
          subtitle: 'Keep showing up to unlock bigger rewards.',
        ),
        const SizedBox(height: StreakTheme.space10),
        _MilestoneTrack(streak: streak),
      ],
    ),
  };

  void _shiftMonth(int delta) {
    playSound(SoundEffect.uiTap);
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }
}

enum _StreakPageTab { streaks, calendar, milestones }

class _StreakTabs extends StatelessWidget {
  const _StreakTabs({required this.active, required this.onSelect});

  final _StreakPageTab active;
  final ValueChanged<_StreakPageTab> onSelect;

  static const _tabs = [
    (_StreakPageTab.streaks, 'STREAKS'),
    (_StreakPageTab.calendar, 'CALENDAR'),
    (_StreakPageTab.milestones, 'MILESTONES'),
  ];

  @override
  Widget build(BuildContext context) {
    final activeIndex = _tabs.indexWhere((item) => item.$1 == active);
    return Container(
      height: StreakTheme.tabBarHeight,
      decoration: BoxDecoration(
        color: StreakTheme.tabBarBackground,
        border: Border(bottom: BorderSide(color: StreakTheme.subtleBorder)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / _tabs.length;
          return Stack(
            children: [
              Row(
                children: [
                  for (var index = 0; index < _tabs.length; index++)
                    Expanded(
                      child: GestureDetector(
                        key: ValueKey('streak_page_tab_$index'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (_tabs[index].$1 == active) return;
                          playSound(SoundEffect.uiTap);
                          onSelect(_tabs[index].$1);
                        },
                        child: AnimatedContainer(
                          duration: StreakTheme.fastDuration,
                          color: index == activeIndex
                              ? StreakTheme.primary.withValues(alpha: 0.07)
                              : Colors.transparent,
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _tabs[index].$2,
                              style: StreakTheme.label(
                                color: index == activeIndex
                                    ? StreakTheme.primary
                                    : StreakTheme.mutedText,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              AnimatedPositioned(
                duration: StreakTheme.standardDuration,
                curve: Curves.easeOutCubic,
                left:
                    tabWidth * activeIndex +
                    tabWidth * StreakTheme.tabIndicatorInsetFactor,
                bottom: 0,
                width: tabWidth * StreakTheme.tabIndicatorWidthFactor,
                height: StreakTheme.tabIndicatorHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: StreakTheme.primary,
                    boxShadow: [
                      BoxShadow(
                        color: StreakTheme.primary.withValues(
                          alpha: StreakTheme.tabIndicatorGlowAlpha,
                        ),
                        blurRadius: StreakTheme.tabIndicatorGlowBlur,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StreakPageHeader extends StatelessWidget {
  const _StreakPageHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: StreakTheme.cardPadding,
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            color: StreakTheme.primary,
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: StreakTheme.space8),
          Text('STREAKS', style: StreakTheme.title()),
        ],
      ),
    );
  }
}

class _StreakHero extends StatelessWidget {
  const _StreakHero({required this.streak});

  final StreakSnapshot streak;

  @override
  Widget build(BuildContext context) {
    final current = streak.current(StreakCategory.overall);
    final best = streak.best(StreakCategory.overall);
    final next = streak.nextMilestone;
    final todayActive = streak.activeOn(StreakCategory.overall, DateTime.now());
    final previousDays = next == null
        ? 0
        : streakMilestones
              .where((milestone) => milestone.days < next.days)
              .map((milestone) => milestone.days)
              .fold<int>(0, (value, days) => days > value ? days : value);
    final progress = next == null
        ? 1.0
        : (current - previousDays) / (next.days - previousDays);

    return StreakElevatedSurface(
      padding: StreakTheme.sectionPadding,
      borderColor: StreakTheme.primary,
      color: StreakTheme.surface,
      child: Column(
        children: [
          SizedBox(
            width: StreakTheme.heroIconSize,
            height: StreakTheme.heroIconSize,
            child: Lottie.asset(
              'assets/animations/streak_animation.json',
              repeat: !MediaQuery.disableAnimationsOf(context),
            ),
          ),
          Text('$current', style: StreakTheme.heroNumber()),
          const SizedBox(height: StreakTheme.space4),
          Text(
            current == 1 ? 'DAY ACTIVE' : 'DAYS ACTIVE',
            style: StreakTheme.label(color: StreakTheme.secondary),
          ),
          const SizedBox(height: StreakTheme.space14),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(label: 'BEST', value: '$best DAYS'),
              ),
              const SizedBox(width: StreakTheme.space8),
              Expanded(
                child: _HeroMetric(
                  label: 'TODAY',
                  value: todayActive ? 'COMPLETE' : 'PLAY NOW',
                  color: todayActive
                      ? StreakTheme.success
                      : StreakTheme.secondary,
                ),
              ),
            ],
          ),
          if (next != null) ...[
            const SizedBox(height: StreakTheme.space16),
            StreakProgressBar(value: progress),
            const SizedBox(height: StreakTheme.space8),
            Text(
              '${next.days - current} days to ${next.rewardLabel}',
              textAlign: TextAlign.center,
              style: StreakTheme.body(),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    this.color = StreakTheme.text,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: StreakTheme.cardPadding,
      decoration: BoxDecoration(
        color: StreakTheme.mutedSurface,
        border: Border.all(color: StreakTheme.subtleBorder),
      ),
      child: Column(
        children: [
          Text(label, style: StreakTheme.label()),
          const SizedBox(height: StreakTheme.space6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: StreakTheme.sectionTitle(color: color),
          ),
        ],
      ),
    );
  }
}

class _CategorySummary extends StatelessWidget {
  const _CategorySummary({required this.streak});

  final StreakSnapshot streak;

  @override
  Widget build(BuildContext context) {
    const categories = [
      StreakCategory.predict,
      StreakCategory.pick,
      StreakCategory.games,
      StreakCategory.pitchDuel,
      StreakCategory.penaltyShootout,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(
          title: 'YOUR STREAKS',
          subtitle: 'Each mode keeps its own daily run.',
        ),
        const SizedBox(height: StreakTheme.space10),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= StreakTheme.maxContentWidth;
            final width = wide
                ? (constraints.maxWidth - StreakTheme.space10) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: StreakTheme.space10,
              runSpacing: StreakTheme.space10,
              children: [
                for (final category in categories)
                  SizedBox(
                    width: width,
                    child: _CategoryCard(
                      category: category,
                      current: streak.current(category),
                      best: streak.best(category),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.current,
    required this.best,
  });

  final StreakCategory category;
  final int current;
  final int best;

  @override
  Widget build(BuildContext context) {
    final accent = _categoryAccent(category);
    return StreakElevatedSurface(
      borderColor: current > 0 ? accent : StreakTheme.inactiveCategoryBorder,
      child: Row(
        children: [
          _CategoryIcon(category: category, color: accent),
          const SizedBox(width: StreakTheme.space10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  streakCategoryLabel(category).toUpperCase(),
                  style: StreakTheme.sectionTitle(),
                ),
                const SizedBox(height: StreakTheme.space4),
                Text('Best $best days', style: StreakTheme.body()),
              ],
            ),
          ),
          if (current > 0) StreakBadge(value: current),
        ],
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({required this.category, required this.color});

  final StreakCategory category;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final asset = switch (category) {
      StreakCategory.predict => 'assets/icons/match.svg',
      StreakCategory.pick => 'assets/icons/pick.svg',
      StreakCategory.games => 'assets/icons/game.svg',
      _ => null,
    };
    if (asset != null) {
      return SvgPicture.asset(
        asset,
        width: StreakTheme.badgeIconSize,
        height: StreakTheme.badgeIconSize,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }
    return Icon(
      switch (category) {
        StreakCategory.pitchDuel => Icons.sports_soccer,
        StreakCategory.penaltyShootout => Icons.gps_fixed,
        _ => Icons.local_fire_department,
      },
      color: color,
      size: StreakTheme.badgeIconSize,
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: StreakTheme.sectionTitle()),
        const SizedBox(height: StreakTheme.space4),
        Text(subtitle, style: StreakTheme.body()),
      ],
    );
  }
}

class _CalendarPanel extends StatelessWidget {
  const _CalendarPanel({
    required this.streak,
    required this.visibleMonth,
    required this.selectedDay,
    required this.onPrevious,
    required this.onNext,
    required this.onSelect,
  });

  final StreakSnapshot streak;
  final DateTime visibleMonth;
  final DateTime selectedDay;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(visibleMonth.year, visibleMonth.month);
    final gridStart = first.subtract(Duration(days: first.weekday - 1));
    final days = [
      for (var index = 0; index < 42; index++)
        gridStart.add(Duration(days: index)),
    ];
    return StreakElevatedSurface(
      borderColor: StreakTheme.primary,
      child: Column(
        children: [
          Row(
            children: [
              Text(
                _monthLabel(visibleMonth).toUpperCase(),
                style: StreakTheme.sectionTitle(color: StreakTheme.primary),
              ),
              const Spacer(),
              IconButton(
                onPressed: onPrevious,
                color: StreakTheme.primary,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                onPressed: onNext,
                color: StreakTheme.primary,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: StreakTheme.space8),
          const _WeekdayHeader(),
          const SizedBox(height: StreakTheme.space6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: StreakTheme.space4,
              crossAxisSpacing: StreakTheme.space4,
              childAspectRatio: StreakTheme.calendarCellAspectRatio,
            ),
            itemBuilder: (context, index) {
              final day = days[index];
              return _CalendarDay(
                key: ValueKey('streak_calendar_day_${streakDayKey(day)}'),
                day: day,
                inMonth: day.month == visibleMonth.month,
                selected: _sameDay(day, selectedDay),
                today: _sameDay(day, DateTime.now()),
                active: streak.activeOn(StreakCategory.overall, day),
                activities: streak.activitiesOn(day),
                onTap: () => onSelect(day),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final label in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: StreakTheme.label(),
            ),
          ),
      ],
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.day,
    required this.inMonth,
    required this.selected,
    required this.today,
    required this.active,
    required this.activities,
    required this.onTap,
    super.key,
  });

  final DateTime day;
  final bool inMonth;
  final bool selected;
  final bool today;
  final bool active;
  final List<StreakActivity> activities;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = selected
        ? StreakTheme.selectedInk
        : inMonth
        ? StreakTheme.text
        : StreakTheme.inactiveDayText;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: StreakTheme.fastDuration,
        padding: StreakTheme.calendarCellPadding,
        decoration: BoxDecoration(
          color: selected
              ? StreakTheme.selectedDayFill
              : active
              ? StreakTheme.activeDayFill
              : StreakTheme.background,
          border: Border.all(
            color: selected
                ? StreakTheme.primary
                : today
                ? StreakTheme.todayBorder
                : StreakTheme.subtleBorder,
            width: today || selected
                ? StreakTheme.activeBorderWidth
                : StreakTheme.borderWidth,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${day.day}',
                style: StreakTheme.bodyStrong(color: textColor),
              ),
            ),
            if (activities.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Wrap(
                  spacing: StreakTheme.space2,
                  runSpacing: StreakTheme.space2,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final activity in activities.take(4))
                      StreakActivityMarker(activity: activity),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayActivityPanel extends StatelessWidget {
  const _DayActivityPanel({required this.day, required this.activities});

  final DateTime day;
  final List<StreakActivity> activities;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameBloc>().state;
    final predictions = context.watch<PredictionCubit>().state;
    final picks = context.watch<PicksCubit>().state;
    final events = _eventsForDay(
      day,
      game.matchHistory,
      predictions.predictions.values,
      predictions.fixtures,
      picks.positions.values,
    );
    return StreakElevatedSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _fullDate(day).toUpperCase(),
            style: StreakTheme.sectionTitle(color: StreakTheme.primary),
          ),
          const SizedBox(height: StreakTheme.space10),
          if (events.isEmpty && activities.isEmpty)
            Text('No streak activity recorded.', style: StreakTheme.body())
          else
            for (
              var index = 0;
              index < (events.isEmpty ? activities.length : events.length);
              index++
            ) ...[
              if (events.isEmpty)
                StreakActivityMarker(
                  activity: activities[index],
                  showLabel: true,
                )
              else
                _DayEventRow(event: events[index]),
              if (index <
                  (events.isEmpty ? activities.length : events.length) - 1)
                const SizedBox(height: StreakTheme.space10),
            ],
        ],
      ),
    );
  }
}

class _DayEventRow extends StatelessWidget {
  const _DayEventRow({required this.event});

  final _StreakDayEvent event;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: StreakTheme.space6),
          child: StreakActivityMarker(activity: event.activity),
        ),
        const SizedBox(width: StreakTheme.space10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.title, style: StreakTheme.bodyStrong()),
              const SizedBox(height: StreakTheme.space2),
              Text(event.subtitle, style: StreakTheme.body()),
            ],
          ),
        ),
      ],
    );
  }
}

class _MilestoneTrack extends StatelessWidget {
  const _MilestoneTrack({required this.streak});

  final StreakSnapshot streak;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < streakMilestones.length; index++) ...[
          Builder(
            builder: (context) {
              final milestone = streakMilestones[index];
              final claimed = streak.claimedMilestones.contains(milestone.days);
              final reached = streak.announcedMilestones.contains(
                milestone.days,
              );
              final visualState = claimed
                  ? StreakMilestoneVisualState.claimed
                  : reached
                  ? StreakMilestoneVisualState.claimable
                  : StreakMilestoneVisualState.locked;
              return StreakMilestoneCard(
                milestone: milestone,
                state: visualState,
                onClaim: reached
                    ? () => context.read<GameBloc>().add(
                        StreakMilestoneClaimed(milestone.days),
                      )
                    : null,
              );
            },
          ),
          if (index < streakMilestones.length - 1)
            const SizedBox(height: StreakTheme.space10),
        ],
      ],
    );
  }
}

Color _categoryAccent(StreakCategory category) => switch (category) {
  StreakCategory.overall => StreakTheme.primary,
  StreakCategory.predict => StreakTheme.predict,
  StreakCategory.pick => StreakTheme.pick,
  StreakCategory.games => StreakTheme.pitchDuel,
  StreakCategory.pitchDuel => StreakTheme.predict,
  StreakCategory.penaltyShootout => StreakTheme.pick,
};

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _monthLabel(DateTime date) => '${_monthName(date.month)} ${date.year}';

String _fullDate(DateTime date) =>
    '${_monthName(date.month)} ${date.day}, ${date.year}';

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

class _StreakDayEvent {
  const _StreakDayEvent({
    required this.activity,
    required this.title,
    required this.subtitle,
    required this.timestamp,
  });

  final StreakActivity activity;
  final String title;
  final String subtitle;
  final DateTime timestamp;
}

List<_StreakDayEvent> _eventsForDay(
  DateTime day,
  Iterable<MatchHistoryEntry> history,
  Iterable<UserPrediction> predictions,
  Iterable<SportMatch> fixtures,
  Iterable<PickPosition> picks,
) {
  final events = <_StreakDayEvent>[];
  for (final prediction in predictions) {
    final submittedAt = prediction.submittedAt.toLocal();
    if (!_sameDay(submittedAt, day)) continue;
    final fixture = fixtures
        .where((item) => item.id == prediction.matchId)
        .firstOrNull;
    events.add(
      _StreakDayEvent(
        activity: StreakActivity.predict,
        title: fixture == null
            ? 'Prediction submitted'
            : '${fixture.home.name} vs ${fixture.away.name}',
        subtitle: 'Prediction quiz · ${_timeLabel(submittedAt)}',
        timestamp: submittedAt,
      ),
    );
  }
  for (final pick in picks) {
    final submittedAt = pick.submittedAt.toLocal();
    if (!_sameDay(submittedAt, day)) continue;
    events.add(
      _StreakDayEvent(
        activity: StreakActivity.pick,
        title: pick.marketQuestion,
        subtitle:
            '${pick.outcomeLabel} · ${pick.stakeOz} Oz · ${_timeLabel(submittedAt)}',
        timestamp: submittedAt,
      ),
    );
  }
  for (final match in history) {
    final submittedAt = DateTime.tryParse(match.timestampIso)?.toLocal();
    if (submittedAt == null || !_sameDay(submittedAt, day)) continue;
    events.add(
      _StreakDayEvent(
        activity: match.isShootout
            ? StreakActivity.penaltyShootout
            : StreakActivity.pitchDuel,
        title: match.isShootout ? 'Penalty Shootout' : 'Pitch Duel',
        subtitle:
            '${match.resultLabel} · ${match.playerScore}-${match.opponentScore} · ${_timeLabel(submittedAt)}',
        timestamp: submittedAt,
      ),
    );
  }
  events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return events;
}

String _timeLabel(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
