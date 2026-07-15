import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../games/tennis/tennis_game.dart';
import '../../../models/tennis.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

class TennisControls extends StatelessWidget {
  const TennisControls({required this.game, required this.settings, super.key});

  final TennisGame game;
  final TennisSettings settings;

  @override
  Widget build(BuildContext context) {
    final movement = _MovementZone(game: game, settings: settings);
    final shot = _ShotZone(game: game, settings: settings);
    return IgnorePointer(
      ignoring: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Cyber.bg.withValues(alpha: 0.98),
              Cyber.bg.withValues(alpha: 0.78),
              Cyber.bg.withValues(alpha: 0),
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: settings.leftHanded ? [shot, movement] : [movement, shot],
        ),
      ),
    );
  }
}

class _MovementZone extends StatefulWidget {
  const _MovementZone({required this.game, required this.settings});

  final TennisGame game;
  final TennisSettings settings;

  @override
  State<_MovementZone> createState() => _MovementZoneState();
}

class _MovementZoneState extends State<_MovementZone> {
  int? _pointer;
  Offset _thumb = Offset.zero;
  Offset _start = Offset.zero;
  DateTime? _startedAt;

  void _down(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _start = event.localPosition;
    _startedAt = DateTime.now();
    _apply(event.localPosition);
  }

  void _move(PointerMoveEvent event) {
    if (_pointer != event.pointer) return;
    _apply(event.localPosition);
  }

  void _apply(Offset local) {
    const radius = 46.0;
    final center = Offset(64 * widget.settings.controlScale, 64);
    var delta = local - center;
    if (delta.distance > radius) {
      delta = Offset.fromDirection(delta.direction, radius);
    }
    final elapsed = _startedAt == null
        ? 999
        : DateTime.now().difference(_startedAt!).inMilliseconds;
    final sprint = elapsed < 210 && (local - _start).distance > 42;
    _thumb = delta;
    widget.game.setMove(delta.dx / radius, delta.dy / radius, sprint: sprint);
    if (mounted) setState(() {});
  }

  void _up(PointerEvent event) {
    if (_pointer != event.pointer) return;
    _pointer = null;
    _thumb = Offset.zero;
    widget.game.setMove(0, 0);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.game.setMove(0, 0);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.settings.controlScale;
    return Opacity(
      opacity: widget.settings.controlOpacity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _ZoneLabel(icon: Icons.open_with, label: 'MOVE / FLICK'),
          const SizedBox(height: 6),
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _down,
            onPointerMove: _move,
            onPointerUp: _up,
            onPointerCancel: _up,
            child: ChamferedActionSurface(
              clipper: const HudChamferClipper(bigCut: 14, smallCut: 5),
              borderColor: Cyber.cyan.withValues(alpha: 0.44),
              child: Container(
                width: 128 * scale,
                height: 128,
                decoration: BoxDecoration(
                  color: Cyber.panel.withValues(alpha: 0.9),
                ),
                child: CustomPaint(painter: _MovementPainter(thumb: _thumb)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementPainter extends CustomPainter {
  const _MovementPainter({required this.thumb});

  final Offset thumb;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final guide = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, 43, guide);
    canvas.drawLine(center.translate(-48, 0), center.translate(48, 0), guide);
    canvas.drawLine(center.translate(0, -48), center.translate(0, 48), guide);
    canvas.drawCircle(
      center + thumb,
      23,
      Paint()
        ..color = thumb == Offset.zero
            ? Cyber.cyan.withValues(alpha: 0.18)
            : Cyber.cyan.withValues(alpha: 0.38),
    );
    canvas.drawCircle(
      center + thumb,
      23,
      Paint()
        ..color = Cyber.cyan.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant _MovementPainter oldDelegate) =>
      oldDelegate.thumb != thumb;
}

class _ShotZone extends StatefulWidget {
  const _ShotZone({required this.game, required this.settings});

  final TennisGame game;
  final TennisSettings settings;

  @override
  State<_ShotZone> createState() => _ShotZoneState();
}

class _ShotZoneState extends State<_ShotZone> {
  int? _pointer;
  Offset _start = Offset.zero;
  Offset _delta = Offset.zero;
  DateTime? _startedAt;

  void _down(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _start = event.localPosition;
    _delta = Offset.zero;
    _startedAt = DateTime.now();
    widget.game.shotStarted();
    if (mounted) setState(() {});
  }

  void _move(PointerMoveEvent event) {
    if (_pointer != event.pointer) return;
    _delta = event.localPosition - _start;
    if (_delta.distance > 74) {
      _delta = Offset.fromDirection(_delta.direction, 74);
    }
    if (mounted) setState(() {});
  }

  void _up(PointerEvent event) {
    if (_pointer != event.pointer) return;
    final held = _startedAt == null
        ? 0.0
        : DateTime.now().difference(_startedAt!).inMilliseconds / 1000;
    widget.game.shotReleased(
      aimX: (_delta.dx / 58).clamp(-1, 1).toDouble(),
      aimY: (-_delta.dy / 58).clamp(-1, 1).toDouble(),
      holdSeconds: held,
    );
    if (widget.settings.haptics) HapticFeedback.selectionClick();
    _pointer = null;
    _delta = Offset.zero;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.settings.controlScale;
    final active = _pointer != null;
    return Opacity(
      opacity: widget.settings.controlOpacity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _ZoneLabel(icon: Icons.sports_tennis, label: 'HIT / SWIPE'),
          const SizedBox(height: 6),
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _down,
            onPointerMove: _move,
            onPointerUp: _up,
            onPointerCancel: _up,
            child: ClipPath(
              clipper: const HudChamferClipper(bigCut: 14, smallCut: 5),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                width: 128 * scale,
                height: 128,
                color: active
                    ? Cyber.lime.withValues(alpha: 0.22)
                    : Cyber.panel.withValues(alpha: 0.9),
                child: CustomPaint(
                  painter: _ShotPainter(delta: _delta, active: active),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShotPainter extends CustomPainter {
  const _ShotPainter({required this.delta, required this.active});

  final Offset delta;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final guide = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Cyber.lime.withValues(alpha: 0.22);
    canvas.drawCircle(center, 42, guide);
    for (var i = 0; i < 4; i++) {
      final angle = -pi / 2 + i * pi / 2;
      canvas.drawLine(
        center + Offset.fromDirection(angle, 28),
        center + Offset.fromDirection(angle, 47),
        guide,
      );
    }
    final thumb = center + delta;
    canvas.drawCircle(
      thumb,
      active ? 24 : 20,
      Paint()..color = Cyber.lime.withValues(alpha: active ? 0.42 : 0.18),
    );
    canvas.drawCircle(
      thumb,
      active ? 24 : 20,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Cyber.lime.withValues(alpha: 0.86),
    );
    final text = TextPainter(
      text: TextSpan(
        text: active ? _gestureLabel(delta) : 'TAP',
        style: Cyber.display(
          9,
          color: Colors.white.withValues(alpha: 0.88),
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, thumb - Offset(text.width / 2, text.height / 2));
  }

  String _gestureLabel(Offset value) {
    if (value.distance < 18) return 'HOLD';
    if (value.dy < -46) return 'LOB';
    if (value.dy < -16) return 'TOP';
    if (value.dy > 46) return 'DROP';
    if (value.dy > 16) return 'SLICE';
    return value.dx < 0 ? 'LEFT' : 'RIGHT';
  }

  @override
  bool shouldRepaint(covariant _ShotPainter oldDelegate) =>
      oldDelegate.delta != delta || oldDelegate.active != active;
}

class _ZoneLabel extends StatelessWidget {
  const _ZoneLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Cyber.muted),
        const SizedBox(width: 5),
        Text(label, style: Cyber.display(9, color: Cyber.muted)),
      ],
    );
  }
}
