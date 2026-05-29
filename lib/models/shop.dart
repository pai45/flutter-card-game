import 'package:flutter/material.dart';

import '../config/enums.dart';

class CoinTier {
  const CoinTier({
    required this.id,
    required this.name,
    required this.inrPrice,
    required this.coins,
    required this.bonusPercent,
    this.tag,
  });

  final String id;
  final String name;
  final int inrPrice;
  final int coins;
  final int bonusPercent;
  final String? tag;
}

class ShopPack {
  const ShopPack({
    required this.id,
    required this.name,
    required this.coinPrice,
    required this.inrPrice,
    required this.playerCount,
    required this.actionCount,
    required this.guarantee,
    required this.accent,
    required this.odds,
    this.gradientAccent = false,
  });

  final String id;
  final String name;
  final int coinPrice;
  final int inrPrice;
  final int playerCount;
  final int actionCount;
  final String guarantee;
  final Color accent;
  final Map<CardRarity, int> odds;
  final bool gradientAccent;

  int get cardCount => playerCount + actionCount;
}

class CardBackItem {
  const CardBackItem({
    required this.id,
    required this.name,
    required this.coinPrice,
    required this.inrPrice,
    required this.animated,
  });

  final String id;
  final String name;
  final int coinPrice;
  final int inrPrice;
  final bool animated;
}

class ShopPackResult {
  const ShopPackResult({required this.cardIds, required this.refund});

  final List<String> cardIds;
  final int refund;
}

const coinTiers = [
  CoinTier(
    id: 'rookie',
    name: 'Rookie',
    inrPrice: 10,
    coins: 1000,
    bonusPercent: 0,
  ),
  CoinTier(
    id: 'starter',
    name: 'Starter',
    inrPrice: 50,
    coins: 5500,
    bonusPercent: 10,
  ),
  CoinTier(
    id: 'pro',
    name: 'Pro',
    inrPrice: 100,
    coins: 12000,
    bonusPercent: 20,
    tag: 'POPULAR',
  ),
  CoinTier(
    id: 'elite',
    name: 'Elite',
    inrPrice: 250,
    coins: 32500,
    bonusPercent: 30,
  ),
  CoinTier(
    id: 'champion',
    name: 'Champion',
    inrPrice: 500,
    coins: 70000,
    bonusPercent: 40,
    tag: 'BEST VALUE',
  ),
  CoinTier(
    id: 'legendary',
    name: 'Legendary',
    inrPrice: 1000,
    coins: 150000,
    bonusPercent: 50,
    tag: 'MAX PACK',
  ),
];

const shopPacks = [
  ShopPack(
    id: 'starter',
    name: 'Starter Pack',
    coinPrice: 0,
    inrPrice: 0,
    playerCount: 5,
    actionCount: 6,
    guarantee: 'FREE SQUAD / 5 PLAYERS + 6 ACTIONS',
    accent: Color(0xff5cdfff),
    odds: {
      CardRarity.common: 70,
      CardRarity.rare: 25,
      CardRarity.epic: 5,
      CardRarity.legendary: 0,
    },
  ),
  ShopPack(
    id: 'bronze',
    name: 'Bronze Pack',
    coinPrice: 150,
    inrPrice: 50,
    playerCount: 1,
    actionCount: 2,
    guarantee: '3 CARDS / MOSTLY COMMONS',
    accent: Color(0xffcd7f32),
    odds: {
      CardRarity.common: 65,
      CardRarity.rare: 28,
      CardRarity.epic: 6,
      CardRarity.legendary: 1,
    },
  ),
  ShopPack(
    id: 'gold',
    name: 'Gold Pack',
    coinPrice: 400,
    inrPrice: 400,
    playerCount: 2,
    actionCount: 2,
    guarantee: '4 CARDS / RARE OR EPIC SHOT',
    accent: Color(0xffffd700),
    odds: {
      CardRarity.common: 35,
      CardRarity.rare: 45,
      CardRarity.epic: 16,
      CardRarity.legendary: 4,
    },
  ),
  ShopPack(
    id: 'elite',
    name: 'Elite Pack',
    coinPrice: 900,
    inrPrice: 1000,
    playerCount: 2,
    actionCount: 3,
    guarantee: '5 HIGH-END CARDS / BEST ODDS',
    accent: Color(0xffff3df7),
    odds: {
      CardRarity.common: 10,
      CardRarity.rare: 40,
      CardRarity.epic: 35,
      CardRarity.legendary: 15,
    },
    gradientAccent: true,
  ),
];

const cardBacks = [
  CardBackItem(
    id: 'default',
    name: 'Default',
    coinPrice: 0,
    inrPrice: 0,
    animated: false,
  ),
  CardBackItem(
    id: 'blue-grid',
    name: 'Blue Grid',
    coinPrice: 1000,
    inrPrice: 30,
    animated: false,
  ),
  CardBackItem(
    id: 'red-streak',
    name: 'Red Streak',
    coinPrice: 1000,
    inrPrice: 30,
    animated: false,
  ),
  CardBackItem(
    id: 'cyan-circuit',
    name: 'Cyan Circuit',
    coinPrice: 1000,
    inrPrice: 30,
    animated: false,
  ),
  CardBackItem(
    id: 'yellow-edge',
    name: 'Yellow Edge',
    coinPrice: 1000,
    inrPrice: 30,
    animated: false,
  ),
  CardBackItem(
    id: 'pulse-cyan',
    name: 'Pulse Cyan',
    coinPrice: 5000,
    inrPrice: 100,
    animated: true,
  ),
  CardBackItem(
    id: 'scan-blue',
    name: 'Scan Blue',
    coinPrice: 5000,
    inrPrice: 100,
    animated: true,
  ),
  CardBackItem(
    id: 'flux-green',
    name: 'Flux Green',
    coinPrice: 5000,
    inrPrice: 100,
    animated: true,
  ),
  CardBackItem(
    id: 'drift-violet',
    name: 'Drift Violet',
    coinPrice: 5000,
    inrPrice: 100,
    animated: true,
  ),
  CardBackItem(
    id: 'holo-foil',
    name: 'Holo Foil',
    coinPrice: 20000,
    inrPrice: 400,
    animated: true,
  ),
  CardBackItem(
    id: 'prism',
    name: 'Prism',
    coinPrice: 20000,
    inrPrice: 400,
    animated: true,
  ),
  CardBackItem(
    id: 'obsidian',
    name: 'Obsidian',
    coinPrice: 20000,
    inrPrice: 400,
    animated: true,
  ),
];

int duplicateRefund(CardRarity rarity) => switch (rarity) {
  CardRarity.common => 100,
  CardRarity.rare => 500,
  CardRarity.epic => 2000,
  CardRarity.legendary => 8000,
};

int rarityMultiplier(CardRarity rarity) => switch (rarity) {
  CardRarity.common => 1,
  CardRarity.rare => 3,
  CardRarity.epic => 8,
  CardRarity.legendary => 20,
};
