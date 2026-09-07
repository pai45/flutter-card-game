import 'package:card_game/config/theme.dart';
import 'package:card_game/models/football_player_profile.dart';
import 'package:card_game/models/league.dart';
import 'package:card_game/models/league_stat_leaders.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/screens/predictions/football_player_profile_screen.dart';
import 'package:card_game/services/espn_football_player_profile_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ProfileService extends EspnFootballPlayerProfileService {
  const _ProfileService(this.profile);

  final FootballPlayerProfile profile;

  @override
  Future<FootballPlayerProfile?> fetch({
    required String leagueId,
    required String athleteId,
    required int? seasonYear,
    SportTeam? team,
  }) async => profile;
}

void main() {
  const team = SportTeam(
    id: '101',
    name: 'Rayo Vallecano',
    shortName: 'RAY',
    color: Cyber.cyan,
  );
  const leader = StatLeader(
    athleteId: '276652',
    name: 'Sergio Camello',
    team: team,
    position: 'F',
    value: 5,
    displayValue: '5',
  );
  const profile = FootballPlayerProfile(
    athleteId: '276652',
    name: 'Sergio Camello',
    team: team,
    seasonYear: 2026,
    position: 'Forward',
    jersey: '10',
    age: 25,
    citizenship: 'Spain',
    active: true,
    displayHeight: "5' 10\"",
    displayWeight: '150 lbs',
    statGroups: [
      FootballPlayerSeasonStatGroup(
        key: 'offensive',
        label: 'Offensive',
        stats: [
          FootballPlayerSeasonStat(
            key: 'totalGoals',
            label: 'G',
            displayValue: '5',
            value: 5,
          ),
          FootballPlayerSeasonStat(
            key: 'goalAssists',
            label: 'A',
            displayValue: '1',
            value: 1,
          ),
          FootballPlayerSeasonStat(
            key: 'appearances',
            label: 'APP',
            displayValue: '4',
            value: 4,
          ),
          FootballPlayerSeasonStat(
            key: 'minutes',
            label: 'MIN',
            displayValue: '248',
            value: 248,
          ),
        ],
      ),
    ],
  );

  testWidgets('renders the ESPN-backed player season dossier', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const FootballPlayerProfileScreen(
          league: League(
            id: 'esp.1',
            name: 'Spanish LaLiga',
            shortCode: 'LALIGA',
            accent: Cyber.cyan,
          ),
          leader: leader,
          seasonYear: 2026,
          service: _ProfileService(profile),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('SCOUT COMPLETE'), findsOneWidget);
    expect(find.text('SERGIO CAMELLO'), findsOneWidget);
    expect(find.text('PLAYER INTEL'), findsOneWidget);
    expect(find.text('2026 SEASON IMPACT'), findsOneWidget);
    expect(find.text('SCOUTING REPORT'), findsOneWidget);
    expect(find.text('ATTACK'), findsOneWidget);
    expect(find.text('248'), findsNWidgets(2));
  });
}
