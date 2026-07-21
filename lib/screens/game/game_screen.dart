import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/game/game_state.dart';
import '../../config/enums.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import '../deck/all_cards_screen.dart';
import '../deck/deck_builder_screen.dart';
import '../home/widgets/starter_pack_onboarding.dart';
import '../home/home_screen.dart';
import '../how_to_play/how_to_play_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import 'widgets/duel_board_phase.dart';
import 'widgets/final_result_phase.dart';
import 'widgets/match_phases.dart';

class GameTabContent extends StatefulWidget {
  const GameTabContent({
    required this.onNavigate,
    this.initialSection = AppSection.home,
    super.key,
  });

  final ValueChanged<AppSection> onNavigate;

  /// Where the card-game hub opens. Defaults to the home lobby; a leaderboard
  /// CHALLENGE opens straight into [AppSection.match].
  final AppSection initialSection;

  @override
  State<GameTabContent> createState() => _GameTabContentState();
}

class _GameTabContentState extends State<GameTabContent> {
  late AppSection _gameSection = widget.initialSection;

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
    return BlocBuilder<GameBloc, GameState>(
      buildWhen: (previous, current) =>
          previous.pendingPackReveal != current.pendingPackReveal,
      builder: (context, state) {
        final packReveal = state.pendingPackReveal;
        if (packReveal != null && packReveal.items.isNotEmpty) {
          return PackOnboardingScreen(
            key: const ValueKey('game-pack-reveal'),
            reveal: packReveal,
          );
        }

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
          AppSection.leaderboard => LeaderboardScreen(
            onNavigate: _navigateGame,
          ),
          _ => HomeScreen(onNavigate: _navigateGame),
        };
      },
    );
  }
}

/// The four round-loop phases hosted by the persistent [DuelBoardPhase].
const _boardPhases = {
  MatchPhase.roleReveal,
  MatchPhase.scenario,
  MatchPhase.play,
  MatchPhase.roundResult,
};

/// Only rebuild the match flow for match-relevant state changes — wallet,
/// ledger, cosmetic and history emissions elsewhere in the app must not
/// rebuild a live board. copyWith passes list references through untouched,
/// so identity checks are an exact cheap dirty test.
bool _matchStateChanged(GameState prev, GameState curr) =>
    prev.phase != curr.phase ||
    prev.currentRound != curr.currentRound ||
    prev.playerScore != curr.playerScore ||
    prev.opponentScore != curr.opponentScore ||
    prev.playerAttacking != curr.playerAttacking ||
    prev.tossChoice != curr.tossChoice ||
    prev.tossResult != curr.tossResult ||
    prev.playerWonToss != curr.playerWonToss ||
    prev.initialAttackingChoice != curr.initialAttackingChoice ||
    prev.currentScenario != curr.currentScenario ||
    prev.selectedPlayerCard != curr.selectedPlayerCard ||
    prev.selectedActionCard != curr.selectedActionCard ||
    !identical(prev.usedPlayerCards, curr.usedPlayerCards) ||
    !identical(prev.usedActionCards, curr.usedActionCards) ||
    !identical(prev.redCardedCards, curr.redCardedCards) ||
    !identical(prev.roundResults, curr.roundResults) ||
    !identical(prev.opponentAttackers, curr.opponentAttackers) ||
    !identical(prev.opponentDefenders, curr.opponentDefenders) ||
    !identical(prev.opponentActions, curr.opponentActions) ||
    !identical(prev.opponentRedCarded, curr.opponentRedCarded) ||
    prev.opponentName != curr.opponentName ||
    !identical(prev.deckSlots, curr.deckSlots) ||
    prev.activeDeckId != curr.activeDeckId ||
    !identical(prev.deckAttackers, curr.deckAttackers) ||
    !identical(prev.deckDefenders, curr.deckDefenders) ||
    !identical(prev.deckActions, curr.deckActions) ||
    prev.deckKeeper != curr.deckKeeper ||
    !identical(prev.ownedCardIds, curr.ownedCardIds) ||
    !identical(prev.ownedActionCardIds, curr.ownedActionCardIds) ||
    prev.progression != curr.progression ||
    !identical(prev.pendingLevelUps, curr.pendingLevelUps) ||
    prev.lastMatchXP != curr.lastMatchXP ||
    prev.coins != curr.coins;

class MatchScreen extends StatefulWidget {
  const MatchScreen({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  bool _introShown = false;

  @override
  void initState() {
    super.initState();
    AudioController.instance.enterScene(AudioScene.pitchDuel);
  }

  @override
  void dispose() {
    AudioController.instance.leaveScene(AudioScene.pitchDuel);
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
      },
      buildWhen: _matchStateChanged,
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
                opponentName: state.opponentName,
                onComplete: () => setState(() => _introShown = true),
              )
            : switch (state.phase) {
                MatchPhase.toss || MatchPhase.tossResult => CoinTossPhase(
                  state: state,
                  onQuit: () => _quit(context),
                ),
                // The whole round loop lives on the persistent Duel Board —
                // role banner, scenario briefing, card placement and the
                // flip/resolve beat all play out on one two-sided screen.
                MatchPhase.roleReveal ||
                MatchPhase.scenario ||
                MatchPhase.play ||
                MatchPhase.roundResult => DuelBoardPhase(
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
        final switcher = AnimatedSwitcher(
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
            key: showIntro
                ? const ValueKey('intro')
                // The coin toss and its result share one persistent widget so the
                // single coin survives the toss → tossResult transition.
                : (state.phase == MatchPhase.toss ||
                      state.phase == MatchPhase.tossResult)
                ? const ValueKey('coinToss')
                // All four round-loop phases share the persistent Duel Board —
                // the AnimatedSwitcher must never cross-fade between beats.
                : _boardPhases.contains(state.phase)
                ? const ValueKey('board')
                : ValueKey(state.phase),
            child: phaseWidget,
          ),
        );
        return switcher;
      },
    );
  }

  Future<void> _quit(BuildContext context) async {
    final gameBloc = context.read<GameBloc>();
    final phase = gameBloc.state.phase;
    final matchInProgress =
        phase != MatchPhase.idle && phase != MatchPhase.finalResult;

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
