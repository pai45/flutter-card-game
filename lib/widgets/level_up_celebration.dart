import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../utils/sound_effects.dart';

class LevelUpCelebration extends StatefulWidget {
  const LevelUpCelebration({
    required this.levels,
    required this.onDismissed,
    super.key,
  });

  final List<int> levels;
  final VoidCallback onDismissed;

  @override
  State<LevelUpCelebration> createState() => _LevelUpCelebrationState();
}

class _LevelUpCelebrationState extends State<LevelUpCelebration>
    with TickerProviderStateMixin {
  late final AnimationController _vignetteCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  late final AnimationController _particleCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  late final AnimationController _badgeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  late final AnimationController _bannerCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  late final AnimationController _shakeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  late final Animation<double> _badgeScale = Tween<double>(begin: 0, end: 1).animate(
    CurvedAnimation(parent: _badgeCtrl, curve: Curves.easeOutBack),
  );

  late final Animation<Offset> _bannerSlide = Tween<Offset>(
    begin: const Offset(0, 0.1),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _bannerCtrl, curve: Curves.easeOutCubic));

  late final Animation<double> _bannerOpacity = CurvedAnimation(
    parent: _bannerCtrl,
    curve: Curves.easeOut,
  );

  int _currentIndex = 0;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  void _startAnimation() {
    playSound(SoundEffect.levelUp);
    _vignetteCtrl.forward();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _particleCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _badgeCtrl.forward();
    });
    _badgeCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _shakeCtrl.forward();
      }
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _bannerCtrl.forward();
    });
    _dismissTimer = Timer(const Duration(milliseconds: 2500), _next);
  }

  void _next() {
    _dismissTimer?.cancel();
    if (_currentIndex < widget.levels.length - 1) {
      _currentIndex++;
      // Reset and replay all animations for next level
      _vignetteCtrl.reset();
      _particleCtrl.reset();
      _badgeCtrl.reset();
      _bannerCtrl.reset();
      _shakeCtrl.reset();
      _startAnimation();
    } else {
      widget.onDismissed();
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _vignetteCtrl.dispose();
    _particleCtrl.dispose();
    _badgeCtrl.dispose();
    _bannerCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = widget.levels[_currentIndex];

    return GestureDetector(
      onTap: _next,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Vignette
            AnimatedBuilder(
              animation: _vignetteCtrl,
              builder: (context, child) => Container(
                color: Colors.black.withValues(
                  alpha: _vignetteCtrl.value * 0.78,
                ),
              ),
            ),
            // Particle burst
            AnimatedBuilder(
              animation: _particleCtrl,
              builder: (context, child) => Center(
                child: CustomPaint(
                  size: const Size(300, 300),
                  painter: _ParticleBurstPainter(
                    progress: _particleCtrl.value,
                    accent: Cyber.cyan,
                  ),
                ),
              ),
            ),
            // Badge and text
            AnimatedBuilder(
              animation: Listenable.merge([_badgeCtrl, _bannerCtrl, _shakeCtrl]),
              builder: (context, child) {
                final shakeOffset = math.sin(_shakeCtrl.value * math.pi * 6) *
                    8 *
                    (1 - _shakeCtrl.value);
                return Transform.translate(
                  offset: Offset(shakeOffset, 0),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Badge
                        Transform.scale(
                          scale: _badgeScale.value,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Cyber.panel,
                              border: Border.all(color: Cyber.cyan, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Cyber.cyan.withValues(alpha: 0.6),
                                  blurRadius: 20,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Text(
                              'LEVEL $level',
                              style: const TextStyle(
                                fontFamily: 'Orbitron',
                                fontSize: 64,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFFD166),
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // "LEVEL UP!" banner
                        SlideTransition(
                          position: _bannerSlide,
                          child: FadeTransition(
                            opacity: _bannerOpacity,
                            child: Column(
                              children: [
                                const Text(
                                  'LEVEL UP!',
                                  style: TextStyle(
                                    fontFamily: 'Orbitron',
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF5CDFFF),
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'New rank unlocked',
                                  style: TextStyle(
                                    fontFamily: 'Onest',
                                    fontSize: 16,
                                    color: Cyber.muted,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            // Tap to continue (appears after 1s)
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _bannerCtrl,
                builder: (context, child) {
                  final opacity = (_bannerCtrl.value - 0.5).clamp(0.0, 1.0);
                  return Opacity(
                    opacity: opacity,
                    child: Center(
                      child: Text(
                        'TAP TO CONTINUE',
                        style: TextStyle(
                          fontFamily: 'Orbitron',
                          fontSize: 12,
                          color: Cyber.muted,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticleBurstPainter extends CustomPainter {
  _ParticleBurstPainter({
    required this.progress,
    required this.accent,
  });

  final double progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    const particleCount = 24;
    const maxRadius = 140.0;

    final paint = Paint()
      ..color = accent.withValues(alpha: (1 - progress) * 0.9)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < particleCount; i++) {
      final angle = (i * (2 * math.pi / particleCount));
      final distance = progress * maxRadius;
      final offset = Offset(
        center.dx + distance * math.cos(angle),
        center.dy + distance * math.sin(angle),
      );
      final dotSize = 4 + (1 - progress) * 3;
      canvas.drawCircle(offset, dotSize, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticleBurstPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
