import 'package:flutter/material.dart';

import '../config/enums.dart';

/// A snapshot of every value the achievement catalog measures, built once from
/// the live game / prediction / picks state. Plain data — no bloc imports — so
/// the catalog stays pure and easy to read.
class AchievementStats {
  const AchievementStats({
    required this.level,
    required this.totalXP,
    required this.matchesPlayed,
    required this.matchWins,
    required this.bestMatchStreak,
    required this.cleanSheets,
    required this.shootoutWins,
    required this.basketballWins,
    required this.predictionsMade,
    required this.correctPredictions,
    required this.picksPlaced,
    required this.picksWon,
    required this.pickStreak,
    required this.pickProfit,
    required this.ownedCards,
    required this.platinumOwned,
    required this.coins,
  });

  const AchievementStats.empty()
    : level = 1,
      totalXP = 0,
      matchesPlayed = 0,
      matchWins = 0,
      bestMatchStreak = 0,
      cleanSheets = 0,
      shootoutWins = 0,
      basketballWins = 0,
      predictionsMade = 0,
      correctPredictions = 0,
      picksPlaced = 0,
      picksWon = 0,
      pickStreak = 0,
      pickProfit = 0,
      ownedCards = 0,
      platinumOwned = 0,
      coins = 0;

  final int level;
  final int totalXP;
  final int matchesPlayed;
  final int matchWins;
  final int bestMatchStreak;
  final int cleanSheets;
  final int shootoutWins;
  final int basketballWins;
  final int predictionsMade;
  final int correctPredictions;
  final int picksPlaced;
  final int picksWon;
  final int pickStreak;
  final int pickProfit;
  final int ownedCards;
  final int platinumOwned;
  final int coins;
}

enum AchievementCategory { matches, progression, predictions, picks, collection }

/// The three tabs the full achievements page groups badges under. Categories
/// fold into tabs: predictions → prediction, picks → picks, and everything
/// about the card game itself (matches, progression, collection) → games.
enum AchievementTab { prediction, picks, games }

extension AchievementTabLabel on AchievementTab {
  String get label => switch (this) {
    AchievementTab.prediction => 'PREDICTION',
    AchievementTab.picks => 'PICKS',
    AchievementTab.games => 'GAMES',
  };
}

/// One earnable badge. Unlock state and progress are derived live from
/// [AchievementStats] via [measure] — there is no stored "unlocked" flag.
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.tier,
    required this.category,
    required this.target,
    required this.measure,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;

  /// Drives the badge colour (bronze → platinum), grading difficulty.
  final CardTier tier;
  final AchievementCategory category;
  final int target;

  /// Current progress value for this achievement, given the player's stats.
  final int Function(AchievementStats) measure;

  int current(AchievementStats s) => measure(s).clamp(0, target);
  bool unlocked(AchievementStats s) => measure(s) >= target;
  double progress(AchievementStats s) =>
      target == 0 ? 0 : (measure(s) / target).clamp(0.0, 1.0);

  AchievementTab get tab => switch (category) {
    AchievementCategory.predictions => AchievementTab.prediction,
    AchievementCategory.picks => AchievementTab.picks,
    AchievementCategory.matches ||
    AchievementCategory.progression ||
    AchievementCategory.collection => AchievementTab.games,
  };
}

/// The full catalogue. Ordered roughly easy → hard within each category so the
/// grid reads as a progression. `final` (not `const`) so measures can be inline
/// closures.
final List<Achievement> achievementCatalog = [
  // ── Matches ───────────────────────────────────────────────────────────────
  Achievement(
    id: 'first_blood',
    title: 'First Blood',
    description: 'Win your first card match.',
    icon: Icons.sports_soccer,
    tier: CardTier.bronze,
    category: AchievementCategory.matches,
    target: 1,
    measure: (s) => s.matchWins,
  ),
  Achievement(
    id: 'hat_trick',
    title: 'Hat-Trick Hero',
    description: 'Win 3 matches.',
    icon: Icons.military_tech,
    tier: CardTier.bronze,
    category: AchievementCategory.matches,
    target: 3,
    measure: (s) => s.matchWins,
  ),
  Achievement(
    id: 'on_fire',
    title: 'On Fire',
    description: 'Reach a 3-match win streak.',
    icon: Icons.local_fire_department,
    tier: CardTier.silver,
    category: AchievementCategory.matches,
    target: 3,
    measure: (s) => s.bestMatchStreak,
  ),
  Achievement(
    id: 'clean_sheet',
    title: 'Clean Sheet',
    description: 'Win a match without conceding.',
    icon: Icons.verified_user,
    tier: CardTier.silver,
    category: AchievementCategory.matches,
    target: 1,
    measure: (s) => s.cleanSheets,
  ),
  Achievement(
    id: 'shootout_ace',
    title: 'Shootout Ace',
    description: 'Win a penalty shootout.',
    icon: Icons.gps_fixed,
    tier: CardTier.silver,
    category: AchievementCategory.matches,
    target: 1,
    measure: (s) => s.shootoutWins,
  ),
  Achievement(
    id: 'first_bucket',
    title: 'First Bucket',
    description: 'Win a Hoop Duel match.',
    icon: Icons.sports_basketball,
    tier: CardTier.silver,
    category: AchievementCategory.matches,
    target: 1,
    measure: (s) => s.basketballWins,
  ),
  Achievement(
    id: 'court_king',
    title: 'Court King',
    description: 'Win 5 Hoop Duel matches.',
    icon: Icons.emoji_events,
    tier: CardTier.gold,
    category: AchievementCategory.matches,
    target: 5,
    measure: (s) => s.basketballWins,
  ),
  Achievement(
    id: 'veteran',
    title: 'Veteran',
    description: 'Play 10 matches.',
    icon: Icons.stadium,
    tier: CardTier.silver,
    category: AchievementCategory.matches,
    target: 10,
    measure: (s) => s.matchesPlayed,
  ),
  Achievement(
    id: 'unstoppable',
    title: 'Unstoppable',
    description: 'Reach a 5-match win streak.',
    icon: Icons.whatshot,
    tier: CardTier.gold,
    category: AchievementCategory.matches,
    target: 5,
    measure: (s) => s.bestMatchStreak,
  ),
  Achievement(
    id: 'centurion',
    title: 'Centurion',
    description: 'Play 50 matches.',
    icon: Icons.workspace_premium,
    tier: CardTier.gold,
    category: AchievementCategory.matches,
    target: 50,
    measure: (s) => s.matchesPlayed,
  ),

  // ── Progression ───────────────────────────────────────────────────────────
  Achievement(
    id: 'rising_star',
    title: 'Rising Star',
    description: 'Reach level 5.',
    icon: Icons.star,
    tier: CardTier.bronze,
    category: AchievementCategory.progression,
    target: 5,
    measure: (s) => s.level,
  ),
  Achievement(
    id: 'pro',
    title: 'Pro',
    description: 'Reach level 10.',
    icon: Icons.auto_awesome,
    tier: CardTier.silver,
    category: AchievementCategory.progression,
    target: 10,
    measure: (s) => s.level,
  ),
  Achievement(
    id: 'legend',
    title: 'Legend',
    description: 'Reach level 25.',
    icon: Icons.emoji_events,
    tier: CardTier.platinum,
    category: AchievementCategory.progression,
    target: 25,
    measure: (s) => s.level,
  ),

  // ── Predictions ───────────────────────────────────────────────────────────
  Achievement(
    id: 'first_prediction',
    title: 'First Call',
    description: 'Complete your first match quiz.',
    icon: Icons.lightbulb,
    tier: CardTier.bronze,
    category: AchievementCategory.predictions,
    target: 1,
    measure: (s) => s.predictionsMade,
  ),
  Achievement(
    id: 'analyst',
    title: 'Analyst',
    description: 'Complete 10 match quizzes.',
    icon: Icons.insights,
    tier: CardTier.silver,
    category: AchievementCategory.predictions,
    target: 10,
    measure: (s) => s.predictionsMade,
  ),
  Achievement(
    id: 'sharp_eye',
    title: 'Sharp Eye',
    description: 'Get 10 predictions right.',
    icon: Icons.visibility,
    tier: CardTier.silver,
    category: AchievementCategory.predictions,
    target: 10,
    measure: (s) => s.correctPredictions,
  ),

  // ── Picks ─────────────────────────────────────────────────────────────────
  Achievement(
    id: 'first_position',
    title: 'First Position',
    description: 'Place your first pick.',
    icon: Icons.trending_up,
    tier: CardTier.bronze,
    category: AchievementCategory.picks,
    target: 1,
    measure: (s) => s.picksPlaced,
  ),
  Achievement(
    id: 'market_mover',
    title: 'Market Mover',
    description: 'Win 5 picks.',
    icon: Icons.show_chart,
    tier: CardTier.silver,
    category: AchievementCategory.picks,
    target: 5,
    measure: (s) => s.picksWon,
  ),
  Achievement(
    id: 'hot_hand',
    title: 'Hot Hand',
    description: 'Hit a 3-pick win streak.',
    icon: Icons.bolt,
    tier: CardTier.gold,
    category: AchievementCategory.picks,
    target: 3,
    measure: (s) => s.pickStreak,
  ),
  Achievement(
    id: 'in_profit',
    title: 'In Profit',
    description: 'Finish in net pick profit.',
    icon: Icons.savings,
    tier: CardTier.silver,
    category: AchievementCategory.picks,
    target: 1,
    measure: (s) => s.pickProfit > 0 ? 1 : 0,
  ),

  // ── Collection ────────────────────────────────────────────────────────────
  Achievement(
    id: 'collector',
    title: 'Collector',
    description: 'Own 25 cards.',
    icon: Icons.collections_bookmark,
    tier: CardTier.bronze,
    category: AchievementCategory.collection,
    target: 25,
    measure: (s) => s.ownedCards,
  ),
  Achievement(
    id: 'platinum_pull',
    title: 'Platinum Pull',
    description: 'Own a platinum-tier card.',
    icon: Icons.diamond,
    tier: CardTier.platinum,
    category: AchievementCategory.collection,
    target: 1,
    measure: (s) => s.platinumOwned,
  ),
  Achievement(
    id: 'treasury',
    title: 'Treasury',
    description: 'Hold 1,000 coins at once.',
    icon: Icons.paid,
    tier: CardTier.gold,
    category: AchievementCategory.collection,
    target: 1000,
    measure: (s) => s.coins,
  ),
];

/// How many catalogue badges are unlocked for [stats].
int unlockedAchievementCount(AchievementStats stats) =>
    achievementCatalog.where((a) => a.unlocked(stats)).length;

/// All badges belonging to [tab], in catalogue order.
List<Achievement> achievementsForTab(AchievementTab tab) =>
    achievementCatalog.where((a) => a.tab == tab).toList();

/// How many badges in [tab] are unlocked for [stats].
int unlockedAchievementCountForTab(AchievementStats stats, AchievementTab tab) =>
    achievementsForTab(tab).where((a) => a.unlocked(stats)).length;

/// The ids of every catalogue badge currently unlocked for [stats]. Used by the
/// celebration watcher to snapshot what the player has already earned.
Set<String> unlockedAchievementIds(AchievementStats stats) =>
    achievementCatalog.where((a) => a.unlocked(stats)).map((a) => a.id).toSet();

/// Badges that are unlocked for [stats] but whose ids are not in
/// [alreadyCelebrated] — i.e. the ones that just crossed their threshold and
/// deserve an "ACHIEVEMENT UNLOCKED" moment. Catalogue order is preserved so a
/// multi-unlock reveal plays easy → hard.
List<Achievement> newlyUnlockedAchievements(
  Set<String> alreadyCelebrated,
  AchievementStats stats,
) => achievementCatalog
    .where((a) => a.unlocked(stats) && !alreadyCelebrated.contains(a.id))
    .toList();
