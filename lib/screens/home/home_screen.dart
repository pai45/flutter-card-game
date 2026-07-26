import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/game/game_state.dart';
import '../../config/enums.dart';
import '../../config/theme.dart';
import '../../config/tutorial_steps.dart';
import '../../models/match.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/game_scaffold.dart';
import '../../widgets/landing_bottom_navigation.dart';
import '../../widgets/player_level_badge.dart';
import '../../widgets/tutorial.dart';
import '../../screens/match_history/match_history_pages.dart';
import 'widgets/daily_drop.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.onNavigate,
    this.showBottomNavigation = true,
    this.onBack,
    super.key,
  });

  final ValueChanged<AppSection> onNavigate;
  final bool showBottomNavigation;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Cyber.bg,
          appBar: ReactHeaderBar(
            title: 'Pitch Duel',
            subtitle: showBottomNavigation ? '// Match Lobby' : null,
            showTitle: showBottomNavigation,
            leftSlot: onBack == null
                ? null
                : IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    color: Cyber.cyan,
                  ),
            rightSlot: PlayerLevelBadge(progression: state.progression),
          ),
          body: CyberArenaBackground(
            assetPath: 'assets/backgrounds/home_stadium.png',
            accent: Cyber.cyan,
            secondaryAccent: Cyber.lime,
            additiveBeams: true,
            // Keep the arena art full-bleed behind the bars; inset the content
            // (incl. the bottom-pinned daily drop) above the gesture bar.
            child: SafeArea(
              top: false,
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
                            const CyberSlideUpFadeIn(
                              child: CyberLobbyStatusBar(
                                systemLabel: 'SYS://PITCH_DUEL v1.0.0',
                              ),
                            ),
                            const SizedBox(height: 18),
                            // Asymmetric HUD hero: logo emblem + identity block.
                            CyberSlideUpFadeIn(
                              delay: const Duration(milliseconds: 80),
                              offset: 24,
                              child: Row(
                                children: [
                                  const _HeroEmblem(size: 92),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                                    color: Cyber.cyan
                                                        .withValues(
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
                            ),
                            const SizedBox(height: 20),
                            // Greeble telemetry — real profile data (no glow).
                            Row(
                              children: [
                                Expanded(
                                  child: CyberDealtCard(
                                    key: const ValueKey('home-stat-level'),
                                    index: 0,
                                    initialDelay: const Duration(
                                      milliseconds: 180,
                                    ),
                                    flyDistance: 130,
                                    child: CyberHudStat(
                                      label: 'LEVEL',
                                      value: '${state.progression.playerLevel}',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: CyberDealtCard(
                                    key: const ValueKey('home-stat-xp'),
                                    index: 1,
                                    initialDelay: const Duration(
                                      milliseconds: 180,
                                    ),
                                    flyDistance: 130,
                                    child: CyberHudStat(
                                      label: 'TOTAL XP',
                                      value: _grp(state.progression.totalXP),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: CyberDealtCard(
                                    key: const ValueKey('home-stat-wins'),
                                    index: 2,
                                    initialDelay: const Duration(
                                      milliseconds: 180,
                                    ),
                                    flyDistance: 130,
                                    child: CyberHudStat(
                                      label: 'WINS',
                                      value: _grp(
                                        _duelWins(state.matchHistory),
                                      ),
                                      accent: Cyber.success,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // PLAY MATCH — hero CTA, unchanged.
                            CyberSlideUpFadeIn(
                              delay: const Duration(milliseconds: 390),
                              offset: 22,
                              child: state.deckReady
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
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: CyberDealtCard(
                                    key: const ValueKey('home-action-deck'),
                                    index: 0,
                                    initialDelay: const Duration(
                                      milliseconds: 470,
                                    ),
                                    staggerMs: 85,
                                    flyDistance: 95,
                                    duration: const Duration(milliseconds: 500),
                                    child: CyberCtaButton(
                                      label: 'Deck Builder',
                                      clip: false,
                                      onPressed: () =>
                                          onNavigate(AppSection.deck),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: CyberDealtCard(
                                    key: const ValueKey('home-action-history'),
                                    index: 1,
                                    initialDelay: const Duration(
                                      milliseconds: 470,
                                    ),
                                    staggerMs: 85,
                                    flyDistance: 95,
                                    duration: const Duration(milliseconds: 500),
                                    child: CyberCtaButton(
                                      label: 'Match History',
                                      clip: false,
                                      onPressed: () => showMatchHistoryArchive(
                                        context,
                                        state.matchHistory,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Secondary links (preserved): how-to-play + replay.
                            CyberSlideUpFadeIn(
                              delay: const Duration(milliseconds: 650),
                              offset: 14,
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 14,
                                runSpacing: 6,
                                children: [
                                  _HudLink(
                                    label: 'HOW TO PLAY',
                                    onTap: () =>
                                        onNavigate(AppSection.howToPlay),
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
                                      context.read<GameBloc>().add(
                                        TutorialReset(),
                                      );
                                      showTutorialNow(
                                        context,
                                        keyName: 'home',
                                        steps: homeTutorialSteps,
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Tutorial reset'),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: CyberSlideUpFadeIn(
                      delay: const Duration(milliseconds: 720),
                      offset: 36,
                      child: const DailyDropButton(),
                    ),
                  ),
                  const TutorialTip(keyName: 'home', steps: homeTutorialSteps),
                ],
              ),
            ),
          ),
          bottomNavigationBar: showBottomNavigation
              ? LandingBottomNavigation(
                  selectedIndex: 0,
                  onNavigate: onNavigate,
                )
              : null,
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

int _duelWins(List<MatchHistoryEntry> history) =>
    history.where(_isDuelWin).length;

bool _isDuelWin(MatchHistoryEntry entry) {
  if (entry.playerScore != entry.opponentScore) {
    return entry.playerScore > entry.opponentScore;
  }
  return (entry.penaltyPlayerScore ?? 0) > (entry.penaltyOpponentScore ?? 0);
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
