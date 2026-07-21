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
import '../../utils/game_audio_mappings.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_toss_coin.dart';
import '../../widgets/spotlight_walkthrough.dart';
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
  bool _walkthroughShown = false;

  final _boardKey = GlobalKey();
  final _timerKey = GlobalKey();
  final _topKey = GlobalKey();
  final _tossKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _cubit = context.read<FootballChessCubit>();
    _game = FootballChessGame(
      match: _cubit.state.match!,
      onCellTapped: _onCellTapped,
    );
    AudioController.instance.enterScene(AudioScene.footballChess);
  }

  @override
  void dispose() {
    AudioController.instance.leaveScene(AudioScene.footballChess);
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
        final gameBloc = context.read<GameBloc>();
        if (!_walkthroughShown &&
            !gameBloc.state.tutorialSeen.contains('football-chess-first')) {
          _walkthroughShown = true;
          _showWalkthrough();
        }
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
    final cue = chessEventSound(event);
    if (cue != null && event != BoardEvent.goal) playSound(cue);
    if (event == BoardEvent.turnover || event == BoardEvent.blocked) {
      HapticFeedback.selectionClick();
    }
  }

  void _onFullTime(ChessMatch m) {
    if (_xpDispatched) return;
    _xpDispatched = true;
    AudioController.instance.stopLoop();
    playSound(SoundEffect.chessFullTime);
    playSound(
      m.isDraw
          ? SoundEffect.matchDraw
          : m.playerWon
          ? SoundEffect.matchWin
          : SoundEffect.matchLose,
    );
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

  void _showWalkthrough() {
    _cubit.setPaused(true);
    AudioController.instance.setSceneMusicEnabled(false);
    showSpotlightWalkthrough(
      context,
      keyName: 'football-chess-first',
      steps: [
        SpotlightStep(
          targetKey: _tossKey,
          title: 'The Coin Toss',
          body:
              'Call the toss to see who gets to kickoff and attack first. Good luck!',
          icon: Icons.monetization_on,
          accent: Cyber.gold,
        ),
        SpotlightStep(
          targetKey: _timerKey,
          title: 'The Clock is Ticking',
          body:
              'You have 2 minutes to score before the game ends. Use your time wisely!',
          icon: Icons.timer,
          accent: Cyber.lime,
        ),
        SpotlightStep(
          targetKey: _boardKey,
          title: 'On the Attack',
          body:
              'When you have the ball, tap your player to MOVE, DRIBBLE, PASS, or SHOOT. Tap an empty square to execute.',
          icon: Icons.flash_on,
          accent: Cyber.cyan,
        ),
        SpotlightStep(
          targetKey: _boardKey,
          title: 'On the Defense',
          body:
              'When defending, select your player to PRESS, TACKLE, or SLIDE. Win the ball back before they score!',
          icon: Icons.shield,
          accent: Cyber.danger,
        ),
        SpotlightStep(
          targetKey: _topKey,
          title: 'Turn Based Action',
          body:
              'The CPU plays immediately after your turn. Watch their moves closely!',
          icon: Icons.smart_toy,
          accent: Cyber.violet,
        ),
      ],
      onComplete: () {
        _cubit.setPaused(false);
        AudioController.instance.setSceneMusicEnabled(true);
        context.read<GameBloc>().add(
          TutorialSeenMarked('football-chess-first'),
        );
      },
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
              Positioned.fill(
                child: SpotlightTarget(
                  spotlightKey: _boardKey,
                  child: GameWidget(game: _game),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SpotlightTarget(
                      spotlightKey: _topKey,
                      child: ChessHud(onExit: widget.onExit),
                    ),
                    const LastActionBanner(),
                  ],
                ),
              ),
              const Align(child: CentreFlash()),
              const OpponentActionToast(),
              Align(
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SpotlightTarget(
                      spotlightKey: _timerKey,
                      child: const DecisionTimer(),
                    ),
                    const ActionBar(),
                  ],
                ),
              ),
              _TossLayer(tossKey: _tossKey, onCall: _cubit.callToss),
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
  const _TossLayer({required this.tossKey, required this.onCall});

  final GlobalKey tossKey;
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
                SpotlightTarget(
                  spotlightKey: tossKey,
                  child: Text(
                    revealed ? 'TOSS RESULT' : 'CALL THE TOSS',
                    style: TextStyle(
                      fontFamily: Cyber.displayFont,
                      fontSize: 16,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w700,
                      color: Cyber.muted,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                CyberTossCoin(
                  result: revealed ? m.tossResult!.name : null,
                  won: m.playerWonToss,
                ),
                const SizedBox(height: 32),
                if (!revealed)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: CyberCallChoiceButton(
                          face: 'H',
                          label: 'HEADS',
                          accent: Cyber.cyan,
                          onTap: () {
                            playSound(SoundEffect.coinFlip);
                            HapticFeedback.mediumImpact();
                            onCall(CoinSide.heads);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: CyberCallChoiceButton(
                          face: 'T',
                          label: 'TAILS',
                          accent: const Color(0xFFC084FC),
                          onTap: () {
                            playSound(SoundEffect.coinFlip);
                            HapticFeedback.mediumImpact();
                            onCall(CoinSide.tails);
                          },
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    (m.playerWonToss ?? false)
                        ? 'YOU WON THE TOSS — YOU KICK OFF'
                        : 'CPU WON THE TOSS',
                    style: Cyber.label(12).copyWith(
                      color: (m.playerWonToss ?? false)
                          ? Cyber.cyan
                          : Cyber.danger,
                      letterSpacing: 1.6,
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
