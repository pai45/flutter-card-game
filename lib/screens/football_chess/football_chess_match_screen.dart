import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/football_chess/football_chess_cubit.dart';
import '../../blocs/football_chess/football_chess_state.dart';
import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../config/theme.dart';
import '../../games/football_chess/football_chess_board.dart';
import '../../games/football_chess/football_chess_game.dart';
import '../../models/football_chess.dart';
import '../../models/progression.dart';
import '../../models/xp_ledger.dart';
import '../../utils/sound_effects.dart';
import 'widgets/football_chess_overlays.dart';
import 'widgets/football_chess_result.dart';

/// The live grid Football Chess match: a full-bleed Flame board with the bare
/// minimum chrome (slim score·clock, a transient centre flash, a contextual
/// SHOOT button). The cubit owns the rules; this screen renders, plays SFX,
/// drives the Flame beats and dispatches XP at full time.
class FootballChessMatchScreen extends StatefulWidget {
  const FootballChessMatchScreen({
    required this.onExit,
    required this.onPlayAgain,
    super.key,
  });

  final VoidCallback onExit;
  final VoidCallback onPlayAgain;

  @override
  State<FootballChessMatchScreen> createState() =>
      _FootballChessMatchScreenState();
}

class _FootballChessMatchScreenState extends State<FootballChessMatchScreen> {
  late final FootballChessCubit _cubit;
  late final FootballChessGame _game;
  bool _kickoffScheduled = false;
  bool _xpDispatched = false;
  int _awardedXp = 0;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<FootballChessCubit>();
    _game = FootballChessGame(
      match: _cubit.state.match!,
      onCellTapped: _onCellTapped,
    );
    AudioController.instance.playLoop(MusicTrack.matchAmbient);
  }

  @override
  void dispose() {
    AudioController.instance.stopLoop();
    if (_cubit.state.match?.phase != ChessMatchPhase.fullTime) {
      _cubit.abandonMatch();
    }
    super.dispose();
  }

  void _onCellTapped(BoardCell? cell) {
    if (cell == null) {
      _cubit.deselect();
    } else {
      _cubit.tapCell(cell);
    }
  }

  void _drive(BuildContext context, FootballChessState state) {
    final m = state.match;
    if (m == null) return;
    switch (m.phase) {
      case ChessMatchPhase.toss:
        if (m.tossResult != null && !_kickoffScheduled) {
          _kickoffScheduled = true;
          playSound(SoundEffect.coinLand);
          HapticFeedback.mediumImpact();
          Future.delayed(const Duration(milliseconds: 1300), () {
            if (mounted) _cubit.beginPlay();
          });
        }
      case ChessMatchPhase.playerTurn:
      case ChessMatchPhase.opponentTurn:
        _game.syncMatch(m);
      case ChessMatchPhase.resolving:
        _game.syncMatch(m);
        _resolutionSfx(m.lastEvent);
        Future.delayed(const Duration(milliseconds: 430), () {
          if (mounted) _cubit.onResolutionAnimated();
        });
      case ChessMatchPhase.goalScored:
        _game.syncMatch(m);
        _game.playGoal(m.turnSide);
        playSound(SoundEffect.goal);
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) _cubit.onGoalReset();
        });
      case ChessMatchPhase.fullTime:
        _onFullTime(m);
    }
  }

  void _resolutionSfx(BoardEvent event) {
    switch (event) {
      case BoardEvent.turnover:
      case BoardEvent.blocked:
        playSound(SoundEffect.defense);
        HapticFeedback.selectionClick();
      case BoardEvent.save:
        playSound(SoundEffect.save);
      case BoardEvent.advanced:
        playSound(SoundEffect.whoosh);
      case BoardEvent.none:
      case BoardEvent.goal:
        break;
    }
  }

  void _onFullTime(ChessMatch m) {
    if (_xpDispatched) return;
    _xpDispatched = true;
    AudioController.instance.stopLoop();
    playSound(m.playerWon ? SoundEffect.matchWin : SoundEffect.matchLose);
    playSound(SoundEffect.bannerSlam);
    HapticFeedback.heavyImpact();
    final margin = (m.playerScore - m.opponentScore).abs();
    _awardedXp = calculateFootballChessXP(
      won: m.playerWon,
      draw: m.isDraw,
      goalMargin: margin,
    );
    final verdict = m.playerWon
        ? 'WIN'
        : m.isDraw
        ? 'DRAW'
        : 'LOSS';
    context.read<GameBloc>().add(
      PredictionXpAdded(
        _awardedXp,
        source: XpTransactionSource.footballChess,
        title: '5V5 FOOTBALL CHESS',
        details: '$verdict ${m.playerScore}-${m.opponentScore}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: BlocListener<FootballChessCubit, FootballChessState>(
        listenWhen: (p, c) => p.match?.eventTick != c.match?.eventTick,
        listener: _drive,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: GameWidget(game: _game)),
              Align(
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ChessHud(onExit: widget.onExit),
                    const LastActionBanner(),
                  ],
                ),
              ),
              const Align(child: CentreFlash()),
              const OpponentActionToast(),
              const Align(
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [DecisionTimer(), ActionBar()],
                ),
              ),
              _TossLayer(onCall: _cubit.callToss),
              _ResultLayer(
                awardedXp: () => _awardedXp,
                onExit: widget.onExit,
                onPlayAgain: widget.onPlayAgain,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Toss overlay (coin call → reveal).
// ---------------------------------------------------------------------------

class _TossLayer extends StatelessWidget {
  const _TossLayer({required this.onCall});

  final ValueChanged<CoinSide> onCall;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FootballChessCubit, FootballChessState>(
      buildWhen: (p, c) =>
          (p.match?.phase == ChessMatchPhase.toss) !=
              (c.match?.phase == ChessMatchPhase.toss) ||
          p.match?.eventTick != c.match?.eventTick,
      builder: (context, state) {
        final m = state.match;
        if (m == null || m.phase != ChessMatchPhase.toss) {
          return const SizedBox.shrink();
        }
        final revealed = m.tossResult != null;
        return Positioned.fill(
          child: Container(
            color: Cyber.bg.withValues(alpha: 0.86),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  revealed ? 'TOSS' : 'CALL THE TOSS',
                  style: TextStyle(
                    fontFamily: Cyber.displayFont,
                    fontSize: 16,
                    letterSpacing: 4,
                    fontWeight: FontWeight.w700,
                    color: Cyber.muted,
                  ),
                ),
                const SizedBox(height: 20),
                if (!revealed)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CoinButton(
                        label: 'HEADS',
                        onTap: () {
                          playSound(SoundEffect.coinFlip);
                          HapticFeedback.mediumImpact();
                          onCall(CoinSide.heads);
                        },
                      ),
                      const SizedBox(width: 16),
                      _CoinButton(
                        label: 'TAILS',
                        onTap: () {
                          playSound(SoundEffect.coinFlip);
                          HapticFeedback.mediumImpact();
                          onCall(CoinSide.tails);
                        },
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      Text(
                        m.tossResult!.name.toUpperCase(),
                        style: TextStyle(
                          fontFamily: Cyber.displayFont,
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                          color: Cyber.gold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        (m.playerWonToss ?? false)
                            ? 'YOU WON THE TOSS — YOU KICK OFF'
                            : 'CPU WON THE TOSS',
                        style: Cyber.label(12).copyWith(
                          color: (m.playerWonToss ?? false)
                              ? Cyber.cyan
                              : Cyber.magenta,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CoinButton extends StatelessWidget {
  const _CoinButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Cyber.cyan.withValues(alpha: 0.2),
              Cyber.panel.withValues(alpha: 0.9),
            ],
          ),
          border: Border.all(color: Cyber.cyan.withValues(alpha: 0.85)),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          label,
          style: Cyber.label(14).copyWith(color: Cyber.cyan, letterSpacing: 2),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full-time result (delegates to the shared revamped victory screen).
// ---------------------------------------------------------------------------

class _ResultLayer extends StatelessWidget {
  const _ResultLayer({
    required this.awardedXp,
    required this.onExit,
    required this.onPlayAgain,
  });

  final int Function() awardedXp;
  final VoidCallback onExit;
  final VoidCallback onPlayAgain;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FootballChessCubit, FootballChessState>(
      buildWhen: (p, c) =>
          (p.match?.phase == ChessMatchPhase.fullTime) !=
          (c.match?.phase == ChessMatchPhase.fullTime),
      builder: (context, state) {
        final m = state.match;
        if (m == null || m.phase != ChessMatchPhase.fullTime) {
          return const SizedBox.shrink();
        }
        return FootballChessResult(
          match: m,
          awardedXp: awardedXp(),
          onExit: onExit,
          onPlayAgain: onPlayAgain,
        );
      },
    );
  }
}
