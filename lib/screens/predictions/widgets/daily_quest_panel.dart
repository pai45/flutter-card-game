import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../blocs/game/game_bloc.dart';
import '../../../blocs/game/game_event.dart';
import '../../../blocs/game/game_state.dart';
import '../../../config/theme.dart';
import '../../../models/daily_quest.dart';
import '../../../models/streak.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_cta_button.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

enum QuestDestination {
  pitchDuel,
  penaltyShootout,
  guessPlayer,
  prediction,
  pick,
}

String questTitle(DailyQuestId id) => switch (id) {
  DailyQuestId.kickOff => 'KICK OFF',
  DailyQuestId.makeYourCall => 'MAKE YOUR CALL',
  DailyQuestId.backYourPlay => 'BACK YOUR PLAY',
  DailyQuestId.dailySweep => 'DAILY SWEEP',
};

Color questAccent(DailyQuestId id) => switch (id) {
  DailyQuestId.kickOff => Cyber.amber,
  DailyQuestId.makeYourCall => Cyber.cyan,
  DailyQuestId.backYourPlay => Cyber.lime,
  DailyQuestId.dailySweep => Cyber.gold,
};

IconData _questIcon(DailyQuestId id) => switch (id) {
  DailyQuestId.kickOff => Icons.sports_esports,
  DailyQuestId.makeYourCall => Icons.insights,
  DailyQuestId.backYourPlay => Icons.show_chart,
  DailyQuestId.dailySweep => Icons.shield,
};

/// Time left until local midnight, when incomplete quests expire.
Duration questTimeLeft(DateTime now) =>
    DateTime(now.year, now.month, now.day + 1).difference(now);

String questClock(Duration left) =>
    '${left.inHours}H ${left.inMinutes.remainder(60).toString().padLeft(2, '0')}M';

/// The TODAY loop: an ops header, one objective card per quest, and the
/// reward vault whose CLAIM CTA is the panel's single glowing element.
class DailyQuestPanel extends StatelessWidget {
  const DailyQuestPanel({required this.state, this.onNavigate, super.key});
  final GameState state;
  final ValueChanged<QuestDestination>? onNavigate;

  Future<void> _chooseGame(BuildContext context) async {
    final destination = await showModalBottomSheet<QuestDestination>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (context) => const _GameChooserSheet(),
    );
    if (destination != null) onNavigate?.call(destination);
  }

  @override
  Widget build(BuildContext context) {
    final quests = state.dailyQuests;
    final today = quests.today;
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QuestOpsHeader(today: today, left: questTimeLeft(now)),
        const SizedBox(height: 14),
        for (final id in DailyQuestId.values) ...[
          _questCard(context, id),
          const SizedBox(height: 10),
        ],
        if (state.questError != null) ...[
          CyberPanel(
            accent: Cyber.danger,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.sync_problem, color: Cyber.danger, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    state.questError!,
                    style: Cyber.body(13, color: Cyber.danger),
                  ),
                ),
                const SizedBox(width: 8),
                CyberObjectiveAction(
                  label: 'RETRY SYNC',
                  icon: Icons.refresh,
                  onTap: () =>
                      context.read<GameBloc>().add(DailyQuestsRefreshed()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 4),
        _RewardVault(
          quests: quests,
          claiming: state.questClaiming,
          enabled: !state.loading && !state.questClaiming,
        ),
      ],
    );
  }

  Widget _questCard(BuildContext context, DailyQuestId id) {
    final quests = state.dailyQuests;
    final today = quests.today;
    final claimed = quests.claimed.contains(quests.rewardId(id));
    final completed = today.completed(id);
    final isSweep = id == DailyQuestId.dailySweep;
    final navigate = onNavigate;
    return CyberObjectiveCard(
      key: ValueKey('quest_${id.name}'),
      index: id.index + 1,
      icon: _questIcon(id),
      accent: questAccent(id),
      title: questTitle(id),
      description: switch (id) {
        DailyQuestId.kickOff => 'Finish any game.',
        DailyQuestId.makeYourCall => '1 prediction or 2 games.',
        DailyQuestId.backYourPlay => '1 pick or 3 games.',
        DailyQuestId.dailySweep => 'Clear all 3 quests.',
      },
      reward: '+${DailyQuestConfig.rewards[id]} OZ',
      rewardDetail: !isSweep
          ? null
          : completed || state.streak.shields < streakShieldCap
          ? '+1 SHIELD'
          : 'SHIELDS FULL',
      progress: today.progress(id),
      segments: isSweep ? 3 : null,
      state: claimed
          ? CyberObjectiveState.claimed
          : completed
          ? CyberObjectiveState.ready
          : CyberObjectiveState.active,
      status: claimed
          ? 'CLAIMED'
          : completed
          ? 'READY'
          : isSweep
          ? '${today.completedCount}/3'
          : '${today.games}/${id.index + 1}',
      actions: completed || isSweep
          ? null
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                CyberObjectiveAction(
                  label: 'PLAY GAME',
                  icon: Icons.sports_esports,
                  accent: Cyber.amber,
                  onTap: navigate == null ? null : () => _chooseGame(context),
                ),
                if (id != DailyQuestId.kickOff)
                  CyberObjectiveAction(
                    label: id == DailyQuestId.makeYourCall
                        ? 'PREDICT'
                        : 'MAKE PICK',
                    icon: id == DailyQuestId.makeYourCall
                        ? Icons.insights
                        : Icons.show_chart,
                    accent: questAccent(id),
                    onTap: navigate == null
                        ? null
                        : () => navigate(
                            id == DailyQuestId.makeYourCall
                                ? QuestDestination.prediction
                                : QuestDestination.pick,
                          ),
                  ),
              ],
            ),
    );
  }
}

/// Three quest segments plus the sweep diamond — the compact "how far through
/// today" read shared by the ops header and the home tile.
class DailyQuestPips extends StatelessWidget {
  const DailyQuestPips({required this.day, this.segmentWidth = 20, super.key});

  final DailyQuestDay day;
  final double segmentWidth;

  @override
  Widget build(BuildContext context) {
    final swept = day.completed(DailyQuestId.dailySweep);
    return Semantics(
      label: '${day.completedCount} of 3 daily quests complete',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final id in DailyQuestId.values.take(3)) ...[
            Container(
              width: segmentWidth,
              height: 6,
              color: day.completed(id)
                  ? Cyber.success
                  : Cyber.line.withValues(alpha: 0.55),
            ),
            const SizedBox(width: 3),
          ],
          const SizedBox(width: 2),
          Transform.rotate(
            angle: 0.785398,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: swept ? Cyber.gold : Colors.transparent,
                border: Border.all(
                  color: swept ? Cyber.gold : Cyber.line,
                  width: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestOpsHeader extends StatelessWidget {
  const _QuestOpsHeader({required this.today, required this.left});

  final DailyQuestDay today;
  final Duration left;

  @override
  Widget build(BuildContext context) {
    // One row: title, today's pips, reset clock. Eligibility rules live on the
    // game chooser sheet, where they matter.
    return Row(
      children: [
        Container(width: 18, height: 2, color: Cyber.gold),
        const SizedBox(width: 8),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('DAILY QUESTS', style: Cyber.display(15)),
          ),
        ),
        const SizedBox(width: 10),
        DailyQuestPips(day: today, segmentWidth: 16),
        const SizedBox(width: 12),
        const Icon(Icons.timer_outlined, size: 13, color: Cyber.muted),
        const SizedBox(width: 4),
        Text(
          questClock(left),
          style: Cyber.label(
            10,
            color: Cyber.muted,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _RewardVault extends StatelessWidget {
  const _RewardVault({
    required this.quests,
    required this.claiming,
    required this.enabled,
  });

  final DailyQuestSnapshot quests;
  final bool claiming;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final coins = quests.claimableCoins;
    final carried = quests.claimable.keys.any(
      (key) => !key.startsWith('quest-${quests.dayKey}-'),
    );
    final ready = coins > 0;
    final allCleared = quests.today.completedCount == 3;
    // Empty vault = one calm row; the CTA only appears when there is a payout.
    return CyberPanel(
      accent: ready ? Cyber.gold : Cyber.line,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                'assets/icons/oz_coins.svg',
                width: 24,
                height: 24,
                colorFilter: ready
                    ? null
                    : const ColorFilter.mode(Cyber.muted, BlendMode.srcIn),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ready
                      ? carried
                            ? 'REWARD VAULT · INCL. EARLIER DAYS'
                            : 'REWARD VAULT'
                      : allCleared
                      ? 'VAULT EMPTY · BACK TOMORROW'
                      : 'VAULT EMPTY · CLEAR A QUEST',
                  style: Cyber.label(
                    10,
                    color: ready ? Cyber.gold : Cyber.muted,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              if (ready)
                TweenAnimationBuilder<double>(
                  tween: Tween(end: coins.toDouble()),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => Text(
                    '+${value.round()} OZ',
                    style: Cyber.display(18, color: Cyber.gold, letterSpacing: 0)
                        .copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ),
            ],
          ),
          if (ready || claiming) ...[
            const SizedBox(height: 12),
            HudCtaButton(
              labelStyle: Cyber.display(20),
              label: claiming ? 'CLAIMING…' : 'CLAIM REWARDS',
              icon: Icons.redeem,
              accent: Cyber.gold,
              height: 56,
              glow: ready && enabled,
              tapSound: SoundEffect.uiConfirm,
              enabled: enabled && ready,
              onTap: () =>
                  context.read<GameBloc>().add(DailyQuestRewardsClaimed()),
            ),
          ],
        ],
      ),
    );
  }
}

class _GameChooserSheet extends StatelessWidget {
  const _GameChooserSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: ClipPath(
        clipper: const HudChamferClipper(bigCut: 18, smallCut: 4),
        child: CustomPaint(
          foregroundPainter: const HudSheetFramePainter(),
          child: ColoredBox(
            color: Cyber.card,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('CHOOSE YOUR GAME', style: Cyber.display(16)),
                  const SizedBox(height: 6),
                  Text(
                    'EVERY FINISHED GAME COUNTS · WINNING OPTIONAL',
                    style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1),
                  ),
                  const SizedBox(height: 14),
                  const _GameChoiceTile(
                    destination: QuestDestination.pitchDuel,
                    title: 'PITCH DUEL',
                    icon: Icons.style,
                    accent: Cyber.cyan,
                  ),
                  const SizedBox(height: 8),
                  const _GameChoiceTile(
                    destination: QuestDestination.penaltyShootout,
                    title: 'PENALTY SHOOTOUT',
                    icon: Icons.sports_soccer,
                    accent: Cyber.violet,
                  ),
                  const SizedBox(height: 8),
                  const _GameChoiceTile(
                    destination: QuestDestination.guessPlayer,
                    title: 'DAILY GUESS THE PLAYER',
                    icon: Icons.person_search,
                    accent: Cyber.lime,
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

class _GameChoiceTile extends StatelessWidget {
  const _GameChoiceTile({
    required this.destination,
    required this.title,
    required this.icon,
    required this.accent,
  });

  final QuestDestination destination;
  final String title;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          playSound(SoundEffect.uiConfirm);
          Navigator.pop(context, destination);
        },
        child: ChamferedActionSurface(
          clipper: const HudChamferClipper(bigCut: 10, smallCut: 3),
          borderColor: accent.withValues(alpha: 0.45),
          child: ColoredBox(
            color: Cyber.panel,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: ColoredBox(
                      color: Color.alphaBlend(
                        accent.withValues(alpha: 0.14),
                        Cyber.panel2,
                      ),
                      child: Icon(icon, color: accent, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(title, style: Cyber.display(13))),
                  Icon(Icons.chevron_right, color: accent, size: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
