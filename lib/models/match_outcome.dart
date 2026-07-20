/// Which side a resolved outcome favours.
enum OutcomeSide { home, away, draw }

/// The sport-agnostic facts extracted from one finished [SportMatch], computed
/// once by [MatchOutcomeResolver] and shared by both the prediction-quiz
/// settlement engine and the picks/markets settlement engine — so "who won"
/// is never derived twice by two independent code paths.
///
/// Fields are nullable/optional because not every sport (or every fixture,
/// depending on how much the feed actually carried) populates all of them.
/// [isFullyResolved] is the single flag callers check before trusting
/// anything else here; when it's false, every archetype resolver for that
/// match should void rather than guess.
class MatchOutcome {
  const MatchOutcome({
    required this.matchId,
    required this.isFullyResolved,
    this.winner,
    this.homeScore,
    this.awayScore,
    this.bothSidesScored,
    this.totalScoreLine,
    this.firstScorerSide,
    this.sportSpecific = const {},
  });

  /// Nothing could be extracted for this match — every archetype must void.
  const MatchOutcome.unresolved(this.matchId)
    : isFullyResolved = false,
      winner = null,
      homeScore = null,
      awayScore = null,
      bothSidesScored = null,
      totalScoreLine = null,
      firstScorerSide = null,
      sportSpecific = const {};

  final String matchId;

  /// False when the match's enriched data wasn't sufficient to determine even
  /// the basics (winner/score). Individual archetypes may still resolve a
  /// narrower fact even when this is true for the whole match — callers
  /// decide per-archetype whether the specific field they need is present.
  final bool isFullyResolved;

  final OutcomeSide? winner;

  /// The primary scoring unit for the sport: goals (football), runs (cricket,
  /// for the side batting second / chasing), points (basketball), games won
  /// (tennis — see `sportSpecific['homeSets']`/`['awaySets']` for the actual
  /// set tally). Null where the concept doesn't map cleanly (motorsport).
  final int? homeScore;
  final int? awayScore;

  /// Football/cricket "both teams scored"-equivalent. Null where not
  /// applicable (tennis, basketball, motorsport).
  final bool? bothSidesScored;

  /// Combined score for over/under-style markets.
  final int? totalScoreLine;

  /// Which side produced the first notable scoring event (e.g. first goal).
  final OutcomeSide? firstScorerSide;

  /// Escape hatch for facts that don't generalise across sports: cricket's
  /// total sixes/first-innings runs, tennis's set tally/straight-sets flag,
  /// basketball's biggest-quarter side, motorsport's podium/pole-sitter names.
  /// Read only by that sport's own archetype-resolution functions — generic
  /// code must never reach into this map.
  final Map<String, Object?> sportSpecific;
}
