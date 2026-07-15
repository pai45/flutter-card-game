import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../blocs/super_over/super_over_state.dart';
import '../../../config/theme.dart';
import '../../../models/super_over.dart';

/// Restrained contact effects layered between the Flame scene and HUD.
class EffectsOverlay extends StatefulWidget {
  const EffectsOverlay({required this.state, super.key});

  final SuperOverState state;

  @override
  State<EffectsOverlay> createState() => _EffectsOverlayState();
}

class _EffectsOverlayState extends State<EffectsOverlay>
    with TickerProviderStateMixin {
  late AnimationController _flashController;
  late AnimationController _vignetteController;
  Color _flashColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      value: 1.0,
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _vignetteController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(EffectsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.state.lastOutcome != widget.state.lastOutcome &&
        widget.state.lastOutcome != null) {
      final lastOutcome = widget.state.lastOutcome;
      if (lastOutcome != null) {
        _flashColor = switch (widget.state.timingTier) {
          TimingTier.perfect => Cyber.cyan,
          TimingTier.great => Cyber.lime,
          TimingTier.good => Colors.white,
          TimingTier.edgePoor => Cyber.amber,
          TimingTier.miss || null =>
            lastOutcome == ShotOutcome.bowled ? Cyber.danger : Cyber.muted,
        };
        if (!widget.state.settings.reducedMotion &&
            !MediaQuery.disableAnimationsOf(context)) {
          _flashController.forward(from: 0);
        } else {
          _flashController.value = 1;
        }
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _vignetteController
        ..stop()
        ..value = .5;
      _flashController.value = 1;
    } else if (!_vignetteController.isAnimating) {
      _vignetteController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _flashController.dispose();
    _vignetteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion =
        widget.state.settings.reducedMotion ||
        MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── ON FIRE vignette ──
          if (widget.state.onFire)
            if (reducedMotion)
              CustomPaint(
                painter: _VignettePainter(color: Cyber.cyan, intensity: .12),
              )
            else
              AnimatedBuilder(
                animation: _vignetteController,
                builder: (context, _) {
                  final t = _vignetteController.value;
                  return CustomPaint(
                    painter: _VignettePainter(
                      color: Cyber.cyan,
                      intensity: 0.14 + t * 0.08,
                    ),
                  );
                },
              ),

          // ── Screen flash ──
          AnimatedBuilder(
            animation: _flashController,
            builder: (context, _) {
              final opacity = (1.0 - _flashController.value) * 0.46;
              if (opacity <= 0.01) return const SizedBox.shrink();
              return CustomPaint(
                painter: _ContactBurstPainter(
                  color: _flashColor,
                  progress: _flashController.value,
                  opacity: opacity,
                ),
              );
            },
          ),

          // ── Combo counter ──
          if (widget.state.combo >= 2)
            Positioned(
              top: 116,
              right: 16,
              child: _ComboCounter(combo: widget.state.combo),
            ),
        ],
      ),
    );
  }
}

class _ContactBurstPainter extends CustomPainter {
  const _ContactBurstPainter({
    required this.color,
    required this.progress,
    required this.opacity,
  });

  final Color color;
  final double progress;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width * .5, size.height * .69);
    final radius = 14 + progress * 42;
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * (1 - progress).clamp(.25, 1)
        ..color = color.withValues(alpha: opacity * .72),
    );
    for (var i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      final innerRadius = 10 + progress * 14;
      final inner = Offset(
        centre.dx + math.sin(angle) * innerRadius,
        centre.dy + math.cos(angle) * innerRadius,
      );
      final outer = Offset(
        centre.dx + math.sin(angle) * radius,
        centre.dy + math.cos(angle) * radius,
      );
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..strokeWidth = 1.2
          ..color = color.withValues(alpha: opacity * .55),
      );
    }
  }

  @override
  bool shouldRepaint(_ContactBurstPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.opacity != opacity ||
      oldDelegate.color != color;
}

class _VignettePainter extends CustomPainter {
  _VignettePainter({required this.color, required this.intensity});

  final Color color;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 0.85,
      colors: [
        Colors.transparent,
        color.withValues(alpha: intensity * 0.5),
        color.withValues(alpha: intensity),
      ],
      stops: const [0.4, 0.75, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }

  @override
  bool shouldRepaint(_VignettePainter oldDelegate) =>
      oldDelegate.intensity != intensity || oldDelegate.color != color;
}

class _ComboCounter extends StatelessWidget {
  const _ComboCounter({required this.combo});

  final int combo;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(combo),
      tween: Tween(begin: 1.4, end: 1.0),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 350),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Cyber.bg.withValues(alpha: 0.7),
          border: Border.all(
            color: combo >= 4 ? Cyber.gold : Cyber.cyan,
            width: 1.5,
          ),
          borderRadius: BorderRadius.zero,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${combo}x',
              style: Cyber.display(
                combo >= 4 ? 22 : 18,
                color: combo >= 4 ? Cyber.gold : Cyber.cyan,
              ),
            ),
            Text(
              'COMBO',
              style: Cyber.label(9, color: Cyber.muted, letterSpacing: 2),
            ),
          ],
        ),
      ),
    );
  }
}
