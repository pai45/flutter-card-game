import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/game_ladder.dart';
import '../../../config/sport_modules.dart';
import '../../../config/theme.dart';
import '../../../models/sport_match.dart';
import '../../../models/unlock_progress.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/cyber/cyber_cta_button.dart';
import '../../../widgets/game_scaffold.dart';
import 'unlock_sheets.dart';

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
        _CompactBeginnerQuestCard(
          step: step,
          next: next,
          accent: accent,
          chapter: unlocks.missionLabel(sport),
          onPlay: () => onPlay(step),
        ),
        if (showHeader) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: CyberObjectiveAction(
              label: 'VIEW QUEST',
              icon: Icons.flag_outlined,
              accent: accent,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (detailContext) => GameScaffold(
                    title: '${sportModuleFor(sport).label.toUpperCase()} QUEST',
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(detailContext).pop(),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: RookiePathPanel(
                        sport: sport,
                        unlocks: unlocks,
                        onPlay: (game) {
                          Navigator.of(detailContext).pop();
                          onPlay(game);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
    required this.chapter,
    required this.onPlay,
  });
  final ArcadeGame step;
  final ArcadeGame? next;
  final Color accent;
  final String chapter;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) => CyberPanel(
    accent: accent,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          chapter,
          style: Cyber.label(10, color: accent, letterSpacing: 1.4),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(step.icon, size: 24, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title, style: Cyber.display(18)),
                  const SizedBox(height: 6),
                  Text(
                    step.questRequirement,
                    style: Cyber.body(13, color: Cyber.muted),
                  ),
                  if (step.isQuiz) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Free beginner attempts until cleared',
                      style: Cyber.body(12, color: Cyber.success),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const HudLine(),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth < 280 ||
                MediaQuery.textScalerOf(context).scale(12) > 15;
            final xp = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, size: 17, color: Cyber.gold),
                const SizedBox(width: 4),
                Text(
                  '+$beginnerQuestStepXp XP',
                  style: Cyber.display(12, color: Cyber.gold).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            );
            final unlock = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  next == null
                      ? Icons.emoji_events_outlined
                      : Icons.lock_open_rounded,
                  size: 16,
                  color: next == null ? Cyber.gold : accent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    next == null
                        ? '+$beginnerQuestCompleteOz Oz on completion'
                        : 'Unlocks ${next!.title}',
                    style: Cyber.body(
                      12,
                      color: AppTheme.textContrast,
                    ).copyWith(height: 1.2),
                  ),
                ),
              ],
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (compact) ...[
                  xp,
                  const SizedBox(height: 8),
                  unlock,
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      xp,
                      const SizedBox(width: 12),
                      Expanded(child: unlock),
                    ],
                  ),
                const SizedBox(height: 16),
                HudCtaButton(
                  key: const ValueKey('beginner-quest-play'),
                  label: compact ? 'PLAY NOW' : 'PLAY ${step.title}',
                  wrapLabel: true,
                  icon: Icons.play_arrow_rounded,
                  height: 60,
                  accent: accent,
                  onTap: onPlay,
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
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
        Text(
          '${module.label.toUpperCase()} // ${unlocks.chapterLabel(sport)}',
          style: Cyber.label(12, color: module.accent),
        ),
        const SizedBox(height: 8),
        Text(
          '$cleared of ${ladder.length} missions complete',
          style: Cyber.body(14),
        ),
        const SizedBox(height: 8),
        CyberProgressBar(value: cleared / ladder.length, accent: module.accent),
        const SizedBox(height: 16),
        BeginnerQuestCard(
          sport: sport,
          unlocks: unlocks,
          onPlay: onPlay,
          showHeader: false,
        ),
        const SizedBox(height: 16),
        _RookieLadder(sport: sport, unlocks: unlocks, onPlay: onPlay),
        const SizedBox(height: 16),
        Text(
          'Complete all ${ladder.length} missions to earn '
          '$beginnerQuestCompleteOz Oz - enough for another sport.',
          style: Cyber.body(13, color: Cyber.gold),
        ),
        if (unlocks.initialQuestActive) ...[
          const SizedBox(height: 16),
          const _DailyQuestLockedPreview(),
        ],
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
                        style: Cyber.body(13, color: Cyber.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          for (var index = 0; index < sports.length; index++) ...[
            Text(
              sportModuleFor(sports[index]).label.toUpperCase(),
              style: Cyber.label(12, color: Cyber.cyan),
            ),
            const SizedBox(height: 8),
            BeginnerQuestCard(
              sport: sports[index],
              unlocks: unlocks,
              onPlay: onPlay,
            ),
            if (index != sports.length - 1) const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _RookieLadder extends StatelessWidget {
  const _RookieLadder({
    required this.sport,
    required this.unlocks,
    required this.onPlay,
  });

  final ValueChanged<ArcadeGame> onPlay;

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
              onTap: index <= cleared
                  ? () => onPlay(ladder[index])
                  : () => showLockedGameSheet(
                      context,
                      ladder[index],
                      onPlay: onPlay,
                    ),
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
    required this.onTap,
  });

  final int index;
  final ArcadeGame game;
  final bool cleared;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = cleared ? Cyber.success : (active ? accent : Cyber.muted);
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(
                cleared
                    ? Icons.check_rounded
                    : active
                    ? Icons.play_arrow_rounded
                    : Icons.lock_outline,
                color: color,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index + 1}. ${game.title}',
                      style: Cyber.display(12),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cleared
                          ? 'Completed - Replay'
                          : active
                          ? 'Current mission - Play'
                          : game.unlockRequirement,
                      style: Cyber.body(13, color: color),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
                  'Complete your first three home-sport missions to unlock '
                  'Daily Quests. Your activity already counts.',
                  style: Cyber.body(13, color: Cyber.muted),
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
                      Expanded(
                        child: Text(
                          "BEGINNER'S QUEST",
                          style: Cyber.label(
                            10,
                            color: accent,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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
                          'VIEW QUEST - ${step.title}',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("BEGINNER'S QUEST", style: Cyber.display(12)),
        const SizedBox(height: 6),
        Text(
          '$cleared of $total missions complete',
          style: Cyber.body(
            13,
            color: accent,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ],
    );
  }
}
