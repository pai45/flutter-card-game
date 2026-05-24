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
    required this.cardCount,
    required this.guarantee,
    required this.accent,
    this.gradientAccent = false,
  });

  final String id;
  final String name;
  final int coinPrice;
  final int inrPrice;
  final int cardCount;
  final String guarantee;
  final Color accent;
  final bool gradientAccent;
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
  const ShopPackResult({
    required this.cardIds,
    required this.refund,
  });

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
    id: 'bronze',
    name: 'Bronze Pack',
    coinPrice: 2000,
    inrPrice: 50,
    cardCount: 5,
    guarantee: 'ALL COMMON / 5% RARE UPGRADE',
    accent: Color(0xffcd7f32),
  ),
  ShopPack(
    id: 'silver',
    name: 'Silver Pack',
    coinPrice: 8000,
    inrPrice: 150,
    cardCount: 5,
    guarantee: '1 RARE GUARANTEED / 10% EPIC',
    accent: Color(0xffc0c0c0),
  ),
  ShopPack(
    id: 'gold',
    name: 'Gold Pack',
    coinPrice: 20000,
    inrPrice: 400,
    cardCount: 5,
    guarantee: '1 EPIC GUARANTEED / 15% LEGENDARY',
    accent: Color(0xffffd700),
  ),
  ShopPack(
    id: 'icon',
    name: 'Icon Pack',
    coinPrice: 50000,
    inrPrice: 1000,
    cardCount: 5,
    guarantee: '1 LEGENDARY + 2 EPICS MINIMUM',
    accent: Color(0xffff3df7),
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
