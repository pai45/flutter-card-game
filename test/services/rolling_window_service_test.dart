import 'package:card_game/blocs/picks/picks_cubit.dart';
import 'package:card_game/blocs/prediction/prediction_cubit.dart';
import 'package:card_game/models/league.dart';
import 'package:card_game/models/prediction.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/models/team_standing.dart';
import 'package:card_game/services/pick_repository.dart';
import 'package:card_game/services/prediction_repository.dart';
import 'package:card_game/services/rolling_window_service.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Delegates everything to a real [MockPredictionRepository] except
/// [enrichFixturesForSport], which normally fires real ESPN network calls
/// (`EspnScoreService.fetchDynamicMatchesForSport`) — undesirable in a unit
/// test that just wants to exercise the day-key gating/refresh-all logic,
/// not live network I/O.
class _NoNetworkPredictionRepository implements PredictionRepository {
  _NoNetworkPredictionRepository(this._inner);
  final PredictionRepository _inner;

  @override
  Future<List<League>> leagues() => _inner.leagues();
  @override
  Future<List<SportMatch>> fixtures({DateTime? day, Sport? sport}) =>
      _inner.fixtures(day: day, sport: sport);
  @override
  Future<List<PredictionQuiz>> quizzesFor(String matchId) =>
      _inner.quizzesFor(matchId);
  @override
  Future<PredictionQuiz?> quizFor(String matchId, String quizId) =>
      _inner.quizFor(matchId, quizId);
  @override
  Future<List<TeamStanding>> standings(String leagueId) =>
      _inner.standings(leagueId);
  @override
  Future<PredictionVoteBreakdown?> votesFor(
    String matchId,
    String quizId,
    String questionId,
  ) => _inner.votesFor(matchId, quizId, questionId);
  @override
  Future<List<MatchPredictionLeaderboardEntry>> matchLeaderboard(
    String matchId,
    String quizId,
  ) => _inner.matchLeaderboard(matchId, quizId);
  @override
  Future<List<SportMatch>> enrichFixturesForSport(
    List<SportMatch> fixtures,
    Sport sport,
  ) async => fixtures;
}

/// Phase 5: the resume/launch-triggered "cronjob" that settles yesterday's
/// fixtures and pulls the newly-in-window day, gated by a persisted day-key
/// so it only ever does real work once per calendar day.
void main() {
  late RollingWindowService service;
  late PredictionCubit predictionCubit;
  late PicksCubit picksCubit;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    service = RollingWindowService(SecureGameStorage());
    predictionCubit = PredictionCubit(
      _NoNetworkPredictionRepository(MockPredictionRepository()),
      SecureGameStorage(),
    );
    picksCubit = PicksCubit(MockPickRepository(), SecureGameStorage());
  });

  test('isDue is true on first run (no persisted key)', () async {
    expect(await service.isDue(now: DateTime(2026, 7, 19)), isTrue);
  });

  test('runIfDue loads every sport and picks markets, then marks the day done', () async {
    await predictionCubit.load();
    await runIfDueAndAwaitLoads(service, predictionCubit, picksCubit, DateTime(2026, 7, 19));

    expect(predictionCubit.state.loadedSports, Sport.values.toSet());
    expect(predictionCubit.state.fixtures, isNotEmpty);
    expect(picksCubit.state.markets, isNotEmpty);
    expect(await service.isDue(now: DateTime(2026, 7, 19)), isFalse);
  });

  test('calling runIfDue twice the same day is a no-op the second time', () async {
    await predictionCubit.load();
    final today = DateTime(2026, 7, 19);
    await runIfDueAndAwaitLoads(service, predictionCubit, picksCubit, today);

    final fixturesAfterFirstRun = predictionCubit.state.fixtures.length;
    // A second call on the same day must not throw and must remain a no-op —
    // loadedSports stays exactly the 5 sports, not re-cleared/re-populated.
    await service.runIfDue(
      predictionCubit: predictionCubit,
      picksCubit: picksCubit,
      now: today,
    );
    expect(predictionCubit.state.fixtures.length, fixturesAfterFirstRun);
    expect(predictionCubit.state.loadedSports, Sport.values.toSet());
  });

  test('a new calendar day makes it due again and re-runs', () async {
    await predictionCubit.load();
    final day1 = DateTime(2026, 7, 19);
    final day2 = DateTime(2026, 7, 20);
    await runIfDueAndAwaitLoads(service, predictionCubit, picksCubit, day1);
    expect(await service.isDue(now: day2), isTrue);

    await runIfDueAndAwaitLoads(service, predictionCubit, picksCubit, day2);
    expect(await service.isDue(now: day2), isFalse);
    // refreshSport clears then repopulates loadedSports — still all 5 after.
    expect(predictionCubit.state.loadedSports, Sport.values.toSet());
  });
}

/// [RollingWindowService.runIfDue] fires `PredictionCubit.refreshSport`,
/// which does its network/settlement work fire-and-forget under the hood in
/// places, but the cubit itself resolves the awaited Future once its own
/// emit has happened — awaiting the service call is sufficient here since
/// [MockPredictionRepository]/[MockPickRepository] have no real async delay.
Future<void> runIfDueAndAwaitLoads(
  RollingWindowService service,
  PredictionCubit predictionCubit,
  PicksCubit picksCubit,
  DateTime now,
) => service.runIfDue(
  predictionCubit: predictionCubit,
  picksCubit: picksCubit,
  now: now,
);
