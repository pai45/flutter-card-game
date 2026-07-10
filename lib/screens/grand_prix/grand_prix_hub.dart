import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/grand_prix/grand_prix_cubit.dart';
import '../../config/enums.dart';
import '../../services/secure_storage_service.dart';
import 'grand_prix_lobby_screen.dart';

/// Standalone Grand Prix Dash shell — the F1 tab's first game. Owns the mode's
/// cubit; the lobby is the only hub section (races are pushed routes), and
/// app-level navigation is delegated up via [onNavigate]. No deck, no starter
/// pack: the car is cosmetic (mirrors the quiz/bingo deck-free modes).
class GrandPrixTabContent extends StatelessWidget {
  const GrandPrixTabContent({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GrandPrixCubit(SecureGameStorage())..load(),
      child: GrandPrixLobbyScreen(onNavigate: onNavigate),
    );
  }
}
