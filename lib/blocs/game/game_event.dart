import '../../models/cards.dart';
import '../../models/deck.dart';
import '../../models/oz_coin_ledger.dart';
import '../../models/streak.dart';

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
  PredictionXpAdded(this.amount, {this.details});

  final int amount;
  final String? details;
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
