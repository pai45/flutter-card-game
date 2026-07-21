import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/prediction/prediction_cubit.dart';
import '../../blocs/prediction/prediction_state.dart';
import '../../config/enums.dart';
import '../../config/sport_modules.dart';
import '../../config/theme.dart';
import '../../models/league.dart';
import '../../models/prediction.dart';
import '../../models/sport_match.dart';
import '../../models/streak.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_underline_tabs.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/cyber/sport_signal_painters.dart';
import '../../widgets/landing_bottom_navigation.dart';
import '../../widgets/staggered_card_entrance.dart';
import '../../widgets/stat_oz_top_bar.dart';
import '../../widgets/streak_widgets.dart';
import '../profile/widgets/profile_card.dart';
import 'streak_calendar_screen.dart';
import 'widgets/history_hud.dart';
import 'widgets/match_prediction_card.dart';

/// A compact sports prediction hub with StatOz styling.
class PredictionHomeScreen extends StatefulWidget {
  const PredictionHomeScreen({
    required this.activeTab,
    required this.onTabChanged,
    required this.activeMatchSportTab,
    required this.onMatchSportTabChanged,
    required this.activeGamesSportTab,
    required this.onGamesSportTabChanged,
    required this.onNavigate,
    required this.onOpenMatch,
    required this.onOpenLeague,
    required this.onOpenGame,
    required this.onOpenShootout,
    required this.onOpenQuiz,
    required this.onOpenFootballBingo,
    required this.onOpenFootballChess,
    required this.onOpenGuessPlayer,
    required this.onOpenBasketballGuessPlayer,
    required this.onOpenCricketGuessPlayer,
    required this.onOpenGrandPrix,
    required this.onOpenF1GuessDriver,
    required this.onOpenTennisGuessWinner,
    required this.onOpenBasketball,
    this.onOpenFinalOver,
    this.onOpenTennisRally,
    this.onAddCoins,
    super.key,
  });

  final int activeTab;
  final ValueChanged<int> onTabChanged;
  final int activeMatchSportTab;
  final ValueChanged<int> onMatchSportTabChanged;
  final int activeGamesSportTab;
  final ValueChanged<int> onGamesSportTabChanged;
  final ValueChanged<AppSection> onNavigate;
  final ValueChanged<SportMatch> onOpenMatch;
  final ValueChanged<League> onOpenLeague;
  final VoidCallback onOpenGame;
  final VoidCallback onOpenShootout;
  final ValueChanged<Sport> onOpenQuiz;
  final VoidCallback onOpenFootballBingo;
  final VoidCallback onOpenFootballChess;
  final VoidCallback onOpenGuessPlayer;
  final VoidCallback onOpenBasketballGuessPlayer;
  final VoidCallback onOpenCricketGuessPlayer;
  final VoidCallback onOpenGrandPrix;
  final VoidCallback onOpenF1GuessDriver;
  final VoidCallback onOpenTennisGuessWinner;
  final VoidCallback onOpenBasketball;
  final VoidCallback? onOpenFinalOver;
  final VoidCallback? onOpenTennisRally;
  final VoidCallback? onAddCoins;

  @override
  State<PredictionHomeScreen> createState() => _PredictionHomeScreenState();
}

class _PredictionHomeScreenState extends State<PredictionHomeScreen> {
  final Set<int> _introPlayedTabs = <int>{};

  Sport get _selectedMatchSport =>
      _predictionSports[widget.activeMatchSportTab];
  Sport get _selectedGamesSport =>
      _predictionSports[widget.activeGamesSportTab];

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
                  onAddCoins:
                      widget.onAddCoins ??
                      () => widget.onNavigate(AppSection.shop),
                  onStreakTap: () => showStreakCalendar(context),
                ),
                CyberGlidingTabs(
                  tabs: _predictionTopTabs,
                  activeIndex: tab,
                  onTap: widget.onTabChanged,
                ),
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
        selectedSport: _selectedMatchSport,
        activeSportTab: widget.activeMatchSportTab,
        onSportTabChanged: widget.onMatchSportTabChanged,
        onOpenMatch: widget.onOpenMatch,
        onOpenLeague: widget.onOpenLeague,
        onOpenGame: widget.onOpenGame,
        onOpenShootout: widget.onOpenShootout,
        animateIntro: _shouldAnimateIntro(0),
        onIntroPlayed: () => _markIntroPlayed(0),
      ),
      _ => _GamesTab(
        selectedSport: _selectedGamesSport,
        activeSportTab: widget.activeGamesSportTab,
        onSportTabChanged: widget.onGamesSportTabChanged,
        onOpenGame: widget.onOpenGame,
        onOpenShootout: widget.onOpenShootout,
        onOpenQuiz: widget.onOpenQuiz,
        onOpenFootballBingo: widget.onOpenFootballBingo,
        onOpenFootballChess: widget.onOpenFootballChess,
        onOpenFinalOver: widget.onOpenFinalOver ?? () {},
        onOpenGuessPlayer: widget.onOpenGuessPlayer,
        onOpenBasketballGuessPlayer: widget.onOpenBasketballGuessPlayer,
        onOpenCricketGuessPlayer: widget.onOpenCricketGuessPlayer,
        onOpenGrandPrix: widget.onOpenGrandPrix,
        onOpenF1GuessDriver: widget.onOpenF1GuessDriver,
        onOpenTennisGuessWinner: widget.onOpenTennisGuessWinner,
        onOpenBasketball: widget.onOpenBasketball,
        onOpenTennisRally: widget.onOpenTennisRally ?? () {},
        animateIntro: _shouldAnimateIntro(1),
        onIntroPlayed: () => _markIntroPlayed(1),
      ),
    };
  }

  bool _shouldAnimateIntro(int tab) => !_introPlayedTabs.contains(tab);

  void _markIntroPlayed(int tab) {
    _introPlayedTabs.add(tab);
  }
}

const _predictionSports = <Sport>[
  Sport.football,
  Sport.cricket,
  Sport.basketball,
  Sport.tennis,
  Sport.motorsport,
];

final _predictionSportLabels = _predictionSports
    .map((sport) => sportModuleFor(sport).label.toUpperCase())
    .toList(growable: false);

final _predictionSportIcons = _predictionSports
    .map((sport) => sportModuleFor(sport).icon)
    .toList(growable: false);

class _PredictionSportsTabs extends StatelessWidget {
  const _PredictionSportsTabs({
    required this.activeIndex,
    required this.selectedSport,
    required this.onTap,
  });

  final int activeIndex;
  final Sport selectedSport;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return CyberUnderlineTabs(
      labels: _predictionSportLabels,
      icons: _predictionSportIcons,
      activeIndex: activeIndex,
      accent: sportModuleFor(selectedSport).accent,
      onTap: onTap,
    );
  }
}

class _PredictionBackground extends StatelessWidget {
  const _PredictionBackground();

  @override
  Widget build(BuildContext context) {
    return const CyberPlainBackground(child: SizedBox.expand());
  }
}

/// The match-hub tabs (PREDICT / PICK / GAMES). Each owns its identity colour —
/// cyan / green / orange — which the gliding active plate morphs between.
final List<CyberGlidingTab> _predictionTopTabs = <CyberGlidingTab>[
  CyberGlidingTab(
    label: 'MATCH',
    accent: Cyber.cyan,
    icon: (color) => SvgPicture.asset(
      'assets/icons/match.svg',
      width: 18,
      height: 18,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    ),
  ),
  CyberGlidingTab(
    label: 'GAMES',
    accent: Cyber.amber,
    icon: (color) => SvgPicture.asset(
      'assets/icons/game.svg',
      width: 18,
      height: 18,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    ),
  ),
];

class _MatchesTab extends StatefulWidget {
  const _MatchesTab({
    required this.selectedSport,
    required this.activeSportTab,
    required this.onSportTabChanged,
    required this.onOpenMatch,
    required this.onOpenLeague,
    required this.onOpenGame,
    required this.onOpenShootout,
    required this.animateIntro,
    required this.onIntroPlayed,
  });

  final Sport selectedSport;
  final int activeSportTab;
  final ValueChanged<int> onSportTabChanged;
  final ValueChanged<SportMatch> onOpenMatch;
  final ValueChanged<League> onOpenLeague;
  final VoidCallback onOpenGame;
  final VoidCallback onOpenShootout;
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
  bool _showNewGamesCallout = false;
  bool _hasAutoSelectedDay = false;

  @override
  void initState() {
    super.initState();
    context.read<PredictionCubit>().loadSport(widget.selectedSport);
  }

  @override
  void didUpdateWidget(covariant _MatchesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSport != widget.selectedSport) {
      context.read<PredictionCubit>().loadSport(widget.selectedSport);
      _selectedDay = _startOfDay(DateTime.now());
      _slideFromLeft = true;
      _dayGeneration++;
      _hasAutoSelectedDay = false;
    }
  }

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
              onPrimary: AppTheme.calendarOnPrimary,
              surface: AppTheme.calendarSurface,
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
    return Column(
      children: [
        _PredictionSportsTabs(
          activeIndex: widget.activeSportTab,
          selectedSport: widget.selectedSport,
          onTap: widget.onSportTabChanged,
        ),
        Expanded(
          child: BlocBuilder<PredictionCubit, PredictionState>(
            builder: (context, state) {
              if (state.loading ||
                  state.loadingSports.contains(widget.selectedSport)) {
                return const Center(
                  child: CircularProgressIndicator(color: Cyber.cyan),
                );
              }
              final validLeagueIds = state.leagues.map((l) => l.id).toSet();
              final allSportFixtures = state.fixtures
                  .where(
                    (fixture) =>
                        fixture.sport == widget.selectedSport &&
                        validLeagueIds.contains(fixture.leagueId),
                  )
                  .toList();
              // Motorsport (F1, IndyCar, NASCAR) browses day-to-day like every
              // other sport — races from different series on the same day
              // group under separate league headers via _groupByLeague below,
              // the same way concurrent football competitions already do.
              final sportFixtures = allSportFixtures;
              final days = _calendarDays(sportFixtures);
              final today = _startOfDay(DateTime.now());

              if (!_hasAutoSelectedDay && sportFixtures.isNotEmpty) {
                _hasAutoSelectedDay = true;
                final todayHasMatches = sportFixtures.any(
                  (f) => _sameDay(f.kickoff, today),
                );
                if (!todayHasMatches) {
                  DateTime? closestDay;
                  int minDiff = 999999;
                  for (final f in sportFixtures) {
                    final d = _startOfDay(f.kickoff);
                    final diff = (d.difference(today).inDays).abs();
                    if (diff < minDiff) {
                      minDiff = diff;
                      closestDay = d;
                    } else if (diff == minDiff && closestDay != null) {
                      if (d.isBefore(closestDay)) {
                        closestDay = d;
                      }
                    }
                  }
                  if (closestDay != null) {
                    _selectedDay = closestDay;
                    _slideFromLeft = closestDay.isBefore(today);
                  }
                }
              }

              if (!days.any((day) => _sameDay(day, _selectedDay)) &&
                  !_sameDay(_selectedDay, today)) {
                _selectedDay = days.any((day) => _sameDay(day, today))
                    ? today
                    : (days.isNotEmpty ? days.first : today);
              }
              final selectedFixtures = sportFixtures
                  .where((fixture) => _sameDay(fixture.kickoff, _selectedDay))
                  .toList();
              final upcomingDays = days
                  .where((d) => !d.isBefore(_selectedDay))
                  .toList();
              final groupedByDay = <DateTime, Map<League, List<SportMatch>>>{};
              for (final day in upcomingDays) {
                final dayFixtures = sportFixtures
                    .where((fixture) => _sameDay(fixture.kickoff, day))
                    .toList();
                if (dayFixtures.isNotEmpty) {
                  final grouped = _groupByLeague(state.leagues, dayFixtures);
                  if (grouped.isNotEmpty) {
                    groupedByDay[day] = grouped;
                  }
                }
              }
              final animateIntro =
                  widget.animateIntro &&
                  !_introPlayed &&
                  groupedByDay.isNotEmpty;
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
                onHorizontalDragEnd: (details) =>
                    _handleDaySwipeEnd(days, details),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: [
                    if (_showNewGamesCallout) ...[
                      _NewGamesReleaseCard(
                        key: const ValueKey('new-games-release-card'),
                        onTap: _openNewGamesRelease,
                        onClose: () {
                          setState(() {
                            _showNewGamesCallout = false;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
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
                    if (groupedByDay.isEmpty)
                      _EmptyMatchDay(day: _selectedDay)
                    else
                      for (final dayEntry in groupedByDay.entries) ...[
                        if (!_sameDay(dayEntry.key, _selectedDay))
                          _DayDividerRow(day: dayEntry.key),
                        for (final entry in dayEntry.value.entries) ...[
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
                                    style:
                                        Cyber.display(
                                          18,
                                          color: Cyber.cyan.withValues(
                                            alpha: 0.85,
                                          ),
                                          letterSpacing: 2,
                                        ).copyWith(
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: entry.key.accent.withValues(
                                        alpha: 0.25,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'ALL GAMES',
                                    style: Cyber.label(
                                      9,
                                      color: Cyber.muted,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          for (final match in entry.value) ...[
                            StaggeredCardEntrance(
                              key: ValueKey(
                                'day-$_dayGeneration-$cardEntranceIndex',
                              ),
                              index: cardEntranceIndex++,
                              animate: animateCards,
                              slideFromLeft: _slideFromLeft,
                              child: MatchPredictionCard(
                                match: match,
                                prediction: state.predictionSummaryForMatch(
                                  match.id,
                                ),
                                quiz:
                                    state.quizzes[predictionStorageKey(
                                      match.id,
                                      state
                                              .predictionSummaryForMatch(
                                                match.id,
                                              )
                                              ?.quizId ??
                                          kDefaultPredictionQuizId,
                                    )],
                                onTap: () => widget.onOpenMatch(match),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openNewGamesRelease() {
    playSound(SoundEffect.uiTap);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _NewGamesReleaseScreen(
          onOpenGame: widget.onOpenGame,
          onOpenShootout: widget.onOpenShootout,
        ),
      ),
    );
  }
}

class _NewGamesReleaseCard extends StatelessWidget {
  const _NewGamesReleaseCard({required this.onTap, this.onClose, super.key});

  final VoidCallback onTap;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Brand new games',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ProfileCard(
          borderColor: Cyber.cyan.withValues(alpha: 0.46),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Cyber.cyan.withValues(alpha: 0.1),
                      border: Border.all(
                        color: Cyber.cyan.withValues(alpha: 0.46),
                      ),
                    ),
                    child: const Icon(
                      Icons.sports_soccer,
                      color: Cyber.cyan,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'BRAND NEW GAMES',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.display(17, letterSpacing: 1.1),
                    ),
                  ),
                  if (onClose != null)
                    GestureDetector(
                      onTap: onClose,
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.close, color: Cyber.muted, size: 20),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Two new ways to play are live: tactical card battles in Pitch Duel and high-pressure spot kicks in Penalty Shootout.',
                style: Cyber.body(12, color: Cyber.muted, height: 1.35),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  _ReleaseMiniChip(label: 'PITCH DUEL', accent: Cyber.cyan),
                  const SizedBox(width: 12),
                  const _ReleaseMiniDivider(),
                  const SizedBox(width: 12),
                  _ReleaseMiniChip(
                    label: 'PENALTY SHOOTOUT',
                    accent: Cyber.lime,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReleaseMiniChip extends StatelessWidget {
  const _ReleaseMiniChip({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        maxLines: 1,
        style: Cyber.label(13, color: accent, letterSpacing: 1),
      ),
    );
  }
}

class _ReleaseMiniDivider extends StatelessWidget {
  const _ReleaseMiniDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 16,
      color: Cyber.border.withValues(alpha: 0.72),
    );
  }
}

class _NewGamesReleaseScreen extends StatelessWidget {
  const _NewGamesReleaseScreen({
    required this.onOpenGame,
    required this.onOpenShootout,
  });

  final VoidCallback onOpenGame;
  final VoidCallback onOpenShootout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _PredictionBackground()),
          SafeArea(
            child: Column(
              children: [
                HistoryHeaderBar(
                  title: 'BRAND NEW GAMES',
                  accent: Cyber.cyan,
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: ListView(
                    key: const ValueKey('new-games-release-screen'),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      Text(
                        'Fresh game modes are now live. Use your squad in faster, more tactical football challenges built for quick sessions and big moments.',
                        style: Cyber.body(13, color: Cyber.muted, height: 1.45),
                      ),
                      const SizedBox(height: 16),
                      _ReleaseGameFeatureCard(
                        title: 'PITCH DUEL',
                        description:
                            'A tactical card match where every round asks you to pick the right player, choose the right action, and outscore your rival across changing match scenarios.',
                        icon: Icons.sports_soccer,
                        accent: Cyber.cyan,
                        ctaLabel: 'PLAY PITCH DUEL',
                        ctaKey: const ValueKey('new-games-page-pitch-duel-cta'),
                        onTap: () => _launchGame(context, onOpenGame),
                      ),
                      const _ReleaseGameDivider(),
                      _ReleaseGameFeatureCard(
                        title: 'PENALTY SHOOTOUT',
                        description:
                            'A fast shootout mode made for instant tension. Aim your kicks, read the keeper, and hold your nerve through sudden swings from the penalty spot.',
                        icon: Icons.gps_fixed,
                        accent: Cyber.lime,
                        ctaLabel: 'PLAY SHOOTOUT',
                        ctaKey: const ValueKey(
                          'new-games-page-penalty-shootout-cta',
                        ),
                        onTap: () => _launchGame(context, onOpenShootout),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _launchGame(BuildContext context, VoidCallback openGame) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => openGame());
  }
}

class _ReleaseGameFeatureCard extends StatelessWidget {
  const _ReleaseGameFeatureCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.ctaLabel,
    required this.ctaKey,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final String ctaLabel;
  final Key ctaKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ReleaseIconBox(icon: icon, accent: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.display(18, letterSpacing: 1.1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: Cyber.body(13, color: Cyber.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          _ReleaseGameButton(
            key: ctaKey,
            label: ctaLabel,
            icon: Icons.keyboard_double_arrow_right,
            accent: accent,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _ReleaseGameDivider extends StatelessWidget {
  const _ReleaseGameDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(height: 1, color: Cyber.border.withValues(alpha: 0.58)),
    );
  }
}

class _ReleaseIconBox extends StatelessWidget {
  const _ReleaseIconBox({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Cyber.bg.withValues(alpha: 0.55),
        border: Border.all(color: accent.withValues(alpha: 0.56)),
      ),
      child: Icon(icon, color: accent, size: 22),
    );
  }
}

class _ReleaseGameButton extends StatelessWidget {
  const _ReleaseGameButton({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  static const _bigCut = 10.0;
  static const _smallCut = 3.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          playSound(SoundEffect.uiTap);
          onTap();
        },
        child: CustomPaint(
          painter: _HudChamferCardPainter(
            bigCut: _bigCut,
            smallCut: _smallCut,
            fillColor: accent.withValues(alpha: 0.14),
            borderColor: accent.withValues(alpha: 0.72),
          ),
          child: ClipPath(
            clipper: const HudChamferClipper(
              bigCut: _bigCut,
              smallCut: _smallCut,
            ),
            child: SizedBox(
              height: 42,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: accent, size: 17),
                  const SizedBox(width: 7),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: Cyber.label(
                          10,
                          color: accent,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
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
  final int? matchCount;
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
                if (matchCount != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '($matchCount)',
                    style: Cyber.label(13, color: Cyber.muted),
                  ),
                ],
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

class _DayDividerRow extends StatelessWidget {
  const _DayDividerRow({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
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
    final header = '${day.day} ${months[day.month - 1]}';
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Center(
        child: Text(
          header,
          style: Cyber.display(15, color: Cyber.cyan, letterSpacing: 1.5),
        ),
      ),
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

  for (var offset = -7; offset <= 4; offset++) {
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

// Sport-specific games hub content.
class _GamesTab extends StatefulWidget {
  const _GamesTab({
    required this.selectedSport,
    required this.activeSportTab,
    required this.onSportTabChanged,
    required this.onOpenGame,
    required this.onOpenShootout,
    required this.onOpenQuiz,
    required this.onOpenFootballBingo,
    required this.onOpenFootballChess,
    required this.onOpenFinalOver,
    required this.onOpenGuessPlayer,
    required this.onOpenBasketballGuessPlayer,
    required this.onOpenCricketGuessPlayer,
    required this.onOpenGrandPrix,
    required this.onOpenF1GuessDriver,
    required this.onOpenTennisGuessWinner,
    required this.onOpenBasketball,
    required this.onOpenTennisRally,
    required this.animateIntro,
    required this.onIntroPlayed,
  });

  final Sport selectedSport;
  final int activeSportTab;
  final ValueChanged<int> onSportTabChanged;
  final VoidCallback onOpenGame;
  final VoidCallback onOpenShootout;
  final ValueChanged<Sport> onOpenQuiz;
  final VoidCallback onOpenFootballBingo;
  final VoidCallback onOpenFootballChess;
  final VoidCallback onOpenFinalOver;
  final VoidCallback onOpenGuessPlayer;
  final VoidCallback onOpenBasketballGuessPlayer;
  final VoidCallback onOpenCricketGuessPlayer;
  final VoidCallback onOpenGrandPrix;
  final VoidCallback onOpenF1GuessDriver;
  final VoidCallback onOpenTennisGuessWinner;
  final VoidCallback onOpenBasketball;
  final VoidCallback onOpenTennisRally;
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
    final streaks = context.select<GameBloc, ({int pitch, int penalty})>(
      (bloc) => (
        pitch: bloc.state.streak.current(StreakCategory.pitchDuel),
        penalty: bloc.state.streak.current(StreakCategory.penaltyShootout),
      ),
    );
    if (animateIntro) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _introPlayed = true;
        widget.onIntroPlayed?.call();
      });
    }
    return Column(
      children: [
        _PredictionSportsTabs(
          activeIndex: widget.activeSportTab,
          selectedSport: widget.selectedSport,
          onTap: widget.onSportTabChanged,
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<Sport>(widget.selectedSport),
              child: _buildSportTab(animateIntro, streaks),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSportTab(bool animateIntro, ({int pitch, int penalty}) streaks) {
    return switch (widget.selectedSport) {
      Sport.football => _buildFootballGames(animateIntro, streaks),
      Sport.motorsport => _buildF1Games(animateIntro),
      Sport.basketball => _buildBasketballGames(animateIntro),
      Sport.cricket => _buildCricketGames(animateIntro),
      Sport.tennis => _buildTennisGames(animateIntro),
    };
  }

  Widget _buildTennisGames(bool animateIntro) {
    return ListView(
      key: const ValueKey('tennis-games-tab'),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
      children: [
        StaggeredCardEntrance(
          index: 0,
          animate: animateIntro,
          child: _TennisRallyGameTile(onTap: widget.onOpenTennisRally),
        ),
        const SizedBox(height: 24),
        const _QuickPlayHeader(gameCount: 2),
        const SizedBox(height: 10),
        _QuickGamesGrid(
          animateIntro: animateIntro,
          startIndex: 1,
          games: [
            _QuickGameEntry(
              key: const ValueKey('tennis-quiz-grid-card'),
              title: 'TENNIS QUIZ',
              subtitle: 'TRIVIA GAUNTLET',
              icon: Icons.quiz_rounded,
              accent: Cyber.violet,
              onTap: () => widget.onOpenQuiz(Sport.tennis),
            ),
            _QuickGameEntry(
              key: const ValueKey('tennis-guess-winner-grid-card'),
              title: 'GUESS THE WINNER',
              subtitle: 'DAILY MYSTERY',
              icon: Icons.person_search_rounded,
              accent: Cyber.cyan,
              onTap: widget.onOpenTennisGuessWinner,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBasketballGames(bool animateIntro) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        StaggeredCardEntrance(
          index: 0,
          animate: animateIntro,
          child: _ArcadeHeroGameTile(
            key: const ValueKey('hoop-duel-hero-card'),
            title: 'HOOP DUEL',
            subtitle: 'STREET 1-ON-1 ARCADE HOOPS',
            badgeLabel: 'FEATURED // STREET',
            ctaLabel: 'HIT THE COURT',
            accent: Cyber.gold,
            background: const CustomPaint(painter: _HoopDuelMiniCourtPainter()),
            onTap: widget.onOpenBasketball,
          ),
        ),
        const SizedBox(height: 12),
        const _QuickPlayHeader(gameCount: 2),
        const SizedBox(height: 10),
        _QuickGamesGrid(
          animateIntro: animateIntro,
          startIndex: 1,
          games: [
            _QuickGameEntry(
              key: const ValueKey('basketball-quiz-grid-card'),
              title: 'BASKETBALL QUIZ',
              subtitle: 'TRIVIA GAUNTLET',
              icon: Icons.quiz_rounded,
              accent: Cyber.violet,
              onTap: () => widget.onOpenQuiz(Sport.basketball),
            ),
            _QuickGameEntry(
              key: const ValueKey('basketball-guess-player-grid-card'),
              title: 'GUESS THE PLAYER',
              subtitle: 'DAILY BASKETBALL MYSTERY',
              icon: Icons.person_search_rounded,
              accent: Cyber.pink,
              onTap: widget.onOpenBasketballGuessPlayer,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCricketGames(bool animateIntro) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        StaggeredCardEntrance(
          index: 0,
          animate: animateIntro,
          child: _ArcadeHeroGameTile(
            key: const ValueKey('final-over-hero-card'),
            title: 'FINAL OVER',
            subtitle: 'SIX-BALL CRICKET CHASE',
            badgeLabel: 'FEATURED // SIX BALLS',
            ctaLabel: 'START THE CHASE',
            accent: Cyber.cyan,
            background: const CustomPaint(
              painter: _FinalOverMiniPitchPainter(),
            ),
            onTap: widget.onOpenFinalOver,
          ),
        ),
        const SizedBox(height: 12),
        const _QuickPlayHeader(gameCount: 2),
        const SizedBox(height: 10),
        _QuickGamesGrid(
          animateIntro: animateIntro,
          startIndex: 1,
          games: [
            _QuickGameEntry(
              key: const ValueKey('cricket-quiz-grid-card'),
              title: 'CRICKET QUIZ',
              subtitle: 'TRIVIA GAUNTLET',
              icon: Icons.quiz_rounded,
              accent: Cyber.violet,
              onTap: () => widget.onOpenQuiz(Sport.cricket),
            ),
            _QuickGameEntry(
              key: const ValueKey('cricket-guess-player-grid-card'),
              title: 'GUESS THE PLAYER',
              subtitle: 'DAILY CRICKET MYSTERY',
              icon: Icons.person_search_rounded,
              accent: Cyber.pink,
              onTap: widget.onOpenCricketGuessPlayer,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFootballGames(
    bool animateIntro,
    ({int pitch, int penalty}) streaks,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        StaggeredCardEntrance(
          index: 0,
          animate: animateIntro,
          child: _ArcadeHeroGameTile(
            key: const ValueKey('pitch-duel-hero-card'),
            title: 'PITCH DUEL',
            subtitle: 'TACTICAL CARD GAME',
            badgeLabel: 'FEATURED // TACTICAL',
            ctaLabel: 'ENTER THE DUEL',
            accent: Cyber.cyan,
            streak: streaks.pitch,
            background: const CustomPaint(
              painter: _PitchDuelMiniTacticsPainter(),
            ),
            onTap: widget.onOpenGame,
          ),
        ),
        const SizedBox(height: 12),
        StaggeredCardEntrance(
          index: 1,
          animate: animateIntro,
          child: _ArcadeHeroGameTile(
            key: const ValueKey('penalty-shootout-hero-card'),
            title: 'PENALTY SHOOTOUT',
            titleLines: const ['PENALTY', 'SHOOTOUT'],
            subtitle: 'SUDDEN-DEATH SPOT KICKS',
            badgeLabel: 'FEATURED // SUDDEN DEATH',
            ctaLabel: 'TAKE THE SHOT',
            accent: Cyber.lime,
            streak: streaks.penalty,
            background: const CustomPaint(
              painter: _PenaltyShootoutMiniGoalPainter(),
            ),
            onTap: widget.onOpenShootout,
          ),
        ),
        const SizedBox(height: 12),
        StaggeredCardEntrance(
          index: 2,
          animate: animateIntro,
          child: _ArcadeHeroGameTile(
            key: const ValueKey('football-chess-hero-card'),
            title: '5V5 FOOTBALL CHESS',
            titleLines: const ['5V5 FOOTBALL', 'CHESS'],
            subtitle: 'TACTICAL SQUAD DUEL',
            badgeLabel: 'FEATURED // 5V5',
            ctaLabel: 'MAKE YOUR MOVE',
            accent: Cyber.gold,
            background: const CustomPaint(
              painter: _FootballChessMiniBoardPainter(),
            ),
            onTap: widget.onOpenFootballChess,
          ),
        ),
        const SizedBox(height: 12),
        const _QuickPlayHeader(gameCount: 3),
        const SizedBox(height: 10),
        _QuickGamesGrid(
          animateIntro: animateIntro,
          startIndex: 3,
          games: [
            _QuickGameEntry(
              key: const ValueKey('football-quiz-grid-card'),
              title: 'FOOTBALL QUIZ',
              subtitle: 'TRIVIA GAUNTLET',
              icon: Icons.quiz_rounded,
              accent: Cyber.violet,
              onTap: () => widget.onOpenQuiz(Sport.football),
            ),
            _QuickGameEntry(
              key: const ValueKey('football-bingo-grid-card'),
              title: 'FOOTBALL BINGO',
              subtitle: 'COUNTRY x CLUB GRID',
              icon: Icons.grid_view_rounded,
              accent: Cyber.amber,
              onTap: widget.onOpenFootballBingo,
            ),
            _QuickGameEntry(
              key: const ValueKey('football-guess-player-grid-card'),
              title: 'GUESS THE PLAYER',
              subtitle: 'DAILY FOOTBALL MYSTERY',
              icon: Icons.person_search_rounded,
              accent: Cyber.pink,
              onTap: widget.onOpenGuessPlayer,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildF1Games(bool animateIntro) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        StaggeredCardEntrance(
          index: 0,
          animate: animateIntro,
          child: _ArcadeHeroGameTile(
            key: const ValueKey('grand-prix-dash-hero-card'),
            title: 'GRAND PRIX DASH',
            subtitle: 'ONE-LAP ARCADE RACER',
            badgeLabel: 'FEATURED // RACE',
            ctaLabel: 'RACE NOW',
            accent: Cyber.f1Red,
            background: const CustomPaint(
              painter: F1MysterySignalPainter(),
            ),
            onTap: widget.onOpenGrandPrix,
          ),
        ),
        const SizedBox(height: 12),
        const _QuickPlayHeader(gameCount: 2),
        const SizedBox(height: 10),
        _QuickGamesGrid(
          animateIntro: animateIntro,
          startIndex: 1,
          games: [
            _QuickGameEntry(
              key: const ValueKey('f1-quiz-grid-card'),
              title: 'F1 QUIZ',
              subtitle: 'TRIVIA GAUNTLET',
              icon: Icons.quiz_rounded,
              accent: Cyber.violet,
              onTap: () => widget.onOpenQuiz(Sport.motorsport),
            ),
            _QuickGameEntry(
              key: const ValueKey('f1-guess-driver-grid-card'),
              title: 'GUESS THE DRIVER',
              subtitle: 'DAILY F1 MYSTERY',
              icon: Icons.person_search_rounded,
              accent: Cyber.pink,
              onTap: widget.onOpenF1GuessDriver,
            ),
          ],
        ),
      ],
    );
  }
}

class _TennisRallyGameTile extends StatelessWidget {
  const _TennisRallyGameTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ArcadeHeroGameTile(
      key: const ValueKey('tennis-rally-hero-card'),
      title: 'TENNIS RALLY',
      subtitle: '2D ARCADE SETS // 5 MODES',
      badgeLabel: 'FEATURED // NEW',
      ctaLabel: 'STEP ON COURT',
      accent: Cyber.lime,
      background: const CustomPaint(painter: TennisMysterySignalPainter()),
      onTap: onTap,
    );
  }
}

class _ArcadeHeroGameTile extends StatelessWidget {
  const _ArcadeHeroGameTile({
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.ctaLabel,
    required this.accent,
    required this.background,
    required this.onTap,
    this.titleLines,
    this.streak = 0,
    super.key,
  });

  final String title;
  final List<String>? titleLines;
  final String subtitle;
  final String badgeLabel;
  final String ctaLabel;
  final Color accent;
  final Widget background;
  final VoidCallback onTap;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title, $ctaLabel',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: CustomPaint(
          painter: _HudChamferCardPainter(
            bigCut: 14,
            smallCut: 4,
            fillColor: Cyber.panel,
            borderColor: accent.withValues(alpha: 0.86),
            borderGlow: true,
          ),
          child: ClipPath(
            clipper: const HudChamferClipper(bigCut: 14, smallCut: 4),
            child: SizedBox(
              height: 174,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  background,
                  Padding(
                    padding: const EdgeInsets.all(17),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          color: accent.withValues(alpha: 0.16),
                          child: Text(
                            badgeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Cyber.display(7, color: accent),
                          ),
                        ),
                        const Spacer(),
                        _HeroTitle(
                          title: title,
                          titleLines: titleLines,
                          streak: streak,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Cyber.display(8, color: accent),
                        ),
                      ],
                    ),
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

class _HeroTitle extends StatelessWidget {
  const _HeroTitle({
    required this.title,
    required this.titleLines,
    required this.streak,
  });

  final String title;
  final List<String>? titleLines;
  final int streak;

  TextStyle get _style => Cyber.display(
    20,
    color: Colors.white,
    letterSpacing: 1,
  ).copyWith(height: 1.02);

  @override
  Widget build(BuildContext context) {
    final lines = titleLines;
    if (lines == null || lines.isEmpty) {
      return Row(
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _style,
            ),
          ),
          if (streak > 0) ...[
            const SizedBox(width: StreakTheme.space8),
            StreakBadge(value: streak),
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final titleWidth = (constraints.maxWidth * 0.56).clamp(168.0, 214.0);

        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: titleWidth.toDouble()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < lines.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        lines[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _style,
                      ),
                    ),
                    if (streak > 0 && i == lines.length - 1) ...[
                      const SizedBox(width: StreakTheme.space8),
                      StreakBadge(value: streak),
                    ],
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HoopDuelMiniCourtPainter extends CustomPainter {
  const _HoopDuelMiniCourtPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0x00101825), Color(0xd12c260d)],
          stops: [0.36, 1],
        ).createShader(Offset.zero & size),
    );

    final court = Path()
      ..moveTo(size.width * 0.64, size.height * 0.16)
      ..lineTo(size.width, size.height * 0.16)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.52, size.height)
      ..close();
    canvas.drawPath(court, Paint()..color = const Color(0xff665116));
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Cyber.gold.withValues(alpha: 0.58);
    canvas.drawPath(court, line);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.79, size.height * 0.73),
        width: 108,
        height: 76,
      ),
      line,
    );
    canvas.drawLine(
      Offset(size.width * 0.82, size.height * 0.16),
      Offset(size.width * 0.82, size.height * 0.52),
      line,
    );
    canvas.drawLine(
      Offset(size.width * 0.74, size.height * 0.28),
      Offset(size.width * 0.91, size.height * 0.28),
      Paint()
        ..strokeWidth = 3
        ..color = Colors.white.withValues(alpha: 0.55),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.82, size.height * 0.39),
        width: 36,
        height: 10,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Cyber.gold,
    );

    final ball = Offset(size.width * 0.91, size.height * 0.60);
    canvas.drawCircle(ball, 17, Paint()..color = Cyber.gold);
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xff17120a).withValues(alpha: 0.78);
    canvas.drawLine(ball.translate(-17, 0), ball.translate(17, 0), seam);
    canvas.drawLine(ball.translate(0, -17), ball.translate(0, 17), seam);
    canvas.drawOval(Rect.fromCenter(center: ball, width: 16, height: 34), seam);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FinalOverMiniPitchPainter extends CustomPainter {
  const _FinalOverMiniPitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0x00101825), Color(0xd10b2b39)],
          stops: [0.36, 1],
        ).createShader(Offset.zero & size),
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.79, size.height * 0.55),
        width: size.width * 0.58,
        height: size.height * 0.68,
      ),
      Paint()..color = const Color(0xff153e36),
    );
    final pitch = Path()
      ..moveTo(size.width * 0.74, size.height * 0.20)
      ..lineTo(size.width * 0.84, size.height * 0.20)
      ..lineTo(size.width * 0.96, size.height * 1.02)
      ..lineTo(size.width * 0.57, size.height * 1.02)
      ..close();
    canvas.drawPath(pitch, Paint()..color = const Color(0xff8b7545));
    canvas.drawPath(
      pitch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Cyber.cyan.withValues(alpha: 0.48),
    );
    final crease = Paint()
      ..strokeWidth = 1.3
      ..color = Colors.white.withValues(alpha: 0.66);
    canvas.drawLine(
      Offset(size.width * 0.61, size.height * 0.83),
      Offset(size.width * 0.93, size.height * 0.83),
      crease,
    );

    final wicketX = size.width * 0.80;
    for (final dx in [-6.0, 0.0, 6.0]) {
      canvas.drawLine(
        Offset(wicketX + dx, size.height * 0.28),
        Offset(wicketX + dx, size.height * 0.48),
        Paint()
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..color = Cyber.cyan,
      );
    }
    canvas.drawLine(
      Offset(wicketX - 7, size.height * 0.30),
      Offset(wicketX + 7, size.height * 0.30),
      Paint()
        ..strokeWidth = 2
        ..color = Cyber.cyan,
    );

    final ball = Offset(size.width * 0.88, size.height * 0.65);
    canvas.drawLine(
      Offset(size.width * 0.72, size.height * 0.52),
      ball,
      Paint()
        ..strokeWidth = 2
        ..color = Cyber.cyan.withValues(alpha: 0.28),
    );
    canvas.drawCircle(ball, 7, Paint()..color = const Color(0xfff3f6f8));
    canvas.drawArc(
      Rect.fromCircle(center: ball, radius: 5),
      -1.2,
      2.4,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Cyber.danger,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PitchDuelMiniTacticsPainter extends CustomPainter {
  const _PitchDuelMiniTacticsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0x00101825), Color(0xd10a2a34)],
          stops: [0.36, 1],
        ).createShader(Offset.zero & size),
    );

    final field = Rect.fromLTRB(
      size.width * 0.57,
      size.height * 0.10,
      size.width * 1.03,
      size.height * 1.02,
    );
    canvas.drawRect(field, Paint()..color = const Color(0xff124b43));
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.42);
    canvas.drawRect(field, line);
    canvas.drawLine(
      Offset(field.left, field.center.dy),
      Offset(field.right, field.center.dy),
      line,
    );
    canvas.drawCircle(field.center, 27, line);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(field.center.dx, field.top),
        width: 82,
        height: 52,
      ),
      line,
    );

    final nodes = [
      Offset(size.width * 0.69, size.height * 0.77),
      Offset(size.width * 0.86, size.height * 0.58),
      Offset(size.width * 0.75, size.height * 0.34),
      Offset(size.width * 0.94, size.height * 0.23),
    ];
    final route = Paint()
      ..strokeWidth = 1.5
      ..color = Cyber.cyan.withValues(alpha: 0.65);
    for (var i = 0; i < nodes.length - 1; i++) {
      canvas.drawLine(nodes[i], nodes[i + 1], route);
    }
    for (var i = 0; i < nodes.length; i++) {
      canvas.drawCircle(
        nodes[i],
        7,
        Paint()..color = i == nodes.length - 1 ? Cyber.gold : Cyber.cyan,
      );
      canvas.drawCircle(
        nodes[i],
        11,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Cyber.cyan.withValues(alpha: 0.34),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PenaltyShootoutMiniGoalPainter extends CustomPainter {
  const _PenaltyShootoutMiniGoalPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0x00101825), Color(0xd10c3021)],
          stops: [0.36, 1],
        ).createShader(Offset.zero & size),
    );

    final goal = Rect.fromLTRB(
      size.width * 0.62,
      size.height * 0.18,
      size.width * 0.98,
      size.height * 0.62,
    );
    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..color = Colors.white.withValues(alpha: 0.60);
    canvas.drawRect(goal, frame);
    final net = Paint()
      ..strokeWidth = 0.8
      ..color = Cyber.lime.withValues(alpha: 0.28);
    for (var i = 1; i < 5; i++) {
      final x = goal.left + goal.width * i / 5;
      canvas.drawLine(Offset(x, goal.top), Offset(x, goal.bottom), net);
    }
    for (var i = 1; i < 4; i++) {
      final y = goal.top + goal.height * i / 4;
      canvas.drawLine(Offset(goal.left, y), Offset(goal.right, y), net);
    }

    final target = Offset(size.width * 0.86, size.height * 0.34);
    for (final radius in [24.0, 15.0, 6.0]) {
      canvas.drawCircle(
        target,
        radius,
        Paint()
          ..style = radius == 6 ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Cyber.lime.withValues(alpha: radius == 6 ? 0.92 : 0.55),
      );
    }

    final ball = Offset(size.width * 0.74, size.height * 0.79);
    canvas.drawCircle(ball, 15, Paint()..color = const Color(0xffedf4f6));
    canvas.drawCircle(ball, 5, Paint()..color = const Color(0xff18202a));
    for (final offset in const [
      Offset(-9, -7),
      Offset(9, -7),
      Offset(-8, 8),
      Offset(8, 8),
    ]) {
      canvas.drawCircle(
        ball + offset,
        3.2,
        Paint()..color = const Color(0xff18202a),
      );
    }
    canvas.drawLine(
      ball.translate(10, -12),
      target.translate(-8, 8),
      Paint()
        ..strokeWidth = 2
        ..color = Cyber.lime.withValues(alpha: 0.34),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FootballChessMiniBoardPainter extends CustomPainter {
  const _FootballChessMiniBoardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0x00101825), Color(0xd12f290b)],
          stops: [0.36, 1],
        ).createShader(Offset.zero & size),
    );

    final board = Rect.fromLTRB(
      size.width * 0.59,
      size.height * 0.10,
      size.width * 1.01,
      size.height * 1.02,
    );
    const cells = 5;
    final cellWidth = board.width / cells;
    final cellHeight = board.height / cells;
    for (var row = 0; row < cells; row++) {
      for (var column = 0; column < cells; column++) {
        final rect = Rect.fromLTWH(
          board.left + column * cellWidth,
          board.top + row * cellHeight,
          cellWidth,
          cellHeight,
        );
        canvas.drawRect(
          rect,
          Paint()
            ..color = (row + column).isEven
                ? const Color(0xff514718)
                : const Color(0xff202b31),
        );
      }
    }
    canvas.drawRect(
      board,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Cyber.gold.withValues(alpha: 0.72),
    );

    final pieces = [
      (Offset(size.width * 0.69, size.height * 0.74), Cyber.cyan),
      (Offset(size.width * 0.84, size.height * 0.74), Cyber.cyan),
      (Offset(size.width * 0.76, size.height * 0.55), Cyber.cyan),
      (Offset(size.width * 0.91, size.height * 0.36), Cyber.gold),
      (Offset(size.width * 0.69, size.height * 0.27), Cyber.gold),
    ];
    for (final piece in pieces) {
      canvas.drawCircle(piece.$1, 9, Paint()..color = piece.$2);
      canvas.drawCircle(
        piece.$1,
        13,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = piece.$2.withValues(alpha: 0.34),
      );
    }
    canvas.drawLine(
      pieces[2].$1,
      pieces[3].$1,
      Paint()
        ..strokeWidth = 2
        ..color = Cyber.gold.withValues(alpha: 0.58),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _QuickPlayHeader extends StatelessWidget {
  const _QuickPlayHeader({required this.gameCount});

  final int gameCount;

  @override
  Widget build(BuildContext context) {
    final badgeLabel = '$gameCount FREE GAME${gameCount == 1 ? '' : 'S'}';

    return Row(
      children: [
        Text(
          'QUICK PLAY',
          style: Cyber.display(11, color: Colors.white, letterSpacing: 1.8),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: Cyber.cyan.withValues(alpha: 0.28),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Cyber.cyan.withValues(alpha: 0.10),
            border: Border.all(color: Cyber.cyan.withValues(alpha: 0.38)),
          ),
          child: Text(
            badgeLabel,
            style: Cyber.display(7, color: Cyber.cyan, letterSpacing: 1.1),
          ),
        ),
      ],
    );
  }
}

class _QuickGameEntry {
  const _QuickGameEntry({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final Key key;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
}

class _QuickGamesGrid extends StatelessWidget {
  const _QuickGamesGrid({
    required this.animateIntro,
    required this.games,
    required this.startIndex,
  });

  final bool animateIntro;
  final List<_QuickGameEntry> games;
  final int startIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final wideColumnCount = constraints.maxWidth >= 560 ? 3 : 2;
        final columnCount = games.length < wideColumnCount
            ? games.length
            : wideColumnCount;
        final cardWidth =
            (constraints.maxWidth - (gap * (columnCount - 1))) / columnCount;
        final cardHeight = (cardWidth * 0.9).clamp(150.0, 176.0).toDouble();

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var index = 0; index < games.length; index++)
              SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: StaggeredCardEntrance(
                  index: startIndex + index,
                  animate: animateIntro,
                  child: _QuickGameTile(
                    key: games[index].key,
                    title: games[index].title,
                    subtitle: games[index].subtitle,
                    icon: games[index].icon,
                    accent: games[index].accent,
                    onTap: games[index].onTap,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuickGameTile extends StatelessWidget {
  const _QuickGameTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  static const _bigCut = 12.0;
  static const _smallCut = 3.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title, free to play',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: CustomPaint(
            painter: _HudChamferCardPainter(
              bigCut: _bigCut,
              smallCut: _smallCut,
              fillColor: Color.lerp(Cyber.panel, accent, 0.055)!,
              borderColor: accent.withValues(alpha: 0.84),
              borderGlow: true,
            ),
            child: ClipPath(
              clipper: const HudChamferClipper(
                bigCut: _bigCut,
                smallCut: _smallCut,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 150;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned(
                        right: -18,
                        bottom: -8,
                        child: Icon(
                          icon,
                          size: compact ? 72 : 86,
                          color: accent.withValues(alpha: 0.065),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: _bigCut,
                        right: 34,
                        child: Container(
                          height: 2,
                          color: accent.withValues(alpha: 0.82),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(compact ? 11 : 13),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _GameIconBox(
                                  icon: icon,
                                  accent: accent,
                                  size: compact ? 36 : 40,
                                  iconSize: compact ? 19 : 22,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 4,
                                  ),
                                  color: accent.withValues(alpha: 0.14),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: accent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'FREE',
                                        style: Cyber.display(
                                          7,
                                          color: accent,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Cyber.display(
                                compact ? 11.5 : 13.5,
                                color: Colors.white,
                                letterSpacing: compact ? 0.65 : 0.9,
                              ).copyWith(height: 1.02),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Cyber.label(
                                compact ? 6.5 : 7.5,
                                color: accent.withValues(alpha: 0.76),
                                letterSpacing: compact ? 0.7 : 1,
                              ).copyWith(height: 1.2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
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
