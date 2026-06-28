// Domain types for the 5v5 Football Chess game (grid/chess model).
//
// The board model + rules live in `lib/games/football_chess/` (pure Dart, so the
// rules stay unit-testable). This file holds the lightweight shared enums + the
// persisted/record types consumed across the cubit, renderer and screens.

/// Which side a piece / turn / possession belongs to.
enum Side { player, opponent }

extension SideX on Side {
  Side get opposite => this == Side.player ? Side.opponent : Side.player;
  bool get isPlayer => this == Side.player;
}

/// The kinds of action a piece can take on a turn.
enum BoardActionType { move, dribble, pass, shoot, press, tackle, slide }

extension BoardActionTypeX on BoardActionType {
  String get label => switch (this) {
    BoardActionType.move => 'MOVE',
    BoardActionType.dribble => 'DRIBBLE',
    BoardActionType.pass => 'PASS',
    BoardActionType.shoot => 'SHOOT',
    BoardActionType.press => 'PRESS',
    BoardActionType.tackle => 'TACKLE',
    BoardActionType.slide => 'SLIDE',
  };

  /// True when the verb needs a follow-up target tap (otherwise it resolves on
  /// the verb tap).
  bool get needsTarget =>
      this == BoardActionType.move ||
      this == BoardActionType.dribble ||
      this == BoardActionType.pass;
}

/// The outcome of resolving an action — drives feedback (SFX, banners).
enum BoardEvent { none, advanced, goal, save, blocked, turnover }

/// A booking handed out for a reckless (missed) slide.
enum CardType { none, yellow, red }

/// Coin-toss call shown at kickoff.
enum CoinSide { heads, tails }

/// The match's high-level state inside the cubit.
enum ChessMatchPhase {
  toss,
  playerTurn,
  opponentTurn,
  resolving,
  goalScored,
  fullTime,
}

/// 5-a-side shapes — now used as the **starting layout** of the four outfielders
/// on the grid (the keeper guards the goal off-grid).
enum ChessFormation { box, diamond, attacking, defensive }

extension ChessFormationX on ChessFormation {
  String get label => switch (this) {
    ChessFormation.box => 'BOX',
    ChessFormation.diamond => 'DIAMOND',
    ChessFormation.attacking => 'HIGH LINE',
    ChessFormation.defensive => 'LOW BLOCK',
  };

  /// 5-a-side code (GK omitted).
  String get code => switch (this) {
    ChessFormation.box => '2-2',
    ChessFormation.diamond => '1-2-1',
    ChessFormation.attacking => '2-1-1',
    ChessFormation.defensive => '1-1-2',
  };

  String get blurb => switch (this) {
    ChessFormation.box => 'Balanced two-and-two across the back and front.',
    ChessFormation.diamond => 'Compact diamond — control the centre.',
    ChessFormation.attacking => 'Push up — start higher up the pitch.',
    ChessFormation.defensive => 'Sit deep — start nearer your own goal.',
  };
}

/// One goal in the match log — feeds the victory screen's MVP + goal timeline.
class ChessGoal {
  const ChessGoal({
    required this.scorerShortName,
    required this.byPlayer,
    required this.atClock,
  });

  final String scorerShortName;
  final bool byPlayer;

  /// `clockRemaining` (seconds) when it went in — rendered as match time.
  final double atClock;
}

/// Persisted lifetime record for 5v5 Football Chess (on-device only, no
/// backend — mirrors how `QuizCubit`/`FriendsCubit` keep personal progress).
class FootballChessStats {
  const FootballChessStats({
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
  });

  factory FootballChessStats.fromJson(Map<String, dynamic> json) =>
      FootballChessStats(
        wins: json['wins'] as int? ?? 0,
        losses: json['losses'] as int? ?? 0,
        draws: json['draws'] as int? ?? 0,
        currentStreak: json['currentStreak'] as int? ?? 0,
        bestStreak: json['bestStreak'] as int? ?? 0,
      );

  final int wins;
  final int losses;
  final int draws;
  final int currentStreak;
  final int bestStreak;

  int get played => wins + losses + draws;

  FootballChessStats recordResult({required bool won, required bool draw}) {
    final nextStreak = won ? currentStreak + 1 : 0;
    return FootballChessStats(
      wins: won ? wins + 1 : wins,
      losses: (!won && !draw) ? losses + 1 : losses,
      draws: draw ? draws + 1 : draws,
      currentStreak: nextStreak,
      bestStreak: nextStreak > bestStreak ? nextStreak : bestStreak,
    );
  }

  Map<String, dynamic> toJson() => {
    'wins': wins,
    'losses': losses,
    'draws': draws,
    'currentStreak': currentStreak,
    'bestStreak': bestStreak,
  };
}
