import 'dart:math' as math;

import 'deterministic_random.dart';
import 'gameplay_tuning.dart';
import 'models.dart';

final class TimingResolver {
  const TimingResolver._();

  static TimingGrade resolve(
    int errorMs, {
    bool hasInput = true,
    GameplayTuning tuning = const GameplayTuning(),
  }) {
    if (!hasInput) return TimingGrade.miss;
    final magnitude = errorMs.abs();
    if (magnitude <= tuning.perfectWindowMs) return TimingGrade.perfect;
    if (magnitude <= tuning.goodWindowMs) return TimingGrade.good;
    if (magnitude <= tuning.earlyLateWindowMs) {
      return errorMs < 0 ? TimingGrade.early : TimingGrade.late;
    }
    if (magnitude <= tuning.poorWindowMs) return TimingGrade.poor;
    return TimingGrade.miss;
  }
}

final class ContactResolver {
  const ContactResolver({this.tuning = const GameplayTuning()});

  final GameplayTuning tuning;

  double compatibility(
    DeliverySpec delivery,
    ShotDirection direction,
    Elevation elevation,
  ) {
    var score = 0.50;
    final lineMatch = switch (delivery.line) {
      DeliveryLine.off ||
      DeliveryLine.wideOff => direction == ShotDirection.offSide,
      DeliveryLine.middle => direction == ShotDirection.straight,
      DeliveryLine.leg ||
      DeliveryLine.wideLeg => direction == ShotDirection.legSide,
    };
    if (lineMatch) {
      score += delivery.line == DeliveryLine.middle ? 0.20 : 0.18;
    } else {
      score -= 0.08;
    }

    score += switch ((delivery.length, elevation)) {
      (DeliveryLength.yorker, Elevation.ground) => 0.10,
      (DeliveryLength.yorker, Elevation.loft) => -0.08,
      (DeliveryLength.full, Elevation.ground) => 0.08,
      (DeliveryLength.full, Elevation.loft) => 0.04,
      (DeliveryLength.good, _) => 0.08,
      (DeliveryLength.short, Elevation.loft) => 0.12,
      (DeliveryLength.short, Elevation.ground) => -0.08,
    };
    return score.clamp(0.0, 1.0);
  }

  /// How hard a given backlift lets you hit: nothing at all still connects (a
  /// dab), and anything from [GameplayTuning.chargePerfectCenter] up swings the
  /// full blade. A null charge is a swing with no backlift input — judged on
  /// timing alone, exactly as the game behaved before the meter existed.
  double backliftPower(double? charge) {
    if (charge == null) return 1;
    final loaded = (charge / tuning.chargePerfectCenter).clamp(0.0, 1.0);
    return tuning.backliftPowerFloor +
        (1 - tuning.backliftPowerFloor) * loaded;
  }

  /// 0 until you pass [GameplayTuning.overswingFrom], then ramps to 1 at a
  /// fully wound-up bat. This is the cost of holding too long.
  double overswing(double? charge) {
    if (charge == null || charge <= tuning.overswingFrom) return 0;
    final past = (charge - tuning.overswingFrom) / (1 - tuning.overswingFrom);
    return past.clamp(0.0, 1.0);
  }

  ContactOutcome resolve({
    required DeliverySpec delivery,
    required Elevation elevation,
    required ShotDirection direction,
    required int timingErrorMs,
    required bool hasInput,
    required bool powerShot,
    required DeterministicRandom random,
    double? charge,
  }) {
    final timing = TimingResolver.resolve(
      timingErrorMs,
      hasInput: hasInput,
      tuning: tuning,
    );
    final bowledThreat =
        delivery.contactX.abs() <= tuning.stumpChannel &&
        delivery.extra != ExtraType.wide &&
        delivery.length != DeliveryLength.short;
    final reachable = delivery.contactX.abs() <= tuning.batterReach;
    if (!hasInput || timing == TimingGrade.miss || !reachable) {
      return ContactOutcome(
        type: ContactType.miss,
        timing: TimingGrade.miss,
        timingErrorMs: timingErrorMs,
        direction: direction,
        elevation: elevation,
        power: 0,
        control: 0,
        shotAngleDegrees: _nominalAngle(direction),
        velocity: FieldVector.zero,
        verticalVelocity: 0,
        acceptedSwing: hasInput,
        powerShotUsed: hasInput && powerShot,
        bowledThreat: bowledThreat,
      );
    }

    final profile = _profile(timing);
    final technique = compatibility(delivery, direction, elevation);
    final wild = overswing(charge);
    var control = profile.control * (0.65 + 0.55 * technique);
    if (powerShot) control += tuning.powerShotControlBonus;
    control *= 1 - tuning.overswingControlPenalty * wild;
    control = control.clamp(0.0, 1.0);

    final edgeChance =
        switch (timing) {
          TimingGrade.perfect => 0.015,
          TimingGrade.good => 0.06,
          TimingGrade.early || TimingGrade.late => 0.22,
          TimingGrade.poor => 0.44,
          TimingGrade.miss => 1.0,
        } +
        (1 - technique) * 0.12 +
        tuning.overswingEdgeBonus * wild;
    final edged = random.nextBool(edgeChance.clamp(0.0, 0.75));

    var power =
        profile.power * (0.80 + 0.42 * technique) * random.range(0.94, 1.06);
    power *= backliftPower(charge);
    if (powerShot) power *= tuning.powerShotPowerMultiplier;
    if (edged) power *= random.range(0.35, 0.65);
    power = power.clamp(0.12, 1.20);

    var angle = _nominalAngle(direction);
    if (timing == TimingGrade.early) angle += 7 + 8 * (1 - control);
    if (timing == TimingGrade.late) angle -= 7 + 8 * (1 - control);
    final maximumSpread = timing == TimingGrade.poor
        ? 28.0
        : 16.0 * (1 - control);
    angle += random.range(-maximumSpread, maximumSpread);
    if (edged) angle += random.range(-18, 18);

    final horizontalSpeed = elevation == Elevation.ground
        ? tuning.groundBaseSpeed + tuning.groundPowerSpeed * power
        : tuning.loftBaseSpeed + tuning.loftPowerSpeed * power;
    final verticalSpeed = elevation == Elevation.loft
        ? tuning.loftVerticalBaseSpeed + tuning.loftVerticalPowerSpeed * power
        : 0.0;
    return ContactOutcome(
      type: edged ? ContactType.edge : ContactType.clean,
      timing: timing,
      timingErrorMs: timingErrorMs,
      direction: direction,
      elevation: elevation,
      power: power,
      control: control,
      shotAngleDegrees: angle,
      velocity: FieldVector.fromShotAngle(angle) * horizontalSpeed,
      verticalVelocity: verticalSpeed,
      acceptedSwing: true,
      powerShotUsed: powerShot,
      bowledThreat: false,
    );
  }

  static double _nominalAngle(ShotDirection direction) => switch (direction) {
    ShotDirection.offSide => -45,
    ShotDirection.straight => 0,
    ShotDirection.legSide => 45,
  };

  static ({double power, double control}) _profile(TimingGrade timing) =>
      switch (timing) {
        TimingGrade.perfect => (power: 1.0, control: 1.0),
        TimingGrade.good => (power: 0.90, control: 0.88),
        TimingGrade.early || TimingGrade.late => (power: 0.74, control: 0.66),
        TimingGrade.poor => (power: 0.48, control: 0.38),
        TimingGrade.miss => (power: 0.0, control: 0.0),
      };
}

final class PhysicsResolver {
  const PhysicsResolver({this.tuning = const GameplayTuning()});

  final GameplayTuning tuning;

  BallKinematics launch(ContactOutcome contact) => BallKinematics(
    position: BallKinematics.atContact.position,
    velocity: contact.velocity,
    height: contact.elevation == Elevation.loft ? 0.001 : 0,
    verticalVelocity: contact.verticalVelocity,
    aerial: contact.elevation == Elevation.loft,
  );

  BallKinematics step(BallKinematics ball, double seconds) {
    if (ball.stopped || seconds <= 0) return ball;
    var position = ball.position + ball.velocity * seconds;
    var velocity = ball.velocity;
    var height = ball.height;
    var verticalVelocity = ball.verticalVelocity;
    var aerial = ball.aerial;
    var bounced = ball.firstBounceOccurred;

    if (aerial) {
      height +=
          verticalVelocity * seconds - 0.5 * tuning.gravity * seconds * seconds;
      verticalVelocity -= tuning.gravity * seconds;
      if (height <= 0 && verticalVelocity <= 0) {
        height = 0;
        verticalVelocity = 0;
        aerial = false;
        bounced = true;
        velocity = velocity * tuning.landingSpeedRetention;
      }
    } else {
      final speed = velocity.length;
      final nextSpeed = math.max(
        0.0,
        speed - tuning.groundDragPerSecond * seconds,
      );
      velocity = speed == 0
          ? FieldVector.zero
          : velocity.normalized * nextSpeed;
    }
    final stopped = !aerial && velocity.length <= 0.015;
    if (stopped) velocity = FieldVector.zero;
    return BallKinematics(
      position: position,
      velocity: velocity,
      height: height,
      verticalVelocity: verticalVelocity,
      aerial: aerial,
      firstBounceOccurred: bounced,
      stopped: stopped,
    );
  }

  int boundaryValue(BallKinematics ball, Elevation elevation) {
    if (ball.position.length < tuning.boundaryRadius) return 0;
    // Ground can never produce a six. Any loft that bounced is also a four.
    return elevation == Elevation.loft && !ball.firstBounceOccurred ? 6 : 4;
  }

  /// A catch at the exact bounce time is a bounce, not a catch.
  bool catchPrecedesBounce(double catchTime, double firstBounceTime) =>
      catchTime < firstBounceTime;

  /// Boundary wins an exact tie against pickup.
  bool pickupPrecedesBoundary(double pickupTime, double boundaryTime) =>
      pickupTime < boundaryTime;
}

final class ChaserSelection {
  const ChaserSelection({required this.primaryId, required this.backupId});

  final int primaryId;
  final int backupId;
}

final class FieldingResolver {
  const FieldingResolver({this.tuning = const GameplayTuning()});

  final GameplayTuning tuning;

  ChaserSelection selectChasers(
    List<FielderState> fielders,
    FieldVector predictedPosition,
  ) {
    if (fielders.length < 2) {
      throw ArgumentError('At least two fielders are required');
    }
    final ranked = [...fielders]
      ..sort((a, b) {
        final aTime =
            reactionDelay(a) +
            a.position.distanceTo(predictedPosition) / tuning.fielderSpeed;
        final bTime =
            reactionDelay(b) +
            b.position.distanceTo(predictedPosition) / tuning.fielderSpeed;
        final comparison = aTime.compareTo(bTime);
        return comparison != 0 ? comparison : a.id.compareTo(b.id);
      });
    return ChaserSelection(primaryId: ranked[0].id, backupId: ranked[1].id);
  }

  double reactionDelay(FielderState fielder) {
    if (fielder.role == FielderRole.wicketkeeper) {
      return tuning.keeperReactionSeconds;
    }
    return fielder.position.length < 0.55
        ? tuning.closeReactionSeconds
        : tuning.deepReactionSeconds;
  }

  double catchChance({
    required FielderState fielder,
    required ContactOutcome contact,
    required bool runningCatch,
    required bool arrivedEarly,
  }) {
    var chance = fielder.role == FielderRole.wicketkeeper
        ? tuning.keeperCatchChance
        : tuning.baseCatchChance;
    if (runningCatch) chance -= 0.12;
    if (contact.power > 0.85) chance -= 0.12;
    if (contact.type == ContactType.edge) chance += 0.06;
    if (arrivedEarly) chance += 0.08;
    return chance.clamp(tuning.catchChanceMinimum, tuning.catchChanceMaximum);
  }

  RiskLevel riskForMargin(double marginSeconds) {
    if (marginSeconds > tuning.safeMarginSeconds) return RiskLevel.safe;
    if (marginSeconds < tuning.dangerMarginSeconds) return RiskLevel.danger;
    return RiskLevel.close;
  }

  /// The runner is safe when crease and stump break are simultaneous.
  bool isRunOut({required int stumpBreakMicros, required int creaseMicros}) =>
      stumpBreakMicros < creaseMicros;
}

final class ObjectiveUpdate {
  const ObjectiveUpdate(this.progress, this.completed);

  final int progress;
  final bool completed;
}

final class ScoringResolver {
  const ScoringResolver._();

  static String historyToken({
    required ExtraType extra,
    required int totalRuns,
    required int batAndRunningRuns,
    required int boundary,
    required DismissalType dismissal,
  }) {
    final parts = <String>[];
    if (extra == ExtraType.wide) parts.add('WD');
    if (extra == ExtraType.noBall) parts.add('NB');
    if (boundary > 0) {
      parts.add('$boundary');
    } else if (batAndRunningRuns > 0) {
      parts.add('$batAndRunningRuns');
    } else if (extra == ExtraType.none && totalRuns == 0) {
      parts.add('0');
    }
    if (dismissal != DismissalType.none) {
      parts.add(switch (dismissal) {
        DismissalType.bowled => 'BOWLED',
        DismissalType.caught => 'CAUGHT',
        DismissalType.runOut => 'RUN OUT',
        DismissalType.none => '',
      });
    }
    return parts.join('+');
  }

  static ObjectiveUpdate updateObjective(
    ObjectiveType objective,
    int currentProgress,
    BallResult result,
  ) {
    final progress = switch (objective) {
      ObjectiveType.twoBoundaries =>
        currentProgress + (result.isBoundary ? 1 : 0),
      ObjectiveType.sixRunsFirstThreeLegalBalls =>
        currentProgress + (result.legalBallsBefore < 3 ? result.totalRuns : 0),
      ObjectiveType.completeDouble => math.max(
        currentProgress,
        result.completedRunningRuns >= 2 ? 1 : 0,
      ),
    };
    final threshold = switch (objective) {
      ObjectiveType.twoBoundaries => 2,
      ObjectiveType.sixRunsFirstThreeLegalBalls => 6,
      ObjectiveType.completeDouble => 1,
    };
    return ObjectiveUpdate(progress, progress >= threshold);
  }

  static int nextCombo(int currentCombo, BallResult result) {
    if (result.isProductiveContact && !result.isWicket) {
      return math.min(3, currentCombo + 1);
    }
    if (result.isWicket ||
        (result.contactType != ContactType.none && result.totalRuns == 0)) {
      return 1;
    }
    // A no-contact extra does not alter combo.
    return currentCombo;
  }

  static int chargeFor(BallResult result, int increasedCombo) {
    final scoredFromContact = result.runsOffBat + result.completedRunningRuns;
    if (result.contactType == ContactType.none || scoredFromContact <= 0) {
      return 0;
    }
    final base = result.boundary == 6
        ? 3
        : result.boundary == 4
        ? 2
        : 1;
    return base + math.max(0, increasedCombo - 1);
  }

  static int starsForWin({
    required bool objectiveCompleted,
    required int legalBalls,
    required int wickets,
  }) {
    var stars = 1;
    if (objectiveCompleted) stars++;
    if (6 - legalBalls >= 2 || 2 - wickets >= 1) stars++;
    return stars;
  }
}
