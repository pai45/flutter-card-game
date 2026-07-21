import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/shootout/shootout_bloc.dart';
import '../../blocs/shootout/shootout_state.dart';
import '../../config/enums.dart';
import '../../data/random_opponent_names.dart';
import '../../models/cards.dart';
import '../../models/progression.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import 'widgets/shootout_lineup_phase.dart';
import 'widgets/shootout_opponent_reveal_phase.dart';
import 'widgets/shootout_phase.dart';
import 'widgets/shootout_result_phase.dart';

/// Standalone Penalty Shootout mode: the active match deck's five players
/// (2 ATK + 2 DEF + keeper) trade kicks with a level-scaled opponent squad.
class ShootoutScreen extends StatefulWidget {
  const ShootoutScreen({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  State<ShootoutScreen> createState() => _ShootoutScreenState();
}

class _ShootoutScreenState extends State<ShootoutScreen> {
  /// Bumped on PLAY AGAIN so the provider key rebuilds a fresh bloc
  /// (and re-rolls the opponent name + squad).
  int _session = 0;
  bool _finishDispatched = false;
  bool _suddenDeathSounded = false;

  @override
  void initState() {
    super.initState();
    AudioController.instance.enterScene(AudioScene.shootout);
  }

  @override
  void dispose() {
    AudioController.instance.leaveScene(AudioScene.shootout);
    super.dispose();
  }

  ShootoutBloc _createBloc(BuildContext context) {
    final game = context.read<GameBloc>().state;
    // deckReady (the entry gate) guarantees a keeper; fall back defensively.
    final keeper = game.deckKeeper ?? goalkeepers.first;
    final level = game.progression.playerLevel;
    final rng = Random();
    final opponentName = randomOpponentName(random: rng);
    final cpu = generateShootoutOpponent(
      level,
      attackers,
      defenders,
      goalkeepers,
      random: rng,
    );
    return ShootoutBloc(
      playerShooters: [...game.deckAttackers, ...game.deckDefenders, keeper],
      playerKeeper: keeper,
      cpuShooters: cpu.shooters,
      cpuKeeper: cpu.keeper,
      cpuLevel: level,
      opponentName: opponentName,
    );
  }

  void _restart() {
    setState(() {
      _session++;
      _finishDispatched = false;
      _suddenDeathSounded = false;
    });
  }

  void _goHome() => widget.onNavigate(AppSection.home);

  Future<void> _quit(BuildContext context) async {
    final s = context.read<ShootoutBloc>().state;
    final inProgress =
        !s.over &&
        s.stage != ShootoutStage.opponentReveal &&
        s.stage != ShootoutStage.lineup &&
        s.stage != ShootoutStage.summary;

    if (inProgress) {
      final confirmed = await showCyberConfirmDialog(
        context,
        title: 'Quit Shootout?',
        message: 'Your current shootout progress will be lost.',
        confirmLabel: 'Quit',
        cancelLabel: 'Keep Playing',
        destructive: true,
      );
      if (!mounted || !confirmed) return;
    }
    _goHome();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ShootoutBloc>(
      key: ValueKey('shootout-session-$_session'),
      create: _createBloc,
      child: BlocConsumer<ShootoutBloc, ShootoutState>(
        listener: (context, state) {
          if (state.suddenDeath && !_suddenDeathSounded) {
            _suddenDeathSounded = true;
            playSound(SoundEffect.penaltySuddenDeath);
          }
          // Award XP/coins/history through GameBloc exactly once per shootout.
          if (state.over && !_finishDispatched) {
            _finishDispatched = true;
            context.read<GameBloc>().add(
              ShootoutFinished(
                playerGoals: state.playerScore,
                cpuGoals: state.opponentScore,
              ),
            );
          }
        },
        builder: (context, state) {
          final Widget phaseWidget = switch (state.stage) {
            ShootoutStage.opponentReveal => ShootoutOpponentRevealPhase(
              state: state,
              onQuit: () => _quit(context),
            ),
            ShootoutStage.lineup => ShootoutLineupPhase(
              state: state,
              onQuit: () => _quit(context),
            ),
            ShootoutStage.choose || ShootoutStage.result => ShootoutPhase(
              state: state,
              onQuit: () => _quit(context),
            ),
            ShootoutStage.summary => ShootoutResultPhase(
              state: state,
              onPlayAgain: _restart,
              onHome: _goHome,
            ),
          };

          final reduceMotion = MediaQuery.of(context).disableAnimations;
          return AnimatedSwitcher(
            duration: Duration(milliseconds: reduceMotion ? 120 : 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              if (reduceMotion) {
                return FadeTransition(opacity: animation, child: child);
              }
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              // The choose and result beats share one persistent widget so
              // the kick loop doesn't crossfade between every kick.
              key: switch (state.stage) {
                ShootoutStage.opponentReveal => const ValueKey(
                  'opponent-reveal',
                ),
                ShootoutStage.lineup => const ValueKey('lineup'),
                ShootoutStage.choose ||
                ShootoutStage.result => const ValueKey('kicks'),
                ShootoutStage.summary => const ValueKey('summary'),
              },
              child: phaseWidget,
            ),
          );
        },
      ),
    );
  }
}
