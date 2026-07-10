/// Every tunable constant for Hoop Duel in one place (mirrors the Grand Prix
/// engine's tuning discipline). Pure Dart — no Flutter imports.
///
/// World units are metres along a single axis x (the side-view court), plus a
/// height axis h for the ball and jumps. The hoop is on the RIGHT.
/// Distances to the rim are `d = kBbRimX - x`.
library;

// ---------------------------------------------------------------------------
// Court geometry
// ---------------------------------------------------------------------------
const double kBbCourtMinX = 0.0;
const double kBbCourtMaxX = 12.6;
const double kBbRimX = 11.6;
const double kBbBackboardX = 11.95;
const double kBbRimHeight = 3.05;

/// Three-point distance from the rim; the arc line sits at x = kBbRimX - this.
const double kBbArcDist = 6.75;

/// Offense/defense reset spots after a made basket / turnover.
const double kBbCheckSpotX = 3.2;
const double kBbDefResetX = 5.6;

/// Shot-zone boundaries by distance to the rim.
const double kBbDunkGate = 1.5;
const double kBbDunkGateRimPressure = 2.2;
const double kBbLayupRange = 2.4;
const double kBbCloseRange = 4.5;

// ---------------------------------------------------------------------------
// Clocks & flow
// ---------------------------------------------------------------------------
const double kBbHalfSeconds = 45;
const double kBbShotClockSeconds = 12;

/// Dead-ball reset (post-basket / violation) — players lerp to reset spots.
const double kBbResetSeconds = 0.9;

// ---------------------------------------------------------------------------
// Movement
// ---------------------------------------------------------------------------
/// Base run speed (m/s) at 70 SPD; scales ±20% across the rating range.
const double kBbBaseSpeed = 3.4;
const double kBbDriveMult = 1.5;
const double kBbStanceMult = 0.62;
const double kBbProtectMult = 0.7;
const double kBbDriveDuration = 0.9;
const double kBbBurstStaminaCost = 12;

/// A direction flip within this window of the previous one = crossover.
const double kBbCrossoverWindow = 0.22;
const double kBbCrossoverDuration = 0.25;
const double kBbStepbackDistance = 0.9;
const double kBbStepbackDuration = 0.3;

/// Guarded auto ball-protection kicks in inside this gap.
const double kBbGuardedGap = 1.4;

/// Soft body separation — bodies can't overlap closer than this.
const double kBbBodyGap = 0.45;

// ---------------------------------------------------------------------------
// Jumps & shot meter
// ---------------------------------------------------------------------------
const double kBbGatherSeconds = 0.12;
const double kBbGatherQuickRelease = 0.08;
const double kBbJumpShotDuration = 0.75;
const double kBbLayupDuration = 0.6;
const double kBbDunkDuration = 0.65;
const double kBbBlockJumpDuration = 0.6;
const double kBbReboundJumpDuration = 0.55;

/// Meter apex (perfect point) as a fraction of the shot jump.
const double kBbShotApexFrac = 0.42;
const double kBbShotApexQuickRelease = 0.36;
const double kBbMaxJumpHeight = 0.75;

/// Perfect half-window (seconds) at rating 50 before modifiers.
const double kBbPerfectHalfWindow = 0.06;

/// Good grade extends this far beyond the perfect window on both sides.
const double kBbGoodHalfWindow = 0.14;

// ---------------------------------------------------------------------------
// Shot model (probabilities multiply, then clamp)
// ---------------------------------------------------------------------------
const double kBbBaseLayup = 0.58;
const double kBbBaseClose = 0.50;
const double kBbBaseMid = 0.46;
const double kBbBaseThree = 0.40;

/// Make-chance change per rating point away from 70.
const double kBbRatingSlope = 0.004;

/// Make-chance loss per metre beyond the zone's reference distance.
const double kBbDistanceSlope = 0.03;

const double kBbTimingPerfect = 1.30;
const double kBbTimingGood = 1.00;
const double kBbTimingEarlyLate = 0.55;

/// Max contest suppression (at gap 0 with a synced jump contest).
const double kBbContestMax = 0.55;
const double kBbContestRange = 2.2;

const double kBbBalanceMoving = 0.85;
const double kBbBalanceStepback = 0.92;

const double kBbHeatShotBonus = 1.12;
const double kBbRepeatPenalty = 0.9;
const int kBbRepeatMaxStacks = 2;

const double kBbShotFloor = 0.02;
const double kBbShotCap = 0.88;
const double kBbShotCapPerfect = 0.93;

/// Put-back bonus on top of the layup base.
const double kBbPutbackBonus = 0.10;
const double kBbPutbackWindow = 0.9;

// ---------------------------------------------------------------------------
// Defense
// ---------------------------------------------------------------------------
const double kBbStealReach = 1.1;
const double kBbStealActiveFrom = 0.08;
const double kBbStealActiveTo = 0.20;
const double kBbStealBase = 0.35;
const double kBbStealRatingSlope = 0.005;
const double kBbStealExposedBonus = 0.25;
const double kBbStealProtectedPenalty = 0.65;
const double kBbWhiffRecover = 0.55;

/// Grounded contest arm-up bonus and its trigger gap.
const double kBbContestGap = 2.2;

/// Block: jump must start within this window of the release to connect.
const double kBbBlockSyncWindow = 0.14;
const double kBbBlockReachBase = 1.2;
const double kBbBlockReachSlope = 0.004;
const double kBbBlockDunkBase = 0.35;
const double kBbStaggerSeconds = 0.6;
const double kBbFakeSeconds = 0.35;

// ---------------------------------------------------------------------------
// Rebounds
// ---------------------------------------------------------------------------
/// Ball becomes grabbable below this height while loose.
const double kBbCatchHeight = 2.6;
const double kBbReboundReach = 0.95;
const double kBbBoxOutBonus = 0.4;
const double kBbGlassCleanerBonus = 0.15;
const double kBbGroundPickupRange = 0.7;
const double kBbGravity = 9.8;

/// A loose ball nobody recovers this long is scooped by the nearest player, so
/// there's never dead time (and the half can always end).
const double kBbLooseTimeout = 3.5;

// ---------------------------------------------------------------------------
// Stamina (0–100)
// ---------------------------------------------------------------------------
const double kBbDrainDrivePerSec = 12;
const double kBbDrainCrossover = 3;
const double kBbDrainJumpShot = 6;
const double kBbDrainDunk = 18;
const double kBbDrainBlockJump = 8;
const double kBbDrainLunge = 5;
const double kBbDrainContest = 2;
const double kBbDrainReboundJump = 6;
const double kBbDrainStancePerSec = 1.5;
const double kBbRegenCalmPerSec = 8;
const double kBbRegenResetPerSec = 15;
const double kBbHalftimeActiveRegen = 40;
const double kBbDunkStaminaGate = 35;

/// Low-stamina floors (fully tired ⇒ these multipliers).
const double kBbTiredSpeedFloor = 0.85;
const double kBbTiredJumpFloor = 0.9;
const double kBbTiredWindowFloor = 0.7;

// ---------------------------------------------------------------------------
// Heat
// ---------------------------------------------------------------------------
const double kBbHeatPerBasket = 0.34;
const double kBbHeatPerStop = 0.12;
const double kBbHeatPerBoard = 0.08;
const double kBbHeatDuration = 15;
const double kBbHeatWindowMult = 1.25;
const double kBbHeatSpeedMult = 1.08;
const double kBbHeatDrainMult = 0.6;

// ---------------------------------------------------------------------------
// AI
// ---------------------------------------------------------------------------
const double kBbAiLatencyRookie = 0.40;
const double kBbAiLatencyPro = 0.25;
const double kBbAiLatencyAllStar = 0.16;
const double kBbAiJitterRookie = 0.12;
const double kBbAiJitterPro = 0.07;
const double kBbAiJitterAllStar = 0.04;
const double kBbAiEpsilonRookie = 0.35;
const double kBbAiEpsilonPro = 0.18;
const double kBbAiEpsilonAllStar = 0.08;
const double kBbAiBiteRookie = 0.55;
const double kBbAiBitePro = 0.30;
const double kBbAiBiteAllStar = 0.15;
