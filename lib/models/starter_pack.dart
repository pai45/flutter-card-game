import 'dart:math';

import '../config/enums.dart';
import 'cards.dart';

/// Relative drop weights for the starter pack (55 : 35 : 4 : 1).
const starterPackTierWeights = {
  CardTier.bronze: 55,
  CardTier.silver: 35,
  CardTier.gold: 4,
  CardTier.platinum: 1,
};

/// Starter-pack drop weights on the unified [CardTier] scale (bronze → platinum).
///
/// Cards are bucketed by rating / action power, then each slot rolls a target
/// tier using [starterDropChance] before drawing from the position pool.
extension StarterPackTier on CardTier {
  /// Probability a single roll lands on this tier. Weights 55/35/4/1, normalized.
  double get starterDropChance =>
      starterPackTierWeights[this]! /
      starterPackTierWeights.values.reduce((a, b) => a + b);

  String get starterLabel => switch (this) {
    CardTier.platinum => 'Platinum',
    CardTier.gold => 'Gold',
    CardTier.silver => 'Silver',
    CardTier.bronze => 'Bronze',
  };
}

/// Tiers in descending drop order — used for weighted rolls and for
/// "nearest available tier" fallback searches.
const _tierByDropOrder = [
  CardTier.platinum,
  CardTier.gold,
  CardTier.silver,
  CardTier.bronze,
];

/// Maps a player's overall rating onto the starter-pack tier scale.
CardTier packRarityForRating(int rating) {
  if (rating >= 90) return CardTier.platinum;
  if (rating >= 86) return CardTier.gold;
  if (rating >= 80) return CardTier.silver;
  return CardTier.bronze;
}

/// Maps an action card's power onto the same scale.
CardTier packRarityForPower(int power) {
  if (power >= 22) return CardTier.platinum;
  if (power >= 16) return CardTier.gold;
  if (power >= 10) return CardTier.silver;
  return CardTier.bronze;
}

CardTier packRarityOfPlayer(PlayerCard card) => packRarityForRating(card.rating);

CardTier packRarityOfAction(ActionCard card) => packRarityForPower(card.power);

/// Rolls a target tier using the 55 / 35 / 4 / 1 weighting
/// (bronze / silver / gold / platinum).
CardTier rollPackRarity(Random random) {
  final roll = random.nextDouble();
  var cumulative = 0.0;
  for (final tier in _tierByDropOrder) {
    cumulative += tier.starterDropChance;
    if (roll < cumulative) return tier;
  }
  return CardTier.bronze;
}

/// Draws one card from [pool] whose tier matches a fresh rarity roll,
/// skipping anything already in [taken].
///
/// If no card of the rolled tier remains, it falls back to the nearest
/// available tier (by ordinal distance), so a draw never fails while any
/// card is left. Returns the picked card and records it in [taken].
T _drawByRarity<T>(
  List<T> pool,
  CardTier Function(T) rarityOf,
  Set<T> taken,
  Random random,
) {
  final available = pool.where((card) => !taken.contains(card)).toList();
  if (available.isEmpty) {
    throw StateError('Starter pack draw failed: pool exhausted.');
  }
  final target = rollPackRarity(random);
  // Smallest ordinal distance from the rolled tier that has stock.
  int distance(T card) => (rarityOf(card).index - target.index).abs();
  final minDistance = available.map(distance).reduce(min);
  final candidates = available
      .where((card) => distance(card) == minDistance)
      .toList();
  final pick = candidates[random.nextInt(candidates.length)];
  taken.add(pick);
  return pick;
}

// ─── Starter pack ────────────────────────────────────────────────────────────

/// A new user's starter pack: 2 strikers, 2 defenders, 1 keeper and a set of
/// action cards split between attack and defense.
class StarterPack {
  const StarterPack({
    required this.strikers,
    required this.defenders,
    required this.keeper,
    required this.attackActions,
    required this.defenseActions,
  });

  final List<PlayerCard> strikers; // 2
  final List<PlayerCard> defenders; // 2
  final PlayerCard keeper; // 1
  final List<ActionCard> attackActions;
  final List<ActionCard> defenseActions;

  List<PlayerCard> get players => [...strikers, ...defenders, keeper];
  List<ActionCard> get actions => [...attackActions, ...defenseActions];

  /// How many of each tier this pack contains (players + actions combined).
  Map<CardTier, int> get rarityBreakdown {
    final counts = {for (final tier in CardTier.values) tier: 0};
    for (final card in players) {
      final tier = packRarityOfPlayer(card);
      counts[tier] = counts[tier]! + 1;
    }
    for (final card in actions) {
      final tier = packRarityOfAction(card);
      counts[tier] = counts[tier]! + 1;
    }
    return counts;
  }
}

const starterPackStrikerCount = 2;
const starterPackDefenderCount = 2;
const starterPackKeeperCount = 1;
const starterPackActionCount = 5;

/// Rolls a random starter pack from the supplied pools.
///
/// Every card is chosen via [rollPackRarity] (bronze 55% / silver 35% / gold 4%
/// / platinum 1%) with no duplicates inside the pack. The [actionCount] action
/// cards are split as evenly as possible between attack and defense; when the
/// count is odd the heavier side (e.g. 3 attack + 2 defense, or vice-versa) is
/// chosen at random.
StarterPack rollStarterPack({
  required List<PlayerCard> strikerPool,
  required List<PlayerCard> defenderPool,
  required List<PlayerCard> keeperPool,
  required List<ActionCard> actionPool,
  int actionCount = starterPackActionCount,
  Random? random,
}) {
  final rng = random ?? Random();
  final takenPlayers = <PlayerCard>{};
  final takenActions = <ActionCard>{};

  final strikers = [
    for (var i = 0; i < starterPackStrikerCount; i++)
      _drawByRarity(strikerPool, packRarityOfPlayer, takenPlayers, rng),
  ];
  final defenders = [
    for (var i = 0; i < starterPackDefenderCount; i++)
      _drawByRarity(defenderPool, packRarityOfPlayer, takenPlayers, rng),
  ];
  final keeper = _drawByRarity(
    keeperPool,
    packRarityOfPlayer,
    takenPlayers,
    rng,
  );

  // Split as evenly as possible; an odd remainder goes to a random side.
  final half = actionCount ~/ 2;
  final attackCount = half + (actionCount.isOdd && rng.nextBool() ? 1 : 0);
  final defenseCount = actionCount - attackCount;
  final attackPool = actionPool
      .where((card) => card.category == ActionCategory.attack)
      .toList();
  final defensePool = actionPool
      .where((card) => card.category == ActionCategory.defense)
      .toList();

  final attackActions = [
    for (var i = 0; i < attackCount; i++)
      _drawByRarity(attackPool, packRarityOfAction, takenActions, rng),
  ];
  final defenseActions = [
    for (var i = 0; i < defenseCount; i++)
      _drawByRarity(defensePool, packRarityOfAction, takenActions, rng),
  ];

  return StarterPack(
    strikers: strikers,
    defenders: defenders,
    keeper: keeper,
    attackActions: attackActions,
    defenseActions: defenseActions,
  );
}

/// Rolls a starter pack from the game's built-in card pools.
StarterPack rollDefaultStarterPack({
  int actionCount = starterPackActionCount,
  Random? random,
}) => rollStarterPack(
  strikerPool: attackers,
  defenderPool: defenders,
  keeperPool: goalkeepers,
  actionPool: actionCards,
  actionCount: actionCount,
  random: random,
);

// ─── Match deck constraint ───────────────────────────────────────────────────

/// A deck taken into a match may hold at most this many cards.
const maxMatchDeckCards = 5;

/// Whether [count] is a legal match-deck size (1..5 cards).
bool isValidMatchDeckSize(int count) =>
    count >= 1 && count <= maxMatchDeckCards;

/// Whether another card may still be added to a match deck that currently
/// holds [currentCount] cards.
bool canAddToMatchDeck(int currentCount) => currentCount < maxMatchDeckCards;

/// Trims [cards] to the 5-card match-deck limit, preserving order.
List<T> enforceMatchDeckLimit<T>(List<T> cards) =>
    cards.take(maxMatchDeckCards).toList();
