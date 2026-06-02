import 'dart:math';

import '../config/enums.dart';
import 'cards.dart';

/// Unified four-tier rarity scale used when rolling a starter pack.
///
/// The game's cards are authored with [CardTier] (bronze/silver/gold/platinum),
/// which does not by itself match the silver/gold/epic/legendary odds we want
/// for pack drops. This enum is the single scale the roller reasons about;
/// [packRarityForRating] / [packRarityForPower] project existing cards onto it.
enum PackRarity { silver, gold, epic, legendary }

extension PackRarityInfo on PackRarity {
  /// Probability a single roll lands on this rarity. The four values sum to 1.
  double get dropChance => switch (this) {
    PackRarity.legendary => 0.05,
    PackRarity.epic => 0.10,
    PackRarity.gold => 0.35,
    PackRarity.silver => 0.50,
  };

  String get label => switch (this) {
    PackRarity.legendary => 'Legendary',
    PackRarity.epic => 'Epic',
    PackRarity.gold => 'Gold',
    PackRarity.silver => 'Silver',
  };
}

/// Rarity buckets in descending drop order — useful for weighted rolls and for
/// "nearest available rarity" fallback searches.
const _rarityByDropOrder = [
  PackRarity.legendary,
  PackRarity.epic,
  PackRarity.gold,
  PackRarity.silver,
];

/// Maps a player's overall rating onto the pack-rarity scale.
PackRarity packRarityForRating(int rating) {
  if (rating >= 90) return PackRarity.legendary;
  if (rating >= 86) return PackRarity.epic;
  if (rating >= 80) return PackRarity.gold;
  return PackRarity.silver;
}

/// Maps an action card's power onto the same scale.
PackRarity packRarityForPower(int power) {
  if (power >= 22) return PackRarity.legendary;
  if (power >= 16) return PackRarity.epic;
  if (power >= 10) return PackRarity.gold;
  return PackRarity.silver;
}

PackRarity packRarityOfPlayer(PlayerCard card) =>
    packRarityForRating(card.rating);

PackRarity packRarityOfAction(ActionCard card) =>
    packRarityForPower(card.power);

/// Rolls a target rarity using the 50 / 35 / 10 / 5 weighting
/// (silver / gold / epic / legendary).
PackRarity rollPackRarity(Random random) {
  final roll = random.nextDouble();
  var cumulative = 0.0;
  for (final rarity in _rarityByDropOrder) {
    cumulative += rarity.dropChance;
    if (roll < cumulative) return rarity;
  }
  return PackRarity.silver;
}

/// Draws one card from [pool] whose rarity matches a fresh rarity roll,
/// skipping anything already in [taken].
///
/// If no card of the rolled rarity remains, it falls back to the nearest
/// available rarity (by ordinal distance), so a draw never fails while any
/// card is left. Returns the picked card and records it in [taken].
T _drawByRarity<T>(
  List<T> pool,
  PackRarity Function(T) rarityOf,
  Set<T> taken,
  Random random,
) {
  final available = pool.where((card) => !taken.contains(card)).toList();
  if (available.isEmpty) {
    throw StateError('Starter pack draw failed: pool exhausted.');
  }
  final target = rollPackRarity(random);
  // Smallest ordinal distance from the rolled rarity that has stock.
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

  /// How many of each rarity this pack contains (players + actions combined).
  Map<PackRarity, int> get rarityBreakdown {
    final counts = {for (final rarity in PackRarity.values) rarity: 0};
    for (final card in players) {
      final rarity = packRarityOfPlayer(card);
      counts[rarity] = counts[rarity]! + 1;
    }
    for (final card in actions) {
      final rarity = packRarityOfAction(card);
      counts[rarity] = counts[rarity]! + 1;
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
/// Every card is chosen via [rollPackRarity] (silver 50% / gold 35% / epic 10%
/// / legendary 5%) with no duplicates inside the pack. The [actionCount] action
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
