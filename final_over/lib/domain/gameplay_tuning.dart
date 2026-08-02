import 'models.dart';

/// All changeable gameplay values live here so balancing never leaks into UI.
final class GameplayTuning {
  const GameplayTuning({
    this.fixedStepMicros = 16667,
    this.maximumFrameMicros = 250000,
    this.deliveryPreparationMicros = 3000000,
    this.runUpMicros = 900000,
    this.incomingToContactMicros = 650000,
    this.lateSwingGraceMicros = 276000,
    this.cameraTransitionMicros = 360000,
    this.impactHoldMicros = 450000,
    this.deliveryResultMicros = 650000,
    this.betweenBallsMicros = 450000,
    this.pickupDecisionMicros = 500000,
    this.perfectWindowMs = 50,
    this.goodWindowMs = 115,
    this.earlyLateWindowMs = 190,
    this.poorWindowMs = 275,
    this.batterReach = 0.085,
    this.stumpChannel = 0.028,
    this.maximumMovement = 0.012,
    this.groundBaseSpeed = 0.36,
    this.groundPowerSpeed = 0.64,
    this.groundDragPerSecond = 0.52,
    this.loftBaseSpeed = 0.42,
    this.loftPowerSpeed = 0.59,
    this.loftVerticalBaseSpeed = 0.55,
    this.loftVerticalPowerSpeed = 0.45,
    this.gravity = 1.65,
    this.landingSpeedRetention = 0.54,
    this.catchHeight = 0.025,
    this.fieldRadius = 1,
    this.pitchLength = 0.42,
    this.pitchWidth = 0.10,
    this.boundaryRadius = 1,
    this.ballPickupRadius = 0.045,
    this.catchRadius = 0.06,
    this.fielderSpeed = 0.29,
    this.backupSpeedFactor = 0.65,
    this.throwSpeed = 0.62,
    this.closeReactionSeconds = 0.24,
    this.deepReactionSeconds = 0.33,
    this.keeperReactionSeconds = 0.14,
    this.runDurationSeconds = 1.20,
    this.turnBackLimit = 0.45,
    this.closeCallSeconds = 0.09,
    this.safeMarginSeconds = 0.22,
    this.dangerMarginSeconds = -0.15,
    this.maximumRuns = 3,
    this.maximumLegalBalls = 18,
    this.maximumOvers = 3,
    this.ballsPerOver = 6,
    this.maximumWickets = 2,
    this.maximumNoBalls = 3,
    this.maximumWides = 5,
    this.noBallProbability = 0.02,
    this.wideProbability = 0.05,
    this.baseCatchChance = 0.82,
    this.keeperCatchChance = 0.88,
    this.catchChanceMinimum = 0.25,
    this.catchChanceMaximum = 0.95,
    this.dropSpeedMinimum = 0.35,
    this.dropSpeedMaximum = 0.60,
    this.powerShotSegments = 10,
    this.powerShotPowerMultiplier = 1.18,
    this.powerShotControlBonus = 0.08,
    this.chargeSeconds = 0.8125,
    this.chargePerfectCenter = 0.80,
    this.chargePerfectHalf = 0.10,
    this.chargeGoodHalf = 0.22,
    this.overswingFrom = 0.92,
    this.backliftPowerFloor = 0.55,
    this.overswingControlPenalty = 0.22,
    this.overswingEdgeBonus = 0.10,
  });

  final int fixedStepMicros;
  final int maximumFrameMicros;
  final int deliveryPreparationMicros;
  final int runUpMicros;
  final int incomingToContactMicros;
  final int lateSwingGraceMicros;
  final int cameraTransitionMicros;
  final int impactHoldMicros;
  final int deliveryResultMicros;
  final int betweenBallsMicros;
  final int pickupDecisionMicros;

  final int perfectWindowMs;
  final int goodWindowMs;
  final int earlyLateWindowMs;
  final int poorWindowMs;

  final double batterReach;
  final double stumpChannel;
  final double maximumMovement;
  final double groundBaseSpeed;
  final double groundPowerSpeed;
  final double groundDragPerSecond;
  final double loftBaseSpeed;
  final double loftPowerSpeed;
  final double loftVerticalBaseSpeed;
  final double loftVerticalPowerSpeed;
  final double gravity;
  final double landingSpeedRetention;
  final double catchHeight;
  final double fieldRadius;
  final double pitchLength;
  final double pitchWidth;
  final double boundaryRadius;
  final double ballPickupRadius;
  final double catchRadius;
  final double fielderSpeed;
  final double backupSpeedFactor;
  final double throwSpeed;
  final double closeReactionSeconds;
  final double deepReactionSeconds;
  final double keeperReactionSeconds;
  final double runDurationSeconds;
  final double turnBackLimit;
  final double closeCallSeconds;
  final double safeMarginSeconds;
  final double dangerMarginSeconds;
  final int maximumRuns;
  final int maximumLegalBalls;
  final int maximumOvers;
  final int ballsPerOver;
  final int maximumWickets;
  final int maximumNoBalls;
  final int maximumWides;
  final double noBallProbability;
  final double wideProbability;
  final double baseCatchChance;
  final double keeperCatchChance;
  final double catchChanceMinimum;
  final double catchChanceMaximum;
  final double dropSpeedMinimum;
  final double dropSpeedMaximum;

  /// Combo segments the batter must bank before OVERDRIVE can be armed. One
  /// source of truth: the HUD reads the same number the controller gates on.
  final int powerShotSegments;
  final double powerShotPowerMultiplier;
  final double powerShotControlBonus;

  // ── Backlift ───────────────────────────────────────────────────────────────
  // Hold a swing plate and the bat loads. How charged you are when you release
  // decides how hard you hit it; hold too long and you are slogging.

  /// Hold time from an empty bat to a fully loaded one.
  final double chargeSeconds;

  /// The charge that pays full power, and the band around it the meter draws.
  final double chargePerfectCenter;
  final double chargePerfectHalf;
  final double chargeGoodHalf;

  /// Past this you are overswinging: the power stays, the control does not.
  final double overswingFrom;

  /// Power multiplier on a completely uncharged swing — the safe little dab.
  final double backliftPowerFloor;
  final double overswingControlPenalty;
  final double overswingEdgeBonus;

  /// Shared difficulty presets used by the host app and balance tooling.
  static const rookie = GameplayTuning(
    perfectWindowMs: 80,
    goodWindowMs: 180,
    earlyLateWindowMs: 300,
    poorWindowMs: 400,
    lateSwingGraceMicros: 401000,
    maximumWickets: 4,
    baseCatchChance: 0.58,
    keeperCatchChance: 0.68,
    powerShotSegments: 4,
    fielderSpeed: 0.24,
    throwSpeed: 0.56,
    closeReactionSeconds: 0.30,
    deepReactionSeconds: 0.40,
    keeperReactionSeconds: 0.18,
    batterReach: 0.100,
    groundBaseSpeed: 0.396,
    groundPowerSpeed: 0.704,
    loftBaseSpeed: 0.462,
    loftPowerSpeed: 0.649,
    backliftPowerFloor: 0.75,
    overswingFrom: 0.98,
    overswingControlPenalty: 0.10,
    overswingEdgeBonus: 0.04,
  );

  static const pro = GameplayTuning(
    perfectWindowMs: 65,
    goodWindowMs: 150,
    earlyLateWindowMs: 245,
    poorWindowMs: 330,
    lateSwingGraceMicros: 331000,
    maximumWickets: 3,
    baseCatchChance: 0.68,
    keeperCatchChance: 0.76,
    powerShotSegments: 5,
    fielderSpeed: 0.27,
    throwSpeed: 0.59,
    closeReactionSeconds: 0.27,
    deepReactionSeconds: 0.36,
    keeperReactionSeconds: 0.16,
    batterReach: 0.092,
    groundBaseSpeed: 0.378,
    groundPowerSpeed: 0.672,
    loftBaseSpeed: 0.441,
    loftPowerSpeed: 0.627,
    backliftPowerFloor: 0.65,
    overswingFrom: 0.95,
    overswingControlPenalty: 0.16,
    overswingEdgeBonus: 0.07,
  );

  static const elite = GameplayTuning(
    perfectWindowMs: 50,
    goodWindowMs: 115,
    earlyLateWindowMs: 190,
    poorWindowMs: 275,
    lateSwingGraceMicros: 276000,
    maximumWickets: 2,
    baseCatchChance: 0.82,
    keeperCatchChance: 0.88,
    powerShotSegments: 8,
    fielderSpeed: 0.29,
    throwSpeed: 0.62,
    closeReactionSeconds: 0.24,
    deepReactionSeconds: 0.33,
    keeperReactionSeconds: 0.14,
    batterReach: 0.085,
    groundBaseSpeed: 0.36,
    groundPowerSpeed: 0.64,
    loftBaseSpeed: 0.42,
    loftPowerSpeed: 0.59,
    backliftPowerFloor: 0.55,
    overswingFrom: 0.92,
    overswingControlPenalty: 0.22,
    overswingEdgeBonus: 0.10,
  );

  /// Approved chase ladder for the three-over format (32–66).
  static const targetOptions = <int>[32, 36, 40, 44, 48, 52, 56, 58, 62, 66];

  static const targetMinimum = 32;
  static const targetMaximum = 66;

  static const lineX = <DeliveryLine, double>{
    DeliveryLine.wideOff: -0.11,
    DeliveryLine.off: -0.035,
    DeliveryLine.middle: 0,
    DeliveryLine.leg: 0.035,
    DeliveryLine.wideLeg: 0.11,
  };

  /// Five balanced shapes. The seed chooses the opening shape and every
  /// physical delivery advances one slot, so wides and no-balls trigger the
  /// same visible tactical reset as legal balls.
  static final List<FieldLayout> fieldLayouts = List.unmodifiable([
    _fieldLayout('balanced', 'BALANCED', const [
      FieldVector(-0.78, -0.12),
      FieldVector(0.78, -0.12),
      FieldVector(-0.45, -0.72),
      FieldVector(0.45, -0.72),
      FieldVector(-0.72, 0.48),
      FieldVector(0.72, 0.48),
      FieldVector(-0.18, -0.82),
      FieldVector(0.18, -0.82),
    ]),
    _fieldLayout('off-guard', 'OFF GUARD', const [
      FieldVector(-0.82, -0.10),
      FieldVector(-0.64, -0.50),
      FieldVector(-0.42, -0.78),
      FieldVector(-0.18, -0.88),
      FieldVector(-0.58, 0.38),
      FieldVector(0.64, -0.58),
      FieldVector(0.80, 0.14),
      FieldVector(0.42, 0.60),
    ]),
    _fieldLayout('leg-guard', 'LEG GUARD', const [
      FieldVector(0.82, -0.10),
      FieldVector(0.64, -0.50),
      FieldVector(0.42, -0.78),
      FieldVector(0.18, -0.88),
      FieldVector(0.58, 0.38),
      FieldVector(-0.64, -0.58),
      FieldVector(-0.80, 0.14),
      FieldVector(-0.42, 0.60),
    ]),
    _fieldLayout('straight-wall', 'STRAIGHT WALL', const [
      FieldVector(-0.74, -0.30),
      FieldVector(0.74, -0.30),
      FieldVector(-0.52, -0.72),
      FieldVector(0.52, -0.72),
      FieldVector(-0.26, -0.91),
      FieldVector(0.26, -0.91),
      FieldVector(-0.66, 0.43),
      FieldVector(0.66, 0.43),
    ]),
    _fieldLayout('close-attack', 'CLOSE ATTACK', const [
      FieldVector(-0.40, -0.32),
      FieldVector(0.40, -0.32),
      FieldVector(-0.28, -0.54),
      FieldVector(0.28, -0.54),
      FieldVector(-0.62, -0.66),
      FieldVector(0.62, -0.66),
      FieldVector(-0.48, 0.44),
      FieldVector(0.48, 0.44),
    ]),
  ]);

  /// Backwards-compatible alias for simulations that explicitly request the
  /// original neutral field.
  static final List<FielderState> balancedField = fieldLayouts.first.fielders;

  static FieldLayout fieldLayoutFor({
    required int matchSeed,
    required int physicalOrdinal,
  }) {
    final count = fieldLayouts.length;
    final seededStart = ((matchSeed % count) + count) % count;
    final deliveryOffset = physicalOrdinal <= 1 ? 0 : physicalOrdinal - 1;
    return fieldLayouts[(seededStart + deliveryOffset) % count];
  }

  static FieldLayout _fieldLayout(
    String id,
    String label,
    List<FieldVector> outfield,
  ) {
    assert(outfield.length == 8);
    return FieldLayout(
      id: id,
      label: label,
      fielders: [
        for (var index = 0; index < outfield.length; index++)
          FielderState(
            id: index,
            role: FielderRole.outfielder,
            homePosition: outfield[index],
            position: outfield[index],
          ),
        const FielderState(
          id: 8,
          role: FielderRole.wicketkeeper,
          homePosition: FieldVector(0, 0.27),
          position: FieldVector(0, 0.27),
        ),
        const FielderState(
          id: 9,
          role: FielderRole.bowler,
          homePosition: FieldVector(0, -0.05),
          position: FieldVector(0, -0.05),
        ),
      ],
    );
  }
}
