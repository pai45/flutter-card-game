import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../blocs/super_over/super_over_state.dart';
import '../../config/theme.dart';
import '../../data/super_over_batter_profiles.dart';
import '../../data/super_over_jerseys.dart';
import '../../models/super_over.dart';
import 'cricket_rig.dart';

/// Shared batting-end perspective used by every on-field element.
///
/// Keeping scene geometry in one place prevents the pitch, actors, ball,
/// shadow and outcome paths from drifting apart on different phone sizes.
class _CricketSceneLayout {
  const _CricketSceneLayout(this.size);

  final Size size;

  double get w => size.width;
  double get h => size.height;
  double get horizonY => h * .385;
  double get strikerY => h * .665;
  Offset get fieldOrigin => Offset(w * .5, h * .65);
  Offset get strikerFeet => Offset(w * .43, strikerY);
  Offset get strikerWicket => Offset(w * .51, strikerY);
  Offset get keeperFeet => Offset(w * .575, strikerY + h * .004);
  Offset get farWicket => Offset(w * .5, h * .425);
  Offset get nonStrikerFeet => Offset(w * .545, h * .442);
  Offset get bowlerStart => Offset(w * .5, h * .28);
  Offset get bowlerRelease => Offset(w * .5, h * .39);

  double pitchHalfWidth(double t) =>
      ui.lerpDouble(w * .105, w * .245, t.clamp(0, 1))!;

  double pitchY(double t) => ui.lerpDouble(horizonY, h * .83, t.clamp(0, 1))!;

  Path get pitchPath => Path()
    ..moveTo(w * .5 - pitchHalfWidth(0), pitchY(0))
    ..lineTo(w * .5 + pitchHalfWidth(0), pitchY(0))
    ..lineTo(w * .5 + pitchHalfWidth(1), pitchY(1))
    ..lineTo(w * .5 - pitchHalfWidth(1), pitchY(1))
    ..close();

  Offset fieldPoint(double angle, double radial) => Offset(
    fieldOrigin.dx + cos(angle) * w * .42 * radial,
    fieldOrigin.dy + sin(angle) * h * .43 * radial,
  );

  double actorScaleAt(double y) => ui.lerpDouble(
    .52,
    1.05,
    ((y - horizonY) / (strikerY - horizonY)).clamp(0, 1),
  )!;
}

class SuperOverGame extends FlameGame {
  SuperOverGame({
    required this.initialState,
    required this.onPhaseChanged,
    required this.onInputArmed,
    required this.onBallBounce,
    required this.onSwingLocked,
    required this.onShotResolved,
    required this.onNoInput,
    required this.onOutcomeAnimationComplete,
  });

  SuperOverState initialState;
  final ValueChanged<SuperOverPhase> onPhaseChanged;
  final VoidCallback onInputArmed;
  final VoidCallback onBallBounce;
  final VoidCallback onSwingLocked;
  final ValueChanged<ShotIntent> onShotResolved;
  final VoidCallback onNoInput;
  final VoidCallback onOutcomeAnimationComplete;

  SuperOverState _state = const SuperOverState();

  bool _deliveryActive = false;
  bool _inputArmed = false;
  bool _swingLocked = false;
  bool _shotReported = false;
  bool _bounceReported = false;
  bool _outcomeActive = false;
  bool _outcomeReported = false;

  double _sequenceTime = 0;
  double _releaseTime = 0;
  double _flightDuration = 0.82;
  double _tapReleaseTime = 0;
  double _timeSinceTap = 0;
  double _outcomeTime = 0;
  int _pendingTimingErrorMs = 0;
  ShotIntent _pendingIntent = const ShotIntent(
    sector: ShotSector.v,
    style: ShotStyle.ground,
    timingErrorMs: 0,
  );
  ShotSector _liveSector = ShotSector.v;
  bool reducedMotion = false;

  static const double _setupDuration = 0.45;
  static const double _runUpDuration = 0.78;
  static const double _contactDelay = 0.16;
  static const double _outcomeDuration = 2.05;

  @override
  Color backgroundColor() => Cyber.bg;

  @override
  Future<void> onLoad() async => _state = initialState;

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
    _bounceReported = false;
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
      difficulty: state.settings.difficulty,
    );
    _flightDuration =
        (0.78 / state.deliveryPlan.paceFactor.clamp(0.65, 1.22)) *
        (window / SuperOverResolution.baseTimingWindowMs).clamp(0.84, 1.18);

    onPhaseChanged(SuperOverPhase.ballSetup);
  }

  void tapBat({required ShotSector sector, required ShotStyle style}) {
    if (!_deliveryActive || !_inputArmed || _swingLocked || _shotReported) {
      return;
    }
    _swingLocked = true;
    _tapReleaseTime = max(0, _sequenceTime - _releaseTime);
    _pendingTimingErrorMs = ((_tapReleaseTime - _flightDuration) * 1000)
        .round();
    _liveSector = sector;
    _pendingIntent = ShotIntent(
      sector: sector,
      style: style,
      timingErrorMs: _pendingTimingErrorMs,
      leftHanded: _state.settings.leftHandedControls,
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
        onShotResolved(_pendingIntent);
      }
    }

    final releaseElapsed = _sequenceTime - _releaseTime;
    final bounceFraction = switch (_state.deliveryPlan.length) {
      DeliveryLength.short => .55,
      DeliveryLength.good => .68,
      DeliveryLength.full => .80,
      DeliveryLength.yorker => .90,
    };
    if (_inputArmed &&
        !_bounceReported &&
        releaseElapsed >= _flightDuration * bounceFraction) {
      _bounceReported = true;
      onBallBounce();
    }
    if (_inputArmed &&
        !_swingLocked &&
        !_shotReported &&
        releaseElapsed > _flightDuration + 0.24) {
      _swingLocked = true;
      _shotReported = true;
      _deliveryActive = false;
      _liveSector = ShotSector.v;
      onSwingLocked();
      onNoInput();
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
    canvas.save();
    if (!reducedMotion && _outcomeActive) {
      final impact = (1 - (_outcomeTime / .30).clamp(0.0, 1.0));
      final heavy =
          _state.lastOutcome == ShotOutcome.six ||
          _state.lastOutcome == ShotOutcome.bowled ||
          _state.lastOutcome == ShotOutcome.caught;
      if (heavy && impact > 0) {
        canvas.translate(
          sin(_outcomeTime * 90) * 2.5 * impact,
          cos(_outcomeTime * 76) * 1.5 * impact,
        );
      }
      final push = 1 + impact * (heavy ? .028 : .014);
      canvas.translate(size.x / 2, size.y * .7);
      canvas.scale(push, push);
      canvas.translate(-size.x / 2, -size.y * .7);
    }
    _renderScene(canvas, Size(size.x, size.y));
    canvas.restore();
  }

  void _renderScene(Canvas canvas, Size screen) {
    final w = screen.width;
    final h = screen.height;
    if (w <= 0 || h <= 0) return;

    _drawSkyAndStadium(canvas, screen);
    _drawField(canvas, screen);
    _drawPitch(canvas, screen);
    if (_outcomeActive) {
      _drawFielders(canvas, screen);
      _drawNonStriker(canvas, screen);
      _drawWicketkeeper(canvas, screen);
    }
    _drawBowler(canvas, screen);
    _drawWickets(canvas, screen);
    _drawBatter(canvas, screen);
    _drawRunningBatters(canvas, screen);
    _drawBall(canvas, screen);
    _drawOutcome(canvas, screen);
    if (_showTopView) _drawTopViewOutcome(canvas, screen);
  }

  // Super Over intentionally stays in one elevated batting-end camera. The
  // tactical top view is retained below only as unreachable legacy drawing
  // code until the renderer is split into smaller files.
  bool get _showTopView => false;

  @visibleForTesting
  bool get debugTopViewActive => _showTopView;

  @visibleForTesting
  String get debugCameraMode => 'batting-end';

  void _drawSkyAndStadium(Canvas canvas, Size screen) {
    final rect = Offset.zero & screen;
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xff0b1c2b), Color(0xff07131f), Color(0xff030912)],
        stops: [0, .48, 1],
      ).createShader(rect);
    canvas.drawRect(rect, sky);

    final nightHalo = Rect.fromCenter(
      center: Offset(screen.width * .5, screen.height * .23),
      width: screen.width * .82,
      height: screen.height * .38,
    );
    canvas.drawOval(
      nightHalo,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Cyber.cyan.withValues(alpha: .075),
            const Color(0xff10253a).withValues(alpha: .035),
            Colors.transparent,
          ],
        ).createShader(nightHalo),
    );

    for (final x in [.18, .82]) {
      final beam = Path()
        ..moveTo(screen.width * x, screen.height * .16)
        ..lineTo(screen.width * (x < .5 ? .38 : .62), screen.height * .47)
        ..lineTo(screen.width * (x < .5 ? .55 : .45), screen.height * .47)
        ..close();
      canvas.drawPath(
        beam,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white.withValues(alpha: .035), Colors.transparent],
          ).createShader(rect),
      );
    }
    _drawStadiumArchitecture(canvas, screen);
  }

  void _drawStadiumArchitecture(Canvas canvas, Size screen) {
    final w = screen.width;
    final h = screen.height;
    final phase = _sequenceTime + _outcomeTime;
    final crowdTop = h * 0.252;
    final crowdHeight = h * 0.112;

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

    final roof = Path()
      ..moveTo(0, crowdTop - h * .014)
      ..quadraticBezierTo(w * .5, crowdTop - h * .095, w, crowdTop - h * .014)
      ..lineTo(w, crowdTop + h * .012)
      ..quadraticBezierTo(w * .5, crowdTop - h * .065, 0, crowdTop + h * .012)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xff0f2334));
    canvas.drawPath(
      roof,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = Cyber.cyan.withValues(alpha: .24),
    );

    for (var i = 1; i < 8; i++) {
      final x = w * i / 8;
      final inset = (i - 4).abs() * h * .006;
      canvas.drawLine(
        Offset(x, crowdTop - h * .018 - inset),
        Offset(x, crowdTop + crowdHeight),
        Paint()
          ..color = Cyber.cyan.withValues(alpha: .075)
          ..strokeWidth = 1,
      );
    }
    canvas.drawPath(
      standBack,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Cyber.cyan.withValues(alpha: 0.22),
    );

    for (var row = 0; row < 4; row++) {
      final y = crowdTop + 10 + row * crowdHeight / 6;
      canvas.drawLine(
        Offset(0, y),
        Offset(w, y + sin(row) * 2),
        Paint()
          ..color = Cyber.cyan.withValues(alpha: 0.08)
          ..strokeWidth = 1,
      );
    }

    for (var i = 0; i < 84; i++) {
      final x = (i * 31.0) % (w + 24) - 12;
      final band = i % 5;
      final wave = reducedMotion ? 0.0 : sin(phase * 1.6 + i * 0.61) * .65;
      final y = crowdTop + 13 + band * crowdHeight / 6 + wave;
      final r = 1.1 + (i % 3) * 0.24;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color =
              (i % 7 == 0
                      ? Cyber.cyan
                      : i % 4 == 0
                      ? Cyber.gold
                      : const Color(0xffff8f00))
                  .withValues(alpha: 0.56),
      );
    }

    final ropeY = crowdTop + crowdHeight + 3;
    canvas.drawLine(
      Offset(0, ropeY),
      Offset(w, ropeY),
      Paint()
        ..color = Cyber.cyan.withValues(alpha: 0.42)
        ..strokeWidth = 1.5,
    );

    _drawAdBoards(canvas, screen, ropeY + 4);
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
    final labels = ['STATOZ', 'FINAL STAND', 'SUPER OVER', 'AIM · TIME · HIT'];
    final boardW = screen.width / labels.length;
    for (var i = 0; i < labels.length; i++) {
      final rect = Rect.fromLTWH(i * boardW, y, boardW - 2, 24);
      final accent = [Cyber.cyan, Cyber.gold, Cyber.cyan, Cyber.amber][i % 4];
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

  Color _outcomeColor(ShotOutcome outcome) {
    return switch (outcome) {
      ShotOutcome.six => Cyber.gold,
      ShotOutcome.four => Cyber.cyan,
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

  /// Tennis Rally-inspired tactical camera used only after a played contact.
  /// The delivery and contact remain in the batting-end view; this camera then
  /// makes placement, running, interception, catches and the rope readable.
  void _drawTopViewOutcome(Canvas canvas, Size screen) {
    final outcome = _state.lastOutcome;
    if (outcome == null) return;
    final rect = Offset.zero & screen;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff101f2b), Color(0xff07141f), Color(0xff040814)],
        ).createShader(rect),
    );

    final field = Rect.fromLTWH(
      screen.width * .055,
      screen.height * .135,
      screen.width * .89,
      screen.height * .69,
    );
    canvas.drawOval(
      field,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, .15),
          radius: .88,
          colors: const [
            Color(0xff17644f),
            Color(0xff0c453c),
            Color(0xff072d2c),
          ],
        ).createShader(field),
    );
    canvas.drawOval(
      field,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Cyber.gold.withValues(alpha: .82),
    );
    canvas.drawOval(
      field.deflate(8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: .24),
    );
    for (var i = 1; i <= 4; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: field.center,
          width: field.width * (.22 + i * .15),
          height: field.height * (.22 + i * .15),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Cyber.cyan.withValues(alpha: .055),
      );
    }

    final origin = Offset(field.center.dx, field.top + field.height * .73);
    _drawTopPitch(canvas, field, origin);
    final destination = _topOutcomeDestination(field, origin, outcome);
    final interceptor = _topInterceptor(field, origin, destination, outcome);
    _drawTopFielders(canvas, field, origin, interceptor, outcome);
    _drawTopShot(canvas, field, origin, destination, outcome);
    _drawTopBatters(canvas, field, origin, outcome);
    _drawTopCameraTag(canvas, field, outcome);
  }

  void _drawTopPitch(Canvas canvas, Rect field, Offset origin) {
    final pitch = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(field.center.dx, field.center.dy + field.height * .04),
        width: field.width * .13,
        height: field.height * .43,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      pitch,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff9b7a43), Color(0xff75572e)],
        ).createShader(pitch.outerRect),
    );
    canvas.drawRRect(
      pitch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Cyber.gold.withValues(alpha: .62),
    );
    final crease = Paint()
      ..color = Colors.white.withValues(alpha: .72)
      ..strokeWidth = 1.2;
    canvas.drawLine(
      origin.translate(-field.width * .075, 0),
      origin.translate(field.width * .075, 0),
      crease,
    );
    final far = Offset(field.center.dx, field.top + field.height * .30);
    canvas.drawLine(
      far.translate(-field.width * .055, 0),
      far.translate(field.width * .055, 0),
      crease,
    );
    for (final dx in [-4.0, 0.0, 4.0]) {
      canvas.drawLine(
        origin.translate(dx, -9),
        origin.translate(dx, 2),
        Paint()
          ..color = Cyber.cyan
          ..strokeWidth = 1.7
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawTopFielders(
    Canvas canvas,
    Rect field,
    Offset origin,
    int interceptor,
    ShotOutcome outcome,
  ) {
    final spots = SuperOverResolution.fielderSpotsForSectors(
      _state.fieldSectors,
    );
    for (var i = 0; i < spots.length; i++) {
      final spot = spots[i];
      final point = _topFieldPoint(field, origin, spot.angle, spot.radial);
      _drawTopAthlete(
        canvas,
        point,
        scale: .72 + (1 - spot.radial) * .16,
        shirt: i == interceptor ? Cyber.gold : Cyber.cyan,
        shorts: const Color(0xff17263e),
        skin: _skinForSeed((_state.config?.seed ?? 31) + i * 19),
        catching: i == interceptor && outcome == ShotOutcome.caught,
        fielding: i == interceptor,
      );
    }
  }

  void _drawTopAthlete(
    Canvas canvas,
    Offset feet, {
    required double scale,
    required Color shirt,
    required Color shorts,
    required Color skin,
    bool catching = false,
    bool fielding = false,
  }) {
    final movement = fielding
        ? Curves.easeOut.transform(((_outcomeTime - .30) / .72).clamp(0.0, 1.0))
        : 0.0;
    final base = feet.translate(
      fielding ? sin(_outcomeTime * 13) * 4 * movement : 0,
      0,
    );
    final hip = base.translate(0, -13 * scale);
    final shoulder = hip.translate(0, -14 * scale);
    final head = shoulder.translate(0, -7 * scale);
    canvas.drawOval(
      Rect.fromCenter(
        center: base.translate(0, 2),
        width: 19 * scale,
        height: 5 * scale,
      ),
      Paint()..color = Colors.black.withValues(alpha: .38),
    );
    final stride = fielding ? sin(_outcomeTime * 18) * 5 * scale : 3 * scale;
    final legs = Paint()
      ..color = shorts
      ..strokeWidth = 5.5 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(hip, base.translate(-stride, 0), legs);
    canvas.drawLine(hip, base.translate(stride, 0), legs);
    canvas.drawLine(
      hip,
      shoulder,
      Paint()
        ..color = shirt
        ..strokeWidth = 10 * scale
        ..strokeCap = StrokeCap.round,
    );
    final handY = catching ? -13 * scale : 7 * scale;
    final arm = Paint()
      ..color = skin
      ..strokeWidth = 4 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(shoulder, shoulder.translate(-8 * scale, handY), arm);
    canvas.drawLine(shoulder, shoulder.translate(8 * scale, handY), arm);
    canvas.drawCircle(head, 5.2 * scale, Paint()..color = skin);
    canvas.drawArc(
      Rect.fromCircle(center: head.translate(0, -1), radius: 5.4 * scale),
      pi,
      pi,
      false,
      Paint()
        ..color = const Color(0xff12131a)
        ..strokeWidth = 3 * scale
        ..style = PaintingStyle.stroke,
    );
    if (fielding) {
      canvas.drawCircle(
        shoulder.translate(0, handY),
        11 * scale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = shirt.withValues(alpha: .72),
      );
    }
  }

  void _drawTopShot(
    Canvas canvas,
    Rect field,
    Offset origin,
    Offset destination,
    ShotOutcome outcome,
  ) {
    final record = _state.ballRecords.lastOrNull;
    final loft = record?.intent?.style == ShotStyle.loft;
    final progress = Curves.easeOutCubic.transform(
      ((_outcomeTime - .24) / (_outcomeDuration - .36)).clamp(0.0, 1.0),
    );
    final control = Offset(
      (origin.dx + destination.dx) / 2,
      min(origin.dy, destination.dy) - field.height * (loft ? .16 : .055),
    );
    final route = Path()
      ..moveTo(origin.dx, origin.dy)
      ..quadraticBezierTo(
        control.dx,
        control.dy,
        destination.dx,
        destination.dy,
      );
    final metric = route.computeMetrics().first;
    final partial = metric.extractPath(0, metric.length * progress);
    final color = _outcomeColor(outcome);
    canvas.drawPath(
      partial,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 10
        ..color = color.withValues(alpha: .10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(
      partial,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.4
        ..color = color.withValues(alpha: .84),
    );
    final tangent = metric.getTangentForOffset(metric.length * progress);
    final ball = tangent?.position ?? origin;
    final floor = Offset.lerp(origin, destination, progress)!;
    canvas.drawOval(
      Rect.fromCenter(center: floor, width: 13, height: 5),
      Paint()..color = Colors.black.withValues(alpha: .30),
    );
    for (var i = 1; i <= 5; i++) {
      final p = max(0.0, progress - i * .035);
      final trail = metric.getTangentForOffset(metric.length * p)?.position;
      if (trail != null) {
        canvas.drawCircle(
          trail,
          2.2,
          Paint()..color = color.withValues(alpha: .24 / i),
        );
      }
    }
    canvas.drawCircle(ball, 7, Paint()..color = Cyber.bg);
    canvas.drawCircle(
      ball,
      4.7,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.35, -.35),
          colors: const [Color(0xffff8d78), Color(0xffba2434)],
        ).createShader(Rect.fromCircle(center: ball, radius: 6)),
    );
    if (progress > .86) {
      final pulse = ((progress - .86) / .14).clamp(0.0, 1.0);
      canvas.drawCircle(
        destination,
        9 + pulse * 25,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * (1 - pulse)
          ..color = color.withValues(alpha: 1 - pulse),
      );
    }
  }

  void _drawTopBatters(
    Canvas canvas,
    Rect field,
    Offset origin,
    ShotOutcome outcome,
  ) {
    final jersey = cricketJerseySpec(_state.jersey);
    final skin = _batterSkin();
    final runs = SuperOverResolution.runsForOutcome(outcome);
    final far = Offset(field.center.dx, field.top + field.height * .30);
    if (runs > 0 && runs < 4) {
      final progress = Curves.easeInOut.transform(
        ((_outcomeTime - .32) / 1.35).clamp(0.0, 1.0),
      );
      final lap = (progress * runs) % 1;
      _drawTopAthlete(
        canvas,
        Offset.lerp(origin.translate(-8, 0), far.translate(-8, 0), lap)!,
        scale: .94,
        shirt: jersey.primary,
        shorts: jersey.accent,
        skin: skin,
        fielding: true,
      );
      _drawTopAthlete(
        canvas,
        Offset.lerp(far.translate(8, 0), origin.translate(8, 0), lap)!,
        scale: .88,
        shirt: jersey.primary,
        shorts: jersey.accent,
        skin: _skinForSeed((_state.config?.seed ?? 9) + 71),
        fielding: true,
      );
    } else {
      _drawTopAthlete(
        canvas,
        origin.translate(-8, 0),
        scale: .94,
        shirt: jersey.primary,
        shorts: jersey.accent,
        skin: skin,
      );
      _drawTopAthlete(
        canvas,
        far.translate(8, 0),
        scale: .84,
        shirt: jersey.primary,
        shorts: jersey.accent,
        skin: _skinForSeed((_state.config?.seed ?? 9) + 71),
      );
    }
  }

  void _drawTopCameraTag(Canvas canvas, Rect field, ShotOutcome outcome) {
    final color = _outcomeColor(outcome);
    final panel = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(field.center.dx, field.top + 25),
        width: field.width * .66,
        height: 35,
      ),
      const Radius.circular(5),
    );
    canvas.drawRRect(panel, Paint()..color = Cyber.bg.withValues(alpha: .88));
    canvas.drawRRect(
      panel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = color.withValues(alpha: .74),
    );
    _drawCanvasText(
      canvas,
      'FIELD VIEW',
      Offset(panel.left + 11, panel.top + 10),
      Cyber.label(8, color: Cyber.muted, letterSpacing: 1.2),
      maxWidth: 90,
    );
    _drawCanvasText(
      canvas,
      _outcomeLabel(outcome),
      Offset(panel.right - 120, panel.top + 8),
      Cyber.display(12, color: color, letterSpacing: 1.2),
      maxWidth: 108,
      textAlign: TextAlign.right,
    );
  }

  Offset _topOutcomeDestination(
    Rect field,
    Offset origin,
    ShotOutcome outcome,
  ) {
    final sector = _state.shotSector ?? _liveSector;
    final angle = SuperOverResolution.shotAngleForSector(sector);
    final range = switch (outcome) {
      ShotOutcome.six => 1.30,
      ShotOutcome.four => 1.16,
      ShotOutcome.three => .90,
      ShotOutcome.two => .70,
      ShotOutcome.one => .50,
      ShotOutcome.dot => .27,
      ShotOutcome.caught => .70,
      ShotOutcome.bowled => 0.0,
    };
    final natural = _topFieldPoint(field, origin, angle, range);
    if (outcome != ShotOutcome.caught) return natural;
    final spots = SuperOverResolution.fielderSpotsForSectors(
      _state.fieldSectors,
    );
    Offset? nearest;
    var distance = double.infinity;
    for (final spot in spots) {
      final point = _topFieldPoint(field, origin, spot.angle, spot.radial);
      final score = (point - natural).distanceSquared;
      if (score < distance) {
        distance = score;
        nearest = point;
      }
    }
    return nearest ?? natural;
  }

  int _topInterceptor(
    Rect field,
    Offset origin,
    Offset destination,
    ShotOutcome outcome,
  ) {
    if (!const {
      ShotOutcome.caught,
      ShotOutcome.one,
      ShotOutcome.two,
      ShotOutcome.three,
    }.contains(outcome)) {
      return -1;
    }
    final spots = SuperOverResolution.fielderSpotsForSectors(
      _state.fieldSectors,
    );
    var index = -1;
    var distance = double.infinity;
    for (var i = 0; i < spots.length; i++) {
      final point = _topFieldPoint(
        field,
        origin,
        spots[i].angle,
        spots[i].radial,
      );
      final score = (point - destination).distanceSquared;
      if (score < distance) {
        distance = score;
        index = i;
      }
    }
    return index;
  }

  Offset _topFieldPoint(
    Rect field,
    Offset origin,
    double angle,
    double radial,
  ) => Offset(
    origin.dx + cos(angle) * field.width * .46 * radial,
    origin.dy + sin(angle) * field.height * .58 * radial,
  );

  Color _batterSkin() {
    final striker = _state.striker;
    if (striker == null) return _skinForSeed(_state.config?.seed ?? 0);
    final index = _state.battingOrder.indexOf(striker);
    final profile = SuperOverBatterProfiles.fromCard(
      striker,
      orderIndex: max(0, index),
    );
    return _skinForSeed(profile.visualSeed);
  }

  Color _skinForSeed(int seed) {
    const tones = [
      Color(0xff70452f),
      Color(0xff8f5738),
      Color(0xffb97852),
      Color(0xffd4a373),
      Color(0xffe1b18e),
    ];
    return tones[seed.abs() % tones.length];
  }

  void _drawField(Canvas canvas, Size screen) {
    final layout = _CricketSceneLayout(screen);
    final top = layout.horizonY;
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
            const Color(0xff174348).withValues(alpha: 0.97),
            const Color(0xff0c3338).withValues(alpha: 0.99),
            const Color(0xff06262d),
          ],
          stops: const [0, .5, 1],
        ).createShader(rect),
    );

    for (var i = 0; i < 3; i++) {
      final bandY = top + i * screen.height * 0.076;
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
          ..color = (i.isEven ? Cyber.cyan : Colors.black).withValues(
            alpha: i.isEven ? 0.008 : 0.016,
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
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = Cyber.cyan.withValues(alpha: 0.50),
    );
    canvas.drawPath(
      boundary.shift(const Offset(0, 3)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.22),
    );

    for (var i = 0; i < 2; i++) {
      final y = top + screen.height * (.16 + i * .16);
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(screen.width / 2, y),
          width: screen.width * (.78 + i * .16),
          height: screen.height * (.20 + i * .08),
        ),
        pi,
        pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Cyber.cyan.withValues(alpha: 0.045),
      );
    }

    final innerField = Rect.fromCenter(
      center: Offset(screen.width * .5, screen.height * .68),
      width: screen.width * .84,
      height: screen.height * .54,
    );
    canvas.drawArc(
      innerField,
      pi * 1.08,
      pi * .84,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: .055),
    );
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
    final layout = _CricketSceneLayout(screen);
    final topY = layout.pitchY(0);
    final bottomY = layout.pitchY(1);
    final cx = screen.width / 2;
    final pitch = layout.pitchPath;
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
            const Color(0xffd0ab63),
            const Color(0xffb48949),
            const Color(0xff8c6438),
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
      Paint()..color = Colors.white.withValues(alpha: 0.035),
    );

    double yAt(double t) => ui.lerpDouble(topY, bottomY, t)!;
    double halfWidthAt(double t) => layout.pitchHalfWidth(t);

    final roughPaint = Paint()
      ..color = Cyber.bg.withValues(alpha: 0.13)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 10; i++) {
      final t = 0.08 + (i % 10) * 0.087;
      final half = halfWidthAt(t);
      final xNorm = ((i * 37) % 100) / 100 * 1.55 - 0.775;
      final p = Offset(cx + xNorm * half, yAt(t));
      roughPaint.strokeWidth = 0.8 + (i % 3) * 0.25;
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
        ..strokeWidth = 2.1
        ..color = const Color(0xffffdc8a).withValues(alpha: .82),
    );

    final creaseOutline = Paint()
      ..color = Cyber.bg.withValues(alpha: .62)
      ..strokeWidth = 3.6;
    final creasePaint = Paint()
      ..color = const Color(0xffd9fbff).withValues(alpha: 0.94)
      ..strokeWidth = 1.55;
    final nearCreaseY = layout.strikerY - screen.height * .005;
    final farCreaseY = layout.farWicket.dy;
    canvas.drawLine(
      Offset(cx - screen.width * 0.21, nearCreaseY),
      Offset(cx + screen.width * 0.21, nearCreaseY),
      creaseOutline,
    );
    canvas.drawLine(
      Offset(cx - screen.width * 0.21, nearCreaseY),
      Offset(cx + screen.width * 0.21, nearCreaseY),
      creasePaint,
    );
    canvas.drawLine(
      Offset(cx - screen.width * 0.10, farCreaseY),
      Offset(cx + screen.width * 0.10, farCreaseY),
      creasePaint..strokeWidth = 1.1,
    );
    for (var i = 1; i <= 2; i++) {
      final y = nearCreaseY + screen.height * (.028 * i);
      final width = screen.width * (.215 + i * .014);
      canvas.drawLine(
        Offset(cx - width, y),
        Offset(cx + width, y),
        Paint()
          ..color = const Color(0xfffff5d2).withValues(alpha: .88)
          ..strokeWidth = 1.3,
      );
    }
    for (final dx in [-0.075, 0.075]) {
      canvas.drawLine(
        Offset(cx + screen.width * dx, nearCreaseY - screen.height * .025),
        Offset(cx + screen.width * dx, nearCreaseY + screen.height * .035),
        Paint()
          ..color = const Color(0xffc8f7ff).withValues(alpha: 0.42)
          ..strokeWidth = 1,
      );
    }
  }

  void _drawFielders(Canvas canvas, Size screen) {
    final layout = _CricketSceneLayout(screen);
    final spots = SuperOverResolution.fielderSpotsForSectors(
      _state.fieldSectors,
    );
    final positions = [
      for (final spot in spots) layout.fieldPoint(spot.angle, spot.radial),
    ];
    var interceptor = -1;
    if (_outcomeActive &&
        const {
          ShotOutcome.caught,
          ShotOutcome.one,
          ShotOutcome.two,
          ShotOutcome.three,
        }.contains(_state.lastOutcome)) {
      final destination = _outcomeEnd(screen);
      var nearest = double.infinity;
      for (var i = 0; i < positions.length; i++) {
        final distance = (positions[i] - destination).distanceSquared;
        if (distance < nearest) {
          nearest = distance;
          interceptor = i;
        }
      }
    }
    for (var i = 0; i < spots.length; i++) {
      final pos = positions[i];
      final scale = layout.actorScaleAt(pos.dy) * .70;
      _drawTinyFielder(
        canvas,
        pos,
        scale,
        skin: _skinForSeed((_state.config?.seed ?? 31) + i * 19),
        active: i == interceptor,
        catching: _state.lastOutcome == ShotOutcome.caught,
      );
    }
  }

  void _drawTinyFielder(
    Canvas canvas,
    Offset pos,
    double scale, {
    required Color skin,
    bool active = false,
    bool catching = false,
  }) {
    final chase = active
        ? Curves.easeOut.transform(((_outcomeTime - .18) / .75).clamp(0.0, 1.0))
        : 0.0;
    final destination = _outcomeEnd(Size(size.x, size.y));
    final body = active
        ? Offset.lerp(pos, destination, chase * (catching ? .72 : .58))!
        : pos;
    final motion = !active
        ? CricketActorMotion.ready
        : catching && chase > .72
        ? CricketActorMotion.catchBall
        : chase > .82
        ? CricketActorMotion.throwBall
        : CricketActorMotion.run;
    CricketActorPainter.draw(
      canvas,
      body,
      scale: scale,
      role: CricketActorRole.fielder,
      motion: motion,
      time: _outcomeActive ? _outcomeTime : _sequenceTime,
      primary: active ? const Color(0xffff9b52) : Cyber.amber,
      accent: Cyber.gold,
      skin: skin,
      facingLeft: destination.dx < body.dx,
    );
  }

  void _drawWicketkeeper(Canvas canvas, Size screen) {
    final layout = _CricketSceneLayout(screen);
    final dismissed =
        _outcomeActive &&
        (_state.lastOutcome == ShotOutcome.bowled ||
            _state.lastOutcome == ShotOutcome.caught);
    CricketActorPainter.draw(
      canvas,
      layout.keeperFeet,
      scale: .88,
      role: CricketActorRole.wicketkeeper,
      motion: dismissed
          ? CricketActorMotion.celebrate
          : CricketActorMotion.ready,
      time: _outcomeActive ? _outcomeTime : _sequenceTime,
      primary: const Color(0xffff8b4c),
      accent: Cyber.gold,
      skin: _skinForSeed((_state.config?.seed ?? 11) + 107),
      facingLeft: true,
    );
  }

  void _drawNonStriker(Canvas canvas, Size screen) {
    if (_outcomeActive &&
        const {
          ShotOutcome.one,
          ShotOutcome.two,
          ShotOutcome.three,
        }.contains(_state.lastOutcome)) {
      return;
    }
    final layout = _CricketSceneLayout(screen);
    final jersey = cricketJerseySpec(_state.jersey);
    CricketActorPainter.draw(
      canvas,
      layout.nonStrikerFeet,
      scale: layout.actorScaleAt(layout.nonStrikerFeet.dy) * .72,
      role: CricketActorRole.nonStriker,
      motion: CricketActorMotion.battingGuard,
      time: _sequenceTime,
      primary: jersey.primary,
      accent: jersey.accent,
      skin: _skinForSeed((_state.config?.seed ?? 23) + 43),
      facingLeft: true,
    );
  }

  void _drawRunningBatters(Canvas canvas, Size screen) {
    final outcome = _state.lastOutcome;
    if (!_outcomeActive ||
        outcome == null ||
        !const {
          ShotOutcome.one,
          ShotOutcome.two,
          ShotOutcome.three,
        }.contains(outcome)) {
      return;
    }
    final progress = Curves.easeInOut.transform(
      ((_outcomeTime - .18) / 1.15).clamp(0.0, 1.0),
    );
    final laps = switch (outcome) {
      ShotOutcome.three => 3,
      ShotOutcome.two => 2,
      _ => 1,
    };
    final run = (progress * laps) % 1;
    final near = Offset.lerp(
      Offset(screen.width * .45, screen.height * .69),
      Offset(screen.width * .50, screen.height * .47),
      run,
    )!;
    final far = Offset.lerp(
      Offset(screen.width * .54, screen.height * .43),
      Offset(screen.width * .57, screen.height * .69),
      run,
    )!;
    final jersey = cricketJerseySpec(_state.jersey);
    _drawRunnerSilhouette(canvas, near, 1 - run * .35, jersey.primary);
    _drawRunnerSilhouette(canvas, far, .65 + run * .35, jersey.primary);
  }

  void _drawRunnerSilhouette(
    Canvas canvas,
    Offset base,
    double scale,
    Color color,
  ) {
    final jersey = cricketJerseySpec(_state.jersey);
    CricketActorPainter.draw(
      canvas,
      base,
      scale: scale * .78,
      role: CricketActorRole.runner,
      motion: CricketActorMotion.run,
      time: _outcomeTime,
      primary: color,
      accent: jersey.accent,
      skin: _batterSkin(),
      facingLeft: base.dx > size.x * .5,
    );
  }

  void _drawBowler(Canvas canvas, Size screen) {
    final layout = _CricketSceneLayout(screen);
    final releaseAt = _setupDuration + _runUpDuration;
    final t = (_sequenceTime / releaseAt).clamp(0.0, 1.0);
    final visualT = switch (_state.upcomingDelivery) {
      DeliveryType.pace => Curves.easeIn.transform(t),
      DeliveryType.slower => Curves.easeInOut.transform(t),
      DeliveryType.spin => Curves.easeOut.transform(t * .94),
      DeliveryType.yorker => pow(t, .78).toDouble(),
    };
    final start = layout.bowlerStart.translate(
      0,
      switch (_state.upcomingDelivery) {
        DeliveryType.pace => -10,
        DeliveryType.slower => -2,
        DeliveryType.spin => 15,
        DeliveryType.yorker => -6,
      },
    );
    final pos = Offset.lerp(start, layout.bowlerRelease, visualT)!;
    final deliveryAccent = switch (_state.upcomingDelivery) {
      DeliveryType.pace => Cyber.cyan,
      DeliveryType.slower => Cyber.lime,
      DeliveryType.spin => Cyber.gold,
      DeliveryType.yorker => Cyber.danger,
    };
    _drawBowlerAvatar(
      canvas,
      pos,
      color: const Color(0xff315ff4),
      accent: const Color(0xffff9818),
      runProgress: visualT,
    );
    if (_deliveryActive && _sequenceTime < releaseAt) {
      canvas.drawCircle(
        pos.translate(0, 3),
        3,
        Paint()..color = deliveryAccent.withValues(alpha: .48),
      );
    }
  }

  void _drawBatter(Canvas canvas, Size screen) {
    final pos = _CricketSceneLayout(screen).strikerFeet;
    final swingProgress = _swingLocked
        ? Curves.easeOutCubic.transform(
            (_timeSinceTap / _contactDelay).clamp(0.0, 1.0),
          )
        : _state.swingLocked
        ? 1.0
        : 0.0;

    if (_state.onFire) {
      canvas.drawCircle(
        pos.translate(4, -28),
        48 + sin(_sequenceTime * 8) * 4,
        Paint()
          ..color = Cyber.gold.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }

    _drawStrikerMarker(canvas, pos, swingProgress: swingProgress);
  }

  void _drawBowlerAvatar(
    Canvas canvas,
    Offset pos, {
    required Color color,
    required Color accent,
    required double runProgress,
  }) {
    final bob = _deliveryActive ? sin(_sequenceTime * 18) * 1.2 : 0.0;
    final anchor = pos.translate(0, bob);
    CricketActorPainter.drawReferenceBowler(
      canvas,
      anchor,
      scale: 1.02,
      runProgress: runProgress,
      time: _sequenceTime,
      primary: color,
      accent: accent,
      skin: _skinForSeed((_state.config?.seed ?? 17) + 211),
      holdingBall: _deliveryActive && runProgress < 0.86,
    );
  }

  void _drawStrikerMarker(
    Canvas canvas,
    Offset pos, {
    required double swingProgress,
  }) {
    if (!_inputArmed && !_swingLocked) {
      final dx = switch (_state.selectedSector) {
        ShotSector.off => -42.0,
        ShotSector.v => 0.0,
        ShotSector.leg => 42.0,
      };
      final start = pos.translate(10, -12);
      final end = start.translate(dx, -72);
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = Cyber.cyan.withValues(alpha: .24)
          ..strokeWidth = 1
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        end,
        3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Cyber.cyan.withValues(alpha: .52),
      );
    }

    _drawBatterAvatar(canvas, pos, swingProgress: swingProgress);
  }

  void _drawBatterAvatar(
    Canvas canvas,
    Offset pos, {
    required double swingProgress,
  }) {
    CricketActorPainter.drawReferenceBatter(
      canvas,
      pos,
      scale: 1.08,
      swingProgress: swingProgress,
      sector: _liveSector,
      style: _state.selectedShotStyle,
      time: _sequenceTime,
      primary: _state.onFire ? Cyber.gold : const Color(0xff315ff4),
      accent: _state.onFire ? Cyber.amber : const Color(0xff6f9dff),
      skin: _batterSkin(),
    );
  }

  void _drawWickets(Canvas canvas, Size screen) {
    final layout = _CricketSceneLayout(screen);
    _drawWicketSet(canvas, layout.farWicket, scale: .55, bowled: false);
    _drawWicketSet(
      canvas,
      layout.strikerWicket,
      scale: 1,
      bowled: _outcomeActive && _state.lastOutcome == ShotOutcome.bowled,
    );
  }

  void _drawWicketSet(
    Canvas canvas,
    Offset base, {
    required double scale,
    required bool bowled,
  }) {
    final x = base.dx;
    final y = base.dy;
    final outline = Paint()
      ..color = Cyber.bg.withValues(alpha: .92)
      ..strokeWidth = 6.5 * scale
      ..strokeCap = StrokeCap.round;
    final paint = Paint()
      ..color = const Color(0xffffefc6)
      ..strokeWidth = 3.4 * scale
      ..strokeCap = StrokeCap.round;
    for (final dx in [-8.0 * scale, 0.0, 8.0 * scale]) {
      canvas.drawLine(
        Offset(x + dx, y - 28 * scale),
        Offset(x + dx, y + 12 * scale),
        outline,
      );
      canvas.drawLine(
        Offset(x + dx, y - 28 * scale),
        Offset(x + dx, y + 12 * scale),
        paint,
      );
    }
    final bailT = bowled
        ? Curves.easeOut.transform((_outcomeTime / .65).clamp(0.0, 1.0))
        : 0.0;
    canvas.save();
    canvas.translate(bailT * 18 * scale, -bailT * 32 * scale);
    canvas.rotate(bailT * 1.8);
    canvas.drawLine(
      Offset(x - 11 * scale, y - 30 * scale),
      Offset(x - scale, y - 30 * scale),
      paint,
    );
    canvas.restore();
    canvas.save();
    canvas.translate(-bailT * 15 * scale, -bailT * 25 * scale);
    canvas.rotate(-bailT * 1.45);
    canvas.drawLine(
      Offset(x + scale, y - 30 * scale),
      Offset(x + 11 * scale, y - 30 * scale),
      paint,
    );
    canvas.restore();
  }

  void _drawBall(Canvas canvas, Size screen) {
    if (!_deliveryActive && !_outcomeActive) return;

    final layout = _CricketSceneLayout(screen);
    Offset pos;
    Offset floor;
    double radius;
    double lift;
    if (_outcomeActive) {
      final hitStop = reducedMotion ? 0.0 : .055;
      final t = Curves.easeOut.transform(
        ((_outcomeTime - hitStop) / (_outcomeDuration - hitStop)).clamp(
          0.0,
          1.0,
        ),
      );
      final start = _contactPoint(layout);
      final end = _outcomeEnd(screen);
      floor = Offset.lerp(start.translate(0, 16), end, t)!;
      final flight = switch (_state.lastOutcome) {
        ShotOutcome.six => sin(pi * t) * screen.height * .16,
        ShotOutcome.four => sin(pi * t) * screen.height * .055,
        ShotOutcome.caught =>
          sin(pi * t) * screen.height * .14 + t * screen.height * .038,
        ShotOutcome.two ||
        ShotOutcome.three => sin(pi * min(1, t * 1.35)) * screen.height * .035,
        ShotOutcome.one ||
        ShotOutcome.dot => sin(pi * min(1, t * 1.7)) * screen.height * .018,
        ShotOutcome.bowled || null => 0.0,
      };
      lift = flight;
      pos = floor.translate(0, -lift);
      radius = 5.0 + layout.actorScaleAt(floor.dy) * 2.8;
    } else if (_inputArmed) {
      final t = ((_sequenceTime - _releaseTime) / _flightDuration).clamp(
        0.0,
        1.18,
      );
      final visualT = _swingLocked ? 1.0 : t.clamp(0.0, 1.0);
      final start = layout.bowlerRelease;
      final contact = _contactPoint(layout);
      final lateral = switch (_state.upcomingDelivery) {
        DeliveryType.spin => sin(visualT * pi) * 26,
        DeliveryType.yorker => 12.0,
        DeliveryType.slower => sin(visualT * pi) * -8,
        DeliveryType.pace => 0.0,
      };
      final lineOffset = switch (_state.deliveryPlan.line) {
        DeliveryLine.off => -18.0,
        DeliveryLine.middle => 0.0,
        DeliveryLine.leg => 18.0,
      };
      _drawBounceMarker(canvas, screen, lineOffset);
      floor = Offset.lerp(
        start,
        contact.translate(lateral + lineOffset, 16),
        Curves.easeIn.transform(visualT),
      )!;
      final bounceFraction = switch (_state.deliveryPlan.length) {
        DeliveryLength.short => .55,
        DeliveryLength.good => .68,
        DeliveryLength.full => .80,
        DeliveryLength.yorker => .90,
      };
      if (_swingLocked) {
        floor = contact.translate(0, 16);
        lift = 16;
      } else if (visualT <= bounceFraction) {
        final u = visualT / bounceFraction;
        lift = ui.lerpDouble(92, 0, u)! + sin(pi * u) * 14;
      } else {
        final u = (visualT - bounceFraction) / (1 - bounceFraction);
        lift = sin(u * pi / 2) * 16;
      }
      pos = floor.translate(0, -lift);
      radius = ui.lerpDouble(4.5, 8.2, visualT)!;
    } else {
      return;
    }

    final trailColor = switch (_state.upcomingDelivery) {
      DeliveryType.pace => Cyber.cyan,
      DeliveryType.slower => Cyber.lime,
      DeliveryType.spin => Cyber.gold,
      DeliveryType.yorker => Cyber.danger,
    };
    final trailOrigin = _outcomeActive
        ? _contactPoint(layout)
        : layout.bowlerRelease.translate(0, -32);
    final trailCount = reducedMotion ? 0 : 4;
    for (var i = trailCount; i >= 1; i--) {
      final fraction = (1 - i * .075).clamp(0.0, 1.0);
      final point = Offset.lerp(trailOrigin, pos, fraction)!;
      canvas.drawCircle(
        point,
        max(1.2, radius * (1 - i / (trailCount + 2)) * .42),
        Paint()..color = trailColor.withValues(alpha: .18 / i),
      );
    }
    final heightFactor = (lift / (screen.height * .18)).clamp(0.0, 1.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: floor.translate(0, 2),
        width: radius * (2.45 - heightFactor * .55),
        height: radius * (.78 - heightFactor * .22),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: .38 - heightFactor * .22)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          1.5 + heightFactor * 3,
        ),
    );
    canvas.drawCircle(
      pos.translate(-8, -10),
      radius * 1.3,
      Paint()
        ..color = trailColor.withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawCircle(pos, radius + 2, Paint()..color = Cyber.bg);
    canvas.drawCircle(pos, radius, Paint()..color = Cyber.danger);
    canvas.drawCircle(
      pos.translate(-radius * 0.25, -radius * 0.2),
      radius * 0.22,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
    if (_outcomeActive && _outcomeTime < .34) {
      final ringT = (_outcomeTime / .34).clamp(0.0, 1.0);
      canvas.drawCircle(
        pos,
        radius + 8 + ringT * 30,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - ringT)
          ..color = trailColor.withValues(alpha: .8 * (1 - ringT)),
      );
    }
  }

  Offset _contactPoint(_CricketSceneLayout layout) {
    return switch (_liveSector) {
      ShotSector.off => layout.strikerFeet.translate(28, -56),
      ShotSector.v => layout.strikerFeet.translate(10, -38),
      ShotSector.leg => layout.strikerFeet.translate(-27, -54),
    };
  }

  void _drawBounceMarker(Canvas canvas, Size screen, double lineOffset) {
    if (_swingLocked) return;
    final y = switch (_state.deliveryPlan.length) {
      DeliveryLength.short => screen.height * .50,
      DeliveryLength.good => screen.height * .55,
      DeliveryLength.full => screen.height * .61,
      DeliveryLength.yorker => screen.height * .645,
    };
    final center = Offset(screen.width * .50 + lineOffset, y);
    final pulse = reducedMotion ? .5 : .5 + sin(_sequenceTime * 8) * .10;
    final markerStrength = switch (_state.settings.difficulty) {
      SuperOverDifficulty.rookie => 1.0,
      SuperOverDifficulty.pro => .72,
      SuperOverDifficulty.allStar => .46,
    };
    final color = _state.deliveryPlan.length == DeliveryLength.yorker
        ? Cyber.danger
        : Cyber.cyan;
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: (25 + pulse * 8) * markerStrength,
        height: 6 + 2 * markerStrength,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color.withValues(alpha: .34 + .36 * markerStrength),
    );
    canvas.drawCircle(center, 2.5, Paint()..color = color);
  }

  Offset _outcomeEnd(Size screen) {
    final layout = _CricketSceneLayout(screen);
    final outcome = _state.lastOutcome ?? ShotOutcome.dot;
    if (outcome == ShotOutcome.bowled) {
      return layout.strikerWicket.translate(2, -4);
    }
    final sector = _state.shotSector ?? _liveSector;
    final angle = SuperOverResolution.shotAngleForSector(sector);
    final radial = switch (outcome) {
      ShotOutcome.six => 1.02,
      ShotOutcome.four => .94,
      ShotOutcome.three => .78,
      ShotOutcome.two => .63,
      ShotOutcome.one => .47,
      ShotOutcome.caught => .67,
      ShotOutcome.dot => .27,
      ShotOutcome.bowled => 0.0,
    };
    return layout.fieldPoint(angle, radial);
  }

  void _drawOutcome(Canvas canvas, Size screen) {
    final outcome = _state.lastOutcome;
    if (!_outcomeActive || outcome == null) return;
    final t = (_outcomeTime / _outcomeDuration).clamp(0.0, 1.0);
    final layout = _CricketSceneLayout(screen);
    final color = _outcomeColor(outcome);

    final impactT = (_outcomeTime / .34).clamp(0.0, 1.0);
    if (impactT < 1 && _state.timingTier == TimingTier.perfect) {
      final contact = _contactPoint(layout);
      for (var i = 0; i < 6; i++) {
        final angle = i * pi / 3 - pi / 6;
        final inner = 5 + impactT * 7;
        final outer = 12 + impactT * 24;
        canvas.drawLine(
          contact.translate(cos(angle) * inner, sin(angle) * inner),
          contact.translate(cos(angle) * outer, sin(angle) * outer),
          Paint()
            ..color = Cyber.cyan.withValues(alpha: .78 * (1 - impactT))
            ..strokeWidth = 1.6 * (1 - impactT) + .4
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    if (outcome == ShotOutcome.four || outcome == ShotOutcome.six) {
      final pulse = (1 - ((_outcomeTime - .18) / .7).clamp(0.0, 1.0));
      if (pulse > 0) {
        final boundary = Path()
          ..moveTo(0, layout.horizonY)
          ..quadraticBezierTo(
            screen.width * .5,
            screen.height * .45,
            screen.width,
            layout.horizonY,
          );
        canvas.drawPath(
          boundary,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 + pulse * 2
            ..color = color.withValues(alpha: .18 + pulse * .46),
        );
      }
    }

    if (outcome == ShotOutcome.bowled) {
      final base = layout.strikerWicket;
      for (var i = 0; i < 5; i++) {
        final a = i * pi / 2.5 + t * 0.8;
        final d = 12 + t * 28;
        canvas.drawLine(
          base,
          base.translate(cos(a) * d, sin(a) * d),
          Paint()
            ..color = (i.isEven ? Cyber.danger : Cyber.amber).withValues(
              alpha: (1 - t) * .82,
            )
            ..strokeWidth = 2,
        );
      }
    }

    if (const {
      ShotOutcome.four,
      ShotOutcome.six,
      ShotOutcome.caught,
      ShotOutcome.bowled,
    }.contains(outcome)) {
      final reveal = Curves.easeOutBack.transform(
        ((_outcomeTime - .16) / .34).clamp(0.0, 1.0),
      );
      final fade = 1 - ((_outcomeTime - 1.42) / .55).clamp(0.0, 1.0);
      final label = switch (outcome) {
        ShotOutcome.four => '4',
        ShotOutcome.six => '6',
        ShotOutcome.caught || ShotOutcome.bowled => 'WICKET',
        _ => _outcomeLabel(outcome),
      };
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style:
              Cyber.display(
                outcome == ShotOutcome.four || outcome == ShotOutcome.six
                    ? 36 * reveal
                    : 20 * reveal,
                color: color.withValues(alpha: fade),
                letterSpacing: 1.2,
              ).copyWith(
                shadows: [
                  Shadow(color: Cyber.bg.withValues(alpha: .9), blurRadius: 4),
                ],
              ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: screen.width * .6);
      final labelX = switch (_state.shotSector ?? _liveSector) {
        ShotSector.off => screen.width * .74,
        ShotSector.v => screen.width * .76,
        ShotSector.leg => screen.width * .24,
      };
      tp.paint(canvas, Offset(labelX - tp.width * .5, screen.height * .225));
    }
  }
}
