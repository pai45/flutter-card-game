import '../models/match.dart';

/// Demo match-history entries, seeded so every game's MATCH HISTORY page — and
/// every sport tab of the cross-sport MATCH ARCHIVE — has a populated log on a
/// fresh install instead of "No matches yet".
///
/// Mirrors `PredictionCubit.applyHistoryDemos`: real results always win. The
/// demos are appended *after* stored history and carry stable `demo-` ids, so
/// `_retainHistoryByMode` dedupes them on relaunch and drops them first as a
/// player's own games fill the per-mode retention cap.
///
/// The set is deliberately a coverage matrix, not a highlight reel: between
/// them these entries exercise every branch `MatchHistoryTile`, the W/D/L
/// record strip and `_MatchHistoryDetailPage` can take —
///
/// * every result label the games write: `Victory`, `Defeat`, `Draw`,
///   `Podium`, `Points`, `Finished`, `Retired`, `CHASE COMPLETE`,
///   `CHASE FAILED`, `Completed`, `Lesson Complete`;
/// * every mode badge: SHOOTOUT, GRAND PRIX, HOOP DUEL, TENNIS RALLY, and the
///   legacy PEN badge from the retired in-match shootout;
/// * the position readout (`P3/20`) races use instead of a scoreline;
/// * a positive, a zero and a negative XP chip, plus a legacy entry with no XP
///   recorded at all;
/// * every round-log outcome stamp — Goal, Saved, Blocked, Missed, Foul,
///   Red Card — in both attacking and defending rounds, and an entry with no
///   round data so the detail page's empty state is reachable.
///
/// XP figures are what the real reward functions would have paid for these
/// scorelines (`calculateMatchXP`, `calculateShootoutXP`,
/// `calculateGrandPrixXP`, `calculateBasketballXP`, `calculateFinalOverXp`,
/// `calculateTennisReward`), so the logs never advertise a payout the games
/// cannot produce.
List<MatchHistoryEntry> demoMatchHistory({DateTime? now}) {
  final at = now ?? DateTime.now();
  String stamp(Duration ago) => at.subtract(ago).toIso8601String();

  return [
    // ── Pitch Duel (mode 'match') ────────────────────────────────────────────
    // Four rounds with the roles alternating, so each side attacks twice: 2-2
    // is the widest scoreline the format can produce.
    MatchHistoryEntry(
      id: 'demo-match-victory',
      deckName: 'Starter Squad',
      timestampIso: stamp(const Duration(hours: 3)),
      resultLabel: 'Victory',
      playerScore: 2,
      opponentScore: 1,
      xpEarned: 13,
      rounds: const [
        MatchHistoryRound(
          round: 1,
          scenarioTitle: 'Counter Attack',
          outcomeLabel: 'Goal',
          playerAttacking: true,
        ),
        MatchHistoryRound(
          round: 2,
          scenarioTitle: 'Box Defense',
          outcomeLabel: 'Saved',
          playerAttacking: false,
        ),
        MatchHistoryRound(
          round: 3,
          scenarioTitle: '1v1 Final Third',
          outcomeLabel: 'Goal',
          playerAttacking: true,
        ),
        MatchHistoryRound(
          round: 4,
          scenarioTitle: 'Last Minute Pressure',
          outcomeLabel: 'Goal',
          playerAttacking: false,
        ),
      ],
    ),
    // Clean sheet plus the two disciplinary outcomes: Foul and Red Card.
    MatchHistoryEntry(
      id: 'demo-match-shutout',
      deckName: 'Iron Wall',
      timestampIso: stamp(const Duration(days: 1, hours: 5)),
      resultLabel: 'Victory',
      playerScore: 2,
      opponentScore: 0,
      xpEarned: 21,
      rounds: const [
        MatchHistoryRound(
          round: 1,
          scenarioTitle: 'Set Piece Chance',
          outcomeLabel: 'Goal',
          playerAttacking: true,
        ),
        MatchHistoryRound(
          round: 2,
          scenarioTitle: 'Penalty Box Chaos',
          outcomeLabel: 'Foul',
          playerAttacking: false,
        ),
        MatchHistoryRound(
          round: 3,
          scenarioTitle: 'Wide Break',
          outcomeLabel: 'Goal',
          playerAttacking: true,
        ),
        MatchHistoryRound(
          round: 4,
          scenarioTitle: 'Box Defense',
          outcomeLabel: 'Red Card',
          playerAttacking: false,
        ),
      ],
    ),
    // Level after four rounds — a draw pays a flat +4 and never goes to
    // penalties (the shootout is its own mode now).
    MatchHistoryEntry(
      id: 'demo-match-draw',
      deckName: 'Starter Squad',
      timestampIso: stamp(const Duration(days: 2, hours: 2)),
      resultLabel: 'Draw',
      playerScore: 1,
      opponentScore: 1,
      xpEarned: 4,
      rounds: const [
        MatchHistoryRound(
          round: 1,
          scenarioTitle: 'Counter Attack',
          outcomeLabel: 'Goal',
          playerAttacking: true,
        ),
        MatchHistoryRound(
          round: 2,
          scenarioTitle: 'Wide Break',
          outcomeLabel: 'Goal',
          playerAttacking: false,
        ),
        MatchHistoryRound(
          round: 3,
          scenarioTitle: 'Set Piece Chance',
          outcomeLabel: 'Missed',
          playerAttacking: true,
        ),
        MatchHistoryRound(
          round: 4,
          scenarioTitle: 'Box Defense',
          outcomeLabel: 'Saved',
          playerAttacking: false,
        ),
      ],
    ),
    // A defeat is the one result that subtracts XP — the tile's red chip.
    MatchHistoryEntry(
      id: 'demo-match-defeat',
      deckName: 'Glass Cannon',
      timestampIso: stamp(const Duration(days: 3, hours: 7)),
      resultLabel: 'Defeat',
      playerScore: 0,
      opponentScore: 2,
      xpEarned: -9,
      rounds: const [
        MatchHistoryRound(
          round: 1,
          scenarioTitle: '1v1 Final Third',
          outcomeLabel: 'Saved',
          playerAttacking: true,
        ),
        MatchHistoryRound(
          round: 2,
          scenarioTitle: 'Penalty Box Chaos',
          outcomeLabel: 'Goal',
          playerAttacking: false,
        ),
        MatchHistoryRound(
          round: 3,
          scenarioTitle: 'Last Minute Pressure',
          outcomeLabel: 'Blocked',
          playerAttacking: true,
        ),
        MatchHistoryRound(
          round: 4,
          scenarioTitle: 'Counter Attack',
          outcomeLabel: 'Goal',
          playerAttacking: false,
        ),
      ],
    ),
    // Legacy shape: a match that went to the old in-match shootout, so it
    // still renders the violet PEN badge.
    MatchHistoryEntry(
      id: 'demo-match-legacy-penalties',
      deckName: 'Starter Squad',
      timestampIso: stamp(const Duration(days: 6, hours: 4)),
      resultLabel: 'Victory',
      playerScore: 1,
      opponentScore: 1,
      penaltyPlayerScore: 4,
      penaltyOpponentScore: 3,
      xpEarned: 10,
      rounds: const [
        MatchHistoryRound(
          round: 1,
          scenarioTitle: 'Wide Break',
          outcomeLabel: 'Goal',
          playerAttacking: true,
        ),
        MatchHistoryRound(
          round: 2,
          scenarioTitle: 'Set Piece Chance',
          outcomeLabel: 'Goal',
          playerAttacking: false,
        ),
        MatchHistoryRound(
          round: 3,
          scenarioTitle: 'Penalty Box Chaos',
          outcomeLabel: 'Blocked',
          playerAttacking: true,
        ),
        MatchHistoryRound(
          round: 4,
          scenarioTitle: 'Box Defense',
          outcomeLabel: 'Missed',
          playerAttacking: false,
        ),
      ],
    ),
    // The oldest shape of all: no round log and no XP recorded — the detail
    // page's "No round data." state, and a tile with no XP chip.
    MatchHistoryEntry(
      id: 'demo-match-legacy-bare',
      deckName: 'Starter Squad',
      timestampIso: stamp(const Duration(days: 9, hours: 1)),
      resultLabel: 'Defeat',
      playerScore: 0,
      opponentScore: 1,
      rounds: const [],
    ),

    // ── Penalty Shootout (mode 'shootout') ───────────────────────────────────
    MatchHistoryEntry(
      id: 'demo-shootout-victory',
      mode: 'shootout',
      deckName: 'Starter Squad',
      timestampIso: stamp(const Duration(hours: 8)),
      resultLabel: 'Victory',
      playerScore: 5,
      opponentScore: 3,
      xpEarned: 10,
      rounds: const [],
    ),
    // Sudden death, past the five regulation kicks.
    MatchHistoryEntry(
      id: 'demo-shootout-sudden-death',
      mode: 'shootout',
      deckName: 'Iron Wall',
      timestampIso: stamp(const Duration(days: 1, hours: 9)),
      resultLabel: 'Victory',
      playerScore: 7,
      opponentScore: 6,
      xpEarned: 8,
      rounds: const [],
    ),
    // A perfect set — the +12 shootout ceiling.
    MatchHistoryEntry(
      id: 'demo-shootout-whitewash',
      mode: 'shootout',
      deckName: 'Starter Squad',
      timestampIso: stamp(const Duration(days: 4, hours: 3)),
      resultLabel: 'Victory',
      playerScore: 5,
      opponentScore: 0,
      xpEarned: 12,
      rounds: const [],
    ),
    // A shootout loss pays nothing — the zero XP chip.
    MatchHistoryEntry(
      id: 'demo-shootout-defeat',
      mode: 'shootout',
      deckName: 'Glass Cannon',
      timestampIso: stamp(const Duration(days: 7, hours: 6)),
      resultLabel: 'Defeat',
      playerScore: 2,
      opponentScore: 4,
      xpEarned: 0,
      rounds: const [],
    ),

    // ── Grand Prix Dash (mode 'grandprix') ───────────────────────────────────
    // playerScore is the finishing position and opponentScore the field size —
    // the tile reads 'P1/20', never a scoreline.
    MatchHistoryEntry(
      id: 'demo-grandprix-win',
      mode: 'grandprix',
      deckName: 'HARBOUR STREET · 1:02.418',
      timestampIso: stamp(const Duration(hours: 5)),
      resultLabel: 'Victory',
      playerScore: 1,
      opponentScore: 20,
      xpEarned: 26,
      rounds: const [],
    ),
    // Long-distance win: the 5-lap x3 multiplier plus a personal best.
    MatchHistoryEntry(
      id: 'demo-grandprix-endurance-pb',
      mode: 'grandprix',
      deckName: 'EMERALD PARK · 5 LAPS · 1:12.887',
      timestampIso: stamp(const Duration(days: 2, hours: 6)),
      resultLabel: 'Victory',
      playerScore: 1,
      opponentScore: 20,
      xpEarned: 81,
      rounds: const [],
    ),
    MatchHistoryEntry(
      id: 'demo-grandprix-podium',
      mode: 'grandprix',
      deckName: 'EMERALD PARK · 3 LAPS · 1:14.902',
      timestampIso: stamp(const Duration(days: 3, hours: 2)),
      resultLabel: 'Podium',
      playerScore: 3,
      opponentScore: 20,
      xpEarned: 36,
      rounds: const [],
    ),
    MatchHistoryEntry(
      id: 'demo-grandprix-points',
      mode: 'grandprix',
      deckName: 'DESERT MILE · 1:08.244',
      timestampIso: stamp(const Duration(days: 5, hours: 8)),
      resultLabel: 'Points',
      playerScore: 6,
      opponentScore: 20,
      xpEarned: 12,
      rounds: const [],
    ),
    MatchHistoryEntry(
      id: 'demo-grandprix-finished',
      mode: 'grandprix',
      deckName: 'MOUNTAIN PASS · 5 LAPS · 1:21.560',
      timestampIso: stamp(const Duration(days: 8, hours: 5)),
      resultLabel: 'Finished',
      playerScore: 14,
      opponentScore: 20,
      xpEarned: 12,
      rounds: const [],
    ),
    // DNF: no lap time was set, so the deck line carries the empty clock.
    MatchHistoryEntry(
      id: 'demo-grandprix-retired',
      mode: 'grandprix',
      deckName: 'COASTAL SPRINT · --:--.---',
      timestampIso: stamp(const Duration(days: 11, hours: 3)),
      resultLabel: 'Retired',
      playerScore: 20,
      opponentScore: 20,
      xpEarned: 4,
      rounds: const [],
    ),

    // ── Hoop Duel (mode 'basketball') ────────────────────────────────────────
    MatchHistoryEntry(
      id: 'demo-basketball-win',
      mode: 'basketball',
      deckName: 'HOOP DUEL · ROOKIE',
      timestampIso: stamp(const Duration(hours: 11)),
      resultLabel: 'Victory',
      playerScore: 21,
      opponentScore: 17,
      xpEarned: 24,
      rounds: const [],
    ),
    // Overtime win at the top difficulty — the +2 OT bonus on top of margin.
    MatchHistoryEntry(
      id: 'demo-basketball-overtime-win',
      mode: 'basketball',
      deckName: 'HOOP DUEL · ALL-STAR',
      timestampIso: stamp(const Duration(days: 2, hours: 9)),
      resultLabel: 'Victory',
      playerScore: 32,
      opponentScore: 30,
      xpEarned: 22,
      rounds: const [],
    ),
    // Losing in overtime still pays a consolation +6.
    MatchHistoryEntry(
      id: 'demo-basketball-overtime-loss',
      mode: 'basketball',
      deckName: 'HOOP DUEL · ALL-STAR',
      timestampIso: stamp(const Duration(days: 5, hours: 4)),
      resultLabel: 'Defeat',
      playerScore: 28,
      opponentScore: 30,
      xpEarned: 6,
      rounds: const [],
    ),
    MatchHistoryEntry(
      id: 'demo-basketball-loss',
      mode: 'basketball',
      deckName: 'HOOP DUEL · PRO',
      timestampIso: stamp(const Duration(days: 9, hours: 7)),
      resultLabel: 'Defeat',
      playerScore: 18,
      opponentScore: 24,
      xpEarned: 4,
      rounds: const [],
    ),

    // ── Final Over (mode 'finalover') ────────────────────────────────────────
    // playerScore is the runs made and opponentScore the target being chased.
    MatchHistoryEntry(
      id: 'demo-finalover-chase-complete',
      mode: 'finalover',
      deckName: 'FINAL OVER · ROOKIE',
      timestampIso: stamp(const Duration(hours: 6)),
      resultLabel: 'CHASE COMPLETE',
      playerScore: 42,
      opponentScore: 40,
      xpEarned: 95,
      rounds: const [],
    ),
    // Elite tier, taken off the last ball — no balls to spare, no bonus.
    MatchHistoryEntry(
      id: 'demo-finalover-last-ball',
      mode: 'finalover',
      deckName: 'FINAL OVER · ELITE',
      timestampIso: stamp(const Duration(days: 3, hours: 5)),
      resultLabel: 'CHASE COMPLETE',
      playerScore: 51,
      opponentScore: 50,
      xpEarned: 131,
      rounds: const [],
    ),
    // A chase lost by two still pays well — the mode rewards the innings, not
    // just the win.
    MatchHistoryEntry(
      id: 'demo-finalover-close-loss',
      mode: 'finalover',
      deckName: 'FINAL OVER · ELITE',
      timestampIso: stamp(const Duration(days: 6, hours: 8)),
      resultLabel: 'CHASE FAILED',
      playerScore: 47,
      opponentScore: 49,
      xpEarned: 119,
      rounds: const [],
    ),
    MatchHistoryEntry(
      id: 'demo-finalover-chase-failed',
      mode: 'finalover',
      deckName: 'FINAL OVER · PRO',
      timestampIso: stamp(const Duration(days: 10, hours: 2)),
      resultLabel: 'CHASE FAILED',
      playerScore: 33,
      opponentScore: 41,
      xpEarned: 51,
      rounds: const [],
    ),

    // ── Tennis Rally (mode 'tennis') ─────────────────────────────────────────
    MatchHistoryEntry(
      id: 'demo-tennis-win',
      mode: 'tennis',
      deckName: 'Carlos Alcaraz vs Novak Djokovic / PRO',
      timestampIso: stamp(const Duration(hours: 9)),
      resultLabel: 'Victory',
      playerScore: 6,
      opponentScore: 4,
      xpEarned: 34,
      rounds: const [],
    ),
    MatchHistoryEntry(
      id: 'demo-tennis-tournament-loss',
      mode: 'tennis',
      deckName: 'Jannik Sinner vs Daniil Medvedev / ALL-STAR',
      timestampIso: stamp(const Duration(days: 1, hours: 11)),
      resultLabel: 'Defeat',
      playerScore: 4,
      opponentScore: 6,
      xpEarned: 24,
      rounds: const [],
    ),
    // The practice modes score against nobody, so the opponent column is 0 and
    // the result reads 'Completed' rather than Victory/Defeat.
    MatchHistoryEntry(
      id: 'demo-tennis-endless-rally',
      mode: 'tennis',
      deckName: 'Ben Shelton vs Taylor Fritz / ROOKIE',
      timestampIso: stamp(const Duration(days: 4, hours: 6)),
      resultLabel: 'Completed',
      playerScore: 1180,
      opponentScore: 0,
      xpEarned: 11,
      rounds: const [],
    ),
    MatchHistoryEntry(
      id: 'demo-tennis-target-practice',
      mode: 'tennis',
      deckName: 'Alex de Minaur vs Alexander Zverev / PRO',
      timestampIso: stamp(const Duration(days: 7, hours: 2)),
      resultLabel: 'Completed',
      playerScore: 640,
      opponentScore: 0,
      xpEarned: 6,
      rounds: const [],
    ),
    // Training pays a one-off +5 the first time and reads its own verdict.
    MatchHistoryEntry(
      id: 'demo-tennis-training',
      mode: 'tennis',
      deckName: 'Flavio Cobolli vs Alexander Bublik / ROOKIE',
      timestampIso: stamp(const Duration(days: 12, hours: 5)),
      resultLabel: 'Lesson Complete',
      playerScore: 0,
      opponentScore: 0,
      xpEarned: 5,
      rounds: const [],
    ),
  ];
}
