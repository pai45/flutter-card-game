import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/enums.dart';
import '../../config/sport_modules.dart';
import '../../config/theme.dart';
import '../../data/rival_roster.dart';
import '../../models/sport_match.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_underline_tabs.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/landing_bottom_navigation.dart';
import '../../widgets/stat_oz_top_bar.dart';
import '../../widgets/staggered_card_entrance.dart';
import '../profile/rival_profile_screen.dart';
import 'widgets/rank_board.dart';
import 'widgets/rank_widgets.dart';

// ─── Domain ──────────────────────────────────────────────────────────────────

enum LeaderboardType { matchDay, tournament, games }

// Matches shop tab styling (_ShopTabs / _TabItem).
const Color _tabBarBg = Cyber.bg;
const Color _tabSecondary = AppTheme.slate400;

const List<LeaderboardType> _typeTabOrder = [
  LeaderboardType.matchDay,
  LeaderboardType.tournament,
  LeaderboardType.games,
];

const List<Sport> _leaderboardSports = [
  Sport.football,
  Sport.cricket,
  Sport.basketball,
  Sport.tennis,
  Sport.motorsport,
];

final _leaderboardSportLabels = _leaderboardSports
    .map((sport) => sportModuleFor(sport).label.toUpperCase())
    .toList(growable: false);

final _leaderboardSportIcons = _leaderboardSports
    .map((sport) => sportModuleFor(sport).icon)
    .toList(growable: false);

enum TournamentBoard { players, teams }

enum TournamentScope { weekly, season, allTime }

enum GameMode { quiz, cardDuel, streaks, accuracy }

class _TeamSeed {
  const _TeamSeed({
    required this.team,
    required this.score,
    required this.movement,
    this.isUser = false,
  });

  final SportTeam team;
  final int score;
  final int movement;
  final bool isUser;
}

const List<_TeamSeed> _teams = [
  _TeamSeed(
    team: SportTeam(
      id: 'fra',
      name: 'France',
      shortName: 'FRA',
      color: Color(0xff1b4fd7),
    ),
    score: 1877,
    movement: 2,
  ),
  _TeamSeed(
    team: SportTeam(
      id: 'esp',
      name: 'Spain',
      shortName: 'ESP',
      color: Color(0xffd71920),
    ),
    score: 1876,
    movement: -1,
  ),
  _TeamSeed(
    team: SportTeam(
      id: 'arg',
      name: 'Argentina',
      shortName: 'ARG',
      color: Color(0xff74acdf),
    ),
    score: 1875,
    movement: -1,
    isUser: true,
  ),
  _TeamSeed(
    team: SportTeam(
      id: 'eng',
      name: 'England',
      shortName: 'ENG',
      color: Color(0xfff5f5f5),
    ),
    score: 1813,
    movement: 0,
  ),
  _TeamSeed(
    team: SportTeam(
      id: 'por',
      name: 'Portugal',
      shortName: 'POR',
      color: Color(0xff006600),
    ),
    score: 1764,
    movement: 1,
  ),
  _TeamSeed(
    team: SportTeam(
      id: 'bra',
      name: 'Brazil',
      shortName: 'BRA',
      color: Color(0xffffdf00),
    ),
    score: 1761,
    movement: -1,
  ),
  _TeamSeed(
    team: SportTeam(
      id: 'ned',
      name: 'Netherlands',
      shortName: 'NED',
      color: Color(0xffff7f00),
    ),
    score: 1756,
    movement: 0,
  ),
  _TeamSeed(
    team: SportTeam(
      id: 'mar',
      name: 'Morocco',
      shortName: 'MAR',
      color: Color(0xffc1272d),
    ),
    score: 1738,
    movement: 1,
  ),
  _TeamSeed(
    team: SportTeam(
      id: 'bel',
      name: 'Belgium',
      shortName: 'BEL',
      color: Color(0xfffdda24),
    ),
    score: 1735,
    movement: 0,
  ),
  _TeamSeed(
    team: SportTeam(
      id: 'ger',
      name: 'Germany',
      shortName: 'GER',
      color: Color(0xff111111),
    ),
    score: 1730,
    movement: 0,
  ),
  _TeamSeed(
    team: SportTeam(
      id: 'cro',
      name: 'Croatia',
      shortName: 'CRO',
      color: Color(0xffe31b23),
    ),
    score: 1717,
    movement: 1,
  ),
  _TeamSeed(
    team: SportTeam(
      id: 'mex',
      name: 'Mexico',
      shortName: 'MEX',
      color: Color(0xff006847),
    ),
    score: 1706,
    movement: 1,
  ),
  _TeamSeed(
    team: SportTeam(
      id: 'usa',
      name: 'United States',
      shortName: 'USA',
      color: Color(0xff3c3b6e),
    ),
    score: 1698,
    movement: 2,
  ),
  _TeamSeed(
    team: SportTeam(
      id: 'uru',
      name: 'Uruguay',
      shortName: 'URU',
      color: Color(0xff7bb9e8),
    ),
    score: 1687,
    movement: -1,
  ),
  _TeamSeed(
    team: SportTeam(
      id: 'col',
      name: 'Colombia',
      shortName: 'COL',
      color: Color(0xffffd100),
    ),
    score: 1684,
    movement: 1,
  ),
  _TeamSeed(
    team: SportTeam(
      id: 'jpn',
      name: 'Japan',
      shortName: 'JPN',
      color: Color(0xff0033a0),
    ),
    score: 1672,
    movement: 0,
  ),
];

ScoreMeta _scoreMeta(LeaderboardType type) => switch (type) {
  LeaderboardType.matchDay => (unit: 'XP'),
  LeaderboardType.tournament => (unit: 'XP'),
  LeaderboardType.games => (unit: 'W'),
};


int _scoreFor(
  LeaderboardType type,
  int base,
  TournamentScope scope,
  GameMode mode,
) {
  switch (type) {
    case LeaderboardType.matchDay:
      return base;
    case LeaderboardType.tournament:
      return switch (scope) {
        TournamentScope.weekly => base,
        TournamentScope.season => base * 6,
        TournamentScope.allTime => base * 27,
      };
    case LeaderboardType.games:
      return (base / 55).round() + mode.index;
  }
}

List<LeaderboardEntry> _entriesFor(
  LeaderboardType type,
  TournamentScope scope,
  GameMode mode,
) {
  return [
    for (var i = 0; i < kRivalRoster.length; i++)
      LeaderboardEntry(
        rank: i + 1,
        name: kRivalRoster[i].name,
        score: _scoreFor(type, kRivalRoster[i].base, scope, mode),
        movement: kRivalRoster[i].movement,
        isNew: kRivalRoster[i].isNew,
        badge: kRivalRoster[i].badge,
        isUser: kRivalRoster[i].isUser,
        xp: kRivalRoster[i].base,
      ),
  ];
}

List<LeaderboardEntry> _teamEntriesFor() {
  return [
    for (var i = 0; i < _teams.length; i++)
      LeaderboardEntry(
        rank: i + 1,
        name: _teams[i].team.name,
        score: _teams[i].score,
        movement: _teams[i].movement,
        isNew: false,
        badge: _teams[i].team.shortName,
        isUser: _teams[i].isUser,
        team: _teams[i].team,
      ),
  ];
}

LeaderboardEntry _userEntry(List<LeaderboardEntry> entries) =>
    entries.firstWhere((e) => e.isUser, orElse: () => entries.last);

/// Pushes the cinematic dossier for a known leaderboard rival [name]. Reused by
/// the leaderboard rows/podium and the profile friends roster; a no-op for an
/// unknown name. [onChallenge] enables the dossier's CHALLENGE action (null
/// hides it — e.g. when opened from the profile roster).
void showRivalDossier(
  BuildContext context,
  String name, {
  void Function(String opponentName, int opponentLevel)? onChallenge,
}) {
  final index = kRivalRoster.indexWhere((s) => s.name == name);
  if (index < 0) return;
  final seed = kRivalRoster[index];
  final userIndex = kRivalRoster.indexWhere((s) => s.isUser);
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 360),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, _, _) => RivalProfileScreen(
        name: seed.name,
        rank: index + 1,
        xp: seed.base,
        pro: seed.badge == 'PRO',
        userRank: userIndex < 0 ? index + 1 : userIndex + 1,
        onChallenge: onChallenge,
      ),
      transitionsBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    required this.onNavigate,
    this.onAddCoins,
    this.onChallenge,
    super.key,
  });

  final ValueChanged<AppSection> onNavigate;
  final VoidCallback? onAddCoins;

  /// Launches a card match against a CPU themed as the given rival
  /// (name, level). Null when challenge isn't available (e.g. the in-game
  /// leaderboard), in which case the dossier hides its CHALLENGE action.
  final void Function(String opponentName, int opponentLevel)? onChallenge;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with TickerProviderStateMixin {
  LeaderboardType _type = LeaderboardType.matchDay;
  TournamentBoard _tournamentBoard = TournamentBoard.teams;
  Sport _sport = Sport.football;
  TournamentScope _scope = TournamentScope.weekly;
  GameMode _mode = GameMode.quiz;

  late final AnimationController _typeTabIndicatorController;
  late Animation<double> _typeTabIndicatorAnimation;
  int _previousTypeTab = 0;

  @override
  void initState() {
    super.initState();
    _typeTabIndicatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 0,
    );
    _typeTabIndicatorAnimation = AlwaysStoppedAnimation<double>(
      _typeTabOrder.indexOf(_type).toDouble(),
    );
  }

  @override
  void dispose() {
    _typeTabIndicatorController.dispose();
    super.dispose();
  }

  void _setTypeTab(int index) {
    final type = _typeTabOrder[index];
    if (type == _type) return;
    _previousTypeTab = _typeTabOrder.indexOf(_type);
    _typeTabIndicatorAnimation =
        Tween<double>(
          begin: _previousTypeTab.toDouble(),
          end: index.toDouble(),
        ).animate(
          CurvedAnimation(
            parent: _typeTabIndicatorController,
            curve: Curves.easeOutCubic,
          ),
        );
    _typeTabIndicatorController.forward(from: 0);
    setState(() => _type = type);
  }

  /// Open a rival's dossier (or jump to your own profile if it's you). Team
  /// rows have no player profile, so they're inert.
  void _openRival(LeaderboardEntry entry) {
    if (entry.team != null) return;
    if (entry.isUser) {
      playSound(SoundEffect.uiTap);
      HapticFeedback.selectionClick();
      widget.onNavigate(AppSection.profile);
      return;
    }
    showRivalDossier(context, entry.name, onChallenge: widget.onChallenge);
  }

  @override
  Widget build(BuildContext context) {
    final accent = sportModuleFor(_sport).accent;
    final isTeamTournament =
        _type == LeaderboardType.tournament &&
        _tournamentBoard == TournamentBoard.teams;
    final allEntries = isTeamTournament
        ? _teamEntriesFor()
        : _entriesFor(_type, _scope, _mode);
    final user = _userEntry(allEntries);
    final entries = allEntries;

    return Scaffold(
      backgroundColor: Cyber.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Cyber.bg)),
          const Positioned.fill(child: CyberTextureOverlay()),
          SafeArea(
            top: false,
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 640;
                final activeSportIndex = _leaderboardSports.indexOf(_sport);
                final filters = _FilterBar(
                  type: _type,
                  scope: _scope,
                  onScope: (scope) => setState(() => _scope = scope),
                  tournamentBoard: _tournamentBoard,
                  onTournamentBoard: (board) =>
                      setState(() => _tournamentBoard = board),
                  mode: _mode,
                  onMode: (mode) => setState(() => _mode = mode),
                  accent: accent,
                  compact: compact,
                );

                return Column(
                  children: [
                    StatOzTopBar(
                      title: 'Leaderboard',
                      accent: accent,
                      onAddCoins:
                          widget.onAddCoins ??
                          () => widget.onNavigate(AppSection.shop),
                    ),
                    _LeaderboardSportsTabs(
                      activeIndex: activeSportIndex < 0 ? 0 : activeSportIndex,
                      selectedSport: _sport,
                      onTap: (index) => setState(() => _sport = _leaderboardSports[index]),
                    ),
                    _LeaderboardTabs(
                      activeTab: _typeTabOrder.indexOf(_type),
                      indicatorAnimation: _typeTabIndicatorAnimation,
                      accent: accent,
                      onTap: _setTypeTab,
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.025),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: entries.isEmpty
                            ? _EmptyState(
                                key: ValueKey('empty-${_type.name}'),
                                filters: filters,
                                type: _type,
                                accent: accent,
                                onAction: widget.onNavigate,
                              )
                            : _Body(
                                key: ValueKey(
                                  '${_type.name}-${_tournamentBoard.name}-${_scope.name}-${_mode.name}',
                                ),
                                filters: filters,
                                entries: entries,
                                type: _type,
                                accent: accent,
                                compact: compact,
                                onTapEntry: isTeamTournament ? null : _openRival,
                              ),
                      ),
                    ),
                    if (entries.isNotEmpty)
                      RankUserBar(
                        user: user,
                        meta: user.team != null
                            ? (unit: 'PTS')
                            : _scoreMeta(_type),
                        accent: accent,
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: LandingBottomNavigation(
        selectedIndex: 2,
        onNavigate: widget.onNavigate,
        includeShop: false,
      ),
    );
  }
}

// ─── Type tabs (matches shop _ShopTabs) ──────────────────────────────────────

class _LeaderboardTabs extends StatelessWidget {
  const _LeaderboardTabs({
    required this.activeTab,
    required this.indicatorAnimation,
    required this.accent,
    required this.onTap,
  });

  final int activeTab;
  final Animation<double> indicatorAnimation;
  final Color accent;
  final ValueChanged<int> onTap;

  static const List<String> _items = ['MATCH DAY', 'TOURNEY', 'GAMES'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: _tabBarBg.withValues(alpha: 0.4),
        border: Border(
          bottom: BorderSide(color: accent.withValues(alpha: 0.22)),
        ),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double tabWidth = constraints.maxWidth / _items.length;
          return Stack(
            children: [
              Row(
                children: [
                  for (int index = 0; index < _items.length; index++)
                    Expanded(
                      child: _Pressable(
                        accent: accent,
                        onTap: () => onTap(index),
                        child: _LeaderboardTabItem(
                          label: _items[index],
                          active: activeTab == index,
                          accent: accent,
                        ),
                      ),
                    ),
                ],
              ),
              AnimatedBuilder(
                animation: indicatorAnimation,
                builder: (BuildContext context, Widget? child) {
                  return Positioned(
                    left: tabWidth * indicatorAnimation.value + tabWidth * 0.18,
                    bottom: 0,
                    width: tabWidth * 0.64,
                    height: 3,
                    child: child!,
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: accent,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.7),
                        blurRadius: 10,
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

class _LeaderboardTabItem extends StatelessWidget {
  const _LeaderboardTabItem({
    required this.label,
    required this.active,
    required this.accent,
  });

  final String label;
  final bool active;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final Color color = active ? accent : _tabSecondary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: active ? accent.withValues(alpha: 0.07) : Colors.transparent,
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: Cyber.label(
              10,
              color: color,
              weight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.child,
    required this.onTap,
    required this.accent,
  });

  final Widget child;
  final VoidCallback onTap;
  final Color accent;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 150),
          scale: _pressed ? 0.97 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.zero,
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: widget.accent.withValues(alpha: 0.25),
                        blurRadius: 16,
                      ),
                    ]
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// ─── Filter bar (sport chips + contextual control) ───────────────────────────

class _LeaderboardSportsTabs extends StatelessWidget {
  const _LeaderboardSportsTabs({
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
      labels: _leaderboardSportLabels,
      icons: _leaderboardSportIcons,
      activeIndex: activeIndex,
      accent: sportModuleFor(selectedSport).accent,
      onTap: onTap,
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.type,
    required this.scope,
    required this.onScope,
    required this.tournamentBoard,
    required this.onTournamentBoard,
    required this.mode,
    required this.onMode,
    required this.accent,
    required this.compact,
  });

  final LeaderboardType type;
  final TournamentScope scope;
  final ValueChanged<TournamentScope> onScope;
  final TournamentBoard tournamentBoard;
  final ValueChanged<TournamentBoard> onTournamentBoard;
  final GameMode mode;
  final ValueChanged<GameMode> onMode;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final showCountdownInline =
        type == LeaderboardType.matchDay && MediaQuery.sizeOf(context).width >= 360;
    final showCountdownBelow =
        type == LeaderboardType.matchDay &&
        !showCountdownInline &&
        !compact;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showCountdownInline || showCountdownBelow)
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: CountdownPill(remaining: '04h 12m'),
            ),
          ),
        if (type == LeaderboardType.tournament) ...[
          _TournamentBoardTabs(
            active: tournamentBoard,
            onSelect: onTournamentBoard,
            accent: accent,
          ),
          if (tournamentBoard == TournamentBoard.players)
            _ScopeToggle(
              scope: scope,
              onScope: onScope,
              accent: accent,
              compact: compact,
            ),
        ],
        if (type == LeaderboardType.games)
          _ModeTabs(mode: mode, onMode: onMode, accent: accent),
      ],
    );
  }
}

class _TournamentBoardTabs extends StatelessWidget {
  const _TournamentBoardTabs({
    required this.active,
    required this.onSelect,
    required this.accent,
  });

  final TournamentBoard active;
  final ValueChanged<TournamentBoard> onSelect;
  final Color accent;

  static const List<({TournamentBoard board, String label})> _items = [
    (board: TournamentBoard.teams, label: 'TEAMS'),
    (board: TournamentBoard.players, label: 'PLAYERS'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          for (final item in _items)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(item.board),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  alignment: Alignment.center,
                  decoration: cutCornerDecoration(
                    color: active == item.board
                        ? accent.withValues(alpha: 0.14)
                        : Cyber.panel.withValues(alpha: 0.5),
                    borderColor: active == item.board
                        ? accent
                        : Cyber.line.withValues(alpha: 0.35),
                    cut: 8,
                  ),
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active == item.board ? accent : Cyber.muted,
                      fontFamily: Cyber.displayFont,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
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

class _ScopeToggle extends StatelessWidget {
  const _ScopeToggle({
    required this.scope,
    required this.onScope,
    required this.accent,
    required this.compact,
  });

  final TournamentScope scope;
  final ValueChanged<TournamentScope> onScope;
  final Color accent;
  final bool compact;

  static const List<({TournamentScope scope, String label})> _items = [
    (scope: TournamentScope.weekly, label: 'WEEKLY'),
    (scope: TournamentScope.season, label: 'SEASON'),
    (scope: TournamentScope.allTime, label: 'ALL-TIME'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 6 : 10, 16, 0),
      child: Row(
        children: [
          for (final item in _items)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onScope(item.scope),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  alignment: Alignment.center,
                  decoration: cutCornerDecoration(
                    color: scope == item.scope
                        ? accent.withValues(alpha: 0.14)
                        : Cyber.panel.withValues(alpha: 0.5),
                    borderColor: scope == item.scope
                        ? accent
                        : Cyber.line.withValues(alpha: 0.35),
                    cut: 8,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.label,
                      maxLines: 1,
                      style: TextStyle(
                        color: scope == item.scope ? accent : Cyber.muted,
                        fontFamily: Cyber.displayFont,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
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

class _ModeTabs extends StatelessWidget {
  const _ModeTabs({
    required this.mode,
    required this.onMode,
    required this.accent,
  });

  final GameMode mode;
  final ValueChanged<GameMode> onMode;
  final Color accent;

  static const List<({GameMode mode, String label})> _items = [
    (mode: GameMode.quiz, label: 'QUIZ'),
    (mode: GameMode.cardDuel, label: 'CARD DUEL'),
    (mode: GameMode.streaks, label: 'STREAKS'),
    (mode: GameMode.accuracy, label: 'ACCURACY'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        children: [
          for (final item in _items)
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onMode(item.mode),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: cutCornerDecoration(
                    color: mode == item.mode
                        ? accent.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderColor: mode == item.mode
                        ? accent
                        : Cyber.line.withValues(alpha: 0.4),
                    cut: 8,
                  ),
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: mode == item.mode ? accent : Cyber.muted,
                      fontFamily: Cyber.displayFont,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
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

// ─── Scrollable body ─────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({
    required this.filters,
    required this.entries,
    required this.type,
    required this.accent,
    required this.compact,
    this.onTapEntry,
    super.key,
  });

  final Widget filters;
  final List<LeaderboardEntry> entries;
  final LeaderboardType type;
  final Color accent;
  final bool compact;
  final ValueChanged<LeaderboardEntry>? onTapEntry;

  @override
  Widget build(BuildContext context) {
    final meta = entries.isNotEmpty && entries.first.team != null
        ? (unit: 'PTS')
        : _scoreMeta(type);
    // A short FRIENDS board (< 3) skips the podium and lists everyone as rows.
    final usePodium = entries.length >= 3;
    final List<LeaderboardEntry> podium = usePodium
        ? entries.take(3).toList()
        : const [];
    final List<LeaderboardEntry> remaining = usePodium
        ? entries.skip(3).toList()
        : entries;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          filters,
          Padding(
            padding: EdgeInsets.fromLTRB(16, compact ? 12 : 18, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RankPodium(
                  entries: podium,
                  meta: meta,
                  accent: accent,
                  animateCards: true,
                  onTapEntry: onTapEntry,
                ),
                if (remaining.isNotEmpty) ...[
                  SizedBox(height: compact ? 18 : 24),
                  for (var i = 0; i < remaining.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: StaggeredCardEntrance(
                        index: i + podium.length,
                        animate: true,
                        maxAnimatedIndex: entries.length,
                        child: RankRow(
                          entry: remaining[i],
                          accent: accent,
                          meta: meta,
                          onTap: onTapEntry == null
                              ? null
                              : () => onTapEntry!(remaining[i]),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty states ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.filters,
    required this.type,
    required this.accent,
    required this.onAction,
    super.key,
  });

  final Widget filters;
  final LeaderboardType type;
  final Color accent;
  final ValueChanged<AppSection> onAction;

  ({IconData icon, String title, String body, String cta, AppSection target})
  _config() {
    switch (type) {
      case LeaderboardType.matchDay:
        return (
          icon: Icons.sports_soccer,
          title: 'NO LIVE MATCH LEADERBOARD',
          body: 'Come back when the next match starts.',
          cta: 'VIEW TOURNAMENT RANKING',
          target: AppSection.leaderboard,
        );
      case LeaderboardType.tournament:
        return (
          icon: Icons.military_tech,
          title: "YOU'RE NOT RANKED YET",
          body: "Play today's match to enter the leaderboard.",
          cta: 'START PLAYING',
          target: AppSection.match,
        );

      case LeaderboardType.games:
        return (
          icon: Icons.sports_esports,
          title: 'NO GAME SCORES YET',
          body: 'Play a game mode to claim your first rank.',
          cta: 'PLAY GAME',
          target: AppSection.match,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _config();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          filters,
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    config.icon,
                    color: accent.withValues(alpha: 0.7),
                    size: 48,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    config.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: Cyber.displayFont,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    config.body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Cyber.muted,
                      fontFamily: Cyber.bodyFont,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  GestureDetector(
                    onTap: () => onAction(config.target),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      decoration: cutCornerDecoration(color: accent, cut: 10),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          config.cta,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Cyber.bg,
                            fontFamily: Cyber.displayFont,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
