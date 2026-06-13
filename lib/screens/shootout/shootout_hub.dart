import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_state.dart';
import '../../config/enums.dart';
import '../deck/all_cards_screen.dart';
import '../deck/deck_builder_screen.dart';
import '../home/widgets/starter_pack_onboarding.dart';
import 'shootout_home_screen.dart';
import 'shootout_screen.dart';

/// Standalone Penalty Shootout game shell — the sibling of [GameTabContent]
/// for Pitch Duel. Routes between the shootout lobby, the deck builder (the
/// squad is shared with Pitch Duel) and the shootout gameplay.
class ShootoutTabContent extends StatefulWidget {
  const ShootoutTabContent({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  State<ShootoutTabContent> createState() => _ShootoutTabContentState();
}

class _ShootoutTabContentState extends State<ShootoutTabContent> {
  AppSection _section = AppSection.home;

  // App-level destinations leave the game and switch the main shell;
  // everything else navigates within the shootout hub.
  static const _appLevel = {
    AppSection.predictions,
    AppSection.leaderboard,
    AppSection.shop,
    AppSection.profile,
  };

  void _navigate(AppSection section) {
    if (_appLevel.contains(section)) {
      widget.onNavigate(section);
    } else {
      setState(
        () => _section = (section == AppSection.game || section == AppSection.match)
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
            key: const ValueKey('shootout-pack-reveal'),
            reveal: packReveal,
          );
        }

        return switch (_section) {
          AppSection.deck => DeckBuilderScreen(onNavigate: _navigate),
          AppSection.allCards => AllCardsScreen(onNavigate: _navigate),
          AppSection.shootout => ShootoutScreen(onNavigate: _navigate),
          _ => ShootoutHomeScreen(
            onNavigate: _navigate,
            onBack: () => widget.onNavigate(AppSection.predictions),
          ),
        };
      },
    );
  }
}
