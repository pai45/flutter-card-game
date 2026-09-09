import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/prediction/prediction_cubit.dart';
import '../../config/enums.dart';
import '../../config/sport_modules.dart';
import '../../config/theme.dart';
import '../../data/leaderboard_leagues.dart';
import '../../data/rival_roster.dart';
import '../../models/sport_match.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/cyber/cyber_underline_tabs.dart';
import '../../widgets/cyber/sport_underline_tabs.dart';
import '../../widgets/landing_bottom_navigation.dart';
import '../../widgets/stat_oz_top_bar.dart';
import '../../widgets/staggered_card_entrance.dart';
import '../profile/rival_profile_screen.dart';
import 'widgets/league_dial.dart';
import 'widgets/rank_board.dart';
import 'user_search_screen.dart';
import 'widgets/rank_widgets.dart';

// ─── Domain ──────────────────────────────────────────────────────────────────

enum LeaderboardType { matches, games }

const List<LeaderboardType> _typeTabOrder = [
  LeaderboardType.matches,
  LeaderboardType.games,
];

const List<Sport> _leaderboardSports = [
  Sport.football,
  Sport.cricket,
  Sport.basketball,
  Sport.motorsport,
  Sport.tennis,
];

enum TournamentBoard { players, teams }

enum TournamentScope { weekly, season, allTime }

/// Every sport's Games board carries its own game catalogue. The enum keeps
/// leaderboard score generation stable while [_gameModesFor] supplies the
/// sport-specific player-facing names. [shootout], [chess] and [bingo] are
/// football-only; every other sport reuses the featured/quiz/mystery trio.
enum GameMode { featured, quiz, mystery, shootout, chess, bingo }

typedef _GameModeOption = ({GameMode mode, String label});

List<_GameModeOption> _gameModesFor(Sport sport) => switch (sport) {
  Sport.football => const [
    (mode: GameMode.featured, label: 'PITCH DUEL'),
    (mode: GameMode.shootout, label: 'PENALTY SHOOTOUT'),
    (mode: GameMode.chess, label: 'FOOTBALL CHESS'),
    (mode: GameMode.bingo, label: 'FOOTBALL BINGO'),
    (mode: GameMode.quiz, label: 'FOOTBALL QUIZ'),
    (mode: GameMode.mystery, label: 'GUESS THE PLAYER'),
  ],
  Sport.cricket => const [
    (mode: GameMode.featured, label: 'FINAL OVER'),
    (mode: GameMode.quiz, label: 'CRICKET QUIZ'),
    (mode: GameMode.mystery, label: 'GUESS THE PLAYER'),
  ],
  Sport.basketball => const [
    (mode: GameMode.featured, label: 'HOOP DUEL'),
    (mode: GameMode.quiz, label: 'BASKETBALL QUIZ'),
    (mode: GameMode.mystery, label: 'GUESS THE PLAYER'),
  ],
  Sport.motorsport => const [
    (mode: GameMode.featured, label: 'GRAND PRIX DASH'),
    (mode: GameMode.quiz, label: 'F1 QUIZ'),
    (mode: GameMode.mystery, label: 'GUESS THE DRIVER'),
  ],
  Sport.tennis => const [
    (mode: GameMode.featured, label: 'TENNIS RALLY'),
    (mode: GameMode.quiz, label: 'TENNIS QUIZ'),
    (mode: GameMode.mystery, label: 'GUESS THE WINNER'),
  ],
};

/// Player-facing name of [mode] on [sport]'s Games board. Falls back to the
/// sport's first game when the pair doesn't exist (the football-only modes).
String gameModeLabel(Sport sport, GameMode mode) {
  final options = _gameModesFor(sport);
  return options
      .firstWhere((option) => option.mode == mode, orElse: () => options.first)
      .label;
}

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
  LeaderboardType.matches => (unit: 'XP'),
  LeaderboardType.games => (unit: 'W'),
};

int _scoreFor(
  LeaderboardType type,
  int base,
  TournamentScope scope,
  GameMode mode,
) {
  switch (type) {
    case LeaderboardType.matches:
      return switch (scope) {
        TournamentScope.weekly => base,
        TournamentScope.season => base * 6,
        TournamentScope.allTime => base * 27,
      };
    case LeaderboardType.games:
      return (base / 55).round() + mode.index;
  }
}

/// Stable hash over `<leagueId>:<name>`. No `Random`, no `DateTime` — a rival
/// must land on the same club and the same league-adjusted score every visit.
///
/// Kept deliberately small-arithmetic: every intermediate stays under 2^53, so
/// it produces the SAME value on the web (where ints are JS doubles) as on the
/// VM. An FNV-1a here silently diverged between the two, giving a rival a
/// different club and rank in the browser than in tests.
int _leagueHash(String value) {
  var hash = 0;
  for (var i = 0; i < value.length; i++) {
    hash = (hash * 31 + value.codeUnitAt(i)) % 0x7fffffff;
  }
  return hash;
}

/// A rival's standing *inside* [league]. Nudging the canonical base by a stable
/// per-league offset keeps the elite near the top while genuinely churning the
/// mid-table — so the podium, and your own rank, differ league to league.
int _leagueBase(int base, int hash) => base + (hash % 700) - 320;

List<LeaderboardEntry> _entriesFor(
  LeaderboardType type,
  TournamentScope scope,
  GameMode mode,
  LeaderboardLeague league,
) {
  final seeded = [
    for (final seed in kRivalRoster)
      (seed: seed, hash: _leagueHash('${league.id}:${seed.name}')),
  ]..sort((a, b) {
    final byBase = _leagueBase(
      b.seed.base,
      b.hash,
    ).compareTo(_leagueBase(a.seed.base, a.hash));
    // Ties fall back to the canonical order so the board never flickers.
    return byBase != 0 ? byBase : a.seed.name.compareTo(b.seed.name);
  });

  return [
    for (var i = 0; i < seeded.length; i++)
      LeaderboardEntry(
        rank: i + 1,
        name: seeded[i].seed.name,
        // Score off the league-adjusted base, not the canonical one, or the
        // column disagrees with the ranking it produced.
        score: _scoreFor(
          type,
          _leagueBase(seeded[i].seed.base, seeded[i].hash),
          scope,
          mode,
        ),
        movement: seeded[i].seed.movement,
        isNew: seeded[i].seed.isNew,
        badge: seeded[i].seed.badge,
        isUser: seeded[i].seed.isUser,
        xp: seeded[i].seed.base,
        subtitle: _clubFor(league, seeded[i].hash),
      ),
  ];
}

/// The rival's club/nation badge on this board. Reuses [LeaderboardEntry.subtitle],
/// which the podium tile, rows and pinned user bar already render — deliberately
/// NOT `team`, since a non-null `team` makes a row inert in [_openRival].
String? _clubFor(LeaderboardLeague league, int hash) =>
    league.clubs.isEmpty ? null : league.clubs[hash % league.clubs.length];

/// Where the user lands in [league], without building the whole board.
int _userRankIn(LeaderboardLeague league) {
  final user = kRivalRoster.firstWhere(
    (seed) => seed.isUser,
    orElse: () => kRivalRoster.last,
  );
  final mine = _leagueBase(
    user.base,
    _leagueHash('${league.id}:${user.name}'),
  );
  var rank = 1;
  for (final seed in kRivalRoster) {
    if (seed.name == user.name) continue;
    final theirs = _leagueBase(
      seed.base,
      _leagueHash('${league.id}:${seed.name}'),
    );
    if (theirs > mine) rank++;
  }
  return rank;
}

/// The league in [catalogue] the user ranks highest in — the "you're king here"
/// hook on the pinned rank bar.
LeaderboardLeague? _bestLeagueFor(List<LeaderboardLeague> catalogue) {
  LeaderboardLeague? best;
  var bestRank = 1 << 30;
  for (final league in catalogue) {
    final rank = _userRankIn(league);
    if (rank < bestRank) {
      bestRank = rank;
      best = league;
    }
  }
  return best;
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
    this.initialType,
    this.initialSport,
    this.initialMode,
    this.onClose,
    super.key,
  });

  final ValueChanged<AppSection> onNavigate;
  final VoidCallback? onAddCoins;

  /// Launches a card match against a CPU themed as the given rival
  /// (name, level). Null when challenge isn't available (e.g. the in-game
  /// leaderboard), in which case the dossier hides its CHALLENGE action.
  final void Function(String opponentName, int opponentLevel)? onChallenge;

  /// Board to open on. Lets a game lobby deep-link straight to its own
  /// standings instead of dropping the player on the default MATCHES board.
  final LeaderboardType? initialType;
  final Sport? initialSport;
  final GameMode? initialMode;

  /// Set when the board is pushed over another screen (a game lobby) rather
  /// than mounted as the leaderboard tab: swaps the bottom nav for a back
  /// action and titles the bar with the game you came from.
  final VoidCallback? onClose;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late LeaderboardType _type = widget.initialType ?? LeaderboardType.matches;
  TournamentBoard _tournamentBoard = TournamentBoard.teams;
  late Sport _sport = widget.initialSport ?? Sport.football;
  TournamentScope _scope = TournamentScope.weekly;
  late GameMode _mode = widget.initialMode ?? GameMode.featured;

  /// Each sport remembers the league you last spun to, so switching tabs and
  /// coming back doesn't reset your board.
  final Map<Sport, String> _leagueBySport = {};

  LeaderboardLeague _leagueFor(Sport sport) {
    final catalogue = leaderboardLeaguesFor(sport);
    final id = _leagueBySport[sport] ??= _defaultLeagueId(sport, catalogue);
    return catalogue.firstWhere(
      (league) => league.id == id,
      orElse: () => catalogue.first,
    );
  }

  /// Defaults to the league the player follows from onboarding when this sport
  /// has one, otherwise the first in the dial.
  ///
  /// Read nullably: the board is also mounted from the in-game shell, where a
  /// PredictionCubit isn't guaranteed — a missing one just means no preference.
  String _defaultLeagueId(Sport sport, List<LeaderboardLeague> catalogue) {
    final followed =
        context.read<PredictionCubit?>()?.state.followedLeagueIds ??
        const <String>[];
    return catalogue
        .firstWhere(
          (league) => followed.contains(league.id),
          orElse: () => catalogue.first,
        )
        .id;
  }

  void _setTypeTab(int index) {
    final type = _typeTabOrder[index];
    if (type == _type) return;
    HapticFeedback.selectionClick();
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
    final onClose = widget.onClose;
    final accent = sportModuleFor(_sport).accent;
    final isTeamTournament =
        _type == LeaderboardType.matches &&
        _tournamentBoard == TournamentBoard.teams;
    final catalogue = leaderboardLeaguesFor(_sport);
    final league = _leagueFor(_sport);
    final allEntries = isTeamTournament
        ? _teamEntriesFor()
        : _entriesFor(_type, _scope, _mode, league);
    var user = _userEntry(allEntries);
    // Reward finding the league you're strongest in.
    if (!isTeamTournament &&
        user.subtitle != null &&
        _bestLeagueFor(catalogue)?.id == league.id) {
      user = user.copyWith(subtitle: '${user.subtitle} // BEST LEAGUE');
    }
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
                  sport: _sport,
                  leagues: catalogue,
                  selectedLeagueId: league.id,
                  onLeague: (id) =>
                      setState(() => _leagueBySport[_sport] = id),
                  accent: accent,
                  compact: compact,
                );

                return Column(
                  children: [
                    StatOzTopBar(
                      title: 'Leaderboard',
                      accent: accent,
                      leading: onClose == null
                          ? null
                          : IconButton(
                              tooltip: 'Back',
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(
                                width: 34,
                                height: 40,
                              ),
                              onPressed: onClose,
                              icon: const Icon(
                                Icons.arrow_back_ios_new,
                                size: 18,
                              ),
                              color: accent,
                            ),
                      onAddCoins:
                          widget.onAddCoins ??
                          () => widget.onNavigate(AppSection.shop),
                    ),
                    _LeaderboardTabs(
                      activeTab: _typeTabOrder.indexOf(_type),
                      onTap: _setTypeTab,
                    ),
                    _LeaderboardSportsTabs(
                      activeIndex: activeSportIndex < 0 ? 0 : activeSportIndex,
                      selectedSport: _sport,
                      onTap: (index) => setState(() {
                        _sport = _leaderboardSports[index];
                        _mode = GameMode.featured;
                      }),
                      onSearch: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => UserSearchScreen(
                              onChallenge: widget.onChallenge,
                            ),
                          ),
                        );
                      },
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
                                onTapEntry: isTeamTournament
                                    ? null
                                    : _openRival,
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
      bottomNavigationBar: onClose != null
          ? null
          : LandingBottomNavigation(
              selectedIndex: 2,
              onNavigate: widget.onNavigate,
              includeShop: false,
            ),
    );
  }
}

// ─── Type tabs (matches shop _ShopTabs) ──────────────────────────────────────

class _LeaderboardTabs extends StatelessWidget {
  const _LeaderboardTabs({required this.activeTab, required this.onTap});

  final int activeTab;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return CyberUnderlineTabs(
      labels: const ['MATCHES', 'GAMES'],
      activeIndex: activeTab,
      onTap: onTap,
      accent: activeTab == 0 ? Cyber.cyan : Cyber.amber,
    );
  }
}

// ─── Filter bar (sport chips + contextual control) ───────────────────────────

class _LeaderboardSportsTabs extends StatelessWidget {
  const _LeaderboardSportsTabs({
    required this.activeIndex,
    required this.selectedSport,
    required this.onTap,
    required this.onSearch,
  });

  final int activeIndex;
  final Sport selectedSport;
  final ValueChanged<int> onTap;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return SportUnderlineTabs(
      activeIndex: activeIndex,
      selectedSport: selectedSport,
      onTap: onTap,
      trailingAction: CyberSearchButton(
        key: const ValueKey('leaderboard-search-button'),
        onTap: onSearch,
        label: 'Search Leaderboard',
      ),
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
    required this.sport,
    required this.leagues,
    required this.selectedLeagueId,
    required this.onLeague,
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
  final Sport sport;
  final List<LeaderboardLeague> leagues;
  final String selectedLeagueId;
  final ValueChanged<String> onLeague;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (type == LeaderboardType.matches) ...[
          _TournamentBoardTabs(
            active: tournamentBoard,
            onSelect: onTournamentBoard,
            accent: accent,
          ),
          if (tournamentBoard == TournamentBoard.players)
            _ScopeRow(
              scope: scope,
              onScope: onScope,
              sport: sport,
              leagues: leagues,
              selectedLeagueId: selectedLeagueId,
              onLeague: onLeague,
              accent: accent,
              compact: compact,
            ),
        ],
        if (type == LeaderboardType.games)
          _ModeTabs(mode: mode, onMode: onMode, sport: sport, accent: accent),
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

/// The players board's filter row: the league dial and the timeframe segments
/// share one line, so "which league" and "over what span" read as one question.
class _ScopeRow extends StatelessWidget {
  const _ScopeRow({
    required this.scope,
    required this.onScope,
    required this.sport,
    required this.leagues,
    required this.selectedLeagueId,
    required this.onLeague,
    required this.accent,
    required this.compact,
  });

  final TournamentScope scope;
  final ValueChanged<TournamentScope> onScope;
  final Sport sport;
  final List<LeaderboardLeague> leagues;
  final String selectedLeagueId;
  final ValueChanged<String> onLeague;
  final Color accent;
  final bool compact;

  static const double _height = 38;

  static const List<({TournamentScope scope, String label})> _items = [
    (scope: TournamentScope.weekly, label: 'WEEKLY'),
    (scope: TournamentScope.season, label: 'SEASON'),
    (scope: TournamentScope.allTime, label: 'ALL-TIME'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 6 : 10, 16, 0),
      child: SizedBox(
        height: _height,
        child: Row(
          children: [
            LeagueDial(
              // Rebuild cleanly when the sport swaps the whole catalogue out.
              key: ValueKey('league-dial-${sport.name}'),
              leagues: leagues,
              selectedId: selectedLeagueId,
              onSelect: onLeague,
              height: _height,
            ),
            const SizedBox(width: 8),
            Container(
              width: 1,
              height: 22,
              color: Cyber.line.withValues(alpha: 0.35),
            ),
            const SizedBox(width: 8),
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onScope(_items[i].scope),
                  child: Container(
                    margin: EdgeInsets.only(
                      right: i == _items.length - 1 ? 0 : 6,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 7,
                      horizontal: 2,
                    ),
                    alignment: Alignment.center,
                    decoration: cutCornerDecoration(
                      color: scope == _items[i].scope
                          ? accent.withValues(alpha: 0.14)
                          : Cyber.panel.withValues(alpha: 0.5),
                      borderColor: scope == _items[i].scope
                          ? accent
                          : Cyber.line.withValues(alpha: 0.35),
                      cut: 8,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _items[i].label,
                        maxLines: 1,
                        style: TextStyle(
                          color: scope == _items[i].scope
                              ? accent
                              : Cyber.muted,
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
      ),
    );
  }
}

class _ModeTabs extends StatelessWidget {
  const _ModeTabs({
    required this.mode,
    required this.onMode,
    required this.sport,
    required this.accent,
  });

  final GameMode mode;
  final ValueChanged<GameMode> onMode;
  final Sport sport;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        children: [
          for (final item in _gameModesFor(sport))
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
      case LeaderboardType.matches:
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
