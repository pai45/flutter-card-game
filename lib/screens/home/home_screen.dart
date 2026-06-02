import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/game/game_state.dart';
import '../../config/enums.dart';
import '../../config/theme.dart';
import '../../config/tutorial_steps.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/game_scaffold.dart';
import '../../widgets/landing_bottom_navigation.dart';
import '../../widgets/player_level_badge.dart';
import '../../widgets/tutorial.dart';
import '../../screens/match_history/match_history_pages.dart';
import 'widgets/daily_drop.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Cyber.bg,
          appBar: ReactHeaderBar(
            title: 'Pitch Duel',
            subtitle: '// Match Lobby',
            rightSlot: PlayerLevelBadge(progression: state.progression),
          ),
          body: _HomeArenaBackground(
            child: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 144),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.sports_soccer,
                            size: 58,
                            color: Cyber.cyan,
                            shadows: [
                              Shadow(
                                color: Cyber.cyan.withValues(alpha: 0.55),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          CyberChip(
                            label: state.deckReady
                                ? 'DECK ONLINE'
                                : 'DEFAULT LOADOUT',
                            color: state.deckReady ? Cyber.lime : Cyber.amber,
                          ),
                          const SizedBox(height: 28),
                          state.deckReady
                              ? HudCtaButton(
                                  label: 'PLAY MATCH',
                                  onTap: () {
                                    context.read<GameBloc>().add(
                                      MatchStarted(),
                                    );
                                    onNavigate(AppSection.match);
                                  },
                                )
                              : Opacity(
                                  opacity: 0.45,
                                  child: IgnorePointer(
                                    child: HudCtaButton(
                                      label: 'PLAY MATCH',
                                      onTap: () {},
                                    ),
                                  ),
                                ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => onNavigate(AppSection.howToPlay),
                            child: const Text(
                              'HOW TO PLAY',
                              style: TextStyle(
                                color: Cyber.cyan,
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextButton(
                            onPressed: () {
                              context.read<GameBloc>().add(TutorialReset());
                              showTutorialNow(
                                context,
                                keyName: 'home',
                                steps: homeTutorialSteps,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Tutorial reset')),
                              );
                            },
                            child: Text(
                              'REPLAY WALKTHROUGH',
                              style: TextStyle(
                                color: Cyber.cyan.withValues(alpha: 0.55),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: CyberCtaButton(
                                  label: 'Deck Builder',
                                  clip: false,
                                  onPressed: () => onNavigate(AppSection.deck),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: CyberCtaButton(
                                  label: 'Match History',
                                  clip: false,
                                  onPressed: () => showMatchHistoryArchive(
                                    context,
                                    state.matchHistory,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DailyDropButton(),
                ),
                const TutorialTip(keyName: 'home', steps: homeTutorialSteps),
              ],
            ),
          ),
          bottomNavigationBar: LandingBottomNavigation(
            selectedIndex: 0,
            onNavigate: onNavigate,
          ),
        );
      },
    );
  }
}

class _HomeArenaBackground extends StatefulWidget {
  const _HomeArenaBackground({required this.child});

  final Widget child;

  @override
  State<_HomeArenaBackground> createState() => _HomeArenaBackgroundState();
}

class _HomeArenaBackgroundState extends State<_HomeArenaBackground>
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
          colors: [Color(0xff020812), Color(0xff071522), Color(0xff02050b)],
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
                opacity: 0.2,
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
                    Cyber.bg.withValues(alpha: 0.32),
                    Colors.transparent,
                    Cyber.bg.withValues(alpha: 0.62),
                  ],
                  stops: const [0.0, 0.48, 1.0],
                ),
              ),
            ),
          ),
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
          Cyber.cyan.withValues(alpha: 0.08 + pulse * 0.035),
          Cyber.lime.withValues(alpha: 0.025),
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
      streakPaint.color = Cyber.cyan.withValues(alpha: opacity);
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
          Cyber.cyan.withValues(alpha: opacity),
          Cyber.cyan.withValues(alpha: opacity * 0.35),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size)
      ..blendMode = BlendMode.plus;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArenaMotionPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
