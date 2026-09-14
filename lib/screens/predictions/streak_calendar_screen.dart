import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../widgets/cyber/cyber_underline_tabs.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import '../../widgets/streak_widgets.dart';
import 'widgets/daily_quest_panel.dart';

export 'widgets/daily_quest_panel.dart' show QuestDestination;

const _hubTransition = Duration(milliseconds: 280);

void showStreakCalendar(
  BuildContext context, {
  ValueChanged<QuestDestination>? onQuestNavigate,
}) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: _hubTransition,
      pageBuilder: (context, animation, secondaryAnimation) =>
          StreakCalendarScreen(onQuestNavigate: onQuestNavigate),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

/// The streak hub: a live STREAK CORE hero (the one focal glow), then TODAY
/// (daily quests + the road-to-365 milestone track), STREAKS (per-mode runs and
/// the shield briefing) and CALENDAR (month fuse + day dossier).
class StreakCalendarScreen extends StatefulWidget {
  const StreakCalendarScreen({this.onQuestNavigate, super.key});
  final ValueChanged<QuestDestination>? onQuestNavigate;

  @override
  State<StreakCalendarScreen> createState() => _StreakCalendarScreenState();
}

class _StreakCalendarScreenState extends State<StreakCalendarScreen> {
  late DateTime _selectedDay = dateOnly(DateTime.now());
  late DateTime _visibleMonth = DateTime(_selectedDay.year, _selectedDay.month);
  int _tab = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<GameBloc>().add(DailyQuestsRefreshed());
    });
    _scheduleRefresh();
  }

  void _scheduleRefresh() {
    final now = DateTime.now();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    _refreshTimer = Timer(nextMinute.difference(now), () {
      if (!mounted) return;
      context.read<GameBloc>().add(DailyQuestsRefreshed());
      setState(() {});
      _scheduleRefresh();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _navigateQuest(QuestDestination destination) {
    Navigator.of(context).pop();
    widget.onQuestNavigate?.call(destination);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      buildWhen: (previous, current) =>
          previous.streak != current.streak ||
          previous.dailyQuests != current.dailyQuests ||
          previous.questClaiming != current.questClaiming ||
          previous.questError != current.questError ||
          previous.loading != current.loading,
      builder: (context, state) {
        final now = DateTime.now();
        final reduced = MediaQuery.disableAnimationsOf(context);
        // No header subtitle: GameScaffold's 64px bar overflows with a
        // subtitle at text scale >= 1.3; the hero carries the telemetry line.
        return GameScaffold(
          title: 'STREAKS',
          leading: _HubBackButton(
            onTap: () => Navigator.of(context).maybePop(),
          ),
          rightSlot: Padding(
            padding: const EdgeInsets.only(left: 8, right: 4),
            child: StreakShieldPips(shields: state.streak.shields, size: 16),
          ),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                sliver: SliverToBoxAdapter(
                  child: _StreakHero(streak: state.streak, now: now),
                ),
              ),
              SliverToBoxAdapter(
                child: CyberUnderlineTabs(
                  labels: _hubTabLabels,
                  activeIndex: _tab,
                  accent: _hubTabAccents[_tab],
                  onTap: (index) {
                    HapticFeedback.selectionClick();
                    setState(() => _tab = index);
                  },
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                sliver: SliverToBoxAdapter(
                  child: AnimatedSwitcher(
                    duration: reduced ? Duration.zero : _hubTransition,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.015),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(_tab),
                      child: _tabContent(state, now),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tabContent(GameState state, DateTime now) {
    final streak = state.streak;
    return switch (_tab) {
      1 => _ModeStreaks(streak: streak, now: now),
      2 => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KeyedSubtree(
            key: const ValueKey('streak-calendar-panel'),
            child: _CalendarPanel(
              streak: streak,
              now: now,
              visibleMonth: _visibleMonth,
              selectedDay: _selectedDay,
              onPrevious: () => _shiftMonth(-1),
              onNext: () => _shiftMonth(1),
              onSelect: (day) {
                playSound(SoundEffect.uiTap);
                HapticFeedback.selectionClick();
                setState(() => _selectedDay = day);
              },
            ),
          ),
          const SizedBox(height: 14),
          _DayActivityPanel(
            day: _selectedDay,
            now: now,
            streak: streak,
            activities: streak.activitiesOn(_selectedDay),
          ),
        ],
      ),
      3 => _MilestoneRoad(streak: streak, now: now),
      _ => DailyQuestPanel(
        state: state,
        onNavigate: widget.onQuestNavigate == null ? null : _navigateQuest,
      ),
    };
  }

  void _shiftMonth(int delta) {
    playSound(SoundEffect.uiTap);
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }
}

// Same flat underline bar as the Leaderboard / sport hubs; the underline takes
// each tab's identity colour (gold quests, amber runs, cyan calendar, violet
// elite road).
const _hubTabLabels = ['TODAY', 'STREAKS', 'CALENDAR', 'MILESTONES'];
const _hubTabAccents = [Cyber.gold, Cyber.amber, Cyber.cyan, Cyber.violet];

class _HubBackButton extends StatelessWidget {
  const _HubBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          playSound(SoundEffect.uiTap);
          onTap();
        },
        child: Center(
          child: SizedBox.square(
            dimension: 36,
            child: ChamferedActionSurface(
              clipper: const HudChamferClipper(bigCut: 8, smallCut: 2),
              borderColor: Cyber.cyan.withValues(alpha: 0.35),
              child: const ColoredBox(
                color: Cyber.panel2,
                child: Icon(
                  Icons.arrow_back_ios_new,
                  size: 16,
                  color: Cyber.cyan,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StreakHero extends StatelessWidget {
  const _StreakHero({required this.streak, required this.now});

  final StreakSnapshot streak;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final flame = streakFlameState(streak, now);
    final current = streak.current(StreakCategory.overall, now: now);
    final best = streak.best(StreakCategory.overall);
    final next = streak.nextMilestone;
    final accent = flame == StreakFlameState.cold
        ? Cyber.cyan
        : streakFlameColor(flame);
    final previousDays = next == null
        ? 0
        : streakMilestones
              .where((milestone) => milestone.days < next.days)
              .fold<int>(0, (value, m) => m.days > value ? m.days : value);
    final progress = next == null
        ? 1.0
        : (current - previousDays) / (next.days - previousDays);
    final (tag, headline, body) = switch (flame) {
      StreakFlameState.live => (
        'LIVE',
        'STREAK SECURED',
        'Back tomorrow for day ${current + 1}.',
      ),
      StreakFlameState.pending => (
        'PENDING',
        'KEEP IT ALIVE',
        'Play anything to lock in day ${current + 1}.',
      ),
      StreakFlameState.atRisk => (
        'AT RISK',
        'STREAK AT RISK',
        '${questClock(questTimeLeft(now))} left'
            '${streak.shields > 0 ? ' · shield armed' : ''}.',
      ),
      StreakFlameState.cold => (
        'COLD',
        'START A NEW RUN',
        'Play anything to light day 1.',
      ),
    };
    final tabular = const [FontFeature.tabularFigures()];

    // Shields live in the header, quests on TODAY — the hero only carries the
    // run itself, its week and the next milestone.
    return CyberPanel(
      accent: accent,
      glow: flame == StreakFlameState.live || flame == StreakFlameState.atRisk,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _FlameCore(flame: flame, accent: accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                TweenAnimationBuilder<double>(
                                  tween: Tween(
                                    begin: 0,
                                    end: current.toDouble(),
                                  ),
                                  duration: reduced
                                      ? Duration.zero
                                      : const Duration(milliseconds: 700),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, value, _) => Text(
                                    '${value.round()}',
                                    style: Cyber.display(
                                      46,
                                      color: flame == StreakFlameState.cold
                                          ? Colors.white
                                          : accent,
                                      letterSpacing: 0,
                                    ).copyWith(fontFeatures: tabular),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${current == 1 ? 'DAY' : 'DAYS'} · BEST $best',
                                  style: Cyber.label(
                                    11,
                                    color: Cyber.muted,
                                    letterSpacing: 1.2,
                                    fontFeatures: tabular,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusTag(
                          label: tag,
                          color: accent,
                          pulse: flame == StreakFlameState.atRisk,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      headline,
                      style: Cyber.label(
                        11.5,
                        color: flame == StreakFlameState.cold
                            ? Colors.white
                            : accent,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(body, style: Cyber.body(12.5, color: Cyber.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          StreakWeekChain(streak: streak, now: now),
          const SizedBox(height: 14),
          if (next != null) ...[
            Row(
              children: [
                Icon(
                  streakRewardIcon(next.rewardType),
                  size: 14,
                  color: streakMilestoneAccent(next),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${next.days} DAYS · ${next.rewardLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.label(10),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${next.days - current} TO GO',
                  style: Cyber.label(
                    10,
                    color: streakMilestoneAccent(next),
                    fontFeatures: tabular,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            CyberProgressBar(
              value: progress,
              accent: streakMilestoneAccent(next),
              animate: !reduced,
            ),
          ] else
            Text(
              'EVERY MILESTONE CLEARED',
              style: Cyber.label(10, color: Cyber.gold, letterSpacing: 1.2),
            ),
        ],
      ),
    );
  }
}

class _FlameCore extends StatelessWidget {
  const _FlameCore({required this.flame, required this.accent});

  final StreakFlameState flame;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      width: 72,
      height: 80,
      child: ChamferedActionSurface(
        clipper: const HudChamferClipper(bigCut: 14, smallCut: 4),
        borderColor: accent.withValues(alpha: 0.45),
        child: ColoredBox(
          color: Color.alphaBlend(accent.withValues(alpha: 0.08), Cyber.panel2),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (flame == StreakFlameState.cold)
                const Icon(
                  Icons.local_fire_department_outlined,
                  size: 34,
                  color: Cyber.muted,
                )
              else
                SizedBox.square(
                  dimension: 60,
                  child: Lottie.asset(
                    'assets/animations/streak_animation.json',
                    repeat: !reduced,
                  ),
                ),
              if (flame == StreakFlameState.atRisk)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(Icons.warning_amber, size: 14, color: Cyber.danger),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({
    required this.label,
    required this.color,
    this.pulse = false,
  });

  final String label;
  final Color color;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    Widget tag(double t) => DecoratedBox(
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.1 + 0.14 * t),
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: BorderSide(color: color.withValues(alpha: 0.7)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 5, height: 5, color: color),
            const SizedBox(width: 5),
            Text(label, style: Cyber.label(8.5, color: color, letterSpacing: 1)),
          ],
        ),
      ),
    );
    if (!pulse || MediaQuery.disableAnimationsOf(context)) return tag(0);
    return CyberPulse(
      period: const Duration(milliseconds: 620),
      builder: (context, t) => tag(t),
    );
  }
}

// ─── MILESTONES: the road to 365 ─────────────────────────────────────────────

class _MilestoneRoad extends StatelessWidget {
  const _MilestoneRoad({required this.streak, required this.now});

  final StreakSnapshot streak;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final current = streak.current(StreakCategory.overall, now: now);
    final next = streak.nextMilestone;
    // Segment i runs from milestone i-1 to milestone i; it is drawn across the
    // previous row's bottom half and this row's top half.
    double fill(int i) {
      final previous = i == 0 ? 0 : streakMilestones[i - 1].days;
      final days = streakMilestones[i].days;
      return ((current - previous) / (days - previous)).clamp(0.0, 1.0);
    }

    final last = streakMilestones.length - 1;
    return Column(
      children: [
        for (var i = 0; i <= last; i++)
          Builder(
            builder: (context) {
              final milestone = streakMilestones[i];
              final claimed = streak.claimedMilestones.contains(milestone.days);
              return _MilestoneRow(
                milestone: milestone,
                current: current,
                topFill: i == 0 ? fill(0) : (fill(i) * 2 - 1).clamp(0.0, 1.0),
                bottomFill: i == last ? null : (fill(i + 1) * 2).clamp(0.0, 1.0),
                claimed: claimed,
                claimable:
                    !claimed &&
                    streak.announcedMilestones.contains(milestone.days),
                isNext: next?.days == milestone.days,
                onClaim: () => context.read<GameBloc>().add(
                  StreakMilestoneClaimed(milestone.days),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({
    required this.milestone,
    required this.current,
    required this.topFill,
    required this.bottomFill,
    required this.claimed,
    required this.claimable,
    required this.isNext,
    required this.onClaim,
  });

  final StreakMilestone milestone;
  final int current;
  final double topFill;
  final double? bottomFill;
  final bool claimed;
  final bool claimable;
  final bool isNext;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final tier = streakMilestoneAccent(milestone);
    final locked = !claimed && !claimable && !isNext;
    final Widget trailing;
    if (claimable) {
      trailing = _ClaimChip(accent: tier, onTap: onClaim);
    } else if (claimed) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified, size: 14, color: Cyber.success),
          const SizedBox(width: 4),
          Text('CLAIMED', style: Cyber.label(9.5, color: Cyber.success)),
        ],
      );
    } else if (isNext) {
      trailing = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${milestone.days - current}',
            style: Cyber.display(18, color: tier, letterSpacing: 0).copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text('TO GO', style: Cyber.label(8, color: Cyber.muted)),
        ],
      );
    } else {
      trailing = Icon(
        Icons.lock_outline,
        size: 16,
        color: Cyber.muted.withValues(alpha: 0.7),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: CustomPaint(
              painter: _RoadRailPainter(
                topFill: topFill,
                bottomFill: bottomFill,
                accent: Cyber.gold,
              ),
              child: Center(
                child: _MilestoneNode(
                  accent: tier,
                  claimed: claimed,
                  claimable: claimable,
                  isNext: isNext,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: ChamferedActionSurface(
                clipper: const HudChamferClipper(bigCut: 10, smallCut: 3),
                borderColor: claimable
                    ? tier.withValues(alpha: 0.8)
                    : isNext
                    ? tier.withValues(alpha: 0.45)
                    : claimed
                    ? Cyber.success.withValues(alpha: 0.4)
                    : Cyber.border,
                child: ColoredBox(
                  color: claimable
                      ? Color.alphaBlend(tier.withValues(alpha: 0.1), Cyber.panel)
                      : Cyber.panel,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${milestone.days} DAYS',
                                style: Cyber.display(
                                  14,
                                  color: locked
                                      ? Colors.white.withValues(alpha: 0.6)
                                      : tier,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Icon(
                                    streakRewardIcon(milestone.rewardType),
                                    size: 13,
                                    color: locked ? Cyber.muted : Colors.white,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      milestone.rewardLabel,
                                      style: Cyber.label(
                                        10,
                                        color: locked
                                            ? Cyber.muted
                                            : Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        trailing,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoadRailPainter extends CustomPainter {
  const _RoadRailPainter({
    required this.topFill,
    required this.bottomFill,
    required this.accent,
  });

  final double topFill;
  final double? bottomFill;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final mid = size.height / 2;
    final base = Paint()
      ..color = Cyber.line.withValues(alpha: 0.45)
      ..strokeWidth = 2;
    final lit = Paint()
      ..color = accent
      ..strokeWidth = 2;
    canvas.drawLine(Offset(x, 0), Offset(x, mid), base);
    if (topFill > 0) {
      canvas.drawLine(Offset(x, 0), Offset(x, mid * topFill), lit);
    }
    final bottom = bottomFill;
    if (bottom != null) {
      canvas.drawLine(Offset(x, mid), Offset(x, size.height), base);
      if (bottom > 0) {
        canvas.drawLine(
          Offset(x, mid),
          Offset(x, mid + (size.height - mid) * bottom),
          lit,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RoadRailPainter old) =>
      old.topFill != topFill ||
      old.bottomFill != bottomFill ||
      old.accent != accent;
}

class _MilestoneNode extends StatelessWidget {
  const _MilestoneNode({
    required this.accent,
    required this.claimed,
    required this.claimable,
    required this.isNext,
  });

  final Color accent;
  final bool claimed;
  final bool claimable;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    Widget node(double t) {
      final (Color fill, Color border, Widget glyph) = claimed
          ? (
              Cyber.success,
              Cyber.success,
              const Icon(Icons.check, size: 13, color: AppTheme.darkInk),
            )
          : claimable
          ? (
              accent,
              accent,
              const Icon(Icons.redeem, size: 13, color: AppTheme.darkInk),
            )
          : isNext
          ? (Cyber.panel, accent, Icon(Icons.flag, size: 12, color: accent))
          : (
              Cyber.bg,
              Cyber.line.withValues(alpha: 0.6),
              const Icon(Icons.lock, size: 10, color: Cyber.muted),
            );
      return SizedBox.square(
        dimension: 24,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: fill,
            shape: BeveledRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(color: border, width: isNext ? 1.5 : 1),
            ),
            // A claimable node is a live reward — the one place on the track
            // allowed to glow.
            shadows: claimable
                ? Cyber.glow(accent, alpha: 0.3 + 0.3 * t, blur: 10 + 6 * t)
                : null,
          ),
          child: Center(child: glyph),
        ),
      );
    }

    if (!claimable || MediaQuery.disableAnimationsOf(context)) return node(0.5);
    return CyberPulse(
      period: const Duration(milliseconds: 900),
      builder: (context, t) => node(t),
    );
  }
}

class _ClaimChip extends StatelessWidget {
  const _ClaimChip({required this.accent, required this.onTap});

  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Claim milestone reward',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.mediumImpact();
          playSound(SoundEffect.uiConfirm);
          onTap();
        },
        child: ClipPath(
          clipper: const HudChamferClipper(bigCut: 8, smallCut: 3),
          child: ColoredBox(
            color: accent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.redeem, size: 14, color: AppTheme.darkInk),
                  const SizedBox(width: 5),
                  Text(
                    'CLAIM',
                    style: Cyber.label(11, color: AppTheme.darkInk),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── STREAKS: per-mode runs + shield briefing ────────────────────────────────

const _modeCategories = [
  StreakCategory.predict,
  StreakCategory.pick,
  StreakCategory.games,
  StreakCategory.pitchDuel,
  StreakCategory.penaltyShootout,
];

class _ModeStreaks extends StatelessWidget {
  const _ModeStreaks({required this.streak, required this.now});

  final StreakSnapshot streak;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 520;
            final width = wide
                ? (constraints.maxWidth - 10) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final category in _modeCategories)
                  SizedBox(
                    width: width,
                    child: _ModeStreakCard(
                      category: category,
                      streak: streak,
                      now: now,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        _ShieldBriefing(shields: streak.shields),
      ],
    );
  }
}

class _ModeStreakCard extends StatelessWidget {
  const _ModeStreakCard({
    required this.category,
    required this.streak,
    required this.now,
  });

  final StreakCategory category;
  final StreakSnapshot streak;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final accent = _categoryAccent(category);
    final current = streak.current(category, now: now);
    final best = streak.best(category);
    final live = current > 0;
    return CyberPanel(
      accent: live ? accent : Cyber.line,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox.square(
                dimension: 34,
                child: ColoredBox(
                  color: Color.alphaBlend(
                    accent.withValues(alpha: live ? 0.14 : 0.05),
                    Cyber.panel2,
                  ),
                  child: Center(
                    child: _CategoryIcon(
                      category: category,
                      color: live ? accent : Cyber.muted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      streakCategoryLabel(category).toUpperCase(),
                      style: Cyber.display(13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'BEST $best',
                      style: Cyber.label(
                        9,
                        color: Cyber.muted,
                        letterSpacing: 0.8,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$current',
                style: Cyber.display(
                  24,
                  color: live ? accent : Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 0,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          // Only a live run earns its week chain; cold modes stay one row.
          if (live) ...[
            const SizedBox(height: 12),
            StreakWeekChain(
              streak: streak,
              now: now,
              category: category,
              accent: accent,
              compact: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _ShieldBriefing extends StatelessWidget {
  const _ShieldBriefing({required this.shields});

  final int shields;

  @override
  Widget build(BuildContext context) {
    return CyberHudPanel(
      title: 'Streak shields',
      code: '$shields/$streakShieldCap',
      child: Row(
        children: [
          StreakShieldPips(shields: shields, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Clear the Daily Sweep to forge one. Each covers a missed day.',
              style: Cyber.body(
                12.5,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── CALENDAR: month fuse + day dossier ──────────────────────────────────────

class _CalendarPanel extends StatelessWidget {
  const _CalendarPanel({
    required this.streak,
    required this.now,
    required this.visibleMonth,
    required this.selectedDay,
    required this.onPrevious,
    required this.onNext,
    required this.onSelect,
  });

  final StreakSnapshot streak;
  final DateTime now;
  final DateTime visibleMonth;
  final DateTime selectedDay;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(visibleMonth.year, visibleMonth.month);
    final gridStart = DateTime(
      first.year,
      first.month,
      first.day - (first.weekday - 1),
    );
    final days = [
      for (var index = 0; index < 42; index++)
        DateTime(gridStart.year, gridStart.month, gridStart.day + index),
    ];
    bool active(DateTime day) => streak.activeOn(StreakCategory.overall, day);
    bool inChain(DateTime day) => active(day) || streak.shieldedOn(day);
    final monthDays = days.where((day) => day.month == visibleMonth.month);
    final activeCount = monthDays.where(active).length;
    final shieldedCount = monthDays.where(streak.shieldedOn).length;

    return CyberPanel(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      child: Column(
        children: [
          Row(
            children: [
              _MonthArrow(
                icon: Icons.chevron_left,
                label: 'Previous month',
                onTap: onPrevious,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      _monthLabel(visibleMonth).toUpperCase(),
                      textAlign: TextAlign.center,
                      style: Cyber.display(14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shieldedCount > 0
                          ? '$activeCount ACTIVE · $shieldedCount SHIELDED'
                          : '$activeCount ACTIVE DAYS',
                      textAlign: TextAlign.center,
                      style: Cyber.label(
                        8.5,
                        color: Cyber.muted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              _MonthArrow(
                icon: Icons.chevron_right,
                label: 'Next month',
                onTap: onNext,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _WeekdayHeader(),
          const SizedBox(height: 6),
          for (var week = 0; week < 6; week++)
            Row(
              children: [
                for (var weekday = 0; weekday < 7; weekday++)
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Builder(
                        builder: (context) {
                          final index = week * 7 + weekday;
                          final day = days[index];
                          return _CalendarDay(
                            key: ValueKey(
                              'streak_calendar_day_${streakDayKey(day)}',
                            ),
                            day: day,
                            inMonth: day.month == visibleMonth.month,
                            selected: _sameDay(day, selectedDay),
                            today: _sameDay(day, now),
                            active: active(day),
                            shielded: streak.shieldedOn(day),
                            chainLeft:
                                weekday > 0 &&
                                inChain(day) &&
                                inChain(days[index - 1]),
                            chainRight:
                                weekday < 6 &&
                                inChain(day) &&
                                inChain(days[index + 1]),
                            activities: streak.activitiesOn(day),
                            onTap: () => onSelect(day),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MonthArrow extends StatelessWidget {
  const _MonthArrow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: 36,
          child: ChamferedActionSurface(
            clipper: const HudChamferClipper(bigCut: 8, smallCut: 2),
            borderColor: Cyber.cyan.withValues(alpha: 0.35),
            child: ColoredBox(
              color: Cyber.panel2,
              child: Icon(icon, color: Cyber.cyan, size: 20),
            ),
          ),
        ),
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
              style: Cyber.label(9, color: Cyber.muted),
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
    required this.shielded,
    required this.chainLeft,
    required this.chainRight,
    required this.activities,
    required this.onTap,
    super.key,
  });

  final DateTime day;
  final bool inMonth;
  final bool selected;
  final bool today;
  final bool active;
  final bool shielded;
  final bool chainLeft;
  final bool chainRight;
  final List<StreakActivity> activities;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fuse = Cyber.gold.withValues(alpha: 0.45);
    final fill = selected
        ? Cyber.gold
        : active
        ? Color.alphaBlend(Cyber.gold.withValues(alpha: 0.2), Cyber.panel2)
        : shielded
        ? Color.alphaBlend(Cyber.cyan.withValues(alpha: 0.14), Cyber.panel2)
        : inMonth
        ? Cyber.bg.withValues(alpha: 0.55)
        : Colors.transparent;
    final border = selected
        ? Cyber.gold
        : today
        ? Cyber.amber
        : active
        ? Cyber.gold.withValues(alpha: 0.45)
        : shielded
        ? Cyber.cyan.withValues(alpha: 0.5)
        : inMonth
        ? Cyber.border.withValues(alpha: 0.6)
        : Cyber.line.withValues(alpha: 0.15);
    final textColor = selected
        ? AppTheme.darkInk
        : inMonth
        ? Colors.white
        : Cyber.muted.withValues(alpha: 0.45);
    return Semantics(
      button: true,
      selected: selected,
      label: _fullDate(day),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The fuse: consecutive chain days in a week row join up.
            Center(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 3,
                      color: chainLeft ? fuse : Colors.transparent,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 3,
                      color: chainRight ? fuse : Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: ShapeDecoration(
                  color: fill,
                  shape: BeveledRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                    side: BorderSide(
                      color: border,
                      width: selected || today ? 1.5 : 1,
                    ),
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${day.day}',
                            style: Cyber.label(
                              11.5,
                              color: textColor,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (active || shielded)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Icon(
                          active ? Icons.local_fire_department : Icons.shield,
                          size: 9,
                          color: selected
                              ? AppTheme.darkInk
                              : active
                              ? Cyber.gold
                              : Cyber.cyan,
                        ),
                      ),
                    if (activities.isNotEmpty)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 3,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final activity in activities.take(3))
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 1.5,
                                ),
                                child: StreakActivityMarker(
                                  activity: activity,
                                  size: 3.5,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayActivityPanel extends StatelessWidget {
  const _DayActivityPanel({
    required this.day,
    required this.now,
    required this.streak,
    required this.activities,
  });

  final DateTime day;
  final DateTime now;
  final StreakSnapshot streak;
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
    final rows = events.isNotEmpty
        ? events
        : [
            for (final activity in activities)
              _StreakDayEvent(
                activity: activity,
                title: streakActivityLabel(activity),
                subtitle: 'Streak activity',
                timestamp: day,
              ),
          ];
    final today = dateOnly(now);
    final selected = dateOnly(day);
    final active = streak.activeOn(StreakCategory.overall, day);
    final shielded = streak.shieldedOn(day);
    final (status, color) = active
        ? ('ACTIVE', Cyber.gold)
        : shielded
        ? ('SHIELDED', Cyber.cyan)
        : selected == today
        ? ('TODAY', Cyber.amber)
        : selected.isAfter(today)
        ? ('UPCOMING', Cyber.muted)
        : ('NO ACTIVITY', Cyber.muted);

    return CyberPanel(
      accent: active
          ? Cyber.gold
          : shielded
          ? Cyber.cyan
          : Cyber.line,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _fullDate(day).toUpperCase(),
                  style: Cyber.display(13, color: Cyber.gold),
                ),
              ),
              const SizedBox(width: 8),
              _StatusTag(label: status, color: color),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Row(
              children: [
                Icon(
                  shielded ? Icons.shield_outlined : Icons.nights_stay_outlined,
                  size: 18,
                  color: Cyber.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    shielded
                        ? 'A shield kept your streak alive on this day.'
                        : selected.isAfter(today)
                        ? 'This day hasn’t happened yet.'
                        : 'No streak activity recorded.',
                    style: Cyber.body(13, color: Cyber.muted),
                  ),
                ),
              ],
            )
          else
            for (var index = 0; index < rows.length; index++) ...[
              if (index > 0) const SizedBox(height: 10),
              _DayEventRow(event: rows[index]),
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
    final color = streakActivityColor(event.activity);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox.square(
          dimension: 30,
          child: ColoredBox(
            color: Color.alphaBlend(color.withValues(alpha: 0.14), Cyber.panel2),
            child: Icon(streakActivityIcon(event.activity), size: 16, color: color),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Cyber.body(13, weight: FontWeight.w800, height: 1.3),
              ),
              const SizedBox(height: 2),
              Text(event.subtitle, style: Cyber.body(12, color: Cyber.muted)),
            ],
          ),
        ),
      ],
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
        width: 18,
        height: 18,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }
    return Icon(
      switch (category) {
        StreakCategory.pitchDuel => Icons.style,
        StreakCategory.penaltyShootout => Icons.sports_soccer,
        _ => Icons.local_fire_department,
      },
      color: color,
      size: 18,
    );
  }
}

Color _categoryAccent(StreakCategory category) => switch (category) {
  StreakCategory.overall => Cyber.gold,
  StreakCategory.predict => Cyber.cyan,
  StreakCategory.pick => Cyber.lime,
  StreakCategory.games => Cyber.amber,
  StreakCategory.pitchDuel => Cyber.amber,
  StreakCategory.penaltyShootout => Cyber.violet,
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
