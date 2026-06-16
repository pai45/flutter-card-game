import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/prediction/prediction_cubit.dart';
import '../../blocs/prediction/prediction_state.dart';
import '../../config/enums.dart';
import '../../config/theme.dart';
import '../../models/league.dart';
import '../../models/sport_match.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/landing_bottom_navigation.dart';
import '../../widgets/staggered_card_entrance.dart';
import '../../widgets/stat_oz_top_bar.dart';
import '../shop/shop_screen.dart' show CoinIcon;
import 'streak_calendar_screen.dart';
import 'picks_home_view.dart';
import 'widgets/match_prediction_card.dart';

/// A compact sports prediction hub with StatOz styling.
class PredictionHomeScreen extends StatefulWidget {
  const PredictionHomeScreen({
    required this.activeTab,
    required this.onTabChanged,
    required this.onNavigate,
    required this.onOpenMatch,
    required this.onOpenLeague,
    required this.onOpenGame,
    required this.onOpenShootout,
    super.key,
  });

  final int activeTab;
  final ValueChanged<int> onTabChanged;
  final ValueChanged<AppSection> onNavigate;
  final ValueChanged<SportMatch> onOpenMatch;
  final ValueChanged<League> onOpenLeague;
  final VoidCallback onOpenGame;
  final VoidCallback onOpenShootout;

  @override
  State<PredictionHomeScreen> createState() => _PredictionHomeScreenState();
}

class _PredictionHomeScreenState extends State<PredictionHomeScreen> {
  final Set<int> _introPlayedTabs = <int>{};

  @override
  Widget build(BuildContext context) {
    final tab = widget.activeTab;
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _PredictionBackground()),
          SafeArea(
            top: false,
            child: Column(
              children: [
                StatOzTopBar(
                  title: 'StatOz',
                  onAddCoins: () => widget.onNavigate(AppSection.shop),
                  onStreakTap: () => showStreakCalendar(context),
                ),
                _PredictionTopBar(activeIndex: tab, onTap: widget.onTabChanged),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: KeyedSubtree(
                      key: ValueKey<int>(tab),
                      child: _buildTab(tab),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: LandingBottomNavigation(
        selectedIndex: 0,
        onNavigate: widget.onNavigate,
        includeShop: false,
      ),
    );
  }

  Widget _buildTab(int tab) {
    return switch (tab) {
      0 => _MatchesTab(
        onOpenMatch: widget.onOpenMatch,
        onOpenLeague: widget.onOpenLeague,
        animateIntro: _shouldAnimateIntro(0),
        onIntroPlayed: () => _markIntroPlayed(0),
      ),
      1 => _PickTab(
        animateIntro: _shouldAnimateIntro(1),
        onIntroPlayed: () => _markIntroPlayed(1),
      ),
      _ => _GamesTab(
        onOpenGame: widget.onOpenGame,
        onOpenShootout: widget.onOpenShootout,
        animateIntro: _shouldAnimateIntro(2),
        onIntroPlayed: () => _markIntroPlayed(2),
      ),
    };
  }

  bool _shouldAnimateIntro(int tab) => !_introPlayedTabs.contains(tab);

  void _markIntroPlayed(int tab) {
    _introPlayedTabs.add(tab);
  }
}

class _PredictionBackground extends StatelessWidget {
  const _PredictionBackground();

  @override
  Widget build(BuildContext context) {
    return const CyberPlainBackground(child: SizedBox.expand());
  }
}

/// Top tab bar (PREDICT / PICK / GAMES). A calm dark strip with one raised,
/// glowing plate that GLIDES — and colour-morphs cyan → green → orange — between
/// tabs as you switch. Per the glow rule only that active plate glows; the
/// resting tabs stay colour-coded in a calm, desaturated version of their own
/// accent so the three identities read at a glance.
class _PredictionTopBar extends StatefulWidget {
  const _PredictionTopBar({required this.activeIndex, required this.onTap});

  final int activeIndex;
  final ValueChanged<int> onTap;

  @override
  State<_PredictionTopBar> createState() => _PredictionTopBarState();
}

class _PredictionTopBarState extends State<_PredictionTopBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final CurvedAnimation _curve;

  // The continuously-interpolated tab index that drives the plate's position
  // and accent as it slides between tabs. Whole values land on a tab; the
  // fractional range in between is where the colour morphs.
  late double _displayIndex = widget.activeIndex.toDouble();
  double _fromIndex = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..addListener(_onTick);
    _curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  void _onTick() {
    final target = widget.activeIndex.toDouble();
    setState(() {
      _displayIndex = _fromIndex + (target - _fromIndex) * _curve.value;
    });
  }

  @override
  void didUpdateWidget(covariant _PredictionTopBar old) {
    super.didUpdateWidget(old);
    if (old.activeIndex != widget.activeIndex) {
      _fromIndex = _displayIndex;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  /// Lerps across the per-tab accents so the plate morphs colour while it glides.
  Color _accentAt(double t) {
    final tabs = _TopBarTabData.tabs;
    final clamped = t.clamp(0.0, (tabs.length - 1).toDouble());
    final i = clamped.floor();
    if (i >= tabs.length - 1) return tabs.last.accent;
    return Color.lerp(tabs[i].accent, tabs[i + 1].accent, clamped - i)!;
  }

  @override
  Widget build(BuildContext context) {
    final plateAccent = _accentAt(_displayIndex);
    return SizedBox(
      height: _TopBarMetrics.rowHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The uniform dark tab row — every tab fills this full height.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _TopBarMetrics.fill,
                border: Border(
                  top: BorderSide(color: Colors.black.withValues(alpha: 0.16)),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tabWidth =
                    constraints.maxWidth / _TopBarTabData.tabs.length;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // The active plate — flush, the SAME height as every tab. It
                    // stands out via its bright fill + glow + chamfer, not size.
                    Positioned(
                      left: tabWidth * _displayIndex,
                      top: 0,
                      width: tabWidth,
                      height: _TopBarMetrics.rowHeight,
                      child: CustomPaint(
                        painter: _TopBarActiveTabPainter(accent: plateAccent),
                      ),
                    ),
                    // Tab content — every tab fills the row and centres its
                    // icon+label on the same baseline.
                    Positioned.fill(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < _TopBarTabData.tabs.length; i++)
                            Expanded(
                              child: _TopBarTab(
                                key: ValueKey('prediction_top_tab_$i'),
                                data: _TopBarTabData.tabs[i],
                                active: i == widget.activeIndex,
                                onTap: () {
                                  if (i == widget.activeIndex) return;
                                  playSound(SoundEffect.uiTap);
                                  HapticFeedback.selectionClick();
                                  widget.onTap(i);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBarTabData {
  const _TopBarTabData({
    required this.label,
    required this.asset,
    required this.accent,
  });

  final String label;
  final String asset;

  /// Each tab owns its identity colour: cyan / green / orange.
  final Color accent;

  static const tabs = [
    _TopBarTabData(
      label: 'PREDICT',
      asset: 'assets/icons/match.svg',
      accent: Cyber.cyan,
    ),
    _TopBarTabData(
      label: 'PICK',
      asset: 'assets/icons/pick.svg',
      accent: Cyber.lime,
    ),
    _TopBarTabData(
      label: 'GAMES',
      asset: 'assets/icons/game.svg',
      accent: Cyber.amber,
    ),
  ];
}

class _TopBarTab extends StatelessWidget {
  const _TopBarTab({
    super.key,
    required this.data,
    required this.active,
    required this.onTap,
  });

  final _TopBarTabData data;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Active: dark ink reads on the bright accent plate. Resting: a calm,
    // desaturated take on the tab's OWN accent so each tab stays colour-coded.
    final Color color = active
        ? _TopBarMetrics.activeInk
        : Color.lerp(data.accent, _TopBarMetrics.mutedInk, 0.32)!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon pops with an elastic bounce as its tab takes focus.
          AnimatedScale(
            scale: active ? 1.0 : 0.84,
            duration: const Duration(milliseconds: 380),
            curve: active ? Curves.elasticOut : Curves.easeOutCubic,
            child: SvgPicture.asset(
              data.asset,
              width: 18,
              height: 18,
              fit: BoxFit.contain,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
          ),
          const SizedBox(height: 5),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              color: color,
              fontFamily: Cyber.displayFont,
              fontSize: active ? 12 : 10,
              fontWeight: active ? FontWeight.w900 : FontWeight.w600,
              height: active ? 1.25 : 1.5,
              letterSpacing: active ? 0.5 : 0.3,
            ),
            child: Text(data.label, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

/// Paints the active tab as a FLUSH bright plate — the same height as every tab,
/// no overhang. A square-topped, chamfered-bottom trapezoid (floating with a small
/// side gap) filled with a bright vertical accent gradient, a crisp accent edge and
/// top sheen, and — as the one focal, "live" element — wrapped in a soft accent glow
/// halo so it stands out by light, not size. Accent morphs in from the bar.
class _TopBarActiveTabPainter extends CustomPainter {
  const _TopBarActiveTabPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    const sideInset = 7.0;
    const chamfer = _TopBarMetrics.chamfer;
    final bottom = size.height;
    final path = Path()
      ..moveTo(sideInset, 0)
      ..lineTo(size.width - sideInset, 0)
      ..lineTo(size.width - sideInset, bottom - chamfer)
      ..lineTo(size.width - sideInset - chamfer, bottom)
      ..lineTo(sideInset + chamfer, bottom)
      ..lineTo(sideInset, bottom - chamfer)
      ..close();

    // Focal "live" element → a scarce accent glow halo is allowed (and wanted).
    canvas.drawPath(
      path,
      Paint()
        ..color = accent.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // Bright vertical accent gradient fill.
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(accent, Colors.white, 0.30)!, accent],
        ).createShader(Offset.zero & size),
    );

    // Crisp brightened accent edge.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Color.lerp(accent, Colors.white, 0.45)!,
    );

    // Top sheen highlight.
    canvas.drawLine(
      const Offset(sideInset + 2, 1.5),
      Offset(size.width - sideInset - 2, 1.5),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _TopBarActiveTabPainter old) =>
      old.accent != accent;
}

abstract final class _TopBarMetrics {
  // Every tab — active or not — shares this height. The active plate is a flush,
  // same-height bright accent plate; it stands out via fill + glow + chamfer, not
  // by overhanging the row.
  static const rowHeight = 61.0;
  static const chamfer = 16.0; // bottom corner cut on the active plate

  static const fill = Color(0xff1a253a);
  static const activeInk = Color(0xff081019); // dark ink on the bright plate
  static const mutedInk = Color(0xff90a1b8);
}

class _MatchesTab extends StatefulWidget {
  const _MatchesTab({
    required this.onOpenMatch,
    required this.onOpenLeague,
    required this.animateIntro,
    required this.onIntroPlayed,
  });

  final ValueChanged<SportMatch> onOpenMatch;
  final ValueChanged<League> onOpenLeague;
  final bool animateIntro;
  final VoidCallback? onIntroPlayed;

  @override
  State<_MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<_MatchesTab> {
  late DateTime _selectedDay = _startOfDay(DateTime.now());
  bool _introPlayed = false;
  double _daySwipeDelta = 0;
  int _dayGeneration = 0;
  bool _slideFromLeft = true;

  bool _hasDay(List<DateTime> days, DateTime day) {
    final normalized = _startOfDay(day);
    return days.any((candidate) => _sameDay(candidate, normalized));
  }

  bool _canMoveDay(List<DateTime> days, int delta) =>
      _hasDay(days, _selectedDay.add(Duration(days: delta)));

  void _moveDay(List<DateTime> days, int delta) {
    final target = _selectedDay.add(Duration(days: delta));
    if (!_hasDay(days, target)) return;
    playSound(SoundEffect.uiTap);
    setState(() {
      _selectedDay = _startOfDay(target);
      _slideFromLeft = delta < 0;
      _dayGeneration++;
    });
  }

  void _handleDaySwipeStart(DragStartDetails details) {
    _daySwipeDelta = 0;
  }

  void _handleDaySwipeUpdate(DragUpdateDetails details) {
    _daySwipeDelta += details.primaryDelta ?? 0;
  }

  void _handleDaySwipeEnd(List<DateTime> days, DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final gestureDelta = velocity.abs() >= 180 ? velocity : _daySwipeDelta;
    _daySwipeDelta = 0;
    if (gestureDelta.abs() < 80) return;
    _moveDay(days, gestureDelta < 0 ? 1 : -1);
  }

  Future<void> _openCalendar(List<DateTime> days) async {
    final today = _startOfDay(DateTime.now());
    final firstDay = days.isEmpty ? today : days.first;
    final lastDay = days.isEmpty
        ? today.add(const Duration(days: 4))
        : days.last;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: firstDay,
      lastDate: lastDay,
      selectableDayPredicate: (day) {
        final normalized = _startOfDay(day);
        return days.any((d) => _sameDay(d, normalized));
      },
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Cyber.cyan,
              onPrimary: Color(0xff101826),
              surface: Color(0xff162235),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      _slideFromLeft = !picked.isAfter(_selectedDay);
      _selectedDay = _startOfDay(picked);
      _dayGeneration++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PredictionCubit, PredictionState>(
      builder: (context, state) {
        if (state.loading) return const _PickSkeleton();
        final days = _calendarDays(state.fixtures);
        if (!days.any((day) => _sameDay(day, _selectedDay))) {
          _selectedDay = _startOfDay(DateTime.now());
        }
        final selectedFixtures = state.fixtures
            .where((fixture) => _sameDay(fixture.kickoff, _selectedDay))
            .toList();
        final grouped = _groupByLeague(state.leagues, selectedFixtures);
        final animateIntro =
            widget.animateIntro && !_introPlayed && selectedFixtures.isNotEmpty;
        if (animateIntro) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _introPlayed = true;
            widget.onIntroPlayed?.call();
          });
        }
        final animateCards = animateIntro || _dayGeneration > 0;
        var cardEntranceIndex = 0;
        return GestureDetector(
          key: const ValueKey('match-day-swipe-area'),
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _handleDaySwipeStart,
          onHorizontalDragUpdate: _handleDaySwipeUpdate,
          onHorizontalDragEnd: (details) => _handleDaySwipeEnd(days, details),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MatchDayNavigator(
                      dayLabel: _dayHeading(_selectedDay),
                      matchCount: selectedFixtures.length,
                      canGoPrevious: _canMoveDay(days, -1),
                      canGoNext: _canMoveDay(days, 1),
                      onPrevious: () => _moveDay(days, -1),
                      onNext: () => _moveDay(days, 1),
                      onCalendar: () {
                        playSound(SoundEffect.uiTap);
                        _openCalendar(days);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (grouped.isEmpty)
                _EmptyMatchDay(day: _selectedDay)
              else
                for (final entry in grouped.entries) ...[
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      playSound(SoundEffect.uiTap);
                      widget.onOpenLeague(entry.key);
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 4),
                      child: Row(
                        children: [
                          Text(
                            entry.key.shortCode,
                            style: TextStyle(
                              color: Cyber.cyan.withValues(alpha: 0.85),
                              fontFamily: Cyber.displayFont,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'STANDINGS',
                            style: Cyber.label(
                              9,
                              color: Cyber.muted,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: entry.key.accent.withValues(alpha: 0.25),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.chevron_right,
                            color: entry.key.accent.withValues(alpha: 0.8),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  for (final match in entry.value) ...[
                    StaggeredCardEntrance(
                      key: ValueKey('day-$_dayGeneration-$cardEntranceIndex'),
                      index: cardEntranceIndex++,
                      animate: animateCards,
                      slideFromLeft: _slideFromLeft,
                      child: MatchPredictionCard(
                        match: match,
                        prediction: state.predictionFor(match.id),
                        onTap:
                            (match.predictable ||
                                state.predictionFor(match.id) != null)
                            ? () => widget.onOpenMatch(match)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
            ],
          ),
        );
      },
    );
  }
}

class _MatchDayNavigator extends StatelessWidget {
  const _MatchDayNavigator({
    required this.dayLabel,
    required this.matchCount,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
    required this.onCalendar,
  });

  final String dayLabel;
  final int matchCount;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onCalendar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MatchDayArrowButton(
            key: const ValueKey('match-day-previous-button'),
            tooltip: 'Previous match day',
            icon: Icons.chevron_left,
            enabled: canGoPrevious,
            onPressed: onPrevious,
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 200,
            child: Row(
              key: const ValueKey('match-day-heading'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    dayLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.display(15, letterSpacing: 1.5),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '($matchCount)',
                  style: Cyber.label(13, color: Cyber.muted),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const ValueKey('match-day-calendar-button'),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Pick match day',
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: onCalendar,
                  icon: const Icon(
                    Icons.calendar_today_outlined,
                    color: Cyber.muted,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _MatchDayArrowButton(
            key: const ValueKey('match-day-next-button'),
            tooltip: 'Next match day',
            icon: Icons.chevron_right,
            enabled: canGoNext,
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _MatchDayArrowButton extends StatelessWidget {
  const _MatchDayArrowButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? Cyber.cyan : Cyber.muted.withValues(alpha: 0.35);
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      padding: EdgeInsets.zero,
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, color: color, size: 22),
    );
  }
}

class _EmptyMatchDay extends StatelessWidget {
  const _EmptyMatchDay({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 360,
      child: CyberNoDataState(
        icon: Icons.event_busy_outlined,
        title: 'No games on ${_monthDayLabel(day)}',
        message: 'Pick another match day to find open predictions.',
        accent: Cyber.cyan,
        spark: Icons.calendar_today_outlined,
      ),
    );
  }
}

Map<League, List<SportMatch>> _groupByLeague(
  List<League> leagues,
  List<SportMatch> fixtures,
) {
  final grouped = <League, List<SportMatch>>{};
  for (final league in leagues) {
    final matches = fixtures.where((m) => m.leagueId == league.id).toList();
    if (matches.isNotEmpty) grouped[league] = matches;
  }
  return grouped;
}

List<DateTime> _calendarDays(List<SportMatch> fixtures) {
  final today = _startOfDay(DateTime.now());
  final daysByEpoch = <int, DateTime>{};

  for (var offset = -1; offset <= 4; offset++) {
    final day = today.add(Duration(days: offset));
    daysByEpoch[day.millisecondsSinceEpoch] = day;
  }

  for (final fixture in fixtures) {
    final day = _startOfDay(fixture.kickoff);
    daysByEpoch[day.millisecondsSinceEpoch] = day;
  }

  final days = daysByEpoch.values.toList()..sort();
  return days;
}

DateTime _startOfDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _dayHeading(DateTime day) {
  final today = _startOfDay(DateTime.now());
  if (_sameDay(day, today)) return 'TODAY';
  if (_sameDay(day, today.add(const Duration(days: 1)))) return 'TOMORROW';
  if (_sameDay(day, today.subtract(const Duration(days: 1)))) {
    return 'YESTERDAY';
  }
  return _monthDayLabel(day).toUpperCase();
}

String _monthDayLabel(DateTime day) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[day.month - 1]} ${day.day}';
}

class _PickTab extends StatelessWidget {
  const _PickTab({required this.animateIntro, required this.onIntroPlayed});

  final bool animateIntro;
  final VoidCallback? onIntroPlayed;

  @override
  Widget build(BuildContext context) =>
      PicksHomeView(animateIntro: animateIntro, onIntroPlayed: onIntroPlayed);
}

// ignore: unused_element
class _SportsTabs extends StatelessWidget {
  const _SportsTabs();

  static const tabs = ['ALL', 'IPL', 'EPL', 'NBA', 'LALIGA', 'SERIE A'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 22),
        itemBuilder: (context, index) {
          final active = index == 0;
          return Align(
            alignment: Alignment.center,
            child: Text(
              tabs[index],
              style: Cyber.label(
                10,
                color: active
                    ? Colors.white
                    : Cyber.muted.withValues(alpha: 0.8),
                letterSpacing: 0.9,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ignore: unused_element
class _MarketFilterTabs extends StatelessWidget {
  const _MarketFilterTabs();

  static const tabs = ['ALL', 'MATCHES', 'EVENT', 'FUTURES'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 31,
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            Expanded(
              child: _MarketFilterChip(label: tabs[i], active: i == 0),
            ),
            if (i != tabs.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _MarketFilterChip extends StatelessWidget {
  const _MarketFilterChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active
            ? const Color(0xff12304a)
            : const Color(0xff111827).withValues(alpha: 0.86),
        border: Border.all(
          color: active
              ? Cyber.cyan.withValues(alpha: 0.7)
              : const Color(0xff273654),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: Cyber.label(
            9,
            color: active ? Cyber.cyan : Cyber.muted.withValues(alpha: 0.72),
            letterSpacing: 0.7,
          ),
        ),
      ),
    );
  }
}

typedef _PickHandler =
    void Function({
      required String key,
      required String question,
      required String selectedPick,
      required int price,
      required Color color,
    });

// ignore: unused_element
class _MatchMarketCard extends StatelessWidget {
  const _MatchMarketCard({required this.selectedKey, required this.onPick});

  final String? selectedKey;
  final _PickHandler onPick;

  static const question = 'Punjab vs Bangalore';

  @override
  Widget build(BuildContext context) {
    return _MarketCardShell(
      height: 146,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: const [
                      _ScoreRow(
                        badge: 'PJK',
                        badgeColor: Color(0xffffefe8),
                        textColor: Color(0xfff04e3e),
                        team: 'Punjab',
                        score: '221 - 4 (20vr)',
                      ),
                      SizedBox(height: 8),
                      _ScoreRow(
                        badge: 'RCB',
                        badgeColor: Color(0xff6b5600),
                        textColor: Color(0xffffd000),
                        team: 'Bangalore',
                        score: '221 - 4',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'IPL',
                      style: Cyber.label(
                        10,
                        color: Cyber.muted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xffff2f35),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'LIVE',
                          style: Cyber.label(
                            8,
                            color: const Color(0xffff2f35),
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: _MarketPriceButton(
                  keyName: 'match-pjk',
                  label: 'PJK',
                  price: 32,
                  color: const Color(0xffdf101d),
                  selected: selectedKey == 'match-pjk',
                  onTap: () => onPick(
                    key: 'match-pjk',
                    question: question,
                    selectedPick: 'PJK',
                    price: 32,
                    color: const Color(0xffdf101d),
                  ),
                ),
              ),
              Expanded(
                child: _MarketPriceButton(
                  keyName: 'match-rcb',
                  label: 'RCB',
                  price: 68,
                  color: const Color(0xff6d5700),
                  selected: selectedKey == 'match-rcb',
                  onTap: () => onPick(
                    key: 'match-rcb',
                    question: question,
                    selectedPick: 'RCB',
                    price: 68,
                    color: const Color(0xff6d5700),
                  ),
                ),
              ),
            ],
          ),
          const _MarketMetaRow(
            values: ['Volume 2.4K Oz', '24h +8', 'Ends after match'],
          ),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.badge,
    required this.badgeColor,
    required this.textColor,
    required this.team,
    required this.score,
  });

  final String badge;
  final Color badgeColor;
  final Color textColor;
  final String team;
  final String score;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TinyBadge(label: badge, color: badgeColor, textColor: textColor),
        const SizedBox(width: 8),
        Text(team, style: Cyber.body(12, weight: FontWeight.w800, height: 1)),
        const SizedBox(width: 7),
        Text(
          score,
          style: Cyber.label(
            10,
            color: Colors.white,
            letterSpacing: 0.3,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// ignore: unused_element
class _BinaryMarketCard extends StatelessWidget {
  const _BinaryMarketCard({
    required this.badge,
    required this.badgeColor,
    required this.question,
    required this.league,
    required this.marketType,
    required this.volume,
    required this.closes,
    required this.selectedKey,
    required this.onPick,
  });

  final String badge;
  final Color badgeColor;
  final String question;
  final String league;
  final String marketType;
  final String volume;
  final String closes;
  final String? selectedKey;
  final _PickHandler onPick;

  @override
  Widget build(BuildContext context) {
    final yesKey = '$question-yes';
    final noKey = '$question-no';
    return _MarketCardShell(
      height: 118,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TinyBadge(label: badge, color: badgeColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    question,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.body(
                      13,
                      weight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  league,
                  style: Cyber.label(
                    10,
                    color: Cyber.muted,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: _MarketPriceButton(
                  keyName: yesKey,
                  label: 'YES',
                  price: 32,
                  color: const Color(0xff36b86a),
                  selected: selectedKey == yesKey,
                  onTap: () => onPick(
                    key: yesKey,
                    question: question,
                    selectedPick: 'YES',
                    price: 32,
                    color: const Color(0xff36b86a),
                  ),
                ),
              ),
              Expanded(
                child: _MarketPriceButton(
                  keyName: noKey,
                  label: 'NO',
                  price: 32,
                  color: const Color(0xffff332e),
                  selected: selectedKey == noKey,
                  onTap: () => onPick(
                    key: noKey,
                    question: question,
                    selectedPick: 'NO',
                    price: 32,
                    color: const Color(0xffff332e),
                  ),
                ),
              ),
            ],
          ),
          _MarketMetaRow(values: [marketType, volume, closes]),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _FuturesMarketCard extends StatelessWidget {
  const _FuturesMarketCard({required this.selectedKey, required this.onPick});

  final String? selectedKey;
  final _PickHandler onPick;

  static const question = 'Who will win IPL 2026?';

  @override
  Widget build(BuildContext context) {
    return _MarketCardShell(
      height: 174,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _TinyBadge(label: 'IPL', color: Color(0xff2f55b8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    question,
                    style: Cyber.body(
                      13,
                      weight: FontWeight.w700,
                      height: 1.12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _FuturesOptionRow(
              keyName: 'futures-mi',
              badge: 'MI',
              badgeColor: const Color(0xff1345a6),
              team: 'Mumbai',
              price: 60,
              strength: 0.64,
              selected: selectedKey == 'futures-mi',
              onTap: () => onPick(
                key: 'futures-mi',
                question: question,
                selectedPick: 'Mumbai',
                price: 60,
                color: const Color(0xff334fd5),
              ),
            ),
            const SizedBox(height: 10),
            _FuturesOptionRow(
              keyName: 'futures-csk',
              badge: 'CSK',
              badgeColor: const Color(0xffffd400),
              textColor: const Color(0xff17367f),
              team: 'Chennai',
              price: 60,
              strength: 0.50,
              selected: selectedKey == 'futures-csk',
              onTap: () => onPick(
                key: 'futures-csk',
                question: question,
                selectedPick: 'Chennai',
                price: 60,
                color: const Color(0xffffd400),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Text(
                  'Futures market',
                  style: Cyber.body(
                    10,
                    color: Cyber.muted.withValues(alpha: 0.7),
                  ),
                ),
                const Spacer(),
                Text(
                  '12 more options',
                  style: Cyber.body(
                    10,
                    color: Cyber.muted.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FuturesOptionRow extends StatelessWidget {
  const _FuturesOptionRow({
    required this.keyName,
    required this.badge,
    required this.badgeColor,
    required this.team,
    required this.price,
    required this.strength,
    required this.selected,
    required this.onTap,
    this.textColor = Colors.white,
  });

  final String keyName;
  final String badge;
  final Color badgeColor;
  final Color textColor;
  final String team;
  final int price;
  final double strength;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 35,
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? Cyber.cyan : Colors.transparent,
            width: selected ? 1 : 0,
          ),
          boxShadow: selected
              ? Cyber.glow(Cyber.cyan, alpha: 0.24, blur: 12, spread: -4)
              : null,
        ),
        child: Row(
          children: [
            _TinyBadge(label: badge, color: badgeColor, textColor: textColor),
            const SizedBox(width: 8),
            SizedBox(
              width: 68,
              child: Text(
                team,
                overflow: TextOverflow.ellipsis,
                style: Cyber.body(11, weight: FontWeight.w800, height: 1),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: strength.clamp(0.0, 1.0),
                  child: Container(
                    height: 2,
                    color: badgeColor == const Color(0xffffd400)
                        ? const Color(0xffffd400)
                        : const Color(0xff315df8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _PricePill(price: price),
          ],
        ),
      ),
    );
  }
}

class _MarketCardShell extends StatelessWidget {
  const _MarketCardShell({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const HudChamferClipper(bigCut: 15, smallCut: 2),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff121b30), Color(0xff0e1628)],
          ),
          border: Border.all(color: const Color(0xff243654)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                color: Cyber.cyan.withValues(alpha: 0.35),
              ),
            ),
            Positioned.fill(child: child),
          ],
        ),
      ),
    );
  }
}

class _MarketPriceButton extends StatefulWidget {
  const _MarketPriceButton({
    required this.keyName,
    required this.label,
    required this.price,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String keyName;
  final String label;
  final int price;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_MarketPriceButton> createState() => _MarketPriceButtonState();
}

class _MarketPriceButtonState extends State<_MarketPriceButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        height: 44,
        transform: Matrix4.translationValues(0, _pressed ? 1 : 0, 0),
        decoration: BoxDecoration(
          color: _pressed
              ? Color.lerp(widget.color, Colors.black, 0.18)
              : widget.color,
          border: Border.all(
            color: widget.selected ? Cyber.cyan : Colors.transparent,
            width: widget.selected ? 1.5 : 0,
          ),
          boxShadow: widget.selected
              ? Cyber.glow(Cyber.cyan, alpha: 0.4, blur: 14, spread: -3)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.label, style: Cyber.label(11, letterSpacing: 0.8)),
            const SizedBox(width: 5),
            CoinIcon(size: 15),
            const SizedBox(width: 3),
            Text(
              '${widget.price}',
              style: Cyber.label(
                13,
                letterSpacing: 0.2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 7),
            Text(
              'BUY PICK',
              style: Cyber.label(
                6,
                color: Colors.white.withValues(alpha: 0.58),
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketMetaRow extends StatelessWidget {
  const _MarketMetaRow({required this.values});

  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 23,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12),
        border: Border(
          top: BorderSide(
            color: const Color(0xff243654).withValues(alpha: 0.7),
          ),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++) ...[
            Flexible(
              fit: i == values.length - 1 ? FlexFit.tight : FlexFit.loose,
              child: Text(
                values[i],
                overflow: TextOverflow.ellipsis,
                textAlign: i == values.length - 1
                    ? TextAlign.right
                    : TextAlign.left,
                style: Cyber.body(
                  9,
                  color: Cyber.muted.withValues(alpha: 0.72),
                  weight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
            if (i != values.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7),
                child: Container(
                  width: 2,
                  height: 2,
                  color: Cyber.cyan.withValues(alpha: 0.5),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  const _TinyBadge({
    required this.label,
    required this.color,
    this.textColor = Colors.white,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: Cyber.label(8, color: textColor, letterSpacing: 0.2),
        ),
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  const _PricePill({required this.price});

  final int price;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xff334fd5),
        border: Border.all(color: Cyber.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CoinIcon(size: 15),
          const SizedBox(width: 4),
          Text(
            '$price',
            style: Cyber.label(
              12,
              letterSpacing: 0.2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickConfirmSheet extends StatefulWidget {
  const _PickConfirmSheet({
    required this.question,
    required this.selectedPick,
    required this.price,
    required this.color,
  });

  final String question;
  final String selectedPick;
  final int price;
  final Color color;

  @override
  State<_PickConfirmSheet> createState() => _PickConfirmSheetState();
}

class _PickConfirmSheetState extends State<_PickConfirmSheet> {
  late int _amount = widget.price;

  @override
  Widget build(BuildContext context) {
    final balance = context.select<GameBloc, int>((b) => b.state.coins);
    final safeBalance = balance == 0 ? 100 : balance;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottom + 12),
      child: ClipPath(
        clipper: const HudChamferClipper(bigCut: 18, smallCut: 4),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff152139), Color(0xff0b101c)],
            ),
            border: Border.all(color: Cyber.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const HudLine(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CONFIRM PICK',
                      style: Cyber.label(
                        12,
                        color: Cyber.cyan,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.question,
                      style: Cyber.body(
                        16,
                        weight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _SheetSummaryTile(
                          label: 'PICK',
                          child: Text(
                            widget.selectedPick,
                            style: Cyber.label(13, color: widget.color),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _SheetSummaryTile(
                          label: 'PRICE',
                          child: _InlineCoinValue(value: widget.price),
                        ),
                        const SizedBox(width: 8),
                        _SheetSummaryTile(
                          label: 'BALANCE',
                          child: _InlineCoinValue(value: safeBalance),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _AmountSelector(
                      value: _amount,
                      step: widget.price,
                      max: safeBalance,
                      onChanged: (value) => setState(() => _amount = value),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 50,
                child: Row(
                  children: [
                    Expanded(
                      child: _SheetAction(
                        label: 'CANCEL',
                        color: Cyber.muted,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Container(width: 1, color: const Color(0xff243654)),
                    Expanded(
                      child: _SheetAction(
                        label: 'CONFIRM PICK',
                        color: Cyber.cyan,
                        onTap: () {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xff121b30),
                              content: Text(
                                'Pick confirmed with $_amount Oz Coins',
                                style: Cyber.body(12),
                              ),
                            ),
                          );
                        },
                      ),
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

class _SheetSummaryTile extends StatelessWidget {
  const _SheetSummaryTile({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 55,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Cyber.bg.withValues(alpha: 0.62),
          border: Border.all(color: const Color(0xff243654)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Cyber.label(
                7,
                color: Cyber.muted.withValues(alpha: 0.72),
                letterSpacing: 1,
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _InlineCoinValue extends StatelessWidget {
  const _InlineCoinValue({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CoinIcon(size: 15),
        const SizedBox(width: 4),
        Text(
          _formatInt(value),
          style: Cyber.label(
            12,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _AmountSelector extends StatelessWidget {
  const _AmountSelector({
    required this.value,
    required this.step,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int step;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final canDecrease = value > step;
    final canIncrease = value + step <= max;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Cyber.bg.withValues(alpha: 0.62),
        border: Border.all(color: Cyber.border),
      ),
      child: Row(
        children: [
          _AmountButton(
            icon: Icons.remove,
            enabled: canDecrease,
            onTap: () => onChanged(value - step),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'AMOUNT',
                  style: Cyber.label(
                    7,
                    color: Cyber.muted.withValues(alpha: 0.72),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                _InlineCoinValue(value: value),
              ],
            ),
          ),
          _AmountButton(
            icon: Icons.add,
            enabled: canIncrease,
            onTap: () => onChanged(value + step),
          ),
        ],
      ),
    );
  }
}

class _AmountButton extends StatelessWidget {
  const _AmountButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: 48,
        child: Icon(
          icon,
          color: enabled ? Cyber.cyan : Cyber.muted.withValues(alpha: 0.35),
          size: 18,
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.12),
        highlightColor: color.withValues(alpha: 0.08),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Cyber.label(10, color: color, letterSpacing: 1.6),
          ),
        ),
      ),
    );
  }
}

class _PickSkeleton extends StatelessWidget {
  const _PickSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 28),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, index) => ClipPath(
        clipper: const HudChamferClipper(bigCut: 15, smallCut: 2),
        child: Container(
          height: index == 3 ? 174 : 118,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xff111827),
            border: Border.all(color: const Color(0xff243654)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 120,
                height: 10,
                color: Cyber.cyan.withValues(alpha: 0.18),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 12,
                color: Cyber.muted.withValues(alpha: 0.12),
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                height: 35,
                color: Cyber.cyan.withValues(alpha: 0.1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GamesTab extends StatefulWidget {
  const _GamesTab({
    required this.onOpenGame,
    required this.onOpenShootout,
    required this.animateIntro,
    required this.onIntroPlayed,
  });

  final VoidCallback onOpenGame;
  final VoidCallback onOpenShootout;
  final bool animateIntro;
  final VoidCallback? onIntroPlayed;

  @override
  State<_GamesTab> createState() => _GamesTabState();
}

class _GamesTabState extends State<_GamesTab> {
  bool _introPlayed = false;

  @override
  Widget build(BuildContext context) {
    final animateIntro = widget.animateIntro && !_introPlayed;
    if (animateIntro) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _introPlayed = true;
        widget.onIntroPlayed?.call();
      });
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        StaggeredCardEntrance(
          index: 0,
          animate: animateIntro,
          child: _GameTile(
            title: 'PITCH DUEL',
            subtitle: 'TACTICAL CARD GAME',
            icon: Icons.sports_soccer,
            accent: Cyber.cyan,
            featured: true,
            onTap: widget.onOpenGame,
          ),
        ),
        const SizedBox(height: 12),
        StaggeredCardEntrance(
          index: 1,
          animate: animateIntro,
          child: _GameTile(
            title: 'PENALTY SHOOTOUT',
            subtitle: 'SUDDEN-DEATH SPOT KICKS',
            icon: Icons.gps_fixed,
            accent: Cyber.lime,
            featured: true,
            onTap: widget.onOpenShootout,
          ),
        ),
        const SizedBox(height: 12),
        StaggeredCardEntrance(
          index: 2,
          animate: animateIntro,
          child: const _GameTile(
            title: 'QUIZ STREAK',
            subtitle: 'COMING SOON',
            icon: Icons.bolt,
            accent: Cyber.violet,
            locked: true,
          ),
        ),
        const SizedBox(height: 12),
        StaggeredCardEntrance(
          index: 3,
          animate: animateIntro,
          child: const _GameTile(
            title: 'ACCURACY CHALLENGE',
            subtitle: 'COMING SOON',
            icon: Icons.track_changes,
            accent: Cyber.gold,
            locked: true,
          ),
        ),
      ],
    );
  }
}

/// HUD game card — flat dark fill, [HudChamferClipper] silhouette and a painted
/// stroke that follows every cut edge (no gradient wash).
class _GameTile extends StatelessWidget {
  const _GameTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    this.onTap,
    this.locked = false,
    this.featured = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  final bool locked;
  final bool featured;

  static const _bigCut = 14.0;
  static const _smallCut = 4.0;

  @override
  Widget build(BuildContext context) {
    final borderAlpha = locked ? 0.38 : 0.82;
    final borderColor = accent.withValues(alpha: borderAlpha);

    return Opacity(
      opacity: locked ? 0.52 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: locked ? null : onTap,
        child: CustomPaint(
          painter: _HudChamferCardPainter(
            bigCut: _bigCut,
            smallCut: _smallCut,
            fillColor: Cyber.panel,
            borderColor: borderColor,
            borderGlow: !locked && featured,
          ),
          child: ClipPath(
            clipper: const HudChamferClipper(
              bigCut: _bigCut,
              smallCut: _smallCut,
            ),
            child: featured && !locked
                ? _FeaturedBody(
                    title: title,
                    subtitle: subtitle,
                    icon: icon,
                    accent: accent,
                    onTap: onTap,
                  )
                : _CompactBody(
                    title: title,
                    subtitle: subtitle,
                    icon: icon,
                    accent: accent,
                    locked: locked,
                  ),
          ),
        ),
      ),
    );
  }
}

class _CompactBody extends StatelessWidget {
  const _CompactBody({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.locked,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _GameIconBox(icon: icon, accent: accent, size: 52, iconSize: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Cyber.display(
                    17,
                    letterSpacing: 1,
                    color: locked
                        ? Colors.white.withValues(alpha: 0.45)
                        : Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Cyber.label(
                    9,
                    color: locked
                        ? Cyber.muted
                        : accent.withValues(alpha: 0.65),
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            locked ? Icons.lock_outline : Icons.chevron_right,
            color: locked ? accent.withValues(alpha: 0.55) : accent,
            size: 22,
          ),
        ],
      ),
    );
  }
}

/// Pitch Duel hero card — corner brackets, crest watermark, and a chamfered
/// "Free" footer matching the reference layout.
class _FeaturedBody extends StatelessWidget {
  const _FeaturedBody({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          right: -8,
          top: 8,
          bottom: 8,
          child: Icon(icon, size: 112, color: accent.withValues(alpha: 0.07)),
        ),
        const Positioned.fill(
          child: CustomPaint(painter: _GameCornerBracketsPainter()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _GameIconBox(
                    icon: icon,
                    accent: accent,
                    size: 52,
                    iconSize: 28,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Cyber.display(18, letterSpacing: 1.1),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: Cyber.label(
                            9,
                            color: Cyber.muted,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: accent, size: 22),
                ],
              ),
              const SizedBox(height: 14),
              _GameFreeButton(onTap: onTap),
            ],
          ),
        ),
      ],
    );
  }
}

class _GameIconBox extends StatelessWidget {
  const _GameIconBox({
    required this.icon,
    required this.accent,
    required this.size,
    required this.iconSize,
  });

  final IconData icon;
  final Color accent;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Cyber.bg.withValues(alpha: 0.55),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Icon(icon, color: accent, size: iconSize),
    );
  }
}

class _GameFreeButton extends StatelessWidget {
  const _GameFreeButton({required this.onTap});

  final VoidCallback? onTap;

  static const _fillColor = Color(0xFF0F3E4F);
  static const _borderColor = Color(0xFF087B95);
  static const _bigCut = 10.0;
  static const _smallCut = 3.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: CustomPaint(
        painter: _HudChamferCardPainter(
          bigCut: _bigCut,
          smallCut: _smallCut,
          fillColor: _fillColor,
          borderColor: _borderColor,
        ),
        child: ClipPath(
          clipper: const HudChamferClipper(
            bigCut: _bigCut,
            smallCut: _smallCut,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CoinIcon(size: 18),
                const SizedBox(width: 8),
                Text('Free', style: Cyber.display(16, letterSpacing: 0.8)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints a flat fill plus a stroke that traces the full [HudChamferClipper]
/// outline — including the diagonal cut edges.
class _HudChamferCardPainter extends CustomPainter {
  const _HudChamferCardPainter({
    required this.bigCut,
    required this.smallCut,
    required this.fillColor,
    required this.borderColor,
    this.borderGlow = false,
  });

  final double bigCut;
  final double smallCut;
  final Color fillColor;
  final Color borderColor;
  final bool borderGlow;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final path = HudChamferClipper(
      bigCut: bigCut,
      smallCut: smallCut,
    ).buildPath(size);

    canvas.drawPath(path, Paint()..color = fillColor);

    if (borderGlow) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = borderColor.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = borderColor,
    );
  }

  @override
  bool shouldRepaint(covariant _HudChamferCardPainter old) =>
      old.bigCut != bigCut ||
      old.smallCut != smallCut ||
      old.fillColor != fillColor ||
      old.borderColor != borderColor ||
      old.borderGlow != borderGlow;
}

/// Thin L-brackets in the top corners of the featured Pitch Duel card.
class _GameCornerBracketsPainter extends CustomPainter {
  const _GameCornerBracketsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const len = 14.0;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, len), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - len, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);
  }

  @override
  bool shouldRepaint(covariant _GameCornerBracketsPainter old) => false;
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
