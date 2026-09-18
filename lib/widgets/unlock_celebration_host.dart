import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/achievement/achievement_celebration_controller.dart';
import '../blocs/game/game_bloc.dart';
import '../blocs/game/game_event.dart';
import '../blocs/game/game_state.dart';
import '../config/game_ladder.dart';
import '../config/sport_modules.dart';
import '../models/sport_match.dart';
import '../models/unlock_progress.dart';
import 'cyber/cyber_unlock_reveal.dart';

/// Wiring between the app-root reveal host (which sits above the navigator)
/// and the shell that owns navigation. The shell flips [hubVisible] as its
/// route is covered/uncovered and registers the CTA routes.
class UnlockRevealGate {
  UnlockRevealGate._();

  static final instance = UnlockRevealGate._();

  /// True only while the home hub is the top route, so unlock moments land
  /// after a game's own result/level-up beats, never over gameplay.
  final ValueNotifier<bool> hubVisible = ValueNotifier(false);

  ValueChanged<ArcadeGame>? playGame;
  ValueChanged<Sport>? openSport;
}

/// Plays queued unlock moments (NEW GAME UNLOCKED / SPORT UNLOCKED /
/// BEGINNER'S QUEST COMPLETE) one at a time. Waits for achievement and streak
/// moments first, sharing the app-root presentation slot with them.
class UnlockCelebrationHost extends StatelessWidget {
  const UnlockCelebrationHost({super.key});

  @override
  Widget build(BuildContext context) {
    final achievements = context
        .watch<AchievementCelebrationController?>()
        ?.state;
    final gate = UnlockRevealGate.instance;
    return ValueListenableBuilder<bool>(
      valueListenable: gate.hubVisible,
      builder: (context, hubVisible, _) => BlocBuilder<GameBloc, GameState>(
        buildWhen: (previous, current) =>
            previous.unlocks.pendingReveals != current.unlocks.pendingReveals ||
            previous.streak.celebrationQueue !=
                current.streak.celebrationQueue ||
            previous.questRewardCoins != current.questRewardCoins ||
            previous.pendingPackReveal != current.pendingPackReveal,
        builder: (context, state) {
          final reveals = state.unlocks.pendingReveals;
          final busy =
              !hubVisible ||
              state.pendingPackReveal != null ||
              state.streak.celebrationQueue.isNotEmpty ||
              state.questRewardCoins > 0 ||
              (achievements?.holding ?? false) ||
              (achievements?.queue.isNotEmpty ?? false);
          if (reveals.isEmpty || busy) return const SizedBox.shrink();
          final reveal = reveals.first;
          return _UnlockRevealFor(
            key: ValueKey(
              '${reveals.length}-${reveal.kind.name}-'
              '${reveal.game?.name ?? reveal.sport?.name}',
            ),
            reveal: reveal,
            onDismissed: () =>
                context.read<GameBloc>().add(UnlockRevealConsumed()),
          );
        },
      ),
    );
  }
}

class _UnlockRevealFor extends StatelessWidget {
  const _UnlockRevealFor({
    required this.reveal,
    required this.onDismissed,
    super.key,
  });

  final UnlockReveal reveal;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final gate = UnlockRevealGate.instance;
    final module = sportModuleFor(reveal.targetSport);
    final sportLabel = module.label.toUpperCase();
    switch (reveal.kind) {
      case UnlockRevealKind.game:
        final game = reveal.game!;
        final ladder = sportGameLadder[game.sport]!;
        return CyberUnlockReveal(
          eyebrow: 'NEW GAME UNLOCKED',
          title: game.title,
          subtitle:
              "Beginner's Quest step ${game.ladderIndex} of "
              '${ladder.length - 1} cleared. Play it to open the next one.',
          icon: game.icon,
          accent: module.accent,
          rewardLabel: '+$beginnerQuestStepXp XP',
          ctaLabel: 'PLAY NOW',
          onCta: gate.playGame == null ? null : () => gate.playGame!(game),
          onDismissed: onDismissed,
        );
      case UnlockRevealKind.sport:
        final first = sportGameLadder[reveal.sport!]!.first;
        return CyberUnlockReveal(
          eyebrow: 'SPORT UNLOCKED',
          title: sportLabel,
          subtitle:
              '$sportLabel matches and picks are live. Its Beginner\'s Quest '
              'starts with ${first.title}.',
          icon: module.icon,
          accent: module.accent,
          ctaLabel: 'ENTER $sportLabel',
          onCta: gate.openSport == null
              ? null
              : () => gate.openSport!(reveal.sport!),
          onDismissed: onDismissed,
        );
      case UnlockRevealKind.questComplete:
        return CyberUnlockReveal(
          eyebrow: "BEGINNER'S QUEST COMPLETE",
          title: 'ALL $sportLabel GAMES OPEN',
          subtitle:
              'Every $sportLabel game is yours. Spend the Oz on your next '
              'sport.',
          icon: Icons.emoji_events_rounded,
          accent: module.accent,
          rewardLabel: '+$beginnerQuestCompleteOz OZ',
          onDismissed: onDismissed,
        );
    }
  }
}
