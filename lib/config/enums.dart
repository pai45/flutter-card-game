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
  shootout,
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
  roleReveal,
  scenario,
  play,
  roundResult,
  finalResult,
}

/// Stages of the standalone Penalty Shootout mode.
enum ShootoutStage { lineup, choose, result, summary }

enum RoundOutcome { goal, saved, blocked, missed, foul, redCard }
