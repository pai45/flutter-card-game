import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/game_ladder.dart';
import '../../../config/sport_modules.dart';
import '../../../config/theme.dart';
import '../../../models/sport_match.dart';
import '../../../models/unlock_progress.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
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
    this.showAction = false,
    super.key,
  });

  final Sport sport;
  final UnlockProgress unlocks;
  final ValueChanged<ArcadeGame> onPlay;
  final bool showHeader;

  /// The Games-tab card is informational. Quest hubs can opt into a direct
  /// launch action alongside their fuller ladder controls.
  final bool showAction;

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
          showAction: showAction,
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
    required this.chapter,
    required this.onPlay,
    required this.showAction,
  });
  final ArcadeGame step;
  final ArcadeGame? next;
  final Color accent;
  final String chapter;
  final VoidCallback onPlay;
  final bool showAction;

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
                if (showAction) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: CyberObjectiveAction(
                        key: const ValueKey('beginner-quest-play'),
                        label: compact ? 'PLAY NOW' : 'PLAY ${step.title}',
                        icon: Icons.play_arrow_rounded,
                        accent: accent,
                        onTap: onPlay,
                      ),
                    ),
                  ),
                ],
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
    final ladder = sportGameLadder[sport]!;
    return Column(
      key: const ValueKey('rookie-path-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
              showAction: true,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(width: 18, height: 2, color: module.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'MISSION LADDER',
                style: Cyber.label(
                  10,
                  color: module.accent,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            Text(
              '$cleared / ${ladder.length}',
              style: Cyber.display(
                11,
                color: Cyber.muted,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Stack(
          children: [
            Positioned(
              left: 17,
              top: 18,
              bottom: 18,
              child: Container(width: 2, color: Cyber.line),
            ),
            Column(
              children: [
                for (var index = 0; index < ladder.length; index++) ...[
                  if (index > 0) const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MissionRouteNode(
                        index: index,
                        cleared: index < cleared,
                        active: index == cleared,
                        accent: module.accent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 260),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: _RookieLadderRow(
                            key: ValueKey(
                              '${ladder[index].name}-${index < cleared
                                  ? 'cleared'
                                  : index == cleared
                                  ? 'active'
                                  : 'locked'}',
                            ),
                            index: index,
                            game: ladder[index],
                            cleared: index < cleared,
                            active: index == cleared,
                            nextUnlock: index == cleared + 1,
                            football: sport == Sport.football,
                            accent: module.accent,
                            onTap: index <= cleared
                                ? () => onPlay(ladder[index])
                                : () => showLockedGameSheet(
                                    context,
                                    ladder[index],
                                    onPlay: onPlay,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _MissionRouteNode extends StatelessWidget {
  const _MissionRouteNode({
    required this.index,
    required this.cleared,
    required this.active,
    required this.accent,
  });

  final int index;
  final bool cleared;
  final bool active;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final color = cleared
        ? Cyber.success
        : active
        ? accent
        : Cyber.muted;
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Cyber.panel2,
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: active ? 0.9 : 0.45)),
      ),
      child: cleared
          ? const Icon(Icons.check_rounded, color: Cyber.success, size: 19)
          : Text(
              '${index + 1}'.padLeft(2, '0'),
              style: Cyber.label(
                9,
                color: color,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
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
    required this.nextUnlock,
    required this.football,
    required this.accent,
    required this.onTap,
    super.key,
  });

  final int index;
  final ArcadeGame game;
  final bool cleared;
  final bool active;
  final bool nextUnlock;
  final bool football;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = cleared
        ? Cyber.success
        : active
        ? accent
        : Cyber.muted;
    final status = cleared
        ? 'CLEARED · REPLAY'
        : active
        ? 'ACTIVE MISSION'
        : nextUnlock
        ? 'NEXT UNLOCK'
        : 'LOCKED';
    void activate() {
      HapticFeedback.selectionClick();
      playSound(SoundEffect.uiTap);
      onTap();
    }

    return Semantics(
      button: true,
      onTap: activate,
      excludeSemantics: true,
      label:
          'Mission ${index + 1}, ${game.title}. $status. '
          '${active
              ? game.questRequirement
              : cleared
              ? 'Replay available'
              : game.unlockRequirement}',
      child: GestureDetector(
        key: ValueKey('mission-ticket-${game.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: activate,
        child: ChamferedActionSurface(
          clipper: const HudChamferClipper(bigCut: 10, smallCut: 2),
          borderColor: active
              ? accent.withValues(alpha: 0.9)
              : nextUnlock
              ? Cyber.amber.withValues(alpha: 0.48)
              : color.withValues(alpha: cleared ? 0.42 : 0.25),
          glowColor: active ? accent : null,
          glow: active ? 0.8 : 0,
          child: ColoredBox(
            color: active
                ? Color.alphaBlend(accent.withValues(alpha: 0.09), Cyber.panel)
                : Cyber.panel,
            child: Stack(
              children: [
                if (active && football)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _MissionPitchPainter(
                          color: accent.withValues(alpha: 0.13),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: active
                      ? _ActiveMissionContent(game: game, accent: accent)
                      : _CompactMissionContent(
                          game: game,
                          cleared: cleared,
                          nextUnlock: nextUnlock,
                          color: color,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveMissionContent extends StatelessWidget {
  const _ActiveMissionContent({required this.game, required this.accent});

  final ArcadeGame game;
  final Color accent;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'LIVE CONTRACT // ${game.ladderIndex + 1}',
        style: Cyber.label(9, color: accent, letterSpacing: 1.2),
      ),
      const SizedBox(height: 10),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MissionIconPlate(icon: game.icon, color: accent),
          const SizedBox(width: 8),
          Expanded(child: Text(game.title, style: Cyber.display(13))),
        ],
      ),
      const SizedBox(height: 10),
      Text(game.questRequirement, style: Cyber.body(12, color: Cyber.muted)),
      const SizedBox(height: 12),
      const HudLine(),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const _MissionRewardEmblem(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            color: accent,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('PLAY', style: Cyber.label(10, color: Cyber.bg)),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: Cyber.bg,
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}

class _CompactMissionContent extends StatelessWidget {
  const _CompactMissionContent({
    required this.game,
    required this.cleared,
    required this.nextUnlock,
    required this.color,
  });

  final ArcadeGame game;
  final bool cleared;
  final bool nextUnlock;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MissionIconPlate(icon: game.icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              game.title,
              style: Cyber.display(
                11.5,
                color: cleared ? AppTheme.textContrast : Cyber.muted,
              ),
            ),
          ),
          if (nextUnlock) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: Cyber.amber,
            ),
          ],
        ],
      ),
      const SizedBox(height: 8),
      Text(
        cleared
            ? 'CLEARED · REPLAY'
            : nextUnlock
            ? 'NEXT UNLOCK'
            : 'LOCKED',
        style: Cyber.label(8.5, color: nextUnlock ? Cyber.amber : color),
      ),
      if (!cleared) ...[
        const SizedBox(height: 4),
        Text(
          game.unlockRequirement,
          style: Cyber.body(11.5, color: Cyber.muted),
        ),
      ],
    ],
  );
}

class _MissionIconPlate extends StatelessWidget {
  const _MissionIconPlate({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Color.alphaBlend(color.withValues(alpha: 0.08), Cyber.panel2),
      border: Border.all(color: color.withValues(alpha: 0.5)),
    ),
    child: Icon(icon, size: 17, color: color),
  );
}

class _MissionRewardEmblem extends StatelessWidget {
  const _MissionRewardEmblem();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Cyber.gold.withValues(alpha: 0.13),
          border: Border.all(color: Cyber.gold.withValues(alpha: 0.75)),
        ),
        child: const Icon(Icons.bolt_rounded, color: Cyber.gold, size: 17),
      ),
      const SizedBox(width: 5),
      Text(
        '+$beginnerQuestStepXp XP',
        style: Cyber.display(
          10,
          color: Cyber.gold,
        ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    ],
  );
}

class _MissionPitchPainter extends CustomPainter {
  const _MissionPitchPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final field = Rect.fromLTWH(
      size.width * 0.47,
      12,
      size.width * 0.57,
      size.height - 24,
    );
    canvas.drawRect(field, paint);
    canvas.drawLine(
      Offset(field.center.dx, field.top),
      Offset(field.center.dx, field.bottom),
      paint,
    );
    canvas.drawCircle(field.center, field.height * 0.13, paint);
    canvas.drawRect(
      Rect.fromLTWH(
        field.left,
        field.center.dy - field.height * 0.18,
        field.width * 0.17,
        field.height * 0.36,
      ),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        field.right - field.width * 0.17,
        field.center.dy - field.height * 0.18,
        field.width * 0.17,
        field.height * 0.36,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _MissionPitchPainter oldDelegate) =>
      oldDelegate.color != color;
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
