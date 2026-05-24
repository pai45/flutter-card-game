import '../../config/enums.dart';
import '../../models/cards.dart';
import '../../models/deck.dart';

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
  CoinsAdded(this.amount);
  final int amount;
}

class CoinsSpent extends GameEvent {
  CoinsSpent(this.amount);
  final int amount;
}

class CardPurchased extends GameEvent {
  CardPurchased(this.cardId);
  final String cardId;
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

class CardBackPurchased extends GameEvent {
  CardBackPurchased(this.cardBackId);
  final String cardBackId;
}

class CardBackEquipped extends GameEvent {
  CardBackEquipped(this.cardBackId);
  final String cardBackId;
}

class PackRevealSeen extends GameEvent {}

class MatchReset extends GameEvent {}

class MatchStarted extends GameEvent {}

class TossChoiceChanged extends GameEvent {
  TossChoiceChanged(this.choice);
  final String choice;
}

class TossResolved extends GameEvent {}

class RoleChosen extends GameEvent {
  RoleChosen(this.playerAttacking);
  final bool playerAttacking;
}

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

class MovePlayed extends GameEvent {}

class RoundAdvanced extends GameEvent {}

class PenaltyStarted extends GameEvent {}

class PenaltyDirectionSelected extends GameEvent {
  PenaltyDirectionSelected(this.direction);
  final PenaltyDirection direction;
}

class PenaltyKickConfirmed extends GameEvent {}

class PenaltyNextKick extends GameEvent {}

class MatchFinished extends GameEvent {}
