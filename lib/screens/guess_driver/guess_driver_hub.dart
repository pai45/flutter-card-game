import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/guess_driver/guess_driver_cubit.dart';
import '../../config/enums.dart';
import '../../config/theme.dart';
import '../../data/f1_guess_data.dart';
import '../../models/daily_mystery.dart';
import '../../services/secure_storage_service.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/daily_mystery_widgets.dart';
import 'guess_driver_home_screen.dart';
import 'guess_driver_logs_screen.dart';
import 'guess_driver_screen.dart';

class GuessDriverTabContent extends StatefulWidget {
  const GuessDriverTabContent({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  State<GuessDriverTabContent> createState() => _GuessDriverTabContentState();
}

class _GuessDriverTabContentState extends State<GuessDriverTabContent>
    with WidgetsBindingObserver {
  late final GuessDriverCubit _cubit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cubit = GuessDriverCubit(
      races: f1Races,
      allDrivers: f1Drivers,
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
      child: BlocBuilder<GuessDriverCubit, GuessDriverState>(
        builder: (context, state) {
          final child = switch (state.viewMode) {
            DailyMysteryViewMode.home => GuessDriverHomeScreen(
              state: state,
              onBack: _backToGames,
              onOpenToday: _cubit.openToday,
              onOpenLogs: _cubit.showLogs,
              onRetry: _cubit.load,
            ),
            DailyMysteryViewMode.play => GuessDriverScreen(
              onBack: _cubit.showHome,
            ),
            DailyMysteryViewMode.logs => GuessDriverLogsScreen(
              state: state,
              onBack: _cubit.showHome,
              onOpenDay: _cubit.openDay,
            ),
            DailyMysteryViewMode.review => DailyMysteryDebrief(
              title: 'DRIVER DEBRIEF',
              subtitle: state.activeDayKey,
              won: state.gameState == GuessDriverGameState.won,
              freshResult: state.freshResult,
              answer: state.targetRace.driverName,
              promptTitle:
                  '${state.targetRace.trackName} · ${state.targetRace.year}',
              promptDetail: state.targetRace.country,
              heartsRemaining: state.remainingHearts,
              icon: Icons.sports_motorsports_rounded,
              accent: Cyber.pink,
              audioProfile: DailyMysteryAudioProfile.driver,
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
