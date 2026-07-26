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

  /// Coin-pack art — `assets/coins/<id>.png`, smallest pile → largest by tier.
  String get imageAsset => 'assets/coins/$id.png';
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
  final Map<CardTier, int> odds;
  final bool gradientAccent;

  int get cardCount => playerCount + actionCount;

  /// Pack art, by convention `assets/packs/<id>.webp` (mirrors player portraits).
  /// Optional on disk — the shop paints a per-tier fallback until the image ships.
  String get artAsset => 'assets/packs/$id.webp';
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
      CardTier.bronze: 70,
      CardTier.silver: 25,
      CardTier.gold: 5,
      CardTier.platinum: 0,
    },
  ),
  ShopPack(
    id: 'bronze',
    name: 'Bronze Pack',
    coinPrice: 150,
    inrPrice: 50,
    playerCount: 1,
    actionCount: 2,
    guarantee: '3 CARDS / MOSTLY BRONZE',
    accent: Color(0xffcd7f32),
    odds: {
      CardTier.bronze: 65,
      CardTier.silver: 28,
      CardTier.gold: 6,
      CardTier.platinum: 1,
    },
  ),
  ShopPack(
    id: 'gold',
    name: 'Gold Pack',
    coinPrice: 400,
    inrPrice: 400,
    playerCount: 2,
    actionCount: 2,
    guarantee: '4 CARDS / SILVER OR GOLD SHOT',
    accent: Color(0xffffd700),
    odds: {
      CardTier.bronze: 35,
      CardTier.silver: 45,
      CardTier.gold: 16,
      CardTier.platinum: 4,
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
      CardTier.bronze: 10,
      CardTier.silver: 40,
      CardTier.gold: 35,
      CardTier.platinum: 15,
    },
    gradientAccent: true,
  ),
];

const racingShopPacks = [
  ShopPack(
    id: 'racing-grid',
    name: 'Grid Pack',
    coinPrice: 150,
    inrPrice: 50,
    playerCount: 1,
    actionCount: 0,
    guarantee: '1 DRIVER / MOSTLY BRONZE',
    accent: Color(0xff35e7ff),
    odds: {
      CardTier.bronze: 65,
      CardTier.silver: 28,
      CardTier.gold: 6,
      CardTier.platinum: 1,
    },
  ),
  ShopPack(
    id: 'racing-podium',
    name: 'Podium Pack',
    coinPrice: 400,
    inrPrice: 400,
    playerCount: 2,
    actionCount: 0,
    guarantee: '2 DRIVERS / SILVER OR GOLD SHOT',
    accent: Color(0xffff3df7),
    odds: {
      CardTier.bronze: 35,
      CardTier.silver: 45,
      CardTier.gold: 16,
      CardTier.platinum: 4,
    },
  ),
  ShopPack(
    id: 'racing-pole',
    name: 'Pole Pack',
    coinPrice: 900,
    inrPrice: 1000,
    playerCount: 3,
    actionCount: 0,
    guarantee: '3 DRIVERS / BEST PLATINUM ODDS',
    accent: Color(0xffffd700),
    odds: {
      CardTier.bronze: 10,
      CardTier.silver: 40,
      CardTier.gold: 35,
      CardTier.platinum: 15,
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

int duplicateRefund(CardTier tier) => switch (tier) {
  CardTier.bronze => 100,
  CardTier.silver => 500,
  CardTier.gold => 2000,
  CardTier.platinum => 8000,
};

int tierMultiplier(CardTier tier) => switch (tier) {
  CardTier.bronze => 1,
  CardTier.silver => 3,
  CardTier.gold => 8,
  CardTier.platinum => 20,
};
