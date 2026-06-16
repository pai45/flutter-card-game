import '../models/prediction.dart';

/// Shared football prediction-question bank, ported from the canonical
/// `questions f (1).js` bank. Only the question *text* and *options* are ported;
/// the JS `resolve()` functions target a live backend and are out of scope for
/// the mock repository (upcoming fixtures stay open, finished demos keep their
/// own hardcoded settled answers in [MockPredictionRepository]).
///
/// [buildFootballQuiz] assembles a gamified per-fixture quiz: an exact-score
/// centerpiece, the compulsory match-winner pick, then one seeded question from
/// each of four category buckets so every match plays a varied but stable set.
///
/// Each question carries a full-bleed [QuizQuestion.backgroundAsset] (see
/// [_backgroundFor]); the art lives in `assets/backgrounds/predictions/` and is
/// keyed by question id. Ids not in the map fall back to `default.webp`.

const _bgDir = 'assets/backgrounds/predictions';

/// True/False prediction on a declarative statement (matches the JS bank).
const List<String> _trueFalse = ['True', 'False'];

enum _Cat { matchBool, matchMcq, teamBool, teamMcq }

/// One bank entry. [options] is a builder so team-name markets ("Which team…")
/// can be bound to the actual fixture sides at render time.
class _BankQuestion {
  const _BankQuestion(this.id, this.cat, this.template, this.options);

  final String id;
  final _Cat cat;

  /// May contain `{teamA}` / `{teamB}` placeholders.
  final String template;

  /// (home, away) -> option labels.
  final List<String> Function(String home, String away) options;
}

/// Boolean helper: declarative statement answered True/False.
List<String> _bool(String _, String _) => _trueFalse;

/// id -> background base name (extension added in [_backgroundFor]). Several
/// questions intentionally share one image; ids absent here use `default`.
const Map<String, String> _bgById = {
  'exact_score': 'match_result_mcq',
  'match_result_mcq': 'match_result_mcq',
  'match_ends_in_draw': 'match_ends_in_draw',
  'both_teams_to_score': 'both_teams_to_score',
  'first_scorer_wins': 'first_scorer_wins',
  'halftime_leader_wins': 'halftime_leader_wins',
  'match_has_red_card': 'match_has_red_card',
  'team_red_card_b': 'match_has_red_card',
  'match_over_4_yellow_cards': 'match_over_4_yellow_cards',
  'first_goal_before_30': 'first_goal_before_30',
  'match_over_8_corners': 'match_over_8_corners',
  'total_corners_range_mcq': 'match_over_8_corners',
  'team_corners_range_mcq': 'match_over_8_corners',
  'team_five_plus_corners': 'match_over_8_corners',
  'team_wins_match': 'team_wins_match',
  'team_clean_sheet': 'team_clean_sheet',
  'team_possession_over_60': 'team_possession_over_60',
  'team_five_plus_shots_on_target': 'team_five_plus_shots_on_target',
  'team_red_card_a': 'team_gets_red_card',
  'team_yellow_card_a': 'total_yellow_cards_range_mcq',
  'team_yellow_card_b': 'total_yellow_cards_range_mcq',
  'total_yellow_cards_range_mcq': 'total_yellow_cards_range_mcq',
  'team_ten_plus_fouls': 'team_ten_plus_fouls',
  'total_cards_range_mcq': 'team_ten_plus_fouls',
  'halftime_leader_mcq': 'halftime_leader_mcq',
  'first_goal_team_mcq': 'first_goal_team_mcq',
  'first_goal_window_mcq': 'first_goal_team_mcq',
  'total_goals_range_mcq': 'total_goals_range_mcq',
  'team_shots_range_mcq': 'team_shots_range_mcq',
  'team_goals_range_mcq': 'team_goals_range_mcq',
  'team_scores_two_plus': 'team_goals_range_mcq',
  // 'match_three_or_more_goals' -> default.webp (no dedicated art)
};

String _backgroundFor(String id) => '$_bgDir/${_bgById[id] ?? 'default'}.webp';

int _rewardFor(_Cat cat) => switch (cat) {
  _Cat.matchMcq || _Cat.teamMcq => 90,
  _Cat.matchBool || _Cat.teamBool => 60,
};

/// The compulsory match-winner question; always included.
const _matchResult = _BankQuestion(
  'match_result_mcq',
  _Cat.matchMcq,
  'Which team will win the match?',
  _winnerOptions,
);

List<String> _winnerOptions(String home, String away) => [home, away, 'Draw'];
List<String> _firstGoalOptions(String home, String away) => [
  home,
  away,
  'No goal scored',
];

/// Full bank (excluding the compulsory winner + the exact-score centerpiece).
final List<_BankQuestion> _bank = [
  // ── match-level booleans ──
  _BankQuestion(
    'match_three_or_more_goals',
    _Cat.matchBool,
    'There will be 3 or more total goals in the match.',
    _bool,
  ),
  _BankQuestion(
    'match_ends_in_draw',
    _Cat.matchBool,
    'The match will end in a draw.',
    _bool,
  ),
  _BankQuestion(
    'both_teams_to_score',
    _Cat.matchBool,
    'Both teams will score at least one goal.',
    _bool,
  ),
  _BankQuestion(
    'first_scorer_wins',
    _Cat.matchBool,
    'The team that scores first will go on to win the match.',
    _bool,
  ),
  _BankQuestion(
    'halftime_leader_wins',
    _Cat.matchBool,
    'The team leading at half time will win the match.',
    _bool,
  ),
  _BankQuestion(
    'match_has_red_card',
    _Cat.matchBool,
    'At least one red card will be shown in the match.',
    _bool,
  ),
  _BankQuestion(
    'match_over_4_yellow_cards',
    _Cat.matchBool,
    'The match will produce 4 or more yellow cards in total.',
    _bool,
  ),
  _BankQuestion(
    'first_goal_before_30',
    _Cat.matchBool,
    'The first goal of the match will be scored before the 30-minute mark.',
    _bool,
  ),
  _BankQuestion(
    'match_over_8_corners',
    _Cat.matchBool,
    'There will be more than 8 corner kicks in the match.',
    _bool,
  ),
  // ── team-specific booleans ──
  _BankQuestion(
    'team_wins_match',
    _Cat.teamBool,
    '{teamA} will win the match.',
    _bool,
  ),
  _BankQuestion(
    'team_clean_sheet',
    _Cat.teamBool,
    '{teamA} will keep a clean sheet (concede 0 goals).',
    _bool,
  ),
  _BankQuestion(
    'team_scores_two_plus',
    _Cat.teamBool,
    '{teamB} will score 2 or more goals in the match.',
    _bool,
  ),
  _BankQuestion(
    'team_possession_over_60',
    _Cat.teamBool,
    '{teamA} will have more than 60% possession.',
    _bool,
  ),
  _BankQuestion(
    'team_five_plus_shots_on_target',
    _Cat.teamBool,
    '{teamB} will register 5 or more shots on target.',
    _bool,
  ),
  _BankQuestion(
    'team_red_card_a',
    _Cat.teamBool,
    '{teamA} will receive a red card in the match.',
    _bool,
  ),
  _BankQuestion(
    'team_red_card_b',
    _Cat.teamBool,
    '{teamB} will receive a red card in the match.',
    _bool,
  ),
  _BankQuestion(
    'team_yellow_card_a',
    _Cat.teamBool,
    '{teamA} will receive a yellow card in the match.',
    _bool,
  ),
  _BankQuestion(
    'team_yellow_card_b',
    _Cat.teamBool,
    '{teamB} will receive a yellow card in the match.',
    _bool,
  ),
  _BankQuestion(
    'team_ten_plus_fouls',
    _Cat.teamBool,
    '{teamA} will commit 10 or more fouls in the match.',
    _bool,
  ),
  _BankQuestion(
    'team_five_plus_corners',
    _Cat.teamBool,
    '{teamA} will win 5 or more corner kicks.',
    _bool,
  ),
  // ── match-level MCQs ──
  _BankQuestion(
    'halftime_leader_mcq',
    _Cat.matchMcq,
    'Which team will be leading at half time?',
    _winnerOptions,
  ),
  _BankQuestion(
    'first_goal_team_mcq',
    _Cat.matchMcq,
    'Which team will score the first goal of the match?',
    _firstGoalOptions,
  ),
  _BankQuestion(
    'total_goals_range_mcq',
    _Cat.matchMcq,
    'How many total goals will be scored in the match?',
    (_, _) => const ['0 - 1', '2 - 3', '4 - 5', '6 or more'],
  ),
  _BankQuestion(
    'total_yellow_cards_range_mcq',
    _Cat.matchMcq,
    'How many yellow cards will be shown in total?',
    (_, _) => const ['0 - 2', '3 - 4', '5 - 6', '7 or more'],
  ),
  _BankQuestion(
    'total_cards_range_mcq',
    _Cat.matchMcq,
    'How many total cards (yellow + red) will be shown in the match?',
    (_, _) => const ['0 - 3', '4 - 5', '6 - 7', '8 or more'],
  ),
  _BankQuestion(
    'total_corners_range_mcq',
    _Cat.matchMcq,
    'How many total corner kicks will the match have?',
    (_, _) => const ['0 - 5', '6 - 9', '10 - 13', '14 or more'],
  ),
  _BankQuestion(
    'first_goal_window_mcq',
    _Cat.matchMcq,
    'When will the first goal of the match be scored?',
    (_, _) => const [
      '1 - 15 min',
      '16 - 30 min',
      '31 - 45 min',
      '46 - 60 min',
      '61 - 75 min',
      '76 - 90+ min',
      'No goal scored',
    ],
  ),
  // ── team-specific MCQs ──
  _BankQuestion(
    'team_goals_range_mcq',
    _Cat.teamMcq,
    'How many goals will {teamA} score in the match?',
    (_, _) => const ['0', '1', '2', '3 or more'],
  ),
  _BankQuestion(
    'team_shots_range_mcq',
    _Cat.teamMcq,
    'How many shots will {teamA} take in the match?',
    (_, _) => const ['Under 5', '5 - 9', '10 - 14', '15 or more'],
  ),
  _BankQuestion(
    'team_corners_range_mcq',
    _Cat.teamMcq,
    'How many corner kicks will {teamA} win?',
    (_, _) => const ['0 - 2', '3 - 5', '6 - 8', '9 or more'],
  ),
];

/// Same stable hash the repository uses, so a fixture's quiz is fixed but varied.
int _stableSeed(String value) {
  var hash = 17;
  for (final unit in value.codeUnits) {
    hash = (hash * 31 + unit) % 100000;
  }
  return hash;
}

QuizQuestion _toQuestion(_BankQuestion q, String home, String away) {
  String bind(String s) =>
      s.replaceAll('{teamA}', home).replaceAll('{teamB}', away);
  return QuizQuestion(
    id: q.id,
    text: bind(q.template),
    options: q.options(home, away),
    reward: _rewardFor(q.cat),
    backgroundAsset: _backgroundFor(q.id),
  );
}

/// Deterministically pick one entry of [cat] from the bank using [salt].
_BankQuestion _pick(int seed, int salt, _Cat cat) {
  final pool = _bank.where((q) => q.cat == cat).toList();
  return pool[(seed + salt) % pool.length];
}

/// Build the gamified per-fixture football quiz from the shared bank:
/// exact-score centerpiece + compulsory winner + one seeded question from each
/// of the four category buckets (6 questions total).
PredictionQuiz buildFootballQuiz({
  required String matchId,
  required String home,
  required String away,
}) {
  final seed = _stableSeed(matchId);
  return PredictionQuiz(
    matchId: matchId,
    questions: [
      QuizQuestion(
        id: 'exact_score',
        text: 'Predict the full-time score',
        type: QuizQuestionType.exactScore,
        reward: 125,
        backgroundAsset: _backgroundFor('exact_score'),
      ),
      _toQuestion(_matchResult, home, away),
      _toQuestion(_pick(seed, 1, _Cat.matchMcq), home, away),
      _toQuestion(_pick(seed, 2, _Cat.matchBool), home, away),
      _toQuestion(_pick(seed, 3, _Cat.teamBool), home, away),
      _toQuestion(_pick(seed, 4, _Cat.teamMcq), home, away),
    ],
  );
}
