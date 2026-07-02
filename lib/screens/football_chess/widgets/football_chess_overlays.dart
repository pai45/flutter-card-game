import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/football_chess/football_chess_cubit.dart';
import '../../../blocs/football_chess/football_chess_state.dart';
import '../../../config/theme.dart';
import '../../../models/football_chess.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../how_to_play/how_to_play_hub_screen.dart';

/// Slim top HUD — just `score · clock`. The board carries everything else.
class ChessHud extends StatelessWidget {
  const ChessHud({required this.onExit, super.key});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FootballChessCubit, FootballChessState>(
      buildWhen: (p, c) =>
          p.match?.playerScore != c.match?.playerScore ||
          p.match?.opponentScore != c.match?.opponentScore ||
          p.match?.clockRemaining.ceil() != c.match?.clockRemaining.ceil(),
      builder: (context, state) {
        final m = state.match;
        if (m == null) return const SizedBox.shrink();
        final s = m.clockRemaining.ceil();
        final clock =
            '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
        final urgent = s <= 15;
        return Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Cyber.muted, size: 20),
                onPressed: () {
                  playSound(SoundEffect.uiTap);
                  onExit();
                },
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _score('${m.playerScore}', Cyber.cyan),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        clock,
                        style: TextStyle(
                          fontFamily: Cyber.displayFont,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: urgent ? Cyber.danger : Colors.white,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    _score('${m.opponentScore}', Cyber.magenta),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.help_outline, color: Cyber.muted, size: 20),
                onPressed: () async {
                  playSound(SoundEffect.uiTap);
                  context.read<FootballChessCubit>().setPaused(true);
                  await showHowToPlayGuide(context, HowToPlayMode.footballChess);
                  if (context.mounted) {
                    context.read<FootballChessCubit>().setPaused(false);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _score(String v, Color c) => Text(
    v,
    style: TextStyle(
      fontFamily: Cyber.displayFont,
      fontSize: 24,
      fontWeight: FontWeight.w800,
      color: c,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}

/// One transient centre flash for all in-match beats — turn changes, the
/// just-resolved result, and GOAL — fired only on a phase change, then it fades.
class CentreFlash extends StatefulWidget {
  const CentreFlash({super.key});

  @override
  State<CentreFlash> createState() => _CentreFlashState();
}

class _CentreFlashState extends State<CentreFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  String _text = '';
  Color _color = Cyber.cyan;
  double _size = 16;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  (String, Color, double)? _msg(ChessMatch m) => switch (m.phase) {
    ChessMatchPhase.goalScored => ('GOAL!', Cyber.gold, 36),
    ChessMatchPhase.resolving =>
      m.banner == null ? null : (m.banner!, Cyber.amber, 18),
    ChessMatchPhase.playerTurn => ('YOUR MOVE', Cyber.cyan, 15),
    ChessMatchPhase.opponentTurn => ("OPPONENT'S MOVE", Cyber.magenta, 15),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    return BlocListener<FootballChessCubit, FootballChessState>(
      listenWhen: (p, c) => p.match?.phase != c.match?.phase,
      listener: (context, state) {
        final m = state.match;
        if (m == null) return;
        final msg = _msg(m);
        if (msg == null) return;
        setState(() {
          _text = msg.$1;
          _color = msg.$2;
          _size = msg.$3;
        });
        _c.forward(from: 0);
      },
      child: IgnorePointer(
        child: Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final v = _c.value;
              if (v == 0 || v >= 1) return const SizedBox.shrink();
              final op = (v < 0.2 ? v / 0.2 : 1 - (v - 0.2) / 0.8).clamp(
                0.0,
                1.0,
              );
              return Opacity(
                opacity: op,
                child: Transform.scale(
                  scale: 0.9 + 0.1 * op,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Cyber.bg.withValues(alpha: 0.82),
                      border: Border.all(color: _color.withValues(alpha: 0.85)),
                      boxShadow: _size >= 30 ? Cyber.glow(_color) : null,
                    ),
                    child: Text(
                      _text,
                      style: TextStyle(
                        fontFamily: Cyber.displayFont,
                        fontSize: _size,
                        fontWeight: FontWeight.w800,
                        letterSpacing: _size >= 30 ? 4 : 2,
                        color: _color,
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
  }
}

/// Contextual action bar — shows the selected piece's legal verbs (DRIBBLE/PASS/
/// SHOOT on the ball; PRESS/TACKLE/SLIDE/MOVE off it). Tapping a verb resolves it
/// or arms it for a target tap; the armed verb stays lit.
class ActionBar extends StatelessWidget {
  const ActionBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FootballChessCubit, FootballChessState>(
      buildWhen: (p, c) => p.match?.eventTick != c.match?.eventTick,
      builder: (context, state) {
        final m = state.match;
        if (m == null ||
            (m.phase != ChessMatchPhase.playerTurn &&
                m.phase != ChessMatchPhase.opponentTurn)) {
          return const SizedBox.shrink();
        }

        Widget content;
        if (m.phase == ChessMatchPhase.opponentTurn) {
          content = Text(
            'WAITING FOR OPPONENT',
            style: TextStyle(
              fontFamily: Cyber.displayFont,
              fontSize: 14,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
              color: Cyber.muted,
            ),
          );
        } else if (!m.hasSelection) {
          content = Text(
            'SELECT A PIECE',
            style: TextStyle(
              fontFamily: Cyber.displayFont,
              fontSize: 14,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
              color: Cyber.cyan,
            ),
          );
        } else if (m.availableActions.isEmpty) {
          content = Text(
            'NO ACTIONS',
            style: TextStyle(
              fontFamily: Cyber.displayFont,
              fontSize: 14,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
              color: Cyber.danger,
            ),
          );
        } else {
          content = Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final verb in m.availableActions)
                if (verb != BoardActionType.move) ...[
                  _ActionChip(
                    verb: verb,
                    armed: m.selectedAction == verb,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      playSound(_sfxFor(verb));
                      context.read<FootballChessCubit>().chooseAction(verb);
                    },
                  ),
                  const SizedBox(width: 8),
                ],
            ],
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 22, left: 12, right: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            constraints: const BoxConstraints(minHeight: 52),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Cyber.panel.withValues(alpha: 0.85),
              border: Border.all(color: Cyber.cyan.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ],
            ),
            child: content,
          ),
        );
      },
    );
  }

  SoundEffect _sfxFor(BoardActionType v) => switch (v) {
    BoardActionType.shoot => SoundEffect.attack,
    BoardActionType.tackle ||
    BoardActionType.slide ||
    BoardActionType.press => SoundEffect.defense,
    _ => SoundEffect.uiTap,
  };
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.verb,
    required this.armed,
    required this.onTap,
  });

  final BoardActionType verb;
  final bool armed;
  final VoidCallback onTap;

  Color get _accent => switch (verb) {
    BoardActionType.shoot => Cyber.gold,
    BoardActionType.dribble || BoardActionType.pass => Cyber.cyan,
    BoardActionType.tackle ||
    BoardActionType.slide ||
    BoardActionType.press => Cyber.magenta,
    BoardActionType.move => Cyber.muted,
  };

  IconData get _icon => switch (verb) {
    BoardActionType.dribble => Icons.directions_run,
    BoardActionType.pass => Icons.sync_alt,
    BoardActionType.shoot => Icons.sports_soccer,
    BoardActionType.press => Icons.compress,
    BoardActionType.tackle => Icons.shield_moon,
    BoardActionType.slide => Icons.sports_kabaddi,
    BoardActionType.move => Icons.open_with,
  };

  @override
  Widget build(BuildContext context) {
    final c = _accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              c.withValues(alpha: armed ? 0.35 : 0.18),
              Cyber.panel.withValues(alpha: 0.95),
            ],
          ),
          border: Border.all(color: c, width: armed ? 2 : 1.2),
          borderRadius: BorderRadius.circular(2),
          boxShadow: armed ? Cyber.glow(c) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, color: c, size: 20),
            const SizedBox(height: 3),
            Text(
              verb.label,
              style: Cyber.label(10, color: c, letterSpacing: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Visible 10s pick countdown — shown during the player's turn; bar + seconds,
/// turning red when low.
class DecisionTimer extends StatelessWidget {
  const DecisionTimer({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FootballChessCubit, FootballChessState>(
      buildWhen: (p, c) =>
          p.match?.phase != c.match?.phase ||
          p.match?.decisionRemaining.ceil() !=
              c.match?.decisionRemaining.ceil(),
      builder: (context, state) {
        final m = state.match;
        if (m == null || m.phase != ChessMatchPhase.playerTurn) {
          return const SizedBox.shrink();
        }
        final secs = m.decisionRemaining.ceil().clamp(0, 99);
        final low = m.decisionRemaining <= 3;
        final accent = low ? Cyber.danger : Cyber.cyan;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: SizedBox(
            width: 200,
            child: Row(
              children: [
                Text(
                  '${secs}s',
                  style: Cyber.label(11, color: accent, letterSpacing: 1)
                      .copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CyberProgressBar(
                    value:
                        (m.decisionRemaining /
                                FootballChessCubit.kDecisionSeconds)
                            .clamp(0.0, 1.0),
                    accent: accent,
                    animate: false,
                    height: 5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Transient banner shown after the CPU completes a move — tells the player
/// which piece moved and what action was played.
class OpponentActionToast extends StatefulWidget {
  const OpponentActionToast({super.key});

  @override
  State<OpponentActionToast> createState() => _OpponentActionToastState();
}

class _OpponentActionToastState extends State<OpponentActionToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  String _pieceName = '';
  String _actionLabel = '';

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _show(String piece, String action) {
    setState(() {
      _pieceName = piece;
      _actionLabel = action;
    });
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<FootballChessCubit, FootballChessState>(
      listenWhen: (p, c) =>
          p.match?.phase != c.match?.phase &&
          c.match?.phase == ChessMatchPhase.resolving &&
          c.match?.turnSide == Side.opponent,
      listener: (context, state) {
        final lm = state.match?.lastMove;
        if (lm == null) return;
        _show(lm.actorName.toUpperCase(), lm.verb.label.toUpperCase());
      },
      child: IgnorePointer(
        child: Align(
          alignment: const Alignment(0, -0.35),
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final v = _c.value;
              if (v == 0 || v >= 1) return const SizedBox.shrink();
              final op = (v < 0.12 ? v / 0.12 : 1 - (v - 0.12) / 0.88).clamp(
                0.0,
                1.0,
              );
              return Opacity(
                opacity: op,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Cyber.bg.withValues(alpha: 0.88),
                    border: Border.all(
                      color: Cyber.magenta.withValues(alpha: 0.85),
                    ),
                    boxShadow: Cyber.glow(Cyber.magenta),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'CPU',
                        style: Cyber.label(
                          9,
                          color: Cyber.muted,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _pieceName,
                        style: TextStyle(
                          fontFamily: Cyber.displayFont,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: Cyber.magenta,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _actionLabel,
                        style: TextStyle(
                          fontFamily: Cyber.displayFont,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Compact running move log under the HUD (last few actions, both sides).
class MoveLogStrip extends StatelessWidget {
  const MoveLogStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FootballChessCubit, FootballChessState>(
      buildWhen: (p, c) => p.match?.moveLog.length != c.match?.moveLog.length,
      builder: (context, state) {
        final m = state.match;
        if (m == null || m.moveLog.isEmpty) return const SizedBox.shrink();
        final recent = m.moveLog.length > 5
            ? m.moveLog.sublist(m.moveLog.length - 5)
            : m.moveLog;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final e in recent) ...[
                _LogChip(entry: e),
                const SizedBox(width: 4),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _LogChip extends StatelessWidget {
  const _LogChip({required this.entry});

  final MoveLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final you = entry.side == Side.player;
    final c = you ? Cyber.cyan : Cyber.magenta;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        border: Border.all(color: c.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${you ? 'YOU' : 'OPP'} ${entry.verb.label}',
            style: Cyber.label(8, color: c, letterSpacing: 0.6),
          ),
          if (entry.card != CardType.none) ...[
            const SizedBox(width: 4),
            Container(
              width: 5,
              height: 7,
              color: entry.card == CardType.red ? Cyber.danger : Cyber.gold,
            ),
          ],
        ],
      ),
    );
  }
}

/// Banner that persistently displays the last action (who did what).
class LastActionBanner extends StatelessWidget {
  const LastActionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FootballChessCubit, FootballChessState>(
      buildWhen: (p, c) => p.match?.lastMove != c.match?.lastMove,
      builder: (context, state) {
        final lm = state.match?.lastMove;
        if (lm == null) return const SizedBox.shrink();
        final you = lm.side == Side.player;
        final color = you ? Cyber.cyan : Cyber.magenta;
        final actorText = you ? 'YOU' : 'CPU';

        // e.g. "YOU TACKLED" or "CPU MOVED"
        String verbLabel = lm.verb.label;
        if (verbLabel.endsWith('E')) {
          verbLabel = '${verbLabel}D';
        } else if (verbLabel == 'PASS' || verbLabel == 'PRESS') {
          verbLabel = '${verbLabel}ED';
        } else if (verbLabel == 'SHOOT') {
          verbLabel = 'SHOT';
        } else {
          verbLabel = '${verbLabel}ED';
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: Cyber.bg.withValues(alpha: 0.8),
            border: Border.all(color: color.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$actorText $verbLabel',
            style: TextStyle(
              fontFamily: Cyber.displayFont,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: color,
            ),
          ),
        );
      },
    );
  }
}
