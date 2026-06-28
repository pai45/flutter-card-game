import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/football_bingo/football_bingo_cubit.dart';
import '../../blocs/football_bingo/football_bingo_state.dart';
import '../../config/enums.dart';
import '../../services/secure_storage_service.dart';
import 'football_bingo_home_screen.dart';
import 'football_bingo_logs_screen.dart';
import 'football_bingo_screen.dart';

class FootballBingoTabContent extends StatefulWidget {
  const FootballBingoTabContent({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  State<FootballBingoTabContent> createState() =>
      _FootballBingoTabContentState();
}

class _FootballBingoTabContentState extends State<FootballBingoTabContent> {
  bool _showGrid = false;
  bool _showLogs = false;

  Future<void> _openDay(BuildContext context, String dayKey) async {
    await context.read<FootballBingoCubit>().openDay(dayKey);
    if (!mounted) return;
    setState(() {
      _showGrid = true;
      _showLogs = false;
    });
  }

  void _backHome() => setState(() => _showGrid = false);
  void _openLogs() => setState(() => _showLogs = true);
  void _closeLogs() => setState(() => _showLogs = false);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FootballBingoCubit(SecureGameStorage())..load(),
      child: BlocBuilder<FootballBingoCubit, FootballBingoState>(
        builder: (context, state) {
          if (_showGrid) {
            return FootballBingoScreen(
              onBack: _backHome,
              onCompleted: _backHome,
            );
          }
          if (_showLogs) {
            return FootballBingoLogsScreen(
              state: state,
              onBack: _closeLogs,
              onOpenDay: (dayKey) => _openDay(context, dayKey),
            );
          }
          return FootballBingoHomeScreen(
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
