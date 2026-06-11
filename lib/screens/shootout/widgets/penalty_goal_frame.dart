import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/enums.dart';
import '../../../config/theme.dart';
import '../../../models/match.dart';
import '../../../utils/sound_effects.dart';

/// Fraction of the result-scene timeline at which the ball reaches the goal.
const _kSceneImpact = 0.55;

/// Shared goal-mouth geometry so the choose overlay, the painters and the
/// result scene all agree on where posts, zones and the spot sit.
class _GoalGeom {
  _GoalGeom(Size s)
    : left = s.width * 0.10,
      right = s.width * 0.90,
      crossbarY = s.height * 0.16,
      groundY = s.height * 0.80,
      spot = Offset(s.width / 2, s.height * 0.93);

  final double left;
  final double right;
  final double crossbarY;
  final double groundY;
  final Offset spot;

  double get width => right - left;
  double get mouthH => groundY - crossbarY;

  double zoneX(PenaltyDirection d) => switch (d) {
    PenaltyDirection.left => left + width * 0.17,
    PenaltyDirection.center => left + width * 0.5,
    PenaltyDirection.right => right - width * 0.17,
  };

  double get targetY => crossbarY + mouthH * 0.40;

  Offset target(PenaltyDirection d) => Offset(zoneX(d), targetY);
}

double _zoneSign(PenaltyDirection d) => switch (d) {
  PenaltyDirection.left => -1,
  PenaltyDirection.center => 0,
  PenaltyDirection.right => 1,
};

// ─── Shared painting helpers ─────────────────────────────────────────────────

/// Posts, crossbar, net grid and ground. On a goal, the net bulges outward
/// around [rippleCenter] while [rippleT] runs 0→1.
void _paintGoalFrame(
  Canvas canvas,
  _GoalGeom g, {
  double rippleT = 0,
  Offset? rippleCenter,
}) {
  final netPaint = Paint()
    ..color = Cyber.cyan.withValues(alpha: 0.20)
    ..strokeWidth = 1
    ..style = PaintingStyle.stroke;

  Offset displace(Offset p) {
    final c = rippleCenter;
    if (c == null || rippleT <= 0 || rippleT >= 1) return p;
    final d = (p - c).distance;
    if (d < 1) return p;
    final amp = 11 * sin(rippleT * pi) * exp(-(d * d) / (2 * 42 * 42));
    return p + (p - c) / d * amp;
  }

  Path netLine(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  List<Offset> sample(Offset a, Offset b) => [
    for (var i = 0; i <= 10; i++) displace(Offset.lerp(a, b, i / 10)!),
  ];

  // Net verticals + horizontals (drawn as displaceable polylines).
  const cols = 9;
  const rows = 5;
  for (var i = 1; i < cols; i++) {
    final x = g.left + g.width * i / cols;
    canvas.drawPath(
      netLine(sample(Offset(x, g.crossbarY), Offset(x, g.groundY))),
      netPaint,
    );
  }
  for (var i = 1; i < rows; i++) {
    final y = g.crossbarY + g.mouthH * i / rows;
    canvas.drawPath(
      netLine(sample(Offset(g.left, y), Offset(g.right, y))),
      netPaint,
    );
  }

  // Expanding impact ring while the net ripples.
  final c = rippleCenter;
  if (c != null && rippleT > 0 && rippleT < 1) {
    canvas.drawCircle(
      c,
      8 + 34 * rippleT,
      Paint()
        ..color = Cyber.lime.withValues(alpha: 0.5 * (1 - rippleT))
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  // Frame: posts + crossbar over the net, ground line, penalty spot.
  final framePaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.92)
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  canvas.drawLine(
    Offset(g.left, g.groundY),
    Offset(g.left, g.crossbarY),
    framePaint,
  );
  canvas.drawLine(
    Offset(g.right, g.groundY),
    Offset(g.right, g.crossbarY),
    framePaint,
  );
  canvas.drawLine(
    Offset(g.left, g.crossbarY),
    Offset(g.right, g.crossbarY),
    framePaint,
  );

  final groundPaint = Paint()
    ..color = Cyber.cyan.withValues(alpha: 0.35)
    ..strokeWidth = 1.5;
  canvas.drawLine(
    Offset(0, g.groundY),
    Offset(g.left + g.width + g.left, g.groundY),
    groundPaint,
  );
  canvas.drawCircle(
    g.spot,
    2.5,
    Paint()..color = Colors.white.withValues(alpha: 0.7),
  );
}

/// Stylised angular keeper. [diveT] 0 = upright on the line, 1 = fully
/// committed toward [dir] (a crouch-and-reach for center).
void _paintKeeper(
  Canvas canvas,
  _GoalGeom g, {
  required Color color,
  required double diveT,
  required PenaltyDirection dir,
}) {
  final kh = g.mouthH * 0.62;
  final sign = _zoneSign(dir);
  final centerX = g.left + g.width / 2;
  final feetX = centerX + (g.zoneX(dir) - centerX) * 0.62 * diveT;
  final crouch = sign == 0 ? diveT : 0.0;

  canvas.save();
  canvas.translate(feetX, g.groundY - kh * 0.10 * crouch);
  canvas.rotate(sign * diveT * 1.0);

  final stroke = Paint()
    ..color = color
    ..strokeWidth = 3.2
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  // Head.
  canvas.drawCircle(Offset(0, -kh * 0.88), kh * 0.10, stroke);
  // Torso.
  canvas.drawLine(Offset(0, -kh * 0.76), Offset(0, -kh * 0.34), stroke);
  // Arms: raised V at rest → straight reach when committed.
  final armY = -kh * 0.68;
  final reach = Offset.lerp(
    Offset(kh * 0.28, -kh * 0.92),
    Offset(kh * 0.12, -kh * 1.06),
    crouch,
  )!;
  canvas.drawLine(Offset(0, armY), Offset(reach.dx, reach.dy), stroke);
  canvas.drawLine(Offset(0, armY), Offset(-reach.dx, reach.dy), stroke);
  // Legs.
  canvas.drawLine(Offset(0, -kh * 0.34), Offset(kh * 0.14, 0), stroke);
  canvas.drawLine(Offset(0, -kh * 0.34), Offset(-kh * 0.14, 0), stroke);

  canvas.restore();
}

void _paintBall(Canvas canvas, Offset pos, double scale, {double alpha = 1}) {
  final r = 8.0 * scale;
  canvas.drawCircle(
    pos,
    r,
    Paint()..color = Colors.white.withValues(alpha: 0.95 * alpha),
  );
  final seam = Paint()
    ..color = Cyber.bg2.withValues(alpha: 0.85 * alpha)
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke;
  canvas.drawCircle(pos, r * 0.45, seam);
  canvas.drawArc(
    Rect.fromCircle(center: pos, radius: r * 0.85),
    0.6,
    1.6,
    false,
    seam,
  );
}

// ─── Choose phase: tappable goal mouth ───────────────────────────────────────

/// Interactive goal mouth for the penalty choose phase: the three direction
/// picks are tap zones on the goal itself. Selection still flows through the
/// same callback the old direction buttons used — presentation only.
class PenaltyGoalMouth extends StatelessWidget {
  const PenaltyGoalMouth({
    required this.playerTaking,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final bool playerTaking;
  final PenaltyDirection? selected;
  final ValueChanged<PenaltyDirection> onSelect;

  String _zoneLabel(PenaltyDirection d) => switch (d) {
    PenaltyDirection.left => playerTaking ? '< LEFT' : '< DIVE',
    PenaltyDirection.center => playerTaking ? 'CENTER' : 'STAY',
    PenaltyDirection.right => playerTaking ? 'RIGHT >' : 'DIVE >',
  };

  @override
  Widget build(BuildContext context) {
    final accent = playerTaking ? Cyber.cyan : Cyber.amber;
    return SizedBox(
      height: 216,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, 216);
          final g = _GoalGeom(size);
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _GoalMouthPainter(
                    playerTaking: playerTaking,
                    selected: selected,
                  ),
                ),
              ),
              // Reticles at the three aim points.
              for (final dir in PenaltyDirection.values)
                Positioned(
                  left: g.zoneX(dir) - 26,
                  top: g.targetY - 26,
                  width: 52,
                  height: 52,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 160),
                    opacity: selected == dir ? 1 : 0.30,
                    child: CustomPaint(
                      painter: _ZoneReticlePainter(
                        accent: accent,
                        active: selected == dir,
                      ),
                    ),
                  ),
                ),
              // Fat-finger hit zones: full-height thirds.
              Row(
                children: [
                  for (final dir in PenaltyDirection.values)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          playSound(SoundEffect.uiTap);
                          onSelect(dir);
                        },
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 160),
                              style: Cyber.label(
                                10,
                                color: selected == dir ? accent : Cyber.muted,
                                letterSpacing: 1.2,
                              ),
                              child: Text(_zoneLabel(dir)),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GoalMouthPainter extends CustomPainter {
  _GoalMouthPainter({required this.playerTaking, required this.selected});

  final bool playerTaking;
  final PenaltyDirection? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final g = _GoalGeom(size);

    // Selected zone wash (behind the net).
    final sel = selected;
    if (sel != null) {
      final accent = playerTaking ? Cyber.cyan : Cyber.amber;
      final third = g.width / 3;
      final index = PenaltyDirection.values.indexOf(sel);
      canvas.drawRect(
        Rect.fromLTRB(
          g.left + third * index,
          g.crossbarY,
          g.left + third * (index + 1),
          g.groundY,
        ),
        Paint()..color = accent.withValues(alpha: 0.09),
      );
    }

    _paintGoalFrame(canvas, g);

    // Opposing keeper guards the line when you shoot; your keeper (leaning
    // toward your pick) when you dive.
    if (playerTaking) {
      _paintKeeper(
        canvas,
        g,
        color: Cyber.amber.withValues(alpha: 0.9),
        diveT: 0,
        dir: PenaltyDirection.center,
      );
    } else {
      _paintKeeper(
        canvas,
        g,
        color: Cyber.cyan.withValues(alpha: 0.95),
        diveT: selected == null ? 0 : 0.30,
        dir: selected ?? PenaltyDirection.center,
      );
    }

    _paintBall(canvas, g.spot, 1);
  }

  @override
  bool shouldRepaint(covariant _GoalMouthPainter old) =>
      old.selected != selected || old.playerTaking != playerTaking;
}

/// Corner ticks + crosshair ring marking an aim zone.
class _ZoneReticlePainter extends CustomPainter {
  _ZoneReticlePainter({required this.accent, required this.active});

  final Color accent;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = active ? accent : Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = active ? 2 : 1.4
      ..style = PaintingStyle.stroke;
    final w = size.width;
    final h = size.height;
    const len = 10.0;
    // Corner ticks.
    canvas.drawPath(
      Path()
        ..moveTo(0, len)
        ..lineTo(0, 0)
        ..lineTo(len, 0)
        ..moveTo(w - len, 0)
        ..lineTo(w, 0)
        ..lineTo(w, len)
        ..moveTo(w, h - len)
        ..lineTo(w, h)
        ..lineTo(w - len, h)
        ..moveTo(len, h)
        ..lineTo(0, h)
        ..lineTo(0, h - len),
      paint,
    );
    canvas.drawCircle(Offset(w / 2, h / 2), 7, paint);
    if (active) {
      canvas.drawCircle(Offset(w / 2, h / 2), 2.4, Paint()..color = accent);
    }
  }

  @override
  bool shouldRepaint(covariant _ZoneReticlePainter old) =>
      old.accent != accent || old.active != active;
}

// ─── Result phase: ball flight + keeper dive scene ───────────────────────────

/// Self-animating penalty resolution: the ball arcs to the shot zone while the
/// keeper dives, then either the net ripples (goal) or the keeper smothers it
/// (save), and the verdict stamps in. Owns its impact sound + haptic so the
/// payoff lands exactly when the ball does.
class PenaltyGoalScene extends StatefulWidget {
  const PenaltyGoalScene({required this.kick, super.key});

  final PenaltyKick kick;

  @override
  State<PenaltyGoalScene> createState() => _PenaltyGoalSceneState();
}

class _PenaltyGoalSceneState extends State<PenaltyGoalScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  bool _started = false;
  bool _impactFired = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _impactFired = true;
      _c.value = 1;
      _fireImpact();
    } else {
      _c.addListener(_onTick);
      _c.forward();
    }
  }

  void _onTick() {
    if (_impactFired || _c.value < _kSceneImpact) return;
    _impactFired = true;
    _fireImpact();
  }

  void _fireImpact() {
    final goal = widget.kick.scored;
    playSound(goal ? SoundEffect.goal : SoundEffect.save);
    if (goal) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _seg(double a, double b, [Curve curve = Curves.linear]) {
    final t = _c.value;
    if (t <= a) return 0;
    if (t >= b) return 1;
    return curve.transform((t - a) / (b - a));
  }

  @override
  Widget build(BuildContext context) {
    final kick = widget.kick;
    final goal = kick.scored;
    final verdictColor = goal ? Cyber.lime : Cyber.red;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final flashT = _seg(_kSceneImpact, 0.75);
        final flash = 0.30 * sin(flashT * pi);
        final shakeT = _seg(_kSceneImpact, 0.9);
        final shakeX = goal ? 0.0 : sin(shakeT * pi * 5) * 6 * (1 - shakeT);
        final stampT = _seg(0.62, 0.92, Curves.easeOutBack);

        return Transform.translate(
          offset: Offset(shakeX, 0),
          child: SizedBox(
            height: 232,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _PenaltyScenePainter(t: _c.value, kick: kick),
                  ),
                ),
                if (flash > 0.01)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: verdictColor.withValues(alpha: flash),
                      ),
                    ),
                  ),
                if (stampT > 0)
                  Center(
                    child: Opacity(
                      opacity: stampT.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.6 + 0.4 * stampT,
                        child: Text(
                          goal ? 'GOAL' : 'SAVED',
                          style:
                              Cyber.display(
                                34,
                                color: verdictColor,
                                letterSpacing: 3,
                              ).copyWith(
                                shadows: [
                                  Shadow(
                                    color: verdictColor.withValues(alpha: 0.75),
                                    blurRadius: 22,
                                  ),
                                ],
                              ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PenaltyScenePainter extends CustomPainter {
  _PenaltyScenePainter({required this.t, required this.kick});

  final double t;
  final PenaltyKick kick;

  double _seg(double a, double b, [Curve curve = Curves.linear]) {
    if (t <= a) return 0;
    if (t >= b) return 1;
    return curve.transform((t - a) / (b - a));
  }

  Offset _bezier(Offset p0, Offset p1, Offset p2, double u) {
    final v = 1 - u;
    return p0 * (v * v) + p1 * (2 * v * u) + p2 * (u * u);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final g = _GoalGeom(size);
    final goal = kick.scored;
    final target = g.target(kick.shootDirection);

    final rippleT = goal ? _seg(_kSceneImpact, 1.0) : 0.0;
    _paintGoalFrame(
      canvas,
      g,
      rippleT: rippleT,
      rippleCenter: goal ? target : null,
    );

    // Keeper: the shooter's opponent. Cyan when YOU are keeping, amber when
    // the CPU keeps. Dive begins just after the ball leaves the spot.
    final keeperColor = kick.byPlayer
        ? Cyber.amber.withValues(alpha: 0.95)
        : Cyber.cyan.withValues(alpha: 0.95);
    final diveT = _seg(0.16, 0.58, Curves.easeOutCubic);
    _paintKeeper(
      canvas,
      g,
      color: keeperColor,
      diveT: diveT,
      dir: kick.diveDirection,
    );

    // Ball flight: spot → target along a floaty arc, with a short trail.
    final flightT = _seg(0.08, _kSceneImpact, Curves.easeIn);
    final control = Offset(
      (g.spot.dx + target.dx) / 2,
      g.crossbarY + g.mouthH * 0.05,
    );

    Offset ballAt(double u) => _bezier(g.spot, control, target, u);

    if (t < _kSceneImpact) {
      if (flightT > 0) {
        // Motion-trail ghosts.
        for (final (lag, alpha) in [(0.16, 0.12), (0.08, 0.25)]) {
          final u = (flightT - lag).clamp(0.0, 1.0);
          if (u > 0) {
            _paintBall(canvas, ballAt(u), 1 - 0.2 * u, alpha: alpha);
          }
        }
      }
      _paintBall(canvas, ballAt(flightT), 1 - 0.2 * flightT);
    } else if (goal) {
      // Ball nestles into the bulging net.
      final settle = _seg(_kSceneImpact, 0.75, Curves.easeOut);
      _paintBall(canvas, target + Offset(0, 6 * settle), 0.8);
    } else {
      // Smothered: ball drops from the glove to the turf.
      final dropT = _seg(_kSceneImpact, 0.85, Curves.easeIn);
      final outward = _zoneSign(kick.shootDirection);
      final landed = Offset(
        target.dx + outward * 26 * dropT,
        target.dy + (g.groundY - 6 - target.dy) * dropT,
      );
      _paintBall(canvas, landed, 0.8 + 0.1 * dropT);
      // Glove-flash burst at the intercept.
      final sparkT = _seg(_kSceneImpact, 0.78);
      if (sparkT > 0 && sparkT < 1) {
        final spark = Paint()
          ..color = Cyber.violet.withValues(alpha: 0.8 * (1 - sparkT))
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 8; i++) {
          final a = i * pi / 4;
          final dirV = Offset(cos(a), sin(a));
          canvas.drawLine(
            target + dirV * (6 + 16 * sparkT),
            target + dirV * (12 + 22 * sparkT),
            spark,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PenaltyScenePainter old) =>
      old.t != t || old.kick != kick;
}
