import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/guess_player/guess_player_cubit.dart';
import '../../config/enums.dart';
import '../../data/guess_player_data.dart';
import '../../models/cards.dart';
import '../../models/guess_player.dart';
import '../../models/sport_match.dart';
import '../../services/secure_storage_service.dart';
import 'guess_player_home_screen.dart';
import 'guess_player_logs_screen.dart';
import 'guess_player_screen.dart';

class GuessPlayerTabContent extends StatefulWidget {
  const GuessPlayerTabContent({
    required this.sport,
    required this.timelines,
    required this.onNavigate,
    required this.allPlayers,
    super.key,
  });

  final Sport sport;
  final List<GuessPlayerTimeline> timelines;
  final ValueChanged<AppSection> onNavigate;
  final List<PlayerCard> allPlayers;

  @override
  State<GuessPlayerTabContent> createState() => _GuessPlayerTabContentState();
}

class _GuessPlayerTabContentState extends State<GuessPlayerTabContent>
    with WidgetsBindingObserver {
  late final GuessPlayerCubit _cubit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cubit = GuessPlayerCubit(
      sport: widget.sport,
      timelines: widget.timelines,
      allPlayers: widget.allPlayers,
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

  void _settleReward(BuildContext context, GuessPlayerState state) {
    final record = state.activeRecord;
    if (record == null) return;
    final completedAt = record.completedAtEpochMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(record.completedAtEpochMs)
        : DateTime.now();
    context.read<GameBloc>().add(
      DailyGuessPlayerSettled(
        sport: widget.sport,
        dayKey: record.dayKey,
        xp: record.xpEarned,
        score: record.score,
        won: record.status == GuessPlayerResultStatus.won,
        completedAt: completedAt,
      ),
    );
    _cubit.consumeSettlement();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocListener<GuessPlayerCubit, GuessPlayerState>(
        listenWhen: (previous, current) =>
            !previous.settlementPending && current.settlementPending,
        listener: _settleReward,
        child: BlocBuilder<GuessPlayerCubit, GuessPlayerState>(
          builder: (context, state) {
            return switch (state.viewMode) {
              GuessPlayerViewMode.play ||
              GuessPlayerViewMode.review => GuessPlayerScreen(
                onBack: _cubit.showHome,
              ),
              GuessPlayerViewMode.logs => GuessPlayerLogsScreen(
                state: state,
                onBack: _cubit.showHome,
                onOpenDay: _cubit.openDay,
              ),
              GuessPlayerViewMode.home => GuessPlayerHomeScreen(
                state: state,
                onBack: () => widget.onNavigate(AppSection.predictions),
                onOpenToday: _cubit.openToday,
                onOpenLogs: _cubit.showLogs,
                onRetry: _cubit.load,
              ),
            };
          },
        ),
      ),
    );
  }
}
