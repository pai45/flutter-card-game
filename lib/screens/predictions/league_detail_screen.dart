import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/prediction/prediction_cubit.dart';
import '../../blocs/prediction/prediction_state.dart';
import '../../config/theme.dart';
import '../../models/league.dart';
import '../../models/sport_match.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import 'match_prediction_screen.dart';
import 'team_detail_screen.dart';
import 'widgets/match_pick_card.dart';
import 'widgets/match_prediction_card.dart';
import 'widgets/standings_table.dart';

/// Per-league hub reached by tapping a league on the prediction home. Shows the
/// league's standings ("ALL TEAMS"), its fixtures ("PREDICTION CENTER") and its
/// quick markets ("PICKS CENTER"). Tapping a team drills into [TeamDetailScreen].
class LeagueDetailScreen extends StatelessWidget {
  const LeagueDetailScreen({required this.league, super.key});

  final League league;

  void _openMatch(BuildContext context, SportMatch match) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MatchPredictionScreen(match: match),
      ),
    );
  }

  void _openTeam(BuildContext context, SportTeam team) {
    playSound(SoundEffect.uiTap);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TeamDetailScreen(team: team, league: league),
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
              final fixtures = state.fixtures
                  .where((m) => m.leagueId == league.id)
                  .toList();
              final pickFixtures = fixtures
                  .where((m) => m.status != MatchStatus.finished)
                  .toList();

              return Column(
                children: [
                  DetailTopBar(title: '${league.shortCode} HUB'),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                      children: [
                        LeagueHeader(league: league, teamCount: standings.length),
                        const SizedBox(height: 22),
                        const _Heading(label: 'ALL TEAMS'),
                        const SizedBox(height: 10),
                        StandingsTable(
                          rows: standings,
                          onTapTeam: (team) => _openTeam(context, team),
                        ),
                        const SizedBox(height: 24),
                        const _Heading(label: 'PREDICTION CENTER'),
                        const SizedBox(height: 12),
                        if (fixtures.isEmpty)
                          const _EmptyNote('No fixtures scheduled.')
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
                          const _EmptyNote('No open markets right now.')
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

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(
        text,
        style: Cyber.body(12.5, color: Cyber.muted),
      ),
    );
  }
}
