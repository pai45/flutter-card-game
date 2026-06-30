import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/football_chess/football_chess_cubit.dart';
import '../../blocs/football_chess/football_chess_state.dart';
import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_state.dart';
import '../../config/enums.dart';
import '../../config/theme.dart';
import '../../data/random_opponent_names.dart';
import '../../models/cards.dart';
import '../../models/football_chess.dart';
import '../../models/progression.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import '../../widgets/player_level_badge.dart';
import 'football_chess_match_screen.dart';
import 'football_chess_matchmaking_screen.dart';

/// Pre-match lobby — Pitch Duel-style hero hub with animated emblem, stat row,
/// active-formation strip, and FIND MATCH CTA. Formation is now configured in
/// the Deck Builder and saved per-deck.
class FootballChessLobbyScreen extends StatefulWidget {
  const FootballChessLobbyScreen({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  State<FootballChessLobbyScreen> createState() =>
      _FootballChessLobbyScreenState();
}

class _FootballChessLobbyScreenState extends State<FootballChessLobbyScreen> {
  final _rng = math.Random();

  ChessFormation _activeFormation(GameState s) {
    if (s.deckSlots.isEmpty) return ChessFormation.box;
    final slot = s.deckSlots.firstWhere(
      (d) => d.id == s.activeDeckId,
      orElse: () => s.deckSlots.first,
    );
    return slot.chessFormation ?? ChessFormation.box;
  }

  bool _deckReady(GameState s) =>
      s.deckAttackers.length >= 2 &&
      s.deckDefenders.length >= 2 &&
      s.deckKeeper != null;

  void _launch() {
    final game = context.read<GameBloc>().state;
    if (!_deckReady(game)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Build a full 5-a-side deck first (2 ATK · 2 DEF · GK).',
          ),
        ),
      );
      return;
    }

    final formation = _activeFormation(game);
    final squad = <PlayerCard>[
      ...game.deckAttackers,
      ...game.deckDefenders,
      game.deckKeeper!,
    ];
    final level = game.progression.playerLevel;
    final opponentName = randomOpponentName();
    final opponentLevel = (level + _rng.nextInt(4) - 1).clamp(1, 99);
    final opponent = generateShootoutOpponent(
      opponentLevel,
      attackers,
      defenders,
      goalkeepers,
    );

    final cubit = context.read<FootballChessCubit>();
    final match = cubit.buildMatch(
      playerSquad: squad,
      formation: formation,
      opponentSquad: opponent.shooters,
      opponentName: opponentName,
      opponentLevel: opponentLevel,
    );

    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => FootballChessMatchmakingScreen(
          playerLevel: level,
          playerSquad: squad,
          opponentName: opponentName,
          opponentLevel: opponentLevel,
          opponentSquad: opponent.shooters,
          onCancel: navigator.pop,
          onKickoff: () {
            cubit.startMatch(match);
            navigator.pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider.value(
                  value: cubit,
                  child: FootballChessMatchScreen(
                    onExit: navigator.pop,
                    onPlayAgain: () {
                      navigator.pop();
                      _launch();
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      buildWhen: (p, c) =>
          p.deckSlots != c.deckSlots || p.progression != c.progression,
      builder: (context, gameState) {
        return BlocBuilder<FootballChessCubit, FootballChessState>(
          builder: (context, chessState) {
            final formation = _activeFormation(gameState);
            final deckReady = _deckReady(gameState);

            return Scaffold(
              backgroundColor: Cyber.bg,
              appBar: ReactHeaderBar(
                title: '5V5 FOOTBALL CHESS',
                subtitle: '// TACTICAL GRID DUEL',
                onBack: () => widget.onNavigate(AppSection.predictions),
                showTitle: false,
                rightSlot: PlayerLevelBadge(progression: gameState.progression),
              ),
              body: CyberBackground(
                animated: true,
                child: SafeArea(
                  top: false,
                  child: chessState.loading
                      ? const Center(
                          child: CircularProgressIndicator(color: Cyber.cyan),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                16,
                                24,
                                24,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: 380,
                                    minHeight: math.max(
                                      0,
                                      constraints.maxHeight - 40,
                                    ),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        // Greeble status strip
                                        const CyberSlideUpFadeIn(
                                          child: _ChessLobbyStatusBar(),
                                        ),
                                        const SizedBox(height: 18),
                                        // Hero row: emblem + identity + chip
                                        CyberSlideUpFadeIn(
                                          delay: const Duration(
                                            milliseconds: 80,
                                          ),
                                          offset: 24,
                                          child: Row(
                                            children: [
                                              const _ChessHeroEmblem(size: 92),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '5V5 FOOTBALL CHESS',
                                                      style:
                                                          Cyber.display(
                                                            22,
                                                            letterSpacing: 1.2,
                                                          ).copyWith(
                                                            shadows: [
                                                              Shadow(
                                                                color: Cyber
                                                                    .cyan
                                                                    .withValues(
                                                                      alpha:
                                                                          0.45,
                                                                    ),
                                                                blurRadius: 14,
                                                              ),
                                                            ],
                                                          ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      'TACTICAL GRID DUEL',
                                                      style: TextStyle(
                                                        color: Cyber.muted,
                                                        fontFamily:
                                                            Cyber.displayFont,
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        letterSpacing: 2.4,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Align(
                                                      alignment:
                                                          Alignment.centerLeft,
                                                      child: CyberChip(
                                                        label: deckReady
                                                            ? 'DECK ONLINE'
                                                            : 'BUILD DECK',
                                                        color: deckReady
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
                                        // Stats row
                                        Row(
                                          children: [
                                            Expanded(
                                              child: CyberDealtCard(
                                                key: const ValueKey(
                                                  'chess-stat-wins',
                                                ),
                                                index: 0,
                                                initialDelay: const Duration(
                                                  milliseconds: 180,
                                                ),
                                                flyDistance: 130,
                                                child: _HudStat(
                                                  label: 'WINS',
                                                  value:
                                                      '${chessState.stats.wins}',
                                                  accent: Cyber.success,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: CyberDealtCard(
                                                key: const ValueKey(
                                                  'chess-stat-losses',
                                                ),
                                                index: 1,
                                                initialDelay: const Duration(
                                                  milliseconds: 180,
                                                ),
                                                flyDistance: 130,
                                                child: _HudStat(
                                                  label: 'LOSSES',
                                                  value:
                                                      '${chessState.stats.losses}',
                                                  accent: Cyber.danger,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: CyberDealtCard(
                                                key: const ValueKey(
                                                  'chess-stat-streak',
                                                ),
                                                index: 2,
                                                initialDelay: const Duration(
                                                  milliseconds: 180,
                                                ),
                                                flyDistance: 130,
                                                child: _HudStat(
                                                  label: 'STREAK',
                                                  value:
                                                      '${chessState.stats.currentStreak}',
                                                  accent: Cyber.cyan,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 24),
                                        // FIND MATCH — hero CTA
                                        CyberSlideUpFadeIn(
                                          delay: const Duration(
                                            milliseconds: 390,
                                          ),
                                          offset: 22,
                                          child: deckReady
                                              ? HudCtaButton(
                                                  label: 'FIND MATCH',
                                                  icon: Icons.sports_soccer,
                                                  tapSound:
                                                      SoundEffect.playMatch,
                                                  helper:
                                                      'SHAPE: ${formation.code}  ${formation.label}',
                                                  onTap: _launch,
                                                )
                                              : Opacity(
                                                  opacity: 0.45,
                                                  child: IgnorePointer(
                                                    child: HudCtaButton(
                                                      label: 'FIND MATCH',
                                                      icon: Icons.sports_soccer,
                                                      onTap: () {},
                                                    ),
                                                  ),
                                                ),
                                        ),
                                        const SizedBox(height: 14),
                                        // Secondary: Deck Builder
                                        CyberDealtCard(
                                          key: const ValueKey(
                                            'chess-action-deck',
                                          ),
                                          index: 0,
                                          initialDelay: const Duration(
                                            milliseconds: 470,
                                          ),
                                          staggerMs: 85,
                                          flyDistance: 95,
                                          duration: const Duration(
                                            milliseconds: 500,
                                          ),
                                          child: CyberCtaButton(
                                            label: 'Deck Builder',
                                            clip: false,
                                            onPressed: () {
                                              HapticFeedback.selectionClick();
                                              playSound(SoundEffect.uiTap);
                                              widget.onNavigate(
                                                AppSection.deck,
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        // Rules text
                                        CyberSlideUpFadeIn(
                                          delay: const Duration(
                                            milliseconds: 650,
                                          ),
                                          offset: 14,
                                          child: Text(
                                            'Chess on a pitch: take turns, move a player or the ball, '
                                            'win it back by position, and shoot from their half to score. '
                                            'XP only — coins stay in the shop.',
                                            textAlign: TextAlign.center,
                                            style: Cyber.body(11).copyWith(
                                              color: Cyber.muted,
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

class _ChessLobbyStatusBar extends StatelessWidget {
  const _ChessLobbyStatusBar();

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
          'SYS://CHESS_GRID v1.0.0',
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

class _ChessHeroEmblem extends StatefulWidget {
  const _ChessHeroEmblem({this.size = 92});

  final double size;

  @override
  State<_ChessHeroEmblem> createState() => _ChessHeroEmblemState();
}

class _ChessHeroEmblemState extends State<_ChessHeroEmblem>
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
                      color: Cyber.magenta.withValues(alpha: 0.18),
                    ),
                  ),
                ),
              ),
              Transform.rotate(
                angle: phase * 0.25,
                child: Icon(
                  Icons.grid_4x4,
                  size: size * 0.58,
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
                painter: _ChessCornerBracketsPainter(
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

class _ChessCornerBracketsPainter extends CustomPainter {
  const _ChessCornerBracketsPainter(this.color);

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
  bool shouldRepaint(covariant _ChessCornerBracketsPainter old) =>
      old.color != color;
}

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
              style: const TextStyle(
                color: Colors.white,
                fontFamily: Cyber.displayFont,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
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
