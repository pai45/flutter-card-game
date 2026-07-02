import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart';
import '../../utils/sound_effects.dart';

class CyberTossCoin extends StatefulWidget {
  const CyberTossCoin({
    super.key,
    required this.result,
    required this.won,
    this.onLanded,
  });

  /// 'heads', 'tails', or null if idle
  final String? result;
  
  /// Determines if it glows cyan (true) or danger/red (false) upon landing.
  final bool? won;
  
  final VoidCallback? onLanded;

  @override
  State<CyberTossCoin> createState() => _CyberTossCoinState();
}

class _CyberTossCoinState extends State<CyberTossCoin> with TickerProviderStateMixin {
  static const double _coinSize = 122;

  // Idle motion.
  late final AnimationController _float;
  late final AnimationController _ring;
  late final Animation<double> _floatAnim;
  late final Animation<double> _ringAnim;

  // Flip + landing burst.
  late final AnimationController _flip;
  late final AnimationController _glow;
  late final Animation<double> _angle;
  late final Animation<double> _settle;
  late final Animation<double> _glowPulse;

  bool _flipStarted = false;
  bool _showFlash = false;
  // True once the flip has settled — gates the win/lose colour reveal.
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _floatAnim = Tween<double>(
      begin: -4,
      end: 4,
    ).animate(CurvedAnimation(parent: _float, curve: Curves.easeInOut));
    _ring = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 20000),
    );
    _ringAnim = Tween<double>(begin: 0, end: 2 * pi).animate(_ring);

    _flip = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _angle = Tween<double>(
      begin: 0,
      end: pi * 6,
    ).animate(CurvedAnimation(parent: _flip, curve: Curves.easeOut));
    _settle = Tween<double>(begin: 0.70, end: 1.0).animate(
      CurvedAnimation(
        parent: _flip,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOutBack),
      ),
    );
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _glowPulse = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _glow, curve: Curves.easeOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.result != null) {
      _startFlip();
      return;
    }
    if (!MediaQuery.of(context).disableAnimations) {
      if (!_float.isAnimating) _float.repeat(reverse: true);
      if (!_ring.isAnimating) _ring.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant CyberTossCoin old) {
    super.didUpdateWidget(old);
    if (old.result == null && widget.result != null) _startFlip();
  }

  void _startFlip() {
    if (_flipStarted) return;
    _flipStarted = true;
    _float.stop();
    _ring.stop();

    if (MediaQuery.of(context).disableAnimations) {
      _flip.value = 1;
      _glow.value = 1;
      _revealed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onLanded?.call();
      });
      return;
    }

    playSound(SoundEffect.coinFlip);
    _flip.forward().then((_) {
      if (!mounted) return;
      playSound(SoundEffect.coinLand);
      HapticFeedback.lightImpact();
      setState(() {
        _showFlash = true;
        _revealed = true;
      });
      _glow.forward();
      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted) setState(() => _showFlash = false);
      });
      widget.onLanded?.call();
    });
  }

  @override
  void dispose() {
    _float.dispose();
    _ring.dispose();
    _flip.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flipping = widget.result != null;
    // Neutral cyan until the coin settles; only then the outcome accent shows
    // (cyan = player won the call, red = CPU).
    final faceColor = _revealed && widget.won == false ? Cyber.danger : Cyber.cyan;
    return AnimatedBuilder(
      animation: Listenable.merge([_float, _ring, _flip, _glow]),
      builder: (context, _) {
        final ringOpacity = flipping ? (1 - _flip.value).clamp(0.0, 1.0) : 1.0;
        return SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Soft radial background glow.
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      faceColor.withValues(alpha: 0.10),
                      faceColor.withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.5, 1],
                  ),
                ),
              ),
              // Radar rings — fade out as the flip takes over.
              if (ringOpacity > 0) ...[
                Opacity(
                  opacity: ringOpacity,
                  child: Transform.rotate(
                    angle: _ringAnim.value,
                    child: const CustomPaint(
                      size: Size(220, 220),
                      painter: _RadarRingPainter(outer: true),
                    ),
                  ),
                ),
                Opacity(
                  opacity: ringOpacity,
                  child: Transform.rotate(
                    angle: -_ringAnim.value * 0.5,
                    child: const CustomPaint(
                      size: Size(168, 168),
                      painter: _RadarRingPainter(outer: false),
                    ),
                  ),
                ),
              ],
              if (_showFlash)
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
              flipping ? _buildFlipCoin(faceColor) : _buildIdleCoin(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIdleCoin() {
    return Transform.translate(
      offset: Offset(0, _floatAnim.value),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _coinSize,
            height: _coinSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [const Color(0xff1a3040), Cyber.bg],
              ),
              border: Border.all(color: Cyber.cyan, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Cyber.cyan.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Cyber.cyan.withValues(alpha: 0.12),
                  blurRadius: 6,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: const CustomPaint(painter: _CoinFacePainter()),
          ),
          Container(
            width: 2,
            height: 14,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Cyber.cyan.withValues(alpha: 0.55),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Container(
            width: 72,
            height: 8,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Cyber.cyan.withValues(alpha: 0.28),
                  Cyber.cyan.withValues(alpha: 0.10),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlipCoin(Color faceColor) {
    // While spinning, the visible face alternates every half-turn so the
    // outcome stays hidden; _angle ends on a whole number of turns, so the
    // coin settles showing the front face — which carries the actual result.
    final frontVisible = (((_angle.value + pi / 2) / pi).floor() % 2) == 0;
    final headsUp = frontVisible == (widget.result == 'heads');
    final glowBlur = 24.0 + _glowPulse.value * 40.0;
    final glowAlpha = 0.35 + _glowPulse.value * 0.45;
    return Transform.scale(
      scale: _settle.value.clamp(0.0, 1.10),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(_angle.value),
        child: Container(
          width: _coinSize,
          height: _coinSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [const Color(0xff1a3545), Cyber.bg],
            ),
            border: Border.all(color: faceColor, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: faceColor.withValues(alpha: glowAlpha),
                blurRadius: glowBlur,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            // The back face renders mirrored under the coin's Y-rotation;
            // counter-rotate it so the letter always reads the right way.
            child: Transform(
              alignment: Alignment.center,
              transform: frontVisible
                  ? Matrix4.identity()
                  : (Matrix4.identity()..rotateY(pi)),
              child: Text(
                headsUp ? 'H' : 'T',
                style: Cyber.display(50, color: faceColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoinFacePainter extends CustomPainter {
  const _CoinFacePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(center, size.width * 0.42, paint);
    canvas.drawCircle(center, size.width * 0.35, paint);

    paint.color = Cyber.cyan.withValues(alpha: 0.3);
    for (int i = 0; i < 12; i++) {
      final angle = i * (pi / 6);
      final r1 = size.width * 0.44;
      final r2 = size.width * 0.48;
      canvas.drawLine(
        Offset(center.dx + r1 * cos(angle), center.dy + r1 * sin(angle)),
        Offset(center.dx + r2 * cos(angle), center.dy + r2 * sin(angle)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _RadarRingPainter extends CustomPainter {
  const _RadarRingPainter({required this.outer});
  final bool outer;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final paint = Paint()
      ..color = Cyber.cyan.withValues(alpha: outer ? 0.20 : 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = outer ? 1.5 : 1.0;

    canvas.drawCircle(center, radius, paint);

    final dashCount = outer ? 3 : 4;
    final dashSweep = outer ? 0.3 : 0.6;
    paint.color = Cyber.cyan.withValues(alpha: outer ? 0.6 : 0.4);
    paint.strokeWidth = outer ? 3 : 2;
    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * (2 * pi / dashCount);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashSweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class CyberCallChoiceButton extends StatefulWidget {
  const CyberCallChoiceButton({
    super.key,
    required this.face,
    required this.label,
    required this.accent,
    required this.onTap,
  });
  final String face;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<CyberCallChoiceButton> createState() => _CyberCallChoiceButtonState();
}

class _CyberCallChoiceButtonState extends State<CyberCallChoiceButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _press, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _onTap() {
    _press.forward().then((_) {
      _press.reverse();
      widget.onTap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return AnimatedBuilder(
      animation: _press,
      builder: (_, _) => Transform.scale(
        scale: _scale.value,
        child: GestureDetector(
          onTap: _onTap,
          child: Container(
            height: 96,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              border: Border.all(
                color: accent.withValues(alpha: 0.55),
                width: 1.4,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accent.withValues(alpha: 0.7),
                      width: 1.4,
                    ),
                  ),
                  child: Text(
                    widget.face,
                    style: Cyber.display(15, color: accent),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.label,
                  style: Cyber.display(17, color: accent, letterSpacing: 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
