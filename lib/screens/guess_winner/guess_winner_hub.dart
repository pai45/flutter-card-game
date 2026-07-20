import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/guess_winner/guess_winner_cubit.dart';
import '../../config/enums.dart';
import '../../config/theme.dart';
import '../../data/tennis_guess_data.dart';
import '../../models/daily_mystery.dart';
import '../../services/secure_storage_service.dart';
import '../../widgets/cyber/daily_mystery_widgets.dart';
import 'guess_winner_home_screen.dart';
import 'guess_winner_logs_screen.dart';
import 'guess_winner_screen.dart';

class GuessWinnerTabContent extends StatefulWidget {
  const GuessWinnerTabContent({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  State<GuessWinnerTabContent> createState() => _GuessWinnerTabContentState();
}

class _GuessWinnerTabContentState extends State<GuessWinnerTabContent>
    with WidgetsBindingObserver {
  late final GuessWinnerCubit _cubit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cubit = GuessWinnerCubit(
      grandSlams: grandSlams,
      allPlayers: tennisPlayers,
      storage: SecureGameStorage(),
    )..load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cubit.refreshForCurrentDay();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cubit.close();
    super.dispose();
  }

  void _backToGames() => widget.onNavigate(AppSection.predictions);

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<GuessWinnerCubit, GuessWinnerState>(
        builder: (context, state) {
          final child = switch (state.viewMode) {
            DailyMysteryViewMode.home => GuessWinnerHomeScreen(
              state: state,
              onBack: _backToGames,
              onOpenToday: _cubit.openToday,
              onOpenLogs: _cubit.showLogs,
              onRetry: _cubit.load,
            ),
            DailyMysteryViewMode.play => GuessWinnerScreen(
              onBack: _cubit.showHome,
            ),
            DailyMysteryViewMode.logs => GuessWinnerLogsScreen(
              state: state,
              onBack: _cubit.showHome,
              onOpenDay: _cubit.openDay,
            ),
            DailyMysteryViewMode.review => DailyMysteryDebrief(
              title: 'CHAMPION DEBRIEF',
              subtitle: state.activeDayKey,
              won: state.gameState == GuessWinnerGameState.won,
              freshResult: state.freshResult,
              answer: state.targetGrandSlam.winnerName,
              promptTitle:
                  '${state.targetGrandSlam.tournament} · ${state.targetGrandSlam.year}',
              promptDetail: state.targetGrandSlam.category,
              heartsRemaining: state.remainingHearts,
              icon: Icons.sports_tennis_rounded,
              accent: Cyber.lime,
              onHome: _cubit.showHome,
              onLogs: _cubit.showLogs,
              onConsumeReveal: _cubit.consumeResultReveal,
            ),
          };
          return PopScope<void>(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              if (state.viewMode == DailyMysteryViewMode.home) {
                _backToGames();
              } else {
                _cubit.showHome();
              }
            },
            child: child,
          );
        },
      ),
    );
  }
}
