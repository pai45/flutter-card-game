import '../config/enums.dart';
import 'cards.dart';
import 'match.dart';

/// Career stats derived from the saved card-match history. Pure aggregation —
/// no persistence and no new tracking; everything is recomputed from the
/// `matchHistory` the game bloc already loads.
class MatchRecord {
  const MatchRecord({
    required this.played,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.cleanSheets,
    required this.shootoutWins,
    required this.basketballWins,
    required this.currentStreak,
    required this.bestStreak,
  });

  factory MatchRecord.fromHistory(List<MatchHistoryEntry> history) {
    var wins = 0;
    var losses = 0;
    var draws = 0;
    var cleanSheets = 0;
    var shootoutWins = 0;
    var basketballWins = 0;
    for (final match in history) {
      switch (match.resultLabel) {
        case 'Victory':
          wins++;
          if (match.opponentScore == 0) cleanSheets++;
          if (match.isShootout) shootoutWins++;
          if (match.isBasketball) basketballWins++;
        case 'Defeat':
          losses++;
        default:
          draws++;
      }
    }
    return MatchRecord(
      played: history.length,
      wins: wins,
      losses: losses,
      draws: draws,
      cleanSheets: cleanSheets,
      shootoutWins: shootoutWins,
      basketballWins: basketballWins,
      currentStreak: matchWinStreak(history),
      bestStreak: bestMatchWinStreak(history),
    );
  }

  final int played;
  final int wins;
  final int losses;
  final int draws;
  final int cleanSheets;
  final int shootoutWins;
  final int basketballWins;
  final int currentStreak;
  final int bestStreak;

  /// Win percentage across all completed matches, 0–100 (0 when none played).
  int get winRate => played == 0 ? 0 : (wins / played * 100).round();
}

/// Consecutive wins counting back from the most recent match. Match history is
/// stored newest-first, so this walks from the front until a non-win breaks it.
int matchWinStreak(List<MatchHistoryEntry> history) {
  var streak = 0;
  for (final match in history) {
    if (match.resultLabel != 'Victory') break;
    streak++;
  }
  return streak;
}

/// Longest run of consecutive wins anywhere in the history.
int bestMatchWinStreak(List<MatchHistoryEntry> history) {
  var best = 0;
  var run = 0;
  for (final match in history) {
    if (match.resultLabel == 'Victory') {
      run++;
      if (run > best) best = run;
    } else {
      run = 0;
    }
  }
  return best;
}

/// Total distinct cards in the game (players + actions) — the denominator for
/// collection completion.
final int collectionTotal = allPlayerCards.length + actionCards.length;

/// How many of the owned player-card ids are platinum tier.
int ownedPlatinumCount(List<String> ownedCardIds) => ownedCardIds
    .map((id) => allPlayerCards.where((card) => card.id == id).firstOrNull)
    .whereType<PlayerCard>()
    .where((card) => card.tier == CardTier.platinum)
    .length;
