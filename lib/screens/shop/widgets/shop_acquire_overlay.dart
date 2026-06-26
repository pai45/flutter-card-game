import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../utils/sound_effects.dart';
import 'shop_card.dart';

/// The single "ACQUIRED" moment every coin purchase shares — avatar, border,
/// banner, card and pack-with-coins all play this so a buy always pays the
/// player back the same way. Modeled on the achievement-unlock reveal: a
/// vignette, an accent-tinted particle burst, the item's OWN preview slamming in
/// (easeOutBack + settle shake) and a banner that carries the name and the
/// coin-spend tick. Glow is intentional — this is a reward moment.
///
/// Hosted in the shop screen's Stack; calls [onDismissed] on tap or auto-advance.
class ShopAcquireOverlay extends StatefulWidget {
  const ShopAcquireOverlay({
    required this.preview,
    required this.name,
    required this.accent,
    required this.coinsSpent,
    required this.onDismissed,
    super.key,
  });

  /// The item's own preview (portrait, border ring, banner swatch, coin stack,
  /// pack art, player card) — what makes the moment denote *this* item.
  final Widget preview;
  final String name;
  final Color accent;
  final int coinsSpent;
  final VoidCallback onDismissed;

  @override
  State<ShopAcquireOverlay> createState() => _ShopAcquireOverlayState();
}

class _ShopAcquireOverlayState extends State<ShopAcquireOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _vignetteCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final AnimationController _particleCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final AnimationController _itemCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  late final AnimationController _bannerCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final AnimationController _shakeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  late final Animation<double> _itemScale = Tween<double>(begin: 0, end: 1)
      .animate(CurvedAnimation(parent: _itemCtrl, curve: Curves.easeOutBack));
  late final Animation<Offset> _bannerSlide = Tween<Offset>(
    begin: const Offset(0, 0.12),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _bannerCtrl, curve: Curves.easeOutCubic));
  late final Animation<double> _bannerOpacity =
      CurvedAnimation(parent: _bannerCtrl, curve: Curves.easeOut);

  Timer? _dismissTimer;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    playSound(SoundEffect.coins);
    HapticFeedback.heavyImpact();
    _vignetteCtrl.forward();
    Future.delayed(const Duration(milliseconds: 90), () {
      if (mounted) _particleCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 130), () {
      if (mounted) _itemCtrl.forward();
    });
    _itemCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) _shakeCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _bannerCtrl.forward();
    });
    _dismissTimer = Timer(const Duration(milliseconds: 2200), _dismiss);
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
    _itemCtrl.dispose();
    _bannerCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
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
                color: Colors.black.withValues(alpha: _vignetteCtrl.value * 0.84),
              ),
            ),
            AnimatedBuilder(
              animation: _particleCtrl,
              builder: (context, _) => Center(
                child: CustomPaint(
                  size: const Size(320, 320),
                  painter: _AcquireBurstPainter(
                    progress: _particleCtrl.value,
                    accent: accent,
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: Listenable.merge([_itemCtrl, _bannerCtrl, _shakeCtrl]),
              builder: (context, _) {
                final shakeOffset = math.sin(_shakeCtrl.value * math.pi * 6) *
                    7 *
                    (1 - _shakeCtrl.value);
                return Transform.translate(
                  offset: Offset(shakeOffset, 0),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Opacity(
                          opacity: _itemCtrl.value.clamp(0.0, 1.0),
                          child: Text(
                            'ACQUIRED',
                            style: Cyber.label(13, color: accent, letterSpacing: 4.2)
                                .copyWith(
                              shadows: [
                                Shadow(
                                  color: accent.withValues(alpha: 0.65),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Transform.scale(
                          scale: _itemScale.value.clamp(0.0, 1.4),
                          child: Container(
                            decoration: BoxDecoration(
                              boxShadow: Cyber.glow(accent, alpha: 0.5, blur: 36),
                            ),
                            child: widget.preview,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SlideTransition(
                          position: _bannerSlide,
                          child: FadeTransition(
                            opacity: _bannerOpacity,
                            child: Column(
                              children: [
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 300),
                                  child: Text(
                                    widget.name.toUpperCase(),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Cyber.display(
                                      26,
                                      color: Colors.white,
                                      letterSpacing: 1.4,
                                    ).copyWith(
                                      shadows: [
                                        Shadow(
                                          color: accent.withValues(alpha: 0.55),
                                          blurRadius: 18,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (widget.coinsSpent > 0) ...[
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CoinIcon(size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        '−${_formatInt(widget.coinsSpent)}',
                                        style: Cyber.display(
                                          18,
                                          color: Cyber.muted,
                                        ).copyWith(
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
                      style: Cyber.label(11, color: Cyber.muted, letterSpacing: 2),
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

/// Radial particle burst behind the item, tinted by the item's accent.
class _AcquireBurstPainter extends CustomPainter {
  _AcquireBurstPainter({required this.progress, required this.accent});

  final double progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    const particleCount = 26;
    final maxRadius = size.width * 0.46;
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = accent.withValues(alpha: (1 - progress) * 0.9)
      ..style = PaintingStyle.fill;

    for (var i = 0; i < particleCount; i++) {
      final angle = i * (2 * math.pi / particleCount);
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
  bool shouldRepaint(_AcquireBurstPainter old) =>
      old.progress != progress || old.accent != accent;
}

String _formatInt(int value) {
  final String raw = value.toString();
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < raw.length; i++) {
    final int fromEnd = raw.length - i;
    buffer.write(raw[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}
