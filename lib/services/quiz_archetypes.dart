import '../models/match_outcome.dart';
import '../models/prediction.dart';
import '../models/sport_match.dart';
import 'match_outcome_resolver.dart';

abstract interface class SportQuizGenerator {
  const SportQuizGenerator();

  PredictionQuiz generate(SportMatch match);
}

/// Deterministic, versioned five-question generator.
///
/// Every value that can change answer meaning (especially thresholds) is
/// captured in the generated snapshot. A future remote implementation can
/// replace this class without changing Cubit or UI callers.
class DeterministicSportQuizGenerator implements SportQuizGenerator {
  const DeterministicSportQuizGenerator();

  @override
  PredictionQuiz generate(SportMatch match) => PredictionQuiz(
    matchId: match.id,
    title: 'Match Prediction',
    subtitle: '5 calls · lock before kickoff',
    schemaVersion: kGeneratedPredictionQuizSchemaVersion,
    generated: true,
    questions: switch (match.sport) {
      Sport.football => _football(match),
      Sport.cricket => _cricket(match),
      Sport.basketball => _basketball(match),
      Sport.tennis => _tennis(match),
      Sport.motorsport => _motorsport(match),
    },
  );

  static List<QuizQuestion> _football(SportMatch match) => [
    const QuizQuestion(
      id: 'exact_score',
      archetypeKey: 'football.exact_score',
      text: 'Predict the full-time score',
      type: QuizQuestionType.exactScore,
      reward: 100,
    ),
    QuizQuestion(
      id: 'winner',
      archetypeKey: 'football.winner',
      text: 'Which team wins?',
      options: [match.home.name, 'Draw', match.away.name],
      reward: 50,
    ),
    const QuizQuestion(
      id: 'btts',
      archetypeKey: 'football.btts',
      text: 'Both teams to score?',
      options: ['Yes', 'No'],
      reward: 40,
    ),
    const QuizQuestion(
      id: 'total_goals_ou',
      archetypeKey: 'football.total_goals',
      settlementRule: {'threshold': 2.5},
      text: 'Total goals over/under 2.5?',
      options: ['Over 2.5', 'Under 2.5'],
      reward: 40,
    ),
    QuizQuestion(
      id: 'first_scorer',
      archetypeKey: 'football.first_scorer',
      text: 'Which side scores first?',
      options: [match.home.name, match.away.name, 'No goals'],
      reward: 45,
    ),
  ];

  static List<QuizQuestion> _cricket(SportMatch match) {
    final limitedOvers =
        match.leagueId.toLowerCase().contains('t20') ||
        match.leagueId.toLowerCase().contains('ipl');
    final runsThreshold = limitedOvers ? 164.5 : 274.5;
    final sixesThreshold = limitedOvers ? 8.5 : 10.5;
    const wicketsThreshold = 11.5;
    return [
      QuizQuestion(
        id: 'winner',
        archetypeKey: 'cricket.winner',
        text: 'Which side wins?',
        options: [match.home.name, match.away.name, 'Tie / No Result'],
        reward: 60,
      ),
      QuizQuestion(
        id: 'total_sixes_ou',
        archetypeKey: 'cricket.total_sixes',
        settlementRule: {'threshold': sixesThreshold},
        text: 'Total sixes over/under $sixesThreshold?',
        options: ['Over $sixesThreshold', 'Under $sixesThreshold'],
        reward: 45,
      ),
      QuizQuestion(
        id: 'first_innings_runs_ou',
        archetypeKey: 'cricket.first_innings_runs',
        settlementRule: {'threshold': runsThreshold},
        text: 'First innings runs over/under $runsThreshold?',
        options: ['Over $runsThreshold', 'Under $runsThreshold'],
        reward: 45,
      ),
      const QuizQuestion(
        id: 'top_score_bracket',
        archetypeKey: 'cricket.top_score',
        text: "The match's top individual score is…",
        options: ['Under 50', '50–99', '100+'],
        reward: 40,
      ),
      const QuizQuestion(
        id: 'total_wickets_ou',
        archetypeKey: 'cricket.total_wickets',
        settlementRule: {'threshold': wicketsThreshold},
        text: 'Total wickets over/under 11.5?',
        options: ['Over 11.5', 'Under 11.5'],
        reward: 40,
      ),
    ];
  }

  static List<QuizQuestion> _basketball(SportMatch match) {
    final threshold = match.leagueId.toLowerCase() == 'nba' ? 219.5 : 159.5;
    return [
      QuizQuestion(
        id: 'winner',
        archetypeKey: 'basketball.winner',
        text: 'Which team wins?',
        options: [match.home.name, match.away.name],
        reward: 60,
      ),
      QuizQuestion(
        id: 'total_points_ou',
        archetypeKey: 'basketball.total_points',
        settlementRule: {'threshold': threshold},
        text: 'Total points over/under $threshold?',
        options: ['Over $threshold', 'Under $threshold'],
        reward: 45,
      ),
      QuizQuestion(
        id: 'halftime_leader',
        archetypeKey: 'basketball.halftime_leader',
        text: 'Who leads at halftime?',
        options: [match.home.name, match.away.name, 'Tied'],
        reward: 45,
      ),
      QuizQuestion(
        id: 'biggest_quarter',
        archetypeKey: 'basketball.biggest_quarter',
        text: 'Which side wins the biggest-margin quarter?',
        options: [match.home.name, match.away.name],
        reward: 40,
      ),
      const QuizQuestion(
        id: 'winning_margin_bracket',
        archetypeKey: 'basketball.winning_margin',
        text: 'The winning margin will be…',
        options: ['1–5', '6–15', '16+'],
        reward: 40,
      ),
    ];
  }

  static List<QuizQuestion> _tennis(SportMatch match) => [
    QuizQuestion(
      id: 'winner',
      archetypeKey: 'tennis.winner',
      text: 'Who wins the match?',
      options: [match.home.name, match.away.name],
      reward: 60,
    ),
    QuizQuestion(
      id: 'first_set_winner',
      archetypeKey: 'tennis.first_set_winner',
      text: 'Who wins the first set?',
      options: [match.home.name, match.away.name],
      reward: 45,
    ),
    const QuizQuestion(
      id: 'total_sets',
      archetypeKey: 'tennis.total_sets',
      text: 'How many sets will be played?',
      options: ['2', '3', '4', '5'],
      reward: 50,
    ),
    const QuizQuestion(
      id: 'straight_sets',
      archetypeKey: 'tennis.straight_sets',
      text: 'Will the winner take it in straight sets?',
      options: ['Yes', 'No'],
      reward: 40,
    ),
    const QuizQuestion(
      id: 'total_games_ou',
      archetypeKey: 'tennis.total_games',
      settlementRule: {'threshold': 22.5},
      text: 'Total games over/under 22.5?',
      options: ['Over 22.5', 'Under 22.5'],
      reward: 45,
    ),
  ];

  static List<QuizQuestion> _motorsport(SportMatch match) {
    final drivers = _driverCandidates(match);
    final constructors = _constructorCandidates(match);
    return [
      QuizQuestion(
        id: 'race_winner',
        archetypeKey: 'motorsport.race_winner',
        text: 'Who wins the race?',
        options: [...drivers, 'OTHER DRIVER'],
        reward: 75,
      ),
      QuizQuestion(
        id: 'pole_sitter',
        archetypeKey: 'motorsport.pole_sitter',
        text: 'Who takes pole position?',
        options: [...drivers, 'OTHER DRIVER'],
        reward: 55,
      ),
      QuizQuestion(
        id: 'winning_constructor',
        archetypeKey: 'motorsport.winning_constructor',
        text: 'Which constructor wins?',
        options: [...constructors, 'OTHER CONSTRUCTOR'],
        reward: 55,
      ),
      const QuizQuestion(
        id: 'pole_to_win',
        archetypeKey: 'motorsport.pole_to_win',
        text: 'Will the pole sitter win the race?',
        options: ['Yes', 'No'],
        reward: 45,
      ),
      const QuizQuestion(
        id: 'winner_started_top_three',
        archetypeKey: 'motorsport.winner_started_top_three',
        text: 'Will the winner start inside the top three?',
        options: ['Yes', 'No'],
        reward: 45,
      ),
    ];
  }

  static List<String> _driverCandidates(SportMatch match) {
    final candidates = <String>[];
    for (final entry in match.f1DriverStandings ?? const <String>[]) {
      _addUnique(candidates, _driverFromResult(entry));
    }
    for (final session in match.f1Sessions ?? const <F1SessionResult>[]) {
      for (final entry in session.results) {
        _addUnique(candidates, _driverFromResult(entry));
      }
    }
    return candidates.take(4).toList(growable: false);
  }

  static List<String> _constructorCandidates(SportMatch match) {
    final candidates = <String>[];
    for (final session in match.f1Sessions ?? const <F1SessionResult>[]) {
      for (final entry in session.results) {
        final constructor = _constructorFromResult(entry);
        if (constructor != null) _addUnique(candidates, constructor);
      }
    }
    if (candidates.isEmpty) {
      candidates.addAll(switch (match.leagueId) {
        'f1' => const ['McLaren', 'Ferrari', 'Mercedes', 'Red Bull'],
        'indycar' => const ['Penske', 'Ganassi', 'Andretti', 'McLaren'],
        _ => const ['Hendrick', 'Joe Gibbs', 'Team Penske', '23XI'],
      });
    }
    return candidates.take(4).toList(growable: false);
  }

  static void _addUnique(List<String> target, String value) {
    if (value.isEmpty ||
        value.toLowerCase() == 'unknown' ||
        target.any((item) => item.toLowerCase() == value.toLowerCase())) {
      return;
    }
    target.add(value);
  }
}

/// Compatibility facade retained for existing call sites and tests.
abstract final class QuizArchetypes {
  static const SportQuizGenerator generator = DeterministicSportQuizGenerator();

  static PredictionQuiz buildQuizFor(SportMatch match) =>
      generator.generate(match);

  static List<QuizQuestion> buildFor(SportMatch match) =>
      buildQuizFor(match).questions;

  static bool canResolve(Sport sport, QuizQuestion question) =>
      question.archetypeKey != null ||
      _legacyKey(sport, question.id) != question.id;

  static List<QuizQuestion> settle(
    Sport sport,
    List<QuizQuestion> questions,
    MatchOutcome outcome,
  ) => [
    for (final question in questions)
      if (question.isSettled)
        question
      else if (!outcome.isFullyResolved)
        question.copyWith(forcedVoid: true)
      else
        _settleQuestion(sport, question, outcome),
  ];

  static LiveQuestionIntel liveIntel(
    SportMatch match,
    QuizQuestion question,
    int? selectedAnswer, {
    DateTime? updatedAt,
  }) {
    final timestamp = updatedAt ?? match.liveLastUpdated ?? DateTime.now();
    if (question.forcedVoid) {
      return LiveQuestionIntel(
        questionId: question.id,
        questionState: PredictionQuestionState.voided,
        pickState: PredictionPickState.unavailable,
        updatedAt: timestamp,
      );
    }
    if (match.status == MatchStatus.finished && question.isSettled) {
      final correctAnswer = question.isScorePrediction
          ? question.settledScoreEncoded
          : question.settledOptionIndex;
      return LiveQuestionIntel(
        questionId: question.id,
        questionState: PredictionQuestionState.finalResult,
        pickState: selectedAnswer == null || correctAnswer == null
            ? PredictionPickState.unavailable
            : selectedAnswer == correctAnswer
            ? PredictionPickState.correct
            : PredictionPickState.incorrect,
        updatedAt: timestamp,
      );
    }

    final outcome = match.status == MatchStatus.finished
        ? MatchOutcomeResolver.resolve(match)
        : MatchOutcomeResolver.resolveCurrent(match);
    final evaluation = _evaluate(match.sport, question, outcome);
    if (!evaluation.available ||
        evaluation.answer == null ||
        (!question.isScorePrediction &&
            evaluation.answer! >= question.options.length)) {
      return LiveQuestionIntel(
        questionId: question.id,
        questionState: PredictionQuestionState.dataUnavailable,
        pickState: selectedAnswer == null
            ? PredictionPickState.unavailable
            : PredictionPickState.stillOpen,
        updatedAt: timestamp,
      );
    }

    final finalResult = match.status == MatchStatus.finished;
    return LiveQuestionIntel(
      questionId: question.id,
      questionState: finalResult
          ? PredictionQuestionState.finalResult
          : evaluation.irreversible
          ? PredictionQuestionState.decided
          : PredictionQuestionState.live,
      pickState: selectedAnswer == null
          ? PredictionPickState.unavailable
          : finalResult
          ? selectedAnswer == evaluation.answer
                ? PredictionPickState.correct
                : PredictionPickState.incorrect
          : selectedAnswer == evaluation.answer
          ? PredictionPickState.leading
          : evaluation.irreversible
          ? PredictionPickState.trailing
          : PredictionPickState.stillOpen,
      updatedAt: timestamp,
    );
  }

  static QuizQuestion _settleQuestion(
    Sport sport,
    QuizQuestion question,
    MatchOutcome outcome,
  ) {
    final evaluation = _evaluate(sport, question, outcome);
    if (!evaluation.available ||
        evaluation.answer == null ||
        (!question.isScorePrediction &&
            evaluation.answer! >= question.options.length)) {
      return question.copyWith(forcedVoid: true);
    }
    if (question.isScorePrediction) {
      final (home, away) = ScoreAnswer.decode(evaluation.answer!);
      return question.copyWith(settledHomeScore: home, settledAwayScore: away);
    }
    return question.copyWith(settledOptionIndex: evaluation.answer);
  }

  static _RuleEvaluation _evaluate(
    Sport sport,
    QuizQuestion question,
    MatchOutcome outcome,
  ) {
    final key = question.archetypeKey ?? _legacyKey(sport, question.id);
    final threshold = (question.settlementRule['threshold'] as num?)
        ?.toDouble();
    final home = outcome.homeScore;
    final away = outcome.awayScore;

    return switch (key) {
      'football.exact_score' =>
        home == null || away == null
            ? const _RuleEvaluation.unavailable()
            : _RuleEvaluation(ScoreAnswer.encode(home, away)),
      'football.winner' => _sideEvaluation(
        outcome.winner,
        homeIndex: 0,
        drawIndex: 1,
        awayIndex: 2,
      ),
      'football.btts' =>
        outcome.bothSidesScored == null
            ? const _RuleEvaluation.unavailable()
            : _RuleEvaluation(
                outcome.bothSidesScored! ? 0 : 1,
                irreversible: outcome.bothSidesScored!,
              ),
      'football.total_goals' => _overUnder(
        outcome.totalScoreLine,
        threshold ?? 2.5,
      ),
      'football.first_scorer' => switch (outcome.firstScorerSide) {
        OutcomeSide.home => const _RuleEvaluation(0, irreversible: true),
        OutcomeSide.away => const _RuleEvaluation(1, irreversible: true),
        OutcomeSide.draw => const _RuleEvaluation(2, irreversible: true),
        null =>
          home == 0 && away == 0
              ? const _RuleEvaluation(2)
              : const _RuleEvaluation.unavailable(),
      },
      'cricket.winner' => _sideEvaluation(
        outcome.winner,
        homeIndex: 0,
        awayIndex: 1,
        drawIndex: 2,
      ),
      'cricket.total_sixes' => _overUnder(
        outcome.sportSpecific['totalSixes'] as int?,
        threshold ?? 8.5,
      ),
      'cricket.first_innings_runs' => _overUnder(
        outcome.sportSpecific['firstInningsRuns'] as int?,
        threshold ?? 164.5,
        irreversible:
            outcome.sportSpecific['firstInningsComplete'] as bool? ?? false,
      ),
      'cricket.top_score' => _topScoreEvaluation(
        outcome.sportSpecific['topScore'] as int?,
      ),
      'cricket.total_wickets' => _overUnder(
        outcome.sportSpecific['totalWickets'] as int?,
        threshold ?? 11.5,
      ),
      'basketball.winner' => _sideEvaluation(
        outcome.winner,
        homeIndex: 0,
        awayIndex: 1,
      ),
      'basketball.total_points' => _overUnder(
        outcome.totalScoreLine,
        threshold ?? 159.5,
      ),
      'basketball.halftime_leader' => _sideEvaluation(
        outcome.sportSpecific['halftimeLeader'] as OutcomeSide?,
        homeIndex: 0,
        awayIndex: 1,
        drawIndex: 2,
        irreversible:
            outcome.sportSpecific['halftimeComplete'] as bool? ?? false,
      ),
      'basketball.biggest_quarter' => _sideEvaluation(
        outcome.sportSpecific['biggestQuarterSide'] as OutcomeSide?,
        homeIndex: 0,
        awayIndex: 1,
      ),
      'basketball.winning_margin' => _marginEvaluation(
        outcome.sportSpecific['winningMargin'] as int?,
      ),
      'tennis.winner' => _sideEvaluation(
        outcome.winner,
        homeIndex: 0,
        awayIndex: 1,
      ),
      'tennis.first_set_winner' => _sideEvaluation(
        outcome.sportSpecific['set1Winner'] as OutcomeSide?,
        homeIndex: 0,
        awayIndex: 1,
        irreversible: outcome.sportSpecific['set1Winner'] != null,
      ),
      'tennis.total_sets' => _totalSetsEvaluation(
        outcome.sportSpecific['totalSets'] as int?,
        finalResult: outcome.isFullyResolved,
      ),
      'tennis.straight_sets' => _boolEvaluation(
        outcome.sportSpecific['straightSets'] as bool?,
      ),
      'tennis.total_games' => _overUnder(
        outcome.sportSpecific['totalGames'] as int?,
        threshold ?? 22.5,
      ),
      'motorsport.race_winner' => _namedEvaluation(
        question.options,
        outcome.sportSpecific['winnerName'] as String?,
      ),
      'motorsport.pole_sitter' => _namedEvaluation(
        question.options,
        outcome.sportSpecific['poleSitter'] as String?,
        irreversible: outcome.sportSpecific['poleSitter'] != null,
      ),
      'motorsport.winning_constructor' => _namedEvaluation(
        question.options,
        outcome.sportSpecific['winningConstructor'] as String?,
      ),
      'motorsport.pole_to_win' => _boolEvaluation(
        outcome.sportSpecific['poleToWin'] as bool?,
      ),
      'motorsport.winner_started_top_three' => _boolEvaluation(
        outcome.sportSpecific['winnerStartedTopThree'] as bool?,
      ),
      _ => const _RuleEvaluation.unavailable(),
    };
  }

  static String _legacyKey(Sport sport, String id) => switch ((sport, id)) {
    (Sport.football, 'exact_score') => 'football.exact_score',
    (Sport.football, 'winner') => 'football.winner',
    (Sport.football, 'btts') => 'football.btts',
    (Sport.football, 'total_goals_ou') => 'football.total_goals',
    (Sport.football, 'first_scorer') => 'football.first_scorer',
    (Sport.cricket, 'winner') => 'cricket.winner',
    (Sport.cricket, 'total_sixes_ou') => 'cricket.total_sixes',
    (Sport.cricket, 'first_innings_runs_ou') => 'cricket.first_innings_runs',
    (Sport.cricket, 'top_score_bracket') => 'cricket.top_score',
    (Sport.cricket, 'total_wickets_ou') => 'cricket.total_wickets',
    (Sport.basketball, 'winner') => 'basketball.winner',
    (Sport.basketball, 'total_points_ou') => 'basketball.total_points',
    (Sport.basketball, 'halftime_leader') => 'basketball.halftime_leader',
    (Sport.basketball, 'biggest_quarter') => 'basketball.biggest_quarter',
    (Sport.basketball, 'winning_margin_bracket') => 'basketball.winning_margin',
    (Sport.tennis, 'winner') => 'tennis.winner',
    (Sport.tennis, 'first_set_winner') => 'tennis.first_set_winner',
    (Sport.tennis, 'total_sets') => 'tennis.total_sets',
    (Sport.tennis, 'straight_sets') => 'tennis.straight_sets',
    (Sport.tennis, 'total_games_ou') => 'tennis.total_games',
    (Sport.motorsport, 'race_winner') => 'motorsport.race_winner',
    (Sport.motorsport, 'pole_sitter') => 'motorsport.pole_sitter',
    (Sport.motorsport, 'winning_constructor') =>
      'motorsport.winning_constructor',
    (Sport.motorsport, 'pole_to_win') => 'motorsport.pole_to_win',
    (Sport.motorsport, 'winner_started_top_three') =>
      'motorsport.winner_started_top_three',
    _ => id,
  };

  static _RuleEvaluation _overUnder(
    num? value,
    double threshold, {
    bool irreversible = false,
  }) {
    if (value == null) return const _RuleEvaluation.unavailable();
    final over = value > threshold;
    return _RuleEvaluation(over ? 0 : 1, irreversible: over || irreversible);
  }

  static _RuleEvaluation _topScoreEvaluation(int? score) {
    if (score == null) return const _RuleEvaluation.unavailable();
    return _RuleEvaluation(score >= 100 ? 2 : (score >= 50 ? 1 : 0));
  }

  static _RuleEvaluation _marginEvaluation(int? margin) {
    if (margin == null) return const _RuleEvaluation.unavailable();
    return _RuleEvaluation(margin >= 16 ? 2 : (margin >= 6 ? 1 : 0));
  }

  static _RuleEvaluation _totalSetsEvaluation(
    int? sets, {
    required bool finalResult,
  }) {
    if (sets == null) return const _RuleEvaluation.unavailable();
    return _RuleEvaluation(
      (sets - 2).clamp(0, 3).toInt(),
      irreversible: finalResult,
    );
  }

  static _RuleEvaluation _boolEvaluation(bool? value) {
    if (value == null) return const _RuleEvaluation.unavailable();
    return _RuleEvaluation(value ? 0 : 1);
  }

  static _RuleEvaluation _sideEvaluation(
    OutcomeSide? side, {
    required int homeIndex,
    required int awayIndex,
    int? drawIndex,
    bool irreversible = false,
  }) => switch (side) {
    OutcomeSide.home => _RuleEvaluation(homeIndex, irreversible: irreversible),
    OutcomeSide.away => _RuleEvaluation(awayIndex, irreversible: irreversible),
    OutcomeSide.draw when drawIndex != null => _RuleEvaluation(
      drawIndex,
      irreversible: irreversible,
    ),
    _ => const _RuleEvaluation.unavailable(),
  };

  static _RuleEvaluation _namedEvaluation(
    List<String> options,
    String? value, {
    bool irreversible = false,
  }) {
    if (value == null || value.isEmpty || options.isEmpty) {
      return const _RuleEvaluation.unavailable();
    }
    final normalized = value.toLowerCase();
    for (var index = 0; index < options.length; index++) {
      final option = options[index].toLowerCase();
      if (!option.startsWith('other') &&
          (option == normalized ||
              option.contains(normalized) ||
              normalized.contains(option))) {
        return _RuleEvaluation(index, irreversible: irreversible);
      }
    }
    return _RuleEvaluation(options.length - 1, irreversible: irreversible);
  }
}

class _RuleEvaluation {
  const _RuleEvaluation(this.answer, {this.irreversible = false})
    : available = true;

  const _RuleEvaluation.unavailable()
    : answer = null,
      irreversible = false,
      available = false;

  final int? answer;
  final bool irreversible;
  final bool available;
}

String _driverFromResult(String entry) {
  final withoutPosition = entry
      .replaceFirst(RegExp(r'^\s*\d+[.)]\s*'), '')
      .trim();
  return withoutPosition.split(' · ').first.split(' (').first.trim();
}

String? _constructorFromResult(String entry) {
  final parts = entry.split(' · ');
  if (parts.length < 2) return null;
  return parts[1].split(' (').first.trim();
}
