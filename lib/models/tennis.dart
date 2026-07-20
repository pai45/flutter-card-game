import 'dart:math';

import '../config/enums.dart';
import '../data/tennis_athletes.dart';
import 'starter_pack.dart';

enum TennisMode {
  quickMatch,
  tournament,
  endlessRally,
  targetPractice,
  training,
}

enum TennisDifficulty { rookie, pro, allStar }

enum TennisArchetype {
  allRounder,
  powerBaseliner,
  speedDefender,
  serveAndVolley,
  spinSpecialist,
  allCourtRival,
}

enum TennisShotType {
  normal,
  power,
  topspin,
  slice,
  lob,
  volley,
  smash,
  dropShot,
  defensive,
  serve,
}

enum TennisTimingGrade { perfect, good, early, late, missed }

enum TennisMatchPhase {
  preServe,
  serving,
  rally,
  pointComplete,
  setComplete,
  practiceComplete,
}

extension TennisModeLabel on TennisMode {
  String get label => switch (this) {
    TennisMode.quickMatch => 'QUICK MATCH',
    TennisMode.tournament => 'TOURNAMENT',
    TennisMode.endlessRally => 'ENDLESS RALLY',
    TennisMode.targetPractice => 'TARGET PRACTICE',
    TennisMode.training => 'TRAINING',
  };
}

extension TennisDifficultyLabel on TennisDifficulty {
  String get label => switch (this) {
    TennisDifficulty.rookie => 'ROOKIE',
    TennisDifficulty.pro => 'PRO',
    TennisDifficulty.allStar => 'ALL-STAR',
  };

  int get winCoins => switch (this) {
    TennisDifficulty.rookie => 20,
    TennisDifficulty.pro => 30,
    TennisDifficulty.allStar => 40,
  };

  int get xpBonus => switch (this) {
    TennisDifficulty.rookie => 0,
    TennisDifficulty.pro => 4,
    TennisDifficulty.allStar => 8,
  };
}

extension TennisArchetypeLabel on TennisArchetype {
  String get label => switch (this) {
    TennisArchetype.allRounder => 'ALL-ROUNDER',
    TennisArchetype.powerBaseliner => 'POWER BASELINER',
    TennisArchetype.speedDefender => 'SPEED DEFENDER',
    TennisArchetype.serveAndVolley => 'SERVE & VOLLEY',
    TennisArchetype.spinSpecialist => 'SPIN SPECIALIST',
    TennisArchetype.allCourtRival => 'ALL-COURT RIVAL',
  };
}

extension TennisShotLabel on TennisShotType {
  String get label => switch (this) {
    TennisShotType.normal => 'GOOD',
    TennisShotType.power => 'POWER',
    TennisShotType.topspin => 'TOPSPIN',
    TennisShotType.slice => 'SLICE',
    TennisShotType.lob => 'LOB',
    TennisShotType.volley => 'VOLLEY',
    TennisShotType.smash => 'SMASH',
    TennisShotType.dropShot => 'DROP SHOT',
    TennisShotType.defensive => 'DEFENSIVE',
    TennisShotType.serve => 'SERVE',
  };
}

class TennisRatings {
  const TennisRatings({
    required this.speed,
    required this.acceleration,
    required this.power,
    required this.control,
    required this.serve,
    required this.stamina,
    required this.volley,
    required this.spin,
    required this.reach,
  });

  factory TennisRatings.fromJson(Map<String, dynamic> json) => TennisRatings(
    speed: _int(json['speed'], 75),
    acceleration: _int(json['acceleration'], 75),
    power: _int(json['power'], 75),
    control: _int(json['control'], 75),
    serve: _int(json['serve'], 75),
    stamina: _int(json['stamina'], 75),
    volley: _int(json['volley'], 75),
    spin: _int(json['spin'], 75),
    reach: _int(json['reach'], 75),
  );

  final int speed;
  final int acceleration;
  final int power;
  final int control;
  final int serve;
  final int stamina;
  final int volley;
  final int spin;
  final int reach;

  int get overall =>
      (speed +
          acceleration +
          power +
          control +
          serve +
          stamina +
          volley +
          spin +
          reach) ~/
      9;

  Map<String, dynamic> toJson() => {
    'speed': speed,
    'acceleration': acceleration,
    'power': power,
    'control': control,
    'serve': serve,
    'stamina': stamina,
    'volley': volley,
    'spin': spin,
    'reach': reach,
  };
}

class TennisPlayer {
  const TennisPlayer({
    required this.id,
    required this.name,
    required this.archetype,
    required this.ratings,
    required this.signature,
    required this.overallRating,
  });

  final String id;
  final String name;
  final TennisArchetype archetype;
  final TennisRatings ratings;
  final String signature;
  final int overallRating;

  CardTier get tier => packRarityForRating(overallRating);
}

/// The playable tennis roster. Backed by the real Top 100 (2026) list so that
/// starter-pack pulls, CPU opponents and the Flame engine all resolve against
/// the same athletes.
const tennisPlayers = tennisTop100;

TennisPlayer tennisPlayerById(String id) => tennisPlayers.firstWhere(
  (player) => player.id == id,
  orElse: () => tennisPlayers.first,
);

class TennisSettings {
  const TennisSettings({
    this.leftHanded = false,
    this.controlScale = 1,
    this.controlOpacity = 0.82,
    this.movementAssist = true,
    this.reducedMotion = false,
    this.strongFlashes = true,
    this.haptics = true,
    this.music = true,
    this.sound = true,
  });

  factory TennisSettings.fromJson(Map<String, dynamic> json) => TennisSettings(
    leftHanded: json['leftHanded'] as bool? ?? false,
    controlScale: _double(json['controlScale'], 1).clamp(0.8, 1.25).toDouble(),
    controlOpacity: _double(
      json['controlOpacity'],
      0.82,
    ).clamp(0.45, 1).toDouble(),
    movementAssist: json['movementAssist'] as bool? ?? true,
    reducedMotion: json['reducedMotion'] as bool? ?? false,
    strongFlashes: json['strongFlashes'] as bool? ?? true,
    haptics: json['haptics'] as bool? ?? true,
    music: json['music'] as bool? ?? true,
    sound: json['sound'] as bool? ?? true,
  );

  final bool leftHanded;
  final double controlScale;
  final double controlOpacity;
  final bool movementAssist;
  final bool reducedMotion;
  final bool strongFlashes;
  final bool haptics;
  final bool music;
  final bool sound;

  TennisSettings copyWith({
    bool? leftHanded,
    double? controlScale,
    double? controlOpacity,
    bool? movementAssist,
    bool? reducedMotion,
    bool? strongFlashes,
    bool? haptics,
    bool? music,
    bool? sound,
  }) => TennisSettings(
    leftHanded: leftHanded ?? this.leftHanded,
    controlScale: controlScale ?? this.controlScale,
    controlOpacity: controlOpacity ?? this.controlOpacity,
    movementAssist: movementAssist ?? this.movementAssist,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    strongFlashes: strongFlashes ?? this.strongFlashes,
    haptics: haptics ?? this.haptics,
    music: music ?? this.music,
    sound: sound ?? this.sound,
  );

  Map<String, dynamic> toJson() => {
    'leftHanded': leftHanded,
    'controlScale': controlScale,
    'controlOpacity': controlOpacity,
    'movementAssist': movementAssist,
    'reducedMotion': reducedMotion,
    'strongFlashes': strongFlashes,
    'haptics': haptics,
    'music': music,
    'sound': sound,
  };
}

class TennisMatchConfig {
  const TennisMatchConfig({
    required this.matchId,
    required this.mode,
    required this.playerId,
    required this.opponentId,
    required this.difficulty,
    required this.seed,
    this.trainingLesson,
    this.tournamentId,
    this.tournamentRound,
  });

  factory TennisMatchConfig.fromJson(Map<String, dynamic> json) =>
      TennisMatchConfig(
        matchId: json['matchId'] as String? ?? 'restored-match',
        mode: _enumByName(
          TennisMode.values,
          json['mode'],
          TennisMode.quickMatch,
        ),
        playerId: json['playerId'] as String? ?? tennisPlayers.first.id,
        opponentId: json['opponentId'] as String? ?? tennisPlayers[1].id,
        difficulty: _enumByName(
          TennisDifficulty.values,
          json['difficulty'],
          TennisDifficulty.pro,
        ),
        seed: _int(json['seed'], 1),
        trainingLesson: json['trainingLesson'] as int?,
        tournamentId: json['tournamentId'] as String?,
        tournamentRound: json['tournamentRound'] as int?,
      );

  final String matchId;
  final TennisMode mode;
  final String playerId;
  final String opponentId;
  final TennisDifficulty difficulty;
  final int seed;
  final int? trainingLesson;
  final String? tournamentId;
  final int? tournamentRound;

  Map<String, dynamic> toJson() => {
    'matchId': matchId,
    'mode': mode.name,
    'playerId': playerId,
    'opponentId': opponentId,
    'difficulty': difficulty.name,
    'seed': seed,
    'trainingLesson': trainingLesson,
    'tournamentId': tournamentId,
    'tournamentRound': tournamentRound,
  };
}

class TennisScoreState {
  const TennisScoreState({
    this.playerGames = 0,
    this.opponentGames = 0,
    this.playerPoints = 0,
    this.opponentPoints = 0,
    this.advantage = -1,
    this.tieBreak = false,
    this.playerTieBreak = 0,
    this.opponentTieBreak = 0,
    this.firstServer = 0,
    this.currentServer = 0,
    this.pointsInGame = 0,
    this.totalGames = 0,
    this.setWinner = -1,
    this.tieBreakFirstServer = 0,
  });

  factory TennisScoreState.fromJson(Map<String, dynamic> json) =>
      TennisScoreState(
        playerGames: _int(json['playerGames'], 0),
        opponentGames: _int(json['opponentGames'], 0),
        playerPoints: _int(json['playerPoints'], 0),
        opponentPoints: _int(json['opponentPoints'], 0),
        advantage: _int(json['advantage'], -1),
        tieBreak: json['tieBreak'] as bool? ?? false,
        playerTieBreak: _int(json['playerTieBreak'], 0),
        opponentTieBreak: _int(json['opponentTieBreak'], 0),
        firstServer: _int(json['firstServer'], 0),
        currentServer: _int(json['currentServer'], 0),
        pointsInGame: _int(json['pointsInGame'], 0),
        totalGames: _int(json['totalGames'], 0),
        setWinner: _int(json['setWinner'], -1),
        tieBreakFirstServer: _int(json['tieBreakFirstServer'], 0),
      );

  final int playerGames;
  final int opponentGames;
  final int playerPoints;
  final int opponentPoints;
  final int advantage;
  final bool tieBreak;
  final int playerTieBreak;
  final int opponentTieBreak;
  final int firstServer;
  final int currentServer;
  final int pointsInGame;
  final int totalGames;
  final int setWinner;
  final int tieBreakFirstServer;

  bool get isDeuce => !tieBreak && playerPoints >= 3 && opponentPoints >= 3;
  bool get complete => setWinner >= 0;
  bool get rightServiceCourt => pointsInGame.isEven;

  String pointLabel(int player) {
    if (tieBreak) {
      return '${player == 0 ? playerTieBreak : opponentTieBreak}';
    }
    if (advantage == player) return 'AD';
    if (isDeuce) return '40';
    final points = player == 0 ? playerPoints : opponentPoints;
    return switch (points.clamp(0, 3).toInt()) {
      0 => 'LOVE',
      1 => '15',
      2 => '30',
      _ => '40',
    };
  }

  Map<String, dynamic> toJson() => {
    'playerGames': playerGames,
    'opponentGames': opponentGames,
    'playerPoints': playerPoints,
    'opponentPoints': opponentPoints,
    'advantage': advantage,
    'tieBreak': tieBreak,
    'playerTieBreak': playerTieBreak,
    'opponentTieBreak': opponentTieBreak,
    'firstServer': firstServer,
    'currentServer': currentServer,
    'pointsInGame': pointsInGame,
    'totalGames': totalGames,
    'setWinner': setWinner,
    'tieBreakFirstServer': tieBreakFirstServer,
  };
}

class TennisMatchStats {
  const TennisMatchStats({
    this.durationSeconds = 0,
    this.aces = 0,
    this.doubleFaults = 0,
    this.winners = 0,
    this.unforcedErrors = 0,
    this.breakPointsWon = 0,
    this.breakPointsSaved = 0,
    this.maxBreakPointsSavedInGame = 0,
    this.firstServesIn = 0,
    this.firstServesAttempted = 0,
    this.perfectContacts = 0,
    this.longestRally = 0,
    this.netPointsWon = 0,
    this.totalPointsWon = 0,
    this.totalPointsLost = 0,
    this.staminaSpent = 0,
    this.cleanHolds = 0,
    this.comebackFromThreeGames = false,
    this.tiebreakNerve = false,
    this.wonTwentyShotRally = false,
    this.shotTypesUsed = const <TennisShotType>{},
  });

  factory TennisMatchStats.fromJson(
    Map<String, dynamic> json,
  ) => TennisMatchStats(
    durationSeconds: _int(json['durationSeconds'], 0),
    aces: _int(json['aces'], 0),
    doubleFaults: _int(json['doubleFaults'], 0),
    winners: _int(json['winners'], 0),
    unforcedErrors: _int(json['unforcedErrors'], 0),
    breakPointsWon: _int(json['breakPointsWon'], 0),
    breakPointsSaved: _int(json['breakPointsSaved'], 0),
    maxBreakPointsSavedInGame: _int(json['maxBreakPointsSavedInGame'], 0),
    firstServesIn: _int(json['firstServesIn'], 0),
    firstServesAttempted: _int(json['firstServesAttempted'], 0),
    perfectContacts: _int(json['perfectContacts'], 0),
    longestRally: _int(json['longestRally'], 0),
    netPointsWon: _int(json['netPointsWon'], 0),
    totalPointsWon: _int(json['totalPointsWon'], 0),
    totalPointsLost: _int(json['totalPointsLost'], 0),
    staminaSpent: _double(json['staminaSpent'], 0),
    cleanHolds: _int(json['cleanHolds'], 0),
    comebackFromThreeGames: json['comebackFromThreeGames'] as bool? ?? false,
    tiebreakNerve: json['tiebreakNerve'] as bool? ?? false,
    wonTwentyShotRally: json['wonTwentyShotRally'] as bool? ?? false,
    shotTypesUsed: _stringList(json['shotTypesUsed'])
        .map(
          (name) =>
              _enumByName(TennisShotType.values, name, TennisShotType.normal),
        )
        .toSet(),
  );

  final int durationSeconds;
  final int aces;
  final int doubleFaults;
  final int winners;
  final int unforcedErrors;
  final int breakPointsWon;
  final int breakPointsSaved;
  final int maxBreakPointsSavedInGame;
  final int firstServesIn;
  final int firstServesAttempted;
  final int perfectContacts;
  final int longestRally;
  final int netPointsWon;
  final int totalPointsWon;
  final int totalPointsLost;
  final double staminaSpent;
  final int cleanHolds;
  final bool comebackFromThreeGames;
  final bool tiebreakNerve;
  final bool wonTwentyShotRally;
  final Set<TennisShotType> shotTypesUsed;

  double get firstServePercentage =>
      firstServesAttempted == 0 ? 0 : firstServesIn / firstServesAttempted;

  int get totalPoints => totalPointsWon + totalPointsLost;

  Map<String, dynamic> toJson() => {
    'durationSeconds': durationSeconds,
    'aces': aces,
    'doubleFaults': doubleFaults,
    'winners': winners,
    'unforcedErrors': unforcedErrors,
    'breakPointsWon': breakPointsWon,
    'breakPointsSaved': breakPointsSaved,
    'maxBreakPointsSavedInGame': maxBreakPointsSavedInGame,
    'firstServesIn': firstServesIn,
    'firstServesAttempted': firstServesAttempted,
    'perfectContacts': perfectContacts,
    'longestRally': longestRally,
    'netPointsWon': netPointsWon,
    'totalPointsWon': totalPointsWon,
    'totalPointsLost': totalPointsLost,
    'staminaSpent': staminaSpent,
    'cleanHolds': cleanHolds,
    'comebackFromThreeGames': comebackFromThreeGames,
    'tiebreakNerve': tiebreakNerve,
    'wonTwentyShotRally': wonTwentyShotRally,
    'shotTypesUsed': shotTypesUsed.map((shot) => shot.name).toList(),
  };
}

class TennisMatchSummary {
  const TennisMatchSummary({
    required this.matchId,
    required this.mode,
    required this.playerId,
    required this.opponentId,
    required this.difficulty,
    required this.playerGames,
    required this.opponentGames,
    required this.won,
    required this.stats,
    this.practiceScore = 0,
    this.tournamentChampion = false,
    this.trainingLesson,
  });

  final String matchId;
  final TennisMode mode;
  final String playerId;
  final String opponentId;
  final TennisDifficulty difficulty;
  final int playerGames;
  final int opponentGames;
  final bool won;
  final TennisMatchStats stats;
  final int practiceScore;
  final bool tournamentChampion;
  final int? trainingLesson;

  int get performanceScore {
    final result = won ? 20 : (playerGames + 2 >= opponentGames ? 10 : 4);
    final difficultyScore = switch (difficulty) {
      TennisDifficulty.rookie => 2,
      TennisDifficulty.pro => 6,
      TennisDifficulty.allStar => 10,
    };
    final serve = (stats.firstServePercentage * 15).round().clamp(0, 15);
    final shotBalance = (8 + stats.winners - stats.unforcedErrors * 2).clamp(
      0,
      15,
    );
    final breakPlay = (stats.breakPointsWon * 3 + stats.breakPointsSaved * 2)
        .clamp(0, 10);
    final perfect = (stats.perfectContacts * 2).clamp(0, 10);
    final rally = (stats.longestRally / 2).round().clamp(0, 10);
    final stamina = (5 - stats.staminaSpent / 80).round().clamp(0, 5);
    final variety = stats.shotTypesUsed.length.clamp(0, 5);
    return (result +
            difficultyScore +
            serve +
            shotBalance +
            breakPlay +
            perfect +
            rally +
            stamina +
            variety)
        .clamp(0, 100)
        .toInt();
  }

  String get grade => switch (performanceScore) {
    >= 90 => 'S',
    >= 78 => 'A',
    >= 64 => 'B',
    >= 48 => 'C',
    _ => 'D',
  };

  Map<String, dynamic> toJson() => {
    'matchId': matchId,
    'mode': mode.name,
    'playerId': playerId,
    'opponentId': opponentId,
    'difficulty': difficulty.name,
    'playerGames': playerGames,
    'opponentGames': opponentGames,
    'won': won,
    'stats': stats.toJson(),
    'practiceScore': practiceScore,
    'tournamentChampion': tournamentChampion,
    'trainingLesson': trainingLesson,
  };
}

class TennisReward {
  const TennisReward({
    required this.xp,
    required this.coins,
    required this.masteryXp,
    required this.farmed,
  });

  static const zero = TennisReward(
    xp: 0,
    coins: 0,
    masteryXp: 0,
    farmed: false,
  );

  final int xp;
  final int coins;
  final int masteryXp;
  final bool farmed;
}

class TennisTournament {
  const TennisTournament({
    required this.id,
    required this.playerId,
    required this.difficulty,
    required this.entrants,
    required this.opponents,
    this.currentRound = 0,
    this.results = const <String>[],
    this.active = true,
    this.champion = false,
  });

  factory TennisTournament.fromJson(Map<String, dynamic> json) =>
      TennisTournament(
        id: json['id'] as String? ?? 'tournament',
        playerId: json['playerId'] as String? ?? tennisPlayers.first.id,
        difficulty: _enumByName(
          TennisDifficulty.values,
          json['difficulty'],
          TennisDifficulty.pro,
        ),
        entrants: _stringList(json['entrants']),
        opponents: _stringList(json['opponents']),
        currentRound: _int(json['currentRound'], 0),
        results: _stringList(json['results']),
        active: json['active'] as bool? ?? true,
        champion: json['champion'] as bool? ?? false,
      );

  final String id;
  final String playerId;
  final TennisDifficulty difficulty;
  final List<String> entrants;
  final List<String> opponents;
  final int currentRound;
  final List<String> results;
  final bool active;
  final bool champion;

  String? get currentOpponentId => active && currentRound < opponents.length
      ? opponents[currentRound]
      : null;

  TennisTournament copyWith({
    int? currentRound,
    List<String>? results,
    bool? active,
    bool? champion,
  }) => TennisTournament(
    id: id,
    playerId: playerId,
    difficulty: difficulty,
    entrants: entrants,
    opponents: opponents,
    currentRound: currentRound ?? this.currentRound,
    results: results ?? this.results,
    active: active ?? this.active,
    champion: champion ?? this.champion,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'playerId': playerId,
    'difficulty': difficulty.name,
    'entrants': entrants,
    'opponents': opponents,
    'currentRound': currentRound,
    'results': results,
    'active': active,
    'champion': champion,
  };
}

class TennisProfile {
  const TennisProfile({
    this.schemaVersion = 1,
    this.starterPackClaimed = false,
    this.ownedPlayerIds = const <String>[],
    this.selectedPlayerId = 'arthur-fery',
    this.lastOpponentId = 'alexander-blockx',
    this.difficulty = TennisDifficulty.pro,
    this.settings = const TennisSettings(),
    this.setsPlayed = 0,
    this.setsWon = 0,
    this.currentWinStreak = 0,
    this.bestWinStreak = 0,
    this.totalAces = 0,
    this.longestRally = 0,
    this.cleanHolds = 0,
    this.breaksConverted = 0,
    this.breakPointsSaved = 0,
    this.netPointsWon = 0,
    this.serveVolleyNetPoints = 0,
    this.comebackSets = 0,
    this.tiebreakNerveWins = 0,
    this.stylesWon = const <TennisArchetype>{},
    this.achievements = const <String>{},
    this.masteryXp = const <String, int>{},
    this.completedLessons = const <int>{},
    this.trophies = const <String, int>{},
    this.bestEndless = 0,
    this.bestTarget = 0,
    this.lastQuickSignature,
    this.quickRepeatCount = 0,
    this.settledMatchIds = const <String>[],
    this.tournament,
  });

  factory TennisProfile.fromJson(Map<String, dynamic> json) {
    final selectedPlayerId =
        json['selectedPlayerId'] as String? ?? tennisPlayers.first.id;
    final hasStarterFields =
        json.containsKey('starterPackClaimed') ||
        json.containsKey('ownedPlayerIds');
    final claimed = json['starterPackClaimed'] as bool? ?? !hasStarterFields;
    final owned = _stringList(json['ownedPlayerIds']);
    final ownedPlayerIds = owned.isNotEmpty || !claimed
        ? owned
        : <String>[selectedPlayerId];
    return TennisProfile(
      schemaVersion: _int(json['schemaVersion'], 1),
      starterPackClaimed: claimed,
      ownedPlayerIds: ownedPlayerIds,
      selectedPlayerId: selectedPlayerId,
      lastOpponentId: json['lastOpponentId'] as String? ?? tennisPlayers[1].id,
      difficulty: _enumByName(
        TennisDifficulty.values,
        json['difficulty'],
        TennisDifficulty.pro,
      ),
      settings: TennisSettings.fromJson(_map(json['settings'])),
      setsPlayed: _int(json['setsPlayed'], 0),
      setsWon: _int(json['setsWon'], 0),
      currentWinStreak: _int(json['currentWinStreak'], 0),
      bestWinStreak: _int(json['bestWinStreak'], 0),
      totalAces: _int(json['totalAces'], 0),
      longestRally: _int(json['longestRally'], 0),
      cleanHolds: _int(json['cleanHolds'], 0),
      breaksConverted: _int(json['breaksConverted'], 0),
      breakPointsSaved: _int(json['breakPointsSaved'], 0),
      netPointsWon: _int(json['netPointsWon'], 0),
      serveVolleyNetPoints: _int(json['serveVolleyNetPoints'], 0),
      comebackSets: _int(json['comebackSets'], 0),
      tiebreakNerveWins: _int(json['tiebreakNerveWins'], 0),
      stylesWon: _stringList(json['stylesWon'])
          .map(
            (name) => _enumByName(
              TennisArchetype.values,
              name,
              TennisArchetype.allRounder,
            ),
          )
          .toSet(),
      achievements: _stringList(json['achievements']).toSet(),
      masteryXp: _intMap(json['masteryXp']),
      completedLessons: _intSet(json['completedLessons']),
      trophies: _intMap(json['trophies']),
      bestEndless: _int(json['bestEndless'], 0),
      bestTarget: _int(json['bestTarget'], 0),
      lastQuickSignature: json['lastQuickSignature'] as String?,
      quickRepeatCount: _int(json['quickRepeatCount'], 0),
      settledMatchIds: _stringList(json['settledMatchIds']),
      tournament: json['tournament'] is Map
          ? TennisTournament.fromJson(_map(json['tournament']))
          : null,
    );
  }

  final int schemaVersion;
  final bool starterPackClaimed;
  final List<String> ownedPlayerIds;
  final String selectedPlayerId;
  final String lastOpponentId;
  final TennisDifficulty difficulty;
  final TennisSettings settings;
  final int setsPlayed;
  final int setsWon;
  final int currentWinStreak;
  final int bestWinStreak;
  final int totalAces;
  final int longestRally;
  final int cleanHolds;
  final int breaksConverted;
  final int breakPointsSaved;
  final int netPointsWon;
  final int serveVolleyNetPoints;
  final int comebackSets;
  final int tiebreakNerveWins;
  final Set<TennisArchetype> stylesWon;
  final Set<String> achievements;
  final Map<String, int> masteryXp;
  final Set<int> completedLessons;
  final Map<String, int> trophies;
  final int bestEndless;
  final int bestTarget;
  final String? lastQuickSignature;
  final int quickRepeatCount;
  final List<String> settledMatchIds;
  final TennisTournament? tournament;

  int masteryFor(String playerId) => masteryXp[playerId] ?? 0;

  int masteryLevel(String playerId) {
    var remaining = masteryFor(playerId);
    var level = 1;
    while (level < 10 && remaining >= level * 100) {
      remaining -= level * 100;
      level++;
    }
    return level;
  }

  double masteryProgress(String playerId) {
    var remaining = masteryFor(playerId);
    var level = 1;
    while (level < 10 && remaining >= level * 100) {
      remaining -= level * 100;
      level++;
    }
    if (level >= 10) return 1;
    return (remaining / (level * 100)).clamp(0, 1).toDouble();
  }

  bool ownsPlayer(String playerId) => ownedPlayerIds.contains(playerId);

  /// Playable athletes are exactly the ones the player has collected. Tennis
  /// shares the card economy with the other sports now, so cards beyond the
  /// starter are earned through packs rather than hardcoded unlock rules.
  bool isPlayerUnlocked(String playerId) => ownsPlayer(playerId);

  TennisProfile copyWith({
    bool? starterPackClaimed,
    List<String>? ownedPlayerIds,
    String? selectedPlayerId,
    String? lastOpponentId,
    TennisDifficulty? difficulty,
    TennisSettings? settings,
    int? setsPlayed,
    int? setsWon,
    int? currentWinStreak,
    int? bestWinStreak,
    int? totalAces,
    int? longestRally,
    int? cleanHolds,
    int? breaksConverted,
    int? breakPointsSaved,
    int? netPointsWon,
    int? serveVolleyNetPoints,
    int? comebackSets,
    int? tiebreakNerveWins,
    Set<TennisArchetype>? stylesWon,
    Set<String>? achievements,
    Map<String, int>? masteryXp,
    Set<int>? completedLessons,
    Map<String, int>? trophies,
    int? bestEndless,
    int? bestTarget,
    String? lastQuickSignature,
    int? quickRepeatCount,
    List<String>? settledMatchIds,
    TennisTournament? tournament,
    bool clearTournament = false,
  }) => TennisProfile(
    schemaVersion: schemaVersion,
    starterPackClaimed: starterPackClaimed ?? this.starterPackClaimed,
    ownedPlayerIds: ownedPlayerIds ?? this.ownedPlayerIds,
    selectedPlayerId: selectedPlayerId ?? this.selectedPlayerId,
    lastOpponentId: lastOpponentId ?? this.lastOpponentId,
    difficulty: difficulty ?? this.difficulty,
    settings: settings ?? this.settings,
    setsPlayed: setsPlayed ?? this.setsPlayed,
    setsWon: setsWon ?? this.setsWon,
    currentWinStreak: currentWinStreak ?? this.currentWinStreak,
    bestWinStreak: bestWinStreak ?? this.bestWinStreak,
    totalAces: totalAces ?? this.totalAces,
    longestRally: longestRally ?? this.longestRally,
    cleanHolds: cleanHolds ?? this.cleanHolds,
    breaksConverted: breaksConverted ?? this.breaksConverted,
    breakPointsSaved: breakPointsSaved ?? this.breakPointsSaved,
    netPointsWon: netPointsWon ?? this.netPointsWon,
    serveVolleyNetPoints: serveVolleyNetPoints ?? this.serveVolleyNetPoints,
    comebackSets: comebackSets ?? this.comebackSets,
    tiebreakNerveWins: tiebreakNerveWins ?? this.tiebreakNerveWins,
    stylesWon: stylesWon ?? this.stylesWon,
    achievements: achievements ?? this.achievements,
    masteryXp: masteryXp ?? this.masteryXp,
    completedLessons: completedLessons ?? this.completedLessons,
    trophies: trophies ?? this.trophies,
    bestEndless: bestEndless ?? this.bestEndless,
    bestTarget: bestTarget ?? this.bestTarget,
    lastQuickSignature: lastQuickSignature ?? this.lastQuickSignature,
    quickRepeatCount: quickRepeatCount ?? this.quickRepeatCount,
    settledMatchIds: settledMatchIds ?? this.settledMatchIds,
    tournament: clearTournament ? null : (tournament ?? this.tournament),
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'starterPackClaimed': starterPackClaimed,
    'ownedPlayerIds': ownedPlayerIds,
    'selectedPlayerId': selectedPlayerId,
    'lastOpponentId': lastOpponentId,
    'difficulty': difficulty.name,
    'settings': settings.toJson(),
    'setsPlayed': setsPlayed,
    'setsWon': setsWon,
    'currentWinStreak': currentWinStreak,
    'bestWinStreak': bestWinStreak,
    'totalAces': totalAces,
    'longestRally': longestRally,
    'cleanHolds': cleanHolds,
    'breaksConverted': breaksConverted,
    'breakPointsSaved': breakPointsSaved,
    'netPointsWon': netPointsWon,
    'serveVolleyNetPoints': serveVolleyNetPoints,
    'comebackSets': comebackSets,
    'tiebreakNerveWins': tiebreakNerveWins,
    'stylesWon': stylesWon.map((style) => style.name).toList(),
    'achievements': achievements.toList(),
    'masteryXp': masteryXp,
    'completedLessons': completedLessons.toList(),
    'trophies': trophies,
    'bestEndless': bestEndless,
    'bestTarget': bestTarget,
    'lastQuickSignature': lastQuickSignature,
    'quickRepeatCount': quickRepeatCount,
    'settledMatchIds': settledMatchIds,
    'tournament': tournament?.toJson(),
  };
}

class TennisMatchSnapshot {
  const TennisMatchSnapshot({
    this.schemaVersion = 1,
    required this.config,
    required this.engine,
    required this.savedAtMillis,
  });

  factory TennisMatchSnapshot.fromJson(Map<String, dynamic> json) =>
      TennisMatchSnapshot(
        schemaVersion: _int(json['schemaVersion'], 1),
        config: TennisMatchConfig.fromJson(_map(json['config'])),
        engine: _map(json['engine']),
        savedAtMillis: _int(json['savedAtMillis'], 0),
      );

  final int schemaVersion;
  final TennisMatchConfig config;
  final Map<String, dynamic> engine;
  final int savedAtMillis;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'config': config.toJson(),
    'engine': engine,
    'savedAtMillis': savedAtMillis,
  };
}

TennisReward calculateTennisReward(
  TennisMatchSummary summary,
  TennisProfile profile,
) {
  if (summary.mode == TennisMode.training) {
    final first =
        summary.trainingLesson != null &&
        !profile.completedLessons.contains(summary.trainingLesson);
    return TennisReward(
      xp: first ? 5 : 0,
      coins: 0,
      masteryXp: first ? 8 : 2,
      farmed: false,
    );
  }
  if (summary.mode == TennisMode.endlessRally ||
      summary.mode == TennisMode.targetPractice) {
    return TennisReward(
      xp: min(12, summary.practiceScore ~/ 100),
      coins: 0,
      masteryXp: min(12, summary.practiceScore ~/ 80),
      farmed: false,
    );
  }

  final signature =
      '${summary.playerId}:${summary.opponentId}:'
      '${summary.difficulty.name}';
  final repeatedRookie =
      summary.mode == TennisMode.quickMatch &&
      summary.difficulty == TennisDifficulty.rookie &&
      profile.lastQuickSignature == signature &&
      profile.quickRepeatCount >= 3;
  final gradeBonus = switch (summary.grade) {
    'S' => 10,
    'A' => 7,
    'B' => 4,
    'C' => 2,
    _ => 0,
  };
  final performanceBonus = min(
    8,
    min(3, summary.stats.aces) +
        (summary.stats.longestRally >= 20 ? 2 : 0) +
        (summary.stats.comebackFromThreeGames ? 2 : 0) +
        (summary.stats.breakPointsSaved >= 3 ? 2 : 0),
  );
  var xp = 12;
  var coins = 0;
  if (summary.won) {
    xp += 10;
    coins = repeatedRookie ? 10 : summary.difficulty.winCoins;
  }
  if (!repeatedRookie) {
    xp += summary.difficulty.xpBonus + gradeBonus + performanceBonus;
  }
  if (summary.mode == TennisMode.tournament && summary.won) {
    coins = (coins * 1.25).round();
    if (summary.tournamentChampion) {
      xp += 30;
      coins += 75;
    }
  }
  final masteryGrade = switch (summary.grade) {
    'S' => 20,
    'A' => 15,
    'B' => 10,
    'C' => 5,
    _ => 0,
  };
  final mastery =
      20 +
      (summary.won ? 20 : 0) +
      masteryGrade +
      min(10, summary.stats.shotTypesUsed.length * 2).toInt();
  return TennisReward(
    xp: xp,
    coins: coins,
    masteryXp: mastery,
    farmed: repeatedRookie,
  );
}

T _enumByName<T extends Enum>(Iterable<T> values, Object? raw, T fallback) {
  final name = raw?.toString();
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

int _int(Object? value, int fallback) =>
    value is num ? value.toInt() : fallback;

double _double(Object? value, double fallback) =>
    value is num ? value.toDouble() : fallback;

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<String> _stringList(Object? value) => value is List
    ? value.whereType<Object>().map((item) => item.toString()).toList()
    : <String>[];

Map<String, int> _intMap(Object? value) {
  if (value is! Map) return <String, int>{};
  return {
    for (final entry in value.entries)
      entry.key.toString(): entry.value is num
          ? (entry.value as num).toInt()
          : 0,
  };
}

Set<int> _intSet(Object? value) => value is List
    ? value.whereType<num>().map((item) => item.toInt()).toSet()
    : <int>{};
