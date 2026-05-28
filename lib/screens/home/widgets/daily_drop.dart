import 'dart:math';

import 'package:flutter/material.dart';

import '../../../config/enums.dart';
import '../../../config/theme.dart';
import '../../../models/cards.dart';
import '../../../widgets/card_unpack_animation.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

String _rarityStr(CardRarity r) => switch (r) {
  CardRarity.common => 'common',
  CardRarity.rare => 'rare',
  CardRarity.epic => 'epic',
  CardRarity.legendary => 'legendary',
};

class DailyDropButton extends StatefulWidget {
  const DailyDropButton({super.key});

  @override
  State<DailyDropButton> createState() => _DailyDropButtonState();
}

class _DailyDropButtonState extends State<DailyDropButton>
    with TickerProviderStateMixin {
  late final AnimationController _shimmer;
  late final AnimationController _glow;
  // Eased position: sweeps during ~10–52% of the cycle, then pauses off-screen
  // before the next sweep — gives the shimmer a clear "flash, rest" rhythm.
  late final Animation<double> _shimmerPos;
  late final Animation<double> _glowPulse;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    _shimmerPos = CurvedAnimation(
      parent: _shimmer,
      curve: const Interval(0.10, 0.52, curve: Curves.easeInOutCubic),
    );

    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _glowPulse = CurvedAnimation(parent: _glow, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _shimmer.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_shimmer, _glow]),
      builder: (_, child) {
        final shimmerT = _shimmerPos.value;
        final glowT = _glowPulse.value;
        final glowBlur = 18.0 + glowT * 30.0;
        final glowAlpha = 0.28 + glowT * 0.24;

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Cyber.bg.withValues(alpha: 0),
                Cyber.bg.withValues(alpha: 0.94),
                Cyber.bg,
              ],
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: GestureDetector(
              onTap: () {
                final card =
                    allPlayerCards[_random.nextInt(allPlayerCards.length)];
                final nav = Navigator.of(context);
                nav.push(
                  PageRouteBuilder<void>(
                    opaque: true,
                    pageBuilder: (ctx, a1, a2) => CardUnpackAnimation(
                      playerName: card.shortName,
                      position: card.position,
                      rating: card.rating,
                      rarity: _rarityStr(card.rarity),
                      onComplete: nav.pop,
                      frontFace: CyberPlayerCardTile(
                        card: card,
                        selected: true,
                        size: VisualCardSize.md,
                      ),
                    ),
                  ),
                );
              },
              child: ClipPath(
                clipper: CyberClipper(),
                child: Stack(
                  children: [
                    // Base gradient + breathing glow
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Cyber.amber, Color(0xffff7a2f), Cyber.magenta],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Cyber.amber.withValues(alpha: glowAlpha),
                            blurRadius: glowBlur,
                          ),
                        ],
                      ),
                      child: const SizedBox(width: double.infinity, height: 76),
                    ),
                    // Single clean diagonal shimmer band — painted directly so
                    // the bright core stays sharp on the saturated gradient.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _ShimmerBandPainter(t: shimmerT),
                        ),
                      ),
                    ),
                    // Top-edge inner highlight
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x22ffffff),
                              Color(0x00000000),
                              Color(0x22000000),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Positioned.fill(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.style, color: Color(0xff160a00)),
                          SizedBox(width: 14),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DAILY DROP',
                                style: TextStyle(
                                  color: Color(0xaa160a00),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'OPEN YOUR DAILY CARD',
                                style: TextStyle(
                                  color: Color(0xff160a00),
                                  fontFamily: 'Orbitron',
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.9,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Draws one diagonal white band that sweeps across the CTA. Drawing it on a
/// single canvas avoids the multi-layer blending issues the previous Stack-of-
/// Transforms approach had and keeps the bright core sharp against the
/// saturated amber → magenta gradient underneath.
class _ShimmerBandPainter extends CustomPainter {
  const _ShimmerBandPainter({required this.t});

  /// Eased position of the band centre — 0 = off-screen left, 1 = off-screen
  /// right. Outside (0, 1) we skip painting entirely so the button is plain
  /// during the rest portion of the cycle.
  final double t;

  static const double _angle = -0.38;
  static const double _bandWidth = 70.0;
  static const double _pad = 110.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final centerX = -_pad + t * (size.width + _pad * 2);
    canvas.translate(centerX, size.height / 2);
    canvas.rotate(_angle);

    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: _bandWidth * 3,
      height: size.height * 2.8,
    );
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.95),
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0, 0.28, 0.44, 0.5, 0.56, 0.72, 1],
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShimmerBandPainter old) => old.t != t;
}
