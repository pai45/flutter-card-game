import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/game/game_bloc.dart';
import '../../../blocs/game/game_state.dart';
import '../../../config/theme.dart';
import '../../../models/daily_quest.dart';
import '../../../models/streak.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/streak_widgets.dart';
import 'daily_quest_panel.dart';

/// The home-feed door into the streak hub: live flame + run, today's quest
/// pips and the single most useful next line. Its border only pulses when a
/// reward is waiting in the vault, so the tile stays calm chrome otherwise.
/// Feed type floor is 10px (enforced by the Trending 320px readability test).
class DailyQuestHomeTile extends StatelessWidget {
  const DailyQuestHomeTile({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      buildWhen: (previous, current) =>
          previous.streak != current.streak ||
          previous.dailyQuests != current.dailyQuests,
      builder: (context, state) {
        final now = DateTime.now();
        final streak = state.streak;
        final flame = streakFlameState(streak, now);
        final current = streak.current(StreakCategory.overall, now: now);
        final quests = state.dailyQuests.refresh(now);
        final today = quests.today;
        final claimable = quests.claimableCoins;
        final remainingOz = DailyQuestId.values
            .where((id) => !today.completed(id))
            .fold<int>(0, (sum, id) => sum + DailyQuestConfig.rewards[id]!);
        final (line, lineColor) = claimable > 0
            ? ('$claimable OZ READY · TAP TO CLAIM', Cyber.gold)
            : flame == StreakFlameState.atRisk
            ? ('STREAK AT RISK · ${questClock(questTimeLeft(now))} LEFT', Cyber.danger)
            : today.completedCount == 3
            ? ('ALL CLEAR · BACK TOMORROW', Cyber.success)
            : (
                '${3 - today.completedCount} QUESTS LEFT · +$remainingOz OZ',
                Cyber.muted,
              );
        final border = claimable > 0
            ? Cyber.gold
            : flame == StreakFlameState.atRisk
            ? Cyber.danger.withValues(alpha: 0.7)
            : Cyber.border;
        final reduced = MediaQuery.disableAnimationsOf(context);

        Widget surface(double t) => ChamferedActionSurface(
          clipper: const HudChamferClipper(bigCut: 12, smallCut: 4),
          borderColor: claimable > 0
              ? border.withValues(alpha: 0.55 + 0.4 * t)
              : border,
          glowColor: Cyber.gold,
          glow: claimable > 0 ? t : 0,
          child: ColoredBox(
            color: Cyber.panel,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  StreakFlame(state: flame, size: 26, animate: false),
                  const SizedBox(width: 4),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$current',
                        style: Cyber.display(
                          20,
                          color: flame == StreakFlameState.cold
                              ? Colors.white.withValues(alpha: 0.7)
                              : streakFlameColor(flame),
                          letterSpacing: 0,
                        ).copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        current == 1 ? 'DAY' : 'DAYS',
                        style: Cyber.label(10, color: Cyber.muted),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 1,
                    height: 34,
                    color: Cyber.line.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'DAILY QUESTS',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Cyber.label(10, letterSpacing: 1.3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            DailyQuestPips(day: today, segmentWidth: 13),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Cyber.label(
                            10,
                            color: lineColor,
                            letterSpacing: 0.4,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (claimable > 0)
                    ClipPath(
                      clipper: const HudChamferClipper(bigCut: 6, smallCut: 2),
                      child: ColoredBox(
                        color: Cyber.gold,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          child: Text(
                            'CLAIM',
                            style: Cyber.label(10, color: AppTheme.darkInk),
                          ),
                        ),
                      ),
                    )
                  else if (streak.shields > 0)
                    StreakShieldPips(shields: streak.shields, size: 13)
                  else
                    const Icon(Icons.chevron_right, color: Cyber.muted, size: 22),
                ],
              ),
            ),
          ),
        );

        return Semantics(
          button: true,
          label: 'Daily quests and streak. $line',
          child: GestureDetector(
            key: const ValueKey('daily-quest-home-tile'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              playSound(SoundEffect.uiTap);
              onTap();
            },
            child: claimable > 0 && !reduced
                ? CyberPulse(
                    period: const Duration(milliseconds: 1400),
                    builder: (context, t) => surface(t),
                  )
                : surface(claimable > 0 ? 1 : 0),
          ),
        );
      },
    );
  }
}
