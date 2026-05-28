enum AppSection { home, deck, howToPlay, match, game, shop, allCards }

enum DeckPickerLane { attacker, defender, action }

enum CardTier { bronze, silver, gold, platinum }

enum CardRarity { common, rare, epic, legendary }

enum PenaltyDirection { left, center, right }

enum PlayerRole { attacker, defender, goalkeeper }

enum ActionCategory { attack, defense, special }

enum MatchPhase {
  idle,
  toss,
  tossResult,
  scenario,
  play,
  roundResult,
  matchEnd,
  penalty,
  finalResult,
}

enum RoundOutcome { goal, saved, blocked, missed, foul, redCard }
