import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/league.dart';
import '../../models/prediction.dart';
import '../../models/sport_match.dart';
import '../../models/team_standing.dart';
import '../../services/prediction_repository.dart';
import '../../services/quiz_archetypes.dart';
import '../../services/secure_storage_service.dart';
import '../../services/settlement_writer.dart';
import 'prediction_state.dart';

/// Result of settling one prediction. [xp] is progression XP; [prizeOz] is the
/// Oz-coin prize won from a paid contest (0 for free quizzes / off the podium),
/// with [rank] the finishing position in a field of [fieldSize].
typedef PredictionSettlement = ({int xp, int prizeOz, int rank, int fieldSize});

const PredictionSettlement _noSettlement = (
  xp: 0,
  prizeOz: 0,
  rank: 0,
  fieldSize: 0,
);

/// Owns the prediction hub's data: fixtures (from [PredictionRepository]) and
/// the user's own predictions (persisted via [SecureGameStorage]).
///
/// Reward crediting is intentionally NOT done here — settlement returns the
/// earned XP (and any contest prize) and the UI credits it through `GameBloc`
/// (`PredictionXpAdded` / `CoinsAdded`), so the cubit stays decoupled from the
/// game economy. Predictions reward XP only, with ONE exception: the Scoreline
/// Quiz is a paid coin contest ([PredictionQuiz.isContest]) whose top-3
/// finishers also win coins ([kScorelineContestPrizes]).
class PredictionCubit extends Cubit<PredictionState> {
  PredictionCubit(this._repository, this._storage)
    : super(const PredictionState());

  final PredictionRepository _repository;
  final SecureGameStorage _storage;

  /// Demo predictions seeded so the prediction history screen can show every
  /// lifecycle bucket (pending · live · settleable · settled) on a fresh
  /// install. Stored predictions always win — a demo is only inserted when the
  /// user has no prediction for that match, so settling a demo fixture
  /// persists across relaunches.
  static void applyHistoryDemos(Map<String, UserPrediction> predictions) {
    final now = DateTime.now();
    final demos = [
      UserPrediction(
        matchId: 'ipl_pjk_kkr',
        answers: const {},
        submittedAt: now.subtract(const Duration(hours: 2)),
        status: PredictionStatus.open,
      ),
      UserPrediction(
        matchId: 'epl_liv_mc',
        answers: const {'q1': 100, 'q2': 0, 'q3': 0, 'q4': 0, 'q5': 0},
        submittedAt: DateTime(now.year, now.month, now.day - 1, 23, 34),
        status: PredictionStatus.open,
      ),
      UserPrediction(
        matchId: 'epl_cfc_new',
        answers: const {'q1': 201, 'q2': 0},
        submittedAt: now.subtract(const Duration(minutes: 45)),
        status: PredictionStatus.locked,
      ),
      // Finished fixture settled as a clean win for history/demo coverage.
      UserPrediction(
        matchId: 'epl_mu_whu',
        answers: const {'q1': 201, 'q2': 0, 'q3': 0, 'q4': 0, 'q5': 1},
        submittedAt: now.subtract(const Duration(days: 3, hours: 2)),
        status: PredictionStatus.settled,
        correctCount: 5,
        rewardEarned: 30,
      ),
      // 8th fixture: Chennai vs Mumbai — answers score 3/4 (q2 misses: user
      // picks Under 12.5, actual is Over).
      UserPrediction(
        matchId: 'ipl_csk_mi',
        answers: const {'q1': 0, 'q2': 1, 'q3': 0, 'q4': 0},
        submittedAt: now.subtract(const Duration(days: 1, hours: 3)),
        status: PredictionStatus.locked,
      ),
      // 9th fixture: Aston Villa vs Brighton — settled as a loss so the
      // history page always shows a red outcome state on a fresh install.
      UserPrediction(
        matchId: 'epl_avl_bha',
        answers: const {'q1': 101, 'q2': 0, 'q3': 1, 'q4': 0},
        submittedAt: now.subtract(const Duration(days: 2, hours: 5)),
        status: PredictionStatus.settled,
        correctCount: 0,
        rewardEarned: 0,
      ),
      UserPrediction(
        matchId: 'ipl_pjk_rcb',
        answers: const {'q1': 0, 'q2': 0, 'q3': 1, 'q4': 0, 'q5': 0},
        submittedAt: DateTime(now.year, 1, 24, 23, 34),
        status: PredictionStatus.settled,
        correctCount: 3,
        rewardEarned: 20,
      ),
      // Demo: finished FIFA fixture predicted but NOT yet revealed → the card
      // shows the gold "RESULTS ARE OUT — TAP TO REVEAL" (unclaimed) state.
      UserPrediction(
        matchId: 'fifa_demo_esp_ger',
        answers: const {'q1': 0, 'q2': 1, 'q3': 0, 'q4': 1, 'q5': 0},
        submittedAt: now.subtract(const Duration(hours: 20)),
        status: PredictionStatus.locked,
      ),
      // WNBA demo (Dallas Wings 82-75 Phoenix Mercury). Locked, not yet
      // settled — proves the new auto-settlement engine (QuizArchetypes +
      // MatchOutcomeResolver, no hand-authored quiz override here) reaches
      // the gold "RESULTS ARE OUT" reveal for basketball too. Scores 3/4:
      // total-points misses (picked Over 159.5, actual total is 157, Under).
      UserPrediction(
        matchId: 'wnba_demo_dal_phx',
        answers: const {
          'winner': 0,
          'total_points_ou': 0,
          'biggest_quarter': 0,
          'winning_margin_bracket': 1,
        },
        submittedAt: now.subtract(const Duration(hours: 18)),
        status: PredictionStatus.locked,
      ),
      // World Cup third-place play-off (France 4-6 England). Locked, not yet
      // settled, so the quiz reads as over — answers locked in and reviewable
      // against the real result — and the card offers the gold "RESULTS ARE
      // OUT" reveal. Scores 4/5: q1 misses (2-1 predicted, 4-6 actual), the
      // other four land, crediting 175 XP through the reveal cinematic.
      UserPrediction(
        matchId: '760516',
        answers: const {'q1': 201, 'q2': 2, 'q3': 0, 'q4': 0, 'q5': 1},
        submittedAt: now.subtract(const Duration(days: 1, hours: 6)),
        status: PredictionStatus.locked,
      ),
      // Demo: finished FIFA fixture settled as a win → the card shows the
      // revealed "+XP" (paired with a won Oz pick for the coins figure).
      UserPrediction(
        matchId: 'fifa_arg_jor',
        answers: const {'q1': 0, 'q2': 0, 'q3': 0, 'q4': 0, 'q5': 0},
        submittedAt: now.subtract(const Duration(hours: 22)),
        status: PredictionStatus.settled,
        correctCount: 4,
        rewardEarned: 240,
      ),
    ];
    for (final demo in demos) {
      predictions.putIfAbsent(demo.key, () => demo);
    }
  }

  Future<void> load() async {
    final leagues = await _repository.leagues();
    
    final stored = await _storage.loadPredictions();
    final predictions = {for (final p in stored) p.key: p};
    applyHistoryDemos(predictions);

    // Emit fast initial state so UI renders immediately
    emit(
      state.copyWith(
        loading: false,
        leagues: leagues,
        predictions: predictions,
        standingsByLeague: const {},
      ),
    );

    // Fetch slow network data asynchronously
    _loadLiveStandings(leagues);
  }

  Future<void> _loadLiveStandings(List<League> leagues) async {
    for (final league in leagues) {
      try {
        final standing = await _repository.standings(league.id);
        if (!isClosed) {
          final nextStandings = Map<String, List<TeamStanding>>.from(state.standingsByLeague);
          nextStandings[league.id] = standing;
          emit(state.copyWith(standingsByLeague: nextStandings));
        }
      } catch (_) {}
    }
  }

  Future<void> loadSport(Sport sport) async {
    if (state.loadedSports.contains(sport) || state.loadingSports.contains(sport)) {
      return;
    }
    await _loadSportUnchecked(sport);
  }

  /// Forces a fresh fetch/re-settlement for [sport] even if it was already
  /// loaded this session — used by [RollingWindowService] on a day-boundary
  /// resume, when yesterday's fixtures need re-settling and today's newly
  /// in-window fixtures need fetching, neither of which `loadSport`'s
  /// load-once guard would otherwise allow.
  Future<void> refreshSport(Sport sport) async {
    if (state.loadingSports.contains(sport)) return;
    emit(
      state.copyWith(
        loadedSports: state.loadedSports.where((s) => s != sport).toSet(),
      ),
    );
    await _loadSportUnchecked(sport);
  }

  Future<void> _loadSportUnchecked(Sport sport) async {
    emit(state.copyWith(loadingSports: {...state.loadingSports, sport}));

    try {
      final localFixtures = await _repository.fixtures(sport: sport);
      final enrichedFixtures = await _repository.enrichFixturesForSport(localFixtures, sport);
      
      final quizzes = <String, PredictionQuiz>{...state.quizzes};
      for (final fixture in enrichedFixtures) {
        if (fixture.sport == sport) {
          var matchQuizzes = await _repository.quizzesFor(fixture.id);
          // No hand-authored/generated quiz exists yet for this fixture —
          // synthesize the small, always-resolvable archetype set instead of
          // leaving it with none (the gap every non-FIFA football league and
          // every cricket fixture hit before this).
          if (matchQuizzes.isEmpty) {
            final questions = QuizArchetypes.buildFor(fixture);
            if (questions.isNotEmpty) {
              matchQuizzes = [
                PredictionQuiz(matchId: fixture.id, questions: questions),
              ];
            }
          }
          for (final quiz in matchQuizzes) {
            // A finished fixture whose quiz isn't settled yet gets resolved
            // now, from the same enriched data just fetched above — this is
            // the fix for the "stuck forever" gold-reveal bug: quizzes reach
            // the UI already settled instead of relying on a hand-typed
            // override. Already-settled quizzes (hand-authored overrides
            // like '760516') are left untouched.
            final resolved =
                (fixture.status == MatchStatus.finished && !quiz.settleable)
                ? SettlementWriter.computeQuizSettlement(fixture, quiz)
                : quiz;
            quizzes[predictionStorageKey(fixture.id, resolved.id)] = resolved;
          }
        }
      }
      
      final allFixturesMap = <String, SportMatch>{};
      for (final f in state.fixtures) {
        allFixturesMap[f.id] = f;
      }
      for (final f in enrichedFixtures) {
        allFixturesMap[f.id] = f;
      }
      
      if (!isClosed) {
        emit(state.copyWith(
          fixtures: allFixturesMap.values.toList(),
          quizzes: quizzes,
          loadingSports: state.loadingSports.where((s) => s != sport).toSet(),
          loadedSports: {...state.loadedSports, sport},
        ));
      }
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(loadingSports: state.loadingSports.where((s) => s != sport).toSet()));
      }
    }
  }

  Future<List<PredictionQuiz>> quizzesFor(String matchId) =>
      _repository.quizzesFor(matchId);

  Future<PredictionQuiz?> quizFor(
    String matchId, [
    String quizId = kDefaultPredictionQuizId,
  ]) => _repository.quizFor(matchId, quizId);

  Future<PredictionVoteBreakdown?> votesFor(
    String matchId,
    String quizId,
    String questionId,
  ) => _repository.votesFor(matchId, quizId, questionId);

  Future<List<MatchPredictionLeaderboardEntry>> matchLeaderboard(
    String matchId,
    String quizId,
  ) => _repository.matchLeaderboard(matchId, quizId);

  /// Stores (or replaces) the user's answers for a fixture.
  Future<void> submit(
    String matchId,
    String quizId,
    Map<String, int> answers, {
    Map<String, PredictionMultiplier> multipliersByQuestion = const {},
  }) async {
    final prediction = UserPrediction(
      matchId: matchId,
      quizId: quizId,
      answers: answers,
      multipliersByQuestion: multipliersByQuestion,
      submittedAt: DateTime.now(),
      status: PredictionStatus.open,
    );
    final next = Map<String, UserPrediction>.from(state.predictions)
      ..[prediction.key] = prediction;
    emit(state.copyWith(predictions: next));
    await _storage.savePredictions(next.values.toList());
  }

  /// Mock settlement: scores the stored answers against the quiz's
  /// [QuizQuestion.settledOptionIndex] and returns the XP earned — plus, for a
  /// paid contest ([PredictionQuiz.isContest]), the finishing rank and Oz-coin
  /// prize — so the caller can credit progression and the wallet. The status
  /// flip to `settled` guards this from running twice, so the prize is awarded
  /// exactly once. Returns [_noSettlement] if there is nothing to settle.
  Future<PredictionSettlement> settle(
    String matchId, [
    String quizId = kDefaultPredictionQuizId,
  ]) async {
    final prediction = state.predictionFor(matchId, quizId);
    if (prediction == null || prediction.status == PredictionStatus.settled) {
      return _noSettlement;
    }
    final quiz = await _repository.quizFor(matchId, quizId);
    if (quiz == null || !quiz.settleable) return _noSettlement;

    var correct = 0;
    var reward = 0;
    for (final q in quiz.questions) {
      // A voided question (data couldn't support it) is neutral: no credit,
      // no penalty, and it doesn't require an answer to have been given.
      if (q.forcedVoid) continue;
      final picked = prediction.answers[q.id];
      if (picked == null) continue;
      final correctAnswer = q.isScorePrediction
          ? q.settledScoreEncoded
          : q.settledOptionIndex;
      if (correctAnswer != null && picked == correctAnswer) {
        correct++;
        reward +=
            prediction.multipliersByQuestion[q.id]?.applyTo(q.reward) ??
            q.reward;
      }
    }

    var rank = 0;
    var prizeOz = 0;
    var fieldSize = 0;
    if (quiz.isContest) {
      (rank, prizeOz, fieldSize) = await _contestFinish(
        matchId,
        quizId,
        playerCorrect: correct,
        totalQuestions: quiz.questions.length,
      );
    }

    final settled = prediction.copyWith(
      status: PredictionStatus.settled,
      correctCount: correct,
      rewardEarned: reward,
      contestRank: rank == 0 ? null : rank,
      contestPrizeOz: prizeOz,
    );
    final next = Map<String, UserPrediction>.from(state.predictions)
      ..[settled.key] = settled;
    emit(state.copyWith(predictions: next));
    await _storage.savePredictions(next.values.toList());
    return (xp: reward, prizeOz: prizeOz, rank: rank, fieldSize: fieldSize);
  }

  /// Ranks the player against the seeded contest field for this quiz. Rivals'
  /// correct counts are clamped to [totalQuestions] so the ranking is fair for
  /// any question count; the player wins ties (generous, and deterministic).
  /// Returns (rank, prizeOz, fieldSize).
  Future<(int, int, int)> _contestFinish(
    String matchId,
    String quizId, {
    required int playerCorrect,
    required int totalQuestions,
  }) async {
    final board = await _repository.matchLeaderboard(matchId, quizId);
    final rivals = board.where((e) => e.name.toLowerCase() != 'you').toList();
    if (rivals.isEmpty) return (1, scorelineContestPrizeFor(1), 1);
    final ahead = rivals
        .where((r) => r.correct.clamp(0, totalQuestions) > playerCorrect)
        .length;
    final rank = ahead + 1;
    return (rank, scorelineContestPrizeFor(rank), rivals.length + 1);
  }
}
