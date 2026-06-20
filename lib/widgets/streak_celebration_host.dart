import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';

import '../blocs/game/game_bloc.dart';
import '../blocs/game/game_event.dart';
import '../blocs/game/game_state.dart';
import '../config/theme.dart';
import '../models/streak.dart';
import 'streak_widgets.dart';

class StreakCelebrationHost extends StatelessWidget {
  const StreakCelebrationHost({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      buildWhen: (previous, current) =>
          previous.streak.celebrationQueue != current.streak.celebrationQueue,
      builder: (context, state) {
        if (state.streak.celebrationQueue.isEmpty) {
          return const SizedBox.shrink();
        }
        final celebration = state.streak.celebrationQueue.first;
        return _StreakCelebrationOverlay(
          key: ValueKey(celebration.id),
          celebration: celebration,
        );
      },
    );
  }
}

class _StreakCelebrationOverlay extends StatefulWidget {
  const _StreakCelebrationOverlay({required this.celebration, super.key});

  final StreakCelebration celebration;

  @override
  State<_StreakCelebrationOverlay> createState() =>
      _StreakCelebrationOverlayState();
}

class _StreakCelebrationOverlayState extends State<_StreakCelebrationOverlay> {
  Timer? _timer;
  bool _entered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _entered = true);
      if (widget.celebration.type == StreakCelebrationType.daily) {
        _timer = Timer(StreakTheme.autoDismissDuration, _consume);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _consume() {
    if (!mounted) return;
    context.read<GameBloc>().add(StreakCelebrationConsumed());
  }

  void _claim() {
    final days = widget.celebration.milestoneDays;
    if (days == null) return;
    context.read<GameBloc>().add(StreakMilestoneClaimed(days));
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final celebration = widget.celebration;
    final milestone = celebration.milestoneDays == null
        ? null
        : streakMilestones
              .where((item) => item.days == celebration.milestoneDays)
              .firstOrNull;
    final next = _nextMilestone(celebration.streak);

    return Material(
      color: StreakTheme.overlayBarrier,
      child: SafeArea(
        child: Center(
          child: AnimatedOpacity(
            opacity: _entered ? 1 : 0,
            duration: reducedMotion
                ? Duration.zero
                : StreakTheme.standardDuration,
            child: AnimatedScale(
              scale: _entered || reducedMotion ? 1 : StreakTheme.entryScale,
              duration: reducedMotion
                  ? Duration.zero
                  : StreakTheme.celebrationDuration,
              curve: Curves.easeOutBack,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: StreakTheme.maxContentWidth,
                ),
                child: Padding(
                  padding: StreakTheme.celebrationPadding,
                  child: Container(
                    width: double.infinity,
                    padding: StreakTheme.celebrationPadding,
                    decoration: BoxDecoration(
                      gradient: StreakTheme.fireBackgroundGradient,
                      border: Border.all(
                        color: StreakTheme.primary,
                        width: StreakTheme.activeBorderWidth,
                      ),
                      boxShadow: StreakTheme.fireGlow,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: StreakTheme.celebrationIconSize,
                          height: StreakTheme.celebrationIconSize,
                          child: Lottie.asset(
                            'assets/animations/streak_animation.json',
                            repeat: !reducedMotion,
                          ),
                        ),
                        const SizedBox(height: StreakTheme.space12),
                        Text(
                          celebration.type == StreakCelebrationType.milestone
                              ? 'MILESTONE REACHED'
                              : 'DAILY STREAK',
                          textAlign: TextAlign.center,
                          style: StreakTheme.title(color: StreakTheme.primary),
                        ),
                        const SizedBox(height: StreakTheme.space8),
                        Text(
                          '${celebration.streak}',
                          style: StreakTheme.celebrationNumber(),
                        ),
                        const SizedBox(height: StreakTheme.space4),
                        Text(
                          celebration.streak == 1 ? 'DAY' : 'DAYS',
                          style: StreakTheme.label(
                            color: StreakTheme.secondary,
                          ),
                        ),
                        const SizedBox(height: StreakTheme.space16),
                        Text(
                          celebration.type == StreakCelebrationType.milestone
                              ? milestone?.rewardLabel ?? 'REWARD READY'
                              : streakActivityLabel(celebration.activity),
                          textAlign: TextAlign.center,
                          style: StreakTheme.bodyStrong(),
                        ),
                        if (celebration.type == StreakCelebrationType.daily &&
                            next != null) ...[
                          const SizedBox(height: StreakTheme.space16),
                          StreakProgressBar(
                            value: celebration.streak / next.days,
                          ),
                          const SizedBox(height: StreakTheme.space8),
                          Text(
                            '${next.days - celebration.streak} days to '
                            '${next.days}-day reward',
                            textAlign: TextAlign.center,
                            style: StreakTheme.body(),
                          ),
                        ],
                        if (celebration.type ==
                            StreakCelebrationType.milestone) ...[
                          const SizedBox(height: StreakTheme.space20),
                          StreakClaimButton(
                            label: 'CLAIM REWARD',
                            onPressed: _claim,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

StreakMilestone? _nextMilestone(int streak) {
  for (final milestone in streakMilestones) {
    if (milestone.days > streak) return milestone;
  }
  return null;
}
