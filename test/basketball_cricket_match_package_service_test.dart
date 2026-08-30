import 'package:card_game/models/sport_match.dart';
import 'package:card_game/services/basketball_match_package_service.dart';
import 'package:card_game/services/cricket_match_package_service.dart';
import 'package:card_game/services/prediction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
