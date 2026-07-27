import 'package:flutter/foundation.dart';
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
  PredictionCubit(
    this._repository,
    this._storage, {
    SportQuizGenerator quizGenerator = const DeterministicSportQuizGenerator(),
    Duration settlementValidationDelay = const Duration(minutes: 5),
    DateTime Function()? now,
  }) : _quizGenerator = quizGenerator,
       _settlementValidationDelay = settlementValidationDelay,
       _now = now ?? DateTime.now,
       super(const PredictionState());

  final PredictionRepository _repository;
  final SecureGameStorage _storage;
  final SportQuizGenerator _quizGenerator;
  final Duration _settlementValidationDelay;
  final DateTime Function() _now;
  final Map<String, SettlementValidationCheckpoint> _settlementCheckpoints = {};

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
      // the gold "RESULTS ARE OUT" reveal for basketball too. Scores 4/5:
      // total-points misses (picked Over 159.5, actual total is 157, Under).
      UserPrediction(
        matchId: 'wnba_demo_dal_phx',
        answers: const {
          'winner': 0,
          'total_points_ou': 0,
          'halftime_leader': 0,
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
    final storedQuizzes = await _storage.loadPredictionQuizzes();
    final checkpoints = await _storage.loadPredictionSettlementCheckpoints();
    final predictions = {for (final p in stored) p.key: p};
    final quizzes = {
      for (final quiz in storedQuizzes)
        predictionStorageKey(quiz.matchId, quiz.id): quiz,
    };
    _settlementCheckpoints
      ..clear()
      ..addEntries(
        checkpoints.map(
          (checkpoint) => MapEntry(
            predictionStorageKey(checkpoint.matchId, checkpoint.quizId),
            checkpoint,
          ),
        ),
      );
    applyHistoryDemos(predictions);

    // Emit fast initial state so UI renders immediately
    emit(
      state.copyWith(
        loading: false,
        leagues: leagues,
        predictions: predictions,
        quizzes: quizzes,
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
          final nextStandings = Map<String, List<TeamStanding>>.from(
            state.standingsByLeague,
          );
          nextStandings[league.id] = standing;
          emit(state.copyWith(standingsByLeague: nextStandings));
        }
      } catch (e) {
        debugPrint(
          'PredictionCubit: failed to load standings for ${league.id}: $e',
        );
      }
    }
  }

  Future<void> loadSport(Sport sport) async {
    if (state.loadedSports.contains(sport) ||
        state.loadingSports.contains(sport)) {
      return;
    }
    await _loadSportUnchecked(sport);
  }

  /// Resolves configured fixture IDs without adding repository-only demo
  /// fixtures to the shared sport feed.
  Future<Map<String, SportMatch>> resolveCatalogFixtures(
    Iterable<String> matchIds,
  ) async {
    final requestedIds = matchIds.toSet();
    final resolved = <String, SportMatch>{
      for (final fixture in state.fixtures)
        if (requestedIds.contains(fixture.id)) fixture.id: fixture,
    };
    final repository = _repository;
    if (repository is! PredictionCatalogLookup) return resolved;
    final catalogLookup = repository as PredictionCatalogLookup;

    for (final matchId in requestedIds) {
      if (resolved.containsKey(matchId)) continue;
      final fixture = await catalogLookup.fixtureById(matchId);
      if (fixture != null) resolved[matchId] = fixture;
    }
    return resolved;
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
      final enrichedFixtures = await _repository.enrichFixturesForSport(
        localFixtures,
        sport,
      );

      final quizzes = <String, PredictionQuiz>{...state.quizzes};
      var checkpointsChanged = false;
      for (final fixture in enrichedFixtures) {
        if (fixture.sport == sport) {
          final authored = await _repository.quizzesFor(fixture.id);
          final cached = quizzes.values
              .where((quiz) => quiz.matchId == fixture.id && quiz.generated)
              .toList(growable: false);
          final validAuthored = authored
              .where((quiz) => _validAuthoredQuiz(fixture.sport, quiz))
              .toList(growable: false);
          // A curated multi-quiz fixture is an intentional game mode: for
          // example the paid Scoreline contest alongside the free Match Events
          // quiz. Those legacy/curated sets can carry their own question count
          // and settlement metadata, so never replace the whole set with one
          // generated quiz merely because an individual card is not the new
          // five-question archetype shape. Single authored quizzes still go
          // through the resolver validation below; generated quizzes remain
          // the fallback wherever no curated set exists.
          final authoredSets = authored.length > 1 ? authored : validAuthored;
          final matchQuizzes = authoredSets.isNotEmpty
              ? authoredSets
              : cached.isNotEmpty
              ? cached
              : [_quizGenerator.generate(fixture)];
          // No hand-authored/generated quiz exists yet for this fixture —
          // synthesize the small, always-resolvable archetype set instead of
          // leaving it with none (the gap every non-FIFA football league and
          // every cricket fixture hit before this).
          // The source selected above is authoritative for this fixture. This
          // also clears a previously cached generated card when a curated
          // multi-quiz fixture becomes available on a later refresh.
          quizzes.removeWhere((_, quiz) => quiz.matchId == fixture.id);
          for (final quiz in matchQuizzes) {
            // A finished fixture whose quiz isn't settled yet gets resolved
            // now, from the same enriched data just fetched above — this is
            // the fix for the "stuck forever" gold-reveal bug: quizzes reach
            // the UI already settled instead of relying on a hand-typed
            // override. Already-settled quizzes (hand-authored overrides
            // like '760516') are left untouched.
            final checkpointKey = predictionStorageKey(fixture.id, quiz.id);
            final checkpointBefore = _settlementCheckpoints[checkpointKey];
            final resolved = fixture.status == MatchStatus.finished
                ? _validatedSettlement(fixture, quiz)
                : quiz;
            checkpointsChanged =
                checkpointsChanged ||
                checkpointBefore != _settlementCheckpoints[checkpointKey];
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

      // Re-pull leagues so any competition ESPN just discovered for this sport
      // (EspnScoreService.discoveredLeagues, populated by the fetch above) is
      // reflected in `validLeagueIds` on the prediction home screen — without
      // this, a fixture whose real ESPN league isn't one of the curated ones
      // fetches fine here but is silently filtered out of the UI.
      final leagues = await _repository.leagues();

      if (!isClosed) {
        final nextFixtures = allFixturesMap.values.toList();
        emit(
          state.copyWith(
            fixtures: nextFixtures,
            quizzes: quizzes,
            leagues: leagues,
            questionIntel: _buildQuestionIntel(
              nextFixtures,
              quizzes,
              state.predictions,
            ),
            loadingSports: state.loadingSports.where((s) => s != sport).toSet(),
            loadedSports: {...state.loadedSports, sport},
          ),
        );
        await _persistGeneratedQuizzes(quizzes.values);
        if (checkpointsChanged) await _persistSettlementCheckpoints();
        await lockDuePredictions(allFixturesMap.values);
      }
    } catch (e) {
      debugPrint('PredictionCubit: failed to load $sport: $e');
      if (!isClosed) {
        emit(
          state.copyWith(
            loadingSports: state.loadingSports.where((s) => s != sport).toSet(),
          ),
        );
      }
    }
  }

  bool _validAuthoredQuiz(Sport sport, PredictionQuiz quiz) =>
      quiz.questions.length == 5 &&
      quiz.questions.every(
        (question) =>
            question.isSettled || QuizArchetypes.canResolve(sport, question),
      );

  PredictionQuiz _validatedSettlement(SportMatch fixture, PredictionQuiz quiz) {
    if (quiz.settleable) return quiz;
    final fingerprint = SettlementWriter.quizResultFingerprint(fixture, quiz);
    if (fingerprint == null) return quiz;

    final key = predictionStorageKey(fixture.id, quiz.id);
    final checkpoint = _settlementCheckpoints[key];
    final now = _now();
    if (checkpoint == null || checkpoint.fingerprint != fingerprint) {
      _settlementCheckpoints[key] = SettlementValidationCheckpoint(
        matchId: fixture.id,
        quizId: quiz.id,
        fingerprint: fingerprint,
        firstSeenAt: now,
        sourceUpdatedAt: fixture.liveLastUpdated,
      );
      return quiz;
    }
    if (checkpoint.sourceUpdatedAt != null &&
        checkpoint.sourceUpdatedAt == fixture.liveLastUpdated) {
      return quiz;
    }
    if (now.difference(checkpoint.firstSeenAt) < _settlementValidationDelay) {
      return quiz;
    }

    _settlementCheckpoints.remove(key);
    return SettlementWriter.computeQuizSettlement(fixture, quiz);
  }

  Future<void> _persistGeneratedQuizzes(
    Iterable<PredictionQuiz> quizzes,
  ) async {
    try {
      await _storage.savePredictionQuizzes(
        quizzes.where((quiz) => quiz.generated).toList(growable: false),
      );
    } catch (error) {
      debugPrint('PredictionCubit: failed to persist quiz snapshots: $error');
    }
  }

  Future<void> _persistSettlementCheckpoints() async {
    try {
      await _storage.savePredictionSettlementCheckpoints(
        _settlementCheckpoints.values.toList(growable: false),
      );
    } catch (error) {
      debugPrint(
        'PredictionCubit: failed to persist settlement validation: $error',
      );
    }
  }

  Map<String, LiveQuestionIntel> _buildQuestionIntel(
    Iterable<SportMatch> fixtures,
    Map<String, PredictionQuiz> quizzes,
    Map<String, UserPrediction> predictions,
  ) {
    final intel = <String, LiveQuestionIntel>{};
    for (final fixture in fixtures) {
      if (fixture.status == MatchStatus.upcoming) continue;
      for (final quiz in quizzes.values.where(
        (candidate) => candidate.matchId == fixture.id,
      )) {
        final prediction =
            predictions[predictionStorageKey(fixture.id, quiz.id)];
        if (prediction == null || prediction.status == PredictionStatus.open) {
          continue;
        }
        for (final question in quiz.questions) {
          intel[predictionQuestionIntelKey(
            fixture.id,
            quiz.id,
            question.id,
          )] = QuizArchetypes.liveIntel(
            fixture,
            question,
            prediction.answers[question.id],
          );
        }
      }
    }
    return intel;
  }

  Future<void> refreshMatch(String matchId) async {
    SportMatch? fixture;
    for (final candidate in state.fixtures) {
      if (candidate.id == matchId) {
        fixture = candidate;
        break;
      }
    }
    if (fixture == null || state.loadingSports.contains(fixture.sport)) return;
    await _loadSportUnchecked(fixture.sport);
  }

  /// Resume catch-up for entries that can change while the app is backgrounded.
  /// Daily rolling-window refresh still discovers new fixtures; this narrower
  /// pass keeps live scores and pending final confirmations current the rest of
  /// the day.
  Future<void> refreshLiveAndPendingMatches() async {
    final lockedMatchIds = state.predictions.values
        .where((prediction) => prediction.status == PredictionStatus.locked)
        .map((prediction) => prediction.matchId)
        .toSet();
    final sports = state.fixtures
        .where(
          (fixture) =>
              lockedMatchIds.contains(fixture.id) &&
              fixture.status != MatchStatus.upcoming,
        )
        .map((fixture) => fixture.sport)
        .toSet();
    for (final sport in sports) {
      if (!state.loadingSports.contains(sport)) {
        await _loadSportUnchecked(sport);
      }
    }
  }

  LiveQuestionIntel? questionIntelFor(
    String matchId,
    String quizId,
    String questionId,
  ) =>
      state.questionIntel[predictionQuestionIntelKey(
        matchId,
        quizId,
        questionId,
      )];

  static Map<int, int> _fallbackVoteTotals(
    String matchId,
    String quizId,
    QuizQuestion question,
  ) {
    final seed = _stableSeed('$matchId:$quizId:${question.id}');
    if (question.isScorePrediction) {
      final scores = <int>[
        ScoreAnswer.encode(1, 0),
        ScoreAnswer.encode(1, 1),
        ScoreAnswer.encode(2, 1),
        ScoreAnswer.encode(0, 0),
        ScoreAnswer.encode(0, 1),
      ];
      return {
        for (var index = 0; index < scores.length; index++)
          scores[index]: 28 + ((seed + index * 23) % 72),
      };
    }
    return {
      for (var index = 0; index < question.options.length; index++)
        index: 34 + ((seed + index * 29) % 96),
    };
  }

  static int _stableSeed(String value) {
    var hash = 17;
    for (final unit in value.codeUnits) {
      hash = (hash * 31 + unit) % 100000;
    }
    return hash;
  }

  Future<List<PredictionQuiz>> quizzesFor(String matchId) async {
    final cached = state.quizzes.values
        .where((quiz) => quiz.matchId == matchId)
        .toList(growable: false);
    return cached.isNotEmpty ? cached : _repository.quizzesFor(matchId);
  }

  Future<PredictionQuiz?> quizFor(
    String matchId, [
    String quizId = kDefaultPredictionQuizId,
  ]) async {
    final cached = state.quizzes[predictionStorageKey(matchId, quizId)];
    if (cached != null) return cached;
    return _repository.quizFor(matchId, quizId);
  }

  Future<PredictionVoteBreakdown?> votesFor(
    String matchId,
    String quizId,
    String questionId,
  ) async {
    final repositoryVotes = await _repository.votesFor(
      matchId,
      quizId,
      questionId,
    );
    if (repositoryVotes != null) return repositoryVotes;
    final quiz = await quizFor(matchId, quizId);
    QuizQuestion? question;
    for (final candidate in quiz?.questions ?? const <QuizQuestion>[]) {
      if (candidate.id == questionId) {
        question = candidate;
        break;
      }
    }
    if (question == null) return null;
    return PredictionVoteBreakdown(
      matchId: matchId,
      questionId: questionId,
      totals: _fallbackVoteTotals(matchId, quizId, question),
    );
  }

  /// The in-match board, with the player's own row resolved against their real
  /// prediction and the whole field re-ranked by points.
  ///
  /// Until results land the player is held out of the ranked field — an
  /// invented provisional rank reads worse than an explicit "pending" — and
  /// slots in on merit once settled. [_contestFinish] deliberately reads the
  /// raw repository board instead, so coin payouts never depend on this.
  Future<List<MatchPredictionLeaderboardEntry>> matchLeaderboard(
    String matchId,
    String quizId,
  ) async {
    final board = await _repository.matchLeaderboard(matchId, quizId);
    final rivals = <MatchPredictionLeaderboardEntry>[];
    MatchPredictionLeaderboardEntry? user;
    for (final entry in board) {
      if (entry.isUser) {
        user ??= entry;
      } else {
        rivals.add(entry);
      }
    }

    final prediction = state.predictionFor(matchId, quizId);
    if (user == null || prediction?.status != PredictionStatus.settled) {
      return _rankedBoard(rivals);
    }

    final quizzes = await _repository.quizzesFor(matchId);
    var total = 0;
    for (final quiz in quizzes) {
      if (quiz.id == quizId) {
        total = quiz.questions.length;
        break;
      }
    }
    final correct = prediction!.correctCount ?? 0;
    final answered = prediction.answers.length;
    // Scaled so a perfect card lands at the top of the rivals' 338-573 band.
    final points =
        (total == 0 ? 0 : (620 * correct / total).round()) + answered * 6;
    return _rankedBoard([
      ...rivals,
      user.copyWith(points: points, correct: correct),
    ]);
  }

  List<MatchPredictionLeaderboardEntry> _rankedBoard(
    List<MatchPredictionLeaderboardEntry> entries,
  ) {
    final sorted = [...entries]..sort((a, b) => b.points.compareTo(a.points));
    return [
      for (var i = 0; i < sorted.length; i++) sorted[i].copyWith(rank: i + 1),
    ];
  }

  /// Creates or updates an editable prediction draft.
  ///
  /// Draft writes preserve the original [UserPrediction.submittedAt] timestamp
  /// and can never reopen a locked or settled prediction. Returns false when
  /// the prediction is immutable or persistence fails.
  Future<bool> saveDraft(
    String matchId,
    String quizId,
    Map<String, int> answers, {
    Map<String, PredictionMultiplier> multipliersByQuestion = const {},
  }) async {
    final key = predictionStorageKey(matchId, quizId);
    final existing = state.predictions[key];
    if (existing != null && existing.status != PredictionStatus.open) {
      return false;
    }
    // New entries are never accepted after kickoff. Existing drafts are left
    // to the deadline-lock path so a queued pre-kickoff autosave can still be
    // flushed before its immutable snapshot is sealed.
    if (existing == null && _fixtureHasStarted(matchId)) return false;
    final prediction = existing == null
        ? UserPrediction(
            matchId: matchId,
            quizId: quizId,
            answers: Map<String, int>.from(answers),
            multipliersByQuestion: Map<String, PredictionMultiplier>.from(
              multipliersByQuestion,
            ),
            submittedAt: _now(),
            status: PredictionStatus.open,
          )
        : existing.copyWith(
            answers: Map<String, int>.from(answers),
            multipliersByQuestion: Map<String, PredictionMultiplier>.from(
              multipliersByQuestion,
            ),
          );
    final previous = state.predictions;
    final next = Map<String, UserPrediction>.from(previous)..[key] = prediction;
    emit(state.copyWith(predictions: next));
    try {
      await _storage.savePredictions(next.values.toList());
      return true;
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            predictions: previous,
            questionIntel: _buildQuestionIntel(
              state.fixtures,
              state.quizzes,
              previous,
            ),
          ),
        );
      }
      debugPrint('PredictionCubit: failed to save draft $key: $error');
      return false;
    }
  }

  bool _fixtureHasStarted(String matchId) {
    for (final fixture in state.fixtures) {
      if (fixture.id != matchId) continue;
      return fixture.status != MatchStatus.upcoming ||
          !fixture.kickoff.isAfter(_now());
    }
    return false;
  }

  /// Compatibility wrapper for older callers. New UI should use [saveDraft].
  @Deprecated('Use saveDraft; submitted predictions remain editable drafts.')
  Future<void> submit(
    String matchId,
    String quizId,
    Map<String, int> answers, {
    Map<String, PredictionMultiplier> multipliersByQuestion = const {},
  }) async {
    await saveDraft(
      matchId,
      quizId,
      answers,
      multipliersByQuestion: multipliersByQuestion,
    );
  }

  /// Atomically writes the latest visible answers and freezes the prediction.
  ///
  /// Re-locking an already locked prediction succeeds without writing again.
  /// Settled predictions and missing drafts cannot be locked.
  Future<bool> lockPrediction(
    String matchId,
    String quizId, {
    Map<String, int>? answers,
    Map<String, PredictionMultiplier>? multipliersByQuestion,
  }) async {
    final key = predictionStorageKey(matchId, quizId);
    final existing = state.predictions[key];
    if (existing == null || existing.status == PredictionStatus.settled) {
      return false;
    }
    if (existing.status == PredictionStatus.locked) return true;

    final locked = existing.copyWith(
      answers: answers == null
          ? existing.answers
          : Map<String, int>.from(answers),
      multipliersByQuestion: multipliersByQuestion == null
          ? existing.multipliersByQuestion
          : Map<String, PredictionMultiplier>.from(multipliersByQuestion),
      status: PredictionStatus.locked,
    );
    final previous = state.predictions;
    final next = Map<String, UserPrediction>.from(previous)..[key] = locked;
    emit(
      state.copyWith(
        predictions: next,
        questionIntel: _buildQuestionIntel(state.fixtures, state.quizzes, next),
      ),
    );
    try {
      await _storage.savePredictions(next.values.toList());
      return true;
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            predictions: previous,
            questionIntel: _buildQuestionIntel(
              state.fixtures,
              state.quizzes,
              previous,
            ),
          ),
        );
      }
      debugPrint('PredictionCubit: failed to lock $key: $error');
      return false;
    }
  }

  /// Freezes every open draft whose fixture has reached its deadline.
  ///
  /// This is called after fixture refreshes so drafts are normalized even when
  /// the app was closed at kickoff. The prediction screen also invokes it when
  /// its foreground countdown crosses zero.
  Future<int> lockDuePredictions(
    Iterable<SportMatch> fixtures, {
    DateTime? now,
  }) async {
    final deadline = now ?? _now();
    final fixturesById = <String, SportMatch>{
      for (final fixture in fixtures) fixture.id: fixture,
    };
    final previous = state.predictions;
    final next = Map<String, UserPrediction>.from(previous);
    var lockedCount = 0;

    for (final entry in previous.entries) {
      final prediction = entry.value;
      if (prediction.status != PredictionStatus.open) continue;
      final fixture = fixturesById[prediction.matchId];
      if (fixture == null) continue;
      final due =
          fixture.status != MatchStatus.upcoming ||
          !fixture.kickoff.isAfter(deadline);
      if (!due) continue;
      next[entry.key] = prediction.copyWith(status: PredictionStatus.locked);
      lockedCount++;
    }

    if (lockedCount == 0) return 0;
    emit(
      state.copyWith(
        predictions: next,
        questionIntel: _buildQuestionIntel(state.fixtures, state.quizzes, next),
      ),
    );
    try {
      await _storage.savePredictions(next.values.toList());
      return lockedCount;
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            predictions: previous,
            questionIntel: _buildQuestionIntel(
              state.fixtures,
              state.quizzes,
              previous,
            ),
          ),
        );
      }
      debugPrint(
        'PredictionCubit: failed to persist $lockedCount deadline locks: $error',
      );
      return 0;
    }
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
    if (prediction == null || prediction.status != PredictionStatus.locked) {
      return _noSettlement;
    }
    final quiz = await quizFor(matchId, quizId);
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
    final rivals = board.where((e) => !e.isUser).toList();
    if (rivals.isEmpty) return (1, scorelineContestPrizeFor(1), 1);
    final ahead = rivals
        .where((r) => r.correct.clamp(0, totalQuestions) > playerCorrect)
        .length;
    final rank = ahead + 1;
    return (rank, scorelineContestPrizeFor(rank), rivals.length + 1);
  }
}
