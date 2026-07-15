/// Flame renderer + real-time loop for Hoop Duel.
///
/// Mirrors Grand Prix Dash: the 60fps simulation lives HERE — `update(dt)`
/// advances the pure [BasketballEngine] in fixed substeps, the CPU thumb is a
/// seeded [BasketballAI], and only coarse events flow up to the screen/cubit.
/// High-frequency HUD values (clocks, stamina, heat, the shot meter) are
/// [ValueNotifier]s so nothing emits bloc state per frame. All drawing is
/// procedural Canvas on `Cyber` tokens; athlete looks are the content-color
/// exception.
library;

import 'dart:collection';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart' show Colors, TextPainter;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flame/text.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;

import '../../config/theme.dart';
import '../../data/basketball_teams.dart';
import '../../models/basketball.dart';
import 'basketball_ai.dart';
import 'basketball_engine.dart';
import 'basketball_rig.dart';
import 'basketball_tuning.dart';

/// One transient HUD banner ("PERFECT RELEASE", "ANKLE BREAKER", …).
class BasketballSting {
  const BasketballSting(this.id, this.label, this.color, {this.major = false});

  final int id;
  final String label;
  final Color color;

  /// Major stings slam bigger and hold longer.
  final bool major;
}

class BasketballGame extends FlameGame {
  BasketballGame({
    required this.config,
    required this.onEvents,
    this.reducedMotion = false,
  }) : engine = BasketballEngine(config),
       _ai = BasketballAI(
         difficulty: config.difficulty,
         seed: config.seed ^ 0xa11ce,
       );

  final BasketballMatchConfig config;

  /// Coarse per-frame event batch — the screen maps these to sounds, haptics
  /// and cubit phase changes.
  final void Function(List<BasketballEvent> events) onEvents;
  final bool reducedMotion;

  final BasketballEngine engine;
  final BasketballAI _ai;
  final Random _fxRng = Random();

  // HUD bindings — cheap 60fps reads, never bloc emissions.
  final ValueNotifier<int> scorePlayer = ValueNotifier(0);
  final ValueNotifier<int> scoreCpu = ValueNotifier(0);
  final ValueNotifier<int> halfClockTenths = ValueNotifier(
    (kBbHalfSeconds * 10).round(),
  );
  final ValueNotifier<int> shotClockSeconds = ValueNotifier(
    kBbShotClockSeconds.round(),
  );
  final ValueNotifier<double> stamina01 = ValueNotifier(1);
  final ValueNotifier<double> heatPlayer = ValueNotifier(0);
  final ValueNotifier<double> heatCpu = ValueNotifier(0);
  final ValueNotifier<bool> heatActivePlayer = ValueNotifier(false);
  final ValueNotifier<bool> heatActiveCpu = ValueNotifier(false);
  final ValueNotifier<ShotMeterView?> meter = ValueNotifier(null);
  final ValueNotifier<int> possession = ValueNotifier(0);
  final ValueNotifier<BasketballSting?> sting = ValueNotifier(null);

  // Input state fed by the Flutter control pads.
  double _moveAxis = 0;
  bool _actionDown = false;
  double _heldT = 0;
  bool _burstQueued = false;
  bool _pressQueued = false;
  bool _releaseQueued = false;
  double _releaseHeld = 0;
  bool _swipeQueued = false;

  bool _paused = false;
  double _accumulator = 0;
  double _slowMoT = 0;
  double _shakeT = 0;
  double _shakeMag = 0;
  double _cineT = 0;
  double _camX = kBbCheckSpotX + 2;
  Offset _shake = Offset.zero;
  int _stingId = 0;

  /// Net sway impulse, consumed by the court renderer.
  double netSway = 0;

  /// Crowd surge impulse (0..1) on big plays — lifts the bob amplitude and
  /// camera flashes beyond the sustained heat "hyped" state.
  double crowdHype = 0;

  /// Backboard score-flash: decaying timer + the scorer's livery color.
  double scoreFlashT = 0;
  Color scoreFlashColor = Cyber.cyan;

  /// Global dribble phase so both ball and player rig can sync.
  double dribblePhase = 0;

  static const double _subDt = 1 / 120;

  // -- world → screen mapping -------------------------------------------------

  double get pxPerUnit => size.x / 8.2;

  double get floorY => size.y * 0.62;

  Offset worldToScreen(double x, double h) => Offset(
    (x - _camX) * pxPerUnit + size.x / 2 + _shake.dx,
    floorY - h * pxPerUnit + _shake.dy,
  );

  @override
  Color backgroundColor() => Cyber.bg;

  /// Impact cinematic (Super Over technique): a decaying focal zoom-punch +
  /// jitter about the rim, applied to the whole canvas for the first ~0.3s
  /// after a dunk/poster/big block. Replaces the old global zoom pulse.
  @override
  void render(Canvas canvas) {
    if (_cineT > 0 && !reducedMotion) {
      final impact = _cineT / kBbCineSeconds;
      final focal = worldToScreen(kBbRimX, kBbRimHeight);
      canvas.save();
      canvas.translate(
        sin(_cineT * 47) * impact * 3,
        cos(_cineT * 53) * impact * 3,
      );
      final zoom = 1 + impact * kBbCineZoom;
      canvas.translate(focal.dx, focal.dy);
      canvas.scale(zoom, zoom);
      canvas.translate(-focal.dx, -focal.dy);
      super.render(canvas);
      canvas.restore();
      return;
    }
    super.render(canvas);
  }

  @override
  Future<void> onLoad() async {
    add(_CourtComponent()..priority = -10);
    add(_LandingMarkerComponent()..priority = -5);
    add(AthleteComponent(team: 1)..priority = 10);
    add(AthleteComponent(team: 0)..priority = 12);
    add(_BallComponent()..priority = 15);
  }

  // -- input API (called by the Flutter control pads) -------------------------

  void setMoveAxis(double axis) => _moveAxis = axis.clamp(-1, 1);

  void tapBurst() => _burstQueued = true;

  void actionPressed() {
    _actionDown = true;
    _heldT = 0;
    _pressQueued = true;
  }

  void actionReleased() {
    if (!_actionDown && !_pressQueued) return;
    _releaseQueued = true;
    _releaseHeld = _heldT;
    _actionDown = false;
  }

  void swipeBack() {
    _swipeQueued = true;
    // A step-back swipe supersedes the hold that started it.
    _actionDown = false;
    _pressQueued = false;
    _releaseQueued = false;
  }

  void cancelTouches() {
    _moveAxis = 0;
    _actionDown = false;
    _pressQueued = false;
    _releaseQueued = false;
    _swipeQueued = false;
    _burstQueued = false;
  }

  // -- match flow API (cubit-driven via the screen) ---------------------------

  void setPaused(bool paused) => _paused = paused;

  void startHalf(int index) {
    engine.startHalf(index);
    cancelTouches();
  }

  void substitutePlayer(int rosterIndex) => engine.substitute(0, rosterIndex);

  /// CPU halftime brain: bring in the freshest bench athlete when gassed.
  void cpuAutoSubstitute() {
    final sim = engine.teams[1];
    if (engine.cpuBody.stamina >= 55) return;
    var best = sim.activeIndex;
    var bestStamina = engine.cpuBody.stamina;
    for (var i = 0; i < sim.staminas.length; i++) {
      if (i == sim.activeIndex) continue;
      if (sim.staminas[i] > bestStamina + 10) {
        best = i;
        bestStamina = sim.staminas[i];
      }
    }
    if (best != sim.activeIndex) engine.substitute(1, best);
  }

  void halftimeRest() => engine.halftimeRest();

  BasketballMatchSummary summary({bool abandoned = false}) =>
      engine.summary(abandoned: abandoned);

  // -- loop --------------------------------------------------------------------

  @override
  void update(double dt) {
    super.update(dt);
    final wallDt = min(dt, 1 / 30);

    if (!_paused) {
      var simDt = wallDt;
      if (_slowMoT > 0) {
        _slowMoT = max(0, _slowMoT - wallDt);
        simDt = wallDt * 0.25;
      }
      _accumulator += simDt;
      final frameEvents = <BasketballEvent>[];
      var first = true;
      while (_accumulator >= _subDt) {
        _accumulator -= _subDt;
        frameEvents.addAll(_stepOnce(consumeEdges: first));
        first = false;
      }
      if (frameEvents.isNotEmpty) {
        _handleEvents(frameEvents);
        onEvents(frameEvents);
      }
    }

    _decayFx(wallDt);
    _syncCamera(wallDt);
    _syncNotifiers();
    dribblePhase += wallDt * 7;
  }

  List<BasketballEvent> _stepOnce({required bool consumeEdges}) {
    if (_actionDown) _heldT += _subDt;
    final intent = BasketballIntent(
      moveAxis: _moveAxis,
      burst: consumeEdges && _burstQueued,
      actionDown: _actionDown,
      actionPressed: consumeEdges && _pressQueued,
      actionReleased: consumeEdges && _releaseQueued,
      heldSeconds: consumeEdges && _releaseQueued ? _releaseHeld : _heldT,
      swipeBack: consumeEdges && _swipeQueued,
    );
    if (consumeEdges) {
      _burstQueued = false;
      _pressQueued = false;
      if (_releaseQueued) {
        _releaseQueued = false;
        _heldT = 0;
      }
      _swipeQueued = false;
    }
    final cpuIntent = _ai.think(engine, _subDt);
    return engine.step(intent, cpuIntent, _subDt);
  }

  void _decayFx(double wallDt) {
    if (_shakeT > 0) {
      _shakeT = max(0, _shakeT - wallDt);
      final k = _shakeT * _shakeMag;
      _shake = Offset(
        (_fxRng.nextDouble() - 0.5) * 2 * k,
        (_fxRng.nextDouble() - 0.5) * 2 * k,
      );
    } else {
      _shake = Offset.zero;
    }
    _cineT = max(0, _cineT - wallDt);
    crowdHype = max(0, crowdHype - wallDt * 0.8);
    scoreFlashT = max(0, scoreFlashT - wallDt);
    netSway = max(0, netSway - wallDt * 2.4);
  }

  void _syncCamera(double wallDt) {
    final ball = engine.ball;
    final mid = (engine.playerBody.x + engine.cpuBody.x) / 2;
    final target = ball.x * 0.55 + mid * 0.45;
    final halfView = size.x / 2 / pxPerUnit;
    final minCam = kBbCourtMinX - 0.4 + halfView;
    final maxCam = kBbCourtMaxX + 0.6 - halfView;
    final clamped = maxCam > minCam
        ? target.clamp(minCam, maxCam)
        : (minCam + maxCam) / 2;
    final k = 1 - exp(-6 * wallDt);
    _camX += (clamped - _camX) * k;
  }

  void _syncNotifiers() {
    scorePlayer.value = engine.teams[0].score;
    scoreCpu.value = engine.teams[1].score;
    halfClockTenths.value = (engine.halfClock * 10).ceil();
    shotClockSeconds.value = engine.shotClock.clamp(0, 99).ceil();
    stamina01.value = (engine.playerBody.stamina / 100 * 100).round() / 100;
    heatPlayer.value = (engine.teams[0].heatMeter * 100).round() / 100;
    heatCpu.value = (engine.teams[1].heatMeter * 100).round() / 100;
    heatActivePlayer.value = engine.teams[0].heatActive;
    heatActiveCpu.value = engine.teams[1].heatActive;
    meter.value = engine.meterView(0);
    possession.value = engine.ball.holder;
  }

  // -- event → juice mapping ---------------------------------------------------

  void _handleEvents(List<BasketballEvent> events) {
    for (final event in events) {
      switch (event.type) {
        case BasketballEventType.basketMade:
          netSway = 1;
          _swishBurst();
          crowdHype = 1;
          scoreFlashT = kBbScoreFlashSeconds;
          scoreFlashColor = basketballTeamById(
            event.team == 0 ? config.teamId : config.cpuTeamId,
          ).primary;
          final mine = event.team == 0;
          final three = event.points == 3;
          if (event.grade == ReleaseGrade.perfect && three && mine) {
            _slowMo(0.4);
          }
          _sting(
            mine ? '+${event.points}' : 'CONCEDED +${event.points}',
            mine ? (three ? Cyber.gold : Cyber.lime) : Cyber.danger,
            major: three && mine,
          );
        case BasketballEventType.buzzerBeater:
          _slowMo(0.5);
          crowdHype = 1;
          _sting('BUZZER BEATER!', Cyber.gold, major: true);
        case BasketballEventType.dunk:
          _shakeNow(0.28, 9);
          _cineT = kBbCineSeconds;
          crowdHype = 1;
          _sting(
            event.team == 0
                ? _pick(const ['THROWN DOWN!', 'HAMMER TIME!', 'WITH AUTHORITY!'])
                : 'DUNKED ON YOUR RIM',
            event.team == 0 ? Cyber.gold : Cyber.danger,
            major: event.team == 0,
          );
        case BasketballEventType.poster:
          _slowMo(0.4);
          _cineT = kBbCineSeconds;
          _sting(
            _pick(const ['POSTERIZED!', 'PUT ON A POSTER!']),
            Cyber.gold,
            major: true,
          );
        case BasketballEventType.block:
          _shakeNow(0.22, 7);
          crowdHype = 1;
          if (event.onDunk) _cineT = kBbCineSeconds;
          _sparkBurst(
            worldToScreen(engine.ball.x, engine.ball.h),
            Cyber.cyan,
            14,
          );
          _sting(
            event.team == 0
                ? _pick(const ['BLOCKED!', 'NOT TODAY!', 'SENT BACK!'])
                : _pick(const ['REJECTED!', 'SWATTED AWAY!']),
            event.team == 0 ? Cyber.cyan : Cyber.danger,
            major: event.onDunk,
          );
        case BasketballEventType.steal:
          _sting(
            event.team == 0 ? _pick(const ['STOLEN!', 'PICKED HIS POCKET!']) : 'TURNOVER!',
            event.team == 0 ? Cyber.cyan : Cyber.danger,
          );
        case BasketballEventType.ankleBreaker:
          _slowMo(0.25);
          _sting(
            _pick(const ['ANKLE BREAKER!', 'SHIFTED!', 'CROSSED UP!']),
            Cyber.violet,
            major: true,
          );
        case BasketballEventType.spinMove:
          _sting(
            event.team == 0
                ? _pick(const ['SPIN CYCLE!', 'REVERSED!'])
                : 'SPUN PAST YOU',
            event.team == 0 ? Cyber.violet : Cyber.danger,
          );
        case BasketballEventType.perfectRelease:
          if (event.team == 0) {
            _sting(_pick(const ['PERFECT', 'SPLASH INCOMING']), Cyber.lime);
          }
        case BasketballEventType.heatStarted:
          _sting(
            event.team == 0 ? 'YOU\'RE ON FIRE!' : 'OPPONENT HEATING UP',
            event.team == 0 ? Cyber.gold : Cyber.danger,
            major: event.team == 0,
          );
        case BasketballEventType.shotClockViolation:
          _sting(
            event.team == 0 ? 'SHOT CLOCK!' : 'FORCED THE STOP!',
            event.team == 0 ? Cyber.danger : Cyber.cyan,
          );
        case BasketballEventType.shotMissed:
          _sparkBurst(worldToScreen(kBbRimX, kBbRimHeight), Cyber.amber, 8);
          netSway = max(netSway, 0.35);
        case BasketballEventType.rebound:
          if (event.offensive && event.team == 0) {
            _sting('OFF. BOARD — PUT IT BACK!', Cyber.cyan);
          }
        default:
          break;
      }
    }
  }

  void _slowMo(double seconds) {
    if (reducedMotion) return;
    _slowMoT = max(_slowMoT, seconds);
  }

  void _shakeNow(double seconds, double magnitude) {
    if (reducedMotion) return;
    _shakeT = seconds;
    _shakeMag = magnitude;
  }

  void _sting(String label, Color color, {bool major = false}) {
    sting.value = BasketballSting(++_stingId, label, color, major: major);
  }

  /// Render-side label variety — uses the fx RNG, never the sim RNG.
  String _pick(List<String> options) =>
      options[_fxRng.nextInt(options.length)];

  void _swishBurst() {
    if (reducedMotion || !isLoaded) return;
    final at = worldToScreen(kBbRimX, kBbRimHeight - 0.2);
    add(
      ParticleSystemComponent(
        position: Vector2(at.dx, at.dy),
        priority: 30,
        particle: Particle.generate(
          count: 12,
          lifespan: 0.5,
          generator: (_) {
            final angle = pi / 2 + (_fxRng.nextDouble() - 0.5) * 0.9;
            final speed = 60 + _fxRng.nextDouble() * 120;
            return AcceleratedParticle(
              speed: Vector2(cos(angle), sin(angle)) * speed,
              acceleration: Vector2(0, 220),
              child: CircleParticle(
                radius: 1.2 + _fxRng.nextDouble() * 1.6,
                paint: Paint()
                  ..color = (_fxRng.nextBool() ? Cyber.gold : Cyber.cyan)
                      .withValues(alpha: 0.9),
              ),
            );
          },
        ),
      ),
    );
  }

  void _sparkBurst(Offset at, Color color, int count) {
    if (reducedMotion || !isLoaded) return;
    add(
      ParticleSystemComponent(
        position: Vector2(at.dx, at.dy),
        priority: 30,
        particle: Particle.generate(
          count: count,
          lifespan: 0.4,
          generator: (_) {
            final angle = _fxRng.nextDouble() * pi * 2;
            final speed = 50 + _fxRng.nextDouble() * 150;
            return AcceleratedParticle(
              speed: Vector2(cos(angle), sin(angle)) * speed,
              acceleration: Vector2(0, 260),
              child: CircleParticle(
                radius: 1.2 + _fxRng.nextDouble() * 1.6,
                paint: Paint()..color = color,
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void onRemove() {
    scorePlayer.dispose();
    scoreCpu.dispose();
    halfClockTenths.dispose();
    shotClockSeconds.dispose();
    stamina01.dispose();
    heatPlayer.dispose();
    heatCpu.dispose();
    heatActivePlayer.dispose();
    heatActiveCpu.dispose();
    meter.dispose();
    possession.dispose();
    sting.dispose();
    super.onRemove();
  }
}

// -----------------------------------------------------------------------------
// Court
// -----------------------------------------------------------------------------

/// Rooftop neon court: skyline greebles, bobbing crowd silhouettes, hardwood
/// band with cyber markings, hoop assembly with a swaying net and a diegetic
/// shot-clock box. Court markings stay high-contrast; atmosphere stays dark.
class _CourtComponent extends PositionComponent
    with HasGameReference<BasketballGame> {
  double _time = 0;

  static final TextPaint _clockText = TextPaint(
    style: TextStyle(
      fontFamily: Cyber.displayFont,
      fontSize: 13,
      fontWeight: FontWeight.w800,
      color: Cyber.gold,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
  static final TextPaint _clockTextDanger = TextPaint(
    style: TextStyle(
      fontFamily: Cyber.displayFont,
      fontSize: 13,
      fontWeight: FontWeight.w800,
      color: Cyber.danger,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
  static final TextPaint _tickerStyle = TextPaint(
    style: TextStyle(
      fontFamily: Cyber.displayFont,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 2,
      color: Cyber.cyan.withValues(alpha: 0.5),
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );

  // Cached ticker layout — rebuilt only when the score/half changes.
  int _tickerKey = -1;
  TextPainter? _tickerPainter;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    final gameRef = game;
    if (!gameRef.isLoaded) return;
    final size = gameRef.size;
    final floorY = gameRef.floorY;
    final px = gameRef.pxPerUnit;

    _skyline(canvas, gameRef, size, floorY, px);
    _roofProps(canvas, gameRef, size, floorY, px);
    _crowd(canvas, gameRef, size, floorY, px);
    _floor(canvas, gameRef, size, floorY, px);
    _hoop(canvas, gameRef, px);
  }

  /// Near-rooftop props (AC units, antennas, railing) at parallax 0.3 —
  /// the depth layer between the far towers (0.15) and the crowd (1.0).
  void _roofProps(
    Canvas canvas,
    BasketballGame gameRef,
    Vector2 size,
    double floorY,
    double px,
  ) {
    final rng = Random(23);
    final dark = Paint()..color = const Color(0xff0d1220);
    final darker = Paint()..color = const Color(0xff161d30);
    final baseY = floorY - 1.62 * px;
    for (var i = 0; i < 12; i++) {
      final worldX = i * 1.45 - 1.8;
      final at = gameRef.worldToScreen(
        worldX * 0.7 + gameRef._camX * 0.3,
        0,
      );
      switch (rng.nextInt(3)) {
        case 0: // AC unit with a fan hint.
          final w = (0.5 + rng.nextDouble() * 0.3) * px;
          final h = 0.30 * px;
          canvas.drawRect(
            Rect.fromLTWH(at.dx - w / 2, baseY - h, w, h),
            dark,
          );
          canvas.drawCircle(Offset(at.dx, baseY - h / 2), h * 0.28, darker);
        case 1: // Antenna mast with a cross-bar.
          final h = (0.7 + rng.nextDouble() * 0.5) * px;
          final mast = Paint()
            ..color = const Color(0xff0d1220)
            ..strokeWidth = 2;
          canvas.drawLine(
            Offset(at.dx, baseY),
            Offset(at.dx, baseY - h),
            mast,
          );
          canvas.drawLine(
            Offset(at.dx - 0.1 * px, baseY - h * 0.6),
            Offset(at.dx + 0.1 * px, baseY - h * 0.6),
            mast,
          );
        case 2: // Railing run.
          final w = (0.8 + rng.nextDouble() * 0.4) * px;
          final rail = Paint()
            ..color = const Color(0xff0d1220)
            ..strokeWidth = 2;
          canvas.drawLine(
            Offset(at.dx - w / 2, baseY - 0.16 * px),
            Offset(at.dx + w / 2, baseY - 0.16 * px),
            rail,
          );
          for (var p = 0; p <= 3; p++) {
            final postX = at.dx - w / 2 + w * p / 3;
            canvas.drawLine(
              Offset(postX, baseY),
              Offset(postX, baseY - 0.16 * px),
              rail,
            );
          }
      }
    }
  }

  void _skyline(
    Canvas canvas,
    BasketballGame gameRef,
    Vector2 size,
    double floorY,
    double px,
  ) {
    // Night-sky gradient: deep violet up top settling into the base bg at
    // the tower line — the farthest depth layer.
    final skyBottom = floorY - 2.2 * px;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, max(0, skyBottom)),
      Paint()
        ..shader = Gradient.linear(
          Offset.zero,
          Offset(0, skyBottom),
          [const Color(0xff140b1e), Cyber.bg],
        ),
    );

    // Star specks (seeded, screen-fixed — infinite-distance parallax).
    final starRng = Random(11);
    for (var i = 0; i < 16; i++) {
      final sx = starRng.nextDouble() * size.x;
      final sy = starRng.nextDouble() * max(0, skyBottom) * 0.65;
      canvas.drawCircle(
        Offset(sx, sy),
        0.4 + starRng.nextDouble() * 1.2,
        Paint()
          ..color = const Color(0xffe8ecf2).withValues(
            alpha: 0.10 + starRng.nextDouble() * 0.15,
          ),
      );
    }

    // Crescent moon: two offset flat circles, no blur.
    final moonC = Offset(
      size.x * 0.78 - gameRef._camX * px * 0.05,
      size.y * 0.14,
    );
    canvas.drawCircle(
      moonC,
      px * 0.30,
      Paint()..color = const Color(0xffe8ecf2).withValues(alpha: 0.45),
    );
    canvas.drawCircle(
      moonC + Offset(-px * 0.11, -px * 0.05),
      px * 0.27,
      Paint()..color = const Color(0xff140b1e),
    );

    // Drifting blimp with a holo side-banner in the player's livery.
    final blimpW = px * 1.4;
    final blimpX =
        (_time * 8) % (size.x + blimpW * 2) - blimpW;
    final blimpY = size.y * 0.09;
    final hull = Rect.fromCenter(
      center: Offset(blimpX, blimpY),
      width: blimpW,
      height: px * 0.4,
    );
    final hullPaint = Paint()..color = const Color(0xff10172a);
    canvas.drawOval(hull, hullPaint);
    // Tail fin.
    final fin = Path()
      ..moveTo(blimpX - blimpW * 0.42, blimpY)
      ..lineTo(blimpX - blimpW * 0.62, blimpY - px * 0.22)
      ..lineTo(blimpX - blimpW * 0.62, blimpY + px * 0.22)
      ..close();
    canvas.drawPath(fin, hullPaint);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(blimpX, blimpY),
        width: blimpW * 0.6,
        height: px * 0.16,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = basketballTeamById(gameRef.config.teamId)
            .primary
            .withValues(alpha: 0.15),
    );

    // Background Grid
    for (var i = 0; i < 15; i++) {
       final gridY = floorY - px * 2.5 - i * px * 0.45;
       canvas.drawLine(
         Offset(0, gridY),
         Offset(size.x, gridY),
         Paint()..color = Cyber.magenta.withValues(alpha: 0.04)..strokeWidth = 1
       );
    }

    // Parallax towers: dark slabs with sparse neon windows and holo billboards.
    final rng = Random(7);
    for (var i = 0; i < 9; i++) {
      final worldX = i * 1.9 - 1.5;
      final at = gameRef.worldToScreen(worldX * 0.85 + gameRef._camX * 0.15, 0);
      final width = (0.9 + rng.nextDouble()) * px;
      final height = (2.4 + rng.nextDouble() * 2.6) * px;
      final top = floorY - 2.2 * px - height;
      canvas.drawRect(
        Rect.fromLTWH(at.dx - width / 2, top, width, height),
        Paint()..color = Cyber.bg2,
      );
      
      if (rng.nextDouble() < 0.35) {
         canvas.drawRect(
           Rect.fromLTWH(at.dx - width / 2 - 2, top + px * 0.5, width + 4, px * 0.8),
           Paint()
             ..color = (rng.nextBool() ? Cyber.cyan : Cyber.gold).withValues(alpha: 0.12)
             ..style = PaintingStyle.stroke
             ..strokeWidth = 2,
         );
      }

      for (var w = 0; w < 4; w++) {
        if (rng.nextDouble() < 0.5) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            at.dx - width / 2 + 4 + rng.nextDouble() * (width - 10),
            top + 6 + rng.nextDouble() * (height - 14),
            3,
            5,
          ),
          Paint()
            ..color = (w.isEven ? Cyber.cyan : Cyber.magenta).withValues(
              alpha: 0.28,
            ),
        );
      }
    }
  }

  void _crowd(
    Canvas canvas,
    BasketballGame gameRef,
    Vector2 size,
    double floorY,
    double px,
  ) {
    final engine = gameRef.engine;
    final hyped = engine.teams[0].heatActive || engine.teams[1].heatActive;
    // Sustained heat sets the floor; big-play hype surges on top (the crowd
    // "stands up" for a beat, then settles).
    final amp = (hyped ? 0.08 : 0.03) + gameRef.crowdHype * 0.06;
    final freq = hyped ? 7.0 : 2.4 + gameRef.crowdHype * 3;
    final userLivery = basketballTeamById(gameRef.config.teamId);
    final cpuLivery = basketballTeamById(gameRef.config.cpuTeamId);
    for (final layer in const [0, 1]) {
      final baseY = floorY - (1.35 - layer * 0.55) * px;
      final base = layer == 0
          ? const Color(0xff0b101c)
          : const Color(0xff10172a);
      final paint = Paint()..color = base;
      final path = Path()..moveTo(0, baseY + px);
      final pockets = <Rect>[];
      final pocketColors = <Color>[];
      var col = 0;
      for (var sx = -20.0; sx <= size.x + 20; sx += px * 0.5) {
        // Stable per-column head-height variance (seedless hash — no
        // per-frame Random allocations).
        final hash = sin(sx * 12.9898 + layer * 78.233) * 43758.5453;
        final variance = (hash - hash.floorToDouble()) * 0.16;
        final head = 0.16 + variance + layer * 0.1;
        final bob = sin(_time * freq + sx * 0.11 + layer * 2) * amp * px;
        path.lineTo(sx, baseY - head * px + bob);
        path.lineTo(sx + px * 0.25, baseY - (0.05 + layer * 0.1) * px + bob);
        // Team-color fan pockets, alternating supporters.
        if (col % 6 == 0 && layer == 1) {
          pockets.add(
            Rect.fromLTWH(sx, baseY - head * px + bob, px * 0.4, px * 0.16),
          );
          pocketColors.add(
            Color.lerp(
              base,
              (col ~/ 6).isEven ? userLivery.primary : cpuLivery.primary,
              0.3,
            )!,
          );
        }
        col++;
      }
      path
        ..lineTo(size.x + 20, baseY + px)
        ..close();
      canvas.drawPath(path, paint);
      for (var i = 0; i < pockets.length; i++) {
        canvas.drawRect(pockets[i], Paint()..color = pocketColors[i]);
      }
    }
    // Camera flashes when hyped or surging on a big play.
    if (hyped || gameRef.crowdHype > 0.3) {
      final flashRng = Random((_time * 12).floor());
      for (var i = 0; i < 4; i++) {
         if (flashRng.nextDouble() < 0.15) {
             final fx = flashRng.nextDouble() * size.x;
             final fy = floorY - px * (0.85 + flashRng.nextDouble() * 0.5);
             canvas.drawCircle(
               Offset(fx, fy),
               px * 0.12,
               Paint()..color = Colors.white.withValues(alpha: flashRng.nextDouble() * 0.9),
             );
         }
      }
    }

    // Hoarding rail between crowd and court, with a scrolling LED ticker.
    final railY = floorY - 0.78 * px;
    final railH = 0.78 * px;
    canvas.drawRect(
      Rect.fromLTWH(0, railY, size.x, railH),
      Paint()..color = const Color(0xff070b14),
    );
    _ticker(canvas, gameRef, size, railY, railH);
    // The rail edge lifts briefly when a basket flashes the boards.
    final edgeLift =
        gameRef.scoreFlashT > 0 ? gameRef.scoreFlashT / kBbScoreFlashSeconds : 0.0;
    canvas.drawLine(
      Offset(0, railY),
      Offset(size.x, railY),
      Paint()
        ..color = Cyber.cyan.withValues(alpha: 0.25 + edgeLift * 0.4)
        ..strokeWidth = 2.0,
    );
  }

  /// Scrolling LED score/flavor line on the hoarding rail. The laid-out text
  /// is cached and only rebuilt when the score changes.
  void _ticker(
    Canvas canvas,
    BasketballGame gameRef,
    Vector2 size,
    double railY,
    double railH,
  ) {
    final engine = gameRef.engine;
    final key = engine.teams[0].score * 1000 +
        engine.teams[1].score +
        engine.halfIndex * 1000000;
    if (key != _tickerKey || _tickerPainter == null) {
      _tickerKey = key;
      const flavors = [
        'HOOP DUEL LIVE',
        'ROOFTOP CIRCUIT',
        'NEON COURT NIGHTS',
        'HEAT CHECK SEASON',
      ];
      final text =
          'YOU ${engine.teams[0].score} — ${engine.teams[1].score} CPU'
          '  •  ${flavors[key % flavors.length]}  •  ';
      _tickerPainter = _tickerStyle.toTextPainter(text);
    }
    final tp = _tickerPainter!;
    if (tp.width <= 0) return;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, railY, size.x, railH));
    final textY = railY + (railH - tp.height) / 2;
    var dx = ((_time * -40) % tp.width) - tp.width;
    while (dx < size.x) {
      tp.paint(canvas, Offset(dx, textY));
      dx += tp.width;
    }
    canvas.restore();
  }

  void _floor(
    Canvas canvas,
    BasketballGame gameRef,
    Vector2 size,
    double floorY,
    double px,
  ) {
    // Hardwood band with subtle gradient to simulate polish reflection.
    final floorRect = Rect.fromLTWH(0, floorY, size.x, size.y - floorY);
    canvas.drawRect(
      floorRect,
      Paint()
        ..shader = Gradient.linear(
          Offset(0, floorY),
          Offset(0, size.y),
          [const Color(0xff1c1524), const Color(0xff0b080f)],
        ),
    );

    // Plank seams.
    final seam = Paint()
      ..color = const Color(0xff2a2233)
      ..strokeWidth = 1.4;
    final camLeft = gameRef._camX - size.x / 2 / px - 1;
    final camRight = gameRef._camX + size.x / 2 / px + 1;
    for (var wx = camLeft.floorToDouble(); wx <= camRight; wx += 0.62) {
      final at = gameRef.worldToScreen(wx, 0);
      canvas.drawLine(at, Offset(at.dx + px * 0.5, size.y), seam);
    }

    // Center court emblem (holographic/neon ring)
    final emblemAt = gameRef.worldToScreen(4.0, 0);
    canvas.drawOval(
       Rect.fromCenter(center: Offset(emblemAt.dx, size.y - (size.y - floorY) / 2), width: px * 4, height: px * 1.5),
       Paint()
         ..style = PaintingStyle.stroke
         ..strokeWidth = 2.5
         ..color = Cyber.magenta.withValues(alpha: 0.18)
    );

    // Three-point strip: everything beyond the arc line glows faint gold.
    final arcAt = gameRef.worldToScreen(BasketballEngine.arcLineX, 0);
    canvas.drawRect(
      Rect.fromLTWH(0, floorY, max(0, arcAt.dx), size.y - floorY),
      Paint()..color = Cyber.gold.withValues(alpha: 0.05),
    );
    canvas.drawLine(
      arcAt,
      Offset(arcAt.dx - px * 0.4, size.y),
      Paint()
        ..color = Cyber.gold.withValues(alpha: 0.6)
        ..strokeWidth = 2.4,
    );

    // Paint / restricted area near the rim.
    final paintFrom = gameRef.worldToScreen(kBbRimX - 2.6, 0);
    final paintTo = gameRef.worldToScreen(kBbBackboardX + 0.4, 0);
    canvas.drawRect(
      Rect.fromLTRB(paintFrom.dx, floorY, paintTo.dx, size.y),
      Paint()..color = Cyber.cyan.withValues(alpha: 0.08),
    );
    canvas.drawLine(
      paintFrom,
      Offset(paintFrom.dx - px * 0.3, size.y),
      Paint()
        ..color = Cyber.cyan.withValues(alpha: 0.45)
        ..strokeWidth = 2.0,
    );
    
    // Restricted area glowing arc
    final restrictedAt = gameRef.worldToScreen(kBbRimX - 1.0, 0);
    canvas.drawArc(
       Rect.fromCenter(center: Offset(restrictedAt.dx, size.y), width: px * 2, height: px * 1.2),
       pi,
       pi,
       false,
       Paint()
         ..style = PaintingStyle.stroke
         ..color = Cyber.cyan.withValues(alpha: 0.35)
         ..strokeWidth = 1.5,
    );

    // Baseline + court edge light.
    canvas.drawLine(
      Offset(0, floorY),
      Offset(size.x, floorY),
      Paint()
        ..color = Cyber.cyan.withValues(alpha: 0.25)
        ..strokeWidth = 2,
    );
  }

  void _hoop(Canvas canvas, BasketballGame gameRef, double px) {
    final rim = gameRef.worldToScreen(kBbRimX, kBbRimHeight);
    final boardBase = gameRef.worldToScreen(kBbBackboardX, kBbRimHeight - 0.2);
    final boardTop = gameRef.worldToScreen(kBbBackboardX, kBbRimHeight + 0.8);
    final poleBase = gameRef.worldToScreen(kBbBackboardX + 0.35, 0);

    // Reflection ghost on the polished hardwood (pole + board), drawn
    // before the assembly so it always sits underneath.
    if (!gameRef.reducedMotion) {
      final floorLine = poleBase.dy;
      final poleTopY = boardTop.dy - px * 0.2;
      canvas.drawLine(
        Offset(poleBase.dx, floorLine),
        Offset(
          poleBase.dx,
          floorLine + (floorLine - poleTopY) * kBbReflectSquash,
        ),
        Paint()
          ..color = const Color(0xff232b3d).withValues(alpha: 0.35)
          ..strokeWidth = px * 0.14
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawRect(
        Rect.fromLTRB(
          boardBase.dx - px * 0.06,
          floorLine + (floorLine - boardBase.dy) * kBbReflectSquash,
          boardBase.dx + px * 0.06,
          floorLine + (floorLine - boardTop.dy) * kBbReflectSquash,
        ),
        Paint()..color = Cyber.cyan.withValues(alpha: 0.06),
      );
    }

    // Pole + arm.
    final polePaint = Paint()
      ..color = const Color(0xff232b3d)
      ..strokeWidth = px * 0.14
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      poleBase,
      Offset(poleBase.dx, boardTop.dy - px * 0.2),
      polePaint,
    );
    canvas.drawLine(
      Offset(poleBase.dx, boardTop.dy - px * 0.1),
      Offset(boardBase.dx, boardBase.dy - px * 0.2),
      polePaint,
    );

    // Backboard glass.
    final board = Rect.fromLTRB(
      boardBase.dx - px * 0.06,
      boardTop.dy,
      boardBase.dx + px * 0.06,
      boardBase.dy,
    );
    canvas.drawRect(board, Paint()..color = const Color(0x14e8ecf2));
    canvas.drawRect(
      board,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Cyber.cyan.withValues(alpha: 0.5),
    );
    // Score flash: the board's LED frame pulses in the scorer's livery —
    // event-driven and decaying, not an always-on glow.
    if (gameRef.scoreFlashT > 0) {
      final flash = gameRef.scoreFlashT / kBbScoreFlashSeconds;
      canvas.drawRect(
        board.inflate(2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = gameRef.scoreFlashColor.withValues(alpha: 0.7 * flash),
      );
    }

    // Rim (side view) + hook to the board.
    final rimPaint = Paint()
      ..color = Cyber.amber
      ..strokeWidth = px * 0.07
      ..strokeCap = StrokeCap.round;
    final rimFront = Offset(rim.dx - 0.23 * px, rim.dy);
    final rimBack = Offset(rim.dx + 0.23 * px, rim.dy);
    canvas.drawLine(rimFront, rimBack, rimPaint);
    canvas.drawLine(
      rimBack,
      Offset(boardBase.dx, rim.dy - px * 0.05),
      rimPaint,
    );

    // Net: swaying segments.
    final sway = sin(_time * 13) * gameRef.netSway * px * 0.12;
    final netPaint = Paint()
      ..color = const Color(0x8fe8ecf2)
      ..strokeWidth = 1.4;
    for (var i = 0; i <= 4; i++) {
      final k = i / 4;
      final top = Offset.lerp(rimFront, rimBack, k)!;
      final bottom = Offset(
        rim.dx + (k - 0.5) * 0.18 * px + sway,
        rim.dy + 0.42 * px,
      );
      canvas.drawLine(top, bottom, netPaint);
    }
    canvas.drawLine(
      Offset(rim.dx - 0.11 * px + sway, rim.dy + 0.28 * px),
      Offset(rim.dx + 0.11 * px + sway, rim.dy + 0.28 * px),
      netPaint,
    );

    // Diegetic shot clock above the board.
    final clock = gameRef.engine.shotClock.clamp(0, 99).ceil();
    final boxCenter = Offset(boardBase.dx, boardTop.dy - px * 0.42);
    final boxRect = Rect.fromCenter(
      center: boxCenter,
      width: px * 0.62,
      height: px * 0.5,
    );
    canvas.drawRect(boxRect, Paint()..color = const Color(0xff070b14));
    canvas.drawRect(
      boxRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = (clock <= 3 ? Cyber.danger : Cyber.gold).withValues(
          alpha: 0.6,
        ),
    );
    (clock <= 3 ? _clockTextDanger : _clockText).render(
      canvas,
      '$clock',
      Vector2(boxCenter.dx, boxCenter.dy),
      anchor: Anchor.center,
    );
  }
}

// -----------------------------------------------------------------------------
// Ball
// -----------------------------------------------------------------------------

class _BallComponent extends PositionComponent
    with HasGameReference<BasketballGame> {
  final Queue<Offset> _trail = Queue();

  @override
  void render(Canvas canvas) {
    final gameRef = game;
    final engine = gameRef.engine;
    final ball = engine.ball;
    final px = gameRef.pxPerUnit;

    final world = _visualPosition(engine, ball);
    final at = gameRef.worldToScreen(world.dx, world.dy);
    final r = 0.14 * px;

    // Heat trail while flying.
    final shooterHeat =
        (ball.phase == BallPhase.shot || ball.phase == BallPhase.loose) &&
        (engine.teams[0].heatActive || engine.teams[1].heatActive);
    if (shooterHeat) {
      _trail.addLast(at);
      while (_trail.length > 7) {
        _trail.removeFirst();
      }
      var i = 0;
      for (final p in _trail) {
        final k = i / _trail.length;
        canvas.drawCircle(
          p,
          r * (0.4 + k * 0.5),
          Paint()..color = Cyber.gold.withValues(alpha: 0.10 + k * 0.12),
        );
        i++;
      }
    } else {
      _trail.clear();
    }

    // Ball shadow.
    final ground = gameRef.worldToScreen(world.dx, 0);
    canvas.drawOval(
      Rect.fromCenter(
        center: ground,
        width: r * 1.6 * (1 - (world.dy / 6).clamp(0.0, 0.7)),
        height: r * 0.5,
      ),
      Paint()..color = const Color(0x4d000000),
    );

    // Reflection ghost in the hardwood polish.
    if (!gameRef.reducedMotion && world.dy < 4) {
      canvas.drawCircle(
        Offset(at.dx, ground.dy + world.dy * px * kBbReflectSquash),
        r * 0.9,
        Paint()..color = Cyber.amber.withValues(alpha: kBbReflectAlpha),
      );
    }

    canvas.drawCircle(at, r, Paint()..color = Cyber.amber);
    final seam = Paint()
      ..color = const Color(0xff5b2c07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, r * 0.14);
    final spin = ball.phase == BallPhase.held
        ? gameRef.dribblePhase * 0.4
        : world.dx * 0.8;
    canvas.drawArc(
      Rect.fromCircle(center: at, radius: r * 0.92),
      spin,
      pi,
      false,
      seam,
    );
    canvas.drawLine(
      Offset(at.dx - r * 0.9, at.dy),
      Offset(at.dx + r * 0.9, at.dy),
      seam..strokeWidth = max(0.8, r * 0.1),
    );
  }

  /// Where to draw the ball: engine position in flight/loose, stylized
  /// dribble/hands while held (the engine's held position is coarse).
  Offset _visualPosition(BasketballEngine engine, BasketballBall ball) {
    if (ball.phase != BallPhase.held || ball.holder < 0) {
      return Offset(ball.x, ball.h);
    }
    final holder = engine.bodies[ball.holder];
    final fx = holder.x + holder.facing * 0.32;
    switch (holder.body) {
      case BodyState.gather:
        return Offset(fx, holder.spec.heightM * 0.62);
      case BodyState.jump:
        final frac = holder.jumpDur > 0
            ? (holder.jumpT / holder.jumpDur).clamp(0.0, 1.0)
            : 0.0;
        final overhead =
            holder.spec.heightM * (0.62 + frac * 0.5) + holder.jumpHeight;
        return Offset(fx + holder.facing * 0.1, overhead);
      case BodyState.fake:
        final k = (holder.stateT / kBbFakeSeconds).clamp(0.0, 1.0);
        final up = sin(min(1.0, k * 2) * pi) * 0.5;
        return Offset(fx, holder.spec.heightM * 0.62 + up);
      default:
        // Dribble bounce; tighter + lower when protecting the ball.
        final guarded =
            (engine.bodies[1 - ball.holder].x - holder.x).abs() <=
            kBbGuardedGap;
        final height = guarded ? 0.5 : 0.75;
        final bounce =
            sin(game.dribblePhase * (guarded ? 1.6 : 1.0)).abs() * height;
        return Offset(fx, 0.14 + bounce);
    }
  }
}

// -----------------------------------------------------------------------------
// Rebound landing marker
// -----------------------------------------------------------------------------

class _LandingMarkerComponent extends PositionComponent
    with HasGameReference<BasketballGame> {
  double _time = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    final gameRef = game;
    final prediction = gameRef.engine.ball.prediction;
    if (prediction == null) return;
    final px = gameRef.pxPerUnit;
    final at = gameRef.worldToScreen(prediction.landX, 0);
    final pulse = 0.75 + sin(_time * 9) * 0.25;
    canvas.drawOval(
      Rect.fromCenter(
        center: at,
        width: px * 0.9 * pulse,
        height: px * 0.28 * pulse,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Cyber.gold.withValues(alpha: 0.65),
    );
  }
}
