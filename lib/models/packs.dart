import 'dart:math';

import '../config/enums.dart';
import 'cards.dart';
import 'progression.dart';

class CardPack {
  const CardPack({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.playerCount,
    required this.actionCount,
    required this.odds,
  });

  final String id;
  final String name;
  final String description;
  final int price;
  final int playerCount;
  final int actionCount;
  final Map<CardRarity, int> odds;

  int get cardCount => playerCount + actionCount;
}

class PackResult {
  const PackResult({
    required this.playerCards,
    required this.actionCards,
    required this.xpGained,
  });

  final List<PlayerCard> playerCards;
  final List<ActionCard> actionCards;
  final int xpGained;

  int get cardCount => playerCards.length + actionCards.length;
}

const starterPackId = 'starter';

const kProgressionPacks = [
  CardPack(
    id: starterPackId,
    name: 'Starter Pack',
    description: 'Your first squad - enough to field a legal deck.',
    price: 0,
    playerCount: 5,
    actionCount: 6,
    odds: {
      CardRarity.common: 70,
      CardRarity.rare: 25,
      CardRarity.epic: 5,
      CardRarity.legendary: 0,
    },
  ),
  CardPack(
    id: 'bronze',
    name: 'Bronze Pack',
    description: '3 cards. Mostly commons, slim shot at better.',
    price: 150,
    playerCount: 1,
    actionCount: 2,
    odds: {
      CardRarity.common: 65,
      CardRarity.rare: 28,
      CardRarity.epic: 6,
      CardRarity.legendary: 1,
    },
  ),
  CardPack(
    id: 'gold',
    name: 'Gold Pack',
    description: '4 cards with a good shot at a rare or epic.',
    price: 400,
    playerCount: 2,
    actionCount: 2,
    odds: {
      CardRarity.common: 35,
      CardRarity.rare: 45,
      CardRarity.epic: 16,
      CardRarity.legendary: 4,
    },
  ),
  CardPack(
    id: 'elite',
    name: 'Elite Pack',
    description: '5 high-end cards. Best legendary odds.',
    price: 900,
    playerCount: 2,
    actionCount: 3,
    odds: {
      CardRarity.common: 10,
      CardRarity.rare: 40,
      CardRarity.epic: 35,
      CardRarity.legendary: 15,
    },
  ),
];

const kDailyDropOdds = {
  CardRarity.common: 40,
  CardRarity.rare: 40,
  CardRarity.epic: 16,
  CardRarity.legendary: 4,
};

CardPack? getProgressionPack(String id) =>
    kProgressionPacks.where((pack) => pack.id == id).firstOrNull;

PackResult buildStarterPack(
  List<PlayerCard> attackerPool,
  List<PlayerCard> defenderPool,
  List<ActionCard> actionPool,
) {
  final starterAttackers = attackerPool.take(3).toList();
  final starterDefenders = defenderPool.take(2).toList();
  final starterActions = actionPool.take(6).toList();
  return _finalize([...starterAttackers, ...starterDefenders], starterActions);
}

PackResult rollPack(
  CardPack pack,
  List<PlayerCard> playerPool,
  List<ActionCard> actionPool, {
  Random? random,
}) {
  final rng = random ?? Random();
  final players = <PlayerCard>[];
  final actions = <ActionCard>[];
  for (var i = 0; i < pack.playerCount; i++) {
    final card = _rollFrom<PlayerCard>(
      playerPool,
      (card) => playerRarity(card.rating),
      pack.odds,
      rng,
    );
    if (card != null) players.add(card);
  }
  for (var i = 0; i < pack.actionCount; i++) {
    final card = _rollFrom<ActionCard>(
      actionPool,
      (card) => actionRarity(card.power),
      pack.odds,
      rng,
    );
    if (card != null) actions.add(card);
  }
  return _finalize(players, actions);
}

PackResult rollDailyDrop(
  List<PlayerCard> playerPool,
  List<ActionCard> actionPool, {
  Random? random,
}) {
  final rng = random ?? Random();
  if (rng.nextBool()) {
    final card = _rollFrom<PlayerCard>(
      playerPool,
      (card) => playerRarity(card.rating),
      kDailyDropOdds,
      rng,
    );
    return _finalize(card == null ? const [] : [card], const []);
  }
  final card = _rollFrom<ActionCard>(
    actionPool,
    (card) => actionRarity(card.power),
    kDailyDropOdds,
    rng,
  );
  return _finalize(const [], card == null ? const [] : [card]);
}

PackResult singlePlayerUnlock(PlayerCard card) => _finalize([card], const []);

PackResult singleActionUnlock(ActionCard card) => _finalize(const [], [card]);

PackResult _finalize(List<PlayerCard> players, List<ActionCard> actions) {
  final xp =
      players.fold<int>(0, (sum, card) => sum + playerCardXp(card)) +
      actions.fold<int>(0, (sum, card) => sum + actionCardXp(card));
  return PackResult(playerCards: players, actionCards: actions, xpGained: xp);
}

CardRarity _pickWeighted(Map<CardRarity, int> odds, Random random) {
  final total = odds.values.fold<int>(0, (sum, weight) => sum + weight);
  var roll = random.nextDouble() * total;
  for (final entry in odds.entries) {
    roll -= entry.value;
    if (roll <= 0) return entry.key;
  }
  return CardRarity.common;
}

T? _rollFrom<T>(
  List<T> pool,
  CardRarity Function(T item) rarityOf,
  Map<CardRarity, int> odds,
  Random random,
) {
  if (pool.isEmpty) return null;
  final wanted = _pickWeighted(odds, random);
  for (final rarity in [
    wanted,
    CardRarity.legendary,
    CardRarity.epic,
    CardRarity.rare,
    CardRarity.common,
  ]) {
    final matches = pool.where((item) => rarityOf(item) == rarity).toList();
    if (matches.isNotEmpty) return matches[random.nextInt(matches.length)];
  }
  return pool[random.nextInt(pool.length)];
}
