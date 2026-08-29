import 'package:card_game/models/sport_match.dart';
import 'package:card_game/services/football_match_package_service.dart';
import 'package:card_game/services/prediction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bundled football package preserves every supplied data section',
    () async {
      final match = await const FootballMatchPackageService().loadBundled();

      expect(match.id, FootballMatchPackageService.bundledMatchId);
      expect(match.leagueId, 'eng.1');
      expect(match.status, MatchStatus.finished);
      expect(match.home.name, 'Fulham');
      expect(match.away.name, 'Chelsea');
      expect(match.homeScore, '2');
      expect(match.awayScore, '3');

      expect(match.teamStats, hasLength(7));
      expect(match.timelineEvents, hasLength(23));
      expect(match.commentary, hasLength(104));
      expect(match.footballMomentum?.series, hasLength(98));
      expect(match.footballMomentum?.goals, hasLength(5));
      expect(match.footballDetails?.scorers, hasLength(5));
      expect(match.homeLineup?.startingXI, hasLength(11));
      expect(match.homeLineup?.substitutes, hasLength(9));
      expect(match.awayLineup?.startingXI, hasLength(11));
      expect(match.awayLineup?.substitutes, hasLength(9));

      expect(match.footballDetails?.venue, 'Craven Cottage');
      expect(match.footballDetails?.attendance, 27461);
      expect(match.footballDetails?.scorers.first.name, 'João Pedro');
      expect(match.awayLineup?.startingXI.first.name, 'Robert Sánchez');
    },
  );

  test(
    'prototype fixture and EPL league are registered in the catalog',
    () async {
      final repository = MockPredictionRepository();
      final leagues = await repository.leagues();
      final fixtures = await repository.fixtures(sport: Sport.football);

      expect(leagues.any((league) => league.id == 'eng.1'), isTrue);
      expect(
        fixtures.any(
          (fixture) => fixture.id == FootballMatchPackageService.bundledMatchId,
        ),
        isTrue,
      );
      expect(
        await repository.fixtureById(
          FootballMatchPackageService.bundledMatchId,
        ),
        isNotNull,
      );
    },
  );
}
