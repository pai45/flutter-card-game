import 'dart:async';
import 'dart:math' as math;

import 'package:final_over/domain/delivery_generator.dart';
import 'package:final_over/domain/deterministic_random.dart';
import 'package:final_over/domain/gameplay_tuning.dart';
import 'package:final_over/domain/models.dart';
import 'package:final_over/domain/resolvers.dart';
import 'game_command.dart';
import 'gameplay_event.dart';

/// The sole gameplay authority. Rendering may send commands and observe state,
/// but it never mutates score or simulation data directly.
final class MatchController {
  MatchController({
    this.tuning = const GameplayTuning(),
    DeliveryGenerator? deliveryGenerator,
  }) : _deliveryGenerator =
           deliveryGenerator ?? DeliveryGenerator(tuning: tuning),
       _contactResolver = ContactResolver(tuning: tuning),
       _physicsResolver = PhysicsResolver(tuning: tuning),
       _fieldingResolver = FieldingResolver(tuning: tuning);

  final GameplayTuning tuning;
  final DeliveryGenerator _deliveryGenerator;
  final ContactResolver _contactResolver;
  final PhysicsResolver _physicsResolver;
  final FieldingResolver _fieldingResolver;
  final StreamController<MatchState> _stateController =
      StreamController<MatchState>.broadcast(sync: true);
  final StreamController<GameplayEvent> _eventController =
      StreamController<GameplayEvent>.broadcast(sync: true);

  MatchState _state = MatchState.initial();
  int _accumulatorMicros = 0;
  bool _disposed = false;
  final List<DeliverySpec> _deliveries = [];
  int? _primaryChaserId;
  int? _backupChaserId;
  bool _catchResolved = false;

  MatchState get state => _state;
  Stream<MatchState> get stateStream => _stateController.stream;
  Stream<GameplayEvent> get eventStream => _eventController.stream;

  SimulationSnapshot get snapshot => SimulationSnapshot(
    simulationMicros: _state.simulationMicros,
    phase: _state.phase,
    ball: _state.ball,
    cameraTransition: _state.cameraTransition,
    runner: _state.runner,
    fielders: _state.fielders,
    risk: _state.runner.risk,
    canRun: _state.canRun,
  );

  /// Starts at the intro. [target] is injectable from 6-24 for tests/debug;
  /// production callers omit it to use the approved seeded target set.
  void startMatch({required int seed, int? target}) {
    _ensureAlive();
    if (target != null && (target < 6 || target > 24)) {
      throw RangeError.range(target, 6, 24, 'target');
    }
    _accumulatorMicros = 0;
    _deliveries.clear();
    _resetTransientSimulation();

    final selectionRandom = SeedStreams.forStream(
      seed,
      0,
      RandomStream.objective,
    );
    final int selectedTarget =
        target ?? selectionRandom.choose<int>(GameplayTuning.targetOptions);
    final objectives = <ObjectiveType>[
      if (selectedTarget >= 8) ObjectiveType.twoBoundaries,
      if (selectedTarget >= 6) ObjectiveType.sixRunsFirstThreeLegalBalls,
      ObjectiveType.completeDouble,
    ];
    final objective = selectionRandom.choose(objectives);
    _setState(
      MatchState.initial().copyWith(
        matchSeed: seed,
        target: selectedTarget,
        phase: MatchPhase.matchIntro,
        objective: objective,
        fielders: GameplayTuning.balancedField,
      ),
    );
    _emit(GameplayEventType.matchStarted, {
      'seed': seed,
      'target': selectedTarget,
      'objective': objective,
    });
  }

  /// Positional convenience for simulations and simple host integrations.
  void startMatchWithSeed(int seed, [int? target]) =>
      startMatch(seed: seed, target: target);

  void dispatch(GameCommand command) {
    _ensureAlive();
    switch (command) {
      case StartCommand():
        if (_state.phase == MatchPhase.matchIntro) _prepareDelivery();
      case SelectElevationCommand(:final elevation):
        if (_state.canConfigureShot) {
          _setState(_state.copyWith(selectedElevation: elevation));
        }
      case SelectDirectionCommand(:final direction):
        if (_state.canConfigureShot) {
          _setState(_state.copyWith(selectedDirection: direction));
        }
      case SwingCommand(:final direction, :final charge):
        _acceptSwing(direction, charge);
      case ActivatePowerShotCommand():
        _activatePowerShot();
      case StartRunCommand():
        _startRun();
      case HoldBallCommand():
        _holdBall();
      case TurnBackCommand():
        _turnBack();
      case PauseCommand():
        _pause();
      case ResumeCommand():
        _resume();
      case RestartCommand(:final seed, :final target):
        startMatch(seed: seed ?? _state.matchSeed + 1, target: target);
      case AppBackgroundedCommand():
        _pause();
      case QuitToHomeCommand():
        _quit();
    }
  }

  /// Adds elapsed wall time to a deterministic fixed 60 Hz accumulator.
  void step(Duration elapsed) {
    _ensureAlive();
    if (elapsed.isNegative || elapsed == Duration.zero || _state.isPaused) {
      return;
    }
    final bounded = math.min(elapsed.inMicroseconds, tuning.maximumFrameMicros);
    _accumulatorMicros += bounded;
    while (_accumulatorMicros >= tuning.fixedStepMicros) {
      _accumulatorMicros -= tuning.fixedStepMicros;
      _fixedTick(tuning.fixedStepMicros);
    }
  }

  void _fixedTick(int micros) {
    if (_state.isTerminal ||
        _state.phase == MatchPhase.idle ||
        _state.phase == MatchPhase.matchIntro ||
        _state.phase == MatchPhase.paused ||
        _state.phase == MatchPhase.quit) {
      return;
    }
    _setState(
      _state.copyWith(
        simulationMicros: _state.simulationMicros + micros,
        phaseElapsedMicros: _state.phaseElapsedMicros + micros,
      ),
    );

    switch (_state.phase) {
      case MatchPhase.deliveryPreparation:
        if (_state.phaseElapsedMicros >= tuning.deliveryPreparationMicros) {
          _enterPhase(MatchPhase.bowlerRunUp);
        }
      case MatchPhase.bowlerRunUp:
        if (_state.phaseElapsedMicros >= tuning.runUpMicros) {
          _enterPhase(MatchPhase.incomingBall);
          _emit(GameplayEventType.ballReleased, {
            'delivery': _state.currentDelivery,
          });
        }
      case MatchPhase.incomingBall:
        _advanceIncomingBall();
      case MatchPhase.contact:
        if (_state.phaseElapsedMicros >= tuning.impactHoldMicros) {
          final contact = _state.contactOutcome;
          if (contact != null && contact.madeContact) {
            _launchContactedBall(contact);
          } else {
            _finalizeDelivery();
          }
        }
      case MatchPhase.cameraTransition ||
          MatchPhase.fieldPlay ||
          MatchPhase.runDecision ||
          MatchPhase.runnersMoving ||
          MatchPhase.throwInProgress:
        _advanceLiveBall(micros);
      case MatchPhase.deliveryResult:
        if (_state.phaseElapsedMicros >= tuning.deliveryResultMicros) {
          _enterPhase(MatchPhase.betweenBalls);
        }
      case MatchPhase.betweenBalls:
        if (_state.phaseElapsedMicros >= tuning.betweenBallsMicros) {
          _prepareDelivery();
        }
      case MatchPhase.idle ||
          MatchPhase.matchIntro ||
          MatchPhase.paused ||
          MatchPhase.won ||
          MatchPhase.lost ||
          MatchPhase.quit:
        break;
    }
  }

  void _prepareDelivery() {
    if (_state.isTerminal || _state.phase == MatchPhase.quit) return;
    final ordinal = _state.physicalDeliveries + 1;
    final expectedContact =
        _state.simulationMicros +
        tuning.deliveryPreparationMicros +
        tuning.runUpMicros +
        tuning.incomingToContactMicros;
    final delivery = _deliveryGenerator.generate(
      matchSeed: _state.matchSeed,
      physicalOrdinal: ordinal,
      legalBalls: _state.legalBalls,
      score: _state.score,
      target: _state.target,
      history: _state.history,
      previousDeliveries: _deliveries,
      expectedContactMicros: expectedContact,
    );
    _deliveries.add(delivery);
    _resetTransientSimulation();
    _setState(
      _state.copyWith(
        phase: MatchPhase.deliveryPreparation,
        phaseElapsedMicros: 0,
        physicalDeliveries: ordinal,
        currentDelivery: delivery,
        currentDeliveryFreeHit: _state.freeHit,
        swingIntent: null,
        contactOutcome: null,
        ball: null,
        cameraTransition: 0,
        runner: const RunnerState(),
        fielders: GameplayTuning.balancedField,
        ledger: const DeliveryLedger(),
        pendingRuns: 0,
        pendingExtras: 0,
        pendingBatRuns: 0,
        deliveryFinalized: false,
        canRun: false,
        holdRequested: false,
        ballHeld: false,
        pickupDecisionMicros: 0,
        throwArrivalMicros: 0,
        endReason: null,
      ),
    );
    _emit(GameplayEventType.deliveryPrepared, {'delivery': delivery});
  }

  void _advanceIncomingBall() {
    final delivery = _state.currentDelivery;
    if (delivery == null) return;
    final now = _state.simulationMicros;
    if (now >= delivery.expectedContactMicros && !_state.ledger.extraApplied) {
      if (delivery.extra != ExtraType.none) _applyExtra(delivery.extra);
      if (_state.isTerminal || _state.deliveryFinalized) return;
      if (delivery.isWide) {
        // Wides are dead immediately: there is no wide running in this MVP.
        _finalizeDelivery();
        return;
      }
    }
    final swing = _state.swingIntent;
    if (swing != null && now >= delivery.expectedContactMicros) {
      _resolveContact(swing);
      return;
    }
    if (now >= delivery.expectedContactMicros + tuning.lateSwingGraceMicros) {
      _resolveContact(null);
    }
  }

  void _applyExtra(ExtraType extra) {
    if (_state.ledger.extraApplied || extra == ExtraType.none) return;
    final ledger = _state.ledger.copyWith(extraRuns: 1, extraApplied: true);
    _setState(_state.copyWith(ledger: ledger, pendingExtras: 1));
    _emit(GameplayEventType.extraAwarded, {'extra': extra, 'runs': 1});
    // A target-winning no-ball/wide extra ends the delivery before contact or
    // any subsequent wicket processing.
    if (_state.score >= _state.target) _finalizeDelivery();
  }

  void _acceptSwing(ShotDirection direction, [double? charge]) {
    if (!_state.canSwing) {
      return;
    }
    final intent = SwingIntent(
      direction: direction,
      inputMicros: _state.simulationMicros,
      powerShot: _state.powerShotArmed,
      charge: charge?.clamp(0.0, 1.0),
    );
    _setState(
      _state.copyWith(
        swingIntent: intent,
        powerShotArmed: intent.powerShot ? false : _state.powerShotArmed,
        powerSegments: intent.powerShot ? 0 : _state.powerSegments,
      ),
    );
    _emit(GameplayEventType.swingAccepted, {
      'direction': direction,
      'powerShot': intent.powerShot,
    });
    final delivery = _state.currentDelivery!;
    if (_state.phase == MatchPhase.incomingBall &&
        _state.simulationMicros >= delivery.expectedContactMicros &&
        !delivery.isWide) {
      _resolveContact(intent);
    }
  }

  void _resolveContact(SwingIntent? swing) {
    if (_state.phase != MatchPhase.incomingBall ||
        _state.contactOutcome != null ||
        _state.deliveryFinalized) {
      return;
    }
    final delivery = _state.currentDelivery!;
    final hasInput = swing != null;
    final errorMs = hasInput
        ? ((swing.inputMicros - delivery.expectedContactMicros) / 1000).round()
        : tuning.poorWindowMs + 1;
    final random = SeedStreams.forStream(
      _state.matchSeed,
      delivery.ordinal,
      RandomStream.contact,
    );
    final outcome = _contactResolver.resolve(
      delivery: delivery,
      elevation: _state.selectedElevation,
      direction: swing?.direction ?? ShotDirection.straight,
      timingErrorMs: errorMs,
      hasInput: hasInput,
      powerShot: swing?.powerShot ?? false,
      random: random,
      charge: swing?.charge,
    );
    var ledger = _state.ledger;
    final protectedDelivery =
        _state.currentDeliveryFreeHit || delivery.isNoBall;
    if (outcome.type == ContactType.miss &&
        outcome.bowledThreat &&
        !protectedDelivery) {
      ledger = ledger.copyWith(dismissal: DismissalType.bowled);
    }
    _setState(
      _state.copyWith(
        phase: MatchPhase.contact,
        phaseElapsedMicros: 0,
        contactOutcome: outcome,
        ledger: ledger,
      ),
    );
    _emit(GameplayEventType.contactResolved, {'outcome': outcome});
  }

  void _launchContactedBall(ContactOutcome contact) {
    final ball = _physicsResolver.launch(contact);
    final predicted = _predictPosition(ball, 2.0);
    final fielders = GameplayTuning.balancedField
        .map(
          (fielder) => fielder.copyWith(
            motion: FielderMotion.reacting,
            reactionRemainingSeconds: _fieldingResolver.reactionDelay(fielder),
          ),
        )
        .toList(growable: false);
    final chasers = _fieldingResolver.selectChasers(fielders, predicted);
    _primaryChaserId = chasers.primaryId;
    _backupChaserId = chasers.backupId;
    _setState(
      _state.copyWith(
        phase: MatchPhase.cameraTransition,
        phaseElapsedMicros: 0,
        ball: ball,
        fielders: fielders,
        cameraTransition: 0,
        canRun: false,
      ),
    );
    _emit(GameplayEventType.cameraTransitionStarted, {
      'primaryFielder': _primaryChaserId,
      'backupFielder': _backupChaserId,
    });
  }

  FieldVector _predictPosition(BallKinematics initial, double seconds) {
    var ball = initial;
    final steps = math.max(1, (seconds * 60).round());
    for (var i = 0; i < steps; i++) {
      ball = _physicsResolver.step(ball, 1 / 60);
      if (ball.position.length >= tuning.boundaryRadius || ball.stopped) break;
    }
    return ball.position;
  }

  void _advanceLiveBall(int micros) {
    if (_state.deliveryFinalized) return;
    if (_advanceRunner(micros)) return;

    final seconds = micros / Duration.microsecondsPerSecond;
    var camera = _state.cameraTransition;
    if (camera < 1) {
      camera = math.min(1.0, camera + micros / tuning.cameraTransitionMicros);
      _setState(
        _state.copyWith(
          cameraTransition: camera,
          canRun:
              camera >= 0.70 &&
              !_state.holdRequested &&
              !_state.runner.active &&
              _state.runner.completedRuns < tuning.maximumRuns,
        ),
      );
    }

    if (!_state.ballHeld) {
      final currentBall = _state.ball;
      if (currentBall == null) return;
      final nextBall = _physicsResolver.step(currentBall, seconds);
      _setState(_state.copyWith(ball: nextBall));

      // Boundary is evaluated before pickup; an exact tie is a boundary.
      final boundary = _physicsResolver.boundaryValue(
        nextBall,
        _state.contactOutcome!.elevation,
      );
      if (boundary > 0) {
        _awardBoundary(boundary);
        return;
      }

      _moveFielders(seconds);
      if (_state.deliveryFinalized || _state.ballHeld) return;
      _resolveCatchOrPickup();
      if (_state.deliveryFinalized) return;
    }

    if (_state.ballHeld && !_state.runner.active) {
      if (_state.holdRequested ||
          _state.runner.completedRuns >= tuning.maximumRuns ||
          (_state.pickupDecisionMicros > 0 &&
              _state.simulationMicros >= _state.pickupDecisionMicros)) {
        _finalizeDelivery();
        return;
      }
    }

    if (_state.canRun && !_state.runner.active && !_state.holdRequested) {
      _setState(
        _state.copyWith(runner: _state.runner.copyWith(risk: _currentRisk())),
      );
    }

    if (_state.cameraTransition >= 1 &&
        _state.phase == MatchPhase.cameraTransition) {
      _enterPhase(MatchPhase.fieldPlay);
    }
  }

  void _moveFielders(double seconds) {
    final ball = _state.ball!;
    final updated = <FielderState>[];
    for (final fielder in _state.fielders) {
      final isPrimary = fielder.id == _primaryChaserId;
      final isBackup = fielder.id == _backupChaserId;
      if (!isPrimary && !isBackup) {
        updated.add(fielder);
        continue;
      }
      var reaction = math.max(0.0, fielder.reactionRemainingSeconds - seconds);
      if (reaction > 0) {
        updated.add(fielder.copyWith(reactionRemainingSeconds: reaction));
        continue;
      }
      final target = isPrimary
          ? ball.position
          : FieldVector.lerp(fielder.homePosition, ball.position, 0.72);
      final delta = target - fielder.position;
      final speed =
          tuning.fielderSpeed * (isPrimary ? 1 : tuning.backupSpeedFactor);
      final travel = math.min(delta.length, speed * seconds);
      final velocity = delta.length == 0
          ? FieldVector.zero
          : delta.normalized * speed;
      updated.add(
        fielder.copyWith(
          position:
              fielder.position +
              (delta.length == 0
                  ? FieldVector.zero
                  : delta.normalized * travel),
          velocity: velocity,
          motion: isPrimary ? FielderMotion.chasing : FielderMotion.backup,
          reactionRemainingSeconds: 0,
        ),
      );
    }
    _setState(_state.copyWith(fielders: updated));
  }

  void _resolveCatchOrPickup() {
    final ball = _state.ball!;
    final primaryIndex = _state.fielders.indexWhere(
      (fielder) => fielder.id == _primaryChaserId,
    );
    if (primaryIndex < 0) return;
    final primary = _state.fielders[primaryIndex];
    final distance = primary.position.distanceTo(ball.position);
    if (!_catchResolved &&
        ball.aerial &&
        ball.height >= tuning.catchHeight &&
        distance <= tuning.catchRadius) {
      _catchResolved = true;
      final contact = _state.contactOutcome!;
      final chance = _fieldingResolver.catchChance(
        fielder: primary,
        contact: contact,
        runningCatch: primary.velocity.length > 0.02,
        arrivedEarly: distance < tuning.catchRadius * 0.55,
      );
      final catchRandom = SeedStreams.forStream(
        _state.matchSeed,
        _state.currentDelivery!.ordinal,
        RandomStream.catchOutcome,
      );
      if (catchRandom.nextBool(chance)) {
        final protected =
            _state.currentDeliveryFreeHit || _state.currentDelivery!.isNoBall;
        _emit(GameplayEventType.catchTaken, {
          'fielderId': primary.id,
          'protected': protected,
        });
        if (protected) {
          _pickUpBall(primary.id);
        } else {
          final ledger = _state.ledger.copyWith(
            dismissal: DismissalType.caught,
            completedRuns: 0,
          );
          _setState(
            _state.copyWith(
              ledger: ledger,
              pendingRuns: 0,
              runner: const RunnerState(),
            ),
          );
          _finalizeDelivery();
        }
        return;
      }
      final dropRandom = SeedStreams.forStream(
        _state.matchSeed,
        _state.currentDelivery!.ordinal,
        RandomStream.drop,
      );
      final retained = dropRandom.range(
        tuning.dropSpeedMinimum,
        tuning.dropSpeedMaximum,
      );
      _setState(
        _state.copyWith(
          ball: ball.copyWith(
            velocity: ball.velocity * retained,
            height: 0,
            verticalVelocity: 0,
            aerial: false,
            firstBounceOccurred: true,
          ),
        ),
      );
      _emit(GameplayEventType.catchDropped, {'fielderId': primary.id});
      return;
    }

    if (!ball.aerial && distance <= tuning.ballPickupRadius) {
      _pickUpBall(primary.id);
    }
  }

  void _pickUpBall(int fielderId) {
    if (_state.ballHeld || _state.deliveryFinalized) return;
    final fielders = _state.fielders
        .map(
          (fielder) => fielder.id == fielderId
              ? fielder.copyWith(
                  hasBall: true,
                  motion: FielderMotion.carrying,
                  velocity: FieldVector.zero,
                )
              : fielder,
        )
        .toList(growable: false);
    _setState(
      _state.copyWith(
        fielders: fielders,
        ballHeld: true,
        ball: _state.ball?.copyWith(
          velocity: FieldVector.zero,
          verticalVelocity: 0,
          aerial: false,
          stopped: true,
        ),
        phase: _state.runner.active
            ? MatchPhase.throwInProgress
            : MatchPhase.runDecision,
        phaseElapsedMicros: 0,
        canRun:
            !_state.holdRequested &&
            _state.runner.completedRuns < tuning.maximumRuns,
        pickupDecisionMicros:
            _state.simulationMicros + tuning.pickupDecisionMicros,
      ),
    );
    _emit(GameplayEventType.ballPickedUp, {'fielderId': fielderId});
    if (_state.runner.active) _startThrow(fielderId);
    if (_state.holdRequested && !_state.runner.active) _finalizeDelivery();
  }

  void _awardBoundary(int boundary) {
    final ledger = _state.ledger.copyWith(
      batRuns: boundary,
      completedRuns: 0,
      boundary: boundary,
    );
    _setState(
      _state.copyWith(
        ledger: ledger,
        pendingBatRuns: boundary,
        pendingRuns: 0,
        runner: const RunnerState(),
        canRun: false,
      ),
    );
    _emit(GameplayEventType.boundary, {'runs': boundary});
    _finalizeDelivery();
  }

  void _startRun() {
    if (!_state.canRun ||
        _state.runner.active ||
        _state.holdRequested ||
        _state.deliveryFinalized ||
        _state.runner.completedRuns >= tuning.maximumRuns) {
      return;
    }
    final runner = _state.runner.copyWith(
      active: true,
      returning: false,
      runNumber: _state.runner.completedRuns + 1,
      progress: 0,
      risk: _currentRisk(),
    );
    _setState(
      _state.copyWith(
        runner: runner,
        canRun: false,
        phase: MatchPhase.runnersMoving,
        phaseElapsedMicros: 0,
        pickupDecisionMicros: 0,
      ),
    );
    _emit(GameplayEventType.runStarted, {'run': runner.runNumber});
    if (_state.ballHeld) {
      final holder = _state.fielders
          .where((fielder) => fielder.hasBall)
          .map((fielder) => fielder.id)
          .firstOrNull;
      if (holder != null) _startThrow(holder);
    }
  }

  void _startThrow(int fielderId) {
    if (!_state.runner.active || _state.throwArrivalMicros > 0) return;
    final holder = _state.fielders.firstWhere(
      (fielder) => fielder.id == fielderId,
    );
    final targetEnd = _state.runner.runNumber.isOdd
        ? const FieldVector(0, -0.21)
        : const FieldVector(0, 0.21);
    final travelSeconds =
        holder.position.distanceTo(targetEnd) / tuning.throwSpeed + 0.10;
    final arrival =
        _state.simulationMicros +
        (travelSeconds * Duration.microsecondsPerSecond).round();
    final fielders = _state.fielders
        .map(
          (fielder) => fielder.id == fielderId
              ? fielder.copyWith(motion: FielderMotion.throwing)
              : fielder,
        )
        .toList(growable: false);
    _setState(
      _state.copyWith(
        fielders: fielders,
        throwArrivalMicros: arrival,
        phase: MatchPhase.throwInProgress,
        phaseElapsedMicros: 0,
        runner: _state.runner.copyWith(risk: _currentRisk(arrival)),
      ),
    );
    _emit(GameplayEventType.throwStarted, {
      'fielderId': fielderId,
      'arrivalMicros': arrival,
    });
  }

  bool _advanceRunner(int micros) {
    final runner = _state.runner;
    if (!runner.active) return false;
    final tickEnd = _state.simulationMicros;
    final tickStart = tickEnd - micros;
    final durationMicros =
        (tuning.runDurationSeconds * Duration.microsecondsPerSecond).round();
    final distanceRemaining = runner.returning
        ? runner.progress
        : 1 - runner.progress;
    final creaseMicros =
        tickStart + (distanceRemaining * durationMicros).round();
    final throwMicros = _state.throwArrivalMicros;

    if (throwMicros > 0 &&
        throwMicros <= tickEnd &&
        throwMicros < creaseMicros) {
      // Strict comparison makes an exact crease/stump tie safe.
      final elapsedFraction = (throwMicros - tickStart) / durationMicros;
      final progress = runner.returning
          ? math.max(0.0, runner.progress - elapsedFraction)
          : math.min(1.0, runner.progress + elapsedFraction);
      _setState(
        _state.copyWith(
          runner: runner.copyWith(active: false, progress: progress),
          ledger: _state.ledger.copyWith(dismissal: DismissalType.runOut),
          canRun: false,
        ),
      );
      _emit(GameplayEventType.runOut, {'run': runner.runNumber});
      _finalizeDelivery();
      return true;
    }

    if (creaseMicros <= tickEnd) {
      if (runner.returning) {
        _setState(
          _state.copyWith(
            runner: runner.copyWith(
              active: false,
              returning: false,
              progress: 0,
            ),
            throwArrivalMicros: 0,
            phase: MatchPhase.runDecision,
            phaseElapsedMicros: 0,
            canRun: !_state.holdRequested,
            pickupDecisionMicros: _state.ballHeld
                ? tickEnd + tuning.pickupDecisionMicros
                : 0,
          ),
        );
        return false;
      }
      _completeRun();
      return _state.deliveryFinalized || _state.isTerminal;
    }

    final delta = micros / durationMicros;
    final progress = runner.returning
        ? math.max(0.0, runner.progress - delta)
        : math.min(1.0, runner.progress + delta);
    _setState(
      _state.copyWith(
        runner: runner.copyWith(progress: progress, risk: _currentRisk()),
      ),
    );
    return false;
  }

  void _completeRun() {
    final completed = _state.runner.completedRuns + 1;
    final ledger = _state.ledger.copyWith(completedRuns: completed);
    _setState(
      _state.copyWith(
        ledger: ledger,
        pendingRuns: completed,
        runner: RunnerState(completedRuns: completed),
        throwArrivalMicros: 0,
        phase: MatchPhase.runDecision,
        phaseElapsedMicros: 0,
        canRun: completed < tuning.maximumRuns && !_state.holdRequested,
        pickupDecisionMicros: _state.ballHeld
            ? _state.simulationMicros + tuning.pickupDecisionMicros
            : 0,
      ),
    );
    _emit(GameplayEventType.runCompleted, {'run': completed});
    // A completed winning run is authoritative before a later stump break.
    if (_state.score >= _state.target) {
      _finalizeDelivery();
    } else if (_state.ballHeld && completed >= tuning.maximumRuns) {
      _finalizeDelivery();
    }
  }

  RiskLevel _currentRisk([int? knownThrowArrival]) {
    final durationMicros =
        (tuning.runDurationSeconds * Duration.microsecondsPerSecond).round();
    final runner = _state.runner;
    final remaining = runner.active
        ? (runner.returning ? runner.progress : 1 - runner.progress)
        : 1.0;
    final crease =
        _state.simulationMicros + (remaining * durationMicros).round();
    final throwArrival =
        knownThrowArrival ??
        (_state.throwArrivalMicros > 0
            ? _state.throwArrivalMicros
            : _estimatedThrowArrivalMicros());
    final margin = (throwArrival - crease) / Duration.microsecondsPerSecond;
    return _fieldingResolver.riskForMargin(margin);
  }

  int _estimatedThrowArrivalMicros() {
    final ball = _state.ball;
    if (ball == null) return _state.simulationMicros + 2000000;
    final runNumber = _state.runner.active
        ? _state.runner.runNumber
        : _state.runner.completedRuns + 1;
    final end = runNumber.isOdd
        ? const FieldVector(0, -0.21)
        : const FieldVector(0, 0.21);
    if (_state.ballHeld) {
      final holder = _state.fielders
          .where((fielder) => fielder.hasBall)
          .firstOrNull;
      final throwTime =
          (holder?.position ?? ball.position).distanceTo(end) /
              tuning.throwSpeed +
          0.10;
      return _state.simulationMicros +
          (throwTime * Duration.microsecondsPerSecond).round();
    }
    final primary = _state.fielders
        .where((fielder) => fielder.id == _primaryChaserId)
        .firstOrNull;
    final chaser =
        primary ??
        _state.fielders.reduce(
          (a, b) =>
              a.position.distanceTo(ball.position) <=
                  b.position.distanceTo(ball.position)
              ? a
              : b,
        );
    // Project the moving ball instead of treating its current position as a
    // stationary pickup point. That stationary estimate made every early run
    // look unsafe even when the ball was travelling into a gap.
    final predictedPickup = _predictPosition(ball, 1.0);
    final pickup = math.max(
      0.55,
      chaser.reactionRemainingSeconds +
          chaser.position.distanceTo(predictedPickup) / tuning.fielderSpeed,
    );
    final throwTime =
        predictedPickup.distanceTo(end) / tuning.throwSpeed + 0.10;
    return _state.simulationMicros +
        ((pickup + throwTime) * Duration.microsecondsPerSecond).round();
  }

  void _turnBack() {
    if (!_state.runner.canTurnBack ||
        _state.runner.progress > tuning.turnBackLimit) {
      return;
    }
    _setState(_state.copyWith(runner: _state.runner.copyWith(returning: true)));
    _emit(GameplayEventType.runnerTurnedBack, {'run': _state.runner.runNumber});
  }

  void _holdBall() {
    if (_state.deliveryFinalized ||
        !_isLiveBallPhase(_state.phase) ||
        _state.runner.active) {
      return;
    }
    _setState(_state.copyWith(holdRequested: true, canRun: false));
    // Before pickup, HOLD still lets a possible boundary finish.
    if (_state.ballHeld || _state.ball?.stopped == true) _finalizeDelivery();
  }

  void _activatePowerShot() {
    if (!_state.canConfigureShot ||
        _state.powerSegments < tuning.powerShotSegments ||
        _state.powerShotArmed) {
      return;
    }
    _setState(_state.copyWith(powerShotArmed: true));
    _emit(GameplayEventType.powerShotActivated);
  }

  void _finalizeDelivery() {
    if (_state.deliveryFinalized ||
        _state.ledger.finalized ||
        _state.currentDelivery == null) {
      return;
    }
    final delivery = _state.currentDelivery!;
    final ledger = _state.ledger.copyWith(finalized: true);
    final contact = _state.contactOutcome;
    final contactType = contact == null || !contact.acceptedSwing
        ? ContactType.none
        : contact.type;
    final timing = contact == null ? TimingGrade.miss : contact.timing;
    final token = ScoringResolver.historyToken(
      extra: delivery.extra,
      totalRuns: ledger.totalRuns,
      batAndRunningRuns: ledger.batRuns + ledger.completedRuns,
      boundary: ledger.boundary,
      dismissal: ledger.dismissal,
    );
    final result = BallResult(
      deliveryOrdinal: delivery.ordinal,
      legalBallsBefore: _state.legalBalls,
      legal: delivery.isLegal,
      extra: delivery.extra,
      extraRuns: ledger.extraRuns,
      runsOffBat: ledger.batRuns,
      completedRunningRuns: ledger.completedRuns,
      boundary: ledger.boundary,
      dismissal: ledger.dismissal,
      contactType: contactType,
      timing: timing,
      freeHitDelivery: _state.currentDeliveryFreeHit,
      historyToken: token,
    );

    final nextHistory = [..._state.history, result];
    final legalBalls = _state.legalBalls + (result.legal ? 1 : 0);
    final wickets = _state.wickets + (result.isWicket ? 1 : 0);
    final committedScore = _state.committedScore + ledger.totalRuns;
    final objectiveUpdate = ScoringResolver.updateObjective(
      _state.objective,
      _state.objectiveProgress,
      result,
    );

    final increasedCombo = result.isProductiveContact
        ? math.min(3, _state.combo + 1)
        : _state.combo;
    final charge = ScoringResolver.chargeFor(result, increasedCombo);
    final combo = result.isWicket
        ? 1
        : ScoringResolver.nextCombo(_state.combo, result);
    final powerSegments = math.min(
      tuning.powerShotSegments,
      _state.powerSegments + charge,
    );
    final nextFreeHit = switch (delivery.extra) {
      ExtraType.noBall => true,
      ExtraType.wide => _state.freeHit,
      ExtraType.none => false,
    };

    // History and legal-ball consumption are committed before terminal checks.
    var next = _state.copyWith(
      committedScore: committedScore,
      legalBalls: legalBalls,
      wickets: wickets,
      pendingRuns: 0,
      pendingExtras: 0,
      pendingBatRuns: 0,
      ledger: ledger,
      history: nextHistory,
      lastResult: result,
      deliveryFinalized: true,
      freeHit: nextFreeHit,
      combo: combo,
      powerSegments: powerSegments,
      objectiveProgress: objectiveUpdate.progress,
      objectiveCompleted: objectiveUpdate.completed,
      runner: RunnerState(completedRuns: ledger.completedRuns),
      canRun: false,
      throwArrivalMicros: 0,
      phase: MatchPhase.deliveryResult,
      phaseElapsedMicros: 0,
    );

    final won = committedScore >= next.target;
    if (won) {
      final stars = ScoringResolver.starsForWin(
        objectiveCompleted: objectiveUpdate.completed,
        legalBalls: legalBalls,
        wickets: wickets,
      );
      next = next.copyWith(
        phase: MatchPhase.won,
        stars: stars,
        endReason: MatchEndReason.targetReached,
      );
    } else if (wickets >= tuning.maximumWickets) {
      next = next.copyWith(
        phase: MatchPhase.lost,
        endReason: MatchEndReason.wicketsLost,
      );
    } else if (legalBalls >= tuning.maximumLegalBalls) {
      next = next.copyWith(
        phase: MatchPhase.lost,
        endReason: MatchEndReason.ballsExhausted,
      );
    }
    _setState(next);
    _emit(GameplayEventType.deliveryCompleted, {'result': result});
    if (result.isWicket) {
      _emit(GameplayEventType.wicket, {'dismissal': result.dismissal});
    }
    if (next.isTerminal) {
      _emit(GameplayEventType.matchEnded, {
        'won': next.phase == MatchPhase.won,
        'reason': next.endReason,
        'stars': next.stars,
      });
    }
  }

  void _pause() {
    if (_state.phase == MatchPhase.paused ||
        _state.isTerminal ||
        _state.phase == MatchPhase.idle ||
        _state.phase == MatchPhase.quit) {
      return;
    }
    _setState(
      _state.copyWith(suspendedPhase: _state.phase, phase: MatchPhase.paused),
    );
    _emit(GameplayEventType.paused);
  }

  void _resume() {
    if (_state.phase != MatchPhase.paused || _state.suspendedPhase == null) {
      return;
    }
    final resumePhase = _state.suspendedPhase!;
    _setState(_state.copyWith(phase: resumePhase, suspendedPhase: null));
    _emit(GameplayEventType.resumed);
  }

  void _quit() {
    if (_state.phase == MatchPhase.quit) return;
    _setState(
      _state.copyWith(phase: MatchPhase.quit, endReason: MatchEndReason.quit),
    );
    _emit(GameplayEventType.quitToHome);
  }

  void _enterPhase(MatchPhase phase) {
    _setState(_state.copyWith(phase: phase, phaseElapsedMicros: 0));
  }

  bool _isLiveBallPhase(MatchPhase phase) =>
      phase == MatchPhase.cameraTransition ||
      phase == MatchPhase.fieldPlay ||
      phase == MatchPhase.runDecision ||
      phase == MatchPhase.runnersMoving ||
      phase == MatchPhase.throwInProgress;

  void _resetTransientSimulation() {
    _primaryChaserId = null;
    _backupChaserId = null;
    _catchResolved = false;
  }

  void _setState(MatchState state) {
    _state = state;
    if (!_stateController.isClosed) _stateController.add(state);
  }

  void _emit(
    GameplayEventType type, [
    Map<String, Object?> payload = const {},
  ]) {
    if (_eventController.isClosed) return;
    _eventController.add(
      GameplayEvent(
        type: type,
        simulationMicros: _state.simulationMicros,
        payload: payload,
      ),
    );
  }

  void _ensureAlive() {
    if (_disposed) throw StateError('MatchController has been disposed');
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _stateController.close();
    await _eventController.close();
  }
}
