import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/super_over/super_over_bloc.dart';
import '../../blocs/super_over/super_over_event.dart';
import '../../blocs/super_over/super_over_state.dart';
import '../../config/theme.dart';

import '../../games/super_over/super_over_game.dart';
import '../../models/super_over.dart';
import '../../models/super_over_stats.dart';
import '../../services/secure_storage_service.dart';
import '../../utils/sound_effects.dart';
import '../deck/cricket_deck_builder_screen.dart';
import 'super_over_lobby_screen.dart';
import 'widgets/effects_overlay.dart';
import 'widgets/super_over_overlays.dart';
import 'widgets/super_over_result.dart';

class SuperOverHub extends StatelessWidget {
  const SuperOverHub({required this.onNavigate, super.key});

  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SuperOverBloc(SecureGameStorage()),
      child: _SuperOverRouter(onNavigate: onNavigate),
    );
  }
}

class _SuperOverRouter extends StatefulWidget {
  const _SuperOverRouter({required this.onNavigate});

  final ValueChanged<String> onNavigate;

  @override
  State<_SuperOverRouter> createState() => _SuperOverRouterState();
}

class _SuperOverRouterState extends State<_SuperOverRouter> {
  late SuperOverGame _game;
  bool _inLobby = true;
  bool _editingDeck = false;
  bool _rewardsDispatched = false;
  bool _showResult = false;
  SuperOverStats _stats = const SuperOverStats();
  CricketJersey _jersey = CricketJersey.mumbai;
  Timer? _targetRevealTimer;
  Timer? _nextBallTimer;
  int? _scheduledRevealBall;

  @override
  void initState() {
    super.initState();
    _game = SuperOverGame(
      initialState: context.read<SuperOverBloc>().state,
      onPhaseChanged: (phase) {
        if (!mounted) return;
        context.read<SuperOverBloc>().add(SuperOverPhaseChanged(phase));
      },
      onInputArmed: () {
        if (!mounted) return;
        context.read<SuperOverBloc>().add(const SuperOverInputArmed());
      },
      onSwingLocked: () {
        if (!mounted) return;
        context.read<SuperOverBloc>().add(const SuperOverSwingLocked());
      },
      onShotResolved: (timingErrorMs) {
        if (!mounted) return;
        context.read<SuperOverBloc>().add(
          SuperOverShotResolved(timingErrorMs: timingErrorMs),
        );
      },
      onOutcomeAnimationComplete: _handleOutcomeAnimationComplete,
    );
    _loadStats();
  }

  @override
  void dispose() {
    _targetRevealTimer?.cancel();
    _nextBallTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final stats = await SecureGameStorage().loadSuperOverStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _jersey = stats.lastJersey;
      });
    }
  }

  void _selectJersey(CricketJersey jersey) {
    if (jersey == _jersey) return;
    setState(() => _jersey = jersey);
    final updated = _stats.copyWith(lastJersey: jersey);
    _stats = updated;
    SecureGameStorage().saveSuperOverStats(updated);
  }

  void _scheduleFirstBall(SuperOverState state) {
    if (_scheduledRevealBall == state.ballsFaced &&
        (_targetRevealTimer?.isActive ?? false)) {
      return;
    }
    _scheduledRevealBall = state.ballsFaced;
    _targetRevealTimer?.cancel();
    _targetRevealTimer = Timer(const Duration(milliseconds: 1150), () {
      if (!mounted) return;
      _targetRevealTimer = null;
      _scheduledRevealBall = null;
      final current = context.read<SuperOverBloc>().state;
      if (current.isOver) return;
      context.read<SuperOverBloc>().add(const SuperOverNextBallRequested());
    });
  }

  void _handleOutcomeAnimationComplete() {
    if (!mounted) return;
    final state = context.read<SuperOverBloc>().state;
    if (state.isOver) {
      setState(() => _showResult = true);
      return;
    }
    _nextBallTimer?.cancel();
    _nextBallTimer = Timer(const Duration(milliseconds: 360), () {
      if (!mounted) return;
      context.read<SuperOverBloc>().add(const SuperOverNextBallRequested());
    });
  }

  void _handleBatTap() {
    final state = context.read<SuperOverBloc>().state;
    if (state.phase == SuperOverPhase.targetReveal) {
      _targetRevealTimer?.cancel();
      _targetRevealTimer = null;
      _scheduledRevealBall = null;
      context.read<SuperOverBloc>().add(const SuperOverNextBallRequested());
      return;
    }
    if (!state.canTap) return;
    playSound(SoundEffect.commit);
    HapticFeedback.lightImpact();
    _game.tapBat();
  }

  void _playOutcomeFeedback(SuperOverState state) {
    switch (state.lastOutcome) {
      case ShotOutcome.six:
        playSound(SoundEffect.goal);
        playSound(SoundEffect.cheering);
        HapticFeedback.heavyImpact();
      case ShotOutcome.four:
        playSound(SoundEffect.cardSlam);
        playSound(SoundEffect.cheering);
        HapticFeedback.mediumImpact();
      case ShotOutcome.caught || ShotOutcome.bowled:
        playSound(SoundEffect.redCard);
        HapticFeedback.heavyImpact();
      case ShotOutcome.one || ShotOutcome.two || ShotOutcome.three:
        playSound(SoundEffect.cardSelect);
        HapticFeedback.selectionClick();
      case ShotOutcome.dot:
        playSound(SoundEffect.whoosh);
      case null:
        break;
    }
  }

  void _startGame() {
    _rewardsDispatched = false;
    _showResult = false;
    _scheduledRevealBall = null;
    _targetRevealTimer?.cancel();
    _nextBallTimer?.cancel();
    setState(() => _inLobby = false);
    final gameState = context.read<GameBloc>().state;
    context.read<SuperOverBloc>().add(SuperOverJerseySelected(_jersey));
    context.read<SuperOverBloc>().add(
      SuperOverStarted(
        battingOrder: gameState.deckBatsmen,
        mode: SuperOverMode.chase,
        playerLevel: gameState.progression.playerLevel,
      ),
    );
  }

  void _exitGame() {
    widget.onNavigate('predictions');
  }

  @override
  Widget build(BuildContext context) {
    if (_editingDeck) {
      return CricketDeckBuilderScreen(
        onBack: () => setState(() => _editingDeck = false),
        onPlaySuperOver: () {
          setState(() => _editingDeck = false);
          _startGame();
        },
      );
    }

    if (_inLobby) {
      return SuperOverLobbyScreen(
        onBack: _exitGame,
        onStartGame: _startGame,
        onEditDeck: () => setState(() => _editingDeck = true),
        onJerseySelected: _selectJersey,
        stats: _stats,
      );
    }

    return Scaffold(
      backgroundColor: Cyber.bg,
      body: BlocConsumer<SuperOverBloc, SuperOverState>(
        listenWhen: (previous, current) =>
            previous.phase != current.phase ||
            previous.isOver != current.isOver ||
            previous.lastOutcome != current.lastOutcome,
        listener: (context, state) {
          _game.syncState(state);
          if (state.phase == SuperOverPhase.targetReveal) {
            _scheduleFirstBall(state);
          } else if (state.phase == SuperOverPhase.ballSetup) {
            _game.startDelivery(state);
          }

          if (state.lastOutcome != null) {
            _playOutcomeFeedback(state);
          }

          if (state.isOver && state.ballsFaced > 0 && !_rewardsDispatched) {
            _rewardsDispatched = true;
            final base = 10;
            final runXp = state.score;
            final sixXp =
                state.wagonWheel.where((s) => s == ShotOutcome.six).length * 4;
            final winXp = state.wonChase == true ? 15 : 0;
            context.read<GameBloc>().add(
              SuperOverFinished(
                runs: state.score,
                wickets: state.wickets,
                wonChase: state.wonChase,
                xp: base + runXp + sixXp + winXp,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.phase == SuperOverPhase.targetReveal) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final current = context.read<SuperOverBloc>().state;
              if (current.phase != SuperOverPhase.targetReveal) return;
              _game.syncState(current);
              _scheduleFirstBall(current);
            });
          }
          return Stack(
            children: [
              Positioned.fill(child: GameWidget(game: _game)),
              Positioned.fill(child: EffectsOverlay(state: state)),
              if (!state.isOver)
                Positioned.fill(
                  child: SuperOverOverlays(
                    state: state,
                    onBatTap: _handleBatTap,
                    onExit: _exitGame,
                  ),
                ),
              if (state.isOver && _showResult)
                Positioned.fill(
                  child: SuperOverResult(
                    state: state,
                    previousHigh: _stats.highScore,
                    onPlayAgain: () {
                      context.read<SuperOverBloc>().add(const SuperOverReset());
                      _loadStats();
                      setState(() {
                        _showResult = false;
                        _inLobby = true;
                      });
                    },
                    onExit: _exitGame,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
