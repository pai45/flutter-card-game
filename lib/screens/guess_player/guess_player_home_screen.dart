import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/guess_player/guess_player_cubit.dart';
import '../../config/theme.dart';
import '../../models/guess_player.dart';
import '../../models/sport_match.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import '../leaderboard/widgets/game_leaderboard_button.dart';
import 'guess_player_lobby.dart';

class GuessPlayerHomeScreen extends StatefulWidget {
  const GuessPlayerHomeScreen({
    required this.state,
    required this.onBack,
    required this.onOpenToday,
    required this.onOpenLogs,
    required this.onRetry,
    super.key,
  });

  final GuessPlayerState state;
  final VoidCallback onBack;
  final VoidCallback onOpenToday;
  final VoidCallback onOpenLogs;
  final VoidCallback onRetry;

  @override
  State<GuessPlayerHomeScreen> createState() => _GuessPlayerHomeScreenState();
}

class _GuessPlayerHomeScreenState extends State<GuessPlayerHomeScreen> {
  Timer? _ticker;
  Duration _untilReset = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateCountdown(),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _updateCountdown() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    if (!mounted) return;
    setState(() => _untilReset = tomorrow.difference(now));
  }

  @override
  Widget build(BuildContext context) {
    final sport = context.read<GuessPlayerCubit>().sport;
    return GameScaffold(
      title: sport.name.toUpperCase(),
      subtitle: 'GUESS THE PLAYER',
      leading: IconButton(
        tooltip: 'Back to games',
        onPressed: () {
          playSound(SoundEffect.uiTap);
          widget.onBack();
        },
        icon: const Icon(Icons.arrow_back, color: Cyber.cyan),
      ),
      rightSlot: GameLeaderboardButton(
        sport: sport,
        mode: GameMode.mystery,
        accent: Cyber.cyan,
      ),
      child: _body(sport),
    );
  }

  Widget _body(Sport sport) {
    if (widget.state.loadStatus == GuessPlayerLoadStatus.loading) {
      return const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(color: Cyber.cyan, strokeWidth: 2),
        ),
      );
    }
    if (widget.state.loadStatus == GuessPlayerLoadStatus.error) {
      return CyberNoDataState(
        icon: Icons.sync_problem_rounded,
        title: 'INTEL LINK FAILED',
        message:
            widget.state.errorMessage ??
            'The daily mystery could not be loaded.',
        accent: Cyber.danger,
        actionLabel: 'RETRY LINK',
        actionIcon: Icons.refresh,
        onAction: widget.onRetry,
      );
    }

    final record =
        widget.state.archive.resultsByDay[widget.state.currentDayKey];
    final ctaLabel = switch (record?.status) {
      GuessPlayerResultStatus.inProgress
          when (record?.startedAtEpochMs ?? 0) > 0 =>
        'RESUME',
      GuessPlayerResultStatus.inProgress => 'PLAY',
      null => 'PLAY',
      _ => 'REVIEW',
    };

    return GuessPlayerLobby(
      sport: sport,
      state: widget.state,
      resetLabel: _formatCountdown(_untilReset),
      ctaLabel: ctaLabel,
      onOpenToday: widget.onOpenToday,
      onOpenLogs: widget.onOpenLogs,
    );
  }
}

String _formatCountdown(Duration value) {
  final hours = value.inHours.toString().padLeft(2, '0');
  final minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
