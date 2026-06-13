import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/achievement/achievement_celebration_controller.dart';
import 'achievement_unlock_celebration.dart';

/// Renders the queued "ACHIEVEMENT UNLOCKED" reveal above everything. Mounted
/// once near the app root (above the Navigator) so it floats over any pushed
/// route. Drives the queue one badge at a time — a fresh [ValueKey] per badge
/// replays the animation, and [onDismissed] pops the head so the next plays.
class AchievementCelebrationHost extends StatelessWidget {
  const AchievementCelebrationHost({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<
      AchievementCelebrationController,
      AchievementCelebrationState
    >(
      builder: (context, state) {
        if (!state.canReveal) return const SizedBox.shrink();
        final achievement = state.queue.first;
        return AchievementUnlockCelebration(
          key: ValueKey(achievement.id),
          achievement: achievement,
          onDismissed: () =>
              context.read<AchievementCelebrationController>().consumeFront(),
        );
      },
    );
  }
}
