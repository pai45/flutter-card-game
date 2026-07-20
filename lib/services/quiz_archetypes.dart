import '../models/match_outcome.dart';
import '../models/prediction.dart';
import '../models/sport_match.dart';

/// Generates a small, always-resolvable question set for fixtures that have
/// no hand-authored quiz — the gap this closes is every non-FIFA football
/// league (MLS, UCL Qualifying, Brasileirão, Liga MX, Allsvenskan,
/// Eliteserien, …) and every cricket fixture, none of which get a quiz today.
///
/// Deliberately NOT reusing [buildFootballQuiz]'s larger, creative bank
/// (~25 archetypes covering possession/cards/corners/etc.) — those need much
/// richer per-league stat data to resolve reliably and stay out of scope
/// here. This is the same shape proven end-to-end by the hand-transcribed
/// World Cup third-place quiz (`'760516'` in prediction_repository.dart):
/// a handful of questions, each backed by a field [MatchOutcomeResolver]
/// always either produces or explicitly can't — so nothing here is ever
/// left half-resolved.
///
/// Tennis/basketball/motorsport are added in later phases; [buildFor]
/// returns an empty list for them for now (same as today's behaviour — no
/// quiz — so this is not a regression).
abstract final class QuizArchetypes {
  /// Fresh, unsettled question set for a fixture with no existing quiz.
  static List<QuizQuestion> buildFor(SportMatch match) => switch (match.sport) {
    Sport.football => _footballTemplate(match.home.name, match.away.name),
    Sport.cricket => _cricketTemplate(match.home.name, match.away.name),
    Sport.basketball => _basketballTemplate(match.home.name, match.away.name),
    _ => const [],
  };

  /// Given a question set built by [buildFor] (or any quiz sharing these
  /// ids) and a resolved [MatchOutcome], returns a copy with settled values
  /// filled in. Any question whose value can't be determined from [outcome]
  /// is voided individually rather than left unresolved.
  static List<QuizQuestion> settle(
    Sport sport,
    List<QuizQuestion> questions,
    MatchOutcome outcome,
  ) => switch (sport) {
    Sport.football => _settleFootball(questions, outcome),
    Sport.cricket => _settleCricket(questions, outcome),
    Sport.basketball => _settleBasketball(questions, outcome),
    _ => questions,
  };

  // ── Football ────────────────────────────────────────────────────────────

  static List<QuizQuestion> _footballTemplate(String home, String away) => [
    const QuizQuestion(
      id: 'exact_score',
      text: 'Predict the full-time score',
      type: QuizQuestionType.exactScore,
      reward: 100,
    ),
    QuizQuestion(
      id: 'winner',
      text: 'Which team wins?',
      options: [home, 'Draw', away],
      reward: 50,
    ),
    const QuizQuestion(
      id: 'btts',
      text: 'Both teams to score?',
      options: ['Yes', 'No'],
      reward: 40,
    ),
    const QuizQuestion(
      id: 'total_goals_ou',
      text: 'Total goals over/under 2.5?',
      options: ['Over 2.5', 'Under 2.5'],
      reward: 40,
    ),
    QuizQuestion(
      id: 'first_scorer',
      text: 'Which side scores first?',
      options: [home, away],
      reward: 45,
    ),
  ];

  static List<QuizQuestion> _settleFootball(
    List<QuizQuestion> questions,
    MatchOutcome outcome,
  ) {
    if (!outcome.isFullyResolved) {
      return [for (final q in questions) q.copyWith(forcedVoid: true)];
    }
    return [
      for (final q in questions)
        switch (q.id) {
          'exact_score' =>
            (outcome.homeScore != null && outcome.awayScore != null)
                ? q.copyWith(
                    settledHomeScore: outcome.homeScore,
                    settledAwayScore: outcome.awayScore,
                  )
                : q.copyWith(forcedVoid: true),
          'winner' => switch (outcome.winner) {
            OutcomeSide.home => q.copyWith(settledOptionIndex: 0),
            OutcomeSide.draw => q.copyWith(settledOptionIndex: 1),
            OutcomeSide.away => q.copyWith(settledOptionIndex: 2),
            null => q.copyWith(forcedVoid: true),
          },
          'btts' => outcome.bothSidesScored == null
              ? q.copyWith(forcedVoid: true)
              : q.copyWith(
                  settledOptionIndex: outcome.bothSidesScored! ? 0 : 1,
                ),
          'total_goals_ou' => outcome.totalScoreLine == null
              ? q.copyWith(forcedVoid: true)
              : q.copyWith(
                  settledOptionIndex: outcome.totalScoreLine! > 2.5 ? 0 : 1,
                ),
          'first_scorer' => switch (outcome.firstScorerSide) {
            OutcomeSide.home => q.copyWith(settledOptionIndex: 0),
            OutcomeSide.away => q.copyWith(settledOptionIndex: 1),
            _ => q.copyWith(forcedVoid: true),
          },
          _ => q.copyWith(forcedVoid: true),
        },
    ];
  }

  // ── Cricket ─────────────────────────────────────────────────────────────

  static List<QuizQuestion> _cricketTemplate(String home, String away) => [
    QuizQuestion(
      id: 'winner',
      text: 'Which side wins?',
      options: [home, away, 'Tie / No Result'],
      reward: 60,
    ),
    const QuizQuestion(
      id: 'total_sixes_ou',
      text: 'Total sixes over/under 8.5?',
      options: ['Over 8.5', 'Under 8.5'],
      reward: 45,
    ),
    const QuizQuestion(
      id: 'first_innings_runs_ou',
      text: 'First innings runs over/under 164.5?',
      options: ['Over 164.5', 'Under 164.5'],
      reward: 45,
    ),
    const QuizQuestion(
      id: 'top_score_bracket',
      text: "The match's top individual score is…",
      options: ['Under 50', '50–99', '100+'],
      reward: 40,
    ),
  ];

  static List<QuizQuestion> _settleCricket(
    List<QuizQuestion> questions,
    MatchOutcome outcome,
  ) {
    if (!outcome.isFullyResolved) {
      return [for (final q in questions) q.copyWith(forcedVoid: true)];
    }
    final totalSixes = outcome.sportSpecific['totalSixes'] as int?;
    final firstInningsRuns = outcome.sportSpecific['firstInningsRuns'] as int?;
    final topScore = outcome.sportSpecific['topScore'] as int?;
    return [
      for (final q in questions)
        switch (q.id) {
          'winner' => switch (outcome.winner) {
            OutcomeSide.home => q.copyWith(settledOptionIndex: 0),
            OutcomeSide.away => q.copyWith(settledOptionIndex: 1),
            OutcomeSide.draw => q.copyWith(settledOptionIndex: 2),
            null => q.copyWith(forcedVoid: true),
          },
          'total_sixes_ou' => totalSixes == null
              ? q.copyWith(forcedVoid: true)
              : q.copyWith(settledOptionIndex: totalSixes > 8 ? 0 : 1),
          'first_innings_runs_ou' => firstInningsRuns == null
              ? q.copyWith(forcedVoid: true)
              : q.copyWith(
                  settledOptionIndex: firstInningsRuns > 164 ? 0 : 1,
                ),
          'top_score_bracket' => topScore == null
              ? q.copyWith(forcedVoid: true)
              : q.copyWith(
                  settledOptionIndex: topScore >= 100
                      ? 2
                      : (topScore >= 50 ? 1 : 0),
                ),
          _ => q.copyWith(forcedVoid: true),
        },
    ];
  }

  // ── Basketball ──────────────────────────────────────────────────────────

  static List<QuizQuestion> _basketballTemplate(String home, String away) => [
    QuizQuestion(
      id: 'winner',
      text: 'Which team wins?',
      options: [home, away],
      reward: 60,
    ),
    const QuizQuestion(
      id: 'total_points_ou',
      text: 'Total points over/under 159.5?',
      options: ['Over 159.5', 'Under 159.5'],
      reward: 45,
    ),
    QuizQuestion(
      id: 'biggest_quarter',
      text: 'Which side wins the biggest-margin quarter?',
      options: [home, away],
      reward: 40,
    ),
    const QuizQuestion(
      id: 'winning_margin_bracket',
      text: 'The winning margin will be…',
      options: ['1–5', '6–15', '16+'],
      reward: 40,
    ),
  ];

  static List<QuizQuestion> _settleBasketball(
    List<QuizQuestion> questions,
    MatchOutcome outcome,
  ) {
    if (!outcome.isFullyResolved) {
      return [for (final q in questions) q.copyWith(forcedVoid: true)];
    }
    final biggestQuarterSide = outcome.sportSpecific['biggestQuarterSide'];
    final margin = outcome.sportSpecific['winningMargin'] as int?;
    return [
      for (final q in questions)
        switch (q.id) {
          'winner' => switch (outcome.winner) {
            OutcomeSide.home => q.copyWith(settledOptionIndex: 0),
            OutcomeSide.away => q.copyWith(settledOptionIndex: 1),
            _ => q.copyWith(forcedVoid: true),
          },
          'total_points_ou' => outcome.totalScoreLine == null
              ? q.copyWith(forcedVoid: true)
              : q.copyWith(
                  settledOptionIndex: outcome.totalScoreLine! > 159.5 ? 0 : 1,
                ),
          'biggest_quarter' => switch (biggestQuarterSide) {
            OutcomeSide.home => q.copyWith(settledOptionIndex: 0),
            OutcomeSide.away => q.copyWith(settledOptionIndex: 1),
            _ => q.copyWith(forcedVoid: true),
          },
          'winning_margin_bracket' => margin == null
              ? q.copyWith(forcedVoid: true)
              : q.copyWith(
                  settledOptionIndex: margin >= 16 ? 2 : (margin >= 6 ? 1 : 0),
                ),
          _ => q.copyWith(forcedVoid: true),
        },
    ];
  }
}
