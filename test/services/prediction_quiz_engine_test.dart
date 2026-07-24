import 'package:card_game/blocs/prediction/prediction_cubit.dart';
import 'package:card_game/models/basketball_scorecard.dart';
import 'package:card_game/models/cricket_scorecard.dart';
import 'package:card_game/models/league.dart';
import 'package:card_game/models/prediction.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/models/team_standing.dart';
import 'package:card_game/models/tennis_scorecard.dart';
import 'package:card_game/services/prediction_repository.dart';
import 'package:card_game/services/quiz_archetypes.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/services/settlement_writer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _home = SportTeam(
  id: 'home',
  name: 'Home',
  shortName: 'HOM',
  color: Colors.blue,
);
const _away = SportTeam(
  id: 'away',
  name: 'Away',
  shortName: 'AWY',
  color: Colors.red,
);

const _teamStats = BasketballTeamStats(
  fgMadeApt: '',
  fgPct: 0,
  tpMadeApt: '',
  tpPct: 0,
  ftMadeApt: '',
  ftPct: 0,
  rebounds: 0,
  assists: 0,
  steals: 0,
  blocks: 0,
  turnovers: 0,
);

SportMatch _fixture(Sport sport, {MatchStatus status = MatchStatus.finished}) {
  final base = SportMatch(
    id: '${sport.name}-fixture',
    leagueId: switch (sport) {
      Sport.basketball => 'wnba',
      Sport.tennis => 'atp',
      Sport.motorsport => 'f1',
      Sport.cricket => 't20',
      Sport.football => 'epl',
    },
    sport: sport,
    home: _home,
    away: _away,
    kickoff: DateTime(2026, 7, 20),
    status: status,
  );
  return switch (sport) {
    Sport.football => base.copyWith(
      homeScore: '2',
      awayScore: '1',
      timelineEvents: const [
        MatchEvent(
          minute: 12,
          isHomeTeam: true,
          playerName: 'Striker',
          type: MatchEventType.goal,
        ),
      ],
    ),
    Sport.cricket => base.copyWith(
      resultLine: 'Home won by 8 runs',
      cricketScorecard: const CricketScorecard(
        innings: [
          CricketInnings(
            teamName: 'Home',
            scoreText: '170-6',
            batters: [
              CricketBatter(
                name: 'A',
                runs: 88,
                balls: 50,
                fours: 8,
                sixes: 5,
                strikeRate: 176,
                dismissalText: 'caught',
              ),
            ],
            bowlers: [],
          ),
          CricketInnings(
            teamName: 'Away',
            scoreText: '162-7',
            batters: [
              CricketBatter(
                name: 'B',
                runs: 61,
                balls: 44,
                fours: 5,
                sixes: 4,
                strikeRate: 138.6,
                dismissalText: 'bowled',
              ),
            ],
            bowlers: [],
          ),
        ],
      ),
    ),
    Sport.basketball => base.copyWith(
      basketballScorecard: const BasketballScorecard(
        homeBoxscore: BasketballTeamBoxscore(
          teamName: 'Home',
          teamId: 'home',
          stats: _teamStats,
          players: [],
        ),
        awayBoxscore: BasketballTeamBoxscore(
          teamName: 'Away',
          teamId: 'away',
          stats: _teamStats,
          players: [],
        ),
        linescores: BasketballLinescores(
          homeScores: [22, 24, 21, 20],
          awayScores: [20, 18, 22, 19],
          homeTotal: 87,
          awayTotal: 79,
        ),
      ),
    ),
    Sport.tennis => base.copyWith(
      tennisScorecard: const TennisScorecard(
        sets: [
          TennisSet(homeScore: 6, awayScore: 4, isHomeWinner: true),
          TennisSet(homeScore: 7, awayScore: 5, isHomeWinner: true),
        ],
      ),
    ),
    Sport.motorsport => base.copyWith(
      f1Sessions: const [
        F1SessionResult(
          name: 'Qualifying',
          results: [
            '1. Driver A · McLaren',
            '2. Driver B · Ferrari',
            '3. Driver C · Mercedes',
          ],
        ),
        F1SessionResult(
          name: 'Race',
          results: [
            '1. Driver A · McLaren',
            '2. Driver C · Mercedes',
            '3. Driver B · Ferrari',
          ],
        ),
      ],
      f1DriverStandings: const [
        '1. Driver A · McLaren',
        '2. Driver B · Ferrari',
        '3. Driver C · Mercedes',
      ],
    ),
  };
}

void main() {
  group('five-question generation', () {
    for (final sport in Sport.values) {
      test('${sport.name} is deterministic and settles all five questions', () {
        final fixture = _fixture(sport);
        final first = QuizArchetypes.buildQuizFor(fixture);
        final second = QuizArchetypes.buildQuizFor(fixture);

        expect(first.questions, hasLength(5));
        expect(first.generated, isTrue);
        expect(first.schemaVersion, kGeneratedPredictionQuizSchemaVersion);
        expect(
          second.questions.map((question) => question.toJson()).toList(),
          first.questions.map((question) => question.toJson()).toList(),
        );

        final settled = SettlementWriter.computeQuizSettlement(fixture, first);
        expect(
          settled.settleable,
          isTrue,
          reason: '${sport.name} left a generated question unresolved',
        );
      });
    }

    test('quiz snapshots preserve answer semantics through JSON', () {
      final original = QuizArchetypes.buildQuizFor(_fixture(Sport.tennis));
      final restored = PredictionQuiz.fromJson(
        Map<String, dynamic>.from(original.toJson()),
      );

      expect(restored.generated, isTrue);
      expect(restored.schemaVersion, original.schemaVersion);
      expect(restored.questions, hasLength(5));
      expect(restored.questions.last.settlementRule['threshold'], 22.5);
    });
  });

  test('live intel reports both question and player-pick state', () {
    final fixture = _fixture(Sport.football, status: MatchStatus.live);
    final quiz = QuizArchetypes.buildQuizFor(fixture);
    final firstScorer = quiz.questions.firstWhere(
      (question) => question.id == 'first_scorer',
    );
    final intel = QuizArchetypes.liveIntel(fixture, firstScorer, 0);

    expect(intel.questionState, PredictionQuestionState.decided);
    expect(intel.pickState, PredictionPickState.leading);
  });

  test('live intel never invents a signal when ESPN data is missing', () {
    final fixture = SportMatch(
      id: 'missing-live-data',
      leagueId: 'epl',
      sport: Sport.football,
      home: _home,
      away: _away,
      kickoff: DateTime(2026, 7, 24, 12),
      status: MatchStatus.live,
    );
    final winner = QuizArchetypes.buildQuizFor(
      fixture,
    ).questions.firstWhere((question) => question.id == 'winner');

    final intel = QuizArchetypes.liveIntel(fixture, winner, 0);

    expect(intel.questionState, PredictionQuestionState.dataUnavailable);
    expect(intel.pickState, PredictionPickState.stillOpen);
  });

  test('settlement requires matching ESPN finals five minutes apart', () async {
    var now = DateTime(2026, 7, 24, 12);
    final repository = _FinalFixtureRepository(_fixture(Sport.football));
    final storage = _MemoryPredictionStorage();
    final firstCubit = PredictionCubit(repository, storage, now: () => now);

    await firstCubit.load();
    await firstCubit.loadSport(Sport.football);
    var quiz = await firstCubit.quizFor('football-fixture');
    expect(quiz, isNotNull);
    expect(quiz!.settleable, isFalse);
    expect(storage.checkpoints, hasLength(1));
    await firstCubit.close();

    now = now.add(const Duration(minutes: 4, seconds: 59));
    final resumedCubit = PredictionCubit(repository, storage, now: () => now);
    addTearDown(resumedCubit.close);
    await resumedCubit.load();
    await resumedCubit.refreshSport(Sport.football);
    quiz = await resumedCubit.quizFor('football-fixture');
    expect(quiz!.settleable, isFalse);

    now = now.add(const Duration(seconds: 1));
    await resumedCubit.refreshSport(Sport.football);
    quiz = await resumedCubit.quizFor('football-fixture');
    expect(quiz!.settleable, isTrue);
    expect(storage.checkpoints, isEmpty);
    expect(storage.quizzes.single.questions, hasLength(5));
  });

  test('a changed ESPN final resets the validation window', () async {
    var now = DateTime(2026, 7, 24, 12);
    final repository = _FinalFixtureRepository(_fixture(Sport.football));
    final storage = _MemoryPredictionStorage();
    final cubit = PredictionCubit(repository, storage, now: () => now);
    addTearDown(cubit.close);

    await cubit.load();
    await cubit.loadSport(Sport.football);
    final firstFingerprint = storage.checkpoints.single.fingerprint;

    repository.fixture = repository.fixture.copyWith(homeScore: '3');
    now = now.add(const Duration(minutes: 5));
    await cubit.refreshSport(Sport.football);

    expect(storage.checkpoints.single.fingerprint, isNot(firstFingerprint));
    expect(storage.checkpoints.single.firstSeenAt, now);
    expect((await cubit.quizFor('football-fixture'))!.settleable, isFalse);

    now = now.add(const Duration(minutes: 5));
    await cubit.refreshSport(Sport.football);
    expect((await cubit.quizFor('football-fixture'))!.settleable, isTrue);
  });

  test('a stale ESPN observation does not count as confirmation', () async {
    var now = DateTime(2026, 7, 24, 12);
    final firstObservedAt = now.subtract(const Duration(seconds: 10));
    final repository = _FinalFixtureRepository(
      _fixture(Sport.football).copyWith(liveLastUpdated: firstObservedAt),
    );
    final storage = _MemoryPredictionStorage();
    final cubit = PredictionCubit(repository, storage, now: () => now);
    addTearDown(cubit.close);

    await cubit.load();
    await cubit.loadSport(Sport.football);
    now = now.add(const Duration(minutes: 5));
    await cubit.refreshSport(Sport.football);

    expect((await cubit.quizFor('football-fixture'))!.settleable, isFalse);

    repository.fixture = repository.fixture.copyWith(liveLastUpdated: now);
    await cubit.refreshSport(Sport.football);

    expect((await cubit.quizFor('football-fixture'))!.settleable, isTrue);
  });

  test('a valid authored five-question quiz takes precedence', () async {
    final fixture = _fixture(Sport.tennis);
    final generated = QuizArchetypes.buildQuizFor(fixture);
    final authored = PredictionQuiz(
      matchId: fixture.id,
      title: 'AUTHORED MATCH MISSION',
      questions: generated.questions,
    );
    final repository = _FinalFixtureRepository(
      fixture,
      authoredQuizzes: [authored],
    );
    final cubit = PredictionCubit(repository, _MemoryPredictionStorage());
    addTearDown(cubit.close);

    await cubit.load();
    await cubit.loadSport(Sport.tennis);

    expect((await cubit.quizFor(fixture.id))!.title, authored.title);
  });
}

class _FinalFixtureRepository implements PredictionRepository {
  _FinalFixtureRepository(this.fixture, {this.authoredQuizzes = const []});

  SportMatch fixture;
  final List<PredictionQuiz> authoredQuizzes;

  @override
  Future<List<League>> leagues() async => const [];

  @override
  Future<List<SportMatch>> fixtures({DateTime? day, Sport? sport}) async =>
      sport == fixture.sport ? [fixture] : const [];

  @override
  Future<List<SportMatch>> enrichFixturesForSport(
    List<SportMatch> fixtures,
    Sport sport,
  ) async => fixtures;

  @override
  Future<List<PredictionQuiz>> quizzesFor(String matchId) async =>
      matchId == fixture.id ? authoredQuizzes : const [];

  @override
  Future<PredictionQuiz?> quizFor(String matchId, String quizId) async => null;

  @override
  Future<List<TeamStanding>> standings(String leagueId) async => const [];

  @override
  Future<PredictionVoteBreakdown?> votesFor(
    String matchId,
    String quizId,
    String questionId,
  ) async => null;

  @override
  Future<List<MatchPredictionLeaderboardEntry>> matchLeaderboard(
    String matchId,
    String quizId,
  ) async => const [];
}

class _MemoryPredictionStorage extends SecureGameStorage {
  List<PredictionQuiz> quizzes = [];
  List<SettlementValidationCheckpoint> checkpoints = [];

  @override
  Future<List<UserPrediction>> loadPredictions() async => const [];

  @override
  Future<List<PredictionQuiz>> loadPredictionQuizzes() async => quizzes;

  @override
  Future<void> savePredictionQuizzes(List<PredictionQuiz> quizzes) async {
    this.quizzes = quizzes;
  }

  @override
  Future<List<SettlementValidationCheckpoint>>
  loadPredictionSettlementCheckpoints() async => checkpoints;

  @override
  Future<void> savePredictionSettlementCheckpoints(
    List<SettlementValidationCheckpoint> checkpoints,
  ) async {
    this.checkpoints = checkpoints;
  }

  @override
  Future<void> savePredictions(List<UserPrediction> predictions) async {}
}
