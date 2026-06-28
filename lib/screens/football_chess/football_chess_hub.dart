import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/football_chess/football_chess_cubit.dart';
import '../../config/enums.dart';
import '../../services/secure_storage_service.dart';
import 'football_chess_lobby_screen.dart';

/// Standalone 5v5 Football Chess shell — the sibling of `GameTabContent`,
/// `ShootoutTabContent` and `QuizTabContent`, launched as a full-screen flow
/// from the GAMES tab. Owns the [FootballChessCubit] so the lobby can show
/// lifetime stats and the match route can read live state via `BlocProvider.value`.
class FootballChessTabContent extends StatelessWidget {
  const FootballChessTabContent({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FootballChessCubit(SecureGameStorage())..load(),
      child: FootballChessLobbyScreen(
        onBack: () => onNavigate(AppSection.predictions),
      ),
    );
  }
}
