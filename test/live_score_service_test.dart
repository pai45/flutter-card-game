import 'package:card_game/models/sport_match.dart';
import 'package:card_game/services/live_score_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('ignores unsupported feeds without touching the fixture', () async {
    var called = false;
    final service = LiveScoreService(
      client: MockClient((_) async {
        called = true;
        return http.Response('[]', 200);
      }),
    );

    final enriched = await service.enrich(
      _match.copyWith(leagueId: 'epl', id: 'epl_liv_mc'),
    );

    expect(called, isFalse);
    expect(enriched.homeScore, isNull);
    expect(enriched.liveStatusNote, isNull);
  });

  test(
    'parses live OpenLigaDB fixture and swaps away/home when needed',
    () async {
      final service = LiveScoreService(
        client: MockClient((request) async {
          expect(request.url.path, '/getmatchdata/wm26/2026');
          return http.Response(_liveBody, 200);
        }),
        now: () => DateTime.utc(2026, 7, 4, 22, 4),
      );

      final enriched = await service.enrich(_match);

      expect(enriched.status, MatchStatus.live);
      expect(enriched.liveMinute, 64);
      expect(enriched.homeScore, '1');
      expect(enriched.awayScore, '0');
      expect(enriched.liveLastUpdated, DateTime.utc(2026, 7, 4, 22, 4));
      expect(enriched.liveStatusNote, isNull);
    },
  );

  test('parses finished fixture and creates result line', () async {
    final service = LiveScoreService(
      client: MockClient((_) async => http.Response(_finishedBody, 200)),
      now: () => DateTime(2026, 7, 5, 5),
    );

    final enriched = await service.enrich(_match);

    expect(enriched.status, MatchStatus.finished);
    expect(enriched.homeScore, '2');
    expect(enriched.awayScore, '1');
    expect(enriched.resultLine, 'France won 2-1');
    expect(enriched.liveMinute, isNull);
  });

  test('missing fixture keeps seeded match with unavailable note', () async {
    final service = LiveScoreService(
      client: MockClient((_) async => http.Response('[]', 200)),
    );

    final enriched = await service.enrich(_match);

    expect(enriched.homeScore, isNull);
    expect(enriched.liveStatusNote, 'Live score fixture not found.');
  });

  test('API error keeps seeded match with status code note', () async {
    final service = LiveScoreService(
      client: MockClient((_) async => http.Response('Too many requests', 429)),
    );

    final enriched = await service.enrich(_match);

    expect(enriched.homeScore, isNull);
    expect(enriched.liveStatusNote, 'Live score unavailable (429).');
  });
}

final _match = SportMatch(
  id: 'fifa_fra_par',
  leagueId: 'fifa',
  sport: Sport.football,
  home: _france,
  away: _paraguay,
  kickoff: DateTime.utc(2026, 7, 4, 21),
  status: MatchStatus.upcoming,
);

const _france = SportTeam(
  id: 'fra',
  name: 'France',
  shortName: 'FRA',
  color: Color(0xff1d4ed8),
);

const _paraguay = SportTeam(
  id: 'par',
  name: 'Paraguay',
  shortName: 'PAR',
  color: Color(0xffd7263d),
);

const _liveBody = '''
[
  {
    "matchDateTimeUTC": "2026-07-04T21:00:00Z",
    "matchIsFinished": false,
    "team1": { "teamName": "Paraguay", "shortName": "PAR" },
    "team2": { "teamName": "Frankreich", "shortName": "FRA" },
    "matchResults": [
      {
        "pointsTeam1": 0,
        "pointsTeam2": 1,
        "resultOrderID": 1,
        "resultTypeID": 1
      }
    ],
    "goals": []
  }
]
''';

const _finishedBody = '''
[
  {
    "matchDateTimeUTC": "2026-07-04T21:00:00Z",
    "matchIsFinished": true,
    "team1": { "teamName": "France", "shortName": "FRA" },
    "team2": { "teamName": "Paraguay", "shortName": "PAR" },
    "matchResults": [
      {
        "pointsTeam1": 1,
        "pointsTeam2": 1,
        "resultOrderID": 1,
        "resultTypeID": 1
      },
      {
        "pointsTeam1": 2,
        "pointsTeam2": 1,
        "resultOrderID": 2,
        "resultTypeID": 2
      }
    ],
    "goals": []
  }
]
''';
