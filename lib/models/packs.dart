import 'dart:math';

import '../config/enums.dart';
import 'cards.dart';
import 'progression.dart';
import 'starter_pack.dart';

/// Number of action cards bundled into the auto-built starter deck. The deck
/// format requires 6, so the starter pack rolls 6 here even though a freshly
/// rolled [StarterPack] defaults to 5.
const starterDeckActionCount = 6;
const cricketStarterCardCount = 3;
const basketballStarterCardCount = 3;
const tennisStarterCardCount = 1;
const grandPrixStarterCardCount = 1;

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
  final Map<CardTier, int> odds;

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
      CardTier.bronze: 70,
      CardTier.silver: 25,
      CardTier.gold: 5,
      CardTier.platinum: 0,
    },
  ),
  CardPack(
    id: 'bronze',
    name: 'Bronze Pack',
    description: '3 cards. Mostly bronze, slim shot at better.',
    price: 150,
    playerCount: 1,
    actionCount: 2,
    odds: {
      CardTier.bronze: 65,
      CardTier.silver: 28,
      CardTier.gold: 6,
      CardTier.platinum: 1,
    },
  ),
  CardPack(
    id: 'gold',
    name: 'Gold Pack',
    description: '4 cards with a good shot at a silver or gold.',
    price: 400,
    playerCount: 2,
    actionCount: 2,
    odds: {
      CardTier.bronze: 35,
      CardTier.silver: 45,
      CardTier.gold: 16,
      CardTier.platinum: 4,
    },
  ),
  CardPack(
    id: 'elite',
    name: 'Elite Pack',
    description: '5 high-end cards. Best platinum odds.',
    price: 900,
    playerCount: 2,
    actionCount: 3,
    odds: {
      CardTier.bronze: 10,
      CardTier.silver: 40,
      CardTier.gold: 35,
      CardTier.platinum: 15,
    },
  ),
];

const kDailyDropOdds = {
  CardTier.bronze: 40,
  CardTier.silver: 40,
  CardTier.gold: 16,
  CardTier.platinum: 4,
};

const kRacingPackIds = {'racing-grid', 'racing-podium', 'racing-pole'};

const kRacingPacks = [
  CardPack(
    id: 'racing-grid',
    name: 'Grid Pack',
    description: '1 driver card — mostly bronze grid talent.',
    price: 150,
    playerCount: 1,
    actionCount: 0,
    odds: {
      CardTier.bronze: 65,
      CardTier.silver: 28,
      CardTier.gold: 6,
      CardTier.platinum: 1,
    },
  ),
  CardPack(
    id: 'racing-podium',
    name: 'Podium Pack',
    description: '2 driver cards with a silver or gold shot.',
    price: 400,
    playerCount: 2,
    actionCount: 0,
    odds: {
      CardTier.bronze: 35,
      CardTier.silver: 45,
      CardTier.gold: 16,
      CardTier.platinum: 4,
    },
  ),
  CardPack(
    id: 'racing-pole',
    name: 'Pole Pack',
    description: '3 high-end drivers — best platinum odds.',
    price: 900,
    playerCount: 3,
    actionCount: 0,
    odds: {
      CardTier.bronze: 10,
      CardTier.silver: 40,
      CardTier.gold: 35,
      CardTier.platinum: 15,
    },
  ),
];

CardPack? getProgressionPack(String id) =>
    kProgressionPacks.where((pack) => pack.id == id).firstOrNull ??
    kRacingPacks.where((pack) => pack.id == id).firstOrNull;

/// Builds a new user's starter pack: a random, rarity-weighted roll of
/// 2 strikers, 2 defenders, 1 keeper and [starterDeckActionCount] action cards.
///
/// Rarity follows the pack odds (bronze 55% / silver 35% / gold 4% /
/// platinum 1%) — see [rollStarterPack]. [keeperPool] defaults to the game's
/// goalkeepers so the existing call sites (which pass attackers/defenders/
/// actions positionally) keep working.
PackResult buildStarterPack(
  List<PlayerCard> attackerPool,
  List<PlayerCard> defenderPool,
  List<ActionCard> actionPool, {
  List<PlayerCard> keeperPool = goalkeepers,
  Random? random,
}) {
  final pack = rollStarterPack(
    strikerPool: attackerPool,
    defenderPool: defenderPool,
    keeperPool: keeperPool,
    actionPool: actionPool,
    actionCount: starterDeckActionCount,
    random: random,
  );
  return _finalize(pack.players, pack.actions);
}

/// Final Over hands out 3 bronze batsmen — always bronze, mirroring Tennis
/// Rally's [buildTennisStarterPack] rule (the ladder above bronze is meant
/// to be earned in-game), since this is the batsman roster's only starter
/// pack now that Super Over has been retired.
PackResult buildCricketStarterPack(
  List<PlayerCard> battingPool, {
  Random? random,
}) {
  final rng = random ?? Random();
  final available = battingPool
      .where((card) => card.tier == CardTier.bronze)
      .toList();
  if (available.isEmpty) {
    throw StateError('Cricket starter pack draw failed: no bronze batsmen.');
  }
  final players = <PlayerCard>[];
  for (var i = 0; i < cricketStarterCardCount && available.isNotEmpty; i++) {
    players.add(available.removeAt(rng.nextInt(available.length)));
  }
  return _finalize(players, const []);
}

PackResult buildBasketballStarterPack(
  List<PlayerCard> basketballPool, {
  Random? random,
}) {
  final rng = random ?? Random();
  final players = <PlayerCard>[];
  final roles = [
    PlayerRole.basketballGuard,
    PlayerRole.basketballWing,
    PlayerRole.basketballBig,
  ];
  for (final role in roles) {
    final available = basketballPool
        .where(
          (card) =>
              card.role == role &&
              card.tier != CardTier.platinum &&
              !players.any((picked) => picked.id == card.id),
        )
        .toList();
    final card = _rollFrom<PlayerCard>(
      available,
      (card) => card.tier,
      kProgressionPacks.first.odds,
      rng,
    );
    if (card != null) players.add(card);
  }
  return _finalize(players, const []);
}

/// Tennis Rally hands out a single card, and it is always bronze — the ladder
/// above bronze is meant to be earned in-game, so this deliberately skips the
/// weighted [_rollFrom] roll the other sports use.
PackResult buildTennisStarterPack(
  List<PlayerCard> tennisPool, {
  Random? random,
}) {
  final rng = random ?? Random();
  final bronze = tennisPool
      .where((card) => card.tier == CardTier.bronze)
      .toList();
  if (bronze.isEmpty) {
    throw StateError('Tennis starter pack draw failed: no bronze players.');
  }
  return _finalize([bronze[rng.nextInt(bronze.length)]], const []);
}

/// Grand Prix Dash hands out one driver, always bronze — same earn-the-ladder
/// rule as [buildTennisStarterPack]. Pool is the full motorsport roster (F1,
/// F2, NASCAR, IndyCar).
PackResult buildGrandPrixStarterPack(
  List<PlayerCard> racingPool, {
  Random? random,
}) {
  final rng = random ?? Random();
  final bronze = racingPool
      .where((card) => card.tier == CardTier.bronze)
      .toList();
  if (bronze.isEmpty) {
    throw StateError(
      'Grand Prix starter pack draw failed: no bronze drivers.',
    );
  }
  return _finalize([bronze[rng.nextInt(bronze.length)]], const []);
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
      (card) => card.tier,
      pack.odds,
      rng,
    );
    if (card != null) players.add(card);
  }
  for (var i = 0; i < pack.actionCount; i++) {
    final card = _rollFrom<ActionCard>(
      actionPool,
      (card) => card.tier,
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
      (card) => card.tier,
      kDailyDropOdds,
      rng,
    );
    return _finalize(card == null ? const [] : [card], const []);
  }
  final card = _rollFrom<ActionCard>(
    actionPool,
    (card) => card.tier,
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

CardTier _pickWeighted(Map<CardTier, int> odds, Random random) {
  final total = odds.values.fold<int>(0, (sum, weight) => sum + weight);
  var roll = random.nextDouble() * total;
  for (final entry in odds.entries) {
    roll -= entry.value;
    if (roll <= 0) return entry.key;
  }
  return CardTier.bronze;
}

T? _rollFrom<T>(
  List<T> pool,
  CardTier Function(T item) tierOf,
  Map<CardTier, int> odds,
  Random random,
) {
  if (pool.isEmpty) return null;
  final wanted = _pickWeighted(odds, random);
  for (final tier in [
    wanted,
    CardTier.platinum,
    CardTier.gold,
    CardTier.silver,
    CardTier.bronze,
  ]) {
    final matches = pool.where((item) => tierOf(item) == tier).toList();
    if (matches.isNotEmpty) return matches[random.nextInt(matches.length)];
  }
  return pool[random.nextInt(pool.length)];
}
