import '../../models/cards.dart';
import '../../models/deck.dart';
import '../../models/oz_coin_ledger.dart';
import '../../models/streak.dart';
import '../../models/super_over.dart';
import '../../models/sport_match.dart';
import '../../models/xp_ledger.dart';

sealed class GameEvent {}

class GameLoaded extends GameEvent {}

class DeckSaved extends GameEvent {
  DeckSaved(this.slot);
  final StoredDeckSlot slot;
}

class DeckApplied extends GameEvent {
  DeckApplied(this.slotId);
  final String slotId;
}

class DeckCreated extends GameEvent {}

class TutorialReset extends GameEvent {}

class TutorialSeenMarked extends GameEvent {
  TutorialSeenMarked(this.keyName);
  final String keyName;
}

class TutorialsSkippedAll extends GameEvent {}

class OwnedCardAdded extends GameEvent {
  OwnedCardAdded(this.cardId);
  final String cardId;
}

class CoinsAdded extends GameEvent {
  CoinsAdded(
    this.amount, {
    this.source = OzCoinTransactionSource.manual,
    this.type,
    this.title,
    this.subtitle,
  });

  final int amount;
  final OzCoinTransactionSource source;
  final OzCoinTransactionType? type;
  final String? title;
  final String? subtitle;
}

class CoinsSpent extends GameEvent {
  CoinsSpent(
    this.amount, {
    this.source = OzCoinTransactionSource.manual,
    this.type,
    this.title,
    this.subtitle,
  });

  final int amount;
  final OzCoinTransactionSource source;
  final OzCoinTransactionType? type;
  final String? title;
  final String? subtitle;
}

/// XP earned outside Pitch Duel matches (prediction settlements).
class PredictionXpAdded extends GameEvent {
  PredictionXpAdded(
    this.amount, {
    this.details,
    this.source = XpTransactionSource.prediction,
    this.title = 'PREDICTION REWARD',
  });

  final int amount;
  final String? details;
  final XpTransactionSource source;
  final String title;
}

class DailyGuessPlayerSettled extends GameEvent {
  DailyGuessPlayerSettled({
    required this.sport,
    required this.dayKey,
    required this.xp,
    required this.score,
    required this.won,
    required this.completedAt,
  });

  final Sport sport;
  final String dayKey;
  final int xp;
  final int score;
  final bool won;
  final DateTime completedAt;

  String get settlementId => 'guess-player:${sport.name}:$dayKey';
}

class CardPurchased extends GameEvent {
  CardPurchased(this.cardId);
  final String cardId;
}

class DirectCardPurchased extends GameEvent {
  DirectCardPurchased({
    required this.cardId,
    required this.price,
    this.spendCoins = true,
  });

  final String cardId;
  final int price;
  final bool spendCoins;
}

class PackOpened extends GameEvent {
  PackOpened({
    required this.packId,
    required this.packName,
    required this.rolledCardIds,
    required this.refund,
  });

  final String packId;
  final String packName;
  final List<String> rolledCardIds;
  final int refund;
}

class StarterPackClaimed extends GameEvent {}

class StarterPackOpened extends GameEvent {}

class CricketStarterPackOpened extends GameEvent {}

class BasketballStarterPackOpened extends GameEvent {}

class TennisStarterPackOpened extends GameEvent {}

class DailyDropClaimed extends GameEvent {}

class ShopPackPurchased extends GameEvent {
  ShopPackPurchased(this.packId, {this.spendCoins = true});

  final String packId;
  final bool spendCoins;
}

class CardBackPurchased extends GameEvent {
  CardBackPurchased(this.cardBackId);
  final String cardBackId;
}

class CardBackEquipped extends GameEvent {
  CardBackEquipped(this.cardBackId);
  final String cardBackId;
}

class AvatarFramePurchased extends GameEvent {
  AvatarFramePurchased(this.frameId);
  final String frameId;
}

class AvatarFrameEquipped extends GameEvent {
  AvatarFrameEquipped(this.frameId);
  final String frameId;
}

/// Buy a shop avatar (player portrait) with coins — BUY → OWNED, no equip.
class ShopAvatarPurchased extends GameEvent {
  ShopAvatarPurchased({
    required this.avatarId,
    required this.price,
    required this.name,
  });

  final String avatarId;
  final int price;
  final String name;
}

/// Buy a shop banner with coins — BUY → OWNED, no equip.
class ShopBannerPurchased extends GameEvent {
  ShopBannerPurchased({
    required this.bannerId,
    required this.price,
    required this.name,
  });

  final String bannerId;
  final int price;
  final String name;
}

/// Buy a Final Over kit design with coins — BUY → OWNED, equip in deck builder.
class ShopFinalOverKitPurchased extends GameEvent {
  ShopFinalOverKitPurchased({
    required this.kitId,
    required this.price,
    required this.name,
  });

  final String kitId;
  final int price;
  final String name;
}

class PackRevealSeen extends GameEvent {}

class StreakActivityRecorded extends GameEvent {
  StreakActivityRecorded(this.activity, {DateTime? occurredAt})
    : occurredAt = occurredAt ?? DateTime.now();

  final StreakActivity activity;
  final DateTime occurredAt;
}

class StreakCelebrationConsumed extends GameEvent {}

class StreakMilestoneClaimed extends GameEvent {
  StreakMilestoneClaimed(this.days);
  final int days;
}

class MatchReset extends GameEvent {}

class MatchStarted extends GameEvent {
  MatchStarted({this.opponentName, this.opponentLevel});

  /// When launched as a leaderboard CHALLENGE, the rival's display name shown
  /// on the VS screen. Null for a normal match (renders as "Opponent").
  final String? opponentName;

  /// Optional difficulty override (the rival's level); falls back to the
  /// player's level when null.
  final int? opponentLevel;
}

class TossChoiceChanged extends GameEvent {
  TossChoiceChanged(this.choice);
  final String choice;
}

class TossResolved extends GameEvent {
  TossResolved(this.call);

  /// The face the player called before the flip: 'heads' or 'tails'.
  final String call;
}

/// Fired when the toss loser acknowledges the result and moves on to see the
/// CPU's role pick (→ [MatchPhase.roleReveal]).
class TossContinued extends GameEvent {}

class RoleChosen extends GameEvent {
  RoleChosen(this.playerAttacking);
  final bool playerAttacking;
}

/// Fired when the player acknowledges the role-reveal beat (CPU-won round 1 or a
/// round 2–4 role switch) and proceeds to the scenario briefing.
class RoleRevealAcknowledged extends GameEvent {}

class ScenarioShown extends GameEvent {}

class PlayStarted extends GameEvent {}

class PlayerSelected extends GameEvent {
  PlayerSelected(this.card);
  final PlayerCard card;
}

class ActionSelected extends GameEvent {
  ActionSelected(this.card);
  final ActionCard card;
}

class MovePlayed extends GameEvent {
  MovePlayed({this.playerSurge});

  /// The player's power swing (0..20) from the Shot Meter, replacing the hidden
  /// random roll on the player's side. Null falls back to a random swing
  /// (e.g. the reduced-motion bypass).
  final double? playerSurge;
}

class RoundAdvanced extends GameEvent {}

class MatchFinished extends GameEvent {}

/// Fired once by the standalone Penalty Shootout mode when a shootout ends,
/// so XP/coins/history flow through the same progression owner as matches.
class ShootoutFinished extends GameEvent {
  ShootoutFinished({required this.playerGoals, required this.cpuGoals});

  final int playerGoals;
  final int cpuGoals;
}

/// Fired once by Grand Prix Dash when the player crosses the line — applies
/// the (already computed, PB bonus included) XP and writes a `grandprix`
/// match-history entry in one handler, mirroring [ShootoutFinished].
/// XP only: racing never pays coins.
class GrandPrixFinished extends GameEvent {
  GrandPrixFinished({
    required this.position,
    required this.fieldSize,
    required this.circuitName,
    required this.lapTimeMs,
    required this.verdictLabel,
    required this.xp,
  });

  final int position;
  final int fieldSize;
  final String circuitName;
  final int lapTimeMs;
  final String verdictLabel; // 'Victory' | 'Podium' | 'Points' | 'Finished'
  final int xp;
}

/// Fired once by Hoop Duel when a match ends — applies the (already computed)
/// XP and writes a `basketball` match-history entry, mirroring
/// [GrandPrixFinished]. XP only: the court never pays coins.
class BasketballFinished extends GameEvent {
  BasketballFinished({
    required this.playerScore,
    required this.cpuScore,
    required this.resultLabel,
    required this.difficultyLabel,
    required this.grade,
    required this.overtime,
    required this.xp,
  });

  final int playerScore;
  final int cpuScore;
  final String resultLabel; // 'Victory' | 'Defeat'
  final String difficultyLabel;
  final String grade;
  final bool overtime;
  final int xp;
}

/// Settles one completed Final Over chase in the global XP and history owner.
/// XP only — Final Over pays no coins.
class FinalOverFinished extends GameEvent {
  FinalOverFinished({
    required this.matchId,
    required this.runs,
    required this.target,
    required this.wickets,
    required this.resultLabel,
    required this.tierLabel,
    required this.grade,
    required this.stars,
    required this.xp,
  });

  final String matchId;
  final int runs;
  final int target;
  final int wickets;
  final String resultLabel; // 'CHASE COMPLETE' | 'CHASE FAILED'
  final String tierLabel;
  final String grade;
  final int stars;
  final int xp;
}

/// Settles one completed Tennis Rally session in the global XP, wallet, and
/// history owner. [matchId] is persisted separately so retries cannot pay twice.
class TennisFinished extends GameEvent {
  TennisFinished({
    required this.matchId,
    required this.playerName,
    required this.opponentName,
    required this.modeLabel,
    required this.difficultyLabel,
    required this.resultLabel,
    required this.grade,
    required this.playerGames,
    required this.opponentGames,
    required this.xp,
    required this.coins,
  });

  final String matchId;
  final String playerName;
  final String opponentName;
  final String modeLabel;
  final String difficultyLabel;
  final String resultLabel;
  final String grade;
  final int playerGames;
  final int opponentGames;
  final int xp;
  final int coins;
}

/// Fired once by Super Over mode when an over finishes to award XP
/// and record history.
class SuperOverFinished extends GameEvent {
  SuperOverFinished({required this.summary});

  final SuperOverMatchSummary summary;
}
