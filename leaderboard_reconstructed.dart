import 'package:flutter/material.dart';
import 
import 'package:flutter_bloc/flutter_bloc.dart';

import 
import '../../config/enums.dart';
import 
import '../../config/theme.dart';
import 
import '../../models/avatar_frame_option.dart';
import 
import '../../utils/sound_effects.dart';
import 
import '../../widgets/cyber/cyber_widgets.dart';
import 
import '../../widgets/stat_oz_top_bar.dart';
import 
import '../profile/rival_profile_screen.dart';
import 

// ─── Domain 

enum LeaderboardType { matchDay, 

// Matches shop tab styling (_ShopTabs / _TabItem).
const Color _tabBarBg = 
const Color _tabSecondary = AppTheme.slate400;

const List<LeaderboardType> 
  LeaderboardType.matchDay,
  LeaderboardType.tournament,
  
];

const List<Sport> _leaderboardSports = [
  
  Sport.cricket,
  Sport.basketball,
  Sport.tennis,
  Sport.f1,


final _leaderboardSportLabels = _leaderboardSports
    .map((sport) => 
    .toList(growable: false);

final 
    .map((sport) => sportModuleFor(sport).icon)
    

enum TournamentBoard { players, teams }

enum TournamentScope { 

enum GameMode { quiz, cardDuel, streaks, accuracy }

class 
  const LeaderboardEntry({
    required this.rank,
    required 
    required this.score,
    required this.movement,
    this.isNew = false,
   
    this.isUser = false,
    this.team,
    this.xp = 0,
  });


  final int rank;
  final String name;
  final int 
  final int movement;
  final bool isNew;
  final String? badge;
  final bool 
  final SportTeam? team;

  /// The player's canonical XP (their `_Seed.base`), 
  /// board type/scope — drives the rival dossier's level and XP meter.
  
}

class _TeamSeed {
  const _TeamSeed({
    required 
    required this.score,
    required this.movement,
    this.isUser = false,
  

  final SportTeam team;
  final int score;
  final int movement;
  final bool 
}

const List<_TeamSeed> _teams = [
  _TeamSeed(
    team: 
      id: 'fra',
      name: 'France',
      shortName: 'FRA',
      color: 
    ),
    score: 1877,
    movement: 2,
  ),
  
    team: SportTeam(
      id: 'esp',
      name: 'Spain',
      shortName: 
      color: Color(0xffd71920),
    ),
    score: 1876,
    movement: 
  ),
  _TeamSeed(
    team: SportTeam(
      id: 'arg',
      name: 
      shortName: 'ARG',
      color: Color(0xff74acdf),
    ),
    score: 
    movement: -1,
    isUser: true,
  ),
  _TeamSeed(
    team: 
      id: 'eng',
      name: 'England',
      shortName: 'ENG',
      
    ),
    score: 1813,
    movement: 0,
  ),
  
    team: SportTeam(
      id: 'por',
      name: 'Portugal',
      
      color: Color(0xff006600),
    ),
    score: 1764,
    
  ),
  _TeamSeed(
    team: SportTeam(
      id: 'bra',
      
      shortName: 'BRA',
      color: Color(0xffffdf00),
    ),
    
    movement: -1,
  ),
  _TeamSeed(
    team: SportTeam(
      
      name: 'Netherlands',
      shortName: 'NED',
      color: 
    ),
    score: 1756,
    movement: 0,
  ),
  
    team: SportTeam(
      id: 'mar',
      name: 'Morocco',
      
      color: Color(0xffc1272d),
    ),
    score: 1738,
    
  ),
  _TeamSeed(
    team: SportTeam(
      id: 'bel',
      
      shortName: 'BEL',
      color: Color(0xfffdda24),
    ),
    
    movement: 0,
  ),
  _TeamSeed(
    team: SportTeam(
      id: 
      name: 'Germany',
      shortName: 'GER',
      color: Color(0xff111111),
 
    score: 1730,
    movement: 0,
  ),
  _TeamSeed(
    team: 
      id: 'cro',
      name: 'Croatia',
      shortName: 'CRO',
      
    ),
    score: 1717,
    movement: 1,
  ),
  
    team: SportTeam(
      id: 'mex',
      name: 'Mexico',
      
      color: Color(0xff006847),
    ),
    score: 1706,
    
  ),
  _TeamSeed(
    team: SportTeam(
      id: 'usa',
      
      shortName: 'USA',
      color: Color(0xff3c3b6e),
    ),
 
    movement: 2,
  ),
  _TeamSeed(
    team: SportTeam(
      
      name: 'Uruguay',
      shortName: 'URU',
      color: 
    ),
    score: 1687,
    movement: -1,
  ),
  
    team: SportTeam(
      id: 'col',
      name: 'Colombia',
      
      color: Color(0xffffd100),
    ),
    score: 1684,
    
  ),
  _TeamSeed(
    team: SportTeam(
      id: 'jpn',
      
      shortName: 'JPN',
      color: Color(0xff0033a0),
    ),
    
    movement: 0,
  ),
];

typedef ScoreMeta = ({String 

ScoreMeta _scoreMeta(LeaderboardType type) => switch (type) {
  
  LeaderboardType.tournament => (unit: 'XP'),
  
};

int _scoreFor(
  LeaderboardType 
  int base,
  TournamentScope scope,
  GameMode mode,
) {
  switch 
    case LeaderboardType.matchDay:
      return base;
    case 
      return switch (scope) {
        TournamentScope.weekly => 
        TournamentScope.season => base * 6,
        TournamentScope.allTime => base * 
      };
    case LeaderboardType.games:
      return (base / 55).round() + 
  }
}

List<LeaderboardEntry> _entriesFor(
  LeaderboardType 
  TournamentScope scope,
  GameMode mode,
) {
  return [
    for (var i 
      LeaderboardEntry(
        rank: i + 1,
        name: 
        score: _scoreFor(type, kRivalRoster[i].base, scope, mode),
        
        isNew: kRivalRoster[i].isNew,
        badge: 
        isUser: kRivalRoster[i].isUser,
        xp: 
      ),
  ];
}

List<LeaderboardEntry> 
  return [
    for (var i = 0; i < _teams.length; i++)
      
        rank: i + 1,
        name: _teams[i].team.name,
        score: 
        movement: _teams[i].movement,
        isNew: false,
        badge: 
        isUser: _teams[i].isUser,
        team: _teams[i].team,
     
  ];
}

LeaderboardEntry _userEntry(List<LeaderboardEntry> entries) =>
    

/// Pushes the cinematic dossier for 
/// the leaderboard rows/podium and the profile friends roster; a 
/// unknown name. [onChallenge] enables the dossier's CHALLENGE action (null
/// hides it 
void showRivalDossier(
  BuildContext context,
  
  void Function(String opponentName, int opponentLevel)? onChallenge,
}) {
  
  if (index < 0) return;
  final seed = 
  final userIndex = kRivalRoster.indexWhere((s) => s.isUser);
  
    PageRouteBuilder<void>(
      transitionDuration: const 
      reverseTransitionDuration: const Duration(milliseconds: 240),
      
        name: seed.name,
        rank: index + 
        xp: seed.base,
        pro: seed.badge == 'PRO',
        userRank: userIndex < 0 ? 
        onChallenge: onChallenge,
      ),
      
        final curved = CurvedAnimation(
          
          curve: Curves.easeOutCubic,
        );
        return 
          opacity: curved,
          child: ScaleTransition(
            
            child: child,
          
        );
      },
    ),
  );
}

String _formatInt(int 
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var 
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    
  }
  return '${value < 0 ? '-' : ''}$buffer';
}

// 

class LeaderboardScreen 
  const LeaderboardScreen({
    required this.onNavigate,
    
    this.onChallenge,
    super.key,
  });

  final 
  final VoidCallback? onAddCoins;

  /// Launches a card 
  /// (name, level). Null when challenge isn't available (e.g. 
  /// leaderboard), in which case the dossier hides its CHALLENGE action.
  final void 

  @override
  
}

class 
    with TickerProviderStateMixin {
  
  TournamentBoard _tournamentBoard = 
  Sport _sport = Sport.football;
  TournamentScope _scope = 
  GameMode _mode = GameMode.quiz;

  late final AnimationController 
  late Animation<double> _typeTabIndicatorAnimation;
  int 

  @override
  void initState() {
    super.initState();

      vsync: this,
      duration: const 
      value: 0,
    );
    _typeTabIndicatorAnimation = 
      _typeTabOrder.indexOf(_type).toDouble(),
    );
  

  @override
  void dispose() {
    _typeTabIndicatorController.dispose();
  
  }

  void _setTypeTab(int index) {
    final type = 
    if (type == _type) return;
    _previousTypeTab = 
    _typeTabIndicatorAnimation =
        Tween<double>(
         
          end: index.toDouble(),
        ).animate(
      
            parent: _typeTabIndicatorController,
            curve: 
          ),
        );
    _typeTabIndicatorController.forward(from: 
    setState(() => _type = type);
  }

  /// Open a rival's dossier (or jump to 
  /// rows have no player profile, so they're inert.
  void 
    if (entry.team != null) return;
    if (entry.isUser) 
      playSound(SoundEffect.uiTap);
      HapticFeedback.selectionClick();
      
      return;
    }
    showRivalDossier(context, 
  }

  @override
  Widget 
    final accent = sportModuleFor(_sport).accent;
    final 
        _type == LeaderboardType.tournament &&
        _tournamentBoard == 
    final allEntries = isTeamTournament
        ? _teamEntriesFor()
    
    final user = _userEntry(allEntries);
    final entries = 

    return Scaffold(
      backgroundColor: Cyber.bg,
      body: 
        children: [
          const Positioned.fill(child: ColoredBox(color: 
          const Positioned.fill(child: CyberTextureOverlay()),
          SafeArea(

            bottom: false,
            child: LayoutBuilder(
          
                final compact = constraints.maxHeight < 640;
    
                  type: _type,
                  
                  onSport: (sport) => setState(() => _sport = sport),
          
                  onScope: (scope) => setState(() => _scope = scope),
          
                  onTournamentBoard: (board) =>
            
                  mode: _mode,
                  
                  accent: accent,
                  
                );

                return Column(
                  
                    StatOzTopBar(
                      title: 'Leaderboard',
     
                      onAddCoins:
                          
                          () => widget.onNavigate(AppSection.shop),
              
                    _LeaderboardTabs(
                      activeTab: 
                      indicatorAnimation: _typeTabIndicatorAnimation,
   
                      onTap: _setTypeTab,
                    
                    Expanded(
                      child: AnimatedSwitcher(
               
                        switchInCurve: 
                        transitionBuilder: (child, animation) => FadeTransition(
 
                          child: SlideTransition(
        
                              begin: const Offset(0, 
                              end: Offset.zero,
                            
                            child: child,
                          ),
  
                        child: entries.isEmpty
                            ? 
                                key: ValueKey('empty-${_type.name}'),
                    
                                type: _type,
                            
                                onAction: widget.onNavigate,
                      
                            : _Body(
                                key: ValueKey(
 
                         
                                filters: filters,
                                entries: 
                                type: _type,
                                accent: 
                                compact: compact,
                                onTapEntry: 
                                    ? null
                                    : 
                              ),
                      ),
                    
                    if (entries.isNotEmpty)
                      _UserRankBar(user: user, type: 
                  ],
                );
              },
      
          ),
        ],
      ),
      bottomNavigationBar: 
        selectedIndex: 2,
        onNavigate: widget.onNavigate,
     
      ),
    );
  }
}

// ─── Type tabs 

class _LeaderboardTabs extends 
  const _LeaderboardTabs({
    required this.activeTab,
    required 
    required this.accent,
    required this.onTap,
  });

  final int activeTab;
  final Animation<double> indicatorAnimation;
  final Color 
  final ValueChanged<int> onTap;

  static const List<String> _items = ['MATCH DAY', 

  @override
  Widget build(BuildContext context) {
    return 
      height: 50,
      decoration: BoxDecoration(
        color: 
        border: Border(
          bottom: BorderSide(color: 
        ),
      ),
      child: LayoutBuilder(
      
          final double tabWidth = 
          return Stack(
            children: [
         
                children: [
                  for (int index = 0; index < _items.length; 
                    Expanded(
                      child: _Pressable(
               
                        onTap: () => onTap(index),
                        
                          label: _items[index],
                          
                          accent: accent,
                        
                      ),
                    ),
                ],
              
              AnimatedBuilder(
                animation: indicatorAnimation,
              
                  return Positioned(
               
                    bottom: 0,
      
                    height: 3,
                    child: 
                  );
                },
                child: Container(
     
                    color: accent,
                    
                      BoxShadow(
                        color: accent.withValues(alpha: 
                        blurRadius: 10,
                      ),
                    
                  ),
                ),
              ),
            ],
    
        },
      ),
    );
  }
}

class 
  const _LeaderboardTabItem({
    required 
    required this.active,
    required this.accent,
  });

  final 
  final bool active;
  final Color accent;

  @override
  Widget 
    final Color color = active ? accent : _tabSecondary;
    return 
      duration: const Duration(milliseconds: 220),
      decoration: 
        color: active ? accent.withValues(alpha: 0.07) : Colors.transparent,
      
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
    
            label,
            maxLines: 1,
            style: 
              10,
              color: color,
              weight: 
              letterSpacing: 1.2,
            ),
          ),
        
      ),
    );
  }
}

class _Pressable extends StatefulWidget 
  const _Pressable({
    required this.child,
    required this.onTap,
    required 
  });

  final Widget child;
  final VoidCallback onTap;
  final 

  @override
  State<_Pressable> createState() => _PressableState();


class _PressableState extends State<_Pressable> {
  bool _pressed = false;
  bool 

  @override
  Widget build(BuildContext context) {
    return 
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() 
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
 
        onTapCancel: () => setState(() => _pressed = 
                      child: AnimatedSwitcher(
                     
                        switchInCurve: 
                        transitionBuilder: (child, animation) => FadeTransition(
     
                          child: SlideTransition(
                
                              begin: const Offset(0, 0.025),
         
                            ).animate(animation),
    required this.onScope,
    required 
    required this.onTournamentBoard,
    required this.mode,
    
    required this.accent,
    required this.compact,
  });

  final LeaderboardType type;
  final List<String> sports;
  final String 
  final ValueChanged<String> onSport;
  final TournamentScope scope;
  final 
  final TournamentBoard tournamentBoard;
  final 
  final GameMode mode;
  final ValueChanged<GameMode> 
  final Color accent;
  final bool compact;

  @override
  Widget 
    return LayoutBuilder(
      builder: (context, constraints) 
        final showCountdownInline =
            type == LeaderboardType.matchDay && 
        final showCountdownBelow =
            type == 
            !showCountdownInline &&
            !compact;


          crossAxisAlignment: CrossAxisAlignment.start,
          children: 
            Padding(
              padding: EdgeInsets.fromLTRB(16, compact ? 6 : 10, 12, 
              child: Row(
                children: [
                  Expanded(
 
                      scrollDirection: 
                      child: Row(
                        children: [
        
                            Padding(
                    
                              child: _SportChip(
  
                                active: sport == 
                                live:
                                    type == 
                                    sport == selectedSport,
               
                                onTap: () => onSport(sport),
         
                            ),
                        ],
             
                    ),
                  ),
                  if 
                    const _CountdownCard(remaining: '04h 12m'),
                
              ),
            ),
            if (showCountdownBelow)
              
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: 
                  alignment: Alignment.centerRight,
                  child: 
                ),
              ),
            if (type 
              _TournamentBoardTabs(
                active: 
                onSelect: onTournamentBoard,
                accent: accent,
 
              if (tournamentBoard == TournamentBoard.players)
                
                  scope: scope,
                  onScope: onScope,
             
                  compact: compact,
                ),
            
            if (type == LeaderboardType.games)
              _ModeTabs(mode: mode, onMode: onMode, 
          ],
        );
      },
    );
  }
}

class _SportChip extends StatelessWidget {
  const _SportChip({
    required 
    required 
    required this.live,
    required this.accent,
    required 
  });

  final String label;
  final bool active;
                        
                      ),
                    ],
                  ),
          
              ),
            ],
          );
        },
      ),
    
  }
}

class _LeaderboardTabItem extends 
  const _LeaderboardTabItem({
    required this.label,
    required 
    required this.accent,
  });

  final String label;
  final bool 
  final Color accent;

  @override
  Widget build(BuildContext context) {
    
    return AnimatedContainer(
      duration: const 
      decoration: BoxDecoration(
        color: active ? 
      ),
      child: Center(
        child: 
          fit: BoxFit.scaleDown,
          child: Text(
            label,
         
            style: Cyber.label(
              10,
              color: color,
 
              letterSpacing: 1.2,
            ),
          
        ),
      ),
    );
  }
}

class _Pressable extends StatefulWidget 
  const _Pressable({
    required this.child,
    required this.onTap,
    required 
  });

  final Widget child;
  final VoidCallback onTap;
  final Color 

  @override
  State<_Pressable> createState() => _PressableState();
}


  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) 
      onExit: (_) => setState(() => _hovered = false),
      child: 
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => 
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => 
        onTap: widget.onTap,
        child: AnimatedScale(
        
          scale: _pressed ? 0.97 : 1,
          child: 
            duration: const Duration(milliseconds: 150),
            decoration: 
              borderRadius: BorderRadius.zero,
              boxShadow: _hovered
     
                      BoxShadow(
                        color: 
                        blurRadius: 16,
                      
                    ]
                  : null,
            ),
            child: 
          ),
        ),
      ),
    );
  }
}

// ─── 
        
          activeIndex: activeSportIndex < 0 ? 0 : activeSportIndex,
          
          onTap: (index) => onSport(_leaderboardSports[index]),
        
        if (showCountdown)
          const Padding(
            padding: 
            child: Align(
              alignment: 
              child: _CountdownCard(remaining: '04h 12m'),
            
          ),
        if (type == LeaderboardType.tournament) ...[
          
            active: tournamentBoard,
            onSelect: 
            accent: accent,
          ),
          if (tournamentBoard == 
            _ScopeToggle(
              scope: scope,
              
              accent: accent,
              compact: compact,
            
        ],
        if (type == LeaderboardType.games)
          _ModeTabs(mode: mode, 
      ],
    );
  }
}

class 
  const _CountdownCard({required this.remaining});

  

  @override
  Widget build(BuildContext context) {
    return 
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: 
        color: Cyber.amber.withValues(alpha: 0.14),
        borderColor: 
        cut: 8,
      ),
      child: Row(
       
        children: [
          const Icon(Icons.timer_outlined, color: 
          const SizedBox(width: 5),
          Text(
            
}

class _ModeTabs extends 
  const _ModeTabs({
    required this.mode,
    required 
    required this.accent,
  });

  final GameMode mode;
  
  final Color accent;

  static const List<({GameMode 
    (mode: GameMode.quiz, label: 'QUIZ'),
    (mode: 
    (mode: GameMode.streaks, label: 'STREAKS'),
    (mode: 
  ];

  @override
  Widget 
    return SizedBox(
      height: 40,
      child: 
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 
        children: [
          for (final item in _items)
            
              padding: const EdgeInsets.only(right: 7),
              child: 
                behavior: HitTestBehavior.opaque,
                onTap: () => 
                child: Container(
                  padding: const 
                  alignment: Alignment.center,
                
                    color: mode == item.mode
                     
                        : Colors.transparent,
                   
                        ? accent
                        : 
                    cut: 8,
                  ),
        
                    item.label,
                    style: 
                      color: mode == item.mode ? accent : Cyber.muted,
                   
                      fontSize: 10,
                      
                      letterSpacing: 0.8,
                    
                  ),
                ),
              ),
            
        ],
      ),
    );
  }
}

// ─── Scrollable 

class _Body extends StatelessWidget 
  const _Body({
    required this.filters,
    required this.entries,
    
    required this.accent,
    required this.compact,
    
    super.key,
  });

  final Widget filters;
  final 
  final LeaderboardType type;
  final Color accent;
  final 
  final ValueChanged<LeaderboardEntry>? onTapEntry;

  @override
  
    final meta = entries.isNotEmpty && entries.first.team != 
        ? (unit: 'PTS')
        : _scoreMeta(type);
    // A short FRIENDS board (< 3) 
    final usePodium = entries.length >= 3;
    final 
        ? entries.take(3).toList()
        : const 
    final List<LeaderboardEntry> remaining = usePodium
        ? 
        : entries;

    return SingleChildScrollView(
    
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: 
          filters,
          Padding(
            padding: EdgeInsets.fromLTRB(16, 
            child: Column(
              crossAxisAlignment: 
              children: [
                _Podium(
             
                  meta: meta,
                  accent: accent,
      
                  onTapEntry: onTapEntry,
                
                if (remaining.isNotEmpty) ...[
                  SizedBox(height: compact ? 18 : 
                  for (var i = 0; i < remaining.length; i++)
                    
                      padding: const EdgeInsets.only(bottom: 10),
                      
                        index: i + podium.length,
                     
                        maxAnimatedIndex: entries.length,
                        
                          entry: remaining[i],
                          
                          meta: meta,
                          onTap: onTapEntry == 
                              ? null
                              : () => 
                        ),
                      ),
             
                ],
              ],
            ),
          ),

      ),
    );
  }
}

// ─── Pinned user rank bar 

class _UserRankBar extends StatelessWidget 
  const _UserRankBar({
    required this.user,
    required this.type,
    
  });

  final LeaderboardEntry user;
  final 
  final Color accent;

  @override
  Widget 
    final meta = user.team != null ? (unit: 'PTS') : _scoreMeta(type);

    return Container(
      width: double.infinity,
      padding: const 
      decoration: BoxDecoration(
        color: 
        border: Border(
          top: BorderSide(color: Cyber.line.withValues(alpha: 
        ),
      ),
      child: Container(
        padding: const 
        decoration: cutCornerDecoration(
        
          borderColor: accent.withValues(alpha: 0.34),
      
        ),
        child: Row(
          children: [
            
              name: user.name,
              size: 54,
              
              team: user.team,
            ),
            const 
            Expanded(
              child: Column(
                
                children: [
                  
                    children: [
                      Text(
                        
                        style: TextStyle(
                          color: 
                          fontFamily: Cyber.displayFont,
            
                          fontWeight: FontWeight.w800,
