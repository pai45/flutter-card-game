import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/prediction/prediction_cubit.dart';
import '../../blocs/prediction/prediction_state.dart';
import '../../config/theme.dart';
import '../../models/league.dart';
import '../../models/sport_match.dart';
import '../../models/team_standing.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import 'match_prediction_screen.dart';
import 'widgets/match_pick_card.dart';
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
              final pickFixtures = fixtures
                  .where((m) => m.status != MatchStatus.finished)
                  .toList();

              return Column(
                children: [
                  DetailTopBar(title: '${league.shortCode} · ${team.shortName}'),
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
                        if (pickFixtures.isEmpty)
                          const _EmptyNote('No open markets for this team.')
                        else
                          for (final match in pickFixtures) ...[
                            MatchPickCard(match: match, standings: standings),
                            const SizedBox(height: 12),
                          ],
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
      child: Text(text, style: Cyber.body(12.5, color: Cyber.muted)),
    );
  }
}
