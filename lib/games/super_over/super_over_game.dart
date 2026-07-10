import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../blocs/super_over/super_over_state.dart';
import '../../config/theme.dart';
import '../../data/super_over_jerseys.dart';
import '../../models/super_over.dart';
import 'cricket_rig.dart';

class SuperOverGame extends FlameGame {
  SuperOverGame({
    required this.initialState,
    required this.onPhaseChanged,
    required this.onInputArmed,
    required this.onSwingLocked,
    required this.onShotResolved,
    required this.onOutcomeAnimationComplete,
  });

  SuperOverState initialState;
  final ValueChanged<SuperOverPhase> onPhaseChanged;
  final VoidCallback onInputArmed;
  final VoidCallback onSwingLocked;
  final ValueChanged<int> onShotResolved;
  final VoidCallback onOutcomeAnimationComplete;

  SuperOverState _state = const SuperOverState();
  ui.Image? _stadium;

  bool _deliveryActive = false;
  bool _inputArmed = false;
  bool _swingLocked = false;
  bool _shotReported = false;
  bool _outcomeActive = false;
  bool _outcomeReported = false;

  double _sequenceTime = 0;
  double _releaseTime = 0;
  double _flightDuration = 0.82;
  double _tapReleaseTime = 0;
  double _timeSinceTap = 0;
  double _outcomeTime = 0;
  int _pendingTimingErrorMs = 0;
  ShotSector _liveSector = ShotSector.v;

  static const double _setupDuration = 0.45;
  static const double _runUpDuration = 0.78;
  static const double _contactDelay = 0.16;
  static const double _outcomeDuration = 1.75;

  @override
  Color backgroundColor() => Cyber.bg;

  @override
  Future<void> onLoad() async {
    _state = initialState;
    try {
      _stadium = await images.load('backgrounds/home_stadium.png');
    } catch (_) {
      _stadium = null;
    }
  }

  void syncState(SuperOverState state) {
    _state = state;
    if (state.phase == SuperOverPhase.outcome ||
        state.phase == SuperOverPhase.result) {
      _startOutcomeIfNeeded(state);
    }
  }

  void startDelivery(SuperOverState state) {
    _state = state;
    _deliveryActive = true;
    _inputArmed = false;
    _swingLocked = false;
    _shotReported = false;
    _outcomeActive = false;
    _outcomeReported = false;
    _sequenceTime = 0;
    _tapReleaseTime = 0;
    _timeSinceTap = 0;
    _pendingTimingErrorMs = 0;
    _liveSector = ShotSector.v;

    final rating = state.striker?.rating ?? 75;
    final window = SuperOverResolution.effectiveTimingWindowMs(
      rating,
      state.upcomingDelivery,
      onFire: state.onFire,
    );
    _flightDuration =
        switch (state.upcomingDelivery) {
          DeliveryType.pace => 0.70,
          DeliveryType.spin => 1.04,
          DeliveryType.yorker => 0.76,
        } *
        (window / SuperOverResolution.baseTimingWindowMs).clamp(0.84, 1.18);

    onPhaseChanged(SuperOverPhase.ballSetup);
  }

  void tapBat() {
    if (!_deliveryActive || !_inputArmed || _swingLocked || _shotReported) {
      return;
    }
    _swingLocked = true;
    _tapReleaseTime = max(0, _sequenceTime - _releaseTime);
    _pendingTimingErrorMs = ((_tapReleaseTime - _flightDuration) * 1000)
        .round();
    _liveSector = SuperOverResolution.sectorForTiming(
      SuperOverResolution.normalizedTimingError(
        timingErrorMs: _pendingTimingErrorMs,
        effectiveWindowMs: SuperOverResolution.effectiveTimingWindowMs(
          _state.striker?.rating ?? 75,
          _state.upcomingDelivery,
          onFire: _state.onFire,
        ),
      ),
    );
    _timeSinceTap = 0;
    onSwingLocked();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_deliveryActive) {
      _updateDelivery(dt);
    }
    if (_outcomeActive) {
      _outcomeTime += dt;
      if (_outcomeTime >= _outcomeDuration && !_outcomeReported) {
        _outcomeReported = true;
        _outcomeActive = false;
        onOutcomeAnimationComplete();
      }
    }
  }

  void _updateDelivery(double dt) {
    _sequenceTime += dt;

    if (_sequenceTime >= _setupDuration &&
        _sequenceTime - dt < _setupDuration) {
      onPhaseChanged(SuperOverPhase.runUp);
    }

    final releaseAt = _setupDuration + _runUpDuration;
    if (_sequenceTime >= releaseAt && !_inputArmed) {
      _releaseTime = _sequenceTime;
      _inputArmed = true;
      onInputArmed();
    }

    if (_swingLocked && !_shotReported) {
      _timeSinceTap += dt;
      if (_timeSinceTap >= _contactDelay) {
        _shotReported = true;
        _deliveryActive = false;
        onShotResolved(_pendingTimingErrorMs);
      }
    }

    final releaseElapsed = _sequenceTime - _releaseTime;
    if (_inputArmed &&
        !_swingLocked &&
        !_shotReported &&
        releaseElapsed > _flightDuration + 0.24) {
      _swingLocked = true;
      _shotReported = true;
      _deliveryActive = false;
      _liveSector = ShotSector.v;
      onSwingLocked();
      onShotResolved(
        (SuperOverResolution.effectiveTimingWindowMs(
                  _state.striker?.rating ?? 75,
                  _state.upcomingDelivery,
                  onFire: _state.onFire,
                ) *
                1.05)
            .round(),
      );
    }
  }

  void _startOutcomeIfNeeded(SuperOverState state) {
    if (_outcomeActive || _outcomeReported) return;
    if (state.lastOutcome == null) return;
    _outcomeActive = true;
    _outcomeReported = false;
    _outcomeTime = 0;
    _liveSector = state.shotSector ?? _liveSector;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _renderScene(canvas, Size(size.x, size.y));
  }

  void _renderScene(Canvas canvas, Size screen) {
    final w = screen.width;
    final h = screen.height;
    if (w <= 0 || h <= 0) return;

    _drawSkyAndStadium(canvas, screen);
    if (_shouldShowTopDownOutcome) {
      _drawTopDownOutcome(canvas, screen);
      _drawOutcome(canvas, screen);
      return;
    }
    _drawField(canvas, screen);
    _drawFielders(canvas, screen);
    _drawPitch(canvas, screen);
    _drawBowler(canvas, screen);
    _drawBall(canvas, screen);
    _drawWickets(canvas, screen);
    _drawBatter(canvas, screen);
    _drawOutcome(canvas, screen);
  }

  bool get _shouldShowTopDownOutcome {
    final outcome = _state.lastOutcome;
    return _outcomeActive &&
        outcome != null &&
        outcome != ShotOutcome.bowled &&
        _outcomeTime > 0.16;
  }

  void _drawSkyAndStadium(Canvas canvas, Size screen) {
    final rect = Offset.zero & screen;
    final bg = _stadium;
    if (bg != null) {
      paintImage(
        canvas: canvas,
        rect: rect,
        image: bg,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
      );
      canvas.drawRect(rect, Paint()..color = Cyber.bg.withValues(alpha: 0.72));
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Cyber.cyan.withValues(alpha: 0.10),
              Colors.transparent,
              Cyber.bg.withValues(alpha: 0.58),
            ],
          ).createShader(rect),
      );
    } else {
      final sky = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xff020812), const Color(0xff071522), Cyber.bg],
          stops: const [0, 0.42, 1],
        ).createShader(rect);
      canvas.drawRect(rect, sky);
    }
    _drawStadiumArchitecture(canvas, screen);
  }

  void _drawStadiumArchitecture(Canvas canvas, Size screen) {
    final w = screen.width;
    final h = screen.height;
    final phase = _sequenceTime + _outcomeTime;
    final crowdTop = h * 0.265;
    final crowdHeight = h * 0.105;

    _drawFloodlightTower(canvas, Offset(w * 0.05, h * 0.33), flip: false);
    _drawFloodlightTower(canvas, Offset(w * 0.95, h * 0.33), flip: true);

    final standBack = Path()
      ..moveTo(0, crowdTop)
      ..quadraticBezierTo(w * 0.50, crowdTop - h * 0.08, w, crowdTop)
      ..lineTo(w, crowdTop + crowdHeight)
      ..quadraticBezierTo(
        w * 0.50,
        crowdTop + crowdHeight + h * 0.05,
        0,
        crowdTop + crowdHeight,
      )
      ..close();
    canvas.drawPath(
      standBack,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Cyber.panel2.withValues(alpha: 0.86),
            Cyber.bg.withValues(alpha: 0.96),
          ],
        ).createShader(Offset.zero & screen),
    );
    canvas.drawPath(
      standBack,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Cyber.cyan.withValues(alpha: 0.22),
    );

    for (var row = 0; row < 5; row++) {
      final y = crowdTop + 10 + row * crowdHeight / 6;
      canvas.drawLine(
        Offset(0, y),
        Offset(w, y + sin(row) * 2),
        Paint()
          ..color = Cyber.cyan.withValues(alpha: 0.08)
          ..strokeWidth = 1,
      );
    }

    const colors = [Cyber.cyan, Cyber.magenta, Cyber.gold, Cyber.lime];
    for (var i = 0; i < 138; i++) {
      final x = (i * 23.0) % (w + 36) - 18;
      final band = i % 6;
      final wave = sin(phase * 3 + i * 0.61) * 1.8;
      final y = crowdTop + 12 + band * crowdHeight / 7 + wave;
      final r = 1.5 + (i % 4) * 0.35;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = colors[i % colors.length].withValues(alpha: 0.82),
      );
    }

    final ropeY = crowdTop + crowdHeight + 3;
    canvas.drawLine(
      Offset(0, ropeY),
      Offset(w, ropeY),
      Paint()
        ..color = Cyber.gold.withValues(alpha: 0.62)
        ..strokeWidth = 2,
    );

    _drawAdBoards(canvas, screen, ropeY + 4);
    _drawMiniScoreboard(canvas, screen);
  }

  void _drawFloodlightTower(Canvas canvas, Offset base, {required bool flip}) {
    final side = flip ? -1.0 : 1.0;
    final polePaint = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.32)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(base, base.translate(side * 16, -108), polePaint);
    canvas.drawLine(
      base.translate(side * 8, -2),
      base.translate(side * 25, -108),
      polePaint..strokeWidth = 1,
    );
    final rack = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: base.translate(side * 21, -118),
        width: 42,
        height: 28,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      rack,
      Paint()..color = Cyber.panel.withValues(alpha: 0.75),
    );
    canvas.drawRRect(
      rack,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Cyber.cyan.withValues(alpha: 0.48),
    );
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 3; col++) {
        final p = Offset(rack.left + 9 + col * 12, rack.top + 9 + row * 10);
        canvas.drawCircle(
          p,
          3,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.64)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
    }
  }

  void _drawAdBoards(Canvas canvas, Size screen, double y) {
    final labels = ['STATOZ', 'POWERPLAY', 'SUPER OVER', 'ONE TAP'];
    final boardW = screen.width / labels.length;
    for (var i = 0; i < labels.length; i++) {
      final rect = Rect.fromLTWH(i * boardW, y, boardW - 2, 24);
      final accent = [Cyber.cyan, Cyber.gold, Cyber.lime, Cyber.magenta][i % 4];
      canvas.drawRect(
        rect,
        Paint()..color = Cyber.panel.withValues(alpha: 0.82),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = accent.withValues(alpha: 0.38),
      );
      _drawCanvasText(
        canvas,
        labels[i],
        Offset(rect.left + 8, rect.top + 7),
        Cyber.label(8, color: accent, letterSpacing: 1.2),
        maxWidth: boardW - 16,
      );
    }
  }

  void _drawMiniScoreboard(Canvas canvas, Size screen) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(screen.width * 0.50, screen.height * 0.235),
        width: screen.width * 0.44,
        height: 34,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(rect, Paint()..color = Cyber.bg.withValues(alpha: 0.78));
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Cyber.cyan.withValues(alpha: 0.28),
    );
    _drawCanvasText(
      canvas,
      'SUPER OVER',
      Offset(rect.left + 14, rect.top + 9),
      Cyber.label(9, color: Cyber.cyan, letterSpacing: 1.8),
      maxWidth: rect.width - 28,
    );
    _drawCanvasText(
      canvas,
      '${_state.score}/${_state.wickets}',
      Offset(rect.right - 58, rect.top + 7),
      Cyber.display(14, color: Cyber.gold, letterSpacing: 0),
      maxWidth: 46,
      textAlign: TextAlign.right,
    );
  }

  void _drawTopDownOutcome(Canvas canvas, Size screen) {
    final outcome = _state.lastOutcome;
    if (outcome == null) return;

    final intro = Curves.easeOutCubic.transform(
      ((_outcomeTime - 0.16) / 0.22).clamp(0.0, 1.0),
    );
    final rect = Offset.zero & screen;
    canvas.drawRect(
      rect,
      Paint()..color = Cyber.bg.withValues(alpha: 0.36 + intro * 0.42),
    );

    final field = Rect.fromLTWH(
      screen.width * 0.08,
      screen.height * 0.18,
      screen.width * 0.84,
      screen.height * 0.64,
    );
    canvas.save();
    canvas.translate(0, (1 - intro) * 24);
    canvas.scale(0.96 + intro * 0.04, 0.96 + intro * 0.04);

    _drawTopDownField(canvas, field);
    final origin = Offset(field.center.dx, field.top + field.height * 0.70);
    _drawTopDownPitch(canvas, field, origin);
    _drawTopDownFielders(canvas, field, origin);
    _drawTopDownShot(canvas, field, origin, outcome);
    _drawTopDownTelemetry(canvas, field, outcome);

    canvas.restore();
  }

  void _drawTopDownField(Canvas canvas, Rect field) {
    canvas.drawOval(
      field,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0.22),
          radius: 0.86,
          colors: [
            const Color(0xff0b6a43).withValues(alpha: 0.96),
            const Color(0xff07382f).withValues(alpha: 0.96),
            Cyber.bg.withValues(alpha: 0.98),
          ],
          stops: const [0.0, 0.62, 1.0],
        ).createShader(field),
    );
    canvas.drawOval(
      field,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Cyber.cyan.withValues(alpha: 0.52),
    );
    canvas.drawOval(
      field.inflate(-10),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Cyber.cyan.withValues(alpha: 0.18),
    );
    for (var i = 1; i <= 4; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: field.center,
          width: field.width * (0.18 + i * 0.16),
          height: field.height * (0.18 + i * 0.16),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = Cyber.cyan.withValues(alpha: 0.08),
      );
    }
  }

  void _drawTopDownPitch(Canvas canvas, Rect field, Offset origin) {
    final pitch = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(field.center.dx, origin.dy - field.height * 0.20),
        width: field.width * 0.14,
        height: field.height * 0.48,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(
      pitch,
      Paint()..color = const Color(0xff8f6a36).withValues(alpha: 0.72),
    );
    canvas.drawRRect(
      pitch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Cyber.gold.withValues(alpha: 0.42),
    );

    final line = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.58)
      ..strokeWidth = 1.2;
    canvas.drawLine(
      origin.translate(-field.width * 0.08, 0),
      origin.translate(field.width * 0.08, 0),
      line,
    );
    canvas.drawCircle(origin, 4, Paint()..color = Cyber.gold);

    final sectorLine = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    for (final sector in ShotSector.values) {
      final angle = SuperOverResolution.shotAngleForSector(sector);
      final end = _topDownPoint(field, origin, angle, 1.04);
      canvas.drawLine(origin, end, sectorLine);
    }
  }

  void _drawTopDownFielders(Canvas canvas, Rect field, Offset origin) {
    final spots = SuperOverResolution.fielderSpotsForSectors(
      _state.fieldSectors,
    );
    for (final spot in spots) {
      final pos = _topDownPoint(field, origin, spot.angle, spot.radial);
      final color = switch (spot.sector) {
        ShotSector.off => Cyber.cyan,
        ShotSector.v => Cyber.gold,
        ShotSector.leg => Cyber.lime,
      };
      _drawRadarFielder(canvas, pos, color);
    }
  }

  void _drawRadarFielder(Canvas canvas, Offset pos, Color color) {
    canvas.drawCircle(
      pos,
      7,
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(pos, 4.2, Paint()..color = color);
    canvas.drawCircle(
      pos,
      5.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Cyber.bg,
    );
  }

  void _drawTopDownShot(
    Canvas canvas,
    Rect field,
    Offset origin,
    ShotOutcome outcome,
  ) {
    final sector = _state.shotSector ?? _liveSector;
    final angle = SuperOverResolution.shotAngleForSector(sector);
    final destination = outcome == ShotOutcome.caught
        ? _topDownCatchPoint(field, origin, sector)
        : _topDownPoint(field, origin, angle, _topDownOutcomeRange(outcome));
    final control = Offset(
      (origin.dx + destination.dx) / 2,
      min(origin.dy, destination.dy) - field.height * 0.10,
    );
    final path = Path()
      ..moveTo(origin.dx, origin.dy)
      ..quadraticBezierTo(
        control.dx,
        control.dy,
        destination.dx,
        destination.dy,
      );
    final progress = Curves.easeOutCubic.transform(
      ((_outcomeTime - 0.22) / (_outcomeDuration - 0.22)).clamp(0.0, 1.0),
    );
    final metric = path.computeMetrics().first;
    final partial = metric.extractPath(0, metric.length * progress);
    final shotColor = _outcomeColor(outcome);

    canvas.drawPath(
      partial,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..color = shotColor.withValues(alpha: 0.13)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(
      partial,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = shotColor.withValues(alpha: 0.86),
    );

    final tangent = metric.getTangentForOffset(metric.length * progress);
    final ball = tangent?.position ?? origin;
    canvas.drawCircle(ball, 8, Paint()..color = Cyber.bg);
    canvas.drawCircle(ball, 5.5, Paint()..color = Cyber.danger);
    canvas.drawCircle(
      ball.translate(-1.4, -1.2),
      1.5,
      Paint()..color = Colors.white.withValues(alpha: 0.82),
    );

    if (progress > 0.82) {
      final ringT = ((progress - 0.82) / 0.18).clamp(0.0, 1.0);
      final ringRadius = ui.lerpDouble(10, 32, ringT)!;
      canvas.drawCircle(
        destination,
        ringRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = shotColor.withValues(alpha: 1 - ringT),
      );
      if (outcome == ShotOutcome.caught) {
        _drawCanvasText(
          canvas,
          'CATCH ZONE',
          destination.translate(-42, -26),
          Cyber.label(9, color: Cyber.danger, letterSpacing: 1.2),
          maxWidth: 90,
        );
      }
    }
  }

  void _drawTopDownTelemetry(Canvas canvas, Rect field, ShotOutcome outcome) {
    final sector = _state.shotSector ?? _liveSector;
    final panel = RRect.fromRectAndRadius(
      Rect.fromLTWH(field.left + 14, field.top + 12, field.width - 28, 36),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      panel,
      Paint()..color = Cyber.panel.withValues(alpha: 0.84),
    );
    canvas.drawRRect(
      panel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Cyber.cyan.withValues(alpha: 0.42),
    );
    _drawCanvasText(
      canvas,
      'FIELD RADAR',
      Offset(panel.left + 12, panel.top + 8),
      Cyber.label(8.5, color: Cyber.cyan, letterSpacing: 1.5),
      maxWidth: 110,
    );
    _drawCanvasText(
      canvas,
      '${_outcomeLabel(outcome)}  /  ${_sectorLabel(sector)}',
      Offset(panel.right - 156, panel.top + 8),
      Cyber.label(8.5, color: _outcomeColor(outcome), letterSpacing: 1.2),
      maxWidth: 146,
      textAlign: TextAlign.right,
    );

    final labels = [
      ('OFF ${_state.fieldSectors.elementAtOrNull(0) ?? 0}', field.left + 20),
      (
        'V ${_state.fieldSectors.elementAtOrNull(1) ?? 0}',
        field.center.dx - 18,
      ),
      ('LEG ${_state.fieldSectors.elementAtOrNull(2) ?? 0}', field.right - 70),
    ];
    for (final (label, x) in labels) {
      _drawCanvasText(
        canvas,
        label,
        Offset(x, field.bottom - 28),
        Cyber.label(8, color: Cyber.muted, letterSpacing: 1.1),
        maxWidth: 58,
      );
    }
  }

  Offset _topDownPoint(Rect field, Offset origin, double angle, double radial) {
    return Offset(
      origin.dx + cos(angle) * field.width * 0.46 * radial,
      origin.dy + sin(angle) * field.height * 0.52 * radial,
    );
  }

  double _topDownOutcomeRange(ShotOutcome outcome) {
    return switch (outcome) {
      ShotOutcome.six => 1.08,
      ShotOutcome.four => 0.96,
      ShotOutcome.three => 0.80,
      ShotOutcome.two => 0.64,
      ShotOutcome.one => 0.48,
      ShotOutcome.dot => 0.28,
      ShotOutcome.caught => 0.68,
      ShotOutcome.bowled => 0.0,
    };
  }

  Offset _topDownCatchPoint(Rect field, Offset origin, ShotSector sector) {
    final shotAngle = SuperOverResolution.shotAngleForSector(sector);
    Offset? bestPoint;
    var bestScore = double.infinity;
    for (final spot in SuperOverResolution.fielderSpotsForSectors(
      _state.fieldSectors,
    )) {
      final point = _topDownPoint(field, origin, spot.angle, spot.radial);
      final sectorPenalty = spot.sector == sector ? 0.0 : 0.35;
      final score = (spot.angle - shotAngle).abs() + sectorPenalty;
      if (score < bestScore) {
        bestScore = score;
        bestPoint = point;
      }
    }
    return bestPoint ??
        _topDownPoint(
          field,
          origin,
          shotAngle,
          _topDownOutcomeRange(ShotOutcome.caught),
        );
  }

  Color _outcomeColor(ShotOutcome outcome) {
    return switch (outcome) {
      ShotOutcome.six => Cyber.gold,
      ShotOutcome.four => Cyber.lime,
      ShotOutcome.caught || ShotOutcome.bowled => Cyber.danger,
      _ => Cyber.cyan,
    };
  }

  String _outcomeLabel(ShotOutcome outcome) {
    return switch (outcome) {
      ShotOutcome.six => 'SIX',
      ShotOutcome.four => 'FOUR',
      ShotOutcome.three => '3 RUNS',
      ShotOutcome.two => '2 RUNS',
      ShotOutcome.one => '1 RUN',
      ShotOutcome.dot => 'DOT BALL',
      ShotOutcome.caught => 'CAUGHT',
      ShotOutcome.bowled => 'BOWLED',
    };
  }

  String _sectorLabel(ShotSector sector) {
    return switch (sector) {
      ShotSector.off => 'OFF SIDE',
      ShotSector.v => 'STRAIGHT',
      ShotSector.leg => 'LEG SIDE',
    };
  }

  void _drawCanvasText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    double maxWidth = 220,
    TextAlign textAlign = TextAlign.left,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  void _drawField(Canvas canvas, Size screen) {
    final top = screen.height * 0.405;
    final path = Path()
      ..moveTo(0, top)
      ..quadraticBezierTo(
        screen.width / 2,
        screen.height * 0.45,
        screen.width,
        top,
      )
      ..lineTo(screen.width, screen.height)
      ..lineTo(0, screen.height)
      ..close();
    final rect = Offset.zero & screen;
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xff06362f).withValues(alpha: 0.92),
            const Color(0xff0d5f3c).withValues(alpha: 0.86),
          ],
        ).createShader(rect),
    );

    for (var i = 0; i < 12; i++) {
      final bandY = top + i * screen.height * 0.052;
      final stripe = Path()
        ..moveTo(0, bandY)
        ..quadraticBezierTo(
          screen.width * 0.50,
          bandY + 34,
          screen.width,
          bandY - 2,
        )
        ..lineTo(screen.width, bandY + screen.height * 0.045)
        ..quadraticBezierTo(
          screen.width * 0.50,
          bandY + screen.height * 0.045 + 30,
          0,
          bandY + screen.height * 0.045,
        )
        ..close();
      canvas.drawPath(
        stripe,
        Paint()
          ..color = (i.isEven ? Cyber.lime : Cyber.cyan).withValues(
            alpha: i.isEven ? 0.028 : 0.018,
          ),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Cyber.cyan.withValues(alpha: 0.18),
    );
    final boundary = Path()
      ..moveTo(0, top)
      ..quadraticBezierTo(
        screen.width / 2,
        screen.height * 0.45,
        screen.width,
        top,
      );
    canvas.drawPath(
      boundary,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..color = Cyber.cyan.withValues(alpha: 0.34),
    );
    canvas.drawPath(
      boundary.shift(const Offset(0, 3)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = Cyber.gold.withValues(alpha: 0.44),
    );

    for (var i = 0; i < 9; i++) {
      final y = top + i * screen.height * 0.07;
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(screen.width / 2, y),
          width: screen.width * (0.35 + i * 0.09),
          height: screen.height * 0.08,
        ),
        pi,
        pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Cyber.cyan.withValues(alpha: 0.11),
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        screen.height * 0.82,
        screen.width,
        screen.height * 0.18,
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Cyber.bg.withValues(alpha: 0.24)],
        ).createShader(rect),
    );
  }

  void _drawPitch(Canvas canvas, Size screen) {
    final topY = screen.height * 0.39;
    final bottomY = screen.height * 0.90;
    final cx = screen.width / 2;
    final pitch = Path()
      ..moveTo(cx - screen.width * 0.11, topY)
      ..lineTo(cx + screen.width * 0.11, topY)
      ..lineTo(cx + screen.width * 0.25, bottomY)
      ..lineTo(cx - screen.width * 0.25, bottomY)
      ..close();
    canvas.drawPath(
      pitch.shift(const Offset(0, 8)),
      Paint()
        ..color = Cyber.bg.withValues(alpha: 0.32)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(
      pitch,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xffb58a45).withValues(alpha: 0.92),
            const Color(0xff7b5a2e).withValues(alpha: 0.90),
            const Color(0xff4f3b23).withValues(alpha: 0.94),
          ],
          stops: const [0.0, 0.52, 1.0],
        ).createShader(Offset.zero & screen),
    );
    final centerStrip = Path()
      ..moveTo(cx - screen.width * 0.045, topY + 12)
      ..lineTo(cx + screen.width * 0.045, topY + 12)
      ..lineTo(cx + screen.width * 0.095, bottomY - 12)
      ..lineTo(cx - screen.width * 0.095, bottomY - 12)
      ..close();
    canvas.drawPath(
      centerStrip,
      Paint()..color = Cyber.gold.withValues(alpha: 0.10),
    );

    double yAt(double t) => ui.lerpDouble(topY, bottomY, t)!;
    double halfWidthAt(double t) =>
        ui.lerpDouble(screen.width * 0.105, screen.width * 0.245, t)!;

    final roughPaint = Paint()
      ..color = Cyber.bg.withValues(alpha: 0.13)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 30; i++) {
      final t = 0.08 + (i % 10) * 0.087;
      final half = halfWidthAt(t);
      final xNorm = ((i * 37) % 100) / 100 * 1.55 - 0.775;
      final p = Offset(cx + xNorm * half, yAt(t));
      roughPaint.strokeWidth = 0.9 + (i % 4) * 0.35;
      canvas.drawLine(
        p,
        p.translate((i.isEven ? 1 : -1) * (6 + i % 5), 3 + (i % 4)),
        roughPaint,
      );
    }

    final seamPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (final xNorm in [-0.42, 0.0, 0.42]) {
      final line = Path()
        ..moveTo(cx + xNorm * halfWidthAt(0.05), yAt(0.05))
        ..quadraticBezierTo(
          cx + xNorm * halfWidthAt(0.50) + sin(xNorm * 4) * 4,
          yAt(0.50),
          cx + xNorm * halfWidthAt(0.95),
          yAt(0.95),
        );
      canvas.drawPath(line, seamPaint);
    }
    canvas.drawPath(
      pitch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Cyber.gold.withValues(alpha: 0.42),
    );

    final creasePaint = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.78)
      ..strokeWidth = 2;
    final creaseGlow = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.14)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawLine(
      Offset(cx - screen.width * 0.22, screen.height * 0.79),
      Offset(cx + screen.width * 0.22, screen.height * 0.79),
      creaseGlow,
    );
    canvas.drawLine(
      Offset(cx - screen.width * 0.21, screen.height * 0.79),
      Offset(cx + screen.width * 0.21, screen.height * 0.79),
      creasePaint,
    );
    canvas.drawLine(
      Offset(cx - screen.width * 0.11, screen.height * 0.455),
      Offset(cx + screen.width * 0.11, screen.height * 0.455),
      creaseGlow..strokeWidth = 5,
    );
    canvas.drawLine(
      Offset(cx - screen.width * 0.10, screen.height * 0.45),
      Offset(cx + screen.width * 0.10, screen.height * 0.45),
      creasePaint..strokeWidth = 1.2,
    );
    for (final dx in [-0.075, 0.075]) {
      canvas.drawLine(
        Offset(cx + screen.width * dx, screen.height * 0.765),
        Offset(cx + screen.width * dx, screen.height * 0.835),
        Paint()
          ..color = Cyber.cyan.withValues(alpha: 0.28)
          ..strokeWidth = 1,
      );
    }
  }

  void _drawFielders(Canvas canvas, Size screen) {
    final origin = Offset(screen.width * 0.50, screen.height * 0.78);
    final spots = SuperOverResolution.fielderSpotsForSectors(
      _state.fieldSectors,
    );
    for (final spot in spots) {
      final pos = Offset(
        origin.dx + cos(spot.angle) * screen.width * 0.42 * spot.radial,
        origin.dy + sin(spot.angle) * screen.height * 0.46 * spot.radial,
      );
      final scale = ui.lerpDouble(0.88, 0.54, spot.radial.clamp(0, 1))!;
      _drawTinyFielder(canvas, pos, scale);
    }
  }

  void _drawTinyFielder(Canvas canvas, Offset pos, double scale) {
    final radius = 5.5 * scale;
    canvas.drawCircle(
      pos,
      radius * 2.2,
      Paint()
        ..color = Cyber.cyan.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(
      pos,
      radius * 1.35,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 * scale
        ..color = Cyber.cyan.withValues(alpha: 0.72),
    );
    canvas.drawCircle(pos, radius, Paint()..color = Cyber.cyan);
    canvas.drawCircle(
      pos.translate(-radius * 0.25, -radius * 0.25),
      radius * 0.28,
      Paint()..color = Colors.white.withValues(alpha: 0.74),
    );
  }

  void _drawBowler(Canvas canvas, Size screen) {
    final releaseAt = _setupDuration + _runUpDuration;
    final t = (_sequenceTime / releaseAt).clamp(0.0, 1.0);
    final pos = Offset(
      screen.width / 2,
      ui.lerpDouble(screen.height * 0.32, screen.height * 0.44, t)!,
    );
    final color = switch (_state.upcomingDelivery) {
      DeliveryType.pace => Cyber.cyan,
      DeliveryType.spin => Cyber.gold,
      DeliveryType.yorker => Cyber.danger,
    };
    _drawBowlerAvatar(canvas, pos, color: color, runProgress: t);
    _drawDeliveryEmitter(
      canvas,
      pos,
      color: color,
      progress: t,
      active: _deliveryActive && _sequenceTime < releaseAt,
    );
  }

  void _drawBatter(Canvas canvas, Size screen) {
    final pos = Offset(screen.width * 0.43, screen.height * 0.795);
    final swing = _swingLocked || _state.swingLocked
        ? switch (_liveSector) {
            ShotSector.leg => -0.95,
            ShotSector.off => 0.85,
            ShotSector.v => -0.20,
          }
        : 0.55 + sin(_sequenceTime * 3) * 0.04;

    if (_state.onFire) {
      canvas.drawCircle(
        pos.translate(4, -28),
        48 + sin(_sequenceTime * 8) * 4,
        Paint()
          ..color = Cyber.gold.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }

    _drawStrikerMarker(canvas, pos, swing: swing);
  }

  void _drawBowlerAvatar(
    Canvas canvas,
    Offset pos, {
    required Color color,
    required double runProgress,
  }) {
    final bob = _deliveryActive ? sin(_sequenceTime * 18) * 2.6 : 0.0;
    final anchor = pos.translate(0, bob);
    final pose = bowlerPose(
      runProgress: runProgress,
      time: _sequenceTime,
      isDeliveryActive: _deliveryActive,
    );
    CricketRigPainter.drawBowlerRig(
      canvas,
      anchor,
      pose,
      primary: Cyber.cyan,
      accent: Cyber.magenta,
      skin: const Color(0xFFD4A373),
      scale: 48,
      holdingBall: _deliveryActive && runProgress < 0.86,
    );
  }

  void _drawDeliveryEmitter(
    Canvas canvas,
    Offset pos, {
    required Color color,
    required double progress,
    required bool active,
  }) {
    final pulse = active ? 0.5 + 0.5 * sin(_sequenceTime * 14) : 0.2;
    canvas.drawCircle(
      pos,
      24 + pulse * 8,
      Paint()
        ..color = color.withValues(alpha: 0.10 + pulse * 0.05)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawCircle(
      pos,
      13,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..color = color.withValues(alpha: 0.78),
    );
    canvas.drawCircle(pos, 6.5, Paint()..color = color);

    final trailPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i <= 4; i++) {
      final y = pos.dy - i * 22 - progress * 12;
      canvas.drawLine(
        Offset(pos.dx - 9 + i * 3, y),
        Offset(pos.dx + 9 - i * 3, y + 10),
        trailPaint..color = color.withValues(alpha: 0.22 / i),
      );
    }
  }

  void _drawStrikerMarker(Canvas canvas, Offset pos, {required double swing}) {
    final target = pos.translate(20, -22);
    canvas.drawCircle(
      target,
      28,
      Paint()
        ..color = Cyber.lime.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawCircle(
      target,
      18,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Cyber.lime.withValues(alpha: 0.62),
    );
    canvas.drawCircle(target, 4.5, Paint()..color = Cyber.gold);

    final pad = RRect.fromRectAndRadius(
      Rect.fromCenter(center: pos.translate(10, 6), width: 46, height: 18),
      const Radius.circular(4),
    );
    canvas.drawRRect(pad, Paint()..color = Cyber.panel.withValues(alpha: 0.72));
    canvas.drawRRect(
      pad,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Cyber.lime.withValues(alpha: 0.38),
    );

    _drawBatterAvatar(canvas, pos.translate(-4, -14), swing: swing);

    final pivot = pos.translate(6, -8);
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(swing);
    final batPath = Path()
      ..moveTo(-4, -6)
      ..lineTo(6, -5)
      ..lineTo(12, 58)
      ..lineTo(-8, 58)
      ..close();
    canvas.drawPath(
      batPath,
      Paint()
        ..color = Cyber.gold
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.2),
    );
    canvas.drawPath(
      batPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Cyber.bg,
    );
    canvas.restore();
  }

  void _drawBatterAvatar(Canvas canvas, Offset pos, {required double swing}) {
    final jerseySpec = cricketJerseySpec(_state.jersey);
    final primary = _state.onFire ? Cyber.gold : jerseySpec.primary;
    final accent = _state.onFire ? Cyber.amber : jerseySpec.accent;
    final pose = batsmanPose(
      swing: swing,
      time: _sequenceTime,
      onFire: _state.onFire,
    );
    CricketRigPainter.drawBatsmanRig(
      canvas,
      pos.translate(6, 0),
      pose,
      primary: primary,
      accent: accent,
      skin: const Color(0xFFD4A373),
      scale: 52,
      onFire: _state.onFire,
    );
  }

  void _drawWickets(Canvas canvas, Size screen) {
    final x = screen.width * 0.51;
    final y = screen.height * 0.80;
    final paint = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.92)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final dx in [-8.0, 0.0, 8.0]) {
      canvas.drawLine(Offset(x + dx, y - 28), Offset(x + dx, y + 12), paint);
    }
    canvas.drawLine(Offset(x - 11, y - 30), Offset(x + 11, y - 30), paint);
  }

  void _drawBall(Canvas canvas, Size screen) {
    if (!_deliveryActive && !_outcomeActive) return;

    Offset pos;
    double radius;
    if (_outcomeActive) {
      final t = Curves.easeOut.transform(
        (_outcomeTime / _outcomeDuration).clamp(0.0, 1.0),
      );
      final start = Offset(screen.width * 0.49, screen.height * 0.77);
      final end = _outcomeEnd(screen);
      pos = Offset.lerp(start, end, t)!;
      radius = ui.lerpDouble(
        8,
        _state.lastOutcome == ShotOutcome.six ? 16 : 6,
        t,
      )!;
    } else if (_inputArmed) {
      final t = ((_sequenceTime - _releaseTime) / _flightDuration).clamp(
        0.0,
        1.18,
      );
      final start = Offset(screen.width / 2, screen.height * 0.43);
      final end = Offset(screen.width * 0.50, screen.height * 0.78);
      final lateral = switch (_state.upcomingDelivery) {
        DeliveryType.spin => sin(t * pi) * 26,
        DeliveryType.yorker => 12.0,
        DeliveryType.pace => 0.0,
      };
      pos = Offset.lerp(
        start,
        end.translate(lateral, 12),
        Curves.easeIn.transform(t.clamp(0, 1)),
      )!;
      radius = ui.lerpDouble(4.5, 9.5, t.clamp(0, 1))!;
    } else {
      return;
    }

    final trailColor = switch (_state.upcomingDelivery) {
      DeliveryType.pace => Cyber.cyan,
      DeliveryType.spin => Cyber.gold,
      DeliveryType.yorker => Cyber.danger,
    };
    canvas.drawCircle(
      pos.translate(-8, -10),
      radius * 1.3,
      Paint()
        ..color = trailColor.withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    canvas.drawCircle(pos, radius + 2, Paint()..color = Cyber.bg);
    canvas.drawCircle(pos, radius, Paint()..color = Cyber.danger);
    canvas.drawCircle(
      pos.translate(-radius * 0.25, -radius * 0.2),
      radius * 0.22,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  Offset _outcomeEnd(Size screen) {
    final outcome = _state.lastOutcome ?? ShotOutcome.dot;
    if (outcome == ShotOutcome.bowled) {
      return Offset(screen.width * 0.52, screen.height * 0.82);
    }
    final sector = _state.shotSector ?? _liveSector;
    final angle = SuperOverResolution.shotAngleForSector(sector);
    final distance = switch (outcome) {
      ShotOutcome.six => screen.height * 0.46,
      ShotOutcome.four => screen.height * 0.38,
      ShotOutcome.three => screen.height * 0.31,
      ShotOutcome.two => screen.height * 0.24,
      ShotOutcome.one => screen.height * 0.18,
      ShotOutcome.caught => screen.height * 0.28,
      ShotOutcome.dot => screen.height * 0.11,
      ShotOutcome.bowled => 0.0,
    };
    return Offset(
      screen.width * 0.50 + cos(angle) * distance,
      screen.height * 0.77 + sin(angle) * distance,
    );
  }

  void _drawOutcome(Canvas canvas, Size screen) {
    final outcome = _state.lastOutcome;
    if (!_outcomeActive || outcome == null) return;
    final t = (_outcomeTime / _outcomeDuration).clamp(0.0, 1.0);
    final label = outcome == ShotOutcome.dot ? 'DOT' : _outcomeLabel(outcome);
    final color = _outcomeColor(outcome);

    if (outcome == ShotOutcome.bowled) {
      final base = Offset(screen.width * 0.51, screen.height * 0.80);
      for (var i = 0; i < 6; i++) {
        final a = i * pi / 3 + t * 0.8;
        final d = 18 + t * 42;
        canvas.drawLine(
          base,
          base.translate(cos(a) * d, sin(a) * d),
          Paint()
            ..color = Cyber.cyan.withValues(alpha: 1 - t)
            ..strokeWidth = 3,
        );
      }
    }

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontFamily: 'Orbitron',
          fontSize: 34 + sin(t * pi) * 7,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          shadows: [
            Shadow(color: Cyber.bg.withValues(alpha: 0.95), blurRadius: 4),
            Shadow(color: color.withValues(alpha: 0.5), blurRadius: 18),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: screen.width);
    tp.paint(
      canvas,
      Offset(screen.width / 2 - tp.width / 2, screen.height * 0.22 - t * 18),
    );
  }
}
