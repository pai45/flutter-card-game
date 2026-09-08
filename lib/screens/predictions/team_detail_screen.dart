import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/prediction/prediction_cubit.dart';
import '../../blocs/prediction/prediction_state.dart';
import '../../blocs/team_hub/team_hub_cubit.dart';
import '../../blocs/team_hub/team_hub_state.dart';
import '../../config/theme.dart';
import '../../data/cricket_match_portraits.dart';
import '../../models/league.dart';
import '../../models/league_stat_leaders.dart';
import '../../models/prediction.dart';
import '../../models/sport_match.dart';
import '../../models/team_hub.dart';
import '../../models/team_standing.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_filter_chips.dart';
import '../../widgets/cyber/cyber_underline_tabs.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/team_logo.dart';
import 'cricket_player_season_screen.dart';
import 'football_player_profile_screen.dart';
import 'match_detail_screen.dart';
import 'widgets/match_prediction_card.dart';
import 'widgets/standings_table.dart';
import 'widgets/team_season_match_card.dart';

enum _TeamHubTab { matches, predictions, players }

enum _MatchFilter { all, upcoming, results }

/// Season-aware club hub reached from TABLE and STATS team rows.
class TeamDetailScreen extends StatefulWidget {
  const TeamDetailScreen({
    required this.team,
    required this.league,
    required this.sport,
    required this.seasonYear,
    required this.seasonLabel,
    this.standing,
    super.key,
  });

  final SportTeam team;
  final League league;
  final Sport sport;
  final int seasonYear;
  final String seasonLabel;
  final TeamStanding? standing;

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  _TeamHubTab _tab = _TeamHubTab.matches;
  _MatchFilter _filter = _MatchFilter.all;

  void _selectTab(int index) {
    if (_tab.index == index) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = _TeamHubTab.values[index]);
  }

  void _openMatch(SportMatch match) {
    playSound(SoundEffect.uiTap);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MatchDetailScreen(match: match, initialTab: 0),
      ),
    );
  }

  void _openPlayer(TeamSeasonPlayer player) {
    HapticFeedback.selectionClick();
    playSound(SoundEffect.uiTap);
    if (widget.sport == Sport.cricket) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CricketPlayerSeasonScreen(
            league: widget.league,
            team: widget.team,
            player: player,
            seasonLabel: widget.seasonLabel,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FootballPlayerProfileScreen(
          league: widget.league,
          seasonYear: widget.seasonYear,
          leader: StatLeader(
            athleteId: player.id,
            value: 0,
            displayValue: '',
            name: player.name,
            teamId: widget.team.id,
            team: widget.team,
            position: player.role,
            flagUrl: player.flagUrl,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: CyberPlainBackground(
        child: SafeArea(
          child: BlocConsumer<TeamHubCubit, TeamHubState>(
            listenWhen: (previous, current) =>
                current.data != null &&
                previous.data?.fixtures != current.data?.fixtures,
            listener: (context, state) {
              final fixtures = state.data?.fixtures ?? const <SportMatch>[];
              if (fixtures.isNotEmpty) {
                unawaited(
                  context.read<PredictionCubit>().ingestFixtures(fixtures),
                );
              }
            },
            builder: (context, hub) => Column(
              children: [
                DetailTopBar(
                  title:
                      '${widget.league.shortCode} // ${widget.team.shortName}',
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: TeamHeader(
                    team: widget.team,
                    standing: widget.standing,
                    competition: widget.league.id,
                  ),
                ),
                CyberUnderlineTabs(
                  labels: const ['MATCHES', 'PREDICTIONS', 'PLAYERS'],
                  activeIndex: _tab.index,
                  onTap: _selectTab,
                  accent: widget.league.accent,
                  height: 48,
                  minTabWidth: 116,
                ),
                if (hub.refreshing || hub.refreshFailed)
                  _SyncStrip(
                    refreshing: hub.refreshing,
                    failed: hub.refreshFailed,
                    onRetry: context.read<TeamHubCubit>().refresh,
                  ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _buildBody(hub),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(TeamHubState hub) {
    if (hub.status == TeamHubStatus.loading && hub.data == null) {
      return const _HubLoader(key: ValueKey('loading'));
    }
    if (hub.status == TeamHubStatus.error && hub.data == null) {
      return CyberNoDataState(
        key: const ValueKey('error'),
        icon: Icons.sync_problem_outlined,
        title: 'TEAM UPLINK OFFLINE',
        message: 'The ESPN season package could not be read.',
        actionLabel: 'RETRY SYNC',
        actionIcon: Icons.refresh,
        onAction: context.read<TeamHubCubit>().load,
      );
    }
    final data = hub.data!;
    return switch (_tab) {
      _TeamHubTab.matches => _MatchesTab(
        key: const ValueKey('matches'),
        fixtures: data.fixtures,
        filter: _filter,
        competition: widget.league.id,
        accent: widget.league.accent,
        onFilter: (filter) {
          HapticFeedback.selectionClick();
          setState(() => _filter = filter);
        },
        onOpenMatch: _openMatch,
      ),
      _TeamHubTab.predictions => _PredictionsTab(
        key: const ValueKey('predictions'),
        fixtures: data.fixtures,
        onOpenMatch: _openMatch,
      ),
      _TeamHubTab.players => _PlayersTab(
        key: const ValueKey('players'),
        players: data.players,
        team: widget.team,
        sport: widget.sport,
        accent: widget.league.accent,
        competition: widget.league.id,
        onOpenPlayer: _openPlayer,
      ),
    };
  }
}

class _MatchesTab extends StatelessWidget {
  const _MatchesTab({
    required this.fixtures,
    required this.filter,
    required this.competition,
    required this.accent,
    required this.onFilter,
    required this.onOpenMatch,
    super.key,
  });

  final List<SportMatch> fixtures;
  final _MatchFilter filter;
  final String competition;
  final Color accent;
  final ValueChanged<_MatchFilter> onFilter;
  final ValueChanged<SportMatch> onOpenMatch;

  @override
  Widget build(BuildContext context) {
    final filtered = fixtures
        .where(
          (match) => switch (filter) {
            _MatchFilter.all => true,
            _MatchFilter.upcoming => match.status != MatchStatus.finished,
            _MatchFilter.results => match.status == MatchStatus.finished,
          },
        )
        .toList();
    filtered.sort((a, b) {
      if (filter == _MatchFilter.results) {
        return b.kickoff.compareTo(a.kickoff);
      }
      if (filter == _MatchFilter.all) {
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
        if (aRank == 2) return b.kickoff.compareTo(a.kickoff);
      }
      return a.kickoff.compareTo(b.kickoff);
    });
    final selected = switch (filter) {
      _MatchFilter.all => 'ALL',
      _MatchFilter.upcoming => 'UPCOMING',
      _MatchFilter.results => 'RESULTS',
    };
    return Column(
      children: [
        CyberFilterChips(
          labels: const ['ALL', 'UPCOMING', 'RESULTS'],
          selected: selected,
          accent: accent,
          onSelect: (label) => onFilter(switch (label) {
            'UPCOMING' => _MatchFilter.upcoming,
            'RESULTS' => _MatchFilter.results,
            _ => _MatchFilter.all,
          }),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const CyberNoDataState(
                  icon: Icons.event_busy_outlined,
                  title: 'NO MATCHES HERE',
                  message: 'No fixtures match this season filter yet.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => TeamSeasonMatchCard(
                    match: filtered[index],
                    competition: competition,
                    onTap: () => onOpenMatch(filtered[index]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _PredictionsTab extends StatelessWidget {
  const _PredictionsTab({
    required this.fixtures,
    required this.onOpenMatch,
    super.key,
  });

  final List<SportMatch> fixtures;
  final ValueChanged<SportMatch> onOpenMatch;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PredictionCubit, PredictionState>(
      builder: (context, state) {
        final matches =
            fixtures.where((match) {
              if (match.status == MatchStatus.upcoming) return true;
              return state.predictionsForMatch(match.id).isNotEmpty;
            }).toList()..sort((a, b) {
              final rank = _predictionRank(
                a,
                state,
              ).compareTo(_predictionRank(b, state));
              return rank == 0 ? a.kickoff.compareTo(b.kickoff) : rank;
            });
        if (matches.isEmpty) {
          return const CyberNoDataState(
            icon: Icons.bolt_outlined,
            title: 'NO PREDICTIONS YET',
            message:
                'Upcoming match challenges and your settled picks will appear here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          itemCount: matches.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final match = matches[index];
            final prediction = state.predictionSummaryForMatch(match.id);
            return MatchPredictionCard(
              match: match,
              prediction: prediction,
              quiz:
                  state.quizzes[predictionStorageKey(
                    match.id,
                    prediction?.quizId ?? kDefaultPredictionQuizId,
                  )],
              favorite: state.favoriteSideFor(match),
              onTap: () => onOpenMatch(match),
            );
          },
        );
      },
    );
  }
}

int _predictionRank(SportMatch match, PredictionState state) {
  final prediction = state.predictionSummaryForMatch(match.id);
  if (match.status == MatchStatus.live && prediction != null) return 0;
  if (match.status == MatchStatus.upcoming && prediction != null) return 1;
  if (match.status == MatchStatus.upcoming) return 2;
  if (prediction?.status == PredictionStatus.locked) return 3;
  return 4;
}

class _PlayersTab extends StatelessWidget {
  const _PlayersTab({
    required this.players,
    required this.team,
    required this.sport,
    required this.accent,
    required this.competition,
    required this.onOpenPlayer,
    super.key,
  });

  final List<TeamSeasonPlayer> players;
  final SportTeam team;
  final Sport sport;
  final Color accent;
  final String competition;
  final ValueChanged<TeamSeasonPlayer> onOpenPlayer;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return const CyberNoDataState(
        icon: Icons.groups_outlined,
        title: 'ROSTER UPLINK PENDING',
        message:
            'ESPN has not published a roster for this team and season yet.',
      );
    }
    final groups = <String, List<TeamSeasonPlayer>>{};
    for (final player in players) {
      groups.putIfAbsent(_playerGroup(player, sport), () => []).add(player);
    }
    final order = sport == Sport.cricket
        ? const [
            'WICKETKEEPERS',
            'BATTERS',
            'ALL-ROUNDERS',
            'BOWLERS',
            'PLAYERS',
          ]
        : const [
            'GOALKEEPERS',
            'DEFENDERS',
            'MIDFIELDERS',
            'FORWARDS',
            'PLAYERS',
          ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        for (final label in order)
          if (groups[label] case final group? when group.isNotEmpty) ...[
            CyberSectionHeading(label: '$label // ${group.length}'),
            const SizedBox(height: 8),
            for (final player in group) ...[
              _PlayerRow(
                player: player,
                team: team,
                sport: sport,
                accent: accent,
                competition: competition,
                onTap: () => onOpenPlayer(player),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.player,
    required this.team,
    required this.sport,
    required this.accent,
    required this.competition,
    required this.onTap,
  });

  final TeamSeasonPlayer player;
  final SportTeam team;
  final Sport sport;
  final Color accent;
  final String competition;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Open ${player.name} player dossier',
    child: PressableScale(
      onTap: onTap,
      child: ClipPath(
        clipper: const HudChamferClipper(bigCut: 10, smallCut: 2),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: Cyber.panel,
            border: Border.all(color: Cyber.line.withValues(alpha: 0.36)),
          ),
          child: Row(
            children: [
              if (sport == Sport.cricket)
                CricketPlayerPortrait(
                  athleteId: player.id,
                  name: player.name,
                  accent: accent,
                  size: 38,
                )
              else
                ClipPath(
                  clipper: const HudChamferClipper(bigCut: 7, smallCut: 2),
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    color: accent.withValues(alpha: 0.14),
                    child: Text(
                      player.jersey?.isNotEmpty == true ? player.jersey! : '--',
                      style: Cyber.display(12, color: accent),
                    ),
                  ),
                ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.body(
                        13,
                        color: AppTheme.whiteColor,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      player.displayRole,
                      style: Cyber.label(8, color: Cyber.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TeamLogo(
                team: team,
                sport: sport,
                competition: competition,
                width: 25,
                height: 23,
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 18, color: accent),
            ],
          ),
        ),
      ),
    ),
  );
}

String _playerGroup(TeamSeasonPlayer player, Sport sport) {
  final role = '${player.positionAbbreviation ?? ''} ${player.role ?? ''}'
      .toLowerCase();
  if (sport == Sport.cricket) {
    if (role.contains('wicket') || role.contains('wk')) return 'WICKETKEEPERS';
    if (role.contains('all')) return 'ALL-ROUNDERS';
    if (role.contains('bowl')) return 'BOWLERS';
    if (role.contains('bat')) return 'BATTERS';
    return 'PLAYERS';
  }
  if (role.contains('goalkeeper') || RegExp(r'\bgk\b').hasMatch(role)) {
    return 'GOALKEEPERS';
  }
  if (role.contains('defender') || RegExp(r'\bdf?\b').hasMatch(role)) {
    return 'DEFENDERS';
  }
  if (role.contains('midfielder') || RegExp(r'\bmf?\b').hasMatch(role)) {
    return 'MIDFIELDERS';
  }
  if (role.contains('forward') || RegExp(r'\bfw?\b').hasMatch(role)) {
    return 'FORWARDS';
  }
  return 'PLAYERS';
}

class _SyncStrip extends StatelessWidget {
  const _SyncStrip({
    required this.refreshing,
    required this.failed,
    required this.onRetry,
  });

  final bool refreshing;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    button: failed,
    label: refreshing ? 'Refreshing ESPN data' : 'ESPN refresh failed, retry',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: failed ? onRetry : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 28),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: Cyber.panel2,
        child: Row(
          children: [
            Icon(
              refreshing ? Icons.sensors : Icons.cloud_off_outlined,
              size: 14,
              color: refreshing ? Cyber.cyan : Cyber.amber,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                refreshing
                    ? 'SYNCING LATEST ESPN TEAM DATA'
                    : 'LIVE REFRESH OFFLINE // USING BUNDLED DATA',
                style: Cyber.label(
                  8,
                  color: refreshing ? Cyber.cyan : Cyber.amber,
                  letterSpacing: 1,
                ),
              ),
            ),
            if (failed) Text('RETRY', style: Cyber.label(8, color: Cyber.cyan)),
          ],
        ),
      ),
    ),
  );
}

class _HubLoader extends StatelessWidget {
  const _HubLoader({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Cyber.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'READING ESPN SEASON PACKAGE',
          style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.2),
        ),
      ],
    ),
  );
}
