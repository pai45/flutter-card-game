import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/achievement/achievement_celebration_controller.dart';
import '../blocs/game/game_bloc.dart';
import '../blocs/game/game_event.dart';
import '../blocs/game/game_state.dart';
import '../config/game_ladder.dart';
import '../config/sport_modules.dart';
import '../models/sport_match.dart';
import '../models/streak.dart';
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
  ValueChanged<Sport>? chooseGame;
  ValueChanged<Sport>? openSport;
  VoidCallback? openQuestHub;
  VoidCallback? chooseSport;
  VoidCallback? backToGames;
  VoidCallback? continueQuest;
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
          if (reveals.isEmpty) return const SizedBox.shrink();
          final reveal = reveals.first;
          final rookieGraduation =
              reveal.kind == UnlockRevealKind.graduation ||
              (reveal.kind == UnlockRevealKind.questComplete &&
                  reveal.sport == state.unlocks.homeSport &&
                  sportGameLadder[reveal.targetSport]!.length ==
                      beginnerChapterLength);
          final deferredShield =
              state.unlocks.initialQuestActive &&
              state.streak.celebrationQueue.isNotEmpty &&
              _isShieldMoment(state.streak.celebrationQueue.first);
          final busy =
              !hubVisible ||
              state.pendingPackReveal != null ||
              (state.streak.celebrationQueue.isNotEmpty &&
                  !rookieGraduation &&
                  !deferredShield) ||
              state.questRewardCoins > 0 ||
              (achievements?.holding ?? false) ||
              (achievements?.queue.isNotEmpty ?? false);
          if (busy) return const SizedBox.shrink();
          return _UnlockRevealFor(
            key: ValueKey(
              '${reveals.length}-${reveal.kind.name}-'
              '${reveal.game?.name ?? reveal.sport?.name}',
            ),
            reveal: reveal,
            rookieGraduation: rookieGraduation,
            questListEnabled: state.unlocks.questListEnabled,
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
    required this.rookieGraduation,
    required this.questListEnabled,
    required this.onDismissed,
    super.key,
  });

  final UnlockReveal reveal;
  final bool rookieGraduation;
  final bool questListEnabled;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final gate = UnlockRevealGate.instance;
    final module = sportModuleFor(reveal.targetSport);
    final sportLabel = module.label.toUpperCase();
    switch (reveal.kind) {
      case UnlockRevealKind.graduation
          when context
              .read<GameBloc>()
              .state
              .unlocks
              .completedFor(reveal.targetSport)
              .contains(reveal.game):
      case UnlockRevealKind.missionComplete:
        final game = reveal.game!;
        final unlocks = context.read<GameBloc>().state.unlocks;
        return CyberUnlockReveal(
          eyebrow: rookieGraduation
              ? 'BEGINNER CHAPTER COMPLETE'
              : 'MISSION COMPLETE',
          title: game.title,
          subtitle:
              '${unlocks.stepsCleared(game.sport)}/${sportGameLadder[game.sport]!.length} missions cleared. '
              '${rookieGraduation ? 'Daily Quests unlocked. ' : ''}Your next game is yours to choose.',
          icon: game.icon,
          accent: module.accent,
          rewardLabel: '+$beginnerQuestStepXp XP',
          ctaLabel: 'CHOOSE NEXT GAME',
          onCta: gate.chooseGame == null
              ? null
              : () => gate.chooseGame!(game.sport),
          secondaryLabel: rookieGraduation ? 'VIEW DAILY QUESTS' : 'CONTINUE',
          onSecondary: rookieGraduation ? gate.openQuestHub : null,
          onDismissed: onDismissed,
        );
      case UnlockRevealKind.game:
      // V1 graduation reveals name the newly opened game, not the cleared one.
      case UnlockRevealKind.graduation:
        final game = reveal.game!;
        final ladder = sportGameLadder[game.sport]!;
        return CyberUnlockReveal(
          eyebrow: rookieGraduation
              ? 'BEGINNER CHAPTER COMPLETE'
              : 'NEW GAME UNLOCKED',
          title: game.title,
          subtitle:
              '${game.ladderIndex}/${ladder.length} missions cleared. '
              '${rookieGraduation ? 'Daily Quests unlocked. Explorer pays 50 Oz.' : game.questRequirement}',
          icon: game.icon,
          accent: module.accent,
          rewardLabel: '+$beginnerQuestStepXp XP',
          ctaLabel: 'PLAY ${game.title}',
          onCta: gate.playGame == null ? null : () => gate.playGame!(game),
          secondaryLabel: rookieGraduation ? 'VIEW DAILY QUESTS' : 'CONTINUE',
          onSecondary: rookieGraduation ? gate.openQuestHub : null,
          onDismissed: onDismissed,
        );
      case UnlockRevealKind.sport:
        return CyberUnlockReveal(
          eyebrow: 'SPORT UNLOCKED',
          title: sportLabel,
          subtitle:
              '$sportLabel matches and picks are live. Its Beginner\'s Quest '
              'lets you choose any first game.',
          icon: module.icon,
          accent: module.accent,
          ctaLabel: 'ENTER $sportLabel',
          onCta: gate.openSport == null
              ? null
              : () => gate.openSport!(reveal.sport!),
          onDismissed: onDismissed,
        );
      case UnlockRevealKind.questComplete:
        final hasLockedSports = context
            .read<GameBloc>()
            .state
            .unlocks
            .lockedSports
            .isNotEmpty;
        return CyberUnlockReveal(
          eyebrow: rookieGraduation
              ? 'BEGINNER CHAPTER COMPLETE'
              : 'SPORT QUEST COMPLETE',
          title: 'ALL $sportLabel GAMES OPEN',
          subtitle:
              '${rookieGraduation ? 'Daily Quests unlocked. ' : ''}'
              '${hasLockedSports ? '50 Oz earned. Choose your next sport.' : 'Every sport is open. Daily Quests await.'}',
          icon: Icons.emoji_events_rounded,
          accent: module.accent,
          rewardLabel:
              '+$beginnerQuestStepXp XP / +$beginnerQuestCompleteOz OZ',
          ctaLabel: hasLockedSports ? 'CHOOSE NEXT SPORT' : 'BACK TO GAMES',
          onCta: hasLockedSports ? gate.chooseSport : gate.backToGames,
          secondaryLabel: 'VIEW DAILY QUESTS',
          onSecondary: gate.openQuestHub,
          onDismissed: onDismissed,
        );
    }
  }
}

bool _isShieldMoment(StreakCelebration celebration) =>
    celebration.type == StreakCelebrationType.shieldEarned ||
    celebration.type == StreakCelebrationType.shieldSaved;
