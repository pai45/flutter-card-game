import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;

import '../../config/theme.dart';
import '../../models/tennis.dart';
import 'tennis_engine.dart';

class TennisSting {
  const TennisSting(this.id, this.label, this.color, {this.major = false});

  final int id;
  final String label;
  final ui.Color color;
  final bool major;
}

class TennisGame extends FlameGame {
  TennisGame({
    required this.config,
    required this.settings,
    required this.onEvents,
    TennisMatchSnapshot? resume,
  }) : engine = TennisEngine(
         config,
         movementAssist: settings.movementAssist,
         snapshot: resume == null
             ? null
             : _map(
                 resume.engine.containsKey('simulation')
                     ? resume.engine['simulation']
                     : resume.engine,
               ),
       ),
       _ai = TennisAI(
         difficulty: config.difficulty,
         seed: config.seed ^ 0x71e115,
       ) {
    if (resume != null && resume.engine['ai'] is Map) {
      _ai.restore(_map(resume.engine['ai']));
    }
    final savedAccumulator = resume?.engine['accumulator'];
    if (savedAccumulator is num) {
      _accumulator = savedAccumulator.toDouble().clamp(0, _subDt);
    }
  }

  static const double _subDt = 1 / 120;

  final TennisMatchConfig config;
  TennisSettings settings;
  final void Function(List<TennisEvent> events) onEvents;
  final TennisEngine engine;
  final TennisAI _ai;

  final ValueNotifier<TennisScoreState> score = ValueNotifier(
    const TennisScoreState(),
  );
  final ValueNotifier<double> stamina01 = ValueNotifier(1);
  final ValueNotifier<double> focus01 = ValueNotifier(0);
  final ValueNotifier<double> serveMeter = ValueNotifier(0);
  final ValueNotifier<int> rally = ValueNotifier(0);
  final ValueNotifier<int> practiceScore = ValueNotifier(0);
  final ValueNotifier<int> ballsRemaining = ValueNotifier(20);
  final ValueNotifier<int> lessonProgress = ValueNotifier(0);
  final ValueNotifier<int> elapsedTenths = ValueNotifier(0);
  final ValueNotifier<TennisMatchPhase> phase = ValueNotifier(
    TennisMatchPhase.preServe,
  );
  final ValueNotifier<TennisTimingGrade?> timing = ValueNotifier(null);
  final ValueNotifier<TennisSting?> sting = ValueNotifier(null);

  double _moveX = 0;
  double _moveY = 0;
  bool _sprint = false;
  bool _shotDown = false;
  bool _shotPressed = false;
  bool _shotReleased = false;
  double _shotHold = 0;
  double _releaseHold = 0;
  double _aimX = 0;
  double _aimY = 0;
  int _serveAim = 0;
  double _accumulator = 0;
  bool _paused = false;
  double _stingT = 0;
  int _stingId = 0;
  double _cameraPush = 0;
  double _netPulse = 0;
  double _linePulse = 0;
  double _clock = 0;
  int _landingFlightId = -1;
  ui.Offset? _landingMarker;
  final List<_TrailPoint> _trail = <_TrailPoint>[];

  @override
  material.Color backgroundColor() => Cyber.bg;

  void setMove(double x, double y, {bool sprint = false}) {
    _moveX = x.clamp(-1, 1).toDouble();
    _moveY = y.clamp(-1, 1).toDouble();
    _sprint = sprint;
  }

  void shotStarted() {
    _shotDown = true;
    _shotPressed = true;
    _shotHold = 0;
  }

  void shotReleased({
    required double aimX,
    required double aimY,
    required double holdSeconds,
  }) {
    _aimX = aimX.clamp(-1, 1).toDouble();
    _aimY = aimY.clamp(-1, 1).toDouble();
    _serveAim = _aimX < -0.3 ? -1 : (_aimX > 0.3 ? 1 : 0);
    _releaseHold = max(_shotHold, holdSeconds);
    _shotReleased = true;
    _shotDown = false;
  }

  void cancelTouches() {
    _moveX = 0;
    _moveY = 0;
    _sprint = false;
    _shotDown = false;
    _shotPressed = false;
    _shotReleased = false;
    _shotHold = 0;
  }

  void setPaused(bool value) {
    _paused = value;
    engine.paused = value;
    if (value) cancelTouches();
  }

  void applySettings(TennisSettings value) {
    settings = value;
    engine.movementAssist = value.movementAssist;
  }

  TennisMatchSnapshot snapshot() => TennisMatchSnapshot(
    config: config,
    engine: <String, dynamic>{
      'simulation': engine.snapshot(),
      'ai': _ai.snapshot(),
      'accumulator': _accumulator,
    },
    savedAtMillis: DateTime.now().millisecondsSinceEpoch,
  );

  TennisMatchSummary summary({bool tournamentChampion = false}) =>
      engine.summary(tournamentChampion: tournamentChampion);

  @override
  void update(double dt) {
    super.update(dt);
    final wallDt = min(dt, 1 / 30);
    _clock += wallDt;
    if (!_paused) {
      _accumulator += wallDt;
      final events = <TennisEvent>[];
      var first = true;
      while (_accumulator >= _subDt) {
        _accumulator -= _subDt;
        events.addAll(_step(consumeEdges: first));
        first = false;
      }
      if (events.isNotEmpty) {
        _handleEvents(events);
        onEvents(events);
      }
    }
    _decayFx(wallDt);
    _syncNotifiers();
    _recordTrail();
  }

  List<TennisEvent> _step({required bool consumeEdges}) {
    if (_shotDown) _shotHold += _subDt;
    final intent = TennisIntent(
      moveX: _moveX,
      moveY: _moveY,
      sprint: _sprint,
      shotDown: _shotDown,
      shotPressed: consumeEdges && _shotPressed,
      shotReleased: consumeEdges && _shotReleased,
      holdSeconds: consumeEdges && _shotReleased ? _releaseHold : _shotHold,
      aimX: _aimX,
      aimY: _aimY,
      serveAim: _serveAim,
    );
    if (consumeEdges) {
      _shotPressed = false;
      if (_shotReleased) {
        _shotReleased = false;
        _shotHold = 0;
      }
    }
    return engine.step(intent, _ai.think(engine, _subDt), _subDt);
  }

  void _handleEvents(List<TennisEvent> events) {
    for (final event in events) {
      switch (event.type) {
        case TennisEventType.contact:
          if (event.team == 0) timing.value = event.timing;
          if (event.shot == TennisShotType.smash) {
            _showSting('SMASH', Cyber.amber, major: true);
            if (!settings.reducedMotion) _cameraPush = 1;
          }
          break;
        case TennisEventType.perfectContact:
          _showSting('PERFECT', Cyber.cyan);
          if (!settings.reducedMotion) _cameraPush = 0.55;
          break;
        case TennisEventType.winner:
          _showSting('WINNER', Cyber.lime, major: true);
          if (!settings.reducedMotion) _cameraPush = 0.8;
          break;
        case TennisEventType.ace:
          _showSting('ACE', Cyber.gold, major: true);
          break;
        case TennisEventType.fault:
          _showSting('FAULT', Cyber.amber);
          break;
        case TennisEventType.doubleFault:
          _showSting('DOUBLE FAULT', Cyber.danger, major: true);
          break;
        case TennisEventType.let:
          _showSting('LET - REPLAY', Cyber.cyan);
          break;
        case TennisEventType.net:
          _netPulse = 1;
          break;
        case TennisEventType.out:
          _linePulse = 1;
          break;
        case TennisEventType.rallyMilestone:
          _showSting(event.label ?? '${event.value} SHOTS', Cyber.cyan);
          break;
        case TennisEventType.tieBreakStarted:
          _showSting('TIEBREAK', Cyber.gold, major: true);
          break;
        case TennisEventType.endChange:
          _showSting('CHANGE ENDS', Cyber.cyan);
          break;
        case TennisEventType.lessonComplete:
          _showSting('LESSON COMPLETE', Cyber.lime, major: true);
          break;
        default:
          break;
      }
    }
  }

  void _showSting(String label, ui.Color color, {bool major = false}) {
    sting.value = TennisSting(++_stingId, label, color, major: major);
    _stingT = major ? 1.35 : 0.85;
  }

  void _decayFx(double dt) {
    if (_stingT > 0) {
      _stingT = max(0, _stingT - dt);
      if (_stingT == 0) sting.value = null;
    }
    _cameraPush = max(0, _cameraPush - dt * 2.5);
    _netPulse = max(0, _netPulse - dt * 3.2);
    _linePulse = max(0, _linePulse - dt * 2.6);
  }

  void _syncNotifiers() {
    if (!identical(score.value, engine.score)) score.value = engine.score;
    _setDouble(stamina01, engine.player.stamina01);
    _setDouble(focus01, engine.player.focus01);
    _setDouble(serveMeter, engine.serveMeter);
    if (rally.value != engine.rallyCount) rally.value = engine.rallyCount;
    if (practiceScore.value != engine.practiceScore) {
      practiceScore.value = engine.practiceScore;
    }
    if (ballsRemaining.value != engine.ballsRemaining) {
      ballsRemaining.value = engine.ballsRemaining;
    }
    if (lessonProgress.value != engine.lessonProgress) {
      lessonProgress.value = engine.lessonProgress;
    }
    final nextElapsed = (engine.elapsed * 10).floor();
    if (elapsedTenths.value != nextElapsed) elapsedTenths.value = nextElapsed;
    if (phase.value != engine.phase) phase.value = engine.phase;
  }

  void _setDouble(ValueNotifier<double> notifier, double value) {
    if ((notifier.value - value).abs() > 0.002) notifier.value = value;
  }

  void _recordTrail() {
    if (!engine.ball.live) {
      _trail.clear();
      return;
    }
    final point = _TrailPoint(engine.ball.x, engine.ball.y, engine.ball.z);
    if (_trail.isEmpty || _trail.last.distanceTo(point) > 0.34) {
      _trail.add(point);
      final limit = settings.reducedMotion ? 2 : 7;
      if (_trail.length > limit) _trail.removeAt(0);
    }
  }

  @override
  void render(ui.Canvas canvas) {
    _drawAtmosphere(canvas);
    _drawCourt(canvas);
    _drawPrediction(canvas);
    _drawPlayer(canvas, engine.opponent);
    _drawPlayer(canvas, engine.player);
    _drawBall(canvas);
    super.render(canvas);
  }

  void _drawAtmosphere(ui.Canvas canvas) {
    final rect = ui.Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRect(
      rect,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset(size.x * 0.5, 0),
          ui.Offset(size.x * 0.5, size.y),
          const <ui.Color>[
            ui.Color(0xff101f2b),
            Cyber.bg,
            ui.Color(0xff040814),
          ],
          const <double>[0, 0.55, 1],
        ),
    );
    final crowdPaint = ui.Paint()..color = Cyber.cyan.withValues(alpha: 0.08);
    for (var row = 0; row < 4; row++) {
      final y = size.y * (0.07 + row * 0.027);
      for (var i = 0; i < 22; i++) {
        final x = (i + (row.isOdd ? 0.5 : 0)) * size.x / 21;
        canvas.drawCircle(ui.Offset(x, y), 1.2 + row * 0.25, crowdPaint);
      }
    }
    canvas.drawRect(
      ui.Rect.fromLTWH(0, size.y * 0.125, size.x, 2),
      ui.Paint()..color = Cyber.lime.withValues(alpha: 0.18),
    );
  }

  void _drawCourt(ui.Canvas canvas) {
    final corners = <ui.Offset>[
      _courtPoint(-tennisCourtHalfWidth, -tennisCourtHalfLength),
      _courtPoint(tennisCourtHalfWidth, -tennisCourtHalfLength),
      _courtPoint(tennisCourtHalfWidth, tennisCourtHalfLength),
      _courtPoint(-tennisCourtHalfWidth, tennisCourtHalfLength),
    ];
    final shadow = ui.Path()..moveTo(corners.first.dx, corners.first.dy + 9);
    for (final point in corners.skip(1)) {
      shadow.lineTo(point.dx, point.dy + 14);
    }
    shadow.close();
    canvas.drawPath(
      shadow,
      ui.Paint()..color = const ui.Color(0xff02050b).withValues(alpha: 0.82),
    );
    final court = ui.Path()..moveTo(corners.first.dx, corners.first.dy);
    for (final point in corners.skip(1)) {
      court.lineTo(point.dx, point.dy);
    }
    court.close();
    canvas.drawPath(
      court,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          corners.first,
          corners[2],
          const <ui.Color>[ui.Color(0xff164b50), ui.Color(0xff0b303b)],
        ),
    );
    canvas.drawPath(
      court,
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = Cyber.cyan.withValues(alpha: 0.52 + _linePulse * 0.32),
    );

    final line = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeCap = ui.StrokeCap.square
      ..strokeWidth = 1.45
      ..color = material.Colors.white.withValues(alpha: 0.84);
    _drawWorldLine(
      canvas,
      -tennisCourtHalfWidth,
      -tennisCourtHalfLength,
      -tennisCourtHalfWidth,
      tennisCourtHalfLength,
      line,
    );
    _drawWorldLine(
      canvas,
      tennisCourtHalfWidth,
      -tennisCourtHalfLength,
      tennisCourtHalfWidth,
      tennisCourtHalfLength,
      line,
    );
    for (final y in <double>[
      -tennisCourtHalfLength,
      -tennisServiceLine,
      tennisServiceLine,
      tennisCourtHalfLength,
    ]) {
      _drawWorldLine(
        canvas,
        -tennisCourtHalfWidth,
        y,
        tennisCourtHalfWidth,
        y,
        line,
      );
    }
    _drawWorldLine(canvas, 0, -tennisServiceLine, 0, tennisServiceLine, line);
    _drawNet(canvas);

    if (config.mode == TennisMode.targetPractice) {
      _drawTarget(canvas, engine.targetX, engine.targetY);
    }
  }

  void _drawNet(ui.Canvas canvas) {
    final left = _courtPoint(-tennisCourtHalfWidth - 0.25, 0);
    final right = _courtPoint(tennisCourtHalfWidth + 0.25, 0);
    final height = 18.0;
    final pulse = _netPulse * 3;
    final netPaint = ui.Paint()
      ..color = material.Colors.white.withValues(alpha: 0.56 + _netPulse * 0.3)
      ..strokeWidth = 0.8;
    for (var i = 0; i <= 10; i++) {
      final t = i / 10;
      final x = ui.lerpDouble(left.dx, right.dx, t)!;
      canvas.drawLine(
        ui.Offset(x, left.dy - height + sin(_clock * 18 + i) * pulse),
        ui.Offset(x, left.dy),
        netPaint,
      );
    }
    for (var i = 0; i <= 4; i++) {
      final y = left.dy - height + i * height / 4;
      canvas.drawLine(ui.Offset(left.dx, y), ui.Offset(right.dx, y), netPaint);
    }
    canvas.drawLine(
      ui.Offset(left.dx, left.dy - height),
      ui.Offset(right.dx, right.dy - height),
      ui.Paint()
        ..color = material.Colors.white.withValues(alpha: 0.92)
        ..strokeWidth = 2.1,
    );
    for (final post in <ui.Offset>[left, right]) {
      canvas.drawLine(
        post,
        post.translate(0, -height - 4),
        ui.Paint()
          ..color = Cyber.cyan
          ..strokeWidth = 2.5,
      );
    }
  }

  void _drawPrediction(ui.Canvas canvas) {
    final ball = engine.ball;
    if (!ball.live || ball.bounces > 0) {
      _landingMarker = null;
      _landingFlightId = -1;
      return;
    }
    if (_landingFlightId != engine.flightId) {
      _landingFlightId = engine.flightId;
      _landingMarker = _calculateLanding();
    }
    final landing = _landingMarker;
    if (landing == null || landing.dy.abs() > tennisCourtHalfLength + 2) return;
    final center = _courtPoint(landing.dx, landing.dy);
    final active = engine.focusPointActive;
    final color = active ? Cyber.lime : Cyber.cyan;
    final alpha = active ? 0.74 : 0.32;
    canvas.drawOval(
      ui.Rect.fromCenter(center: center, width: active ? 34 : 26, height: 12),
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = active ? 2.4 : 1.3
        ..color = color.withValues(alpha: alpha),
    );
    canvas.drawCircle(
      center,
      active ? 3.5 : 2.5,
      ui.Paint()..color = color.withValues(alpha: alpha),
    );
  }

  ui.Offset? _calculateLanding() {
    final ball = engine.ball;
    if (!ball.live) return null;
    final a = tennisGravity * 0.5;
    final discriminant = ball.vz * ball.vz - 4 * a * ball.z;
    if (discriminant < 0) return null;
    final root = sqrt(discriminant);
    final roots = <double>[
      (-ball.vz + root) / (2 * a),
      (-ball.vz - root) / (2 * a),
    ].where((value) => value > 0.01).toList()..sort();
    if (roots.isEmpty) return null;
    final t = roots.first;
    return ui.Offset(ball.x + ball.vx * t, ball.y + ball.vy * t);
  }

  void _drawTarget(ui.Canvas canvas, double x, double y) {
    final center = _courtPoint(x, y);
    final shrink = max(0.62, 1 - engine.targetIndex * 0.018);
    final colors = <ui.Color>[Cyber.cyan, Cyber.lime, Cyber.gold];
    final widths = <double>[54, 34, 16];
    for (var i = 0; i < widths.length; i++) {
      canvas.drawOval(
        ui.Rect.fromCenter(
          center: center,
          width: widths[i] * shrink,
          height: widths[i] * 0.38 * shrink,
        ),
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = colors[i].withValues(alpha: 0.72),
      );
    }
  }

  void _drawPlayer(ui.Canvas canvas, TennisBody body) {
    final feet = _courtPoint(body.x, body.y);
    final depth = _depth(body.y);
    final scale = 0.58 + depth * 0.48;
    final palette = _palette(body.spec.id);
    canvas.drawOval(
      ui.Rect.fromCenter(
        center: feet.translate(0, 3),
        width: 28 * scale,
        height: 7 * scale,
      ),
      ui.Paint()..color = material.Colors.black.withValues(alpha: 0.38),
    );
    final swing = body.swingT > 0 ? min(1.0, body.swingT * 3.2) : 0.0;
    final isBackhand = engine.ball.x < body.x;
    final lean = body.swingShot == TennisShotType.smash ? -5.0 : 0.0;
    final hip = feet.translate(0, -19 * scale + lean * scale);
    final shoulder = hip.translate(0, -22 * scale);
    final head = shoulder.translate(0, -11 * scale);
    final limb = ui.Paint()
      ..color = palette.skin
      ..strokeWidth = 6 * scale
      ..strokeCap = ui.StrokeCap.round;
    final uniform = ui.Paint()
      ..color = palette.shirt
      ..strokeWidth = 12 * scale
      ..strokeCap = ui.StrokeCap.round;
    final leg = ui.Paint()
      ..color = palette.shorts
      ..strokeWidth = 7 * scale
      ..strokeCap = ui.StrokeCap.round;
    final stride = sin(_clock * 9 + body.team) * 4 * scale;
    canvas.drawLine(
      hip.translate(-3 * scale, 0),
      feet.translate(-6 * scale + stride, -1),
      leg,
    );
    canvas.drawLine(
      hip.translate(3 * scale, 0),
      feet.translate(6 * scale - stride, -1),
      leg,
    );
    canvas.drawLine(hip, shoulder, uniform);
    final nonRacketHand = shoulder.translate(
      (isBackhand ? 7 : -7) * scale,
      12 * scale,
    );
    canvas.drawLine(shoulder, nonRacketHand, limb);

    var racketHand = shoulder.translate(10 * scale, 10 * scale);
    if (swing > 0) {
      final shot = body.swingShot;
      if (shot == TennisShotType.smash || shot == TennisShotType.serve) {
        racketHand = shoulder.translate(
          (isBackhand ? -8 : 8) * scale,
          (-24 + 16 * swing) * scale,
        );
      } else if (shot == TennisShotType.slice ||
          shot == TennisShotType.dropShot) {
        racketHand = shoulder.translate(
          (isBackhand ? -22 : 22) * scale,
          (4 + 13 * swing) * scale,
        );
      } else {
        racketHand = shoulder.translate(
          (isBackhand ? -26 : 26) * scale * (0.35 + swing),
          (8 - 15 * swing) * scale,
        );
      }
    }
    canvas.drawLine(shoulder, racketHand, limb);
    final racketEnd = racketHand.translate(
      (isBackhand ? -1 : 1) * 14 * scale,
      -5 * scale,
    );
    canvas.drawLine(
      racketHand,
      racketEnd,
      ui.Paint()
        ..color = Cyber.border
        ..strokeWidth = 2.2 * scale,
    );
    canvas.drawOval(
      ui.Rect.fromCenter(
        center: racketEnd.translate((isBackhand ? -1 : 1) * 6 * scale, -2),
        width: 12 * scale,
        height: 18 * scale,
      ),
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2 * scale
        ..color = palette.racket,
    );
    canvas.drawCircle(head, 7.5 * scale, ui.Paint()..color = palette.skin);
    canvas.drawArc(
      ui.Rect.fromCircle(center: head.translate(0, -1), radius: 7.8 * scale),
      pi,
      pi,
      false,
      ui.Paint()
        ..color = palette.hair
        ..strokeWidth = 4 * scale
        ..style = ui.PaintingStyle.stroke,
    );
    if (body.team == 0 && engine.focusPointActive) {
      canvas.drawCircle(
        hip,
        28 * scale,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Cyber.lime.withValues(alpha: 0.5),
      );
    }
  }

  void _drawBall(ui.Canvas canvas) {
    final ball = engine.ball;
    if (!ball.live) return;
    for (var i = 0; i < _trail.length; i++) {
      final point = _trail[i];
      final alpha = (i + 1) / _trail.length * 0.16;
      canvas.drawCircle(
        _ballPoint(point.x, point.y, point.z),
        2.1,
        ui.Paint()..color = Cyber.lime.withValues(alpha: alpha),
      );
    }
    final floor = _courtPoint(ball.x, ball.y);
    final center = _ballPoint(ball.x, ball.y, ball.z);
    final depth = _depth(ball.y);
    final radius = 3.4 + depth * 1.25;
    canvas.drawOval(
      ui.Rect.fromCenter(
        center: floor.translate(0, 2),
        width: radius * 3.2,
        height: radius * 1.1,
      ),
      ui.Paint()
        ..color = material.Colors.black.withValues(
          alpha: (0.32 - min(0.22, ball.z * 0.055)),
        ),
    );
    canvas.drawCircle(
      center,
      radius + 2.2,
      ui.Paint()..color = Cyber.lime.withValues(alpha: 0.12),
    );
    canvas.drawCircle(
      center,
      radius,
      ui.Paint()
        ..shader = ui.Gradient.radial(
          center.translate(-1.2, -1.2),
          radius * 1.5,
          const <ui.Color>[ui.Color(0xfff5ff8b), ui.Color(0xffa8d520)],
        ),
    );
    canvas.drawArc(
      ui.Rect.fromCircle(center: center, radius: radius * 0.72),
      -1.1,
      1.7,
      false,
      ui.Paint()
        ..color = material.Colors.white.withValues(alpha: 0.72)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  void _drawWorldLine(
    ui.Canvas canvas,
    double x1,
    double y1,
    double x2,
    double y2,
    ui.Paint paint,
  ) {
    canvas.drawLine(_courtPoint(x1, y1), _courtPoint(x2, y2), paint);
  }

  ui.Offset _courtPoint(double x, double y) {
    final depth = _depth(y);
    final zoom = 1 + _cameraPush * 0.025;
    final courtY = ui.lerpDouble(size.y * 0.17, size.y * 0.80, depth)!;
    final halfWidth = ui.lerpDouble(size.x * 0.245, size.x * 0.475, depth)!;
    final centerX = size.x * 0.5;
    return ui.Offset(
      centerX + x / tennisCourtHalfWidth * halfWidth * zoom,
      size.y * 0.5 + (courtY - size.y * 0.5) * zoom,
    );
  }

  ui.Offset _ballPoint(double x, double y, double z) {
    final floor = _courtPoint(x, y);
    final lift = z * (14 + _depth(y) * 10);
    return floor.translate(0, -lift);
  }

  double _depth(double y) =>
      ((y + tennisCourtHalfLength) / (tennisCourtHalfLength * 2))
          .clamp(0, 1)
          .toDouble();
}

class _TrailPoint {
  const _TrailPoint(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  double distanceTo(_TrailPoint other) =>
      sqrt(pow(x - other.x, 2) + pow(y - other.y, 2) + pow(z - other.z, 2));
}

class _AthletePalette {
  const _AthletePalette({
    required this.skin,
    required this.hair,
    required this.shirt,
    required this.shorts,
    required this.racket,
  });

  final ui.Color skin;
  final ui.Color hair;
  final ui.Color shirt;
  final ui.Color shorts;
  final ui.Color racket;
}

_AthletePalette _palette(String id) => switch (id) {
  'jett-okafor' => const _AthletePalette(
    skin: ui.Color(0xff8f5738),
    hair: ui.Color(0xff121011),
    shirt: ui.Color(0xffff8e4f),
    shorts: ui.Color(0xff26314d),
    racket: Cyber.amber,
  ),
  'mira-chen' => const _AthletePalette(
    skin: ui.Color(0xffe1a37e),
    hair: ui.Color(0xff17131c),
    shirt: ui.Color(0xff55e7c4),
    shorts: ui.Color(0xff18304a),
    racket: Cyber.cyan,
  ),
  'luca-vale' => const _AthletePalette(
    skin: ui.Color(0xffd3a078),
    hair: ui.Color(0xff5b3625),
    shirt: ui.Color(0xffffd55d),
    shorts: ui.Color(0xff323241),
    racket: Cyber.gold,
  ),
  'sora-malik' => const _AthletePalette(
    skin: ui.Color(0xffad704d),
    hair: ui.Color(0xff221922),
    shirt: ui.Color(0xff9ee568),
    shorts: ui.Color(0xff1c3a35),
    racket: Cyber.lime,
  ),
  'kaia-brooks' => const _AthletePalette(
    skin: ui.Color(0xff70432f),
    hair: ui.Color(0xff161015),
    shirt: ui.Color(0xffff6f91),
    shorts: ui.Color(0xff3a233d),
    racket: Cyber.pink,
  ),
  'theo-laurent' => const _AthletePalette(
    skin: ui.Color(0xffc88f67),
    hair: ui.Color(0xff352a20),
    shirt: ui.Color(0xff6bbdff),
    shorts: ui.Color(0xff1e304d),
    racket: Cyber.cyan,
  ),
  'riven-cole' => const _AthletePalette(
    skin: ui.Color(0xff9c6447),
    hair: ui.Color(0xff151517),
    shirt: ui.Color(0xffef6dff),
    shorts: ui.Color(0xff2d2546),
    racket: Cyber.violet,
  ),
  _ => const _AthletePalette(
    skin: ui.Color(0xffca8464),
    hair: ui.Color(0xff30201e),
    shirt: ui.Color(0xff67dcff),
    shorts: ui.Color(0xff20314a),
    racket: Cyber.cyan,
  ),
};

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
