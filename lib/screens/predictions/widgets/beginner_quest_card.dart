import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/game_ladder.dart';
import '../../../config/sport_modules.dart';
import '../../../config/theme.dart';
import '../../../models/sport_match.dart';
import '../../../models/unlock_progress.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/unlock_celebration_host.dart';
import 'unlock_sheets.dart';

/// Slot #1 of a sport's GAMES tab while its quest is running. The active
/// mission, route progress and reward share one compact card.
class BeginnerQuestCard extends StatelessWidget {
  const BeginnerQuestCard({
    required this.sport,
    required this.unlocks,
    required this.onPlay,
    this.showAction = false,
    super.key,
  });

  final Sport sport;
  final UnlockProgress unlocks;
  final ValueChanged<ArcadeGame> onPlay;

  /// Active Games-tab missions stay informational. A waiting mission always
  /// offers the picker; quest hubs can also offer direct launch actions.
  final bool showAction;

  @override
  Widget build(BuildContext context) {
    final step = unlocks.currentStep(sport);
    if (!unlocks.isQuestActive(sport)) return const SizedBox.shrink();
    final ladder = sportGameLadder[sport]!;
    final cleared = unlocks.stepsCleared(sport);
    final accent = sportModuleFor(sport).accent;
    return Column(
      key: ValueKey('beginner-quest-${sport.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CompactBeginnerQuestCard(
          step: step,
          sport: sport,
          accent: accent,
          chapter: unlocks.chapterLabel(sport),
          cleared: cleared,
          total: ladder.length,
          onPlay: () => step == null
              ? showQuestGamePicker(context, sport, onPlay: onPlay)
              : onPlay(step),
          showAction: showAction || step == null,
        ),
      ],
    );
  }
}

/// A single active-contract card for the GAMES tab. Its compact HUD progress
/// avoids repeating a second header above the mission itself.
class _CompactBeginnerQuestCard extends StatelessWidget {
  const _CompactBeginnerQuestCard({
    required this.step,
    required this.sport,
    required this.accent,
    required this.chapter,
    required this.cleared,
    required this.total,
    required this.onPlay,
    required this.showAction,
  });
  final ArcadeGame? step;
  final Sport sport;
  final Color accent;
  final String chapter;
  final int cleared;
  final int total;
  final VoidCallback onPlay;
  final bool showAction;

  @override
  Widget build(BuildContext context) {
    final questTitle = chapter == 'BEGINNER'
        ? "BEGINNER'S QUEST"
        : '$chapter QUEST';
    return CyberPanel(
      accent: accent,
      glow: !showAction,
      cornerCuts: true,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Stack(
        children: [
          if (sport == Sport.football)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _MissionPitchPainter(
                    color: accent.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.flag_rounded, size: 15, color: accent),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      questTitle,
                      style: Cyber.label(10, color: accent, letterSpacing: 1.5),
                    ),
                  ),
                  Semantics(
                    label: '$cleared of $total missions complete',
                    excludeSemantics: true,
                    child: Text(
                      '${cleared.toString().padLeft(2, '0')}/${total.toString().padLeft(2, '0')}',
                      style: Cyber.display(11, color: Colors.white).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              CyberProgressBar(
                value: cleared / total,
                accent: accent,
                height: 4,
                trackColor: Cyber.bg.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MissionIconPlate(
                    icon: step?.icon ?? Icons.sports_esports_rounded,
                    color: accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step?.title ??
                              (cleared == 0
                                  ? 'CHOOSE YOUR FIRST GAME'
                                  : 'CHOOSE YOUR NEXT GAME'),
                          style: Cyber.display(18),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          step?.questRequirement ??
                              'Pick any unfinished game to begin your route.',
                          style: Cyber.bodyFor(context, 13, color: Cyber.muted),
                        ),
                        if (step?.isQuiz == true) ...[
                          const SizedBox(height: 5),
                          Text(
                            'Free beginner attempts until cleared',
                            style: Cyber.bodyFor(
                              context,
                              12,
                              color: Cyber.success,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const HudLine(),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact =
                      constraints.maxWidth < 280 ||
                      MediaQuery.textScalerOf(context).scale(12) > 15;
                  final xp = _QuestRewardRail(
                    icon: Icons.bolt_rounded,
                    label: '+$beginnerQuestStepXp XP',
                    color: Cyber.gold,
                  );
                  final unlock = step == null
                      ? null
                      : _QuestRewardRail(
                          icon: cleared == total - 1
                              ? Icons.emoji_events_outlined
                              : Icons.lock_open_rounded,
                          label: cleared == total - 1
                              ? '+$beginnerQuestCompleteOz Oz ON CLEAR'
                              : 'CHOOSE NEXT GAME ON CLEAR',
                          color: cleared == total - 1 ? Cyber.gold : accent,
                        );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (compact) ...[
                        xp,
                        if (unlock != null) ...[
                          const SizedBox(height: 8),
                          unlock,
                        ],
                      ] else
                        Row(
                          children: [
                            xp,
                            if (unlock != null) ...[
                              const SizedBox(width: 14),
                              Expanded(child: unlock),
                            ],
                          ],
                        ),
                      if (showAction) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: CyberObjectiveAction(
                              key: ValueKey(
                                step == null
                                    ? 'beginner-quest-choose'
                                    : 'beginner-quest-play',
                              ),
                              label: step == null
                                  ? 'CHOOSE GAME'
                                  : compact
                                  ? 'PLAY NOW'
                                  : 'PLAY ${step!.title}',
                              icon: step == null
                                  ? Icons.touch_app_rounded
                                  : Icons.play_arrow_rounded,
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
        ],
      ),
    );
  }
}

class _QuestRewardRail extends StatelessWidget {
  const _QuestRewardRail({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          label,
          softWrap: true,
          style: Cyber.label(
            10,
            color: color,
            letterSpacing: 0.8,
          ).copyWith(height: 1.25),
        ),
      ),
    ],
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
    final choosing = unlocks.needsSelection(sport);
    return Column(
      key: const ValueKey('rookie-path-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (choosing) ...[
          BeginnerQuestCard(sport: sport, unlocks: unlocks, onPlay: onPlay),
          const SizedBox(height: 16),
        ],
        _QuestChapterMap(
          cleared: unlocks.stepsCleared(sport),
          total: sportGameLadder[sport]!.length,
          accent: sportModuleFor(sport).accent,
        ),
        if (!choosing) ...[
          const SizedBox(height: 20),
          _RookieLadder(sport: sport, unlocks: unlocks, onPlay: onPlay),
        ],
      ],
    );
  }
}

/// The two meaningful rewards stay visible without repeating six locked games.
class _QuestChapterMap extends StatelessWidget {
  const _QuestChapterMap({
    required this.cleared,
    required this.total,
    required this.accent,
  });

  final int cleared;
  final int total;
  final Color accent;

  @override
  Widget build(BuildContext context) => CyberPanel(
    accent: accent,
    cornerCuts: true,
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('YOUR ROUTE', style: Cyber.label(10, color: accent)),
        const SizedBox(height: 12),
        for (final chapter in [
          (
            name: 'BEGINNER',
            start: 0,
            end: beginnerChapterLength,
            reward: total == beginnerChapterLength
                ? 'DAILY +$beginnerQuestCompleteOz OZ'
                : 'DAILY QUESTS',
            icon: Icons.flag_rounded,
          ),
          if (total > beginnerChapterLength)
            (
              name: 'EXPLORER',
              start: beginnerChapterLength,
              end: total,
              reward: '+$beginnerQuestCompleteOz OZ',
              icon: Icons.toll_rounded,
            ),
        ]) ...[
          if (chapter.start > 0) ...[
            const SizedBox(height: 12),
            const HudLine(),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Icon(
                chapter.icon,
                size: 18,
                color: cleared >= chapter.end ? Cyber.success : accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  chapter.name,
                  style: Cyber.display(
                    11,
                    color: cleared >= chapter.end
                        ? Cyber.success
                        : Colors.white,
                  ),
                ),
              ),
              Text(
                chapter.reward,
                style: Cyber.label(
                  9,
                  color: chapter.start > 0 || total == beginnerChapterLength
                      ? Cyber.gold
                      : accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          CyberProgressBar(
            value: ((cleared - chapter.start) / (chapter.end - chapter.start))
                .clamp(0, 1)
                .toDouble(),
            accent: cleared >= chapter.end ? Cyber.success : accent,
            height: 4,
          ),
        ],
      ],
    ),
  );
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
                        style: Cyber.bodyFor(context, 13, color: Cyber.muted),
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
    final ladder = unlocks.routeFor(sport);
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
                'GAME BOARD',
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
                        cleared: index < cleared,
                        active: ladder[index] == unlocks.currentStep(sport),
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
                                  : ladder[index] == unlocks.currentStep(sport)
                                  ? 'active'
                                  : 'locked'}',
                            ),
                            missionNumber: cleared + 1,
                            game: ladder[index],
                            cleared: index < cleared,
                            active: ladder[index] == unlocks.currentStep(sport),
                            football: sport == Sport.football,
                            accent: module.accent,
                            onTap: unlocks.isGameUnlocked(ladder[index])
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
    required this.cleared,
    required this.active,
    required this.accent,
  });

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
      child: Icon(
        cleared
            ? Icons.check_rounded
            : active
            ? Icons.bolt_rounded
            : Icons.lock_outline_rounded,
        color: color,
        size: 18,
      ),
    );
  }
}

class _RookieLadderRow extends StatelessWidget {
  const _RookieLadderRow({
    required this.missionNumber,
    required this.game,
    required this.cleared,
    required this.active,
    required this.football,
    required this.accent,
    required this.onTap,
    super.key,
  });

  final int missionNumber;
  final ArcadeGame game;
  final bool cleared;
  final bool active;
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
          '${active
              ? 'Mission $missionNumber'
              : cleared
              ? 'Completed game'
              : 'Game option'}, ${game.title}. $status. '
          '${active
              ? game.questRequirement
              : cleared
              ? 'Replay available'
              : 'Finish your current mission to choose this game'}',
      child: GestureDetector(
        key: ValueKey('mission-ticket-${game.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: activate,
        child: ChamferedActionSurface(
          clipper: const HudChamferClipper(bigCut: 10, smallCut: 2),
          borderColor: active
              ? accent.withValues(alpha: 0.9)
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
                      ? _ActiveMissionContent(
                          game: game,
                          accent: accent,
                          missionNumber: missionNumber,
                        )
                      : _CompactMissionContent(
                          game: game,
                          cleared: cleared,
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
  const _ActiveMissionContent({
    required this.game,
    required this.accent,
    required this.missionNumber,
  });

  final ArcadeGame game;
  final Color accent;
  final int missionNumber;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'LIVE CONTRACT // $missionNumber',
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
      Text(
        game.questRequirement,
        style: Cyber.bodyFor(context, 12, color: Cyber.muted),
      ),
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
    required this.color,
  });

  final ArcadeGame game;
  final bool cleared;
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
          if (!cleared)
            const Icon(
              Icons.lock_outline_rounded,
              size: 15,
              color: Cyber.muted,
            ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        cleared ? 'CLEARED · REPLAY' : 'LOCKED',
        style: Cyber.label(8.5, color: color),
      ),
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
    if (!unlocks.isQuestActive(sport)) return const SizedBox.shrink();
    final ladder = sportGameLadder[sport]!;
    final cleared = unlocks.stepsCleared(sport);
    final accent = sportModuleFor(sport).accent;
    return Semantics(
      button: true,
      label: step == null
          ? "Beginner's Quest, choose your next game"
          : "Beginner's Quest, next: play ${step.title}",
      child: GestureDetector(
        key: ValueKey('beginner-quest-strip-${sport.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          playSound(SoundEffect.uiTap);
          final choose = UnlockRevealGate.instance.chooseGame;
          if (step == null && choose != null) {
            choose(sport);
          } else {
            onTap();
          }
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
                          step == null
                              ? 'CHOOSE YOUR ${cleared == 0 ? 'FIRST' : 'NEXT'} GAME'
                              : 'VIEW QUEST - ${step.title}',
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
