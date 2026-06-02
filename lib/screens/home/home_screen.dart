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
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 144),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _LobbyStatusBar(),
                          const SizedBox(height: 18),
                          // Asymmetric HUD hero: logo emblem + identity block.
                          Row(
                            children: [
                              const _HeroEmblem(size: 92),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'PITCH DUEL',
                                      style:
                                          Cyber.display(
                                            26,
                                            letterSpacing: 1.4,
                                          ).copyWith(
                                            shadows: [
                                              Shadow(
                                                color: Cyber.cyan.withValues(
                                                  alpha: 0.45,
                                                ),
                                                blurRadius: 14,
                                              ),
                                            ],
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'TACTICAL CARD DUEL',
                                      style: TextStyle(
                                        color: Cyber.muted,
                                        fontFamily: Cyber.displayFont,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 2.4,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: CyberChip(
                                        label: state.deckReady
                                            ? 'DECK ONLINE'
                                            : 'DEFAULT LOADOUT',
                                        color: state.deckReady
                                            ? Cyber.lime
                                            : Cyber.amber,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Greeble telemetry — real profile data (no glow).
                          Row(
                            children: [
                              Expanded(
                                child: _HudStat(
                                  label: 'LEVEL',
                                  value: '${state.progression.playerLevel}',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _HudStat(
                                  label: 'TOTAL XP',
                                  value: _grp(state.progression.totalXP),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _HudStat(
                                  label: 'COINS',
                                  value: _grp(state.coins),
                                  accent: Cyber.gold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // PLAY MATCH — hero CTA, unchanged.
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
                          const SizedBox(height: 14),
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
                          const SizedBox(height: 16),
                          // Secondary links (preserved): how-to-play + replay.
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 14,
                            runSpacing: 6,
                            children: [
                              _HudLink(
                                label: 'HOW TO PLAY',
                                onTap: () => onNavigate(AppSection.howToPlay),
                              ),
                              Container(
                                width: 3,
                                height: 3,
                                color: Cyber.muted,
                              ),
                              _HudLink(
                                label: 'REPLAY WALKTHROUGH',
                                faint: true,
                                onTap: () {
                                  context.read<GameBloc>().add(TutorialReset());
                                  showTutorialNow(
                                    context,
                                    keyName: 'home',
                                    steps: homeTutorialSteps,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Tutorial reset'),
                                    ),
                                  );
                                },
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

/// Groups an integer with thousands separators ("3870" -> "3,870").
String _grp(int value) {
  final s = value.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${value < 0 ? '-' : ''}$b';
}

/// Greeble status strip above the hero: a live "ONLINE" indicator and a system
/// version readout, split by a thin HUD line.
class _LobbyStatusBar extends StatelessWidget {
  const _LobbyStatusBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: Cyber.success,
            shape: BoxShape.circle,
            // Live indicator — glow is intentional here.
            boxShadow: Cyber.glow(
              Cyber.success,
              alpha: 0.6,
              blur: 8,
              spread: 0,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'ONLINE',
          style: TextStyle(
            color: Cyber.success,
            fontFamily: Cyber.displayFont,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: Cyber.cyan.withValues(alpha: 0.16),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'SYS://PITCH_DUEL v1.0.0',
          style: TextStyle(
            color: Cyber.muted,
            fontFamily: Cyber.displayFont,
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

/// Animated soccer emblem framed by HUD corner brackets.
class _HeroEmblem extends StatefulWidget {
  const _HeroEmblem({this.size = 92});

  final double size;

  @override
  State<_HeroEmblem> createState() => _HeroEmblemState();
}

class _HeroEmblemState extends State<_HeroEmblem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _spin,
        builder: (context, _) {
          final phase = _spin.value * math.pi * 2;
          final pulse = 0.5 + 0.5 * math.sin(phase * 2);
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: size * 0.9,
                height: size * 0.9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Cyber.bg.withValues(alpha: 0.5),
                  border: Border.all(
                    color: Cyber.cyan.withValues(alpha: 0.26 + pulse * 0.12),
                  ),
                  boxShadow: Cyber.glow(
                    Cyber.cyan,
                    alpha: 0.2 + pulse * 0.08,
                    blur: 18 + pulse * 4,
                    spread: -4,
                  ),
                ),
              ),
              SizedBox(
                width: size * 0.74,
                height: size * 0.74,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Cyber.lime.withValues(alpha: 0.18),
                    ),
                  ),
                ),
              ),
              Transform.rotate(
                angle: phase,
                child: Icon(
                  Icons.sports_soccer,
                  size: size * 0.64,
                  color: Cyber.cyan,
                  shadows: [
                    Shadow(
                      color: Cyber.cyan.withValues(alpha: 0.62),
                      blurRadius: 16 + pulse * 4,
                    ),
                  ],
                ),
              ),
              CustomPaint(
                size: Size.square(size),
                painter: _CornerBracketsPainter(
                  Cyber.cyan.withValues(alpha: 0.62 + pulse * 0.14),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CornerBracketsPainter extends CustomPainter {
  const _CornerBracketsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    const len = 11.0;
    final w = size.width;
    final h = size.height;
    canvas.drawLine(Offset.zero, const Offset(len, 0), p);
    canvas.drawLine(Offset.zero, const Offset(0, len), p);
    canvas.drawLine(Offset(w, 0), Offset(w - len, 0), p);
    canvas.drawLine(Offset(w, 0), Offset(w, len), p);
    canvas.drawLine(Offset(0, h), Offset(len, h), p);
    canvas.drawLine(Offset(0, h), Offset(0, h - len), p);
    canvas.drawLine(Offset(w, h), Offset(w - len, h), p);
    canvas.drawLine(Offset(w, h), Offset(w, h - len), p);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketsPainter old) =>
      old.color != color;
}

/// A compact telemetry cell (label + value). Secondary data — no glow.
class _HudStat extends StatelessWidget {
  const _HudStat({
    required this.label,
    required this.value,
    this.accent = Cyber.cyan,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Cyber.bg.withValues(alpha: 0.5),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontFamily: Cyber.displayFont,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Cyber.muted,
              fontFamily: Cyber.displayFont,
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// A flat HUD text link (no Material ripple). Used for the secondary actions.
class _HudLink extends StatelessWidget {
  const _HudLink({
    required this.label,
    required this.onTap,
    this.faint = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool faint;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: faint ? Cyber.cyan.withValues(alpha: 0.55) : Cyber.cyan,
          fontFamily: Cyber.displayFont,
          fontSize: faint ? 10 : 11,
          fontWeight: faint ? FontWeight.w800 : FontWeight.w900,
          letterSpacing: faint ? 2.2 : 1.4,
        ),
      ),
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
