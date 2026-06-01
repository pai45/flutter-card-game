import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_state.dart';
import '../../config/enums.dart';
import '../../config/theme.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/landing_bottom_navigation.dart';

// ─── Domain ──────────────────────────────────────────────────────────────────

enum LeaderboardType { matchDay, tournament, coins, games }

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
  });

  /// >0 climbed, <0 dropped, 0 held.
  final int rank;
  final String name;
  final int score;
  final int movement;
  final bool isNew;
  final String? badge;
  final bool isUser;
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

// Named users keep the exact scores from the brief; filler rivals are inserted
// above so the current user ("pai", 3870 XP, ↑3) lands at rank #12 — which keeps
// the sticky card + "Around Me" meaningful while honouring every given number.
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

typedef ScoreMeta = ({String unit, IconData icon});

ScoreMeta _scoreMeta(LeaderboardType type) => switch (type) {
  LeaderboardType.matchDay => (unit: 'XP', icon: Icons.bolt),
  LeaderboardType.tournament => (unit: 'XP', icon: Icons.military_tech),
  LeaderboardType.coins => (unit: 'OZ', icon: Icons.monetization_on),
  LeaderboardType.games => (unit: 'W', icon: Icons.sports_esports),
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

Color _avatarColor(String name) {
  const palette = [
    Cyber.cyan,
    Cyber.violet,
    Cyber.gold,
    Cyber.success,
    Cyber.magenta,
    Cyber.amber,
  ];
  var hash = 0;
  for (final unit in name.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return palette[hash % palette.length];
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  LeaderboardType _type = LeaderboardType.matchDay;
  String _sport = 'IPL';
  TournamentScope _scope = TournamentScope.weekly;
  GameMode _mode = GameMode.quiz;

  final ScrollController _scroll = ScrollController();
  final GlobalKey _userRowKey = GlobalKey();

  static const List<String> _sports = ['IPL', 'UCL', 'NBA', 'F1'];

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToUser() {
    final ctx = _userRowKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      alignment: 0.42,
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(_type);
    final entries = _entriesFor(_type, _scope, _mode);
    final user = _userEntry(entries);

    return BlocBuilder<GameBloc, GameState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Cyber.bg,
          body: CyberBackground(
            animated: true,
            child: SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 640;
                  final hidePinnedChrome = constraints.maxHeight < 500;

                  return Column(
                    children: [
                      _Header(coins: state.coins, accent: accent),
                      _TypeSelector(
                        active: _type,
                        onSelect: (type) => setState(() => _type = type),
                      ),
                      _FilterBar(
                        type: _type,
                        sports: _sports,
                        selectedSport: _sport,
                        onSport: (sport) => setState(() => _sport = sport),
                        scope: _scope,
                        onScope: (scope) => setState(() => _scope = scope),
                        mode: _mode,
                        onMode: (mode) => setState(() => _mode = mode),
                        accent: accent,
                        compact: compact,
                      ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          switchInCurve: Curves.easeOutCubic,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
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
                                  type: _type,
                                  accent: accent,
                                  onAction: widget.onNavigate,
                                )
                              : _Body(
                                  key: ValueKey(
                                    '${_type.name}-${_scope.name}-${_mode.name}',
                                  ),
                                  entries: entries,
                                  user: user,
                                  type: _type,
                                  accent: accent,
                                  scope: _scope,
                                  controller: _scroll,
                                  userRowKey: _userRowKey,
                                  onAction: widget.onNavigate,
                                  compact: compact,
                                ),
                        ),
                      ),
                      if (entries.isNotEmpty && !hidePinnedChrome) ...[
                        if (!compact)
                          _AroundMeButton(accent: accent, onTap: _scrollToUser),
                        _StickyUserCard(
                          user: user,
                          type: _type,
                          accent: accent,
                          compact: compact,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
          bottomNavigationBar: LandingBottomNavigation(
            selectedIndex: 2,
            onNavigate: widget.onNavigate,
          ),
        );
      },
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.coins, required this.accent});

  final int coins;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: accent.withValues(alpha: 0.22)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.emoji_events,
            color: Cyber.gold,
            size: 24,
            shadows: [
              Shadow(color: Cyber.gold.withValues(alpha: 0.6), blurRadius: 14),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'LEADERBOARD',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: Cyber.displayFont,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    letterSpacing: 1.6,
                    shadows: [
                      Shadow(
                        color: accent.withValues(alpha: 0.5),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
                Text(
                  '// CLIMB THE RANKS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent.withValues(alpha: 0.55),
                    fontFamily: Cyber.displayFont,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
              ],
            ),
          ),
          Flexible(child: _CoinPill(coins: coins)),
        ],
      ),
    );
  }
}

class _CoinPill extends StatelessWidget {
  const _CoinPill({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(
        color: Cyber.bg.withValues(alpha: 0.7),
        border: Border.all(color: Cyber.gold.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(color: Cyber.gold.withValues(alpha: 0.16), blurRadius: 14),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on, color: Cyber.gold, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _formatInt(coins),
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: Cyber.displayFont,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'OZ',
            style: TextStyle(
              color: Cyber.gold.withValues(alpha: 0.8),
              fontFamily: Cyber.displayFont,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Type selector ───────────────────────────────────────────────────────────

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.active, required this.onSelect});

  final LeaderboardType active;
  final ValueChanged<LeaderboardType> onSelect;

  static const List<({LeaderboardType type, String label, IconData icon})>
  _items = [
    (
      type: LeaderboardType.matchDay,
      label: 'MATCH DAY',
      icon: Icons.local_fire_department,
    ),
    (
      type: LeaderboardType.tournament,
      label: 'TOURNEY',
      icon: Icons.military_tech,
    ),
    (type: LeaderboardType.coins, label: 'COINS', icon: Icons.monetization_on),
    (type: LeaderboardType.games, label: 'GAMES', icon: Icons.sports_esports),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          for (final item in _items)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _TypeChip(
                  label: item.label,
                  icon: item.icon,
                  active: active == item.type,
                  accent: _accentFor(item.type),
                  onTap: () => onSelect(item.type),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? accent : Cyber.muted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          gradient: active
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [accent.withValues(alpha: 0.20), Cyber.panel2],
                )
              : null,
          color: active ? null : Cyber.panel.withValues(alpha: 0.5),
          border: Border.all(
            color: active ? accent : Cyber.line.withValues(alpha: 0.4),
            width: active ? 1.4 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.28),
                    blurRadius: 14,
                    spreadRadius: -4,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontFamily: Cyber.displayFont,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
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
                    const _CountdownCard(remaining: 'Ends 04h 12m'),
                ],
              ),
            ),
            if (showCountdownBelow)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _CountdownCard(remaining: 'Ends 04h 12m'),
                ),
              ),
            if (type == LeaderboardType.tournament)
              _ScopeToggle(
                scope: scope,
                onScope: onScope,
                accent: accent,
                compact: compact,
              ),
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
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.14) : Colors.transparent,
          border: Border.all(
            color: active ? accent : Cyber.line.withValues(alpha: 0.4),
          ),
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
                decoration: BoxDecoration(
                  color: Cyber.danger,
                  boxShadow: [
                    BoxShadow(
                      color: Cyber.danger.withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Cyber.amber.withValues(alpha: 0.18), Cyber.panel2],
        ),
        border: Border.all(color: Cyber.amber.withValues(alpha: 0.55)),
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
                  decoration: BoxDecoration(
                    color: scope == item.scope
                        ? accent.withValues(alpha: 0.14)
                        : Cyber.panel.withValues(alpha: 0.5),
                    border: Border.all(
                      color: scope == item.scope
                          ? accent
                          : Cyber.line.withValues(alpha: 0.35),
                    ),
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
                  decoration: BoxDecoration(
                    color: mode == item.mode
                        ? accent.withValues(alpha: 0.16)
                        : Colors.transparent,
                    border: Border.all(
                      color: mode == item.mode
                          ? accent
                          : Cyber.line.withValues(alpha: 0.4),
                    ),
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
    required this.entries,
    required this.user,
    required this.type,
    required this.accent,
    required this.scope,
    required this.controller,
    required this.userRowKey,
    required this.onAction,
    required this.compact,
    super.key,
  });

  final List<LeaderboardEntry> entries;
  final LeaderboardEntry user;
  final LeaderboardType type;
  final Color accent;
  final TournamentScope scope;
  final ScrollController controller;
  final GlobalKey userRowKey;
  final ValueChanged<AppSection> onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final meta = _scoreMeta(type);
    final podium = entries.take(3).toList();
    final rewardZone = entries
        .where((e) => e.rank >= 4 && e.rank <= 10)
        .toList();
    final eliteZone = entries.where((e) => e.rank > 10).toList();

    return SingleChildScrollView(
      controller: controller,
      padding: EdgeInsets.fromLTRB(16, compact ? 10 : 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _UserSummaryCard(user: user, type: type, accent: accent),
          SizedBox(height: compact ? 14 : 20),
          const _SectionLabel('TOP RANKS'),
          SizedBox(height: compact ? 10 : 12),
          _Podium(entries: podium, meta: meta),
          SizedBox(height: compact ? 14 : 20),
          _ZoneDivider(
            label: 'TOP 10 · REWARD ZONE',
            icon: Icons.workspace_premium,
            color: Cyber.gold,
          ),
          const SizedBox(height: 10),
          for (final entry in rewardZone)
            Padding(
              key: entry.isUser ? userRowKey : null,
              padding: const EdgeInsets.only(bottom: 8),
              child: _LeaderboardRow(entry: entry, accent: accent, meta: meta),
            ),
          const SizedBox(height: 8),
          _ZoneDivider(
            label: 'ELITE ZONE · TOP 100',
            icon: Icons.shield_moon,
            color: Cyber.violet,
          ),
          const SizedBox(height: 10),
          for (final entry in eliteZone)
            Padding(
              key: entry.isUser ? userRowKey : null,
              padding: const EdgeInsets.only(bottom: 8),
              child: _LeaderboardRow(entry: entry, accent: accent, meta: meta),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: Cyber.muted,
        fontFamily: Cyber.displayFont,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
      ),
    );
  }
}

// ─── User rank summary ───────────────────────────────────────────────────────

class _UserSummaryCard extends StatelessWidget {
  const _UserSummaryCard({
    required this.user,
    required this.type,
    required this.accent,
  });

  final LeaderboardEntry user;
  final LeaderboardType type;
  final Color accent;

  ({double pct, String label}) _milestone() {
    switch (type) {
      case LeaderboardType.matchDay:
        return (pct: user.score / 5000, label: 'ELITE TIER');
      case LeaderboardType.tournament:
        return (pct: 0.64, label: 'GOLD I');
      case LeaderboardType.coins:
        return (pct: user.score / 5000, label: 'NEXT VAULT');
      case LeaderboardType.games:
        return (pct: user.score / 100, label: 'VETERAN');
    }
  }

  List<({String label, String value})> _stats() {
    switch (type) {
      case LeaderboardType.matchDay:
        return const [
          (label: 'ACCURACY', value: '78%'),
          (label: 'WIN STREAK', value: '7'),
          (label: 'ANSWERED', value: '142'),
        ];
      case LeaderboardType.tournament:
        return const [
          (label: 'DIVISION', value: 'GOLD II'),
          (label: 'WIN STREAK', value: '7'),
          (label: 'PROMOS', value: '3'),
        ];
      case LeaderboardType.coins:
        return const [
          (label: 'PROFIT TODAY', value: '+320'),
          (label: 'BIGGEST WIN', value: '1,240'),
          (label: 'TRADES', value: '38'),
        ];
      case LeaderboardType.games:
        return const [
          (label: 'WINS', value: '70'),
          (label: 'WIN STREAK', value: '7'),
          (label: 'BEST MODE', value: 'DUEL'),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = _scoreMeta(type);
    final milestone = _milestone();
    final pct = milestone.pct.clamp(0.0, 1.0);

    return CyberPanel(
      accent: accent,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(name: user.name, size: 46, highlight: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'YOUR RANK',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: accent.withValues(alpha: 0.8),
                              fontFamily: Cyber.displayFont,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.6,
                            ),
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
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: Cyber.displayFont,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            shadows: [
                              Shadow(
                                color: accent.withValues(alpha: 0.5),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: Cyber.bodyFont,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 108),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _formatInt(user.score),
                        maxLines: 1,
                        style: TextStyle(
                          color: accent,
                          fontFamily: Cyber.displayFont,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Text(
                      meta.unit,
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.7),
                        fontFamily: Cyber.displayFont,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'NEXT: ${milestone.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Cyber.muted,
                    fontFamily: Cyber.displayFont,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(pct * 100).round()}%',
                style: TextStyle(
                  color: accent,
                  fontFamily: Cyber.displayFont,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _ProgressBar(pct: pct, accent: accent),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < _stats().length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _StatBlock(stat: _stats()[i], accent: accent),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.pct, required this.accent});

  final double pct;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Stack(
        children: [
          Container(height: 7, color: Cyber.bg.withValues(alpha: 0.7)),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: pct),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => FractionallySizedBox(
              widthFactor: value,
              child: Container(
                height: 7,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent.withValues(alpha: 0.7), accent],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.stat, required this.accent});

  final ({String label, String value}) stat;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: Cyber.bg.withValues(alpha: 0.5),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              stat.value,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: Cyber.displayFont,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            stat.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Cyber.muted,
              fontFamily: Cyber.displayFont,
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Podium ──────────────────────────────────────────────────────────────────

class _Podium extends StatelessWidget {
  const _Podium({required this.entries, required this.meta});

  final List<LeaderboardEntry> entries;
  final ScoreMeta meta;

  @override
  Widget build(BuildContext context) {
    if (entries.length < 3) return const SizedBox.shrink();
    final first = entries[0];
    final second = entries[1];
    final third = entries[2];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _PodiumCard(
            entry: second,
            meta: meta,
            color: Cyber.violet,
            height: 150,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PodiumCard(
            entry: first,
            meta: meta,
            color: Cyber.gold,
            height: 178,
            champion: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PodiumCard(
            entry: third,
            meta: meta,
            color: Cyber.amber,
            height: 150,
          ),
        ),
      ],
    );
  }
}

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({
    required this.entry,
    required this.meta,
    required this.color,
    required this.height,
    this.champion = false,
  });

  final LeaderboardEntry entry;
  final ScoreMeta meta;
  final Color color;
  final double height;
  final bool champion;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: champion ? 520 : 420),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 18),
          child: child,
        ),
      ),
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.22), Cyber.panel2],
          ),
          border: Border.all(
            color: color.withValues(alpha: champion ? 0.95 : 0.55),
            width: champion ? 1.8 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: champion ? 0.4 : 0.2),
              blurRadius: champion ? 22 : 14,
              spreadRadius: champion ? 1 : -2,
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (champion)
                Icon(
                  Icons.workspace_premium,
                  color: color,
                  size: 20,
                  shadows: [
                    Shadow(color: color.withValues(alpha: 0.7), blurRadius: 10),
                  ],
                )
              else
                Text(
                  '#${entry.rank}',
                  style: TextStyle(
                    color: color,
                    fontFamily: Cyber.displayFont,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              const SizedBox(height: 6),
              _Avatar(name: entry.name, size: champion ? 50 : 42, ring: color),
              const SizedBox(height: 7),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 86),
                child: Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: Cyber.displayFont,
                    fontSize: champion ? 12 : 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _formatInt(entry.score),
                style: TextStyle(
                  color: color,
                  fontFamily: Cyber.displayFont,
                  fontSize: champion ? 17 : 14,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                meta.unit,
                style: TextStyle(
                  color: color.withValues(alpha: 0.7),
                  fontFamily: Cyber.displayFont,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 5),
              _MovementBadge(movement: entry.movement, isNew: entry.isNew),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Zone divider ────────────────────────────────────────────────────────────

class _ZoneDivider extends StatelessWidget {
  const _ZoneDivider({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontFamily: Cyber.displayFont,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(height: 1, color: color.withValues(alpha: 0.25)),
        ),
      ],
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
    final rankColor = entry.rank <= 10 ? Cyber.gold : Cyber.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        gradient: isUser
            ? LinearGradient(
                colors: [accent.withValues(alpha: 0.18), Cyber.panel2],
              )
            : null,
        color: isUser ? null : Cyber.panel.withValues(alpha: 0.45),
        border: Border.all(
          color: isUser ? accent : Cyber.line.withValues(alpha: 0.3),
          width: isUser ? 1.4 : 1,
        ),
        boxShadow: isUser
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.28),
                  blurRadius: 16,
                  spreadRadius: -4,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '${entry.rank}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: rankColor,
                fontFamily: Cyber.displayFont,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _Avatar(name: entry.name, size: 34, highlight: isUser),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: Cyber.bodyFont,
                      fontSize: 14,
                      fontWeight: isUser ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (isUser)
                  const _Tag(label: 'YOU', color: Cyber.cyan)
                else if (entry.badge != null)
                  _Tag(label: entry.badge!, color: Cyber.violet),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _MovementBadge(movement: entry.movement, isNew: entry.isNew),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 82),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _formatInt(entry.score),
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
                    color: Cyber.muted,
                    fontFamily: Cyber.displayFont,
                    fontSize: 7,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
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

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: Cyber.displayFont,
          fontSize: 8,
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
  });

  final String name;
  final double size;
  final bool highlight;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final color = ring ?? _avatarColor(name);
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.35), Cyber.bg],
        ),
        border: Border.all(
          color: color.withValues(alpha: highlight ? 0.95 : 0.6),
          width: highlight ? 1.6 : 1,
        ),
        boxShadow: highlight
            ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12)]
            : null,
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontFamily: Cyber.displayFont,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

// ─── Around-me shortcut ──────────────────────────────────────────────────────

class _AroundMeButton extends StatelessWidget {
  const _AroundMeButton({required this.accent, required this.onTap});

  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              border: Border.all(color: accent.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.my_location, color: accent, size: 13),
                const SizedBox(width: 6),
                Text(
                  'AROUND ME',
                  style: TextStyle(
                    color: accent,
                    fontFamily: Cyber.displayFont,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
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

// ─── Sticky user position ────────────────────────────────────────────────────

class _StickyUserCard extends StatelessWidget {
  const _StickyUserCard({
    required this.user,
    required this.type,
    required this.accent,
    required this.compact,
  });

  final LeaderboardEntry user;
  final LeaderboardType type;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final meta = _scoreMeta(type);
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, compact ? 4 : 6),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.22), Cyber.panel],
        ),
        border: Border.all(color: accent, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.32),
            blurRadius: 18,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '#${user.rank}',
              style: TextStyle(
                color: accent,
                fontFamily: Cyber.displayFont,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _Avatar(name: user.name, size: 36, highlight: true),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: Cyber.bodyFont,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const _Tag(label: 'YOU', color: Cyber.cyan),
              ],
            ),
          ),
          _MovementBadge(movement: user.movement, isNew: user.isNew),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 82),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _formatInt(user.score),
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
                    color: accent.withValues(alpha: 0.7),
                    fontFamily: Cyber.displayFont,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
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

// ─── Empty states ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.type,
    required this.accent,
    required this.onAction,
    super.key,
  });

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
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              config.icon,
              color: accent.withValues(alpha: 0.7),
              size: 48,
              shadows: [
                Shadow(color: accent.withValues(alpha: 0.5), blurRadius: 18),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              config.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontFamily: Cyber.displayFont,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                shadows: [
                  Shadow(color: accent.withValues(alpha: 0.4), blurRadius: 10),
                ],
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
                decoration: BoxDecoration(
                  color: accent,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.5),
                      blurRadius: 16,
                    ),
                  ],
                ),
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
    );
  }
}
