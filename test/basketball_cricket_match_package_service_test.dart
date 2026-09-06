import 'dart:convert';

import 'package:card_game/models/sport_match.dart';
import 'package:card_game/services/basketball_match_package_service.dart';
import 'package:card_game/services/cricket_match_package_service.dart';
import 'package:card_game/services/prediction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bundled basketball package preserves every supplied category',
    () async {
      final match = await const BasketballMatchPackageService().loadBundled();
      final details = match.basketballDetails!;

      expect(match.id, BasketballMatchPackageService.bundledMatchId);
      expect(match.leagueId, 'nba');
      expect(match.status, MatchStatus.finished);
      expect(match.home.name, 'San Antonio Spurs');
      expect(match.away.name, 'New York Knicks');
      expect(match.homeScore, '90');
      expect(match.awayScore, '94');
      expect(match.teamStats, hasLength(12));
      expect(details.plays, hasLength(96));
      expect(details.turningPoints, hasLength(10));
      expect(
        details.plays.where((play) => play.coordinate != null),
        hasLength(64),
      );
      expect(
        details.injuries.expand((report) => report.injuries),
        hasLength(4),
      );
      expect(details.leaders.expand((group) => group.leaders), hasLength(6));
      expect(details.officials, hasLength(4));
      expect(details.teams, hasLength(2));
      expect(details.teams[0].players, hasLength(15));
      expect(details.teams[1].players, hasLength(15));
      expect(match.basketballScorecard?.homeBoxscore.players, hasLength(15));
      expect(match.basketballScorecard?.awayBoxscore.players, hasLength(15));
    },
  );

  test('bundled cricket package preserves every supplied category', () async {
    final match = await const CricketMatchPackageService().loadBundled();
    final details = match.cricketDetails!;

    expect(match.id, CricketMatchPackageService.bundledMatchId);
    expect(match.leagueId, 'ipl');
    expect(match.status, MatchStatus.finished);
    expect(match.home.name, 'Royal Challengers Bengaluru');
    expect(match.away.name, 'Gujarat Titans');
    expect(match.teamStats, hasLength(7));
    expect(details.innings, hasLength(2));
    expect(match.cricketScorecard?.innings, hasLength(2));
    expect(details.notes, hasLength(25));
    expect(details.commentary, hasLength(18));
    expect(details.inningsProgress, hasLength(2));
    expect(details.inningsProgress[0].teamId, '1298769');
    expect(details.inningsProgress[0].points.last.runs, 155);
    expect(details.inningsProgress[0].points.last.wickets, 8);
    expect(details.inningsProgress[0].points.last.over, 20);
    expect(details.inningsProgress[1].teamId, '335970');
    expect(details.inningsProgress[1].points.last.runs, 161);
    expect(details.inningsProgress[1].points.last.wickets, 5);
    expect(details.inningsProgress[1].points.last.over, 18);
    expect(details.inningsRateProgress, hasLength(2));
    final firstRate = details.inningsRateProgress[0];
    final secondRate = details.inningsRateProgress[1];
    expect(firstRate.points, hasLength(120));
    expect(secondRate.points, hasLength(108));
    expect(firstRate.points.last.runs, 155);
    expect(secondRate.points.last.runs, 161);
    expect(
      firstRate.points.where((point) => point.boundary == 4),
      hasLength(15),
    );
    expect(
      firstRate.points.where((point) => point.boundary == 6),
      hasLength(3),
    );
    expect(
      secondRate.points.where((point) => point.boundary == 4),
      hasLength(18),
    );
    expect(
      secondRate.points.where((point) => point.boundary == 6),
      hasLength(7),
    );
    expect(firstRate.points[59].runRate, closeTo(6.3, 0.001));
    expect(secondRate.points[59].runRate, closeTo(10, 0.001));
    expect(
      secondRate.points.first.requiredRunRate(target: 156),
      closeTo(7.815, 0.001),
    );
    expect(secondRate.points.last.requiredRunRate(target: 156), 0);
    expect(details.officials, hasLength(6));
    expect(details.teams, hasLength(2));
    expect(details.teams[0].players, hasLength(12));
    expect(details.teams[1].players, hasLength(12));
    expect(match.cricketScorecard?.innings[0].batters, hasLength(10));
    expect(match.cricketScorecard?.innings[1].batters, hasLength(7));
    expect(match.cricketScorecard?.innings[0].bowlers, hasLength(5));
    expect(match.cricketScorecard?.innings[1].bowlers, hasLength(6));
    expect(
      match.cricketScorecard!.innings.expand((innings) => innings.partnerships),
      hasLength(6),
    );
  });

  test(
    'cricket decoder rejects boundary totals that drift from the innings',
    () async {
      final source = await rootBundle.loadString(
        CricketMatchPackageService.assetPath,
      );
      final root = jsonDecode(source) as Map<String, dynamic>;
      final timelines = root['inningsRateProgress'] as List<dynamic>;
      final first = timelines.first as Map<String, dynamic>;
      final points = first['points'] as List<dynamic>;
      final boundary = points.cast<Map<String, dynamic>>().firstWhere(
        (point) => point['boundary'] == 4,
      );
      boundary.remove('boundary');

      expect(
        () => const CricketMatchPackageService().decode(jsonEncode(root)),
        throwsFormatException,
      );
    },
  );

  test(
    'NBA and IPL prototypes are registered in the fixture catalog',
    () async {
      final repository = MockPredictionRepository();
      final leagues = await repository.leagues();
      final basketball = await repository.fixtures(sport: Sport.basketball);
      final cricket = await repository.fixtures(sport: Sport.cricket);

      expect(leagues.any((league) => league.id == 'nba'), isTrue);
      expect(leagues.any((league) => league.id == 'ipl'), isTrue);
      expect(
        basketball.any(
          (match) => match.id == BasketballMatchPackageService.bundledMatchId,
        ),
        isTrue,
      );
      expect(
        cricket.any(
          (match) => match.id == CricketMatchPackageService.bundledMatchId,
        ),
        isTrue,
      );
      expect(
        await repository.fixtureById(
          BasketballMatchPackageService.bundledMatchId,
        ),
        isNotNull,
      );
      expect(
        await repository.fixtureById(CricketMatchPackageService.bundledMatchId),
        isNotNull,
      );
    },
  );

  test('NBA Finals and RCB-GT stay on the local current day', () async {
    var currentDay = DateTime(2032, 2, 28, 9, 15);
    final repository = MockPredictionRepository(now: () => currentDay);

    Future<List<SportMatch>> bundledToday() async {
      final basketball = await repository.fixtures(sport: Sport.basketball);
      final cricket = await repository.fixtures(sport: Sport.cricket);
      return [
        basketball.singleWhere(
          (match) => match.id == BasketballMatchPackageService.bundledMatchId,
        ),
        cricket.singleWhere(
          (match) => match.id == CricketMatchPackageService.bundledMatchId,
        ),
      ];
    }

    for (final match in await bundledToday()) {
      expect(
        DateTime(match.kickoff.year, match.kickoff.month, match.kickoff.day),
        DateTime(2032, 2, 28),
      );
    }

    currentDay = DateTime(2032, 2, 29, 0, 5);
    for (final match in await bundledToday()) {
      expect(
        DateTime(match.kickoff.year, match.kickoff.month, match.kickoff.day),
        DateTime(2032, 2, 29),
      );
    }
  });
}
