import 'package:card_game/blocs/prediction/prediction_cubit.dart';
import 'package:card_game/models/league.dart';
import 'package:card_game/models/prediction.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/models/team_standing.dart';
import 'package:card_game/screens/predictions/match_prediction_screen.dart';
import 'package:card_game/services/prediction_repository.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/utils/sound_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AudioController.instance.muted.value = true;
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('prediction quiz reveals number, words, then options', (
    tester,
  ) async {
    final cubit = PredictionCubit(_QuizRepo(_quiz), SecureGameStorage());
    addTearDown(cubit.close);

    await tester.pumpWidget(
      BlocProvider<PredictionCubit>.value(
        value: cubit,
        child: MaterialApp(home: MatchPredictionScreen(match: _match)),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('1'), findsOneWidget);
    expect(find.text('WILL'), findsNothing);
    expect(find.text('YES'), findsNothing);

    await _pumpFrames(tester, const Duration(seconds: 4));

    expect(find.text('WILL'), findsOneWidget);
    expect(find.text('YES'), findsOneWidget);
  });

  testWidgets('prediction quiz keeps NEXT disabled until the current answer', (
    tester,
  ) async {
    final cubit = PredictionCubit(_QuizRepo(_quiz), SecureGameStorage());
    addTearDown(cubit.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(home: MatchPredictionScreen(match: _match)),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await _pumpFrames(tester, const Duration(seconds: 4));

    await _tapButton(tester, 'NEXT');
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('SECOND'), findsNothing);
    expect(find.text('2'), findsNothing);
  });
}

Future<void> _pumpFrames(WidgetTester tester, Duration duration) async {
  var elapsed = Duration.zero;
  const step = Duration(milliseconds: 16);
  while (elapsed < duration) {
    await tester.pump(step);
    elapsed += step;
  }
}

Future<void> _tapButton(WidgetTester tester, String label) {
  return tester.tap(
    find
        .ancestor(of: find.text(label), matching: find.byType(GestureDetector))
        .first,
  );
}

class _QuizRepo implements PredictionRepository {
  const _QuizRepo(this.quiz);

  final PredictionQuiz quiz;

  @override
  Future<List<League>> leagues() async => const [];

  @override
  Future<List<SportMatch>> fixtures({DateTime? day}) async => const [];

  @override
  Future<PredictionQuiz?> quizFor(String matchId) async =>
      matchId == quiz.matchId ? quiz : null;

  @override
  Future<List<TeamStanding>> standings(String leagueId) async => const [];
}

const _home = SportTeam(
  id: 'home',
  name: 'Home FC',
  shortName: 'HOM',
  color: Color(0xff31d0ff),
);

const _away = SportTeam(
  id: 'away',
  name: 'Away FC',
  shortName: 'AWY',
  color: Color(0xfff7c948),
);

final _match = SportMatch(
  id: 'quiz_match',
  leagueId: 'test',
  sport: Sport.football,
  home: _home,
  away: _away,
  kickoff: DateTime.now().add(const Duration(hours: 2)),
  status: MatchStatus.upcoming,
);

const _quiz = PredictionQuiz(
  matchId: 'quiz_match',
  questions: [
    QuizQuestion(
      id: 'q1',
      text: 'Will home win',
      options: ['Yes', 'No'],
      reward: 5,
    ),
    QuizQuestion(
      id: 'q2',
      text: 'Second question',
      options: ['Home', 'Away'],
      reward: 5,
    ),
  ],
);
