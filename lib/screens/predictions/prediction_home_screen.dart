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
import '../../widgets/landing_bottom_navigation.dart';
import '../../widgets/staggered_card_entrance.dart';
import '../../widgets/stat_oz_top_bar.dart';
import '../../widgets/streak_widgets.dart';
import '../profile/widgets/profile_card.dart';
import '../shop/shop_screen.dart' show CoinIcon;
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
    required this.onOpenSuperOver,
    required this.onOpenCricketDeck,
    required this.onOpenGuessPlayer,
    required this.onOpenBasketballGuessPlayer,
    required this.onOpenCricketGuessPlayer,
    required this.onOpenGrandPrix,
    required this.onOpenBasketball,
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
  final VoidCallback onOpenSuperOver;
  final VoidCallback onOpenCricketDeck;
  final VoidCallback onOpenGuessPlayer;
  final VoidCallback onOpenBasketballGuessPlayer;
  final VoidCallback onOpenCricketGuessPlayer;
  final VoidCallback onOpenGrandPrix;
  final VoidCallback onOpenBasketball;
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
        onOpenSuperOver: widget.onOpenSuperOver,
        onOpenCricketDeck: widget.onOpenCricketDeck,
        onOpenGuessPlayer: widget.onOpenGuessPlayer,
        onOpenBasketballGuessPlayer: widget.onOpenBasketballGuessPlayer,
        onOpenCricketGuessPlayer: widget.onOpenCricketGuessPlayer,
        onOpenGrandPrix: widget.onOpenGrandPrix,
        onOpenBasketball: widget.onOpenBasketball,
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
  Sport.f1,
];

final _predictionSportLabels = _predictionSports
    .map((sport) => sportModuleFor(sport).label.toUpperCase())
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
  bool _showNewGamesCallout = true;

  @override
  void didUpdateWidget(covariant _MatchesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSport != widget.selectedSport) {
      _selectedDay = _startOfDay(DateTime.now());
      _slideFromLeft = true;
      _dayGeneration++;
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
              if (state.loading) return const _PickSkeleton();
              final sportFixtures = state.fixtures
                  .where((fixture) => fixture.sport == widget.selectedSport)
                  .toList();
              final days = _calendarDays(sportFixtures);
              final today = _startOfDay(DateTime.now());
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
                  groupedByDay[day] = _groupByLeague(
                    state.leagues,
                    dayFixtures,
                  );
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
          style: Cyber.label(9, color: textColor, letterSpacing: 0.2),
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
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (_, index) => ClipPath(
        clipper: const HudChamferClipper(bigCut: 15, smallCut: 2),
        child: Container(
          height: index == 3 ? 174 : 118,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.skeletonFill,
            border: Border.all(color: AppTheme.borderMuted),
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
    required this.selectedSport,
    required this.activeSportTab,
    required this.onSportTabChanged,
    required this.onOpenGame,
    required this.onOpenShootout,
    required this.onOpenQuiz,
    required this.onOpenFootballBingo,
    required this.onOpenFootballChess,
    required this.onOpenSuperOver,
    required this.onOpenCricketDeck,
    required this.onOpenGuessPlayer,
    required this.onOpenBasketballGuessPlayer,
    required this.onOpenCricketGuessPlayer,
    required this.onOpenGrandPrix,
    required this.onOpenBasketball,
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
  final VoidCallback onOpenSuperOver;
  final VoidCallback onOpenCricketDeck;
  final VoidCallback onOpenGuessPlayer;
  final VoidCallback onOpenBasketballGuessPlayer;
  final VoidCallback onOpenCricketGuessPlayer;
  final VoidCallback onOpenGrandPrix;
  final VoidCallback onOpenBasketball;
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
      Sport.f1 => _buildF1Games(animateIntro),
      Sport.basketball => _buildBasketballGames(animateIntro),
      Sport.cricket => _buildCricketGames(animateIntro),
    };
  }

  Widget _buildBasketballGames(bool animateIntro) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        StaggeredCardEntrance(
          index: 0,
          animate: animateIntro,
          child: _GameTile(
            title: 'HOOP DUEL',
            subtitle: 'STREET 1-ON-1 ARCADE HOOPS',
            icon: Icons.sports_basketball,
            accent: Cyber.gold,
            featured: true,
            showTrailingIcon: false,
            onTap: widget.onOpenBasketball,
          ),
        ),
        const SizedBox(height: 12),
        StaggeredCardEntrance(
          index: 1,
          animate: animateIntro,
          child: _GameTile(
            title: 'GUESS THE PLAYER',
            subtitle: 'DAILY BASKETBALL MYSTERY',
            icon: Icons.person_search,
            accent: Cyber.pink,
            featured: true,
            showTrailingIcon: false,
            onTap: widget.onOpenBasketballGuessPlayer,
          ),
        ),
        const SizedBox(height: 12),
        StaggeredCardEntrance(
          index: 2,
          animate: animateIntro,
          child: _GameTile(
            title: 'BASKETBALL QUIZ',
            subtitle: 'TRIVIA GAUNTLET',
            icon: Icons.quiz,
            accent: Cyber.violet,
            featured: true,
            showTrailingIcon: false,
            onTap: () => widget.onOpenQuiz(Sport.basketball),
          ),
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
          child: _GameTile(
            title: 'SUPER OVER',
            subtitle: 'ARCADE CRICKET BATTING',
            icon: Icons.sports_cricket,
            accent: Cyber.lime,
            featured: true,
            showTrailingIcon: false,
            onTap: widget.onOpenSuperOver,
          ),
        ),
        const SizedBox(height: 12),
        StaggeredCardEntrance(
          index: 1,
          animate: animateIntro,
          child: _GameTile(
            title: 'GUESS THE PLAYER',
            subtitle: 'DAILY CRICKET MYSTERY',
            icon: Icons.person_search,
            accent: Cyber.pink,
            featured: true,
            showTrailingIcon: false,
            onTap: widget.onOpenCricketGuessPlayer,
          ),
        ),
        const SizedBox(height: 12),
        StaggeredCardEntrance(
          index: 2,
          animate: animateIntro,
          child: _GameTile(
            title: 'CRICKET QUIZ',
            subtitle: 'TRIVIA GAUNTLET',
            icon: Icons.quiz,
            accent: Cyber.violet,
            featured: true,
            showTrailingIcon: false,
            onTap: () => widget.onOpenQuiz(Sport.cricket),
          ),
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
          child: _GameTile(
            title: 'PITCH DUEL',
            subtitle: 'TACTICAL CARD GAME',
            icon: Icons.sports_soccer,
            accent: Cyber.cyan,
            streak: streaks.pitch,
            featured: true,
            showTrailingIcon: false,
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
            streak: streaks.penalty,
            featured: true,
            showTrailingIcon: false,
            onTap: widget.onOpenShootout,
          ),
        ),
        const SizedBox(height: 12),
        StaggeredCardEntrance(
          index: 2,
          animate: animateIntro,
          child: _GameTile(
            title: '5V5 FOOTBALL CHESS',
            subtitle: 'TACTICAL SQUAD DUEL',
            icon: Icons.grid_on,
            accent: Cyber.gold,
            featured: true,
            showTrailingIcon: false,
            onTap: widget.onOpenFootballChess,
          ),
        ),
        const SizedBox(height: 12),
        StaggeredCardEntrance(
          index: 3,
          animate: animateIntro,
          child: _GameTile(
            title: 'FOOTBALL QUIZ',
            subtitle: 'TRIVIA GAUNTLET',
            icon: Icons.quiz,
            accent: Cyber.violet,
            featured: true,
            showTrailingIcon: false,
            onTap: () => widget.onOpenQuiz(Sport.football),
          ),
        ),
        const SizedBox(height: 12),
        StaggeredCardEntrance(
          index: 4,
          animate: animateIntro,
          child: _GameTile(
            title: 'FOOTBALL BINGO',
            subtitle: 'COUNTRY x CLUB GRID',
            icon: Icons.grid_view,
            accent: Cyber.amber,
            featured: true,
            showTrailingIcon: false,
            onTap: widget.onOpenFootballBingo,
          ),
        ),
        const SizedBox(height: 12),
        StaggeredCardEntrance(
          index: 5,
          animate: animateIntro,
          child: _GameTile(
            title: 'GUESS THE PLAYER',
            subtitle: 'DAILY FOOTBALL MYSTERY',
            icon: Icons.person_search,
            accent: Cyber.pink,
            featured: true,
            showTrailingIcon: false,
            onTap: widget.onOpenGuessPlayer,
          ),
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
          child: _GameTile(
            title: 'GRAND PRIX DASH',
            subtitle: 'ONE-LAP ARCADE RACER',
            icon: Icons.sports_motorsports,
            accent: Cyber.f1Red,
            featured: true,
            showTrailingIcon: false,
            onTap: widget.onOpenGrandPrix,
          ),
        ),
        const SizedBox(height: 12),
        StaggeredCardEntrance(
          index: 1,
          animate: animateIntro,
          child: _GameTile(
            title: 'F1 QUIZ',
            subtitle: 'TRIVIA GAUNTLET',
            icon: Icons.quiz,
            accent: Cyber.violet,
            featured: true,
            showTrailingIcon: false,
            onTap: () => widget.onOpenQuiz(Sport.f1),
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
    this.featured = false,
    this.streak = 0,
    this.showTrailingIcon = true,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  final bool featured;
  final int streak;
  final bool showTrailingIcon;

  static const _bigCut = 14.0;
  static const _smallCut = 4.0;

  @override
  Widget build(BuildContext context) {
    final borderColor = accent.withValues(alpha: 0.82);

    return Opacity(
      opacity: 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: CustomPaint(
          painter: _HudChamferCardPainter(
            bigCut: _bigCut,
            smallCut: _smallCut,
            fillColor: Cyber.panel,
            borderColor: borderColor,
            borderGlow: featured,
          ),
          child: ClipPath(
            clipper: const HudChamferClipper(
              bigCut: _bigCut,
              smallCut: _smallCut,
            ),
            child: featured
                ? _FeaturedBody(
                    title: title,
                    subtitle: subtitle,
                    icon: icon,
                    accent: accent,
                    streak: streak,
                    onTap: onTap,
                    showTrailingIcon: showTrailingIcon,
                  )
                : _CompactBody(
                    title: title,
                    subtitle: subtitle,
                    icon: icon,
                    accent: accent,
                    showTrailingIcon: showTrailingIcon,
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
    required this.showTrailingIcon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final bool showTrailingIcon;

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
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Cyber.label(
                    9,
                    color: accent.withValues(alpha: 0.65),
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (showTrailingIcon)
            Icon(Icons.chevron_right, color: accent, size: 22),
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
    required this.streak,
    required this.showTrailingIcon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  final int streak;
  final bool showTrailingIcon;

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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Cyber.display(18, letterSpacing: 1.1),
                              ),
                            ),
                            if (streak > 0) ...[
                              const SizedBox(width: StreakTheme.space8),
                              StreakBadge(value: streak),
                            ],
                          ],
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
                  if (showTrailingIcon)
                    Icon(Icons.chevron_right, color: accent, size: 22),
                ],
              ),
              const SizedBox(height: 14),
              _GameFreeButton(onTap: onTap, accent: accent),
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
  const _GameFreeButton({required this.onTap, required this.accent});

  final VoidCallback? onTap;
  final Color accent;

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
          fillColor: accent,
          borderColor: Colors.transparent,
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
                const Icon(
                  Icons.toll_rounded,
                  size: 18,
                  color: AppTheme.darkInk,
                ),
                const SizedBox(width: 8),
                Text(
                  'Free',
                  style: Cyber.display(
                    16,
                    color: AppTheme.darkInk,
                    letterSpacing: 0.8,
                  ),
                ),
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
