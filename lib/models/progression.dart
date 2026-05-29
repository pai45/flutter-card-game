import 'dart:math';

import '../config/enums.dart';
import 'cards.dart';

// Cumulative XP required to reach level L. L1 = 0, L2 = 100, L3 = 300.
const int _kLevelXp = 50;

int xpToReach(int level) => _kLevelXp * level * (level - 1);

int levelFromXp(int totalXp) {
  final xp = max(0, totalXp);
  final level =
      ((_kLevelXp + sqrt(_kLevelXp * _kLevelXp + 4 * _kLevelXp * xp)) /
              (2 * _kLevelXp))
          .floor();
  return max(1, level);
}

class LevelProgress {
  const LevelProgress({
    required this.level,
    required this.intoLevel,
    required this.levelSpan,
    required this.toNextLevel,
    required this.pct,
  });

  final int level;
  final int intoLevel;
  final int levelSpan;
  final int toNextLevel;
  final double pct;
}

LevelProgress levelProgress(int totalXp) {
  final xp = max(0, totalXp);
  final level = levelFromXp(xp);
  final start = xpToReach(level);
  final next = xpToReach(level + 1);
  final span = next - start;
  final into = xp - start;
  return LevelProgress(
    level: level,
    intoLevel: into,
    levelSpan: span,
    toNextLevel: next - xp,
    pct: span == 0 ? 0 : (into / span).clamp(0.0, 1.0),
  );
}

CardRarity playerRarity(int rating) {
  if (rating >= 90) return CardRarity.legendary;
  if (rating >= 83) return CardRarity.epic;
  if (rating >= 75) return CardRarity.rare;
  return CardRarity.common;
}

CardRarity actionRarity(int power) {
  if (power >= 20) return CardRarity.legendary;
  if (power >= 14) return CardRarity.epic;
  if (power >= 8) return CardRarity.rare;
  return CardRarity.common;
}

int playerCardXp(PlayerCard card) => card.rating;

int actionCardXp(ActionCard card) => max(15, 30 + card.power);

const Duration kDailyDropCooldown = Duration(hours: 24);

class DailyDropStatus {
  const DailyDropStatus(this.ready, this.remaining);

  final bool ready;
  final Duration remaining;
}

DailyDropStatus dailyDropStatus(DateTime? lastClaimedAt, [DateTime? now]) {
  if (lastClaimedAt == null) return const DailyDropStatus(true, Duration.zero);
  final elapsed = (now ?? DateTime.now()).difference(lastClaimedAt);
  final remaining = kDailyDropCooldown - elapsed;
  if (remaining <= Duration.zero) {
    return const DailyDropStatus(true, Duration.zero);
  }
  return DailyDropStatus(false, remaining);
}

String formatCountdown(Duration duration) {
  final totalMinutes =
      duration.inMinutes + (duration.inSeconds % 60 > 0 ? 1 : 0);
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return hours <= 0 ? '${minutes}m' : '${hours}h ${minutes}m';
}

int coinsForResult(String result) {
  final normalized = result.toLowerCase();
  if (normalized == 'victory' || normalized == 'win') return 50;
  if (normalized == 'draw') return 25;
  return 10;
}

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
  const PlayerProgression({required this.totalXP});

  factory PlayerProgression.initial() => const PlayerProgression(totalXP: 0);

  factory PlayerProgression.fromJson(Map<String, dynamic> json) =>
      PlayerProgression(totalXP: json['totalXP'] as int? ?? 0);

  final int totalXP;

  int get playerLevel => levelFromXp(totalXP);
  int get xpIntoLevel => levelProgress(totalXP).intoLevel;
  int get xpToNextLevel => levelProgress(totalXP).levelSpan;
  int get xpRemainingToNextLevel => levelProgress(totalXP).toNextLevel;

  Map<String, dynamic> toJson() => {'totalXP': totalXP};

  // Apply XP delta and compute new level.
  // Returns the updated progression state and a list of levels newly crossed.
  // XP is never negative; losses floor at 0. No de-leveling occurs.
  ({PlayerProgression updated, List<int> levelsGained}) applyXP(int delta) {
    final oldLevel = playerLevel;
    final newTotal = max(0, totalXP + delta);
    final level = levelFromXp(newTotal);
    final gained = List<int>.generate(
      max(0, level - oldLevel),
      (i) => oldLevel + i + 1,
    );

    return (
      updated: PlayerProgression(totalXP: newTotal),
      levelsGained: gained,
    );
  }
}

class OpponentDeck {
  const OpponentDeck({
    required this.attackers,
    required this.defenders,
    required this.actions,
    required this.level,
  });

  final List<PlayerCard> attackers;
  final List<PlayerCard> defenders;
  final List<ActionCard> actions;
  final int level;
}

int targetRatingForLevel(int level) => min(95, 66 + level * 2);

double cpuSmartness(int level) => min(1.0, level / 12);

List<PlayerCard> _nearestByRating(
  List<PlayerCard> pool,
  int target,
  int count,
  Random random,
) {
  final sorted = [...pool]
    ..sort(
      (a, b) => (a.rating - target).abs().compareTo((b.rating - target).abs()),
    );
  final window = sorted.take(max(count * 2, count)).toList()..shuffle(random);
  return window.take(count).toList();
}

OpponentDeck generateOpponentDeck(
  int level,
  List<PlayerCard> attackerPool,
  List<PlayerCard> defenderPool,
  List<ActionCard> actionPool, {
  Random? random,
}) {
  final rng = random ?? Random();
  final target = targetRatingForLevel(level);
  final opponentAttackers = _nearestByRating(attackerPool, target, 2, rng);
  final opponentDefenders = _nearestByRating(defenderPool, target, 2, rng);
  final smartness = cpuSmartness(level);
  final byPower = [...actionPool]..sort((a, b) => b.power.compareTo(a.power));
  final remaining = [...actionPool];
  final picks = <ActionCard>[];

  for (var i = 0; i < 6 && remaining.isNotEmpty; i++) {
    final card = rng.nextDouble() < smartness
        ? byPower.firstWhere(remaining.contains, orElse: () => remaining.first)
        : remaining[rng.nextInt(remaining.length)];
    picks.add(card);
    remaining.remove(card);
  }

  return OpponentDeck(
    attackers: opponentAttackers,
    defenders: opponentDefenders,
    actions: picks,
    level: level,
  );
}

ActionCard chooseOpponentAction(
  List<ActionCard> available,
  int level, {
  Random? random,
}) {
  final rng = random ?? Random();
  if (available.length == 1 || rng.nextDouble() > cpuSmartness(level)) {
    return available[rng.nextInt(available.length)];
  }
  int score(ActionCard card) => card.power - (card.risky ? 4 : 0);
  return ([...available]..sort((a, b) => score(b).compareTo(score(a)))).first;
}

PlayerCard chooseOpponentPlayer(
  List<PlayerCard> available,
  int level, {
  Random? random,
}) {
  final rng = random ?? Random();
  if (available.length == 1 || rng.nextDouble() > cpuSmartness(level)) {
    return available[rng.nextInt(available.length)];
  }
  return ([...available]..sort((a, b) => b.rating.compareTo(a.rating))).first;
}
