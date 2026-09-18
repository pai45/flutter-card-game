import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/prediction/prediction_cubit.dart';
import '../../blocs/prediction/prediction_state.dart';
import '../../config/sport_modules.dart';
import '../../config/theme.dart';
import '../../data/team_palettes.dart';
import '../../models/prediction.dart';
import '../../models/sport_match.dart';
import '../../models/unlock_progress.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import '../../widgets/staggered_card_entrance.dart';
import 'widgets/match_prediction_card.dart';

class MatchSearchScreen extends StatefulWidget {
  const MatchSearchScreen({required this.onOpenMatch, super.key});

  final ValueChanged<SportMatch> onOpenMatch;

  @override
  State<MatchSearchScreen> createState() => _MatchSearchScreenState();
}

class _MatchSearchScreenState extends State<MatchSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = '';
  bool _scanComplete = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadAllSports());
    });
  }

  Future<void> _loadAllSports() async {
    await context.read<PredictionCubit>().loadAllSports();
    if (!mounted) return;
    setState(() => _scanComplete = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _updateQuery(String value) {
    setState(() => _query = value.trim().toLowerCase());
  }

  void _clearQuery() {
    _controller.clear();
    _updateQuery('');
    _focusNode.requestFocus();
  }

  void _openMatch(SportMatch match) {
    HapticFeedback.selectionClick();
    widget.onOpenMatch(match);
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'MATCH SEARCH',
      subtitle: '// TEAM + LEAGUE FINDER',
      leading: IconButton(
        key: const ValueKey('match-search-back-button'),
        tooltip: 'Back to matches',
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_ios_new, color: Cyber.cyan, size: 18),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _focusNode.unfocus,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: CyberSearchField(
                key: const ValueKey('match-search-field'),
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                hintText: 'Search team or league',
                onChanged: _updateQuery,
                onSubmitted: (_) => _focusNode.unfocus(),
                onClear: _clearQuery,
              ),
            ),
            Expanded(
              child: BlocBuilder<PredictionCubit, PredictionState>(
                builder: (context, state) {
                  final groups = _query.length < 2
                      ? const <_MatchSearchGroup>[]
                      : _groupsForQuery(
                          state,
                          _query,
                          // Locked sports stay teasers: search never surfaces
                          // their fixtures.
                          (context.read<GameBloc?>()?.state.unlocks ??
                                  const UnlockProgress())
                              .isSportUnlocked,
                        );
                  final missingSports = Sport.values
                      .where((sport) => !state.loadedSports.contains(sport))
                      .toList(growable: false);
                  return ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      if (!_scanComplete)
                        _ScanStatusPanel(
                          loaded: state.loadedSports.length,
                          total: Sport.values.length,
                        )
                      else if (missingSports.isNotEmpty)
                        _PartialFeedPanel(missingSports: missingSports),
                      if (!_scanComplete || missingSports.isNotEmpty)
                        const SizedBox(height: 16),
                      if (_query.isEmpty)
                        const CyberNoDataState(
                          icon: Icons.radar_rounded,
                          title: 'SCAN THE FIXTURE NETWORK',
                          message:
                              'Search every loaded sport by team name, team code, league name, or league code.',
                          spark: Icons.search_rounded,
                        )
                      else if (_query.length < 2)
                        const CyberNoDataState(
                          icon: Icons.keyboard_rounded,
                          title: 'ADD ONE MORE SIGNAL',
                          message:
                              'Enter at least two characters to start searching the fixture network.',
                          spark: Icons.bolt_rounded,
                        )
                      else if (groups.isEmpty)
                        CyberNoDataState(
                          icon: Icons.search_off_rounded,
                          title: _scanComplete
                              ? 'NO MATCH FOUND'
                              : 'SCANNING FOR MATCHES',
                          message: _scanComplete
                              ? 'No available fixture uses “${_controller.text.trim()}”. Try a team code or league abbreviation.'
                              : 'More sport feeds are still coming online. Results will appear as they are found.',
                          spark: Icons.radar_rounded,
                        )
                      else ...[
                        _ResultTelemetry(
                          entityCount: groups.length,
                          fixtureCount: groups.fold(
                            0,
                            (total, group) => total + group.fixtures.length,
                          ),
                        ),
                        const SizedBox(height: 16),
                        for (
                          var groupIndex = 0;
                          groupIndex < groups.length;
                          groupIndex++
                        ) ...[
                          _SearchGroupHeader(group: groups[groupIndex]),
                          const SizedBox(height: 12),
                          for (
                            var matchIndex = 0;
                            matchIndex < groups[groupIndex].fixtures.length;
                            matchIndex++
                          ) ...[
                            StaggeredCardEntrance(
                              index: groupIndex + matchIndex,
                              animate: true,
                              child: MatchPredictionCard(
                                key: ValueKey(
                                  'match-search-fixture-${groups[groupIndex].fixtures[matchIndex].id}',
                                ),
                                match: groups[groupIndex].fixtures[matchIndex],
                                prediction: state.predictionSummaryForMatch(
                                  groups[groupIndex].fixtures[matchIndex].id,
                                ),
                                quiz: _quizFor(
                                  state,
                                  groups[groupIndex].fixtures[matchIndex],
                                ),
                                favorite: state.favoriteSideFor(
                                  groups[groupIndex].fixtures[matchIndex],
                                ),
                                onTap: () => _openMatch(
                                  groups[groupIndex].fixtures[matchIndex],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

PredictionQuiz? _quizFor(PredictionState state, SportMatch match) {
  final prediction = state.predictionSummaryForMatch(match.id);
  return state.quizzes[predictionStorageKey(
    match.id,
    prediction?.quizId ?? kDefaultPredictionQuizId,
  )];
}

enum _SearchEntityKind { league, team }

class _MatchSearchGroup {
  const _MatchSearchGroup({
    required this.key,
    required this.kind,
    required this.title,
    required this.code,
    required this.sport,
    required this.accent,
    required this.fixtures,
    required this.rank,
  });

  final String key;
  final _SearchEntityKind kind;
  final String title;
  final String code;
  final Sport sport;
  final Color accent;
  final List<SportMatch> fixtures;
  final int rank;
}

List<_MatchSearchGroup> _groupsForQuery(
  PredictionState state,
  String normalizedQuery,
  bool Function(Sport sport) sportOpen,
) {
  final groups = <_MatchSearchGroup>[];
  final fixturesByLeague = <String, List<SportMatch>>{};
  for (final fixture in state.fixtures) {
    if (!sportOpen(fixture.sport)) continue;
    fixturesByLeague.putIfAbsent(fixture.leagueId, () => []).add(fixture);
  }

  for (final league in state.leagues) {
    final fixtures = fixturesByLeague[league.id];
    if (fixtures == null || fixtures.isEmpty) continue;
    final rank = _queryRank(normalizedQuery, [league.name, league.shortCode]);
    if (rank == null) continue;
    fixtures.sort((a, b) => a.kickoff.compareTo(b.kickoff));
    groups.add(
      _MatchSearchGroup(
        key: league.id,
        kind: _SearchEntityKind.league,
        title: league.name,
        code: league.shortCode,
        sport: fixtures.first.sport,
        accent: league.accent,
        fixtures: fixtures,
        rank: rank,
      ),
    );
  }

  final teams = <String, ({SportTeam team, Sport sport})>{};
  for (final fixture in state.fixtures) {
    teams['${fixture.sport.name}:${fixture.home.id}'] = (
      team: fixture.home,
      sport: fixture.sport,
    );
    teams['${fixture.sport.name}:${fixture.away.id}'] = (
      team: fixture.away,
      sport: fixture.sport,
    );
  }
  for (final entry in teams.entries) {
    final candidate = entry.value;
    final rank = _queryRank(normalizedQuery, [
      candidate.team.name,
      candidate.team.shortName,
    ]);
    if (rank == null) continue;
    final fixtures =
        state.fixtures
            .where(
              (fixture) =>
                  fixture.sport == candidate.sport &&
                  (fixture.home.id == candidate.team.id ||
                      fixture.away.id == candidate.team.id),
            )
            .toList()
          ..sort((a, b) => a.kickoff.compareTo(b.kickoff));
    groups.add(
      _MatchSearchGroup(
        key: entry.key,
        kind: _SearchEntityKind.team,
        title: candidate.team.name,
        code: candidate.team.shortName,
        sport: candidate.sport,
        accent: paletteForTeam(
          candidate.team,
          sport: candidate.sport,
          competition: fixtures.isEmpty ? null : fixtures.first.leagueId,
        ).secondaryTextColor,
        fixtures: fixtures,
        rank: rank,
      ),
    );
  }

  groups.sort((a, b) {
    final kindOrder = a.kind.index.compareTo(b.kind.index);
    if (kindOrder != 0) return kindOrder;
    final rankOrder = a.rank.compareTo(b.rank);
    if (rankOrder != 0) return rankOrder;
    return a.title.compareTo(b.title);
  });
  return groups;
}

int? _queryRank(String query, List<String> values) {
  var best = 3;
  for (final raw in values) {
    final value = raw.trim().toLowerCase();
    if (value == query) {
      best = 0;
    } else if (value.startsWith(query)) {
      best = best > 1 ? 1 : best;
    } else if (value.contains(query)) {
      best = best > 2 ? 2 : best;
    }
  }
  return best == 3 ? null : best;
}

class _ScanStatusPanel extends StatelessWidget {
  const _ScanStatusPanel({required this.loaded, required this.total});

  final int loaded;
  final int total;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.radar_rounded, color: Cyber.cyan, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SCANNING SPORT NETWORK',
                  style: Cyber.label(10, letterSpacing: 1.5),
                ),
              ),
              Text(
                '$loaded/$total',
                style: Cyber.label(10, color: Cyber.muted, letterSpacing: 1.2),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CyberProgressBar(
            value: total == 0 ? 0 : loaded / total,
            accent: Cyber.cyan,
            height: 5,
          ),
        ],
      ),
    );
  }
}

class _PartialFeedPanel extends StatelessWidget {
  const _PartialFeedPanel({required this.missingSports});

  final List<Sport> missingSports;

  @override
  Widget build(BuildContext context) {
    final labels = missingSports
        .map((sport) => sportModuleFor(sport).label.toUpperCase())
        .join(' · ');
    return CyberPanel(
      accent: Cyber.amber,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(
            Icons.signal_wifi_statusbar_connected_no_internet_4,
            color: Cyber.amber,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'PARTIAL FEED // $labels UNAVAILABLE',
              style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.1),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultTelemetry extends StatelessWidget {
  const _ResultTelemetry({
    required this.entityCount,
    required this.fixtureCount,
  });

  final int entityCount;
  final int fixtureCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SectionLabel(label: 'SIGNALS FOUND'),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: Cyber.borderSubtle)),
        const SizedBox(width: 10),
        Text(
          '$entityCount ENTITIES // $fixtureCount FIXTURES',
          style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.1),
        ),
      ],
    );
  }
}

class _SearchGroupHeader extends StatelessWidget {
  const _SearchGroupHeader({required this.group});

  final _MatchSearchGroup group;

  @override
  Widget build(BuildContext context) {
    final sport = sportModuleFor(group.sport);
    final kindLabel = group.kind == _SearchEntityKind.league
        ? 'LEAGUE'
        : 'TEAM';
    final icon = group.kind == _SearchEntityKind.league
        ? Icons.emoji_events_outlined
        : sport.icon;
    return CyberPanel(
      key: ValueKey('match-search-result-${group.kind.name}-${group.key}'),
      accent: group.accent,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Icon(icon, color: group.accent, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$kindLabel // ${sport.label.toUpperCase()}',
                  style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.4),
                ),
                const SizedBox(height: 4),
                Text(
                  group.title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.display(14, letterSpacing: 1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${group.code.toUpperCase()} // ${group.fixtures.length}',
            style: Cyber.label(10, color: group.accent, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}
