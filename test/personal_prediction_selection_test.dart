import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:card_game/models/prediction.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/screens/predictions/widgets/personal_prediction_selection.dart';

void main() {
  final fixture = SportMatch(
    id: 'old',
    leagueId: 'review',
    sport: Sport.football,
    home: const SportTeam(
      id: 'h',
      name: 'Home',
      shortName: 'HOM',
      color: Colors.blue,
    ),
    away: const SportTeam(
      id: 'a',
      name: 'Away',
      shortName: 'AWA',
      color: Colors.red,
    ),
    kickoff: DateTime(2026, 1, 1),
    status: MatchStatus.finished,
  );
  const quiz = PredictionQuiz(
    matchId: 'old',
    id: 'main',
    title: 'Match quiz',
    questions: [
      QuizQuestion(
        id: 'q',
        text: 'Who wins?',
        options: ['Home', 'Away'],
        reward: 10,
        settledOptionIndex: 0,
      ),
    ],
  );
  final prediction = UserPrediction(
    matchId: 'old',
    answers: const {'q': 0},
    submittedAt: DateTime(2026, 1, 1),
    status: PredictionStatus.locked,
  );
  List<PersonalPredictionEntry> select(
    Iterable<UserPrediction> entries, {
    PredictionQuiz value = quiz,
    bool visible = true,
  }) => selectPersonalPredictions(
    predictions: entries,
    fixtures: {'old': fixture},
    quizzes: {'old::main': value},
    visible: (_) => visible,
  );
  test(
    'saved finished fixtures survive discovery selection and deduplicate per quiz',
    () {
      final entries = select([prediction, prediction]);
      expect(entries, hasLength(1));
      expect(entries.single.reveal, isTrue);
      final settled = select([
        prediction.copyWith(status: PredictionStatus.settled, rewardEarned: 10),
      ]);
      expect(settled.single.reveal, isFalse);
      expect(settled.single.prediction.rewardEarned, 10);
      expect(select([prediction], visible: false), isEmpty);
      expect(select([]), isEmpty);
    },
  );
  test('missing results remain history and never advertise a reveal', () {
    const unresolved = PredictionQuiz(
      matchId: 'old',
      id: 'main',
      title: 'Quiz',
      questions: [
        QuizQuestion(
          id: 'q',
          text: 'Who wins?',
          options: ['Home', 'Away'],
          reward: 10,
        ),
      ],
    );
    expect(select([prediction], value: unresolved).single.reveal, isFalse);
    expect(
      selectPersonalPredictions(
        predictions: [prediction],
        fixtures: const {},
        quizzes: {'old::main': quiz},
        visible: (_) => true,
      ),
      isEmpty,
    );
  });
}
