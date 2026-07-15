import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:final_over/application/application.dart';
import 'package:final_over/domain/domain.dart';

const int _maximumSimulationMicros = 120 * Duration.microsecondsPerSecond;

/// Timing buckets used by the balancing bot.
///
/// The percentages are fixed by [CompetentBot.sampleTiming]: Perfect 20%, Good
/// 50%, Early/Late 22%, Poor 6%, and Miss 2%.
enum BotTimingBucket { perfect, good, earlyLate, poor, miss }

final class BotTimingPlan {
  const BotTimingPlan({required this.bucket, required this.errorMicros});

  final BotTimingBucket bucket;
  final int? errorMicros;

  bool get swings => errorMicros != null;
}

/// A deterministic player used only for repeatable balance verification.
///
/// It always chooses the highest documented line/length compatibility. For a
/// Good-length tie it alternates Ground and Loft from its own random stream,
/// which cannot perturb delivery, contact, catch, drop, or throw streams.
final class CompetentBot {
  CompetentBot({required this.matchSeed, this.tuning = GameplayTuning.elite});

  final int matchSeed;
  final GameplayTuning tuning;

  int? _plannedDelivery;
  BotTimingPlan? _timingPlan;
  ShotDirection _direction = ShotDirection.straight;
  Elevation _elevation = Elevation.ground;
  bool _elevationDispatched = false;
  bool _directionDispatched = false;
  bool _powerDispatched = false;
  bool _holdDispatched = false;

  final Map<BotTimingBucket, int> timingPlans = {
    for (final bucket in BotTimingBucket.values) bucket: 0,
  };
  final Map<RiskLevel, int> runStarts = {
    for (final risk in RiskLevel.values) risk: 0,
  };

  /// Derives the exact requested 20/50/22/6/2 timing distribution.
  static BotTimingPlan sampleTiming(
    int matchSeed,
    int deliveryOrdinal, {
    GameplayTuning tuning = GameplayTuning.elite,
  }) {
    final seed = DeterministicRandom.mix64(
      matchSeed ^ (deliveryOrdinal * 0xd1b54a32d192ed03) ^ 0x6a09e667f3bcc909,
    );
    final random = DeterministicRandom(seed);
    final roll = random.nextInt(100);
    final sign = random.nextBool() ? 1 : -1;
    if (roll < 20) {
      return const BotTimingPlan(
        bucket: BotTimingBucket.perfect,
        errorMicros: 0,
      );
    }
    if (roll < 70) {
      return BotTimingPlan(
        bucket: BotTimingBucket.good,
        errorMicros:
            sign *
            ((tuning.perfectWindowMs + tuning.goodWindowMs) * 500).round(),
      );
    }
    if (roll < 92) {
      return BotTimingPlan(
        bucket: BotTimingBucket.earlyLate,
        errorMicros:
            sign *
            ((tuning.goodWindowMs + tuning.earlyLateWindowMs) * 500).round(),
      );
    }
    if (roll < 98) {
      return BotTimingPlan(
        bucket: BotTimingBucket.poor,
        errorMicros:
            sign *
            ((tuning.earlyLateWindowMs + tuning.poorWindowMs) * 500).round(),
      );
    }
    return const BotTimingPlan(bucket: BotTimingBucket.miss, errorMicros: null);
  }

  /// Sends every command that is justified by the current immutable state.
  void act(MatchController controller) {
    // Several decisions can be made synchronously (for example selecting the
    // shot and arming Power Shot), so drain them before advancing simulation.
    for (var decision = 0; decision < 6; decision++) {
      final state = controller.state;
      if (state.isTerminal || state.phase == MatchPhase.quit) return;

      if (state.phase == MatchPhase.matchIntro) {
        controller.dispatch(const GameCommand.start());
        continue;
      }

      final delivery = state.currentDelivery;
      if (delivery != null && delivery.ordinal != _plannedDelivery) {
        _planDelivery(delivery);
      }

      if (state.phase == MatchPhase.deliveryPreparation) {
        if (!_elevationDispatched) {
          _elevationDispatched = true;
          controller.dispatch(GameCommand.selectElevation(_elevation));
          continue;
        }
        if (!_directionDispatched) {
          _directionDispatched = true;
          controller.dispatch(GameCommand.selectDirection(_direction));
          continue;
        }
        if (!_powerDispatched &&
            state.powerSegments >= tuning.powerShotSegments) {
          _powerDispatched = true;
          controller.dispatch(const GameCommand.activatePowerShot());
          continue;
        }
      }

      if ((state.phase == MatchPhase.bowlerRunUp ||
              state.phase == MatchPhase.incomingBall) &&
          state.swingIntent == null &&
          delivery != null &&
          _timingPlan!.swings &&
          state.simulationMicros >=
              delivery.expectedContactMicros + _timingPlan!.errorMicros!) {
        final releasedAt =
            delivery.expectedContactMicros - tuning.incomingToContactMicros;
        final heldSeconds =
            (state.simulationMicros - releasedAt) /
            Duration.microsecondsPerSecond;
        final charge = (heldSeconds / tuning.chargeSeconds).clamp(0.0, 1.0);
        controller.dispatch(GameCommand.swing(_direction, charge: charge));
        continue;
      }

      if (_isLiveBallPhase(state.phase) &&
          state.canRun &&
          !state.runner.active &&
          !_holdDispatched) {
        // The controller continuously projects pickup and throw arrival from
        // the moving trajectory; rendering and verification consume that
        // single authoritative risk label.
        final risk = state.runner.risk;
        final mayTakeClose = _isLateMatchPressure(state);
        if (risk == RiskLevel.safe ||
            (risk == RiskLevel.close && mayTakeClose)) {
          runStarts[risk] = runStarts[risk]! + 1;
          controller.dispatch(const GameCommand.startRun());
        } else {
          _holdDispatched = true;
          controller.dispatch(const GameCommand.holdBall());
        }
        continue;
      }

      return;
    }
  }

  void _planDelivery(DeliverySpec delivery) {
    _plannedDelivery = delivery.ordinal;
    _timingPlan = sampleTiming(matchSeed, delivery.ordinal, tuning: tuning);
    timingPlans[_timingPlan!.bucket] = timingPlans[_timingPlan!.bucket]! + 1;
    _direction = switch (delivery.line) {
      DeliveryLine.wideOff || DeliveryLine.off => ShotDirection.offSide,
      DeliveryLine.middle => ShotDirection.straight,
      DeliveryLine.leg || DeliveryLine.wideLeg => ShotDirection.legSide,
    };
    _elevation = switch (delivery.length) {
      DeliveryLength.yorker || DeliveryLength.full => Elevation.ground,
      DeliveryLength.short => Elevation.loft,
      DeliveryLength.good => _goodLengthElevation(matchSeed, delivery.ordinal),
    };
    _elevationDispatched = false;
    _directionDispatched = false;
    _powerDispatched = false;
    _holdDispatched = false;
  }

  static Elevation _goodLengthElevation(int seed, int ordinal) {
    final value = DeterministicRandom.mix64(
      seed ^ (ordinal * 0x94d049bb133111eb) ^ 0xbb67ae8584caa73b,
    );
    return value.isEven ? Elevation.ground : Elevation.loft;
  }

  static bool _isLateMatchPressure(MatchState state) {
    if (state.ballsRemaining > 2) return false;
    return state.runsNeeded >= math.max(2, state.ballsRemaining * 2);
  }

  static bool _isLiveBallPhase(MatchPhase phase) =>
      phase == MatchPhase.cameraTransition ||
      phase == MatchPhase.fieldPlay ||
      phase == MatchPhase.runDecision ||
      phase == MatchPhase.runnersMoving ||
      phase == MatchPhase.throwInProgress;
}

final class MatchMetrics {
  const MatchMetrics({
    required this.won,
    required this.score,
    required this.legalBalls,
    required this.physicalDeliveries,
    required this.wickets,
    required this.contacts,
    required this.contactPowerSum,
    required this.boundaries,
    required this.scoringLegalBalls,
    required this.catchEvents,
    required this.dropEvents,
    required this.pickupEvents,
    required this.wides,
    required this.noBalls,
    required this.completedRuns,
    required this.durationMicros,
    required this.stars,
    required this.fingerprint,
    required this.timingPlans,
    required this.runStarts,
  });

  final bool won;
  final int score;
  final int legalBalls;
  final int physicalDeliveries;
  final int wickets;
  final int contacts;
  final double contactPowerSum;
  final int boundaries;
  final int scoringLegalBalls;
  final int catchEvents;
  final int dropEvents;
  final int pickupEvents;
  final int wides;
  final int noBalls;
  final int completedRuns;
  final int durationMicros;
  final int stars;
  final int fingerprint;
  final Map<BotTimingBucket, int> timingPlans;
  final Map<RiskLevel, int> runStarts;
}

final class SimulationReport {
  SimulationReport({
    required this.matches,
    required this.target,
    required this.seedStart,
    required this.wins,
    required this.totalScore,
    required this.legalBalls,
    required this.physicalDeliveries,
    required this.wickets,
    required this.contacts,
    required this.contactPowerSum,
    required this.boundaries,
    required this.scoringLegalBalls,
    required this.catchEvents,
    required this.dropEvents,
    required this.pickupEvents,
    required this.wides,
    required this.noBalls,
    required this.completedRuns,
    required this.totalDurationMicros,
    required this.maximumDurationMicros,
    required this.totalStars,
    required this.fingerprint,
    required Map<BotTimingBucket, int> timingPlans,
    required Map<RiskLevel, int> runStarts,
  }) : timingPlans = Map.unmodifiable(timingPlans),
       runStarts = Map.unmodifiable(runStarts);

  final int matches;
  final int target;
  final int seedStart;
  final int wins;
  final int totalScore;
  final int legalBalls;
  final int physicalDeliveries;
  final int wickets;
  final int contacts;
  final double contactPowerSum;
  final int boundaries;
  final int scoringLegalBalls;
  final int catchEvents;
  final int dropEvents;
  final int pickupEvents;
  final int wides;
  final int noBalls;
  final int completedRuns;
  final int totalDurationMicros;
  final int maximumDurationMicros;
  final int totalStars;
  final int fingerprint;
  final Map<BotTimingBucket, int> timingPlans;
  final Map<RiskLevel, int> runStarts;

  double get winRate => _ratio(wins, matches);
  double get averageScore => _ratio(totalScore, matches);
  double get boundaryPerContactRate => _ratio(boundaries, contacts);
  double get scoringLegalBallRate => _ratio(scoringLegalBalls, legalBalls);
  double get averageContactPower => _ratio(contactPowerSum, contacts);
  double get contactPerPhysicalDeliveryRate =>
      _ratio(contacts, physicalDeliveries);
  double get wicketPerLegalBallRate => _ratio(wickets, legalBalls);
  double get wideRate => _ratio(wides, physicalDeliveries);
  double get noBallRate => _ratio(noBalls, physicalDeliveries);
  double get averageDurationSeconds =>
      _ratio(totalDurationMicros, matches) / Duration.microsecondsPerSecond;
  double get maximumDurationSeconds =>
      maximumDurationMicros / Duration.microsecondsPerSecond;
  double get averageStars => _ratio(totalStars, matches);

  List<String> get gateFailures {
    final failures = <String>[];
    _checkRange(failures, 'win rate', winRate, 0.35, 0.65);
    _checkRange(
      failures,
      'boundary/contact rate',
      boundaryPerContactRate,
      0.18,
      0.38,
    );
    _checkRange(
      failures,
      'wicket/legal-ball rate',
      wicketPerLegalBallRate,
      0.07,
      0.18,
    );
    _checkRange(failures, 'wide rate', wideRate, 0.02, 0.08);
    _checkRange(failures, 'no-ball rate', noBallRate, 0.005, 0.04);
    if (maximumDurationSeconds >= 120) {
      failures.add(
        'maximum match duration ${maximumDurationSeconds.toStringAsFixed(2)}s '
        'must be below 120s',
      );
    }
    if ((runStarts[RiskLevel.danger] ?? 0) != 0) {
      failures.add('the bot started a DANGER run');
    }
    return failures;
  }

  bool get meetsBalanceGates => gateFailures.isEmpty;

  Map<String, Object> toJson() => {
    'matches': matches,
    'target': target,
    'seedStart': seedStart,
    'wins': wins,
    'winRate': winRate,
    'averageScore': averageScore,
    'legalBalls': legalBalls,
    'physicalDeliveries': physicalDeliveries,
    'contacts': contacts,
    'averageContactPower': averageContactPower,
    'boundaries': boundaries,
    'scoringLegalBalls': scoringLegalBalls,
    'scoringLegalBallRate': scoringLegalBallRate,
    'catchEvents': catchEvents,
    'dropEvents': dropEvents,
    'pickupEvents': pickupEvents,
    'boundaryPerContactRate': boundaryPerContactRate,
    'contactPerPhysicalDeliveryRate': contactPerPhysicalDeliveryRate,
    'wickets': wickets,
    'wicketPerLegalBallRate': wicketPerLegalBallRate,
    'wides': wides,
    'wideRate': wideRate,
    'noBalls': noBalls,
    'noBallRate': noBallRate,
    'completedRuns': completedRuns,
    'averageDurationSeconds': averageDurationSeconds,
    'maximumDurationSeconds': maximumDurationSeconds,
    'averageStars': averageStars,
    'timingPlans': {
      for (final entry in timingPlans.entries) entry.key.name: entry.value,
    },
    'runStarts': {
      for (final entry in runStarts.entries) entry.key.name: entry.value,
    },
    'fingerprint': _hex64(fingerprint),
    'meetsBalanceGates': meetsBalanceGates,
    'gateFailures': gateFailures,
  };

  String pretty() {
    final timingTotal = timingPlans.values.fold<int>(0, (a, b) => a + b);
    String timingLine(BotTimingBucket bucket) {
      final count = timingPlans[bucket] ?? 0;
      return '${bucket.name.padRight(10)} ${_percent(_ratio(count, timingTotal))} '
          '($count)';
    }

    final lines = <String>[
      'Final Over deterministic balance simulation',
      'Matches: $matches | target: $target | seeds: $seedStart-'
          '${seedStart + matches - 1}',
      'Win rate:                 ${_percent(winRate)} ($wins/$matches)',
      'Boundary / contact:       ${_percent(boundaryPerContactRate)} '
          '($boundaries/$contacts)',
      'Scoring / legal ball:     ${_percent(scoringLegalBallRate)} '
          '($scoringLegalBalls/$legalBalls)',
      'Contact / physical ball:  ${_percent(contactPerPhysicalDeliveryRate)} '
          '($contacts/$physicalDeliveries)',
      'Average contact power:     ${averageContactPower.toStringAsFixed(3)}',
      'Catch / drop / pickup:     $catchEvents / $dropEvents / $pickupEvents',
      'Wicket / legal ball:      ${_percent(wicketPerLegalBallRate)} '
          '($wickets/$legalBalls)',
      'Wide / physical ball:     ${_percent(wideRate)} ($wides/$physicalDeliveries)',
      'No-ball / physical ball:  ${_percent(noBallRate)} '
          '($noBalls/$physicalDeliveries)',
      'Average score:            ${averageScore.toStringAsFixed(2)}',
      'Average / max duration:   ${averageDurationSeconds.toStringAsFixed(2)}s / '
          '${maximumDurationSeconds.toStringAsFixed(2)}s',
      'Completed running runs:   $completedRuns',
      'Average stars:            ${averageStars.toStringAsFixed(2)}',
      'Timing plan:',
      ...BotTimingBucket.values.map(timingLine),
      'Runs started by risk:     SAFE ${runStarts[RiskLevel.safe] ?? 0}, '
          'CLOSE ${runStarts[RiskLevel.close] ?? 0}, '
          'DANGER ${runStarts[RiskLevel.danger] ?? 0}',
      'Fingerprint:              ${_hex64(fingerprint)}',
      meetsBalanceGates
          ? 'BALANCE GATES: PASS'
          : 'BALANCE GATES: FAIL\n  - ${gateFailures.join('\n  - ')}',
    ];
    return lines.join('\n');
  }

  static double _ratio(num numerator, num denominator) =>
      denominator == 0 ? 0 : numerator / denominator;

  static void _checkRange(
    List<String> failures,
    String label,
    double value,
    double minimum,
    double maximum,
  ) {
    if (value < minimum || value > maximum) {
      failures.add(
        '$label ${_percent(value)} is outside '
        '${_percent(minimum)}-${_percent(maximum)}',
      );
    }
  }

  static String _percent(double value) =>
      '${(value * 100).toStringAsFixed(2)}%';
}

Future<MatchMetrics> simulateMatch({
  required int seed,
  int target = 14,
  GameplayTuning tuning = GameplayTuning.elite,
}) async {
  final controller = MatchController(tuning: tuning);
  final bot = CompetentBot(matchSeed: seed, tuning: tuning);
  var contactPowerSum = 0.0;
  var catchEvents = 0;
  var dropEvents = 0;
  var pickupEvents = 0;
  final eventSubscription = controller.eventStream.listen((event) {
    switch (event.type) {
      case GameplayEventType.contactResolved:
        final outcome = event.payload['outcome'];
        if (outcome is ContactOutcome && outcome.madeContact) {
          contactPowerSum += outcome.power;
        }
      case GameplayEventType.catchTaken:
        catchEvents++;
      case GameplayEventType.catchDropped:
        dropEvents++;
      case GameplayEventType.ballPickedUp:
        pickupEvents++;
      case GameplayEventType.matchStarted ||
          GameplayEventType.deliveryPrepared ||
          GameplayEventType.ballReleased ||
          GameplayEventType.swingAccepted ||
          GameplayEventType.powerShotActivated ||
          GameplayEventType.extraAwarded ||
          GameplayEventType.cameraTransitionStarted ||
          GameplayEventType.runStarted ||
          GameplayEventType.runCompleted ||
          GameplayEventType.runnerTurnedBack ||
          GameplayEventType.throwStarted ||
          GameplayEventType.runOut ||
          GameplayEventType.boundary ||
          GameplayEventType.wicket ||
          GameplayEventType.deliveryCompleted ||
          GameplayEventType.paused ||
          GameplayEventType.resumed ||
          GameplayEventType.matchEnded ||
          GameplayEventType.quitToHome:
        break;
    }
  });
  try {
    controller.startMatch(seed: seed, target: target);
    bot.act(controller);
    while (!controller.state.isTerminal &&
        controller.state.phase != MatchPhase.quit &&
        controller.state.simulationMicros < _maximumSimulationMicros) {
      bot.act(controller);
      controller.step(Duration(microseconds: tuning.fixedStepMicros));
    }
    bot.act(controller);

    final state = controller.state;
    if (!state.isTerminal) {
      throw StateError(
        'Seed $seed did not terminate within '
        '${_maximumSimulationMicros ~/ Duration.microsecondsPerSecond}s '
        '(phase ${state.phase.name}, score ${state.score}, '
        'balls ${state.legalBalls}, deliveries ${state.physicalDeliveries}).',
      );
    }

    final history = state.history;
    final contacts = history
        .where(
          (result) =>
              result.contactType == ContactType.clean ||
              result.contactType == ContactType.edge,
        )
        .length;
    final fingerprint = _matchFingerprint(state);
    return MatchMetrics(
      won: state.phase == MatchPhase.won,
      score: state.committedScore,
      legalBalls: state.legalBalls,
      physicalDeliveries: history.length,
      wickets: history.where((result) => result.isWicket).length,
      contacts: contacts,
      contactPowerSum: contactPowerSum,
      boundaries: history.where((result) => result.isBoundary).length,
      scoringLegalBalls: history
          .where((result) => result.legal && result.totalRuns > 0)
          .length,
      catchEvents: catchEvents,
      dropEvents: dropEvents,
      pickupEvents: pickupEvents,
      wides: history.where((result) => result.extra == ExtraType.wide).length,
      noBalls: history
          .where((result) => result.extra == ExtraType.noBall)
          .length,
      completedRuns: history.fold<int>(
        0,
        (sum, result) => sum + result.completedRunningRuns,
      ),
      durationMicros: state.simulationMicros,
      stars: state.stars,
      fingerprint: fingerprint,
      timingPlans: Map.of(bot.timingPlans),
      runStarts: Map.of(bot.runStarts),
    );
  } finally {
    await eventSubscription.cancel();
    await controller.dispose();
  }
}

Future<SimulationReport> simulateMatches({
  int matches = 10000,
  int target = 14,
  int seedStart = 1,
  GameplayTuning tuning = GameplayTuning.elite,
}) async {
  if (matches <= 0) throw ArgumentError.value(matches, 'matches');
  if (target < 6 || target > 24) {
    throw RangeError.range(target, 6, 24, 'target');
  }

  var wins = 0;
  var totalScore = 0;
  var legalBalls = 0;
  var physicalDeliveries = 0;
  var wickets = 0;
  var contacts = 0;
  var contactPowerSum = 0.0;
  var boundaries = 0;
  var scoringLegalBalls = 0;
  var catchEvents = 0;
  var dropEvents = 0;
  var pickupEvents = 0;
  var wides = 0;
  var noBalls = 0;
  var completedRuns = 0;
  var totalDurationMicros = 0;
  var maximumDurationMicros = 0;
  var totalStars = 0;
  var fingerprint = 0xcbf29ce484222325;
  final timingPlans = {for (final bucket in BotTimingBucket.values) bucket: 0};
  final runStarts = {for (final risk in RiskLevel.values) risk: 0};

  for (var index = 0; index < matches; index++) {
    final metrics = await simulateMatch(
      seed: seedStart + index,
      target: target,
      tuning: tuning,
    );
    if (metrics.won) wins++;
    totalScore += metrics.score;
    legalBalls += metrics.legalBalls;
    physicalDeliveries += metrics.physicalDeliveries;
    wickets += metrics.wickets;
    contacts += metrics.contacts;
    contactPowerSum += metrics.contactPowerSum;
    boundaries += metrics.boundaries;
    scoringLegalBalls += metrics.scoringLegalBalls;
    catchEvents += metrics.catchEvents;
    dropEvents += metrics.dropEvents;
    pickupEvents += metrics.pickupEvents;
    wides += metrics.wides;
    noBalls += metrics.noBalls;
    completedRuns += metrics.completedRuns;
    totalDurationMicros += metrics.durationMicros;
    maximumDurationMicros = math.max(
      maximumDurationMicros,
      metrics.durationMicros,
    );
    totalStars += metrics.stars;
    fingerprint = _fnv64(fingerprint, metrics.fingerprint);
    for (final bucket in BotTimingBucket.values) {
      timingPlans[bucket] = timingPlans[bucket]! + metrics.timingPlans[bucket]!;
    }
    for (final risk in RiskLevel.values) {
      runStarts[risk] = runStarts[risk]! + metrics.runStarts[risk]!;
    }
  }

  return SimulationReport(
    matches: matches,
    target: target,
    seedStart: seedStart,
    wins: wins,
    totalScore: totalScore,
    legalBalls: legalBalls,
    physicalDeliveries: physicalDeliveries,
    wickets: wickets,
    contacts: contacts,
    contactPowerSum: contactPowerSum,
    boundaries: boundaries,
    scoringLegalBalls: scoringLegalBalls,
    catchEvents: catchEvents,
    dropEvents: dropEvents,
    pickupEvents: pickupEvents,
    wides: wides,
    noBalls: noBalls,
    completedRuns: completedRuns,
    totalDurationMicros: totalDurationMicros,
    maximumDurationMicros: maximumDurationMicros,
    totalStars: totalStars,
    fingerprint: fingerprint,
    timingPlans: timingPlans,
    runStarts: runStarts,
  );
}

int _matchFingerprint(MatchState state) {
  var hash = 0xcbf29ce484222325;
  hash = _fnv64(hash, state.matchSeed);
  hash = _fnv64(hash, state.target);
  hash = _fnv64(hash, state.committedScore);
  hash = _fnv64(hash, state.legalBalls);
  hash = _fnv64(hash, state.wickets);
  hash = _fnv64(hash, state.phase.index);
  hash = _fnv64(hash, state.stars);
  for (final result in state.history) {
    hash = _fnv64(hash, result.deliveryOrdinal);
    hash = _fnv64(hash, result.totalRuns);
    hash = _fnv64(hash, result.boundary);
    hash = _fnv64(hash, result.extra.index);
    hash = _fnv64(hash, result.dismissal.index);
    hash = _fnv64(hash, result.contactType.index);
    hash = _fnv64(hash, result.timing.index);
  }
  return hash;
}

int _fnv64(int hash, int value) {
  const mask = 0xffffffffffffffff;
  const prime = 0x100000001b3;
  var result = hash & mask;
  var input = value & mask;
  for (var byte = 0; byte < 8; byte++) {
    result ^= input & 0xff;
    result = (result * prime) & mask;
    input >>= 8;
  }
  return result;
}

String _hex64(int value) {
  final unsigned = BigInt.from(value).toUnsigned(64);
  return unsigned.toRadixString(16).padLeft(16, '0');
}

Future<void> main(List<String> arguments) async {
  var matches = 10000;
  var target = 14;
  var seedStart = 1;
  var jsonOutput = false;
  var enforceGates = true;

  for (final argument in arguments) {
    if (argument.startsWith('--matches=')) {
      matches = int.parse(argument.substring('--matches='.length));
    } else if (argument.startsWith('--target=')) {
      target = int.parse(argument.substring('--target='.length));
    } else if (argument.startsWith('--seed-start=')) {
      seedStart = int.parse(argument.substring('--seed-start='.length));
    } else if (argument == '--json') {
      jsonOutput = true;
    } else if (argument == '--no-gate') {
      enforceGates = false;
    } else if (argument == '--help' || argument == '-h') {
      stdout.writeln(
        'Usage: dart run tool/simulate_matches.dart '
        '[--matches=10000] [--target=14] [--seed-start=1] '
        '[--json] [--no-gate]',
      );
      return;
    } else {
      stderr.writeln('Unknown argument: $argument');
      exitCode = 64;
      return;
    }
  }

  final report = await simulateMatches(
    matches: matches,
    target: target,
    seedStart: seedStart,
  );
  if (jsonOutput) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report.toJson()));
  } else {
    stdout.writeln(report.pretty());
  }
  if (enforceGates && !report.meetsBalanceGates) exitCode = 1;
}
