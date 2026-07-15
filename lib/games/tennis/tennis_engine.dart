import 'dart:math';

import '../../models/tennis.dart';

const double tennisCourtHalfWidth = 4.115;
const double tennisCourtHalfLength = 11.885;
const double tennisServiceLine = 6.40;
const double tennisNetHeight = 0.914;
const double tennisGravity = -9.8;

bool tennisBallInsideSingles(double x, double y) =>
    x.abs() <= tennisCourtHalfWidth + 0.001 &&
    y.abs() <= tennisCourtHalfLength + 0.001;

bool tennisServeInsideBox({
  required double x,
  required double y,
  required int server,
  required bool rightServiceCourt,
}) {
  final expectedSide = rightServiceCourt ? 1.0 : -1.0;
  final boxSide = server == 0 ? expectedSide : -expectedSide;
  final correctHalf = x.abs() <= 0.001 || x.sign == boxSide.sign;
  final correctDepth = server == 0
      ? y <= 0.001 && y >= -tennisServiceLine - 0.001
      : y >= -0.001 && y <= tennisServiceLine + 0.001;
  return x.abs() <= tennisCourtHalfWidth + 0.001 && correctHalf && correctDepth;
}

class TennisIntent {
  const TennisIntent({
    this.moveX = 0,
    this.moveY = 0,
    this.sprint = false,
    this.shotDown = false,
    this.shotPressed = false,
    this.shotReleased = false,
    this.holdSeconds = 0,
    this.aimX = 0,
    this.aimY = 0,
    this.serveAim = 0,
  });

  static const idle = TennisIntent();

  final double moveX;
  final double moveY;
  final bool sprint;
  final bool shotDown;
  final bool shotPressed;
  final bool shotReleased;
  final double holdSeconds;
  final double aimX;
  final double aimY;

  /// -1 = wide, 0 = body, 1 = centre/T.
  final int serveAim;
}

enum TennisEventType {
  serveStarted,
  contact,
  perfectContact,
  bounce,
  net,
  let,
  fault,
  doubleFault,
  ace,
  out,
  winner,
  pointEnded,
  gameEnded,
  endChange,
  tieBreakStarted,
  setEnded,
  rallyMilestone,
  practiceScore,
  lessonComplete,
}

class TennisEvent {
  const TennisEvent(
    this.type, {
    this.team,
    this.label,
    this.value,
    this.shot,
    this.timing,
  });

  final TennisEventType type;
  final int? team;
  final String? label;
  final int? value;
  final TennisShotType? shot;
  final TennisTimingGrade? timing;
}

class TennisPointResult {
  const TennisPointResult({
    required this.winner,
    required this.gameWon,
    required this.setWon,
    required this.tieBreakStarted,
    required this.endChange,
    required this.breakPointConverted,
    required this.breakPointSaved,
  });

  final int winner;
  final bool gameWon;
  final bool setWon;
  final bool tieBreakStarted;
  final bool endChange;
  final bool breakPointConverted;
  final bool breakPointSaved;
}

/// Pure tennis scorekeeper. It has no Flutter or Flame dependency and can be
/// driven directly by unit tests.
class TennisScoring {
  TennisScoring({required int firstServer})
    : _state = TennisScoreState(
        firstServer: firstServer,
        currentServer: firstServer,
        tieBreakFirstServer: firstServer,
      );

  TennisScoring.fromState(TennisScoreState state) : _state = state;

  TennisScoreState _state;
  TennisScoreState get state => _state;

  bool isBreakPointFor(int player) {
    if (_state.tieBreak || player == _state.currentServer) return false;
    return _wouldWinGame(player);
  }

  bool isSetPointFor(int player) {
    if (_state.complete) return false;
    final clone = TennisScoring.fromState(
      TennisScoreState.fromJson(_state.toJson()),
    );
    return clone.awardPoint(player).setWon;
  }

  bool _wouldWinGame(int player) {
    final mine = player == 0 ? _state.playerPoints : _state.opponentPoints;
    final theirs = player == 0 ? _state.opponentPoints : _state.playerPoints;
    if (_state.advantage == player) return true;
    return mine >= 3 && theirs <= 2;
  }

  TennisPointResult awardPoint(int winner) {
    if (_state.complete) {
      return TennisPointResult(
        winner: winner,
        gameWon: false,
        setWon: true,
        tieBreakStarted: false,
        endChange: false,
        breakPointConverted: false,
        breakPointSaved: false,
      );
    }

    final serverBefore = _state.currentServer;
    final receiverBefore = 1 - serverBefore;
    final wasBreakPoint = isBreakPointFor(receiverBefore);
    var playerGames = _state.playerGames;
    var opponentGames = _state.opponentGames;
    var playerPoints = _state.playerPoints;
    var opponentPoints = _state.opponentPoints;
    var advantage = _state.advantage;
    var playerTieBreak = _state.playerTieBreak;
    var opponentTieBreak = _state.opponentTieBreak;
    var tieBreak = _state.tieBreak;
    var tieBreakFirstServer = _state.tieBreakFirstServer;
    var currentServer = _state.currentServer;
    var pointsInGame = _state.pointsInGame + 1;
    var totalGames = _state.totalGames;
    var setWinner = -1;
    var gameWon = false;
    var tieBreakStarted = false;
    var endChange = false;

    if (tieBreak) {
      if (winner == 0) {
        playerTieBreak++;
      } else {
        opponentTieBreak++;
      }
      final mine = winner == 0 ? playerTieBreak : opponentTieBreak;
      final theirs = winner == 0 ? opponentTieBreak : playerTieBreak;
      if (mine >= 7 && mine - theirs >= 2) {
        setWinner = winner;
        playerGames = winner == 0 ? 7 : 6;
        opponentGames = winner == 1 ? 7 : 6;
      } else {
        final nextPoint = playerTieBreak + opponentTieBreak;
        if (nextPoint > 0 && nextPoint % 6 == 0) endChange = true;
        currentServer = _tieBreakServer(tieBreakFirstServer, nextPoint);
      }
    } else {
      if (playerPoints >= 3 && opponentPoints >= 3) {
        if (advantage == winner) {
          gameWon = true;
        } else if (advantage == 1 - winner) {
          advantage = -1;
        } else {
          advantage = winner;
        }
      } else {
        if (winner == 0) {
          playerPoints++;
        } else {
          opponentPoints++;
        }
        final mine = winner == 0 ? playerPoints : opponentPoints;
        final theirs = winner == 0 ? opponentPoints : playerPoints;
        if (mine >= 4 && mine - theirs >= 2) gameWon = true;
      }

      if (gameWon) {
        if (winner == 0) {
          playerGames++;
        } else {
          opponentGames++;
        }
        totalGames++;
        playerPoints = 0;
        opponentPoints = 0;
        advantage = -1;
        pointsInGame = 0;
        currentServer = 1 - currentServer;
        final mine = winner == 0 ? playerGames : opponentGames;
        final theirs = winner == 0 ? opponentGames : playerGames;
        if (mine >= 6 && mine - theirs >= 2) {
          setWinner = winner;
        } else if (playerGames == 6 && opponentGames == 6) {
          tieBreak = true;
          tieBreakStarted = true;
          tieBreakFirstServer = currentServer;
          currentServer = tieBreakFirstServer;
        }
        if (setWinner < 0 && totalGames.isEven) endChange = true;
      }
    }

    _state = TennisScoreState(
      playerGames: playerGames,
      opponentGames: opponentGames,
      playerPoints: playerPoints,
      opponentPoints: opponentPoints,
      advantage: advantage,
      tieBreak: tieBreak,
      playerTieBreak: playerTieBreak,
      opponentTieBreak: opponentTieBreak,
      firstServer: _state.firstServer,
      currentServer: currentServer,
      pointsInGame: pointsInGame,
      totalGames: totalGames,
      setWinner: setWinner,
      tieBreakFirstServer: tieBreakFirstServer,
    );
    return TennisPointResult(
      winner: winner,
      gameWon: gameWon,
      setWon: setWinner >= 0,
      tieBreakStarted: tieBreakStarted,
      endChange: endChange,
      breakPointConverted: wasBreakPoint && winner == receiverBefore && gameWon,
      breakPointSaved: wasBreakPoint && winner == serverBefore,
    );
  }

  static int _tieBreakServer(int first, int pointIndex) {
    if (pointIndex == 0) return first;
    final block = (pointIndex - 1) ~/ 2;
    return block.isEven ? 1 - first : first;
  }
}

class TennisBody {
  TennisBody({required this.team, required this.spec});

  final int team;
  final TennisPlayer spec;
  double x = 0;
  double y = 0;
  double stamina = 100;
  double focus = 0;
  double swingT = 0;
  TennisShotType? swingShot;
  TennisTimingGrade? lastTiming;

  double get stamina01 => stamina / 100;
  double get focus01 => focus / 100;

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'stamina': stamina,
    'focus': focus,
    'swingT': swingT,
    'swingShot': swingShot?.name,
    'lastTiming': lastTiming?.name,
  };

  void restore(Map<String, dynamic> json) {
    x = _num(json['x'], 0);
    y = _num(json['y'], team == 0 ? 9 : -9);
    stamina = _num(json['stamina'], 100).clamp(0, 100).toDouble();
    focus = _num(json['focus'], 0).clamp(0, 100).toDouble();
    swingT = _num(json['swingT'], 0);
    swingShot = _nullableEnum(TennisShotType.values, json['swingShot']);
    lastTiming = _nullableEnum(TennisTimingGrade.values, json['lastTiming']);
  }
}

class TennisBall {
  double x = 0;
  double y = 0;
  double z = 0;
  double vx = 0;
  double vy = 0;
  double vz = 0;
  int bounces = 0;
  int lastHitter = 1;
  bool live = false;
  bool serve = false;
  bool netTouched = false;
  TennisShotType shot = TennisShotType.normal;

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'z': z,
    'vx': vx,
    'vy': vy,
    'vz': vz,
    'bounces': bounces,
    'lastHitter': lastHitter,
    'live': live,
    'serve': serve,
    'netTouched': netTouched,
    'shot': shot.name,
  };

  void restore(Map<String, dynamic> json) {
    x = _num(json['x'], 0);
    y = _num(json['y'], 0);
    z = _num(json['z'], 0);
    vx = _num(json['vx'], 0);
    vy = _num(json['vy'], 0);
    vz = _num(json['vz'], 0);
    bounces = _integer(json['bounces'], 0);
    lastHitter = _integer(json['lastHitter'], 1);
    live = json['live'] as bool? ?? false;
    serve = json['serve'] as bool? ?? false;
    netTouched = json['netTouched'] as bool? ?? false;
    shot = _enum(TennisShotType.values, json['shot'], TennisShotType.normal);
  }
}

class _QueuedShot {
  _QueuedShot({
    required this.at,
    required this.holdSeconds,
    required this.aimX,
    required this.aimY,
    required this.serveAim,
  });

  final double at;
  final double holdSeconds;
  final double aimX;
  final double aimY;
  final int serveAim;
}

class _MutableStats {
  int aces = 0;
  int doubleFaults = 0;
  int winners = 0;
  int unforcedErrors = 0;
  int breakPointsWon = 0;
  int breakPointsSaved = 0;
  int breakPointsSavedCurrentGame = 0;
  int maxBreakPointsSavedInGame = 0;
  int firstServesIn = 0;
  int firstServesAttempted = 0;
  int perfectContacts = 0;
  int longestRally = 0;
  int netPointsWon = 0;
  int totalPointsWon = 0;
  int totalPointsLost = 0;
  double staminaSpent = 0;
  int cleanHolds = 0;
  bool comeback = false;
  bool tiebreakNerve = false;
  bool wonTwentyShotRally = false;
  final Set<TennisShotType> shots = <TennisShotType>{};
  int maxDeficit = 0;
  int pointsLostCurrentServiceGame = 0;

  TennisMatchStats freeze(int durationSeconds) => TennisMatchStats(
    durationSeconds: durationSeconds,
    aces: aces,
    doubleFaults: doubleFaults,
    winners: winners,
    unforcedErrors: unforcedErrors,
    breakPointsWon: breakPointsWon,
    breakPointsSaved: breakPointsSaved,
    maxBreakPointsSavedInGame: maxBreakPointsSavedInGame,
    firstServesIn: firstServesIn,
    firstServesAttempted: firstServesAttempted,
    perfectContacts: perfectContacts,
    longestRally: longestRally,
    netPointsWon: netPointsWon,
    totalPointsWon: totalPointsWon,
    totalPointsLost: totalPointsLost,
    staminaSpent: staminaSpent,
    cleanHolds: cleanHolds,
    comebackFromThreeGames: comeback,
    tiebreakNerve: tiebreakNerve,
    wonTwentyShotRally: wonTwentyShotRally,
    shotTypesUsed: Set<TennisShotType>.unmodifiable(shots),
  );

  Map<String, dynamic> toJson() => freeze(0).toJson()
    ..['maxDeficit'] = maxDeficit
    ..['pointsLostCurrentServiceGame'] = pointsLostCurrentServiceGame
    ..['breakPointsSavedCurrentGame'] = breakPointsSavedCurrentGame;

  void restore(Map<String, dynamic> json) {
    final frozen = TennisMatchStats.fromJson(json);
    aces = frozen.aces;
    doubleFaults = frozen.doubleFaults;
    winners = frozen.winners;
    unforcedErrors = frozen.unforcedErrors;
    breakPointsWon = frozen.breakPointsWon;
    breakPointsSaved = frozen.breakPointsSaved;
    maxBreakPointsSavedInGame = frozen.maxBreakPointsSavedInGame;
    firstServesIn = frozen.firstServesIn;
    firstServesAttempted = frozen.firstServesAttempted;
    perfectContacts = frozen.perfectContacts;
    longestRally = frozen.longestRally;
    netPointsWon = frozen.netPointsWon;
    totalPointsWon = frozen.totalPointsWon;
    totalPointsLost = frozen.totalPointsLost;
    staminaSpent = frozen.staminaSpent;
    cleanHolds = frozen.cleanHolds;
    comeback = frozen.comebackFromThreeGames;
    tiebreakNerve = frozen.tiebreakNerve;
    wonTwentyShotRally = frozen.wonTwentyShotRally;
    shots
      ..clear()
      ..addAll(frozen.shotTypesUsed);
    maxDeficit = _integer(json['maxDeficit'], 0);
    pointsLostCurrentServiceGame = _integer(
      json['pointsLostCurrentServiceGame'],
      0,
    );
    breakPointsSavedCurrentGame = _integer(
      json['breakPointsSavedCurrentGame'],
      0,
    );
  }
}

class TennisRandom {
  TennisRandom(int seed) : state = seed & 0x7fffffff;

  int state;

  double nextDouble() {
    state = (1103515245 * state + 12345) & 0x7fffffff;
    return state / 0x80000000;
  }

  int nextInt(int max) =>
      (nextDouble() * max).floor().clamp(0, max - 1).toInt();
}

class TennisEngine {
  TennisEngine(
    this.config, {
    this.movementAssist = true,
    Map<String, dynamic>? snapshot,
  }) : random = TennisRandom(config.seed),
       player = TennisBody(team: 0, spec: tennisPlayerById(config.playerId)),
       opponent = TennisBody(
         team: 1,
         spec: tennisPlayerById(config.opponentId),
       ),
       scoring = TennisScoring(
         firstServer: config.mode == TennisMode.training
             ? 0
             : (config.seed.isEven ? 0 : 1),
       ) {
    if (snapshot == null) {
      _resetBodies();
      _startPoint(initial: true);
    } else {
      _restore(snapshot);
    }
  }

  final TennisMatchConfig config;
  bool movementAssist;
  final TennisRandom random;
  final TennisBody player;
  final TennisBody opponent;
  final TennisBall ball = TennisBall();
  late TennisScoring scoring;
  final _MutableStats _stats = _MutableStats();

  TennisMatchPhase phase = TennisMatchPhase.preServe;
  int serveNumber = 1;
  double serveMeter = 0;
  bool serveMeterRising = true;
  int rallyCount = 0;
  int practiceScore = 0;
  int ballsRemaining = 20;
  int lessonProgress = 0;
  int targetIndex = 0;
  int flightId = 0;
  double targetX = 0;
  double targetY = -8;
  double elapsed = 0;
  double pointResetT = 0;
  bool paused = false;
  bool focusPointActive = false;
  bool endSwapped = false;

  _QueuedShot? _playerShot;
  _QueuedShot? _opponentShot;
  double _playerHold = 0;
  double _opponentHold = 0;
  bool _trainingAimLeft = false;
  bool _trainingAimRight = false;
  bool _trainingSprintUsed = false;
  bool _serveContinuation = false;
  bool _playerSavedTieBreakSetPoint = false;
  int _opponentMissLockedFlightId = -1;
  final List<TennisEvent> _events = <TennisEvent>[];

  TennisScoreState get score => scoring.state;
  bool get complete =>
      phase == TennisMatchPhase.setComplete ||
      phase == TennisMatchPhase.practiceComplete;
  TennisBody bodyFor(int team) => team == 0 ? player : opponent;

  bool canHit(int team) {
    if (!ball.live || phase != TennisMatchPhase.rally) return false;
    if (config.mode == TennisMode.targetPractice && team == 1) return false;
    // A player cannot strike their own live shot again. Without this guard the
    // AI can generate a contact on consecutive fixed steps while the ball is
    // still inside its reach, repeatedly relaunching the same trajectory.
    if (ball.lastHitter == team) return false;
    if (team == 0 && ball.y < 0) return false;
    if (team == 1 && ball.y > 0) return false;
    final body = bodyFor(team);
    final reach = 0.75 + body.spec.ratings.reach / 100 * 0.65;
    final distance = sqrt(pow(ball.x - body.x, 2) + pow(ball.y - body.y, 2));
    return distance <= reach && ball.z >= 0.18 && ball.z <= 2.8;
  }

  List<TennisEvent> step(
    TennisIntent playerIntent,
    TennisIntent opponentIntent,
    double dt,
  ) {
    _events.clear();
    if (paused || complete) return const <TennisEvent>[];
    final safeDt = dt.clamp(0, 1 / 30).toDouble();
    elapsed += safeDt;
    if (config.mode == TennisMode.targetPractice && elapsed >= 90) {
      _finishPractice();
      return List<TennisEvent>.unmodifiable(_events);
    }

    _updateBody(player, playerIntent, safeDt);
    _updateBody(opponent, opponentIntent, safeDt);
    _captureIntent(0, playerIntent, safeDt);
    _captureIntent(1, opponentIntent, safeDt);

    if (phase == TennisMatchPhase.pointComplete) {
      pointResetT -= safeDt;
      if (pointResetT <= 0) _startPoint();
    } else if (phase == TennisMatchPhase.preServe ||
        phase == TennisMatchPhase.serving) {
      _updateServe(playerIntent, opponentIntent, safeDt);
    } else if (phase == TennisMatchPhase.rally) {
      _tryContact(0);
      _tryContact(1);
      _updateBall(safeDt);
    }

    player.swingT = max(0, player.swingT - safeDt);
    opponent.swingT = max(0, opponent.swingT - safeDt);
    return List<TennisEvent>.unmodifiable(_events);
  }

  void _updateBody(TennisBody body, TennisIntent intent, double dt) {
    if (phase == TennisMatchPhase.pointComplete) {
      _recover(body, dt * 0.8);
      return;
    }
    var mx = intent.moveX.clamp(-1, 1).toDouble();
    var my = intent.moveY.clamp(-1, 1).toDouble();
    if (body.team == 0 &&
        movementAssist &&
        mx.abs() + my.abs() < 0.08 &&
        ball.live &&
        ball.y > 0) {
      mx = ((ball.x - body.x) * 0.22).clamp(-0.36, 0.36).toDouble();
      my = ((ball.y - body.y) * 0.12).clamp(-0.24, 0.24).toDouble();
    }
    final length = sqrt(mx * mx + my * my);
    if (length > 1) {
      mx /= length;
      my /= length;
    }
    final rating = body.spec.ratings;
    final tired = 0.70 + body.stamina01 * 0.30;
    final sprinting = intent.sprint && body.stamina > 8;
    final speed =
        (3.5 + rating.speed / 100 * 2.4) * tired * (sprinting ? 1.35 : 1);
    body.x += mx * speed * dt;
    body.y += my * speed * dt;
    body.x = body.x
        .clamp(-tennisCourtHalfWidth - 1.1, tennisCourtHalfWidth + 1.1)
        .toDouble();
    if (body.team == 0) {
      body.y = body.y.clamp(0.75, tennisCourtHalfLength + 1.1).toDouble();
    } else {
      body.y = body.y.clamp(-tennisCourtHalfLength - 1.1, -0.75).toDouble();
    }
    if (length > 0.05) {
      final drain = (sprinting ? 7.2 : 0.65) * length * dt;
      body.stamina = max(0, body.stamina - drain);
      if (body.team == 0) _stats.staminaSpent += drain;
    } else {
      body.stamina = min(100, body.stamina + 3.0 * dt);
    }
    if (body.team == 0 && intent.sprint) _trainingSprintUsed = true;
  }

  void _recover(TennisBody body, double dt) {
    final targetY = body.team == 0 ? 8.8 : -8.8;
    body.x += (0 - body.x) * min(1, dt * 2.2);
    body.y += (targetY - body.y) * min(1, dt * 2.2);
    body.stamina = min(100, body.stamina + dt * 9);
  }

  void _captureIntent(int team, TennisIntent intent, double dt) {
    if (team == 0) {
      if (intent.shotDown) _playerHold += dt;
      if (intent.shotReleased) {
        _playerShot = _QueuedShot(
          at: elapsed,
          holdSeconds: max(intent.holdSeconds, _playerHold),
          aimX: intent.aimX,
          aimY: intent.aimY,
          serveAim: intent.serveAim,
        );
        _playerHold = 0;
      }
    } else {
      if (intent.shotDown) _opponentHold += dt;
      if (intent.shotReleased) {
        _opponentShot = _QueuedShot(
          at: elapsed,
          holdSeconds: max(intent.holdSeconds, _opponentHold),
          aimX: intent.aimX,
          aimY: intent.aimY,
          serveAim: intent.serveAim,
        );
        _opponentHold = 0;
      }
    }
  }

  void _updateServe(
    TennisIntent playerIntent,
    TennisIntent opponentIntent,
    double dt,
  ) {
    final server = score.currentServer;
    final intent = server == 0 ? playerIntent : opponentIntent;
    final queued = server == 0 ? _playerShot : _opponentShot;
    if (intent.shotPressed || intent.shotDown) {
      if (phase == TennisMatchPhase.preServe) {
        phase = TennisMatchPhase.serving;
        serveMeter = 0;
        serveMeterRising = true;
        _events.add(TennisEvent(TennisEventType.serveStarted, team: server));
      }
    }
    if (phase == TennisMatchPhase.serving) {
      final delta = dt / (serveNumber == 1 ? 1.05 : 1.25);
      serveMeter += serveMeterRising ? delta : -delta;
      if (serveMeter >= 1) {
        serveMeter = 1;
        serveMeterRising = false;
      } else if (serveMeter <= 0) {
        serveMeter = 0;
        serveMeterRising = true;
      }
    }
    if (phase == TennisMatchPhase.serving && queued != null) {
      if (server == 0) {
        _playerShot = null;
      } else {
        _opponentShot = null;
      }
      _launchServe(server, queued);
    }
  }

  void _launchServe(int server, _QueuedShot queued) {
    final body = bodyFor(server);
    final accuracy = 1 - (serveMeter - 0.82).abs() / 0.82;
    final rating = body.spec.ratings.serve / 100;
    final secondSafety = serveNumber == 2 ? 0.14 : 0;
    final quality = (accuracy * 0.72 + rating * 0.28 + secondSafety).clamp(
      0,
      1,
    );
    final side = score.rightServiceCourt ? 1.0 : -1.0;
    final direction = queued.serveAim.clamp(-1, 1);
    var targetX = side * (1.05 + direction * 1.25);
    if (server == 1) targetX *= -1;
    final targetY = server == 0 ? -4.4 : 4.4;
    final error = (1 - quality) * (serveNumber == 1 ? 2.7 : 1.6);
    targetX += (random.nextDouble() * 2 - 1) * error;
    final longError = quality < 0.45 ? (0.45 - quality) * 7 : 0;
    final actualTargetY = targetY + (server == 0 ? -longError : longError);
    final duration = 0.58 + (1 - quality) * 0.20;
    ball
      ..x = body.x
      ..y = body.y
      ..z = 2.35
      ..bounces = 0
      ..lastHitter = server
      ..live = true
      ..serve = true
      ..netTouched = false
      ..shot = TennisShotType.serve;
    _setFlight(targetX, actualTargetY, duration);
    phase = TennisMatchPhase.rally;
    _stats.firstServesAttempted += server == 0 && serveNumber == 1 ? 1 : 0;
    body
      ..swingT = 0.55
      ..swingShot = TennisShotType.serve;
  }

  void _tryContact(int team) {
    if (!canHit(team)) return;
    if (team == 1 && _opponentMissLockedFlightId == flightId) return;
    final queued = team == 0 ? _playerShot : _opponentShot;
    if (queued == null) return;
    if (team == 0) {
      _playerShot = null;
    } else {
      _opponentShot = null;
    }
    final body = bodyFor(team);
    final distance = sqrt(pow(ball.x - body.x, 2) + pow(ball.y - body.y, 2));
    final queueAge = elapsed - queued.at;
    var grade = TennisTimingGrade.good;
    final perfectWindow =
        (0.075 + body.spec.ratings.control / 2200) *
        (0.72 + body.stamina01 * 0.28) *
        (team == 0 && focusPointActive ? 1.10 : 1);
    if (distance <= 0.34 && queueAge <= perfectWindow) {
      grade = TennisTimingGrade.perfect;
    } else if (distance > 1.05) {
      grade = ball.vy * (team == 0 ? 1 : -1) > 0
          ? TennisTimingGrade.late
          : TennisTimingGrade.early;
    } else if (queueAge > 0.45) {
      grade = TennisTimingGrade.early;
    }
    final shot = _resolveShot(team, queued, grade);
    if (grade == TennisTimingGrade.missed) return;
    if (team == 1 && _opponentMissesReturn(body, distance, grade)) {
      _opponentMissLockedFlightId = flightId;
      body
        ..swingT = 0.28
        ..swingShot = shot
        ..lastTiming = TennisTimingGrade.missed;
      return;
    }
    _launchRallyShot(team, queued, shot, grade);
    body
      ..swingT = shot == TennisShotType.smash ? 0.62 : 0.36
      ..swingShot = shot
      ..lastTiming = grade;
    _events.add(
      TennisEvent(
        TennisEventType.contact,
        team: team,
        shot: shot,
        timing: grade,
        label: grade.name.toUpperCase(),
      ),
    );
    if (team == 0) {
      _stats.shots.add(shot);
      if (config.mode == TennisMode.endlessRally) {
        practiceScore++;
        _events.add(
          TennisEvent(
            TennisEventType.practiceScore,
            team: 0,
            value: practiceScore,
            label: '$practiceScore RETURNS',
          ),
        );
      }
      if (queued.aimX < -0.25) _trainingAimLeft = true;
      if (queued.aimX > 0.25) _trainingAimRight = true;
      if (grade == TennisTimingGrade.perfect) {
        _stats.perfectContacts++;
        player.focus = min(100, player.focus + 12);
        _events.add(
          const TennisEvent(
            TennisEventType.perfectContact,
            team: 0,
            label: 'PERFECT',
          ),
        );
      }
      _updateTrainingOnContact(shot, grade);
    }
  }

  bool _opponentMissesReturn(
    TennisBody body,
    double distance,
    TennisTimingGrade grade,
  ) {
    final rating = body.spec.ratings;
    final returnRating =
        (rating.control * 0.42 +
            rating.reach * 0.23 +
            rating.speed * 0.20 +
            rating.stamina * 0.15) /
        100;
    final base = 0.24 - returnRating * 0.17;
    final stretch = ((distance - 0.42) / 0.92).clamp(0, 1) * 0.17;
    final tired = (1 - body.stamina01) * 0.16;
    final timing = switch (grade) {
      TennisTimingGrade.perfect => -0.025,
      TennisTimingGrade.good => 0.0,
      TennisTimingGrade.early || TennisTimingGrade.late => 0.12,
      TennisTimingGrade.missed => 0.22,
    };
    final shotPressure = switch (ball.shot) {
      TennisShotType.serve => 0.06,
      TennisShotType.power || TennisShotType.smash => 0.05,
      TennisShotType.dropShot || TennisShotType.slice => 0.035,
      TennisShotType.topspin || TennisShotType.lob => 0.025,
      TennisShotType.volley => 0.04,
      TennisShotType.defensive || TennisShotType.normal => 0.0,
    };
    final difficultyScale = switch (config.difficulty) {
      TennisDifficulty.rookie => 1.25,
      TennisDifficulty.pro => 1.0,
      TennisDifficulty.allStar => 0.78,
    };
    final chance =
        (base + stretch + tired + timing + shotPressure) * difficultyScale;
    return random.nextDouble() < chance.clamp(0.015, 0.42);
  }

  TennisShotType _resolveShot(
    int team,
    _QueuedShot queued,
    TennisTimingGrade grade,
  ) {
    final body = bodyFor(team);
    final nearNet = body.y.abs() < 4.4;
    final highBall = ball.z > 2.05;
    final stretched =
        sqrt(pow(ball.x - body.x, 2) + pow(ball.y - body.y, 2)) > 0.95;
    if (highBall && nearNet) return TennisShotType.smash;
    if (nearNet && ball.bounces == 0) return TennisShotType.volley;
    if (stretched || grade == TennisTimingGrade.late) {
      return TennisShotType.defensive;
    }
    if (queued.aimY < -0.55) return TennisShotType.dropShot;
    if (queued.aimY < -0.16) return TennisShotType.slice;
    if (queued.aimY > 0.55) return TennisShotType.lob;
    if (queued.aimY > 0.16) return TennisShotType.topspin;
    if (queued.holdSeconds >= 0.28) return TennisShotType.power;
    return TennisShotType.normal;
  }

  void _launchRallyShot(
    int team,
    _QueuedShot queued,
    TennisShotType shot,
    TennisTimingGrade grade,
  ) {
    final body = bodyFor(team);
    final rating = body.spec.ratings;
    final side = team == 0 ? -1.0 : 1.0;
    var targetY = side * 8.8;
    var duration = 0.92;
    var staminaCost = 1.1;
    switch (shot) {
      case TennisShotType.power:
        duration = 0.68 - rating.power / 2500;
        staminaCost = 6.5;
        break;
      case TennisShotType.topspin:
        duration = 0.92;
        staminaCost = 2.2;
        break;
      case TennisShotType.slice:
        duration = 1.08;
        staminaCost = 1.8;
        break;
      case TennisShotType.lob:
        duration = 1.36;
        staminaCost = 3.2;
        break;
      case TennisShotType.volley:
        duration = 0.63;
        targetY = side * 7.2;
        staminaCost = 2.4;
        break;
      case TennisShotType.smash:
        duration = 0.54;
        staminaCost = 9.0;
        break;
      case TennisShotType.dropShot:
        duration = 0.92;
        targetY = side * 2.8;
        staminaCost = 3.5;
        break;
      case TennisShotType.defensive:
        duration = 1.28;
        targetY = side * 8.1;
        staminaCost = 1.2;
        break;
      case TennisShotType.normal:
      case TennisShotType.serve:
        duration = 0.92;
        staminaCost = 1.1;
        break;
    }
    var targetX = queued.aimX.clamp(-1, 1) * tennisCourtHalfWidth * 0.88;
    final control =
        (rating.control +
            (shot == TennisShotType.topspin || shot == TennisShotType.slice
                ? rating.spin
                : rating.power)) /
        200;
    final timingError = switch (grade) {
      TennisTimingGrade.perfect => 0.10,
      TennisTimingGrade.good => 0.35,
      TennisTimingGrade.early || TennisTimingGrade.late => 0.95,
      TennisTimingGrade.missed => 2.0,
    };
    final tiredError = (1 - body.stamina01) * 0.8;
    final difficultyError =
        shot == TennisShotType.power || shot == TennisShotType.dropShot
        ? 0.25
        : 0;
    final spread = max(
      0.04,
      timingError + tiredError + difficultyError - control * 0.38,
    );
    targetX += (random.nextDouble() * 2 - 1) * spread;
    targetY += (random.nextDouble() * 2 - 1) * spread * 0.9;
    body.stamina = max(0, body.stamina - staminaCost);
    if (team == 0) _stats.staminaSpent += staminaCost;
    ball
      ..x = body.x
      ..y = body.y
      ..z = max(0.55, ball.z)
      ..bounces = 0
      ..lastHitter = team
      ..live = true
      ..serve = false
      ..netTouched = false
      ..shot = shot;
    _setFlight(targetX, targetY, duration);
    rallyCount++;
    _stats.longestRally = max(_stats.longestRally, rallyCount);
    if (rallyCount == 5 || rallyCount == 10 || rallyCount == 20) {
      if (team == 0) player.focus = min(100, player.focus + 5);
      _events.add(
        TennisEvent(
          TennisEventType.rallyMilestone,
          team: team,
          value: rallyCount,
          label: '$rallyCount SHOTS',
        ),
      );
    }
  }

  void _setFlight(double targetX, double targetY, double duration) {
    flightId++;
    final speedScale = config.mode == TennisMode.endlessRally
        ? 1 + 0.02 * (practiceScore ~/ 5)
        : 1.0;
    final t = max(0.42, duration / speedScale);
    ball.vx = (targetX - ball.x) / t;
    ball.vy = (targetY - ball.y) / t;
    ball.vz = (0 - ball.z - 0.5 * tennisGravity * t * t) / t;
  }

  void _updateBall(double dt) {
    if (!ball.live) return;
    final previousY = ball.y;
    ball
      ..x += ball.vx * dt
      ..y += ball.vy * dt
      ..z += ball.vz * dt
      ..vz += tennisGravity * dt;

    final crossedNet =
        (previousY < 0 && ball.y >= 0) || (previousY > 0 && ball.y <= 0);
    if (crossedNet && !ball.netTouched && ball.z < tennisNetHeight) {
      ball.netTouched = true;
      flightId++;
      _events.add(
        TennisEvent(TennisEventType.net, team: ball.lastHitter, label: 'NET'),
      );
      if (ball.z >= tennisNetHeight * 0.72 && random.nextDouble() < 0.45) {
        ball.z = tennisNetHeight + 0.04;
        ball.vy *= 0.58;
        ball.vz = max(0.25, ball.vz.abs() * 0.25);
      } else {
        ball.vx *= 0.2;
        ball.vy *= -0.08;
        ball.vz = 0;
      }
    }

    if (ball.z <= 0 && ball.vz < 0) {
      ball.z = 0;
      ball.bounces++;
      ball.vz = -ball.vz * _bounceFactor(ball.shot);
      ball.vx *= 0.88;
      ball.vy *= 0.88;
      _events.add(
        TennisEvent(
          TennisEventType.bounce,
          team: ball.lastHitter,
          value: ball.bounces,
        ),
      );
      if (ball.bounces == 1) {
        if (ball.serve) {
          _resolveServeBounce();
          if (!ball.live) return;
        } else if (!tennisBallInsideSingles(ball.x, ball.y)) {
          _events.add(
            TennisEvent(
              TennisEventType.out,
              team: ball.lastHitter,
              label: 'OUT',
            ),
          );
          _awardPoint(1 - ball.lastHitter, 'OUT');
          return;
        } else if (!_onReceiverSide(ball.lastHitter, ball.y)) {
          _awardPoint(1 - ball.lastHitter, ball.netTouched ? 'NET' : 'OUT');
          return;
        } else if (config.mode == TennisMode.targetPractice &&
            ball.lastHitter == 0 &&
            ball.y < 0) {
          _scoreTarget();
          return;
        }
      }
      if (ball.bounces >= 2) {
        if (ball.serve && ball.lastHitter == score.currentServer) {
          if (ball.lastHitter == 0) _stats.aces++;
          _events.add(
            TennisEvent(
              TennisEventType.ace,
              team: ball.lastHitter,
              label: 'ACE',
            ),
          );
        }
        _awardPoint(ball.lastHitter, 'WINNER');
      }
    }

    if (ball.y.abs() > tennisCourtHalfLength + 5 ||
        ball.x.abs() > tennisCourtHalfWidth + 6) {
      _awardPoint(1 - ball.lastHitter, 'OUT');
    }
  }

  double _bounceFactor(TennisShotType shot) => switch (shot) {
    TennisShotType.slice || TennisShotType.dropShot => 0.48,
    TennisShotType.topspin => 0.72,
    TennisShotType.lob || TennisShotType.defensive => 0.76,
    _ => 0.62,
  };

  bool _onReceiverSide(int hitter, double y) => hitter == 0 ? y <= 0 : y >= 0;

  void _resolveServeBounce() {
    final server = ball.lastHitter;
    final inside = tennisServeInsideBox(
      x: ball.x,
      y: ball.y,
      server: server,
      rightServiceCourt: score.rightServiceCourt,
    );
    if (ball.netTouched && inside) {
      ball.live = false;
      _events.add(TennisEvent(TennisEventType.let, team: server, label: 'LET'));
      phase = TennisMatchPhase.pointComplete;
      pointResetT = 0.45;
      _serveContinuation = true;
      return;
    }
    if (!inside) {
      ball.live = false;
      _handleFault(server);
      return;
    }
    if (server == 0 && serveNumber == 1) _stats.firstServesIn++;
    if (server == 0 &&
        config.mode == TennisMode.training &&
        config.trainingLesson == 6) {
      _updateTrainingOnContact(TennisShotType.serve, TennisTimingGrade.good);
      if (lessonProgress == 1 && phase != TennisMatchPhase.practiceComplete) {
        ball.live = false;
        serveNumber = 2;
        _serveContinuation = true;
        phase = TennisMatchPhase.pointComplete;
        pointResetT = 0.5;
      }
    }
  }

  void _handleFault(int server) {
    _events.add(
      TennisEvent(TennisEventType.fault, team: server, label: 'FAULT'),
    );
    if (serveNumber == 1) {
      serveNumber = 2;
      _serveContinuation = true;
      phase = TennisMatchPhase.pointComplete;
      pointResetT = 0.42;
    } else {
      if (server == 0) _stats.doubleFaults++;
      _events.add(
        TennisEvent(
          TennisEventType.doubleFault,
          team: server,
          label: 'DOUBLE FAULT',
        ),
      );
      _awardPoint(1 - server, 'DOUBLE FAULT');
    }
  }

  void _awardPoint(int winner, String label) {
    if (phase == TennisMatchPhase.pointComplete || complete) return;
    ball.live = false;
    if (winner == 0 && rallyCount >= 20) _stats.wonTwentyShotRally = true;
    if (winner == 0) {
      _stats.totalPointsWon++;
    } else {
      _stats.totalPointsLost++;
      if (score.currentServer == 0) _stats.pointsLostCurrentServiceGame++;
    }
    if (winner == ball.lastHitter && label == 'WINNER') {
      if (winner == 0) {
        _stats.winners++;
        player.focus = min(100, player.focus + 8);
        if (player.y.abs() < 4.4) _stats.netPointsWon++;
      }
      _events.add(
        TennisEvent(TennisEventType.winner, team: winner, label: 'WINNER'),
      );
    } else if (winner != ball.lastHitter && ball.lastHitter == 0) {
      _stats.unforcedErrors++;
    }

    if (config.mode == TennisMode.endlessRally) {
      if (winner == 1) {
        _finishPractice();
      } else {
        phase = TennisMatchPhase.pointComplete;
        pointResetT = 0.55;
      }
      return;
    }
    if (config.mode == TennisMode.training && config.trainingLesson != 8) {
      phase = TennisMatchPhase.pointComplete;
      pointResetT = 0.55;
      return;
    }
    if (config.mode == TennisMode.targetPractice) {
      _nextTargetBall();
      return;
    }

    final savedTieBreakSetPoint =
        score.tieBreak && winner == 0 && scoring.isSetPointFor(1);
    if (savedTieBreakSetPoint) _playerSavedTieBreakSetPoint = true;
    final result = scoring.awardPoint(winner);
    serveNumber = 1;
    final deficit = score.opponentGames - score.playerGames;
    _stats.maxDeficit = max(_stats.maxDeficit, deficit);
    if (result.breakPointConverted && winner == 0) _stats.breakPointsWon++;
    if (result.breakPointSaved && winner == 0) {
      _stats.breakPointsSaved++;
      _stats.breakPointsSavedCurrentGame++;
      _stats.maxBreakPointsSavedInGame = max(
        _stats.maxBreakPointsSavedInGame,
        _stats.breakPointsSavedCurrentGame,
      );
    }
    if (result.gameWon) {
      if (winner == 0 &&
          score.currentServer == 1 &&
          _stats.pointsLostCurrentServiceGame == 0) {
        _stats.cleanHolds++;
      }
      _stats.pointsLostCurrentServiceGame = 0;
      _stats.breakPointsSavedCurrentGame = 0;
      _events.add(
        TennisEvent(
          TennisEventType.gameEnded,
          team: winner,
          label: winner == 0 ? 'GAME PLAYER' : 'GAME OPPONENT',
        ),
      );
    }
    if (result.tieBreakStarted) {
      _events.add(
        const TennisEvent(TennisEventType.tieBreakStarted, label: 'TIEBREAK'),
      );
    }
    if (result.endChange) {
      endSwapped = !endSwapped;
      _events.add(
        const TennisEvent(TennisEventType.endChange, label: 'CHANGE ENDS'),
      );
    }
    _events.add(
      TennisEvent(TennisEventType.pointEnded, team: winner, label: label),
    );
    if (result.setWon) {
      _stats.comeback = winner == 0 && _stats.maxDeficit >= 3;
      _stats.tiebreakNerve = winner == 0 && _playerSavedTieBreakSetPoint;
      phase = TennisMatchPhase.setComplete;
      if (focusPointActive) focusPointActive = false;
      _events.add(
        TennisEvent(
          TennisEventType.setEnded,
          team: winner,
          label: winner == 0 ? 'VICTORY' : 'DEFEAT',
        ),
      );
    } else if (config.mode == TennisMode.training &&
        config.trainingLesson == 8 &&
        result.gameWon) {
      lessonProgress++;
      _events.add(
        const TennisEvent(
          TennisEventType.lessonComplete,
          team: 0,
          value: 8,
          label: 'SCORING COMPLETE',
        ),
      );
      _finishPractice();
    } else {
      phase = TennisMatchPhase.pointComplete;
      pointResetT = result.gameWon ? 1.0 : 0.78;
    }
  }

  void _startPoint({bool initial = false}) {
    if (complete) return;
    final continuingPoint = !initial && _serveContinuation;
    _serveContinuation = false;
    rallyCount = 0;
    ball.live = false;
    _playerShot = null;
    _opponentShot = null;
    _opponentMissLockedFlightId = -1;
    serveMeter = 0;
    if (initial) serveNumber = 1;
    _resetBodies();
    if (!continuingPoint) {
      if (player.focus >= 100) {
        focusPointActive = true;
        player.focus = 0;
      } else {
        focusPointActive = false;
      }
    }
    if (config.mode == TennisMode.endlessRally ||
        config.mode == TennisMode.targetPractice ||
        (config.mode == TennisMode.training && config.trainingLesson != 6)) {
      _startFeed();
    } else {
      phase = TennisMatchPhase.preServe;
    }
  }

  void _resetBodies() {
    player
      ..x = score.rightServiceCourt ? -1.25 : 1.25
      ..y = 9.1;
    opponent
      ..x = score.rightServiceCourt ? 1.25 : -1.25
      ..y = -9.1;
  }

  void _startFeed() {
    opponent
      ..x = (random.nextDouble() * 2 - 1) * 1.3
      ..y = config.mode == TennisMode.training && config.trainingLesson == 5
          ? -3.2
          : -8.6;
    ball
      ..x = opponent.x
      ..y = opponent.y
      ..z = 1.1
      ..bounces = 0
      ..lastHitter = 1
      ..live = true
      ..serve = false
      ..netTouched = false
      ..shot = TennisShotType.normal;
    final target = (random.nextDouble() * 2 - 1) * 2.5;
    _setFlight(target, 7.8, 1.0);
    phase = TennisMatchPhase.rally;
  }

  void _scoreTarget() {
    final distance = sqrt(pow(ball.x - targetX, 2) + pow(ball.y - targetY, 2));
    final shrink = max(0.62, 1 - targetIndex * 0.018);
    final points = distance <= 0.65 * shrink
        ? 500
        : distance <= 1.25 * shrink
        ? 250
        : distance <= 2.1 * shrink
        ? 100
        : 25;
    practiceScore += points;
    _events.add(
      TennisEvent(
        TennisEventType.practiceScore,
        team: 0,
        value: points,
        label: '+$points',
      ),
    );
    _nextTargetBall();
  }

  void _nextTargetBall() {
    ballsRemaining--;
    if (ballsRemaining <= 0) {
      _finishPractice();
      return;
    }
    targetIndex++;
    targetX = (targetIndex.isEven ? -1 : 1) * (1.1 + (targetIndex % 3) * 0.75);
    targetY = -5.2 - (targetIndex % 4) * 1.25;
    phase = TennisMatchPhase.pointComplete;
    pointResetT = 0.55;
  }

  void _updateTrainingOnContact(TennisShotType shot, TennisTimingGrade grade) {
    if (config.mode != TennisMode.training || config.trainingLesson == null) {
      return;
    }
    final lesson = config.trainingLesson!;
    switch (lesson) {
      case 1:
        if (shot == TennisShotType.normal) lessonProgress++;
        break;
      case 2:
        if (grade == TennisTimingGrade.perfect) lessonProgress = 1;
        break;
      case 3:
        lessonProgress =
            (_trainingAimLeft ? 1 : 0) + (_trainingAimRight ? 1 : 0);
        break;
      case 4:
        if (shot == TennisShotType.power) lessonProgress = 1;
        break;
      case 5:
        if (shot == TennisShotType.lob) lessonProgress = 1;
        break;
      case 6:
        if (shot == TennisShotType.serve) lessonProgress++;
        break;
      case 7:
        if (_trainingSprintUsed) lessonProgress++;
        break;
      case 8:
        break;
    }
    final target = switch (lesson) {
      1 => 3,
      3 => 2,
      6 => 2,
      7 => 2,
      8 => 999,
      _ => 1,
    };
    if (lessonProgress >= target) {
      _events.add(
        TennisEvent(
          TennisEventType.lessonComplete,
          team: 0,
          value: lesson,
          label: 'LESSON COMPLETE',
        ),
      );
      _finishPractice();
    }
  }

  void _finishPractice() {
    ball.live = false;
    phase = TennisMatchPhase.practiceComplete;
    _events.add(
      TennisEvent(
        TennisEventType.setEnded,
        team: 0,
        value: practiceScore,
        label: config.mode == TennisMode.training
            ? 'LESSON COMPLETE'
            : 'SESSION COMPLETE',
      ),
    );
  }

  TennisMatchSummary summary({bool tournamentChampion = false}) {
    final won =
        config.mode == TennisMode.quickMatch ||
            config.mode == TennisMode.tournament
        ? score.setWinner == 0
        : true;
    return TennisMatchSummary(
      matchId: config.matchId,
      mode: config.mode,
      playerId: config.playerId,
      opponentId: config.opponentId,
      difficulty: config.difficulty,
      playerGames: score.playerGames,
      opponentGames: score.opponentGames,
      won: won,
      stats: _stats.freeze(elapsed.round()),
      practiceScore: config.mode == TennisMode.endlessRally
          ? practiceScore * 100
          : practiceScore,
      tournamentChampion: tournamentChampion,
      trainingLesson: config.trainingLesson,
    );
  }

  Map<String, dynamic> snapshot() => {
    'rng': random.state,
    'score': score.toJson(),
    'player': player.toJson(),
    'opponent': opponent.toJson(),
    'ball': ball.toJson(),
    'phase': phase.name,
    'serveNumber': serveNumber,
    'serveMeter': serveMeter,
    'serveMeterRising': serveMeterRising,
    'rallyCount': rallyCount,
    'practiceScore': practiceScore,
    'ballsRemaining': ballsRemaining,
    'lessonProgress': lessonProgress,
    'targetIndex': targetIndex,
    'flightId': flightId,
    'targetX': targetX,
    'targetY': targetY,
    'elapsed': elapsed,
    'pointResetT': pointResetT,
    'focusPointActive': focusPointActive,
    'endSwapped': endSwapped,
    'serveContinuation': _serveContinuation,
    'playerSavedTieBreakSetPoint': _playerSavedTieBreakSetPoint,
    'opponentMissLockedFlightId': _opponentMissLockedFlightId,
    'stats': _stats.toJson(),
  };

  void _restore(Map<String, dynamic> json) {
    random.state = _integer(json['rng'], config.seed) & 0x7fffffff;
    scoring = TennisScoring.fromState(
      TennisScoreState.fromJson(_map(json['score'])),
    );
    player.restore(_map(json['player']));
    opponent.restore(_map(json['opponent']));
    ball.restore(_map(json['ball']));
    phase = _enum(
      TennisMatchPhase.values,
      json['phase'],
      TennisMatchPhase.preServe,
    );
    serveNumber = _integer(json['serveNumber'], 1);
    serveMeter = _num(json['serveMeter'], 0);
    serveMeterRising = json['serveMeterRising'] as bool? ?? true;
    rallyCount = _integer(json['rallyCount'], 0);
    practiceScore = _integer(json['practiceScore'], 0);
    ballsRemaining = _integer(json['ballsRemaining'], 20);
    lessonProgress = _integer(json['lessonProgress'], 0);
    targetIndex = _integer(json['targetIndex'], 0);
    flightId = _integer(json['flightId'], 0);
    targetX = _num(json['targetX'], 0);
    targetY = _num(json['targetY'], -8);
    elapsed = _num(json['elapsed'], 0);
    pointResetT = _num(json['pointResetT'], 0);
    focusPointActive = json['focusPointActive'] as bool? ?? false;
    endSwapped = json['endSwapped'] as bool? ?? false;
    _serveContinuation = json['serveContinuation'] as bool? ?? false;
    _playerSavedTieBreakSetPoint =
        json['playerSavedTieBreakSetPoint'] as bool? ?? false;
    _opponentMissLockedFlightId = _integer(
      json['opponentMissLockedFlightId'],
      -1,
    );
    _stats.restore(_map(json['stats']));
  }
}

/// AI consumes only public engine state and emits the same intent shape as a
/// human control pad. Reaction delays are explicit and difficulty never alters
/// the body's legal movement, stamina, or reach.
class TennisAI {
  TennisAI({required this.difficulty, required int seed, this.team = 1})
    : _random = TennisRandom(seed);

  final TennisDifficulty difficulty;
  final int team;
  final TennisRandom _random;
  double _reactionT = 0;
  double _serveHold = 0;
  bool _serveDown = false;
  double _observedBallX = 0;
  double _observedBallY = 0;
  double _observedPlayerX = 0;
  double _observedPlayerY = 0;

  double get reactionDelay => switch (difficulty) {
    TennisDifficulty.rookie => 0.30,
    TennisDifficulty.pro => 0.18,
    TennisDifficulty.allStar => 0.11,
  };

  Map<String, dynamic> snapshot() => {
    'rng': _random.state,
    'reactionT': _reactionT,
    'serveHold': _serveHold,
    'serveDown': _serveDown,
    'observedBallX': _observedBallX,
    'observedBallY': _observedBallY,
    'observedPlayerX': _observedPlayerX,
    'observedPlayerY': _observedPlayerY,
  };

  void restore(Map<String, dynamic> json) {
    _random.state = _integer(json['rng'], 1) & 0x7fffffff;
    _reactionT = _num(json['reactionT'], 0);
    _serveHold = _num(json['serveHold'], 0);
    _serveDown = json['serveDown'] as bool? ?? false;
    _observedBallX = _num(json['observedBallX'], 0);
    _observedBallY = _num(json['observedBallY'], 0);
    _observedPlayerX = _num(json['observedPlayerX'], 0);
    _observedPlayerY = _num(json['observedPlayerY'], 0);
  }

  TennisIntent think(TennisEngine engine, double dt) {
    _reactionT -= dt;
    if (_reactionT <= 0) {
      _reactionT = reactionDelay;
      _observedBallX = engine.ball.x;
      _observedBallY = engine.ball.y;
      final other = engine.bodyFor(1 - team);
      _observedPlayerX = other.x;
      _observedPlayerY = other.y;
    }
    final body = engine.bodyFor(team);
    final serving =
        engine.score.currentServer == team &&
        (engine.phase == TennisMatchPhase.preServe ||
            engine.phase == TennisMatchPhase.serving);
    if (serving) {
      _serveHold += dt;
      if (!_serveDown) {
        _serveDown = true;
        return const TennisIntent(shotDown: true, shotPressed: true);
      }
      final releaseAt = switch (difficulty) {
        TennisDifficulty.rookie => 0.68,
        TennisDifficulty.pro => 0.78,
        TennisDifficulty.allStar => 0.84,
      };
      if (_serveHold >= releaseAt) {
        final held = _serveHold;
        _serveHold = 0;
        _serveDown = false;
        return TennisIntent(
          shotReleased: true,
          holdSeconds: held,
          serveAim: _random.nextInt(3) - 1,
        );
      }
      return const TennisIntent(shotDown: true);
    }
    _serveHold = 0;
    _serveDown = false;

    var targetX = 0.0;
    var targetY = team == 0 ? 8.6 : -8.6;
    final ballApproaching =
        engine.ball.live && (team == 0 ? engine.ball.y > 0 : engine.ball.y < 0);
    if (ballApproaching) {
      targetX = _observedBallX
          .clamp(-tennisCourtHalfWidth, tennisCourtHalfWidth)
          .toDouble();
      targetY = _observedBallY
          .clamp(
            team == 0 ? 1.2 : -tennisCourtHalfLength,
            team == 0 ? tennisCourtHalfLength : -1.2,
          )
          .toDouble();
    }
    final dx = (targetX - body.x).clamp(-1, 1).toDouble();
    final dy = (targetY - body.y).clamp(-1, 1).toDouble();
    final sprint =
        ballApproaching && (targetX - body.x).abs() > 1.9 && body.stamina > 24;
    if (engine.canHit(team)) {
      final aimError = switch (difficulty) {
        TennisDifficulty.rookie => 0.42,
        TennisDifficulty.pro => 0.24,
        TennisDifficulty.allStar => 0.12,
      };
      var aimX = _observedPlayerX > 0 ? -0.78 : 0.78;
      aimX += (_random.nextDouble() * 2 - 1) * aimError;
      var aimY = 0.0;
      final otherDeep = _observedPlayerY.abs() > 8.5;
      final otherAtNet = _observedPlayerY.abs() < 4.4;
      final tacticChance = switch (difficulty) {
        TennisDifficulty.rookie => 0.10,
        TennisDifficulty.pro => 0.26,
        TennisDifficulty.allStar => 0.42,
      };
      if (otherAtNet && _random.nextDouble() < tacticChance) {
        aimY = 0.8;
      } else if (otherDeep && _random.nextDouble() < tacticChance) {
        aimY = -0.72;
      }
      final hold = body.stamina > 35 && _random.nextDouble() < tacticChance
          ? 0.34
          : 0.08;
      return TennisIntent(
        moveX: dx,
        moveY: dy,
        sprint: sprint,
        shotReleased: true,
        holdSeconds: hold,
        aimX: aimX.clamp(-1, 1).toDouble(),
        aimY: aimY,
      );
    }
    return TennisIntent(moveX: dx, moveY: dy, sprint: sprint);
  }
}

T _enum<T extends Enum>(Iterable<T> values, Object? raw, T fallback) {
  final name = raw?.toString();
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

T? _nullableEnum<T extends Enum>(Iterable<T> values, Object? raw) {
  if (raw == null) return null;
  for (final value in values) {
    if (value.name == raw.toString()) return value;
  }
  return null;
}

double _num(Object? value, double fallback) =>
    value is num ? value.toDouble() : fallback;

int _integer(Object? value, int fallback) =>
    value is num ? value.toInt() : fallback;

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
