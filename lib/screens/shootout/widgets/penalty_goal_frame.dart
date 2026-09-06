import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/enums.dart';
import '../../../config/theme.dart';
import '../../../models/cards.dart';
import '../../../models/match.dart';
import '../../../utils/game_audio_mappings.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/goal_mouth.dart';
import 'penalty_keeper_rig.dart';

/// Fraction of the result-scene timeline at which the ball reaches the goal.
const _kSceneImpact = 0.62;

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
///
/// Thin adapter over the shared [paintGoalMouth], which this drawing was
/// extracted into so the shot map could reuse the same goal instead of
/// re-deriving it. Verified pixel-identical to the original before switching.
void _paintGoalFrame(
  Canvas canvas,
  _GoalGeom g, {
  double rippleT = 0,
  Offset? rippleCenter,
}) => paintGoalMouth(
  canvas,
  GoalMouthFrame(
    left: g.left,
    right: g.right,
    crossbarY: g.crossbarY,
    groundY: g.groundY,
  ),
  rippleT: rippleT,
  rippleCenter: rippleCenter,
  spot: g.spot,
);

void _paintBall(Canvas canvas, Offset pos, double scale, {double alpha = 1}) =>
    paintGoalBall(canvas, pos, scale, alpha: alpha);

// ─── Choose phase: tappable goal mouth ───────────────────────────────────────

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

/// Role-aware penalty interaction. Shooting keeps the familiar goal targets;
/// defending replaces them with explicit keeper controls below a non-tappable
/// goal so the two responsibilities cannot be mistaken for each other.
class PenaltyInteractionArena extends StatefulWidget {
  const PenaltyInteractionArena({
    required this.role,
    required this.shooter,
    required this.keeper,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final ShootoutTurnRole role;
  final PlayerCard shooter;
  final PlayerCard keeper;
  final PenaltyDirection? selected;
  final ValueChanged<PenaltyDirection> onSelect;

  @override
  State<PenaltyInteractionArena> createState() =>
      _PenaltyInteractionArenaState();
}

class _PenaltyInteractionArenaState extends State<PenaltyInteractionArena>
    with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final AnimationController _preview = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  );
  bool _reduceMotion = false;

  bool get _shooting => widget.role == ShootoutTurnRole.shooting;

  String _directionLabel(PenaltyDirection direction) => switch (direction) {
    PenaltyDirection.left => 'LEFT',
    PenaltyDirection.center => 'CENTER',
    PenaltyDirection.right => 'RIGHT',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncMotion(resetPreview: false);
  }

  @override
  void didUpdateWidget(covariant PenaltyInteractionArena oldWidget) {
    super.didUpdateWidget(oldWidget);
    final roleChanged = oldWidget.role != widget.role;
    final directionChanged = oldWidget.selected != widget.selected;
    if (roleChanged || directionChanged) {
      _syncMotion(resetPreview: directionChanged);
    }
  }

  void _syncMotion({required bool resetPreview}) {
    if (_reduceMotion) {
      _idle
        ..stop()
        ..value = 0;
    } else if (!_idle.isAnimating) {
      _idle.repeat();
    }

    if (!_shooting || widget.selected == null) {
      _preview
        ..stop()
        ..value = 0;
    } else if (_reduceMotion) {
      _preview
        ..stop()
        ..value = 0.78;
    } else if (resetPreview || !_preview.isAnimating) {
      _preview
        ..value = 0
        ..repeat();
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    _preview.dispose();
    super.dispose();
  }

  void _select(PenaltyDirection direction) {
    HapticFeedback.selectionClick();
    playSound(SoundEffect.penaltyTarget);
    widget.onSelect(direction);
  }

  @override
  Widget build(BuildContext context) {
    const goalHeight = 220.0;
    final stateAccent = _shooting ? Cyber.cyan : Cyber.amber;
    return Semantics(
      container: true,
      label: _shooting
          ? widget.selected == null
                ? 'Your shot. Choose a goal target.'
                : 'Shot preview ${_directionLabel(widget.selected!).toLowerCase()}.'
          : 'You are the goalkeeper. Choose a dive direction.',
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: ValueKey(
                'penalty-characters-${widget.shooter.id}-${widget.keeper.id}',
              ),
              height: goalHeight,
              decoration: BoxDecoration(
                color: Cyber.bg.withValues(alpha: 0.28),
                border: Border.all(color: stateAccent.withValues(alpha: 0.22)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    stateAccent.withValues(alpha: 0.06),
                    Cyber.bg.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(constraints.maxWidth, goalHeight);
                  final goal = _GoalGeom(size);
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            end: widget.selected == null ? 0 : 1,
                          ),
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          builder: (context, selectionT, _) => AnimatedBuilder(
                            animation: Listenable.merge([_idle, _preview]),
                            builder: (context, _) => CustomPaint(
                              key: _shooting && widget.selected != null
                                  ? ValueKey(
                                      'shot-preview-${widget.selected!.name}',
                                    )
                                  : const ValueKey('penalty-arena-paint'),
                              painter: _InteractionArenaPainter(
                                role: widget.role,
                                shooter: widget.shooter,
                                keeper: widget.keeper,
                                selected: widget.selected,
                                selectionT: selectionT,
                                idleT: _idle.value,
                                previewT: _preview.value,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_shooting) ...[
                        for (final direction in PenaltyDirection.values)
                          Positioned(
                            left: goal.zoneX(direction) - 30,
                            top: goal.targetY - 30,
                            width: 60,
                            height: 60,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 160),
                              opacity: widget.selected == direction ? 1 : 0.42,
                              child: CustomPaint(
                                key: ValueKey('shot-reticle-${direction.name}'),
                                painter: _ZoneReticlePainter(
                                  accent: Cyber.cyan,
                                  active: widget.selected == direction,
                                ),
                              ),
                            ),
                          ),
                        for (final direction in PenaltyDirection.values)
                          Positioned(
                            left: goal.zoneX(direction) - 39,
                            top: goal.targetY + 33,
                            width: 78,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              decoration: BoxDecoration(
                                color: widget.selected == direction
                                    ? Cyber.cyan.withValues(alpha: 0.16)
                                    : Cyber.bg2.withValues(alpha: 0.34),
                                border: Border.all(
                                  color:
                                      (widget.selected == direction
                                              ? Cyber.cyan
                                              : Cyber.line)
                                          .withValues(
                                            alpha: widget.selected == direction
                                                ? 0.45
                                                : 0.18,
                                          ),
                                ),
                              ),
                              child: Text(
                                _directionLabel(direction),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Cyber.label(
                                  9,
                                  color: widget.selected == direction
                                      ? Cyber.cyan
                                      : Colors.white.withValues(alpha: 0.68),
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        Positioned.fill(
                          child: Row(
                            children: [
                              for (final (index, direction)
                                  in PenaltyDirection.values.indexed)
                                Expanded(
                                  child: FocusTraversalOrder(
                                    order: NumericFocusOrder(index.toDouble()),
                                    child: Semantics(
                                      button: true,
                                      label:
                                          'Shoot ${_directionLabel(direction).toLowerCase()}',
                                      selected: widget.selected == direction,
                                      child: Material(
                                        type: MaterialType.transparency,
                                        child: InkWell(
                                          key: ValueKey(
                                            'shoot-direction-${direction.name}',
                                          ),
                                          onTap: () => _select(direction),
                                          child: const SizedBox.expand(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            if (!_shooting) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final (index, direction)
                      in PenaltyDirection.values.indexed) ...[
                    if (index > 0) const SizedBox(width: 8),
                    Expanded(
                      child: FocusTraversalOrder(
                        order: NumericFocusOrder(index.toDouble()),
                        child: _DivePad(
                          direction: direction,
                          selected: widget.selected == direction,
                          onPressed: () => _select(direction),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DivePad extends StatelessWidget {
  const _DivePad({
    required this.direction,
    required this.selected,
    required this.onPressed,
  });

  final PenaltyDirection direction;
  final bool selected;
  final VoidCallback onPressed;

  String get _label => switch (direction) {
    PenaltyDirection.left => 'DIVE LEFT',
    PenaltyDirection.center => 'HOLD CENTER',
    PenaltyDirection.right => 'DIVE RIGHT',
  };

  IconData get _icon => switch (direction) {
    PenaltyDirection.left => Icons.keyboard_double_arrow_left,
    PenaltyDirection.center => Icons.shield_outlined,
    PenaltyDirection.right => Icons.keyboard_double_arrow_right,
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Keeper ${_label.toLowerCase()}',
      child: Material(
        color: selected
            ? Cyber.cyan.withValues(alpha: 0.18)
            : Cyber.panel2.withValues(alpha: 0.86),
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: (selected ? Cyber.cyan : Cyber.line).withValues(
              alpha: selected ? 0.72 : 0.42,
            ),
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: InkWell(
          key: ValueKey('dive-direction-${direction.name}'),
          onTap: onPressed,
          borderRadius: BorderRadius.circular(3),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _icon,
                    size: 20,
                    color: selected ? Cyber.cyan : Colors.white,
                  ),
                  const SizedBox(height: 5),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _label,
                      maxLines: 1,
                      style: Cyber.label(
                        9,
                        color: selected ? Cyber.cyan : Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InteractionArenaPainter extends CustomPainter {
  _InteractionArenaPainter({
    required this.role,
    required this.shooter,
    required this.keeper,
    required this.selected,
    required this.selectionT,
    required this.idleT,
    required this.previewT,
  });

  final ShootoutTurnRole role;
  final PlayerCard shooter;
  final PlayerCard keeper;
  final PenaltyDirection? selected;
  final double selectionT;
  final double idleT;
  final double previewT;

  Offset _previewPoint(Offset start, Offset control, Offset end, double t) {
    final inverse = 1 - t;
    return start * (inverse * inverse) +
        control * (2 * inverse * t) +
        end * (t * t);
  }

  void _paintShotPreview(
    Canvas canvas,
    _GoalGeom goal,
    PenaltyDirection direction,
  ) {
    final target = goal.target(direction);
    final control = Offset(
      (goal.spot.dx + target.dx) / 2,
      goal.crossbarY + goal.mouthH * 0.04,
    );
    final trajectory = Path()
      ..moveTo(goal.spot.dx, goal.spot.dy)
      ..quadraticBezierTo(control.dx, control.dy, target.dx, target.dy);
    canvas.drawPath(
      trajectory,
      Paint()
        ..color = Cyber.cyan.withValues(alpha: 0.22)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke,
    );
    for (var index = 1; index <= 5; index++) {
      canvas.drawCircle(
        _previewPoint(goal.spot, control, target, index / 6),
        1.4,
        Paint()..color = Cyber.cyan.withValues(alpha: 0.38),
      );
    }

    // Keep a faint ball on the spot so this reads as an aim preview rather
    // than the real kick resolving before the confirmation button is pressed.
    _paintBall(canvas, goal.spot, 0.82, alpha: 0.28);
    final flightT = Curves.easeIn.transform((previewT / 0.78).clamp(0.0, 1.0));
    final fade = previewT <= 0.88
        ? 1.0
        : (1 - (previewT - 0.88) / 0.12).clamp(0.0, 1.0);
    for (final (lag, alpha) in [(0.14, 0.13), (0.07, 0.25)]) {
      final trailT = (flightT - lag).clamp(0.0, 1.0);
      if (trailT > 0) {
        _paintBall(
          canvas,
          _previewPoint(goal.spot, control, target, trailT),
          0.9 - trailT * 0.12,
          alpha: alpha * fade,
        );
      }
    }
    _paintBall(
      canvas,
      _previewPoint(goal.spot, control, target, flightT),
      1 - flightT * 0.16,
      alpha: fade,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final goal = _GoalGeom(size);
    final shooting = role == ShootoutTurnRole.shooting;
    final direction = selected ?? PenaltyDirection.center;
    if (shooting && selected != null) {
      final third = goal.width / 3;
      final index = PenaltyDirection.values.indexOf(direction);
      canvas.drawRect(
        Rect.fromLTRB(
          goal.left + third * index,
          goal.crossbarY,
          goal.left + third * (index + 1),
          goal.groundY,
        ),
        Paint()..color = Cyber.cyan.withValues(alpha: 0.14),
      );
    }

    _paintGoalFrame(canvas, goal);
    final pose = !shooting && selected != null
        ? (direction == PenaltyDirection.center
              ? KeeperPose.smother
              : KeeperPose.anticipate)
        : KeeperPose.ready;
    paintPenaltyKeeper(
      canvas,
      anchor: Offset(goal.left + goal.width / 2, goal.groundY),
      height: goal.mouthH * 0.78,
      visual: PenaltyAthleteVisualSpec.fromCard(keeper, userSide: !shooting),
      pose: pose,
      direction: shooting ? PenaltyDirection.center : direction,
      progress: shooting ? 0 : selectionT,
      // The opposing keeper must stay completely still while the user aims.
      idlePhase: shooting ? 0 : idleT,
    );
    paintPenaltyKicker(
      canvas,
      anchor: goal.spot,
      height: goal.mouthH * 0.52,
      visual: PenaltyAthleteVisualSpec.fromCard(shooter, userSide: shooting),
      pose: KickerPose.ready,
      direction: direction,
      progress: selectionT,
      idlePhase: idleT,
    );
    if (shooting && selected != null) {
      _paintShotPreview(canvas, goal, direction);
    } else {
      _paintBall(canvas, goal.spot, 1);
    }
  }

  @override
  bool shouldRepaint(covariant _InteractionArenaPainter old) =>
      old.role != role ||
      old.shooter != shooter ||
      old.keeper != keeper ||
      old.selected != selected ||
      old.selectionT != selectionT ||
      old.idleT != idleT ||
      old.previewT != previewT;
}

/// Self-animating penalty resolution: the ball arcs to the shot zone while the
/// keeper dives, then either the net ripples (goal) or the keeper smothers it.
/// Owns its impact sound and haptic so the payoff lands with the ball.
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
    final positiveForUser = widget.kick.byPlayer ? goal : !goal;
    playSound(shootoutImpactSound(goal: goal));
    if (positiveForUser) {
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
    final positiveForUser = kick.byPlayer ? goal : !goal;
    final verdictColor = positiveForUser ? Cyber.lime : Cyber.red;
    final verdict = switch ((kick.byPlayer, goal)) {
      (true, true) => 'GOAL',
      (true, false) =>
        'SAVED BY ${(kick.keeper?.shortName ?? 'KEEPER').toUpperCase()}',
      (false, true) => 'GOAL CONCEDED',
      (false, false) => 'YOU SAVED IT',
    };

    return Semantics(
      liveRegion: true,
      label: verdict,
      child: AnimatedBuilder(
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
                            verdict,
                            textAlign: TextAlign.center,
                            style:
                                Cyber.display(
                                  verdict.length > 13 ? 22 : 34,
                                  color: verdictColor,
                                  letterSpacing: verdict.length > 13 ? 1.4 : 3,
                                ).copyWith(
                                  shadows: [
                                    Shadow(
                                      color: verdictColor.withValues(
                                        alpha: 0.75,
                                      ),
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
      ),
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

    // Keeper: the shooter's opponent. The articulated rig commits after the
    // taker's plant foot, reaches the real ball on a save, then recovers.
    final diveT = _seg(0.30, _kSceneImpact, Curves.easeOutCubic);
    final recoveryT = _seg(0.76, 1.0, Curves.easeOutCubic);
    final keeperPose = goal
        ? KeeperPose.beaten
        : recoveryT > 0
        ? KeeperPose.recover
        : (kick.diveDirection == PenaltyDirection.center
              ? KeeperPose.smother
              : KeeperPose.catching);
    paintPenaltyKeeper(
      canvas,
      anchor: Offset(g.left + g.width / 2, g.groundY),
      height: g.mouthH * 0.78,
      visual: PenaltyAthleteVisualSpec.fromCard(
        kick.keeper,
        userSide: !kick.byPlayer,
      ),
      pose: keeperPose,
      direction: kick.diveDirection,
      progress: recoveryT > 0 ? recoveryT : diveT,
      intercept: goal || recoveryT > 0 ? null : target,
    );

    final kickerPose = t < 0.18
        ? KickerPose.runUp
        : t < 0.33
        ? KickerPose.strike
        : t < _kSceneImpact
        ? KickerPose.followThrough
        : goal
        ? KickerPose.celebrate
        : KickerPose.dejected;
    final kickerT = switch (kickerPose) {
      KickerPose.runUp => _seg(0.0, 0.22, Curves.easeInCubic),
      KickerPose.strike => _seg(0.18, 0.33, Curves.easeOutCubic),
      KickerPose.followThrough => _seg(0.33, 0.52, Curves.easeOutCubic),
      KickerPose.celebrate ||
      KickerPose.dejected => _seg(_kSceneImpact, 1.0, Curves.easeOutBack),
      KickerPose.ready => 1.0,
    };
    paintPenaltyKicker(
      canvas,
      anchor: g.spot,
      height: g.mouthH * 0.56,
      visual: PenaltyAthleteVisualSpec.fromCard(
        kick.shooter,
        userSide: kick.byPlayer,
      ),
      pose: kickerPose,
      direction: kick.shootDirection,
      progress: kickerT,
    );

    // Ball flight begins only once the taker's striking leg reaches the spot.
    final flightT = _seg(0.30, _kSceneImpact, Curves.easeIn);
    final control = Offset(
      (g.spot.dx + target.dx) / 2,
      g.crossbarY + g.mouthH * 0.05,
    );

    Offset ballAt(double u) => _bezier(g.spot, control, target, u);

    if (t < 0.30) {
      _paintBall(canvas, g.spot, 1);
    } else if (t < _kSceneImpact) {
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
