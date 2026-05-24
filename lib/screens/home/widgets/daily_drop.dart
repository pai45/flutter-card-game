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
  // Eased position: only sweeps during 8–62% of the cycle so it pauses off-screen
  late final Animation<double> _shimmerPos;
  late final Animation<double> _glowPulse;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _shimmerPos = CurvedAnimation(
      parent: _shimmer,
      curve: const Interval(0.08, 0.62, curve: Curves.easeInOut),
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
                    // Shimmer bands
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final travel = constraints.maxWidth + 260;
                          final dx = -180.0 + shimmerT * travel;
                          return Stack(
                            children: [
                              // Trailing warm halo — wider, amber-tinted, slightly behind
                              Transform.translate(
                                offset: Offset(dx - 48, 0),
                                child: Transform.rotate(
                                  angle: -0.32,
                                  child: Container(
                                    width: 210,
                                    height: constraints.maxHeight * 2.1,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withValues(alpha: 0),
                                          Cyber.amber.withValues(alpha: 0.10),
                                          Colors.white.withValues(alpha: 0.14),
                                          Cyber.amber.withValues(alpha: 0.10),
                                          Colors.white.withValues(alpha: 0),
                                        ],
                                        stops: const [0, 0.25, 0.5, 0.75, 1],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Leading bright core band
                              Transform.translate(
                                offset: Offset(dx, 0),
                                child: Transform.rotate(
                                  angle: -0.32,
                                  child: Container(
                                    width: 100,
                                    height: constraints.maxHeight * 2.1,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withValues(alpha: 0),
                                          Colors.white.withValues(alpha: 0.24),
                                          Colors.white.withValues(alpha: 0.68),
                                          Colors.white.withValues(alpha: 0.24),
                                          Colors.white.withValues(alpha: 0),
                                        ],
                                        stops: const [0, 0.22, 0.5, 0.78, 1],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Soft diagonal wash that rides with the bands
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment(-1 + shimmerT * 2, -1),
                                      end: Alignment(0.2 + shimmerT * 2, 1),
                                      colors: [
                                        Colors.white.withValues(alpha: 0),
                                        Colors.white.withValues(alpha: 0.07),
                                        Colors.white.withValues(alpha: 0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
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
