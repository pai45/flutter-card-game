import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/picks/picks_cubit.dart';
import '../../blocs/picks/picks_state.dart';
import '../../blocs/prediction/prediction_cubit.dart';
import '../../blocs/prediction/prediction_state.dart';
import '../../config/theme.dart';
import '../../models/league.dart';
import '../../models/picks.dart';
import '../../models/sport_match.dart';
import '../../models/team_standing.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import 'market_detail_screen.dart';
import 'match_prediction_screen.dart';
import 'widgets/pick_market_card.dart';
import 'widgets/pick_trade_sheet.dart';
import 'widgets/match_prediction_card.dart';
import 'widgets/standings_table.dart';

/// A single team's hub within a league: its standing summary, its fixtures
/// ("PREDICTION CENTER") and its quick markets ("PICKS CENTER"). Reached by
/// tapping a row in [StandingsTable] on the league detail screen.
class TeamDetailScreen extends StatelessWidget {
  const TeamDetailScreen({required this.team, required this.league, super.key});

  final SportTeam team;
  final League league;

  void _openMatch(BuildContext context, SportMatch match) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MatchPredictionScreen(match: match),
      ),
    );
  }

  void _openPickMarket(BuildContext context, String marketId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MarketDetailScreen(marketId: marketId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: CyberPlainBackground(
        child: SafeArea(
          child: BlocBuilder<PredictionCubit, PredictionState>(
            builder: (context, state) {
              final standings = state.standingsFor(league.id);
              final standing = _standingFor(standings, team.id);
              final fixtures = state.fixturesForTeam(league.id, team.id);

              return Column(
                children: [
                  DetailTopBar(
                    title: '${league.shortCode} · ${team.shortName}',
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                      children: [
                        TeamHeader(team: team, standing: standing),
                        const SizedBox(height: 24),
                        const _Heading(label: 'PREDICTION CENTER'),
                        const SizedBox(height: 12),
                        if (fixtures.isEmpty)
                          const _EmptyNote(
                            'No fixtures for this team yet — check back on match day.',
                          )
                        else
                          for (final match in fixtures) ...[
                            MatchPredictionCard(
                              match: match,
                              prediction: state.predictionFor(match.id),
                              onTap:
                                  (match.predictable ||
                                      state.predictionFor(match.id) != null)
                                  ? () => _openMatch(context, match)
                                  : null,
                            ),
                            const SizedBox(height: 12),
                          ],
                        const SizedBox(height: 12),
                        const _Heading(label: 'PICKS CENTER'),
                        const SizedBox(height: 12),
                        BlocBuilder<PicksCubit, PicksState>(
                          builder: (context, picksState) {
                            final markets = picksState.markets
                                .where(
                                  (m) =>
                                      m.leagueId == league.id &&
                                      _marketMentionsTeam(m, team),
                                )
                                .toList();
                            if (markets.isEmpty) {
                              return const _EmptyNote(
                                'No markets for this team.',
                              );
                            }
                            return Column(
                              children: [
                                for (final market in markets) ...[
                                  PickMarketCard(
                                    market: market,
                                    positions: picksState.positionsForMarket(
                                      market.id,
                                    ),
                                    onOpen: () =>
                                        _openPickMarket(context, market.id),
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
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

TeamStanding? _standingFor(List<TeamStanding> standings, String teamId) {
  for (final s in standings) {
    if (s.team.id == teamId) return s;
  }
  return null;
}

bool _marketMentionsTeam(PickMarket market, SportTeam team) {
  final needle = team.name.toLowerCase();
  final short = team.shortName.toLowerCase();
  bool contains(String? value) {
    final text = value?.toLowerCase() ?? '';
    return text.contains(needle) || text.contains(short);
  }

  return contains(market.question) ||
      contains(market.homeLabel) ||
      contains(market.awayLabel) ||
      market.outcomes.any((outcome) => contains(outcome.label));
}

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

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(text, style: Cyber.body(13, color: Cyber.muted)),
    );
  }
}
