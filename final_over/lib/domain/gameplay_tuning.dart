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
    this.impactHoldMicros = 80000,
    this.deliveryResultMicros = 650000,
    this.betweenBallsMicros = 450000,
    this.pickupDecisionMicros = 350000,
    this.perfectWindowMs = 50,
    this.goodWindowMs = 115,
    this.earlyLateWindowMs = 190,
    this.poorWindowMs = 275,
    this.batterReach = 0.085,
    this.stumpChannel = 0.028,
    this.maximumMovement = 0.012,
    this.groundBaseSpeed = 0.42,
    this.groundPowerSpeed = 0.78,
    this.groundDragPerSecond = 0.72,
    this.loftBaseSpeed = 0.45,
    this.loftPowerSpeed = 0.65,
    this.loftVerticalBaseSpeed = 0.55,
    this.loftVerticalPowerSpeed = 0.45,
    this.gravity = 1.65,
    this.landingSpeedRetention = 0.62,
    this.catchHeight = 0.025,
    this.fieldRadius = 1,
    this.pitchLength = 0.42,
    this.pitchWidth = 0.10,
    this.boundaryRadius = 1,
    this.ballPickupRadius = 0.045,
    this.catchRadius = 0.06,
    this.fielderSpeed = 0.35,
    this.backupSpeedFactor = 0.70,
    this.throwSpeed = 0.78,
    this.closeReactionSeconds = 0.18,
    this.deepReactionSeconds = 0.24,
    this.keeperReactionSeconds = 0.12,
    this.runDurationSeconds = 1.38,
    this.turnBackLimit = 0.45,
    this.closeCallSeconds = 0.09,
    this.safeMarginSeconds = 0.30,
    this.dangerMarginSeconds = -0.15,
    this.maximumRuns = 3,
    this.maximumLegalBalls = 6,
    this.maximumWickets = 2,
    this.maximumNoBalls = 1,
    this.maximumWides = 2,
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
    maximumWickets: 3,
    baseCatchChance: 0.58,
    keeperCatchChance: 0.68,
    powerShotSegments: 4,
    fielderSpeed: 0.28,
    throwSpeed: 0.68,
    closeReactionSeconds: 0.24,
    deepReactionSeconds: 0.32,
    keeperReactionSeconds: 0.16,
    batterReach: 0.100,
    groundBaseSpeed: 0.462,
    groundPowerSpeed: 0.858,
    loftBaseSpeed: 0.495,
    loftPowerSpeed: 0.715,
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
    maximumWickets: 2,
    baseCatchChance: 0.68,
    keeperCatchChance: 0.76,
    powerShotSegments: 5,
    fielderSpeed: 0.32,
    throwSpeed: 0.73,
    closeReactionSeconds: 0.21,
    deepReactionSeconds: 0.28,
    keeperReactionSeconds: 0.14,
    batterReach: 0.092,
    groundBaseSpeed: 0.441,
    groundPowerSpeed: 0.819,
    loftBaseSpeed: 0.4725,
    loftPowerSpeed: 0.6825,
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
    fielderSpeed: 0.35,
    throwSpeed: 0.78,
    closeReactionSeconds: 0.18,
    deepReactionSeconds: 0.24,
    keeperReactionSeconds: 0.12,
    batterReach: 0.085,
    groundBaseSpeed: 0.42,
    groundPowerSpeed: 0.78,
    loftBaseSpeed: 0.45,
    loftPowerSpeed: 0.65,
    backliftPowerFloor: 0.55,
    overswingFrom: 0.92,
    overswingControlPenalty: 0.22,
    overswingEdgeBonus: 0.10,
  );

  static const targetOptions = <int>[8, 10, 12, 14, 16, 18, 20];

  static const lineX = <DeliveryLine, double>{
    DeliveryLine.wideOff: -0.11,
    DeliveryLine.off: -0.035,
    DeliveryLine.middle: 0,
    DeliveryLine.leg: 0.035,
    DeliveryLine.wideLeg: 0.11,
  };

  /// Eight outfield dots plus a wicketkeeper and bowler.
  static const balancedField = <FielderState>[
    FielderState(
      id: 0,
      role: FielderRole.outfielder,
      homePosition: FieldVector(-0.78, -0.12),
      position: FieldVector(-0.78, -0.12),
    ),
    FielderState(
      id: 1,
      role: FielderRole.outfielder,
      homePosition: FieldVector(0.78, -0.12),
      position: FieldVector(0.78, -0.12),
    ),
    FielderState(
      id: 2,
      role: FielderRole.outfielder,
      homePosition: FieldVector(-0.45, -0.72),
      position: FieldVector(-0.45, -0.72),
    ),
    FielderState(
      id: 3,
      role: FielderRole.outfielder,
      homePosition: FieldVector(0.45, -0.72),
      position: FieldVector(0.45, -0.72),
    ),
    FielderState(
      id: 4,
      role: FielderRole.outfielder,
      homePosition: FieldVector(-0.72, 0.48),
      position: FieldVector(-0.72, 0.48),
    ),
    FielderState(
      id: 5,
      role: FielderRole.outfielder,
      homePosition: FieldVector(0.72, 0.48),
      position: FieldVector(0.72, 0.48),
    ),
    FielderState(
      id: 6,
      role: FielderRole.outfielder,
      homePosition: FieldVector(-0.18, -0.82),
      position: FieldVector(-0.18, -0.82),
    ),
    FielderState(
      id: 7,
      role: FielderRole.outfielder,
      homePosition: FieldVector(0.18, -0.82),
      position: FieldVector(0.18, -0.82),
    ),
    FielderState(
      id: 8,
      role: FielderRole.wicketkeeper,
      homePosition: FieldVector(0, 0.27),
      position: FieldVector(0, 0.27),
    ),
    FielderState(
      id: 9,
      role: FielderRole.bowler,
      homePosition: FieldVector(0, -0.05),
      position: FieldVector(0, -0.05),
    ),
  ];
}
