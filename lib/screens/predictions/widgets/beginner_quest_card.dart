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
    this.showHeader = true,
    super.key,
  });

  final Sport sport;
  final UnlockProgress unlocks;
  final ValueChanged<ArcadeGame> onPlay;
  final bool showHeader;

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
        if (showHeader) ...[
          _QuestHeader(accent: accent, cleared: cleared, total: ladder.length),
          const SizedBox(height: 8),
        ],
        if (showHeader)
          _CompactBeginnerQuestCard(
            step: step,
            next: next,
            accent: accent,
            onPlay: () => onPlay(step),
          )
        else
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

/// The GAMES tab already shows overall quest progress in [_QuestHeader], so
/// this card keeps only the next decision: what to play and what it unlocks.
class _CompactBeginnerQuestCard extends StatelessWidget {
  const _CompactBeginnerQuestCard({
    required this.step,
    required this.next,
    required this.accent,
    required this.onPlay,
  });

  final ArcadeGame step;
  final ArcadeGame? next;
  final Color accent;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final outcome = next == null
        ? '+$beginnerQuestCompleteOz OZ QUEST BONUS'
        : 'UNLOCKS ${next!.title}';
    return Semantics(
      container: true,
      label:
          'Play ${step.title}. Finish one run. $outcome. '
          'Reward +$beginnerQuestStepXp XP.',
      child: ChamferedActionSurface(
        clipper: const HudChamferClipper(bigCut: 12, smallCut: 4),
        borderColor: accent.withValues(alpha: 0.5),
        child: ColoredBox(
          color: Cyber.panel,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SizedBox.square(
                      dimension: 36,
                      child: ChamferedActionSurface(
                        clipper: const HudChamferClipper(
                          bigCut: 8,
                          smallCut: 2,
                        ),
                        borderColor: accent.withValues(alpha: 0.5),
                        child: ColoredBox(
                          color: Color.alphaBlend(
                            accent.withValues(alpha: 0.1),
                            Cyber.panel2,
                          ),
                          child: Icon(step.icon, size: 17, color: accent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'PLAY ${step.title}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Cyber.display(13, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CyberChip(
                      label: '+$beginnerQuestStepXp XP',
                      color: Cyber.gold,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      next == null
                          ? Icons.emoji_events_outlined
                          : Icons.lock_open_rounded,
                      size: 14,
                      color: next == null ? Cyber.gold : accent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '1 RUN // $outcome',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Cyber.label(
                          8.5,
                          color: Cyber.muted,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CyberObjectiveAction(
                      key: const ValueKey('beginner-quest-play'),
                      label: 'PLAY NOW',
                      icon: Icons.play_arrow_rounded,
                      accent: accent,
                      onTap: onPlay,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The first-time player's focused quest hub. It deliberately shows one
/// mission family and keeps Daily Quest progress behind a calm lock preview.
class RookiePathPanel extends StatelessWidget {
  const RookiePathPanel({
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
    final module = sportModuleFor(sport);
    final ladder = sportGameLadder[sport]!;
    final cleared = unlocks.stepsCleared(sport);
    return Column(
      key: const ValueKey('rookie-path-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CyberPanel(
          accent: module.accent,
          glow: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(module.icon, color: module.accent, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ROOKIE PATH // ${module.label.toUpperCase()}',
                          style: Cyber.label(
                            9,
                            color: module.accent,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "BEGINNER'S QUEST",
                          style: Cyber.display(20, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$cleared/${ladder.length}',
                    style: Cyber.display(18, color: module.accent).copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CyberProgressBar(
                value: cleared / ladder.length,
                accent: module.accent,
                height: 7,
              ),
              const SizedBox(height: 10),
              Text(
                '+$beginnerQuestStepXp XP PER STEP  //  '
                '+$beginnerQuestCompleteOz OZ ON COMPLETE',
                style: Cyber.label(8.5, color: Cyber.gold, letterSpacing: 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        BeginnerQuestCard(
          sport: sport,
          unlocks: unlocks,
          onPlay: onPlay,
          showHeader: false,
        ),
        const SizedBox(height: 16),
        _RookieLadder(sport: sport, unlocks: unlocks),
        const SizedBox(height: 16),
        const _DailyQuestLockedPreview(),
      ],
    );
  }
}

/// Compact active sport quests used below Daily Quests in the multi-sport
/// QUESTS tab.
class SportQuestList extends StatelessWidget {
  const SportQuestList({
    required this.unlocks,
    required this.onPlay,
    super.key,
  });

  final UnlockProgress unlocks;
  final ValueChanged<ArcadeGame> onPlay;

  @override
  Widget build(BuildContext context) {
    final sports = unlocks.activeQuestSports;
    return Column(
      key: const ValueKey('sport-quest-list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            const Icon(Icons.flag_rounded, size: 15, color: Cyber.cyan),
            const SizedBox(width: 8),
            Text('SPORT QUESTS', style: Cyber.display(11, letterSpacing: 1.8)),
            const SizedBox(width: 10),
            const Expanded(child: HudLine()),
          ],
        ),
        const SizedBox(height: 10),
        if (sports.isEmpty)
          CyberPanel(
            accent: Cyber.success,
            child: Row(
              children: [
                const Icon(
                  Icons.verified_rounded,
                  color: Cyber.success,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ALL SPORT QUESTS CLEARED',
                        style: Cyber.display(12, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Every unlocked sport is fully operational.',
                        style: Cyber.body(11, color: Cyber.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          for (var index = 0; index < sports.length; index++) ...[
            BeginnerQuestStrip(
              sport: sports[index],
              unlocks: unlocks,
              onTap: () {
                final step = unlocks.currentStep(sports[index]);
                if (step != null) onPlay(step);
              },
            ),
            if (index != sports.length - 1) const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _RookieLadder extends StatelessWidget {
  const _RookieLadder({required this.sport, required this.unlocks});

  final Sport sport;
  final UnlockProgress unlocks;

  @override
  Widget build(BuildContext context) {
    final module = sportModuleFor(sport);
    final ladder = sportGameLadder[sport]!;
    final cleared = unlocks.stepsCleared(sport);
    return CyberPanel(
      accent: module.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('MISSION LADDER', style: Cyber.label(10, color: module.accent)),
          const SizedBox(height: 10),
          for (var index = 0; index < ladder.length; index++) ...[
            _RookieLadderRow(
              index: index,
              game: ladder[index],
              cleared: index < cleared,
              active: index == cleared,
              accent: module.accent,
            ),
            if (index != ladder.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 7),
                child: HudLine(),
              ),
          ],
        ],
      ),
    );
  }
}

class _RookieLadderRow extends StatelessWidget {
  const _RookieLadderRow({
    required this.index,
    required this.game,
    required this.cleared,
    required this.active,
    required this.accent,
  });

  final int index;
  final ArcadeGame game;
  final bool cleared;
  final bool active;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final color = cleared ? Cyber.success : (active ? accent : Cyber.muted);
    return Row(
      children: [
        SizedBox.square(
          dimension: 26,
          child: Center(
            child: Icon(
              cleared
                  ? Icons.check_rounded
                  : (active ? Icons.play_arrow_rounded : Icons.lock_outline),
              size: 17,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${index + 1}. ${game.title}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Cyber.display(
              10.5,
              color: active || cleared ? Colors.white : Cyber.muted,
            ),
          ),
        ),
        Text(
          cleared ? 'CLEARED' : (active ? 'ACTIVE' : 'LOCKED'),
          style: Cyber.label(8, color: color, letterSpacing: 1),
        ),
      ],
    );
  }
}

class _DailyQuestLockedPreview extends StatelessWidget {
  const _DailyQuestLockedPreview();

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.muted,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline_rounded, color: Cyber.muted, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DAILY QUESTS LOCKED',
                  style: Cyber.display(12, color: Colors.white),
                ),
                const SizedBox(height: 5),
                Text(
                  'Finish your home-sport Rookie Path to reveal today\'s '
                  'missions. Your activity is already being tracked.',
                  style: Cyber.body(11, color: Cyber.muted),
                ),
              ],
            ),
          ),
        ],
      ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 340 ||
            MediaQuery.textScalerOf(context).scale(10) > 12;
        return Row(
          children: [
            Icon(Icons.flag_rounded, size: 15, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "BEGINNER'S QUEST",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Cyber.display(
                  11,
                  color: Colors.white,
                  letterSpacing: 1.8,
                ),
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 10),
              SizedBox(
                width: 32,
                child: Divider(color: accent.withValues(alpha: 0.28)),
              ),
            ],
            const SizedBox(width: 10),
            Text(
              compact ? '$cleared/$total' : '$cleared/$total GAMES CLEARED',
              style: Cyber.label(
                8,
                color: accent,
                letterSpacing: 1.1,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        );
      },
    );
  }
}
