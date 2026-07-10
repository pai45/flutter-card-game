import 'package:flutter/material.dart';

import '../../../blocs/super_over/super_over_state.dart';
import '../../../config/theme.dart';
import '../../../models/super_over.dart';

/// Full-screen effects overlay layered between GameWidget and HUD.
/// Handles: screen flash on shots, ON FIRE vignette, combo counter.
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
        _flashColor = switch (lastOutcome) {
          ShotOutcome.six => Cyber.gold,
          ShotOutcome.four => Cyber.lime,
          ShotOutcome.caught || ShotOutcome.bowled => Cyber.danger,
          _ => Colors.white,
        };
        _flashController.forward(from: 0);
      }
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
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── ON FIRE vignette ──
          if (widget.state.onFire)
            AnimatedBuilder(
              animation: _vignetteController,
              builder: (context, _) {
                final t = _vignetteController.value;
                return CustomPaint(
                  painter: _VignettePainter(
                    color: Cyber.amber,
                    intensity: 0.25 + t * 0.15,
                  ),
                );
              },
            ),

          // ── Screen flash ──
          AnimatedBuilder(
            animation: _flashController,
            builder: (context, _) {
              final opacity = (1.0 - _flashController.value) * 0.35;
              if (opacity <= 0.01) return const SizedBox.shrink();
              return Container(color: _flashColor.withValues(alpha: opacity));
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
      duration: const Duration(milliseconds: 350),
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
          borderRadius: BorderRadius.circular(4),
          boxShadow: Cyber.glow(
            combo >= 4 ? Cyber.gold : Cyber.cyan,
            alpha: 0.4,
            blur: 12,
          ),
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
