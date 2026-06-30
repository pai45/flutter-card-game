import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/guess_player/guess_player_cubit.dart';
import '../../config/enums.dart';
import '../../models/cards.dart';
import '../../services/secure_storage_service.dart';
import 'guess_player_home_screen.dart';
import 'guess_player_logs_screen.dart';
import 'guess_player_screen.dart';

class GuessPlayerTabContent extends StatefulWidget {
  const GuessPlayerTabContent({
    required this.onNavigate,
    required this.allPlayers,
    super.key,
  });

  final ValueChanged<AppSection> onNavigate;
  final List<PlayerCard> allPlayers;

  @override
  State<GuessPlayerTabContent> createState() => _GuessPlayerTabContentState();
}

class _GuessPlayerTabContentState extends State<GuessPlayerTabContent> {
  bool _showGame = false;
  bool _showLogs = false;

  Future<void> _openDay(BuildContext context, String dayKey) async {
    await context.read<GuessPlayerCubit>().openDay(dayKey);
    if (!mounted) return;
    setState(() {
      _showGame = true;
      _showLogs = false;
    });
  }

  void _backHome() => setState(() => _showGame = false);
  void _openLogs() => setState(() => _showLogs = true);
  void _closeLogs() => setState(() => _showLogs = false);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GuessPlayerCubit(
        allPlayers: widget.allPlayers,
        storage: SecureGameStorage(),
      )..load(),
      child: BlocBuilder<GuessPlayerCubit, GuessPlayerState>(
        builder: (context, state) {
          if (_showGame) {
            return GuessPlayerScreen(onBack: _backHome);
          }
          if (_showLogs) {
            return GuessPlayerLogsScreen(
              state: state,
              onBack: _closeLogs,
              onOpenDay: (dayKey) => _openDay(context, dayKey),
            );
          }
          return GuessPlayerHomeScreen(
            state: state,
            onBack: () => widget.onNavigate(AppSection.predictions),
            onOpenDay: (dayKey) => _openDay(context, dayKey),
            onOpenLogs: _openLogs,
          );
        },
      ),
    );
  }
}
