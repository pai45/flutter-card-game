import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/football_chess/football_chess_cubit.dart';
import '../../config/enums.dart';
import '../../services/secure_storage_service.dart';
import '../deck/all_cards_screen.dart';
import '../deck/deck_builder_screen.dart';
import 'football_chess_lobby_screen.dart';

/// Standalone 5v5 Football Chess shell — manages internal section routing
/// (lobby → deck builder → all cards) while delegating app-level navigation
/// (predictions, leaderboard, shop, profile) up to [onNavigate].
///
/// Mirrors the `GameTabContent` routing pattern from `game_screen.dart`.
class FootballChessTabContent extends StatefulWidget {
  const FootballChessTabContent({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  State<FootballChessTabContent> createState() =>
      _FootballChessTabContentState();
}

class _FootballChessTabContentState extends State<FootballChessTabContent> {
  AppSection _section = AppSection.home;

  static const _appLevel = {
    AppSection.predictions,
    AppSection.leaderboard,
    AppSection.shop,
    AppSection.profile,
  };

  void _navigate(AppSection section) {
    if (_appLevel.contains(section)) {
      widget.onNavigate(section);
      return;
    }
    setState(() {
      _section = switch (section) {
        // PLAY button in the deck builder returns to the chess lobby,
        // not the Pitch Duel card-game match screen.
        AppSection.match => AppSection.home,
        AppSection.game => AppSection.home,
        _ => section,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FootballChessCubit(SecureGameStorage())..load(),
      child: switch (_section) {
        AppSection.deck => DeckBuilderScreen(onNavigate: _navigate),
        AppSection.allCards => AllCardsScreen(onNavigate: _navigate),
        _ => FootballChessLobbyScreen(onNavigate: _navigate),
      },
    );
  }
}
