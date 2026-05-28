import 'dart:math';

// XP required to progress from level N to level N+1: gap(N) = 25 × N
int xpGap(int level) => 25 * level;

// Calculate XP delta for a match result.
// Wins in regulation get more XP scaled by goal margin + shutout bonus, capped at +25.
// Losses in regulation lose XP scaled by goal conceded margin, floored at -15.
// Penalty outcomes get flat bonuses/penalties.
int calculateMatchXP({
  required String resultLabel,
  required int playerScore,
  required int opponentScore,
  required bool wentToPenalties,
}) {
  if (resultLabel == 'Draw') return 0;
  if (resultLabel == 'Victory') {
    if (wentToPenalties) return 6;
    final diff = playerScore - opponentScore;
    final shutout = opponentScore == 0 ? 5 : 0;
    return min(25, 10 + diff * 3 + shutout);
  }
  // Defeat
  if (wentToPenalties) return -2;
  return max(-15, -(5 + (opponentScore - playerScore) * 2));
}

class PlayerProgression {
  const PlayerProgression({
    required this.playerLevel,
    required this.totalXP,
    required this.xpIntoLevel,
    required this.xpToNextLevel,
  });

  factory PlayerProgression.initial() => const PlayerProgression(
    playerLevel: 1,
    totalXP: 0,
    xpIntoLevel: 0,
    xpToNextLevel: 25,
  );

  factory PlayerProgression.fromJson(Map<String, dynamic> json) =>
      PlayerProgression(
        playerLevel: json['playerLevel'] as int? ?? 1,
        totalXP: json['totalXP'] as int? ?? 0,
        xpIntoLevel: json['xpIntoLevel'] as int? ?? 0,
        xpToNextLevel: json['xpToNextLevel'] as int? ?? 25,
      );

  final int playerLevel;
  final int totalXP;
  final int xpIntoLevel; // XP earned within the current level
  final int xpToNextLevel; // = xpGap(playerLevel)

  Map<String, dynamic> toJson() => {
    'playerLevel': playerLevel,
    'totalXP': totalXP,
    'xpIntoLevel': xpIntoLevel,
    'xpToNextLevel': xpToNextLevel,
  };

  // Apply XP delta and compute new level.
  // Returns the updated progression state and a list of levels newly crossed.
  // XP is never negative; losses floor at 0. No de-leveling occurs.
  ({PlayerProgression updated, List<int> levelsGained}) applyXP(int delta) {
    final newTotal = max(0, totalXP + delta);
    var level = 1;
    var accumulated = 0;

    while (true) {
      final gap = xpGap(level);
      if (accumulated + gap > newTotal) break;
      accumulated += gap;
      level++;
    }

    final gained = List<int>.generate(
      level - playerLevel,
      (i) => playerLevel + i + 1,
    );

    return (
      updated: PlayerProgression(
        playerLevel: level,
        totalXP: newTotal,
        xpIntoLevel: newTotal - accumulated,
        xpToNextLevel: xpGap(level),
      ),
      levelsGained: gained,
    );
  }
}
