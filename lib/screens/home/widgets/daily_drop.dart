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
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            final card = allPlayerCards[_random.nextInt(allPlayerCards.length)];
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
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Cyber.amber, Color(0xffff7a2f), Cyber.magenta],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Cyber.amber.withValues(alpha: 0.32),
                        blurRadius: 22,
                      ),
                    ],
                  ),
                  child: const SizedBox(width: double.infinity, height: 76),
                ),
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _shimmer,
                    builder: (context, _) {
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final travel = width + 260;
                          return Stack(
                            children: [
                              Transform.translate(
                                offset: Offset(
                                  -180 + _shimmer.value * travel,
                                  0,
                                ),
                                child: Transform.rotate(
                                  angle: -0.32,
                                  child: Container(
                                    width: 132,
                                    height: constraints.maxHeight * 2.1,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withValues(alpha: 0),
                                          Colors.white.withValues(alpha: 0.18),
                                          Colors.white.withValues(alpha: 0.55),
                                          Colors.white.withValues(alpha: 0.18),
                                          Colors.white.withValues(alpha: 0),
                                        ],
                                        stops: const [0, 0.24, 0.5, 0.76, 1],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment(
                                        -1 + _shimmer.value * 2,
                                        -1,
                                      ),
                                      end: Alignment(
                                        0.2 + _shimmer.value * 2,
                                        1,
                                      ),
                                      colors: [
                                        Colors.white.withValues(alpha: 0),
                                        Colors.white.withValues(alpha: 0.08),
                                        Colors.white.withValues(alpha: 0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
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
  }
}
