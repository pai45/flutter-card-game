import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/game/game_state.dart';
import '../../config/enums.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import '../deck/all_cards_screen.dart';
import '../deck/deck_builder_screen.dart';
import '../home/home_screen.dart';
import '../how_to_play/how_to_play_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import 'widgets/final_result_phase.dart';
import 'widgets/match_phases.dart';
import 'widgets/penalty_phase.dart';

class GameTabContent extends StatefulWidget {
  const GameTabContent({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  State<GameTabContent> createState() => _GameTabContentState();
}

class _GameTabContentState extends State<GameTabContent> {
  AppSection _gameSection = AppSection.home;

  // App-level destinations leave the card game and switch the main shell;
  // everything else navigates within the card-game hub.
  static const _appLevel = {
    AppSection.predictions,
    AppSection.leaderboard,
    AppSection.shop,
    AppSection.profile,
  };

  void _navigateGame(AppSection section) {
    if (_appLevel.contains(section)) {
      widget.onNavigate(section);
    } else {
      setState(
        () => _gameSection = section == AppSection.game
            ? AppSection.home
            : section,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_gameSection) {
      AppSection.home => HomeScreen(
        onNavigate: _navigateGame,
        showBottomNavigation: false,
        onBack: () => widget.onNavigate(AppSection.predictions),
      ),
      AppSection.deck => DeckBuilderScreen(onNavigate: _navigateGame),
      AppSection.howToPlay => HowToPlayScreen(onNavigate: _navigateGame),
      AppSection.match => MatchScreen(onNavigate: _navigateGame),
      AppSection.allCards => AllCardsScreen(onNavigate: _navigateGame),
      AppSection.leaderboard => LeaderboardScreen(onNavigate: _navigateGame),
      _ => HomeScreen(onNavigate: _navigateGame),
    };
  }
}

class MatchScreen extends StatefulWidget {
  const MatchScreen({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  Timer? cpuTossTimer;
  bool _introShown = false;

  @override
  void dispose() {
    cpuTossTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GameBloc, GameState>(
      listener: (context, state) {
        if (state.phase == MatchPhase.scenario &&
            state.currentScenario == null) {
          context.read<GameBloc>().add(ScenarioShown());
        }
        if (state.phase == MatchPhase.tossResult &&
            state.playerWonToss == false) {
          cpuTossTimer?.cancel();
          cpuTossTimer = Timer(const Duration(milliseconds: 900), () {
            if (!mounted) return;
            context.read<GameBloc>().add(RoleChosen(Random().nextBool()));
          });
        }
      },
      builder: (context, state) {
        final showIntro = state.phase == MatchPhase.toss && !_introShown;
        final deckName = state.deckSlots.isNotEmpty
            ? state.deckSlots
                  .firstWhere(
                    (s) => s.id == state.activeDeckId,
                    orElse: () => state.deckSlots.first,
                  )
                  .name
            : 'Squad';

        final Widget phaseWidget = showIntro
            ? MatchIntroPhase(
                deckName: deckName,
                onComplete: () => setState(() => _introShown = true),
              )
            : switch (state.phase) {
                MatchPhase.toss => TossPhase(
                  state: state,
                  onQuit: () => _quit(context),
                ),
                MatchPhase.tossResult => TossResultPhase(
                  state: state,
                  onQuit: () => _quit(context),
                ),
                MatchPhase.scenario => ScenarioPhase(
                  state: state,
                  onQuit: () => _quit(context),
                ),
                MatchPhase.play => PlayPhase(
                  state: state,
                  onQuit: () => _quit(context),
                ),
                MatchPhase.roundResult => RoundResultPhase(
                  state: state,
                  onQuit: () => _quit(context),
                ),
                MatchPhase.matchEnd => MatchEndPhase(
                  state: state,
                  onQuit: () => _quit(context),
                ),
                MatchPhase.penalty => PenaltyPhase(
                  state: state,
                  onQuit: () => _quit(context),
                ),
                MatchPhase.finalResult => FinalResultPhase(
                  state: state,
                  onNavigate: widget.onNavigate,
                ),
                MatchPhase.idle => GameScaffold(
                  title: 'Match',
                  subtitle: '// Match Terminal',
                  grain: true,
                  leading: IconButton(
                    onPressed: () => _quit(context),
                    icon: const Icon(Icons.close),
                  ),
                  child: Center(
                    child: CyberCtaButton(
                      label: state.deckReady ? 'Start Match' : 'Deck Required',
                      primary: true,
                      onPressed: state.deckReady
                          ? () => context.read<GameBloc>().add(MatchStarted())
                          : null,
                    ),
                  ),
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
            key: showIntro ? const ValueKey('intro') : ValueKey(state.phase),
            child: phaseWidget,
          ),
        );
      },
    );
  }

  Future<void> _quit(BuildContext context) async {
    final gameBloc = context.read<GameBloc>();
    final phase = gameBloc.state.phase;
    final matchInProgress =
        phase != MatchPhase.idle &&
        phase != MatchPhase.finalResult &&
        phase != MatchPhase.matchEnd;

    if (matchInProgress) {
      final confirmed = await showCyberConfirmDialog(
        context,
        title: 'Quit Match?',
        message: 'Your current match progress will be lost.',
        confirmLabel: 'Quit',
        cancelLabel: 'Keep Playing',
        destructive: true,
      );
      if (!mounted || !confirmed) return;
    }

    gameBloc.add(MatchReset());
    widget.onNavigate(AppSection.home);
  }
}
