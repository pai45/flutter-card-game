import re

with open('lib/screens/leaderboard/leaderboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Imports
content = content.replace(
    "import '../../config/enums.dart';",
    "import '../../config/enums.dart';\nimport '../../config/sport_modules.dart';"
)
content = content.replace(
    "import '../../utils/sound_effects.dart';",
    "import '../../utils/sound_effects.dart';\nimport '../../widgets/cyber/cyber_underline_tabs.dart';"
)

# 2. Enums and constants
content = content.replace(
    "enum LeaderboardType { matchDay, tournament, coins, games }",
    "enum LeaderboardType { matchDay, tournament, games }"
)
content = content.replace(
    "const List<LeaderboardType> _typeTabOrder = [\n  LeaderboardType.matchDay,\n  LeaderboardType.tournament,\n  LeaderboardType.coins,\n  LeaderboardType.games,\n];",
    "const List<LeaderboardType> _typeTabOrder = [\n  LeaderboardType.matchDay,\n  LeaderboardType.tournament,\n  LeaderboardType.games,\n];\n\nconst List<Sport> _leaderboardSports = [\n  Sport.football,\n  Sport.cricket,\n  Sport.basketball,\n  Sport.tennis,\n  Sport.f1,\n];\n\nfinal _leaderboardSportLabels = _leaderboardSports\n    .map((sport) => sportModuleFor(sport).label.toUpperCase())\n    .toList(growable: false);\n\nfinal _leaderboardSportIcons = _leaderboardSports\n    .map((sport) => sportModuleFor(sport).icon)\n    .toList(growable: false);"
)
content = content.replace(
    "static const List<String> _items = ['MATCH DAY', 'TOURNEY', 'COINS', 'GAMES'];",
    "static const List<String> _items = ['MATCH DAY', 'TOURNEY', 'GAMES'];"
)

# 3. State variables
content = content.replace(
    "String _sport = 'Football';",
    "Sport _sport = Sport.football;"
)

# 4. FilterBar layout swap
# I will use a regex to replace the LayoutBuilder inside build
layout_regex = re.compile(r'SafeArea\([^\]]+?final compact = constraints\.maxHeight < 640;', re.DOTALL)
new_layout = """SafeArea(
            top: false,
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 640;"""

# Replace the layout logic
content = content.replace(
    '''                final filters = _FilterBar(
                  type: _type,
                  sports: const [
                    'Football',
                    'Cricket',
                    'Basketball',
                    'Tennis',
                    'F1'
                  ],
                  selectedSport: _sport,
                  onSport: (sport) => setState(() => _sport = sport),
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
                    _LeaderboardTabs(
                      activeTab: _typeTabOrder.indexOf(_type),
                      indicatorAnimation: _typeTabIndicatorAnimation,
                      accent: accent,
                      onTap: _setTypeTab,
                    ),
                    Expanded(''',
    '''                final activeSportIndex = _leaderboardSports.indexOf(_sport);
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
                    Expanded('''
)

# 5. Fix _Body key
content = content.replace(
    "'----',",
    "'----',"
)
content = content.replace(
    "final accent = sportModuleFor(_sport == 'Football' ? Sport.football : _sport == 'Cricket' ? Sport.cricket : _sport == 'Basketball' ? Sport.basketball : _sport == 'Tennis' ? Sport.tennis : Sport.f1).accent;",
    "final accent = sportModuleFor(_sport).accent;"
)

# 6. Replace FilterBar and SportChip
filterbar_regex = re.compile(r'class _FilterBar extends StatelessWidget \{.*?class _SportChip extends StatelessWidget \{.*?\}\n\}', re.DOTALL)
new_filter_bar = '''class _LeaderboardSportsTabs extends StatelessWidget {
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
              child: _CountdownCard(remaining: '04h 12m'),
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
}'''

content = filterbar_regex.sub(new_filter_bar, content)

# 7. Remove coins from EmptyState
empty_state_regex = re.compile(r"      case LeaderboardType\.coins:.*?target: AppSection\.shop,\n        \);", re.DOTALL)
content = empty_state_regex.sub("", content)

with open('lib/screens/leaderboard/leaderboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Done")
