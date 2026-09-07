import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/league_stats/league_stats_cubit.dart';
import '../../blocs/league_stats/league_stats_state.dart';
import '../../blocs/picks/picks_cubit.dart';
import '../../blocs/picks/picks_state.dart';
import '../../blocs/prediction/prediction_cubit.dart';
import '../../blocs/prediction/prediction_state.dart';
import '../../config/theme.dart';
import '../../data/followable_leagues.dart';
import '../../models/league.dart';
import '../../models/prediction.dart';
import '../../models/sport_match.dart';
import '../../models/team_standing.dart';
import '../../models/league_stat_leaders.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_filter_chips.dart';
import '../../widgets/cyber/cyber_underline_tabs.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/team_logo.dart';
import 'market_detail_screen.dart';
import 'match_detail_screen.dart';
import 'football_player_profile_screen.dart';
import 'team_detail_screen.dart';
import 'widgets/pick_market_card.dart';
import 'widgets/pick_trade_sheet.dart';
import 'widgets/match_prediction_card.dart';
import 'widgets/stat_leaderboard.dart';
import 'widgets/standings_table.dart';
import 'widgets/team_stat_board.dart';

enum _HubTab { table, leaders, stats, fixtures, picks }

/// Per-league hub reached by tapping a league's STANDING strip on the
/// prediction home. Five tabs: the standings table, the player stat
/// leaderboards, the club STATS boards, the league's fixtures ("PREDICTION
/// CENTER") and its quick markets ("PICKS CENTER"). Tapping a team drills into
/// [TeamDetailScreen].
///
/// Data comes from [LeagueStatsCubit], which renders the bundled package first
/// and layers live ESPN over it. When a competition is in neither source, the
/// table falls back to the repository-backed standings on [PredictionCubit].
class LeagueDetailScreen extends StatefulWidget {
  const LeagueDetailScreen({
    required this.league,
    this.openFixturesTab = false,
    super.key,
  });

  final League league;

  /// Opens straight to the GAMES (fixtures) tab instead of the standings
  /// table — used by the "view more" link on a league's collapsed match feed.
  final bool openFixturesTab;

  @override
  State<LeagueDetailScreen> createState() => _LeagueDetailScreenState();
}

class _LeagueDetailScreenState extends State<LeagueDetailScreen> {
  late _HubTab _tab = widget.openFixturesTab ? _HubTab.fixtures : _HubTab.table;
  bool _followBusy = false;

  League get _league => widget.league;
  Color get _accent => _league.accent;

  @override
  void initState() {
    super.initState();
    if (widget.openFixturesTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<LeagueStatsCubit>().ensureSeasonFixtures();
      });
    }
  }

  void _openMatch(SportMatch match) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => MatchDetailScreen(match: match)),
    );
  }

  void _openTeam(SportTeam team) {
    playSound(SoundEffect.uiTap);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TeamDetailScreen(team: team, league: _league),
      ),
    );
  }

  void _openPickMarket(String marketId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MarketDetailScreen(marketId: marketId),
      ),
    );
  }

  void _openPlayerProfile(StatLeader leader, LeagueStatsSnapshot snapshot) {
    playSound(SoundEffect.uiTap);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FootballPlayerProfileScreen(
          league: _league,
          leader: leader,
          seasonYear: snapshot.seasonYear,
        ),
      ),
    );
  }

  void _selectTab(int index) {
    final next = _HubTab.values[index];
    if (next == _tab) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = next);
    if (next == _HubTab.fixtures || next == _HubTab.picks) {
      context.read<LeagueStatsCubit>().ensureSeasonFixtures();
    }
  }

  Future<void> _selectSeason(int year) async {
    HapticFeedback.selectionClick();
    await context.read<LeagueStatsCubit>().selectSeason(year);
    if (!mounted) return;
    if (_tab == _HubTab.fixtures || _tab == _HubTab.picks) {
      await context.read<LeagueStatsCubit>().ensureSeasonFixtures();
    }
  }

  Future<void> _toggleFollow(
    FollowableLeague followable,
    PredictionState prediction,
  ) async {
    if (_followBusy) return;
    final leagueId = followable.league.id;
    final followed = prediction.followedLeagueIds.contains(leagueId);
    final favoriteId = prediction.favoriteTeams[leagueId];
    if (followed && favoriteId != null) {
      final favorite = followableTeam(leagueId, favoriteId);
      final confirmed = await showCyberConfirmDialog(
        context,
        title: 'UNFOLLOW ${followable.league.shortCode}?',
        message: favorite == null
            ? 'This removes the league and its saved favourite club.'
            : 'This also removes ${favorite.name} as your favourite club.',
        confirmLabel: 'UNFOLLOW',
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => _followBusy = true);
    HapticFeedback.mediumImpact();
    try {
      await context.read<PredictionCubit>().setLeagueFollowed(
        leagueId,
        !followed,
      );
      if (!mounted) return;
      playSound(SoundEffect.uiTap);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Cyber.panel2,
            content: Text(
              followed
                  ? '${followable.league.shortCode} REMOVED FROM FOLLOWING'
                  : '${followable.league.shortCode} ADDED TO FOLLOWING',
              style: Cyber.label(9, color: Cyber.success, letterSpacing: 1.0),
            ),
          ),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Cyber.panel2,
          content: Text(
            'COULD NOT UPDATE FOLLOWING',
            style: Cyber.label(9, color: Cyber.danger),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: CyberPlainBackground(
        child: SafeArea(
          child: BlocBuilder<PredictionCubit, PredictionState>(
            builder: (context, state) {
              final fixtures = state.fixtures
                  .where((m) => _matchesLeague(m.leagueId))
                  .toList();
              final followable = followableLeagueFor(_league);
              final followed =
                  followable != null &&
                  state.followedLeagueIds.contains(followable.league.id);

              return BlocBuilder<LeagueStatsCubit, LeagueStatsState>(
                builder: (context, stats) {
                  final fallback = state.standingsFor(_league.id);
                  final teamCount = stats.hasStandings
                      ? stats.snapshot.allRows.length
                      : fallback.length;

                  return Column(
                    children: [
                      DetailTopBar(title: '${_league.shortCode} HUB'),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                        child: LeagueHeader(
                          league: _league,
                          teamCount: teamCount,
                          subtitle: _headerSubtitle(stats),
                          seasons: stats.seasons,
                          selectedSeasonYear: stats.selectedSeasonYear,
                          onSeasonSelected: stats.seasons.length > 1
                              ? _selectSeason
                              : null,
                          followed: followed,
                          followBusy: _followBusy,
                          onToggleFollow: followable == null
                              ? null
                              : () => _toggleFollow(followable, state),
                        ),
                      ),
                      CyberUnderlineTabs(
                        labels: const [
                          'TABLE',
                          'LEADERS',
                          'STATS',
                          'GAMES',
                          'PICKS',
                        ],
                        icons: const [
                          Icons.table_rows_outlined,
                          Icons.military_tech_outlined,
                          Icons.query_stats_outlined,
                          Icons.sports_soccer_outlined,
                          Icons.insights_outlined,
                        ],
                        activeIndex: _tab.index,
                        onTap: _selectTab,
                        accent: _accent,
                      ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: _buildTab(state, stats, fixtures, fallback),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  bool _matchesLeague(String leagueId) {
    if (leagueId == _league.id) return true;
    final target = followableLeagueFor(_league);
    final candidate = followableLeagueById(leagueId);
    return target != null && identical(target, candidate);
  }

  String? _headerSubtitle(LeagueStatsState stats) {
    final season = stats.snapshot.seasonLabel;
    if (season == null) return null;
    return RegExp(r'\d{4}(?:-\d{2})?').firstMatch(season)?.group(0);
  }

  Widget _buildTab(
    PredictionState state,
    LeagueStatsState stats,
    List<SportMatch> fixtures,
    List<TeamStanding> fallback,
  ) {
    if (stats.archiveUnavailable) {
      return const CyberNoDataState(
        key: ValueKey('archive-unavailable'),
        icon: Icons.desktop_windows_outlined,
        title: 'ARCHIVE UNAVAILABLE ON WEB',
        message: 'Open Pitch Duel on mobile or desktop to load ESPN archives.',
      );
    }
    final seasonFixtures = _mergeSeasonFixtures(stats, fixtures);
    final followable = followableLeagueFor(_league);
    final leagueIds = <String>{
      _league.id,
      if (followable != null) followable.league.id,
      if (followable != null) ...followable.aliases,
    };
    return switch (_tab) {
      _HubTab.table => _TableTab(
        key: const ValueKey('hub-table'),
        stats: stats,
        fallback: fallback,
        accent: _accent,
        competition: _league.id,
        onTapTeam: _openTeam,
      ),
      _HubTab.leaders => _LeadersTab(
        key: const ValueKey('hub-leaders'),
        stats: stats,
        accent: _accent,
        onTapPlayer: (leader) => _openPlayerProfile(leader, stats.snapshot),
      ),
      _HubTab.stats => _StatsTab(
        key: const ValueKey('hub-stats'),
        stats: stats,
        accent: _accent,
      ),
      _HubTab.fixtures => _FixturesTab(
        key: const ValueKey('hub-fixtures'),
        state: state,
        stats: stats,
        fixtures: seasonFixtures,
        onOpenMatch: _openMatch,
        onRetry: context.read<LeagueStatsCubit>().ensureSeasonFixtures,
      ),
      _HubTab.picks => _PicksTab(
        key: const ValueKey('hub-picks'),
        leagueIds: leagueIds,
        stats: stats,
        fixtures: seasonFixtures,
        onOpenMarket: _openPickMarket,
        onOpenMatch: _openMatch,
        onRetry: context.read<LeagueStatsCubit>().ensureSeasonFixtures,
      ),
    };
  }

  List<SportMatch> _mergeSeasonFixtures(
    LeagueStatsState stats,
    List<SportMatch> rolling,
  ) {
    final byId = <String, SportMatch>{
      for (final match in stats.seasonFixtures) match.id: match,
    };
    if (stats.isCurrentSeason) {
      for (final match in rolling) {
        byId[match.id] = match;
      }
    }
    if (byId.isEmpty && stats.isCurrentSeason) return rolling;
    final matches = byId.values.toList();
    matches.sort((a, b) {
      if (!stats.isCurrentSeason) return b.kickoff.compareTo(a.kickoff);
      final aRank = a.status == MatchStatus.live
          ? 0
          : a.status == MatchStatus.upcoming
          ? 1
          : 2;
      final bRank = b.status == MatchStatus.live
          ? 0
          : b.status == MatchStatus.upcoming
          ? 1
          : 2;
      if (aRank != bRank) return aRank.compareTo(bRank);
      return aRank == 2
          ? b.kickoff.compareTo(a.kickoff)
          : a.kickoff.compareTo(b.kickoff);
    });
    return matches;
  }
}

/// Standings tab: conference toggle (when the league has groups) over the
/// shared [StandingsTable].
class _TableTab extends StatelessWidget {
  const _TableTab({
    required this.stats,
    required this.fallback,
    required this.accent,
    required this.competition,
    required this.onTapTeam,
    super.key,
  });

  final LeagueStatsState stats;
  final List<TeamStanding> fallback;
  final Color accent;
  final String competition;
  final ValueChanged<SportTeam> onTapTeam;

  @override
  Widget build(BuildContext context) {
    if (stats.status == LeagueStatsStatus.loading && fallback.isEmpty) {
      return const _HubLoader(label: 'PULLING LIVE TABLE');
    }

    final groups = stats.snapshot.groups;
    if (groups.isEmpty) {
      if (fallback.isEmpty) {
        return const CyberNoDataState(
          icon: Icons.table_chart_outlined,
          title: 'NO TABLE YET',
          message: 'Standings for this competition are not published yet.',
        );
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          const _Heading(label: 'ALL TEAMS'),
          const SizedBox(height: 10),
          StandingsTable(
            rows: fallback,
            accent: accent,
            competition: competition,
            onTapTeam: onTapTeam,
          ),
        ],
      );
    }

    final index = stats.groupIndex.clamp(0, groups.length - 1);
    final group = groups[index];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        if (groups.length > 1) ...[
          CyberUnderlineTabs(
            labels: [for (final g in groups) g.shortLabel],
            activeIndex: index,
            accent: accent,
            height: 42,
            onTap: (i) {
              HapticFeedback.selectionClick();
              context.read<LeagueStatsCubit>().selectGroup(i);
            },
          ),
          const SizedBox(height: 14),
        ] else
          const _Heading(label: 'ALL TEAMS'),
        if (groups.length == 1) const SizedBox(height: 10),
        StandingsTable(
          key: ValueKey('standings-${group.label}'),
          rows: group.rows,
          accent: accent,
          competition: competition,
          showGoals: true,
          onTapTeam: onTapTeam,
        ),
      ],
    );
  }
}

/// Leaders tab: horizontally scrolling category tabs over one [StatLeaderboard].
class _LeadersTab extends StatelessWidget {
  const _LeadersTab({
    required this.stats,
    required this.accent,
    required this.onTapPlayer,
    super.key,
  });

  final LeagueStatsState stats;
  final Color accent;
  final ValueChanged<StatLeader> onTapPlayer;

  @override
  Widget build(BuildContext context) {
    if (stats.status == LeagueStatsStatus.loading) {
      return const _HubLoader(label: 'PULLING STAT LEADERS');
    }

    final categories = stats.snapshot.categories;
    if (categories.isEmpty) {
      return const CyberNoDataState(
        icon: Icons.military_tech_outlined,
        title: 'NO STAT LEADERS',
        message:
            'This competition has not published season leaderboards yet. '
            'Check back once the season is under way.',
      );
    }

    final index = stats.categoryIndex.clamp(0, categories.length - 1);
    final category = categories[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CyberUnderlineTabs(
          labels: [for (final c in categories) c.label],
          activeIndex: index,
          accent: accent,
          height: 44,
          minTabWidth: 104,
          onTap: (i) {
            HapticFeedback.selectionClick();
            context.read<LeagueStatsCubit>().selectCategory(i);
          },
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              StatLeaderboard(
                category: category,
                leagueAccent: accent,
                resolving: stats.resolvingCategory,
                onTapLeader: onTapPlayer,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Club STATS tab: four category tabs (ATTACK / DEFENCE / KEEPING /
/// DISCIPLINE) over a league-total pulse strip, a stat chip selector, and one
/// [TeamStatBoard] ranking every club.
///
/// Fed entirely by the bundled package — the live ESPN feed carries no per-team
/// season statistics, so a competition outside the package shows the locked
/// state rather than an empty board.
class _StatsTab extends StatefulWidget {
  const _StatsTab({required this.stats, required this.accent, super.key});

  final LeagueStatsState stats;
  final Color accent;

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  @override
  void initState() {
    super.initState();
    // Club stats cost one request per team, so they are pulled the first time
    // this tab is opened rather than on hub load. No-ops when the bundled
    // package already supplied them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<LeagueStatsCubit>().ensureTeamStats();
    });
  }

  LeagueStatsState get stats => widget.stats;
  Color get accent => widget.accent;

  @override
  Widget build(BuildContext context) {
    if (stats.status == LeagueStatsStatus.loading) {
      return const _HubLoader(label: 'READING SEASON STATS');
    }
    if (!stats.hasTeamStats) {
      if (stats.loadingTeamStats) {
        return const _HubLoader(label: 'PULLING CLUB STATS');
      }
      return const CyberNoDataState(
        icon: Icons.query_stats_outlined,
        title: 'NO CLUB STATS',
        message:
            'This competition has not published season statistics yet. '
            'Check back once the season is under way.',
      );
    }

    final snapshot = stats.snapshot;
    // Cricket and football share no stat keys, so the board set follows the
    // package that filled the hub rather than being hardcoded to football.
    final statGroups = statGroupsFor(snapshot.statDefinitions);
    final groupIndex = stats.statGroupIndex.clamp(0, statGroups.length - 1);
    final group = statGroups[groupIndex];
    final groupAccent = group.accent ?? accent;

    final statIndex = stats.statIndex.clamp(0, group.boards.length - 1);
    final spec = group.boards[statIndex];
    final boardAccent = spec.accent ?? groupAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Labels, not icons: the hub's own tab bar directly above is already
        // icon-only, and a second icon row under it reads as chrome rather
        // than as a choice. This also matches the LEADERS sub-tabs.
        CyberUnderlineTabs(
          labels: [for (final g in statGroups) g.label],
          activeIndex: groupIndex,
          accent: groupAccent,
          height: 44,
          minTabWidth: 92,
          onTap: (i) {
            HapticFeedback.selectionClick();
            context.read<LeagueStatsCubit>().selectStatGroup(i);
          },
        ),
        CyberFilterChips(
          labels: [for (final b in group.boards) b.label],
          selected: spec.label,
          accent: groupAccent,
          onSelect: (label) {
            final next = group.boards.indexWhere((b) => b.label == label);
            if (next < 0) return;
            HapticFeedback.selectionClick();
            context.read<LeagueStatsCubit>().selectStat(next);
          },
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              _StatPulseStrip(
                snapshot: snapshot,
                group: group,
                accent: groupAccent,
              ),
              const SizedBox(height: 16),
              TeamStatBoard(
                key: ValueKey('${group.label}-${spec.stat}'),
                entries: snapshot.boardFor(
                  spec.stat,
                  lowerIsBetter: spec.lowerIsBetter,
                ),
                spec: spec,
                definition: snapshot.statDefinitions[spec.stat],
                accent: boardAccent,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// League-wide totals for the selected group — the context the per-club
/// rankings below are measured against. Calm cells; no glow (glow rule).
class _StatPulseStrip extends StatelessWidget {
  const _StatPulseStrip({
    required this.snapshot,
    required this.group,
    required this.accent,
  });

  final LeagueStatsSnapshot snapshot;
  final StatBoardGroup group;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (group.pulse.isEmpty) return const SizedBox.shrink();
    final teamCount = snapshot.teamStats.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CyberSectionHeading(label: '${group.label} // LEAGUE TOTAL'),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < group.pulse.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Builder(
                builder: (context) {
                  final pulse = group.pulse[i];
                  final total = snapshot.totalOf(pulse.stat);
                  final value = pulse.perTeam && teamCount > 0
                      ? total / teamCount
                      : total;
                  return CyberMiniMetric(
                    label: pulse.label,
                    value: value == value.roundToDouble()
                        ? value.round().toString()
                        : value.toStringAsFixed(1),
                    // Only the first cell is tinted, so the strip reads as
                    // context with one anchor rather than three equal claims.
                    accent: i == 0 ? accent : null,
                  );
                },
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Fixtures tab — the league's prediction center, unchanged in behaviour.
class _FixturesTab extends StatelessWidget {
  const _FixturesTab({
    required this.state,
    required this.stats,
    required this.fixtures,
    required this.onOpenMatch,
    required this.onRetry,
    super.key,
  });

  final PredictionState state;
  final LeagueStatsState stats;
  final List<SportMatch> fixtures;
  final ValueChanged<SportMatch> onOpenMatch;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (!stats.isCurrentSeason &&
        stats.fixturesStatus == LeagueFixturesStatus.loading) {
      return const _HubLoader(label: 'SYNCING SEASON SCHEDULE');
    }
    if (stats.fixturesStatus == LeagueFixturesStatus.error &&
        fixtures.isEmpty) {
      return CyberNoDataState(
        icon: Icons.sync_problem_outlined,
        title: 'SCHEDULE LINK LOST',
        message: 'The selected season could not be loaded.',
        actionLabel: 'RETRY SYNC',
        actionIcon: Icons.refresh,
        onAction: onRetry,
      );
    }
    if (fixtures.isEmpty) {
      return CyberNoDataState(
        icon: Icons.event_busy_outlined,
        title: 'NO FIXTURES',
        message: stats.isCurrentSeason
            ? 'No games scheduled for this league right now.'
            : 'No matches were returned for this season.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      itemCount: fixtures.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _Heading(
              label: stats.isCurrentSeason
                  ? 'PREDICTION CENTER'
                  : 'SEASON MATCH ARCHIVE',
            ),
          );
        }
        final match = fixtures[index - 1];
        final prediction = state.predictionSummaryForMatch(match.id);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: MatchPredictionCard(
            match: match,
            prediction: prediction,
            quiz:
                state.quizzes[predictionStorageKey(
                  match.id,
                  prediction?.quizId ?? kDefaultPredictionQuizId,
                )],
            favorite: state.favoriteSideFor(match),
            onTap: () => onOpenMatch(match),
          ),
        );
      },
    );
  }
}

/// Picks tab — the league's quick markets, unchanged in behaviour.
class _PicksTab extends StatelessWidget {
  const _PicksTab({
    required this.leagueIds,
    required this.stats,
    required this.fixtures,
    required this.onOpenMarket,
    required this.onOpenMatch,
    required this.onRetry,
    super.key,
  });

  final Set<String> leagueIds;
  final LeagueStatsState stats;
  final List<SportMatch> fixtures;
  final ValueChanged<String> onOpenMarket;
  final ValueChanged<SportMatch> onOpenMatch;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (!stats.isCurrentSeason) {
      return _HistoricalPickArchive(
        fixtures: fixtures,
        status: stats.fixturesStatus,
        onOpenMatch: onOpenMatch,
        onRetry: onRetry,
      );
    }
    return BlocBuilder<PicksCubit, PicksState>(
      builder: (context, picksState) {
        final markets = picksState.markets
            .where((m) => leagueIds.contains(m.leagueId))
            .toList();
        if (markets.isEmpty) {
          return const CyberNoDataState(
            icon: Icons.insights_outlined,
            title: 'NO MARKETS',
            message: 'No quick markets are open for this league right now.',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            const _Heading(label: 'PICKS CENTER'),
            const SizedBox(height: 12),
            for (final market in markets) ...[
              PickMarketCard(
                market: market,
                positions: picksState.positionsForMarket(market.id),
                onOpen: () => onOpenMarket(market.id),
                onBuy: (outcome) => showPickTradeSheet(
                  context: context,
                  market: market,
                  outcome: outcome,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _HistoricalPickArchive extends StatelessWidget {
  const _HistoricalPickArchive({
    required this.fixtures,
    required this.status,
    required this.onOpenMatch,
    required this.onRetry,
  });

  final List<SportMatch> fixtures;
  final LeagueFixturesStatus status;
  final ValueChanged<SportMatch> onOpenMatch;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (status == LeagueFixturesStatus.loading ||
        status == LeagueFixturesStatus.idle) {
      return const _HubLoader(label: 'UNLOCKING RESULT ARCHIVE');
    }
    if (status == LeagueFixturesStatus.error) {
      return CyberNoDataState(
        icon: Icons.sync_problem_outlined,
        title: 'RESULT ARCHIVE OFFLINE',
        message: 'Final scores for this season could not be loaded.',
        actionLabel: 'RETRY SYNC',
        actionIcon: Icons.refresh,
        onAction: onRetry,
      );
    }
    final results =
        fixtures
            .where(
              (match) => match.status == MatchStatus.finished && match.hasScore,
            )
            .toList()
          ..sort((a, b) => b.kickoff.compareTo(a.kickoff));
    if (results.isEmpty) {
      return const CyberNoDataState(
        icon: Icons.fact_check_outlined,
        title: 'NO FINAL RESULTS',
        message: 'This season has no completed score records yet.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      itemCount: results.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: _Heading(label: 'READ-ONLY RESULT ARCHIVE'),
          );
        }
        final match = results[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ArchivedPickResultCard(
            match: match,
            onTap: () => onOpenMatch(match),
          ),
        );
      },
    );
  }
}

class _ArchivedPickResultCard extends StatelessWidget {
  const _ArchivedPickResultCard({required this.match, required this.onTap});

  final SportMatch match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final home = int.tryParse(match.homeScore ?? '');
    final away = int.tryParse(match.awayScore ?? '');
    final result = home == null || away == null
        ? 'FINAL'
        : home == away
        ? 'DRAW'
        : home > away
        ? '${match.home.shortName} WIN'
        : '${match.away.shortName} WIN';
    return Semantics(
      button: true,
      label:
          '${match.home.name} ${match.homeScore}, ${match.away.name} ${match.awayScore}, $result',
      child: PressableScale(
        onTap: onTap,
        child: CyberPanel(
          accent: Cyber.line,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            children: [
              Row(
                children: [
                  const CyberStatusPill(
                    label: 'RESULT LOCKED',
                    color: Cyber.success,
                  ),
                  const Spacer(),
                  Text(
                    _archiveDate(match.kickoff),
                    style: Cyber.label(8, color: Cyber.muted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _ArchiveTeam(team: match.home)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      children: [
                        Text(
                          '${match.homeScore ?? '-'}  -  ${match.awayScore ?? '-'}',
                          style: Cyber.display(20, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          result,
                          style: Cyber.label(8, color: Cyber.success),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _ArchiveTeam(team: match.away, alignEnd: true),
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

class _ArchiveTeam extends StatelessWidget {
  const _ArchiveTeam({required this.team, this.alignEnd = false});

  final SportTeam team;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        TeamLogo(team: team, width: 34, height: 34),
        const SizedBox(height: 6),
        Text(
          team.shortName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Cyber.display(10, color: Colors.white),
        ),
      ],
    );
  }
}

String _archiveDate(DateTime value) {
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
  return '${value.day.toString().padLeft(2, '0')} ${months[value.month - 1]} ${value.year}';
}

class _HubLoader extends StatelessWidget {
  const _HubLoader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2, color: Cyber.cyan),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.6),
          ),
        ],
      ),
    );
  }
}

/// Section heading: a section label with a fading accent rule, reused on both
/// the league and team detail screens.
class _Heading extends StatelessWidget {
  const _Heading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SectionLabel(label: label),
        const SizedBox(width: 10),
        Expanded(
          child: Container(height: 1, color: Cyber.line.withValues(alpha: 0.3)),
        ),
      ],
    );
  }
}
