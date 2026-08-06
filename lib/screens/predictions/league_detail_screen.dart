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
import '../../models/league.dart';
import '../../models/prediction.dart';
import '../../models/sport_match.dart';
import '../../models/team_standing.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_underline_tabs.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import 'market_detail_screen.dart';
import 'match_detail_screen.dart';
import 'team_detail_screen.dart';
import 'widgets/pick_market_card.dart';
import 'widgets/pick_trade_sheet.dart';
import 'widgets/match_prediction_card.dart';
import 'widgets/stat_leaderboard.dart';
import 'widgets/standings_table.dart';

enum _HubTab { table, leaders, fixtures, picks }

/// Per-league hub reached by tapping a league's STANDING strip on the
/// prediction home. Four tabs: the live standings table, the ESPN stat
/// leaderboards, the league's fixtures ("PREDICTION CENTER") and its quick
/// markets ("PICKS CENTER"). Tapping a team drills into [TeamDetailScreen].
///
/// Standings and leaderboards come from [LeagueStatsCubit] (live ESPN); when a
/// competition has no ESPN slug the table falls back to the repository-backed
/// standings on [PredictionCubit].
class LeagueDetailScreen extends StatefulWidget {
  const LeagueDetailScreen({required this.league, super.key});

  final League league;

  @override
  State<LeagueDetailScreen> createState() => _LeagueDetailScreenState();
}

class _LeagueDetailScreenState extends State<LeagueDetailScreen> {
  _HubTab _tab = _HubTab.table;

  League get _league => widget.league;
  Color get _accent => _league.accent;

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

  void _selectTab(int index) {
    final next = _HubTab.values[index];
    if (next == _tab) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = next);
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
                  .where((m) => m.leagueId == _league.id)
                  .toList();

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
                          subtitle: _headerSubtitle(stats, teamCount),
                        ),
                      ),
                      CyberUnderlineTabs(
                        labels: const ['TABLE', 'LEADERS', 'GAMES', 'PICKS'],
                        icons: const [
                          Icons.table_rows_outlined,
                          Icons.military_tech_outlined,
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

  String? _headerSubtitle(LeagueStatsState stats, int teamCount) {
    final season = stats.snapshot.seasonLabel;
    if (season == null) return null;
    return '${season.toUpperCase()} // $teamCount TEAMS';
  }

  Widget _buildTab(
    PredictionState state,
    LeagueStatsState stats,
    List<SportMatch> fixtures,
    List<TeamStanding> fallback,
  ) {
    return switch (_tab) {
      _HubTab.table => _TableTab(
        key: const ValueKey('hub-table'),
        stats: stats,
        fallback: fallback,
        accent: _accent,
        onTapTeam: _openTeam,
      ),
      _HubTab.leaders => _LeadersTab(
        key: const ValueKey('hub-leaders'),
        stats: stats,
        accent: _accent,
      ),
      _HubTab.fixtures => _FixturesTab(
        key: const ValueKey('hub-fixtures'),
        state: state,
        fixtures: fixtures,
        onOpenMatch: _openMatch,
      ),
      _HubTab.picks => _PicksTab(
        key: const ValueKey('hub-picks'),
        leagueId: _league.id,
        onOpenMarket: _openPickMarket,
      ),
    };
  }
}

/// Standings tab: conference toggle (when the league has groups) over the
/// shared [StandingsTable].
class _TableTab extends StatelessWidget {
  const _TableTab({
    required this.stats,
    required this.fallback,
    required this.accent,
    required this.onTapTeam,
    super.key,
  });

  final LeagueStatsState stats;
  final List<TeamStanding> fallback;
  final Color accent;
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
          showGoals: true,
          onTapTeam: onTapTeam,
        ),
      ],
    );
  }
}

/// Leaders tab: horizontally scrolling category tabs over one [StatLeaderboard].
class _LeadersTab extends StatelessWidget {
  const _LeadersTab({required this.stats, required this.accent, super.key});

  final LeagueStatsState stats;
  final Color accent;

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
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Fixtures tab — the league's prediction center, unchanged in behaviour.
class _FixturesTab extends StatelessWidget {
  const _FixturesTab({
    required this.state,
    required this.fixtures,
    required this.onOpenMatch,
    super.key,
  });

  final PredictionState state;
  final List<SportMatch> fixtures;
  final ValueChanged<SportMatch> onOpenMatch;

  @override
  Widget build(BuildContext context) {
    if (fixtures.isEmpty) {
      return const CyberNoDataState(
        icon: Icons.event_busy_outlined,
        title: 'NO FIXTURES',
        message: 'No games scheduled for this league right now.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        const _Heading(label: 'PREDICTION CENTER'),
        const SizedBox(height: 12),
        for (final match in fixtures) ...[
          MatchPredictionCard(
            match: match,
            prediction: state.predictionSummaryForMatch(match.id),
            quiz: state.quizzes[predictionStorageKey(
              match.id,
              state.predictionSummaryForMatch(match.id)?.quizId ??
                  kDefaultPredictionQuizId,
            )],
            onTap: () => onOpenMatch(match),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// Picks tab — the league's quick markets, unchanged in behaviour.
class _PicksTab extends StatelessWidget {
  const _PicksTab({
    required this.leagueId,
    required this.onOpenMarket,
    super.key,
  });

  final String leagueId;
  final ValueChanged<String> onOpenMarket;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PicksCubit, PicksState>(
      builder: (context, picksState) {
        final markets = picksState.markets
            .where((m) => m.leagueId == leagueId)
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
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Cyber.cyan,
            ),
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
