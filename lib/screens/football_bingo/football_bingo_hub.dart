import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/football_bingo/football_bingo_cubit.dart';
import '../../blocs/football_bingo/football_bingo_state.dart';
import '../../config/enums.dart';
import '../../services/secure_storage_service.dart';
import 'football_bingo_home_screen.dart';
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

  Future<void> _openDay(BuildContext context, String dayKey) async {
    await context.read<FootballBingoCubit>().openDay(dayKey);
    if (!mounted) return;
    setState(() => _showGrid = true);
  }

  void _backHome() => setState(() => _showGrid = false);

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
          return FootballBingoHomeScreen(
            state: state,
            onBack: () => widget.onNavigate(AppSection.predictions),
            onOpenDay: (dayKey) => _openDay(context, dayKey),
          );
        },
      ),
    );
  }
}
