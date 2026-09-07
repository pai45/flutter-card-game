import 'package:card_game/models/sport_match.dart';
import 'package:card_game/services/football_match_package_service.dart';
import 'package:card_game/services/prediction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Fulham Chelsea stays on today across cached daily rollover', () async {
    var now = DateTime(2032, 2, 28, 23, 59);
    final repository = MockPredictionRepository(now: () => now);
    final source = await const FootballMatchPackageService().loadBundled();
    for (final day in [28, 29]) {
      now = DateTime(2032, 2, day, 23, 59);
      final fixtures = await repository.fixtures(sport: Sport.football);
      final listed = fixtures.singleWhere(
        (match) => match.id == FootballMatchPackageService.bundledMatchId,
      );
      final detail = await repository.fixtureById(listed.id);
      for (final match in [listed, detail!]) {
        expect(
          match.kickoff,
          DateTime(2032, 2, day, source.kickoff.hour, source.kickoff.minute),
        );
        expect(match.status, MatchStatus.finished);
        expect(match.homeScore, source.homeScore);
        expect(match.awayScore, source.awayScore);
        expect(match.commentary, hasLength(104));
        expect(match.footballMomentum?.series, hasLength(98));
      }
    }
  });

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
      expect(match.timelineEvents, hasLength(22));
      final halftime = match.timelineEvents!.singleWhere(
        (event) => event.type == MatchEventType.halftime,
      );
      expect(halftime.scoreDisplay, '1 - 2');
      expect(
        match.timelineEvents!.any(
          (event) => event.type == MatchEventType.secondHalf,
        ),
        isFalse,
      );
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
