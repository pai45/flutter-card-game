import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/achievement.dart';
import '../screens/profile/widgets/achievement_badge.dart';
import '../utils/label_helpers.dart';
import '../utils/sound_effects.dart';
import 'cyber/cyber_widgets.dart';

/// Full-screen "ACHIEVEMENT UNLOCKED" moment for a single badge. Modeled on
/// [LevelUpCelebration]: chained controllers drive a vignette, a tier-coloured
/// particle burst, an easeOutBack badge slam (with a settle shake) and a banner
/// that carries the title, description and tier chip. Glow is intentional here —
/// this is a reward "moment", which the glow rule allows.
///
/// Shows one achievement and calls [onDismissed] when it finishes (tap or
/// auto-advance); the host drives the queue one badge at a time.
class AchievementUnlockCelebration extends StatefulWidget {
  const AchievementUnlockCelebration({
    required this.achievement,
    required this.onDismissed,
    super.key,
  });

  final Achievement achievement;
  final VoidCallback onDismissed;

  @override
  State<AchievementUnlockCelebration> createState() =>
      _AchievementUnlockCelebrationState();
}

class _AchievementUnlockCelebrationState
    extends State<AchievementUnlockCelebration>
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
    duration: const Duration(milliseconds: 420),
  );

  late final AnimationController _shakeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  late final Animation<double> _badgeScale = Tween<double>(
    begin: 0,
    end: 1,
  ).animate(CurvedAnimation(parent: _badgeCtrl, curve: Curves.easeOutBack));

  late final Animation<Offset> _bannerSlide = Tween<Offset>(
    begin: const Offset(0, 0.12),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _bannerCtrl, curve: Curves.easeOutCubic));

  late final Animation<double> _bannerOpacity = CurvedAnimation(
    parent: _bannerCtrl,
    curve: Curves.easeOut,
  );

  Timer? _dismissTimer;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    playSound(SoundEffect.achievement);
    HapticFeedback.heavyImpact();
    _vignetteCtrl.forward();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _particleCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _badgeCtrl.forward();
    });
    _badgeCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) _shakeCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 320), () {
      if (mounted) _bannerCtrl.forward();
    });
    _dismissTimer = Timer(const Duration(milliseconds: 3000), _dismiss);
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _dismissTimer?.cancel();
    widget.onDismissed();
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
    final achievement = widget.achievement;
    final tier = tierColor(achievement.tier);

    return GestureDetector(
      onTap: _dismiss,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _vignetteCtrl,
              builder: (context, _) => ColoredBox(
                color: Colors.black.withValues(
                  alpha: _vignetteCtrl.value * 0.82,
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _particleCtrl,
              builder: (context, _) => Center(
                child: CustomPaint(
                  size: const Size(320, 320),
                  painter: _BadgeBurstPainter(
                    progress: _particleCtrl.value,
                    accent: tier,
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: Listenable.merge([
                _badgeCtrl,
                _bannerCtrl,
                _shakeCtrl,
              ]),
              builder: (context, _) {
                final shakeOffset =
                    math.sin(_shakeCtrl.value * math.pi * 6) *
                    7 *
                    (1 - _shakeCtrl.value);
                return Transform.translate(
                  offset: Offset(shakeOffset, 0),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Opacity(
                          opacity: _badgeCtrl.value.clamp(0.0, 1.0),
                          child: Text(
                            'ACHIEVEMENT UNLOCKED',
                            style:
                                Cyber.label(
                                  13,
                                  color: tier,
                                  letterSpacing: 3.4,
                                ).copyWith(
                                  shadows: [
                                    Shadow(
                                      color: tier.withValues(alpha: 0.65),
                                      blurRadius: 16,
                                    ),
                                  ],
                                ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Transform.scale(
                          scale: _badgeScale.value,
                          child: Container(
                            decoration: BoxDecoration(
                              boxShadow: Cyber.glow(tier, alpha: 0.6, blur: 34),
                            ),
                            child: AchievementBadgePlate(
                              icon: achievement.icon,
                              tier: tier,
                              unlocked: true,
                              size: 104,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SlideTransition(
                          position: _bannerSlide,
                          child: FadeTransition(
                            opacity: _bannerOpacity,
                            child: Column(
                              children: [
                                Text(
                                  achievement.title.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style:
                                      Cyber.display(
                                        32,
                                        color: Colors.white,
                                        letterSpacing: 1.5,
                                      ).copyWith(
                                        shadows: [
                                          Shadow(
                                            color: tier.withValues(alpha: 0.55),
                                            blurRadius: 18,
                                          ),
                                        ],
                                      ),
                                ),
                                const SizedBox(height: 10),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 300,
                                  ),
                                  child: Text(
                                    achievement.description,
                                    textAlign: TextAlign.center,
                                    style: Cyber.body(14, color: Cyber.muted),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                CyberChip(
                                  label: achievement.tier.name.toUpperCase(),
                                  color: tier,
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
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _bannerCtrl,
                builder: (context, _) => Opacity(
                  opacity: (_bannerCtrl.value - 0.5).clamp(0.0, 1.0),
                  child: Center(
                    child: Text(
                      'TAP TO CONTINUE',
                      style: Cyber.label(
                        11,
                        color: Cyber.muted,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Radial particle burst behind the badge — dots fly out and fade as the badge
/// lands. Tinted by the achievement tier so each grade reads differently.
class _BadgeBurstPainter extends CustomPainter {
  _BadgeBurstPainter({required this.progress, required this.accent});

  final double progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    const particleCount = 28;
    final maxRadius = size.width * 0.46;
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = accent.withValues(alpha: (1 - progress) * 0.9)
      ..style = PaintingStyle.fill;

    for (var i = 0; i < particleCount; i++) {
      final angle = i * (2 * math.pi / particleCount);
      // Alternate ring distance so the burst feels less mechanical.
      final reach = i.isEven ? maxRadius : maxRadius * 0.78;
      final distance = Curves.easeOut.transform(progress) * reach;
      final offset = Offset(
        center.dx + distance * math.cos(angle),
        center.dy + distance * math.sin(angle),
      );
      final dotSize = 3.5 + (1 - progress) * 3;
      canvas.drawCircle(offset, dotSize, paint);
    }
  }

  @override
  bool shouldRepaint(_BadgeBurstPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.accent != accent;
}
