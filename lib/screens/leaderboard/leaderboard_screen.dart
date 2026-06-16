import 'package:flutter/material.dart';

import '../../config/enums.dart';
import '../../config/theme.dart';
import '../../models/avatar_option.dart';
import '../../models/sport_match.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/landing_bottom_navigation.dart';
import '../../widgets/stat_oz_top_bar.dart';
import '../../widgets/staggered_card_entrance.dart';
import '../../widgets/team_logo.dart';

// ─── Domain ──────────────────────────────────────────────────────────────────

enum LeaderboardType { matchDay, tournament, coins, games }

// Matches shop tab styling (_ShopTabs / _TabItem).
const Color _tabBarBg = Cyber.bg;
const Color _tabCyan = Cyber.cyan;
const Color _tabSecondary = AppTheme.slate400;

const List<LeaderboardType> _typeTabOrder = [
  LeaderboardType.matchDay,
  LeaderboardType.tournament,
  LeaderboardType.coins,
  LeaderboardType.games,
];

enum TournamentBoard { players, teams }

enum TournamentScope { weekly, season, allTime }

enum GameMode { quiz, cardDuel, streaks, accuracy }

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.score,
    required this.movement,
    this.isNew = false,
    this.badge,
    this.isUser = false,
    this.team,
  });

  /// >0 climbed, <0 dropped, 0 held.
  final int rank;
  final String name;
  final int score;
  final int movement;
  final bool isNew;
  final String? badge;
  final bool isUser;
  final SportTeam? team;
}

class _Seed {
  const _Seed(
    this.name,
    this.base,
    this.movement, {
    this.isNew = false,
    this.badge,
    this.isUser = false,
  });

  final String name;
  final int base;
  final int movement;
  final bool isNew;
  final String? badge;
  final bool isUser;
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

// Named users keep the exact scores from the brief; filler rivals are inserted
// above so the current user ("pai", 3870 XP, ↑3) lands at rank #12.
const List<_Seed> _board = [
  _Seed('jarvis', 3910, -1, badge: 'PRO'),
  _Seed('Vortex', 3905, 2),
  _Seed('NeoStrike', 3901, -1, badge: 'PRO'),
  _Seed('PhantomX', 3897, 1),
  _Seed('Blaze', 3893, 4),
  _Seed('Titan', 3889, -2),
  _Seed('EchoZero', 3885, 1, badge: 'PRO'),
  _Seed('Reaper', 3881, -3),
  _Seed('NovaQ', 3878, 2),
  _Seed('Falcon9', 3874, -1),
  _Seed('Striker', 3872, 5, isNew: true),
  _Seed('pai', 3870, 3, isUser: true), // rank 12 — current user
  _Seed('Diwakar', 3860, -2),
  _Seed('monika', 3830, 1, badge: 'PRO'),
  _Seed('Raja2000', 3740, -1),
  _Seed('Invincible51', 3670, 4),
  _Seed('rocky', 3380, -2),
  _Seed('Mirage', 3120, 1),
  _Seed('Zenith', 2980, -1, isNew: true),
  _Seed('Ghost', 2810, 2),
  _Seed('Drift', 2640, -3),
  _Seed('Volt', 2470, 1),
  _Seed('Comet', 2300, -1),
  _Seed('Rookie7', 1980, 0, isNew: true),
];

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

typedef ScoreMeta = ({String unit});

ScoreMeta _scoreMeta(LeaderboardType type) => switch (type) {
  LeaderboardType.matchDay => (unit: 'XP'),
  LeaderboardType.tournament => (unit: 'XP'),
  LeaderboardType.coins => (unit: 'OZ'),
  LeaderboardType.games => (unit: 'W'),
};

Color _accentFor(LeaderboardType type) =>
    type == LeaderboardType.coins ? Cyber.gold : Cyber.cyan;

int _scoreFor(
  LeaderboardType type,
  int base,
  TournamentScope scope,
  GameMode mode,
) {
  switch (type) {
    case LeaderboardType.matchDay:
    case LeaderboardType.coins:
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
    for (var i = 0; i < _board.length; i++)
      LeaderboardEntry(
        rank: i + 1,
        name: _board[i].name,
        score: _scoreFor(type, _board[i].base, scope, mode),
        movement: _board[i].movement,
        isNew: _board[i].isNew,
        badge: _board[i].badge,
        isUser: _board[i].isUser,
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

String _formatInt(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${value < 0 ? '-' : ''}$buffer';
}

ShapeDecoration _cutDecoration({
  required Color color,
  Color borderColor = Colors.transparent,
  double borderWidth = 1,
  double cut = 14,
}) {
  return ShapeDecoration(
    color: color,
    shape: _CutCornerBorder(
      cut: cut,
      side: BorderSide(color: borderColor, width: borderWidth),
    ),
  );
}

class _CutCornerBorder extends ShapeBorder {
  const _CutCornerBorder({required this.cut, this.side = BorderSide.none});

  final double cut;
  final BorderSide side;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  ShapeBorder scale(double t) {
    return _CutCornerBorder(cut: cut * t, side: side.scale(t));
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return getOuterPath(rect.deflate(side.width), textDirection: textDirection);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final safeCut = cut.clamp(0, rect.shortestSide / 2).toDouble();
    return Path()
      ..moveTo(rect.left + safeCut, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.bottom - safeCut)
      ..lineTo(rect.right - safeCut, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top + safeCut)
      ..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width <= 0) return;
    final paint = side.toPaint()..style = PaintingStyle.stroke;
    canvas.drawPath(getOuterPath(rect, textDirection: textDirection), paint);
  }
}

AvatarOption _avatarForName(String name) {
  var hash = 0;
  for (final unit in name.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return avatarOptions[hash % avatarOptions.length];
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with TickerProviderStateMixin {
  LeaderboardType _type = LeaderboardType.matchDay;
  TournamentBoard _tournamentBoard = TournamentBoard.teams;
  String _sport = 'FIFA';
  TournamentScope _scope = TournamentScope.weekly;
  GameMode _mode = GameMode.quiz;

  static const List<String> _sports = ['FIFA', 'IPL', 'UCL', 'NBA', 'F1'];

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

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(_type);
    final isTeamTournament =
        _type == LeaderboardType.tournament &&
        _tournamentBoard == TournamentBoard.teams;
    final entries = isTeamTournament
        ? _teamEntriesFor()
        : _entriesFor(_type, _scope, _mode);
    final user = _userEntry(entries);

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
                final filters = _FilterBar(
                  type: _type,
                  sports: _sports,
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
                      onAddCoins: () => widget.onNavigate(AppSection.shop),
                    ),
                    _LeaderboardTabs(
                      activeTab: _typeTabOrder.indexOf(_type),
                      indicatorAnimation: _typeTabIndicatorAnimation,
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
                              ),
                      ),
                    ),
                    if (entries.isNotEmpty)
                      _UserRankBar(user: user, type: _type, accent: accent),
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
    required this.onTap,
  });

  final int activeTab;
  final Animation<double> indicatorAnimation;
  final ValueChanged<int> onTap;

  static const List<String> _items = ['MATCH DAY', 'TOURNEY', 'COINS', 'GAMES'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: _tabBarBg.withValues(alpha: 0.4),
        border: Border(
          bottom: BorderSide(color: _tabCyan.withValues(alpha: 0.22)),
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
                        onTap: () => onTap(index),
                        child: _LeaderboardTabItem(
                          label: _items[index],
                          active: activeTab == index,
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
                    color: _tabCyan,
                    boxShadow: [
                      BoxShadow(
                        color: _tabCyan.withValues(alpha: 0.7),
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
  const _LeaderboardTabItem({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final Color color = active ? _tabCyan : _tabSecondary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: active ? _tabCyan.withValues(alpha: 0.07) : Colors.transparent,
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
  const _Pressable({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

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
                        color: _tabCyan.withValues(alpha: 0.25),
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

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.type,
    required this.sports,
    required this.selectedSport,
    required this.onSport,
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
  final List<String> sports;
  final String selectedSport;
  final ValueChanged<String> onSport;
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final showCountdownInline =
            type == LeaderboardType.matchDay && constraints.maxWidth >= 360;
        final showCountdownBelow =
            type == LeaderboardType.matchDay &&
            !showCountdownInline &&
            !compact;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, compact ? 6 : 10, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final sport in sports)
                            Padding(
                              padding: const EdgeInsets.only(right: 7),
                              child: _SportChip(
                                label: sport,
                                active: sport == selectedSport,
                                live:
                                    type == LeaderboardType.matchDay &&
                                    sport == selectedSport,
                                accent: accent,
                                onTap: () => onSport(sport),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (showCountdownInline)
                    const _CountdownCard(remaining: '04h 12m'),
                ],
              ),
            ),
            if (showCountdownBelow)
              const Padding(
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
      },
    );
  }
}

class _SportChip extends StatelessWidget {
  const _SportChip({
    required this.label,
    required this.active,
    required this.live,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool live;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? accent : Cyber.muted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: _cutDecoration(
          color: active ? accent.withValues(alpha: 0.14) : Colors.transparent,
          borderColor: active
              ? accent.withValues(alpha: 0.72)
              : Cyber.line.withValues(alpha: 0.28),
          cut: 8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontFamily: Cyber.displayFont,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            if (live) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: _cutDecoration(color: Cyber.danger, cut: 3),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: Cyber.displayFont,
                    fontSize: 7,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({required this.remaining});

  final String remaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: _cutDecoration(
        color: Cyber.amber.withValues(alpha: 0.14),
        borderColor: Cyber.amber.withValues(alpha: 0.55),
        cut: 8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, color: Cyber.amber, size: 13),
          const SizedBox(width: 5),
          Text(
            remaining,
            style: const TextStyle(
              color: Cyber.amber,
              fontFamily: Cyber.displayFont,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
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
                  decoration: _cutDecoration(
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
                  decoration: _cutDecoration(
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
                  decoration: _cutDecoration(
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
    super.key,
  });

  final Widget filters;
  final List<LeaderboardEntry> entries;
  final LeaderboardType type;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final meta = entries.isNotEmpty && entries.first.team != null
        ? (unit: 'PTS')
        : _scoreMeta(type);
    final podium = entries.take(3).toList();
    final remaining = entries.skip(3).toList();

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
                _Podium(
                  entries: podium,
                  meta: meta,
                  accent: accent,
                  animateCards: true,
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
                        child: _LeaderboardRow(
                          entry: remaining[i],
                          accent: accent,
                          meta: meta,
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

// ─── Pinned user rank bar ────────────────────────────────────────────────────

class _UserRankBar extends StatelessWidget {
  const _UserRankBar({
    required this.user,
    required this.type,
    required this.accent,
  });

  final LeaderboardEntry user;
  final LeaderboardType type;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final meta = user.team != null ? (unit: 'PTS') : _scoreMeta(type);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Cyber.bg,
        border: Border(
          top: BorderSide(color: Cyber.line.withValues(alpha: 0.32)),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: _cutDecoration(
          color: accent.withValues(alpha: 0.1),
          borderColor: accent.withValues(alpha: 0.34),
          cut: 18,
        ),
        child: Row(
          children: [
            _Avatar(
              name: user.name,
              size: 54,
              highlight: true,
              team: user.team,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Your rank',
                        style: TextStyle(
                          color: accent.withValues(alpha: 0.85),
                          fontFamily: Cyber.displayFont,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _MovementBadge(
                        movement: user.movement,
                        isNew: user.isNew,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '#${user.rank}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: Cyber.displayFont,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: Cyber.bodyFont,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _AnimatedScoreText(
                  key: ValueKey('user-${type.name}-${user.score}-${meta.unit}'),
                  value: user.score,
                  style: TextStyle(
                    color: accent,
                    fontFamily: Cyber.displayFont,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  meta.unit.toLowerCase(),
                  style: TextStyle(
                    color: accent.withValues(alpha: 0.7),
                    fontFamily: Cyber.displayFont,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
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

// ─── Podium ──────────────────────────────────────────────────────────────────

class _Podium extends StatelessWidget {
  const _Podium({
    required this.entries,
    required this.meta,
    required this.accent,
    required this.animateCards,
  });

  final List<LeaderboardEntry> entries;
  final ScoreMeta meta;
  final Color accent;
  final bool animateCards;

  @override
  Widget build(BuildContext context) {
    if (entries.length < 3) return const SizedBox.shrink();
    final first = entries[0];
    final second = entries[1];
    final third = entries[2];
    return Column(
      children: [
        StaggeredCardEntrance(
          index: 0,
          animate: animateCards,
          maxAnimatedIndex: entries.length,
          child: _WinnerTile(
            entry: first,
            meta: meta,
            color: Cyber.gold,
            avatarSize: 86,
            primary: true,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StaggeredCardEntrance(
                index: 1,
                animate: animateCards,
                maxAnimatedIndex: entries.length,
                child: _WinnerTile(
                  entry: second,
                  meta: meta,
                  color: accent,
                  avatarSize: 66,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StaggeredCardEntrance(
                index: 2,
                animate: animateCards,
                maxAnimatedIndex: entries.length,
                child: _WinnerTile(
                  entry: third,
                  meta: meta,
                  color: Cyber.amber,
                  avatarSize: 66,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WinnerTile extends StatelessWidget {
  const _WinnerTile({
    required this.entry,
    required this.meta,
    required this.color,
    required this.avatarSize,
    this.primary = false,
  });

  final LeaderboardEntry entry;
  final ScoreMeta meta;
  final Color color;
  final double avatarSize;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(primary ? 16 : 12),
      decoration: _cutDecoration(
        color: primary
            ? Cyber.panel.withValues(alpha: 0.84)
            : Cyber.panel.withValues(alpha: 0.58),
        borderColor: color.withValues(alpha: primary ? 0.42 : 0.26),
        cut: primary ? 18 : 13,
      ),
      child: primary
          ? Row(
              children: [
                _Avatar(
                  name: entry.name,
                  size: avatarSize,
                  ring: color,
                  team: entry.team,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _WinnerCopy(entry: entry, color: color),
                ),
                const SizedBox(width: 12),
                _WinnerScore(score: entry.score, unit: meta.unit, color: color),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '#${entry.rank}',
                      style: TextStyle(
                        color: color,
                        fontFamily: Cyber.displayFont,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _MovementBadge(
                      movement: entry.movement,
                      isNew: entry.isNew,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _Avatar(
                      name: entry.name,
                      size: avatarSize,
                      ring: color,
                      team: entry.team,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: Cyber.bodyFont,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _AnimatedScoreText(
                            key: ValueKey(
                              'winner-${entry.rank}-${entry.score}-${meta.unit}',
                            ),
                            value: entry.score,
                            suffix: ' ${meta.unit}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color,
                              fontFamily: Cyber.displayFont,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _WinnerCopy extends StatelessWidget {
  const _WinnerCopy({required this.entry, required this.color});

  final LeaderboardEntry entry;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '#${entry.rank}',
              style: TextStyle(
                color: color,
                fontFamily: Cyber.displayFont,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.workspace_premium, color: Cyber.gold, size: 18),
            const SizedBox(width: 8),
            _MovementBadge(movement: entry.movement, isNew: entry.isNew),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          entry.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: Cyber.bodyFont,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.05,
          ),
        ),
        if (entry.badge != null) ...[
          const SizedBox(height: 8),
          _Tag(label: entry.badge!, color: color),
        ],
      ],
    );
  }
}

class _WinnerScore extends StatelessWidget {
  const _WinnerScore({
    required this.score,
    required this.unit,
    required this.color,
  });

  final int score;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 98),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: _AnimatedScoreText(
              key: ValueKey('podium-$score-$unit'),
              value: score,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontFamily: Cyber.displayFont,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              color: color.withValues(alpha: 0.72),
              fontFamily: Cyber.displayFont,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── List row ────────────────────────────────────────────────────────────────

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.entry,
    required this.accent,
    required this.meta,
  });

  final LeaderboardEntry entry;
  final Color accent;
  final ScoreMeta meta;

  @override
  Widget build(BuildContext context) {
    final isUser = entry.isUser;
    final rankColor = entry.rank <= 3 ? Cyber.gold : Cyber.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: _cutDecoration(
        color: isUser
            ? accent.withValues(alpha: 0.1)
            : Cyber.panel.withValues(alpha: 0.34),
        borderColor: isUser
            ? accent.withValues(alpha: 0.5)
            : Colors.transparent,
        cut: 12,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '#${entry.rank}',
              textAlign: TextAlign.left,
              style: TextStyle(
                color: rankColor,
                fontFamily: Cyber.displayFont,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _Avatar(
            name: entry.name,
            size: 48,
            highlight: isUser,
            team: entry.team,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: Cyber.bodyFont,
                          fontSize: 15,
                          fontWeight: isUser
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isUser) ...[
                      const SizedBox(width: 7),
                      const _Tag(label: 'YOU', color: Cyber.cyan),
                    ] else if (entry.badge != null) ...[
                      const SizedBox(width: 7),
                      _Tag(label: entry.badge!, color: Cyber.violet),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                _MovementBadge(movement: entry.movement, isNew: entry.isNew),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 86),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _AnimatedScoreText(
                    key: ValueKey(
                      'row-${entry.rank}-${entry.score}-${meta.unit}',
                    ),
                    value: entry.score,
                    maxLines: 1,
                    style: TextStyle(
                      color: accent,
                      fontFamily: Cyber.displayFont,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Text(
                  meta.unit,
                  style: TextStyle(
                    color: Cyber.muted.withValues(alpha: 0.82),
                    fontFamily: Cyber.displayFont,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
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

class _AnimatedScoreText extends StatelessWidget {
  const _AnimatedScoreText({
    required this.value,
    required this.style,
    this.suffix = '',
    this.maxLines,
    this.overflow,
    super.key,
  });

  final int value;
  final TextStyle style;
  final String suffix;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery?.disableAnimations ?? false) {
      return _buildText(value);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, current, _) => _buildText(current.round()),
    );
  }

  Widget _buildText(int current) {
    return Text(
      '${_formatInt(current)}$suffix',
      maxLines: maxLines,
      overflow: overflow,
      style: style,
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: _cutDecoration(
        color: color.withValues(alpha: 0.16),
        borderColor: color.withValues(alpha: 0.7),
        cut: 4,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: Cyber.displayFont,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─── Movement badge ──────────────────────────────────────────────────────────

class _MovementBadge extends StatelessWidget {
  const _MovementBadge({required this.movement, required this.isNew});

  final int movement;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    if (isNew) {
      return _pill('NEW', Cyber.gold);
    }
    if (movement > 0) {
      return _pill('▲$movement', Cyber.success);
    }
    if (movement < 0) {
      return _pill('▼${-movement}', Cyber.danger);
    }
    return Text(
      '—',
      style: TextStyle(
        color: Cyber.muted,
        fontFamily: Cyber.displayFont,
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Text(
      label,
      style: TextStyle(
        color: color,
        fontFamily: Cyber.displayFont,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.3,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

// ─── Avatar ──────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.name,
    required this.size,
    this.highlight = false,
    this.ring,
    this.team,
  });

  final String name;
  final double size;
  final bool highlight;
  final Color? ring;
  final SportTeam? team;

  @override
  Widget build(BuildContext context) {
    if (team != null) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: TeamLogo(
            team: team!,
            width: size,
            height: size,
            cutBottomRight: false,
          ),
        ),
      );
    }

    final color = ring ?? (highlight ? Cyber.cyan : Cyber.line);
    final avatar = _avatarForName(name);
    final borderWidth = highlight ? 2.0 : 1.2;
    final borderColor = color.withValues(alpha: highlight ? 0.9 : 0.42);

    return SizedBox(
      width: size,
      height: size,
      child: ClipPath(
        clipper: const OctagonClipper(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Cyber.panel),
            Image.asset(
              avatar.assetPath,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
            CustomPaint(
              painter: OctagonBorderPainter(
                color: borderColor,
                strokeWidth: borderWidth,
              ),
            ),
          ],
        ),
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
      case LeaderboardType.coins:
        return (
          icon: Icons.lock_outline,
          title: 'COINS LEADERBOARD LOCKED',
          body: 'Unlocks after your first trade.',
          cta: 'EXPLORE PICKS',
          target: AppSection.shop,
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
                      decoration: _cutDecoration(color: accent, cut: 10),
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
