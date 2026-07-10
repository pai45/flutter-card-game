import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/basketball/basketball_cubit.dart';
import '../../config/enums.dart';
import '../../services/secure_storage_service.dart';
import '../deck/basketball_deck_builder_screen.dart';
import 'basketball_lobby_screen.dart';

/// Standalone Hoop Duel shell — the Basketball tab's first game. Owns the
/// mode's cubit; the lobby swaps to a basketball roster-deck builder when
/// editing, and app-level navigation is delegated up via [onNavigate].
class BasketballTabContent extends StatelessWidget {
  const BasketballTabContent({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BasketballCubit(SecureGameStorage())..load(),
      child: _BasketballRouter(onNavigate: onNavigate),
    );
  }
}

class _BasketballRouter extends StatefulWidget {
  const _BasketballRouter({required this.onNavigate});

  final ValueChanged<AppSection> onNavigate;

  @override
  State<_BasketballRouter> createState() => _BasketballRouterState();
}

class _BasketballRouterState extends State<_BasketballRouter> {
  bool _editingDeck = false;

  @override
  Widget build(BuildContext context) {
    if (_editingDeck) {
      return BasketballDeckBuilderScreen(
        onBack: () => setState(() => _editingDeck = false),
        onPlayHoopDuel: () => setState(() => _editingDeck = false),
      );
    }

    return BasketballLobbyScreen(
      onNavigate: widget.onNavigate,
      onEditDeck: () => setState(() => _editingDeck = true),
    );
  }
}
