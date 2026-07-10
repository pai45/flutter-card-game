import 'package:card_game/services/pick_repository.dart';
import 'package:card_game/services/prediction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('France vs Paraguay fixture appears on 05/07 local Match day', () async {
    final repository = MockPredictionRepository();
    final fixtures = await repository.fixtures();
    final match = fixtures.singleWhere((match) => match.id == 'fifa_fra_par');

    expect(match.home.name, 'France');
    expect(match.away.name, 'Paraguay');
    expect(match.kickoff, DateTime(2026, 7, 5, 2, 30));
    expect(match.leagueId, 'fifa');
  });

  test('France vs Paraguay quiz and linked picks are available', () async {
    final predictionRepository = MockPredictionRepository();
    final quizzes = await predictionRepository.quizzesFor('fifa_fra_par');

    expect(quizzes, hasLength(2));
    expect(quizzes.map((quiz) => quiz.id), ['main', 'events']);
    expect(quizzes.first.title, 'Scoreline Quiz');
    expect(quizzes.first.questions.first.text, 'Predict the full-time score');

    final pickRepository = MockPickRepository();
    final markets = await pickRepository.markets();
    final matchMarkets = markets
        .where((market) => market.matchId == 'fifa_fra_par')
        .toList();

    expect(matchMarkets, hasLength(5));
    expect(
      matchMarkets.map((market) => market.id),
      containsAll([
        'fifa_fra_par_winner',
        'fifa_fra_par_btts',
        'fifa_fra_par_fra_over_1_5',
        'fifa_fra_par_first_goal',
        'fifa_fra_par_red_card',
      ]),
    );
  });

  test('FIFA fixtures are knockout-only and expose quiz set hubs', () async {
    final repository = MockPredictionRepository();
    final fixtures = await repository.fixtures();
    final fifaFixtures = fixtures
        .where((fixture) => fixture.leagueId == 'fifa')
        .toList();

    expect(fifaFixtures, hasLength(32));
    expect(
      fifaFixtures.every(
        (fixture) => !fixture.kickoff.isBefore(DateTime(2026, 6, 28)),
      ),
      isTrue,
    );
    expect(
      fifaFixtures.every(
        (fixture) => !fixture.kickoff.isAfter(DateTime(2026, 7, 19, 23, 59)),
      ),
      isTrue,
    );

    final footballQuizzes = await repository.quizzesFor('fifa_r16_por_esp');
    expect(footballQuizzes, hasLength(2));
    expect(footballQuizzes.map((quiz) => quiz.id), ['main', 'events']);
    expect(footballQuizzes.first.title, 'Scoreline Quiz');
    expect(footballQuizzes.last.title, 'Match Events Quiz');
    expect(footballQuizzes.last.questions.first.options, [
      'Portugal',
      'Draw',
      'Spain',
    ]);

    final cricketQuizzes = await repository.quizzesFor('ipl_pjk_kkr');
    expect(cricketQuizzes, hasLength(2));
    expect(cricketQuizzes.map((quiz) => quiz.id), ['main', 'events']);
    expect(cricketQuizzes.first.title, 'Match Basics Quiz');
    expect(cricketQuizzes.last.title, 'Match Events Quiz');
    expect(cricketQuizzes.last.questions.first.options, [
      'Punjab',
      'KKR',
      'Tie',
    ]);

    for (final fixture in fifaFixtures) {
      final quizzes = await repository.quizzesFor(fixture.id);
      expect(
        quizzes,
        hasLength(2),
        reason: '${fixture.id} should use the two-card Predict tab hub',
      );
      expect(
        quizzes.map((quiz) => quiz.id),
        ['main', 'events'],
        reason: '${fixture.id} should expose main and events quiz sets',
      );
    }
  });
}
