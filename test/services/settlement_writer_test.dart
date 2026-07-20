import 'package:card_game/models/picks.dart';
import 'package:card_game/models/prediction.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/services/prediction_repository.dart';
import 'package:card_game/services/quiz_archetypes.dart';
import 'package:card_game/services/settlement_writer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SportTeam _team(String name) => SportTeam(
  id: name.toLowerCase(),
  name: name,
  shortName: name.substring(0, 3),
  color: const Color(0xffffffff),
);

SportMatch _footballMatch({String? homeScore, String? awayScore}) => SportMatch(
  id: 'f1',
  leagueId: 'test',
  sport: Sport.football,
  home: _team('Home'),
  away: _team('Away'),
  kickoff: DateTime(2026, 7, 20),
  status: MatchStatus.finished,
  homeScore: homeScore,
  awayScore: awayScore,
  timelineEvents: const [
    MatchEvent(minute: 10, isHomeTeam: true, playerName: 'X', type: MatchEventType.goal),
  ],
);

SportMatch _cricketMatch({String? resultLine}) => SportMatch(
  id: 'c1',
  leagueId: 'test',
  sport: Sport.cricket,
  home: _team('Home'),
  away: _team('Away'),
  kickoff: DateTime(2026, 7, 20),
  status: MatchStatus.finished,
  resultLine: resultLine,
);

PickMarket _market(String archetype, List<String> outcomeIds) => PickMarket(
  id: 'm1::$archetype',
  question: 'Test market',
  type: PickMarketType.match,
  sport: Sport.football,
  leagueId: 'test',
  leagueLabel: 'Test',
  status: PickMarketStatus.closed,
  outcomes: [
    for (final id in outcomeIds)
      PickOutcome(id: id, label: id, probabilityPercent: 50, color: const Color(0xffffffff)),
  ],
  volumeOz: 100,
  closesAt: DateTime(2026, 7, 20),
  matchId: 'm1',
);

void main() {
  group('SettlementWriter.computeQuizSettlement — football', () {
    test('a resolvable match produces a fully settleable quiz', () {
      final match = _footballMatch(homeScore: '2', awayScore: '1');
      final quiz = PredictionQuiz(matchId: match.id, questions: QuizArchetypes.buildFor(match));
      expect(quiz.settleable, isFalse, reason: 'freshly built quiz has no settled values yet');

      final settled = SettlementWriter.computeQuizSettlement(match, quiz);
      expect(settled.settleable, isTrue);
    });

    test('an unresolvable match still produces a settleable (all-voided) quiz', () {
      final match = _footballMatch(); // no score at all
      final quiz = PredictionQuiz(matchId: match.id, questions: QuizArchetypes.buildFor(match));
      final settled = SettlementWriter.computeQuizSettlement(match, quiz);

      expect(settled.settleable, isTrue, reason: 'never-stuck guarantee: void, don\'t strand');
      expect(settled.questions.every((q) => q.forcedVoid), isTrue);
    });
  });

  group('SettlementWriter.computeQuizSettlement — cricket', () {
    test('a no-result match voids every question but stays settleable', () {
      final match = _cricketMatch(resultLine: 'Match abandoned, no result');
      final quiz = PredictionQuiz(matchId: match.id, questions: QuizArchetypes.buildFor(match));
      final settled = SettlementWriter.computeQuizSettlement(match, quiz);

      expect(settled.settleable, isTrue);
      expect(settled.questions.every((q) => q.forcedVoid), isTrue);
    });
  });

  group('SettlementWriter.computeMarketSettlement', () {
    test('a resolvable winner market settles, never left closed/unresolved', () {
      final match = _footballMatch(homeScore: '2', awayScore: '0');
      final market = _market('winner', ['home', 'draw', 'away']);
      final settled = SettlementWriter.computeMarketSettlement(match, market);

      expect(settled.isResultKnown, isTrue);
      expect(settled.status, PickMarketStatus.settled);
      expect(settled.resolvedOutcomeId, 'home');
    });

    test('an unresolvable market is voided, never left closed/unresolved', () {
      final match = _footballMatch(); // no score
      final market = _market('winner', ['home', 'draw', 'away']);
      final settled = SettlementWriter.computeMarketSettlement(match, market);

      expect(settled.isResultKnown, isTrue);
      expect(settled.status, PickMarketStatus.voided);
      expect(settled.voidReason, isNotNull);
    });
  });

  group('never-stuck guarantee — batch across every generated archetype', () {
    test('every football+cricket quiz settles to settleable regardless of data', () {
      final matches = [
        _footballMatch(homeScore: '3', awayScore: '3'),
        _footballMatch(homeScore: '0', awayScore: '0'),
        _footballMatch(),
        _cricketMatch(resultLine: 'Home won by 10 runs'),
        _cricketMatch(resultLine: 'Match tied'),
        _cricketMatch(resultLine: 'No result'),
        _cricketMatch(),
      ];
      for (final match in matches) {
        final quiz = PredictionQuiz(matchId: match.id, questions: QuizArchetypes.buildFor(match));
        final settled = SettlementWriter.computeQuizSettlement(match, quiz);
        expect(
          settled.settleable,
          isTrue,
          reason: '${match.sport} fixture with resultLine="${match.resultLine}" left unsettleable',
        );
      }
    });
  });

  group('regression — hand-authored override still wins over the auto-generator', () {
    test('the World Cup third-place quiz (760516) is already settleable from the repository', () async {
      final repository = MockPredictionRepository();
      final quiz = await repository.quizFor('760516', kDefaultPredictionQuizId);
      expect(quiz, isNotNull);
      expect(
        quiz!.settleable,
        isTrue,
        reason: 'the hand-transcribed override must still resolve on its own, unmodified',
      );
      // Its exact score question is the ground-truth 4-6, not something the
      // generic auto-generator would produce independently — confirms
      // PredictionCubit.loadSport's "already settleable => leave alone"
      // check doesn't re-run the auto-generator over hand-authored data.
      final examples = {for (final q in quiz.questions) q.id: q};
      expect(examples['q1']!.settledHomeScore, 4);
      expect(examples['q1']!.settledAwayScore, 6);
    });
  });
}
