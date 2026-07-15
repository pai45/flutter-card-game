/// Presentation beats for Final Over.
///
/// Gameplay tuning does NOT live here — that is `GameplayTuning` inside the
/// `final_over` package, and it is the only thing allowed to change how a match
/// plays out. Everything below is render-facing: how hard the camera kicks and
/// how long a celebration runs. Changing any of it must not change a single run
/// scored.
library;

/// Screen shake on contact / boundary / wicket.
const double kFoShakeSeconds = 0.32;
const double kFoShakeContact = 5.0;
const double kFoShakeWicket = 8.0;

/// Focal zoom-punch on a run-out or a completed run — the moment the chase
/// tightens.
const double kFoCineSeconds = 0.55;
const double kFoCineZoom = 0.055;

/// How long a full-screen effect (impact ring, boundary pulse, wicket burst)
/// lives.
const double kFoEffectSeconds = 1.1;

/// The last legal ball dims the edges of the world. Cheap, and it works.
const double kFoFinalBallVignette = 0.62;

/// How long a HUD sting (SIX / FOUR / OUT / PERFECT) stays up.
const double kFoStingMajorMs = 1500;
const double kFoStingMinorMs = 1000;

/// Bowler run-up leg-cycle speed, in radians of phase per unit of run-up
/// progress.
const double kFoRunUpCycle = 26.0;

/// The crowd. It never goes completely quiet, it goes berserk for a boundary or
/// a wicket, and it takes a couple of seconds to come back down.
const int kFoCrowdDots = 96;
const double kFoCrowdIdleHype = 0.22;
const double kFoCrowdHypeSeconds = 2.2;
