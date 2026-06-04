enum AppSection {
  // App-level destinations (bottom nav).
  predictions, // HOME — the sports-prediction hub
  leaderboard,
  shop,
  profile,
  // Card-game ("Pitch Duel") internal sections, reached under the GAMES tab.
  home,
  deck,
  howToPlay,
  match,
  game,
  allCards,
}

enum DeckPickerLane { attacker, defender, keeper, action }

enum CardTier { bronze, silver, gold, platinum }

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
