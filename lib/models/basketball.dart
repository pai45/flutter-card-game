/// Domain model for Hoop Duel — the 2D side-view 1v1 arcade basketball duel.
///
/// Pure data: enums, athlete specs, match config/summary, and the persisted
/// lifetime record. No Flutter/Flame imports so the engine and tests stay pure.
library;

enum BasketballArchetype { balancedGuard, sharpshooter, slasher, interiorPower }

enum BasketballCardRole { guard, wing, big }

/// One signature trait per athlete — small, readable effects.
enum BasketballTrait {
  /// Faster gather + earlier release apex, slightly wider perfect window.
  quickRelease,

  /// No distance falloff beyond the three-point arc.
  deepRange,

  /// Wider dunk gate and halved layup contest.
  rimPressure,

  /// Rebound contest bonus and stronger box-out.
  glassCleaner,
}

enum BasketballDifficulty { rookie, pro, allStar }

/// Where a shot resolves from, by distance to the rim at release.
enum ShotZone { dunk, layup, close, mid, three }

/// Release timing grade against the shot meter.
enum ReleaseGrade { perfect, good, early, late }

String basketballArchetypeLabel(BasketballArchetype archetype) =>
    switch (archetype) {
      BasketballArchetype.balancedGuard => 'BALANCED GUARD',
      BasketballArchetype.sharpshooter => 'SHARPSHOOTER',
      BasketballArchetype.slasher => 'SLASHER',
      BasketballArchetype.interiorPower => 'INTERIOR POWER',
    };

String basketballTraitLabel(BasketballTrait trait) => switch (trait) {
  BasketballTrait.quickRelease => 'QUICK RELEASE',
  BasketballTrait.deepRange => 'DEEP RANGE',
  BasketballTrait.rimPressure => 'RIM PRESSURE',
  BasketballTrait.glassCleaner => 'GLASS CLEANER',
};

String basketballTraitBlurb(BasketballTrait trait) => switch (trait) {
  BasketballTrait.quickRelease => 'Faster gather, harder to block',
  BasketballTrait.deepRange => 'No penalty on deep threes',
  BasketballTrait.rimPressure => 'Dunks from further out',
  BasketballTrait.glassCleaner => 'Owns the rebound battle',
};

String basketballDifficultyLabel(BasketballDifficulty difficulty) =>
    switch (difficulty) {
      BasketballDifficulty.rookie => 'ROOKIE',
      BasketballDifficulty.pro => 'PRO',
      BasketballDifficulty.allStar => 'ALL-STAR',
    };

BasketballDifficulty basketballDifficultyFromName(String? name) =>
    BasketballDifficulty.values.firstWhere(
      (d) => d.name == name,
      orElse: () => BasketballDifficulty.pro,
    );

/// A Hoop Duel athlete. Ratings are 0-99.
class BasketballAthlete {
  const BasketballAthlete({
    required this.id,
    required this.name,
    required this.ovr,
    required this.teamName,
    required this.teamCode,
    required this.position,
    required this.cardRole,
    required this.archetype,
    required this.trait,
    required this.tagline,
    required this.heightM,
    required this.speed,
    required this.handling,
    required this.inside,
    required this.mid,
    required this.three,
    required this.dunk,
    required this.defense,
    required this.steal,
    required this.block,
    required this.rebound,
    required this.stamina,
  });

  final String id;
  final String name;
  final int ovr;
  final String teamName;
  final String teamCode;
  final String position;
  final BasketballCardRole cardRole;
  final BasketballArchetype archetype;
  final BasketballTrait trait;

  /// One-line lobby flavor, e.g. 'Never rushed. Never late.'
  final String tagline;

  /// Body height in metres — feeds reach for blocks/rebounds.
  final double heightM;

  final int speed;
  final int handling;
  final int inside;
  final int mid;
  final int three;
  final int dunk;
  final int defense;
  final int steal;
  final int block;
  final int rebound;
  final int stamina;

  /// Shooting rating for a zone (dunk uses [dunk], put-backs use [inside]).
  int ratingFor(ShotZone zone) => switch (zone) {
    ShotZone.dunk => dunk,
    ShotZone.layup || ShotZone.close => inside,
    ShotZone.mid => mid,
    ShotZone.three => three,
  };

  int get overall => ovr;
}

/// Everything a match needs to run deterministically.
class BasketballMatchConfig {
  const BasketballMatchConfig({
    required this.playerRoster,
    required this.playerStarterIndex,
    required this.cpuRoster,
    required this.cpuStarterIndex,
    required this.difficulty,
    required this.seed,
    this.showHints = false,
    this.teamId = 'lakers',
    this.cpuTeamId = 'bulls',
  });

  /// Three athletes picked in the lobby; one is active at a time.
  final List<BasketballAthlete> playerRoster;
  final int playerStarterIndex;
  final List<BasketballAthlete> cpuRoster;
  final int cpuStarterIndex;
  final BasketballDifficulty difficulty;
  final int seed;

  /// First-match contextual control hints.
  final bool showHints;

  /// The user's selected team livery ID.
  final String teamId;

  /// The CPU's team livery ID — always different from [teamId].
  final String cpuTeamId;
}

/// Player-side box score, accumulated by the engine for the result screen.
class BasketballBoxScore {
  const BasketballBoxScore({
    this.attempts = 0,
    this.makes = 0,
    this.threesMade = 0,
    this.perfectReleases = 0,
    this.dunks = 0,
    this.blocks = 0,
    this.steals = 0,
    this.rebounds = 0,
    this.turnovers = 0,
    this.bestRun = 0,
  });

  final int attempts;
  final int makes;
  final int threesMade;
  final int perfectReleases;
  final int dunks;
  final int blocks;
  final int steals;
  final int rebounds;
  final int turnovers;

  /// Longest unanswered scoring run (points).
  final int bestRun;

  int get fgPercent => attempts == 0 ? 0 : (makes * 100 ~/ attempts);
}

/// Final match outcome handed from the engine to the cubit/result screen.
class BasketballMatchSummary {
  const BasketballMatchSummary({
    required this.playerScore,
    required this.cpuScore,
    required this.overtime,
    required this.box,
    required this.difficulty,
    this.buzzerBeater = false,
    this.abandoned = false,
  });

  final int playerScore;
  final int cpuScore;
  final bool overtime;
  final BasketballBoxScore box;
  final BasketballDifficulty difficulty;

  /// The winning basket beat the final buzzer.
  final bool buzzerBeater;
  final bool abandoned;

  bool get won => playerScore > cpuScore;
  int get margin => (playerScore - cpuScore).abs();

  /// Performance grade D→S: result + shot quality + defense, not just score.
  String get grade {
    var score = 0;
    if (won) score += 3;
    if (box.fgPercent >= 60) {
      score += 2;
    } else if (box.fgPercent >= 45) {
      score += 1;
    }
    if (box.perfectReleases >= 3) score += 1;
    if (box.blocks + box.steals >= 3) {
      score += 2;
    } else if (box.blocks + box.steals >= 1) {
      score += 1;
    }
    if (box.turnovers >= 4) score -= 1;
    if (won && margin >= 8) score += 1;
    return switch (score) {
      >= 8 => 'S',
      >= 6 => 'A',
      >= 4 => 'B',
      >= 2 => 'C',
      _ => 'D',
    };
  }
}

/// Persisted lifetime Hoop Duel record (on-device only — mirrors
/// [GrandPrixStats]). Also remembers the last roster/starter/difficulty so a
/// returning player can hit PLAY immediately, and whether the first-match
/// control hints have been shown.
class BasketballStats {
  const BasketballStats({
    this.games = 0,
    this.wins = 0,
    this.losses = 0,
    this.otGames = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.mostPoints = 0,
    this.bestMargin = 0,
    this.totalDunks = 0,
    this.totalBlocks = 0,
    this.totalPerfects = 0,
    this.lastRosterIds = const [],
    this.lastStarterId,
    this.lastDifficulty = BasketballDifficulty.pro,
    this.hintsSeen = false,
    this.lastTeamId = 'lakers',
  });

  factory BasketballStats.fromJson(Map<String, dynamic> json) {
    final rawRoster = json['lastRosterIds'];
    return BasketballStats(
      games: json['games'] as int? ?? 0,
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      otGames: json['otGames'] as int? ?? 0,
      currentStreak: json['currentStreak'] as int? ?? 0,
      bestStreak: json['bestStreak'] as int? ?? 0,
      mostPoints: json['mostPoints'] as int? ?? 0,
      bestMargin: json['bestMargin'] as int? ?? 0,
      totalDunks: json['totalDunks'] as int? ?? 0,
      totalBlocks: json['totalBlocks'] as int? ?? 0,
      totalPerfects: json['totalPerfects'] as int? ?? 0,
      lastRosterIds: rawRoster is List
          ? [for (final id in rawRoster) '$id']
          : const [],
      lastStarterId: json['lastStarterId'] as String?,
      lastDifficulty: basketballDifficultyFromName(
        json['lastDifficulty'] as String?,
      ),
      hintsSeen: json['hintsSeen'] as bool? ?? false,
      lastTeamId: json['lastTeamId'] as String? ?? 'lakers',
    );
  }

  final int games;
  final int wins;
  final int losses;
  final int otGames;
  final int currentStreak;
  final int bestStreak;
  final int mostPoints;
  final int bestMargin;
  final int totalDunks;
  final int totalBlocks;
  final int totalPerfects;
  final List<String> lastRosterIds;
  final String? lastStarterId;
  final BasketballDifficulty lastDifficulty;
  final bool hintsSeen;
  final String lastTeamId;

  BasketballStats copyWith({
    List<String>? lastRosterIds,
    String? lastStarterId,
    BasketballDifficulty? lastDifficulty,
    bool? hintsSeen,
    String? lastTeamId,
  }) => BasketballStats(
    games: games,
    wins: wins,
    losses: losses,
    otGames: otGames,
    currentStreak: currentStreak,
    bestStreak: bestStreak,
    mostPoints: mostPoints,
    bestMargin: bestMargin,
    totalDunks: totalDunks,
    totalBlocks: totalBlocks,
    totalPerfects: totalPerfects,
    lastRosterIds: lastRosterIds ?? this.lastRosterIds,
    lastStarterId: lastStarterId ?? this.lastStarterId,
    lastDifficulty: lastDifficulty ?? this.lastDifficulty,
    hintsSeen: hintsSeen ?? this.hintsSeen,
    lastTeamId: lastTeamId ?? this.lastTeamId,
  );

  BasketballStats recordResult(BasketballMatchSummary summary) {
    final won = summary.won;
    final nextStreak = won ? currentStreak + 1 : 0;
    return BasketballStats(
      games: games + 1,
      wins: won ? wins + 1 : wins,
      losses: won ? losses : losses + 1,
      otGames: summary.overtime ? otGames + 1 : otGames,
      currentStreak: nextStreak,
      bestStreak: nextStreak > bestStreak ? nextStreak : bestStreak,
      mostPoints: summary.playerScore > mostPoints
          ? summary.playerScore
          : mostPoints,
      bestMargin: won && summary.margin > bestMargin
          ? summary.margin
          : bestMargin,
      totalDunks: totalDunks + summary.box.dunks,
      totalBlocks: totalBlocks + summary.box.blocks,
      totalPerfects: totalPerfects + summary.box.perfectReleases,
      lastRosterIds: lastRosterIds,
      lastStarterId: lastStarterId,
      lastDifficulty: summary.difficulty,
      hintsSeen: hintsSeen,
      lastTeamId: lastTeamId,
    );
  }

  Map<String, dynamic> toJson() => {
    'games': games,
    'wins': wins,
    'losses': losses,
    'otGames': otGames,
    'currentStreak': currentStreak,
    'bestStreak': bestStreak,
    'mostPoints': mostPoints,
    'bestMargin': bestMargin,
    'totalDunks': totalDunks,
    'totalBlocks': totalBlocks,
    'totalPerfects': totalPerfects,
    'lastRosterIds': lastRosterIds,
    'lastStarterId': lastStarterId,
    'lastDifficulty': lastDifficulty.name,
    'hintsSeen': hintsSeen,
    'lastTeamId': lastTeamId,
  };
}
