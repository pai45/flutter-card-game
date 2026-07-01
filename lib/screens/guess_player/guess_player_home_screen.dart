import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../blocs/guess_player/guess_player_cubit.dart';
import '../../config/theme.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/cyber/cyber_widgets.dart';

class GuessPlayerHomeScreen extends StatelessWidget {
  const GuessPlayerHomeScreen({
    required this.state,
    required this.onBack,
    required this.onOpenDay,
    required this.onOpenLogs,
    super.key,
  });

  final GuessPlayerState state;
  final VoidCallback onBack;
  final ValueChanged<String> onOpenDay;
  final VoidCallback onOpenLogs;

  @override
  Widget build(BuildContext context) {
    final today = state.todayKey;
    final todayResult = state.archive.resultsByDay[today];
    final solvedCount = state.archive.resultsByDay.values
        .where((result) => result.won)
        .length;
    final ctaLabel = todayResult != null
        ? (todayResult.won ? 'REVIEW SOLUTION' : 'REVIEW RESULTS')
        : 'PLAY TODAY\'S MYSTERY';

    return Scaffold(
      backgroundColor: Cyber.bg,
      appBar: _HomeHeader(onBack: onBack),
      body: _GuessPlayerStadiumBackground(
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final topGap = (constraints.maxHeight * 0.27)
                  .clamp(120.0, 238.0)
                  .toDouble();

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                children: [
                  SizedBox(height: topGap),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _LandingHero(
                            solvedCount: solvedCount,
                            unlockedCount: state.unlockedDayKeys.length,
                          ),
                          const SizedBox(height: 20),
                          CyberSlideUpFadeIn(
                            delay: const Duration(milliseconds: 390),
                            offset: 22,
                            child: HudCtaButton(
                              label: ctaLabel,
                              icon: Icons.person_search,
                              accent: Cyber.magenta,
                              tapSound: SoundEffect.playMatch,
                              onTap: () => onOpenDay(today),
                            ),
                          ),
                          const SizedBox(height: 14),
                          CyberSlideUpFadeIn(
                            delay: const Duration(milliseconds: 470),
                            offset: 22,
                            child: _DailyLogsHeader(onTap: onOpenLogs),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget implements PreferredSizeWidget {
  const _HomeHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Size get preferredSize => const Size.fromHeight(66);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 66,
      backgroundColor: const Color(0xff070a14),
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      title: Container(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.borderMuted)),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back to matches',
              onPressed: () {
                playSound(SoundEffect.uiTap);
                onBack();
              },
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            ),
            const Spacer(),
            const Icon(Icons.person_search, color: Cyber.magenta, size: 24),
          ],
        ),
      ),
    );
  }
}

class _GuessPlayerStadiumBackground extends StatefulWidget {
  const _GuessPlayerStadiumBackground({required this.child});

  final Widget child;

  @override
  State<_GuessPlayerStadiumBackground> createState() =>
      _GuessPlayerStadiumBackgroundState();
}

class _GuessPlayerStadiumBackgroundState
    extends State<_GuessPlayerStadiumBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff020812), Color(0xff101024), Color(0xff02050b)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final phase = _controller.value * math.pi * 2;
                return Transform.translate(
                  offset: Offset(math.sin(phase) * 8, math.cos(phase) * 6),
                  child: Transform.scale(
                    scale: 1.05 + 0.008 * math.sin(phase * 2),
                    child: child,
                  ),
                );
              },
              child: Opacity(
                opacity: 0.22,
                child: Image.asset(
                  'assets/backgrounds/home_stadium.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _ArenaMotionPainter(progress: _controller.value),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Cyber.bg.withValues(alpha: 0.16),
                    Cyber.bg.withValues(alpha: 0.3),
                    Cyber.bg.withValues(alpha: 0.78),
                  ],
                  stops: const [0.0, 0.48, 1.0],
                ),
              ),
            ),
          ),
          const Positioned.fill(child: CyberTextureOverlay()),
          widget.child,
        ],
      ),
    );
  }
}

class _ArenaMotionPainter extends CustomPainter {
  const _ArenaMotionPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rect = Offset.zero & size;
    final phase = progress * math.pi * 2;

    final pulse = 0.5 + 0.5 * math.sin(phase * 2);
    final fieldGlow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 0.72),
        radius: 0.88,
        colors: [
          Cyber.magenta.withValues(alpha: 0.08 + pulse * 0.035),
          Cyber.cyan.withValues(alpha: 0.025),
          Colors.transparent,
        ],
        stops: const [0.0, 0.28, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, fieldGlow);

    _drawBeam(
      canvas,
      size,
      start: Offset(size.width * 0.08, size.height * 0.72),
      end: Offset(size.width * (0.42 + math.sin(phase) * 0.06), 0),
      width: size.width * 0.42,
      opacity: 0.026 + pulse * 0.016,
    );
    _drawBeam(
      canvas,
      size,
      start: Offset(size.width * 0.92, size.height * 0.72),
      end: Offset(size.width * (0.58 + math.cos(phase) * 0.06), 0),
      width: size.width * 0.42,
      opacity: 0.026 + (1 - pulse) * 0.016,
    );

    final streakPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.055)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 14; i++) {
      final seed = i * 37.0;
      final x = ((seed * 19) % size.width) + math.sin(phase + i) * 18;
      final travel = (progress + i * 0.071) % 1.0;
      final y = size.height * (0.96 - travel * 0.82);
      final length = 12.0 + (i % 4) * 5.0;
      final opacity = 0.025 + 0.03 * math.sin(phase + i).abs();
      streakPaint.color = Cyber.magenta.withValues(alpha: opacity);
      canvas.drawLine(
        Offset(x, y),
        Offset(x + length * 0.42, y - length),
        streakPaint,
      );
    }
  }

  void _drawBeam(
    Canvas canvas,
    Size size, {
    required Offset start,
    required Offset end,
    required double width,
    required double opacity,
  }) {
    final path = Path()
      ..moveTo(start.dx - width * 0.5, start.dy)
      ..lineTo(start.dx + width * 0.5, start.dy)
      ..lineTo(end.dx + width * 0.08, end.dy)
      ..lineTo(end.dx - width * 0.08, end.dy)
      ..close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Cyber.magenta.withValues(alpha: opacity),
          Cyber.magenta.withValues(alpha: opacity * 0.35),
          Colors.transparent,
        ],
      ).createShader(path.getBounds());
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArenaMotionPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _LandingHero extends StatelessWidget {
  const _LandingHero({required this.solvedCount, required this.unlockedCount});

  final int solvedCount;
  final int unlockedCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CyberSlideUpFadeIn(child: _TelemetryStrip()),
        const SizedBox(height: 12),
        CyberSlideUpFadeIn(
          delay: const Duration(milliseconds: 80),
          offset: 24,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const _GuessIconBay(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'GUESS THE PLAYER',
                        maxLines: 1,
                        style: Cyber.display(22, color: Colors.white).copyWith(
                          letterSpacing: 1.1,
                          shadows: [
                            Shadow(
                              color: Cyber.magenta.withValues(alpha: 0.32),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'CAREER TIMELINE GAME',
                      style: Cyber.label(10, color: Cyber.muted),
                    ),
                    const SizedBox(height: 8),
                    const CyberChip(
                      label: 'DAILY MYSTERY',
                      color: Cyber.magenta,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: CyberDealtCard(
                key: const ValueKey('guess-home-stat-solved'),
                index: 0,
                initialDelay: const Duration(milliseconds: 180),
                flyDistance: 130,
                child: _StatTile(label: 'SOLVED', value: '$solvedCount'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: CyberDealtCard(
                key: const ValueKey('guess-home-stat-unlocked'),
                index: 1,
                initialDelay: const Duration(milliseconds: 180),
                flyDistance: 130,
                child: _StatTile(label: 'UNLOCKED', value: '$unlockedCount'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TelemetryStrip extends StatelessWidget {
  const _TelemetryStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xff071321).withValues(alpha: 0.82),
        border: Border(
          left: BorderSide(color: Cyber.magenta.withValues(alpha: 0.35)),
          right: BorderSide(color: Cyber.magenta.withValues(alpha: 0.35)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: Cyber.lime,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Cyber.lime.withValues(alpha: 0.6),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('ONLINE', style: Cyber.display(9, color: Cyber.lime)),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: Cyber.magenta.withValues(alpha: 0.18),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'SYS://CAREER TIMELINE | 1.0.0',
                style: Cyber.label(8, color: Cyber.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuessIconBay extends StatelessWidget {
  const _GuessIconBay();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            top: 0,
            child: _HudCorner(top: true, left: true),
          ),
          const Positioned(
            right: 0,
            top: 0,
            child: _HudCorner(top: true, left: false),
          ),
          const Positioned(
            left: 0,
            bottom: 0,
            child: _HudCorner(top: false, left: true),
          ),
          const Positioned(
            right: 0,
            bottom: 0,
            child: _HudCorner(top: false, left: false),
          ),
          Center(
            child: Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: const Color(0xff102036).withValues(alpha: 0.95),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Cyber.magenta.withValues(alpha: 0.16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Cyber.magenta.withValues(alpha: 0.14),
                    blurRadius: 24,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.person_search,
                color: Cyber.magenta,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HudCorner extends StatelessWidget {
  const _HudCorner({required this.top, required this.left});

  final bool top;
  final bool left;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        border: Border(
          top: top
              ? BorderSide(color: Cyber.magenta.withValues(alpha: 0.75))
              : BorderSide.none,
          bottom: top
              ? BorderSide.none
              : BorderSide(color: Cyber.magenta.withValues(alpha: 0.75)),
          left: left
              ? BorderSide(color: Cyber.magenta.withValues(alpha: 0.75))
              : BorderSide.none,
          right: left
              ? BorderSide.none
              : BorderSide(color: Cyber.magenta.withValues(alpha: 0.75)),
        ),
      ),
    );
  }
}

class _DailyLogsHeader extends StatelessWidget {
  const _DailyLogsHeader({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        playSound(SoundEffect.uiTap);
        onTap();
      },
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xff102036).withValues(alpha: 0.92),
          border: Border.all(color: Cyber.border.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            const Icon(Icons.history, color: Cyber.magenta, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'DAILY LOGS',
                style: Cyber.display(
                  14,
                  color: Cyber.magenta,
                ).copyWith(letterSpacing: 1.4),
              ),
            ),
            const Icon(Icons.chevron_right, color: Cyber.cyan, size: 22),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xff102036).withValues(alpha: 0.86),
        border: Border.all(color: Cyber.magenta.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: Cyber.display(
              16,
              color: Cyber.magenta,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 2),
          Text(label, style: Cyber.label(8, color: Cyber.muted)),
        ],
      ),
    );
  }
}
