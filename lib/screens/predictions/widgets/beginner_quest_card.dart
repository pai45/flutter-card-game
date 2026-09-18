import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/game_ladder.dart';
import '../../../config/sport_modules.dart';
import '../../../config/theme.dart';
import '../../../models/sport_match.dart';
import '../../../models/unlock_progress.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// Slot #1 of a sport's GAMES tab while its Beginner's Quest is running: the
/// current objective ("PLAY FINAL OVER"), a segment per ladder game, the step
/// reward and what it unlocks next. Built on the shared [CyberObjectiveCard]
/// so it reads as the same quest family as the daily quests.
class BeginnerQuestCard extends StatelessWidget {
  const BeginnerQuestCard({
    required this.sport,
    required this.unlocks,
    required this.onPlay,
    super.key,
  });

  final Sport sport;
  final UnlockProgress unlocks;
  final ValueChanged<ArcadeGame> onPlay;

  @override
  Widget build(BuildContext context) {
    final step = unlocks.currentStep(sport);
    if (step == null) return const SizedBox.shrink();
    final ladder = sportGameLadder[sport]!;
    final cleared = unlocks.stepsCleared(sport);
    final accent = sportModuleFor(sport).accent;
    final lastStep = step.ladderIndex == ladder.length - 1;
    final next = lastStep ? null : ladder[step.ladderIndex + 1];
    return Column(
      key: ValueKey('beginner-quest-${sport.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QuestHeader(accent: accent, cleared: cleared, total: ladder.length),
        const SizedBox(height: 8),
        CyberObjectiveCard(
          index: cleared + 1,
          icon: step.icon,
          accent: accent,
          title: 'PLAY ${step.title}',
          description: next == null
              ? 'Finish one run - win or lose - to clear your '
                    "Beginner's Quest."
              : 'Finish one run - win or lose - to unlock ${next.title}.',
          status: 'STEP ${cleared + 1} OF ${ladder.length}',
          progress: cleared / ladder.length,
          segments: ladder.length,
          reward: '+$beginnerQuestStepXp XP',
          rewardDetail: next == null
              ? '+$beginnerQuestCompleteOz OZ'
              : 'UNLOCKS ${next.title}',
          actions: Align(
            alignment: Alignment.centerRight,
            child: CyberObjectiveAction(
              key: const ValueKey('beginner-quest-play'),
              label: 'PLAY NOW',
              icon: Icons.play_arrow_rounded,
              accent: accent,
              onTap: () => onPlay(step),
            ),
          ),
        ),
      ],
    );
  }
}

/// One-line quest strip for the MATCH tab: takes the daily-quest tile's slot
/// while the Beginner's Quest runs, so a new player sees one objective, not two.
class BeginnerQuestStrip extends StatelessWidget {
  const BeginnerQuestStrip({
    required this.sport,
    required this.unlocks,
    required this.onTap,
    super.key,
  });

  final Sport sport;
  final UnlockProgress unlocks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final step = unlocks.currentStep(sport);
    if (step == null) return const SizedBox.shrink();
    final ladder = sportGameLadder[sport]!;
    final cleared = unlocks.stepsCleared(sport);
    final accent = sportModuleFor(sport).accent;
    return Semantics(
      button: true,
      label: "Beginner's Quest, next: play ${step.title}",
      child: GestureDetector(
        key: ValueKey('beginner-quest-strip-${sport.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          playSound(SoundEffect.uiTap);
          onTap();
        },
        child: ChamferedActionSurface(
          clipper: const HudChamferClipper(bigCut: 12, smallCut: 4),
          borderColor: accent.withValues(alpha: 0.55),
          child: ColoredBox(
            color: Color.alphaBlend(
              accent.withValues(alpha: 0.06),
              Cyber.panel,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.flag_rounded, size: 16, color: accent),
                      const SizedBox(width: 8),
                      Text(
                        "BEGINNER'S QUEST",
                        style: Cyber.label(
                          10,
                          color: accent,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$cleared / ${ladder.length}',
                        style: Cyber.display(11, color: Colors.white).copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'NEXT: PLAY ${step.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Cyber.display(13, color: Colors.white),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: accent),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CyberProgressBar(
                    value: cleared / ladder.length,
                    accent: accent,
                    height: 5,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestHeader extends StatelessWidget {
  const _QuestHeader({
    required this.accent,
    required this.cleared,
    required this.total,
  });

  final Color accent;
  final int cleared;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.flag_rounded, size: 15, color: accent),
        const SizedBox(width: 8),
        Text(
          "BEGINNER'S QUEST",
          style: Cyber.display(11, color: Colors.white, letterSpacing: 1.8),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(height: 1, color: accent.withValues(alpha: 0.28)),
        ),
        const SizedBox(width: 10),
        Text(
          '$cleared/$total GAMES CLEARED',
          style: Cyber.label(
            8,
            color: accent,
            letterSpacing: 1.1,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ],
    );
  }
}
