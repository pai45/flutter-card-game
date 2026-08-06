import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../shop/widgets/shop_card.dart' show CoinIcon;

/// Full-screen first-run payoff shown after profile setup and before the hub.
/// The backdrop is deliberately deterministic and clean: no grain, noise,
/// scanlines, texture overlay, or background image.
class OnboardingCoinRewardAnimation extends StatefulWidget {
  const OnboardingCoinRewardAnimation({
    required this.amount,
    required this.balanceAfter,
    required this.onComplete,
    super.key,
  });

  final int amount;
  final int balanceAfter;
  final VoidCallback onComplete;

  @override
  State<OnboardingCoinRewardAnimation> createState() =>
      _OnboardingCoinRewardAnimationState();
}

class _OnboardingCoinRewardAnimationState
    extends State<OnboardingCoinRewardAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3300),
  )..addListener(_playTimelineCues);

  Timer? _autoContinueTimer;
  bool _started = false;
  bool _finished = false;
  bool _revealCuePlayed = false;
  bool _creditCuePlayed = false;
  int _lastTickBucket = -1;
  DateTime? _lastTickAt;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _revealCuePlayed = true;
      _creditCuePlayed = true;
      _controller.value = 1;
      playSound(SoundEffect.coins);
      HapticFeedback.mediumImpact();
      _scheduleAutoContinue(const Duration(milliseconds: 1600));
      return;
    }
    playSound(SoundEffect.whoosh);
    _controller.forward().then((_) {
      if (mounted) {
        _scheduleAutoContinue(const Duration(milliseconds: 700));
      }
    });
  }

  void _playTimelineCues() {
    final t = _controller.value;
    if (!_revealCuePlayed && t >= 0.36) {
      _revealCuePlayed = true;
      playSound(SoundEffect.cardReveal);
      HapticFeedback.mediumImpact();
    }
    if (t >= 0.44 && t < 0.75) {
      final count = (_countProgress(t) * widget.amount.abs()).round();
      final bucket = count ~/ math.max(1, widget.amount.abs() ~/ 10);
      final now = DateTime.now();
      final canTick =
          _lastTickAt == null ||
          now.difference(_lastTickAt!) >= const Duration(milliseconds: 75);
      if (bucket != _lastTickBucket && canTick) {
        _lastTickBucket = bucket;
        _lastTickAt = now;
        playSound(SoundEffect.countdownTick);
      }
    }
    if (!_creditCuePlayed && t >= 0.75) {
      _creditCuePlayed = true;
      playSound(SoundEffect.coins);
      HapticFeedback.heavyImpact();
    }
  }

  double _countProgress(double timeline) =>
      Curves.easeOutCubic.transform(_interval(timeline, 0.44, 0.75));

  void _handleTap() {
    if (_finished) return;
    if (_controller.value < 0.78) {
      _autoContinueTimer?.cancel();
      _controller.stop();
      _controller.value = 0.82;
      _scheduleAutoContinue(const Duration(milliseconds: 1400));
      return;
    }
    _finish();
  }

  void _scheduleAutoContinue(Duration delay) {
    _autoContinueTimer?.cancel();
    _autoContinueTimer = Timer(delay, _finish);
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _autoContinueTimer?.cancel();
    widget.onComplete();
  }

  @override
  void dispose() {
    _autoContinueTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: GestureDetector(
        key: const ValueKey('onboarding-reward-tap-target'),
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: Semantics(
          liveRegion: true,
          label:
              '${_formatInt(widget.amount.abs())} coins credited. '
              'Balance ${_formatInt(widget.balanceAfter)} coins.',
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => _RewardScene(
              timeline: _controller.value,
              amount: widget.amount.abs(),
              balanceAfter: widget.balanceAfter,
            ),
          ),
        ),
      ),
    );
  }
}

class _RewardScene extends StatelessWidget {
  const _RewardScene({
    required this.timeline,
    required this.amount,
    required this.balanceAfter,
  });

  final double timeline;
  final int amount;
  final int balanceAfter;

  @override
  Widget build(BuildContext context) {
    final intro = Curves.easeOut.transform(_interval(timeline, 0, 0.18));
    final rise = Curves.easeOutBack.transform(_interval(timeline, 0.04, 0.30));
    final shakeProgress = _interval(timeline, 0.23, 0.38);
    final shake =
        math.sin(shakeProgress * math.pi * 9) * 8 * (1 - shakeProgress);
    final slam = Curves.easeOutBack.transform(_interval(timeline, 0.36, 0.58));
    final revealProgress = _interval(timeline, 0.35, 0.72);
    final countProgress = Curves.easeOutCubic.transform(
      _interval(timeline, 0.44, 0.75),
    );
    final settlement = Curves.easeOutBack.transform(
      _interval(timeline, 0.67, 0.84),
    );
    final flashPhase = _interval(timeline, 0.34, 0.43);
    final flashOpacity = math.sin(flashPhase * math.pi).clamp(0.0, 1.0);
    final displayedAmount = (amount * countProgress).round();

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Cyber.bg),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _CleanRewardBackdropPainter(progress: timeline),
            ),
          ),
        ),
        if (revealProgress > 0 && revealProgress < 1)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _RewardBurstPainter(progress: revealProgress),
              ),
            ),
          ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 680;
              final tightRewardLine = compact || constraints.maxWidth < 420;
              final maxArt = compact ? 184.0 : 232.0;
              final artSize = math.min(
                maxArt,
                math.min(
                  constraints.maxWidth * 0.58,
                  constraints.maxHeight * 0.34,
                ),
              );
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    SizedBox(height: compact ? 20 : 40),
                    Opacity(
                      opacity: intro.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, 12 * (1 - intro)),
                        child: Column(
                          children: [
                            Text(
                              'WELCOME BONUS',
                              style: Cyber.label(
                                12,
                                color: Cyber.cyan,
                                letterSpacing: 4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'SYS://WALLET LINKED',
                              style: Cyber.label(
                                9,
                                color: Cyber.muted,
                                letterSpacing: 2.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Transform.translate(
                      offset: Offset(shake, (1 - rise) * 110),
                      child: Transform.scale(
                        scale: timeline < 0.36
                            ? 0.66 + 0.34 * rise
                            : 0.72 + 0.28 * slam,
                        child: Opacity(
                          opacity: rise.clamp(0.0, 1.0),
                          child: _RewardPackArt(size: artSize),
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 16 : 24),
                    Opacity(
                      opacity: _interval(timeline, 0.42, 0.57),
                      child: Transform.translate(
                        offset: Offset(0, 16 * (1 - settlement)),
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CoinIcon(size: tightRewardLine ? 34 : 42),
                                    const SizedBox(width: 12),
                                    Text(
                                      '+${_formatInt(displayedAmount)}',
                                      key: const ValueKey(
                                        'onboarding-reward-amount',
                                      ),
                                      style:
                                          Cyber.display(
                                            tightRewardLine ? 38 : 48,
                                            color: Cyber.gold,
                                            letterSpacing: 1.2,
                                          ).copyWith(
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Opacity(
                              opacity: settlement.clamp(0.0, 1.0),
                              child: Transform.scale(
                                scale: 0.9 + 0.1 * settlement,
                                child: Text(
                                  'COINS CREDITED TO WALLET',
                                  key: const ValueKey(
                                    'onboarding-reward-credited',
                                  ),
                                  style: Cyber.label(
                                    11,
                                    color: AppTheme.whiteColor,
                                    letterSpacing: 2.8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 16 : 24),
                    Opacity(
                      opacity: settlement.clamp(0.0, 1.0),
                      child: _BalancePlate(balance: balanceAfter),
                    ),
                    const Spacer(),
                    Opacity(
                      opacity: _interval(timeline, 0.76, 0.90),
                      child: Text(
                        'TAP TO CONTINUE',
                        style: Cyber.label(
                          10,
                          color: Cyber.muted,
                          letterSpacing: 2.4,
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 20 : 32),
                  ],
                ),
              );
            },
          ),
        ),
        if (flashOpacity > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: Cyber.gold.withValues(alpha: flashOpacity * 0.68),
              ),
            ),
          ),
      ],
    );
  }
}

class _RewardPackArt extends StatelessWidget {
  const _RewardPackArt({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        boxShadow: Cyber.glow(Cyber.gold, alpha: 0.46, blur: 34, spread: 2),
      ),
      child: CustomPaint(
        foregroundPainter: const _RewardFramePainter(),
        child: ClipPath(
          clipper: CyberClipper(),
          child: Image.asset(
            'assets/coins/rookie.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const ColoredBox(
              color: Cyber.panel,
              child: Center(child: CoinIcon(size: 72)),
            ),
          ),
        ),
      ),
    );
  }
}

class _BalancePlate extends StatelessWidget {
  const _BalancePlate({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: const _CalmPlatePainter(),
      child: ClipPath(
        clipper: CyberClipper(),
        child: ColoredBox(
          color: Cyber.panel,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'WALLET BALANCE',
                  style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.8),
                ),
                const SizedBox(width: 16),
                const CoinIcon(size: 18),
                const SizedBox(width: 6),
                Text(
                  _formatInt(balance),
                  key: const ValueKey('onboarding-reward-balance'),
                  style:
                      Cyber.display(
                        16,
                        color: AppTheme.whiteColor,
                        letterSpacing: 0.8,
                      ).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RewardFramePainter extends CustomPainter {
  const _RewardFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      CyberClipper.buildPath(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = Cyber.gold.withValues(alpha: 0.86),
    );
  }

  @override
  bool shouldRepaint(covariant _RewardFramePainter oldDelegate) => false;
}

class _CalmPlatePainter extends CustomPainter {
  const _CalmPlatePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      CyberClipper.buildPath(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Cyber.line,
    );
  }

  @override
  bool shouldRepaint(covariant _CalmPlatePainter oldDelegate) => false;
}

class _CleanRewardBackdropPainter extends CustomPainter {
  const _CleanRewardBackdropPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.43);
    final radius = size.shortestSide * 0.74;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Cyber.gold.withValues(alpha: 0.09 + progress * 0.05),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    final rayPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Cyber.gold.withValues(alpha: 0.08);
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      final inner = radius * 0.48;
      final outer = radius * (0.82 + (i.isEven ? 0.12 : 0));
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * inner,
        center + Offset(math.cos(angle), math.sin(angle)) * outer,
        rayPaint,
      );
    }
    canvas.drawCircle(center, radius * 0.56, rayPaint);
    canvas.drawCircle(
      center,
      radius * 0.78,
      rayPaint..color = Cyber.cyan.withValues(alpha: 0.05),
    );
  }

  @override
  bool shouldRepaint(_CleanRewardBackdropPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _RewardBurstPainter extends CustomPainter {
  const _RewardBurstPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.43);
    final eased = Curves.easeOut.transform(progress);
    final fade = (1 - progress).clamp(0.0, 1.0);
    final maxRadius = size.shortestSide * 0.58;

    for (final delay in const [0.0, 0.18]) {
      final wave = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (wave <= 0 || wave >= 1) continue;
      canvas.drawCircle(
        center,
        maxRadius * Curves.easeOut.transform(wave),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 * (1 - wave) + 0.6
          ..color = Cyber.gold.withValues(alpha: (1 - wave) * 0.58),
      );
    }

    for (var i = 0; i < 24; i++) {
      final angle = i * (math.pi * 2 / 24) + (i.isOdd ? 0.07 : 0);
      final reach = maxRadius * (i.isEven ? 0.92 : 0.72);
      final point =
          center + Offset(math.cos(angle), math.sin(angle)) * (eased * reach);
      final coinRadius = 2.5 + (i % 3) * 0.7;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Cyber.gold.withValues(alpha: fade * 0.9);
      canvas.drawCircle(point, coinRadius, paint);
      canvas.drawLine(
        point - Offset(coinRadius * 0.45, 0),
        point + Offset(coinRadius * 0.45, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RewardBurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

double _interval(double value, double begin, double end) =>
    ((value - begin) / (end - begin)).clamp(0.0, 1.0);

String _formatInt(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final fromEnd = raw.length - i;
    buffer.write(raw[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}
