import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/achievement.dart';
import '../../../utils/label_helpers.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../predictions/widgets/history_hud.dart' show CutChipBorder;

/// A single achievement badge: a cut-corner tier-coloured plate, the title, and
/// a thin progress bar while it's still being worked towards. Matte at rest
/// (the focal glow on the profile lives on the hero XP meter, per the glow
/// rule). Tapping opens [showAchievementDetail].
class AchievementBadge extends StatelessWidget {
  const AchievementBadge({
    required this.achievement,
    required this.stats,
    super.key,
  });

  static const double width = 74;

  final Achievement achievement;
  final AchievementStats stats;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked(stats);
    final progress = achievement.progress(stats);
    final tier = tierColor(achievement.tier);
    final inProgress = !unlocked && progress > 0;

    return PressableScale(
      onTap: () => showAchievementDetail(context, achievement, stats),
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BadgePlate(
              icon: achievement.icon,
              tier: tier,
              unlocked: unlocked,
              inProgress: inProgress,
            ),
            const SizedBox(height: 7),
            SizedBox(
              height: 24,
              child: Text(
                achievement.title.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Cyber.label(
                  8,
                  color: unlocked
                      ? Colors.white
                      : Cyber.muted.withValues(alpha: 0.7),
                  letterSpacing: 0.6,
                  height: 1.2,
                ),
              ),
            ),
            if (inProgress) ...[
              const SizedBox(height: 5),
              CyberProgressBar(
                value: progress,
                accent: tier,
                height: 3,
                trackColor: Cyber.bg,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BadgePlate extends StatelessWidget {
  const _BadgePlate({
    required this.icon,
    required this.tier,
    required this.unlocked,
    required this.inProgress,
  });

  final IconData icon;
  final Color tier;
  final bool unlocked;
  final bool inProgress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: ShapeDecoration(
              color: unlocked
                  ? Color.lerp(Cyber.card, tier, 0.16)
                  : Cyber.panel2.withValues(alpha: 0.55),
              shape: CutChipBorder(
                cut: 11,
                side: BorderSide(
                  color: unlocked
                      ? tier.withValues(alpha: 0.85)
                      : Cyber.line.withValues(alpha: 0.30),
                  width: unlocked ? 1.5 : 1,
                ),
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 26,
                color: unlocked ? tier : Cyber.muted.withValues(alpha: 0.45),
              ),
            ),
          ),
          // Locked + not yet started → a small padlock marker bottom-right.
          if (!unlocked && !inProgress)
            Positioned(
              right: 3,
              bottom: 3,
              child: Icon(
                Icons.lock,
                size: 11,
                color: Cyber.muted.withValues(alpha: 0.55),
              ),
            ),
        ],
      ),
    );
  }
}

/// Detail sheet for a single achievement — big plate, description, and either an
/// UNLOCKED chip or a progress bar with the current/target count.
Future<void> showAchievementDetail(
  BuildContext context,
  Achievement achievement,
  AchievementStats stats,
) {
  final unlocked = achievement.unlocked(stats);
  final tier = tierColor(achievement.tier);
  final current = achievement.current(stats);

  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.8),
    builder: (context) => Dialog(
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: CyberPanel(
          accent: tier,
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AchievementBadgePlate(
                icon: achievement.icon,
                tier: tier,
                unlocked: unlocked,
              ),
              const SizedBox(height: 16),
              Text(
                achievement.title.toUpperCase(),
                textAlign: TextAlign.center,
                style: Cyber.display(20, color: Colors.white, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              Text(
                achievement.description,
                textAlign: TextAlign.center,
                style: Cyber.body(13, color: Cyber.muted),
              ),
              const SizedBox(height: 18),
              if (unlocked)
                CyberChip(label: 'UNLOCKED', color: tier)
              else ...[
                CyberProgressBar(value: achievement.progress(stats), accent: tier),
                const SizedBox(height: 8),
                Text(
                  '$current / ${achievement.target}',
                  style: Cyber.label(
                    11,
                    color: Cyber.muted,
                    letterSpacing: 1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

/// A justified, wrapping grid of [AchievementBadge]s. When [entrance] is given,
/// the badges fade + pop in, staggered by position (the gratification beat).
class AchievementBadgeGrid extends StatelessWidget {
  const AchievementBadgeGrid({
    required this.badges,
    required this.stats,
    this.entrance,
    super.key,
  });

  final List<Achievement> badges;
  final AchievementStats stats;
  final AnimationController? entrance;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const badgeW = AchievementBadge.width;
        final width = constraints.maxWidth;
        var columns = ((width + 10) / (badgeW + 10)).floor();
        columns = columns.clamp(3, 6);
        final spacing = columns > 1
            ? (width - columns * badgeW) / (columns - 1)
            : 0.0;
        return Wrap(
          spacing: spacing,
          runSpacing: 18,
          children: [
            for (var i = 0; i < badges.length; i++)
              _maybeStagger(
                i,
                badges.length,
                AchievementBadge(achievement: badges[i], stats: stats),
              ),
          ],
        );
      },
    );
  }

  Widget _maybeStagger(int index, int count, Widget child) {
    final controller = entrance;
    if (controller == null) return child;
    return _StaggeredBadge(
      controller: controller,
      index: index,
      count: count,
      child: child,
    );
  }
}

/// Fades + pops a single badge in, offset by its position so the grid cascades.
class _StaggeredBadge extends StatelessWidget {
  const _StaggeredBadge({
    required this.controller,
    required this.index,
    required this.count,
    required this.child,
  });

  final AnimationController controller;
  final int index;
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = count <= 1 ? 0.0 : (index / count * 0.5).clamp(0.0, 0.5);
    final end = (start + 0.5).clamp(0.0, 1.0);
    // Opacity must stay within [0, 1], so the fade uses a non-overshooting
    // curve while the scale gets the bouncy easeOutBack.
    final fade = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
    final scale = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutBack),
    );
    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(scale: scale, child: child),
    );
  }
}

/// The big tier-coloured cut-corner badge plate used in the detail sheet and
/// reused by the [AchievementUnlockCelebration] reveal. [size] scales both the
/// plate and the glyph so it can grow for the celebration "moment".
class AchievementBadgePlate extends StatelessWidget {
  const AchievementBadgePlate({
    required this.icon,
    required this.tier,
    required this.unlocked,
    this.size = 84,
    super.key,
  });

  final IconData icon;
  final Color tier;
  final bool unlocked;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: unlocked
            ? Color.lerp(Cyber.card, tier, 0.18)
            : Cyber.panel2.withValues(alpha: 0.6),
        shape: CutChipBorder(
          cut: size * 0.167,
          side: BorderSide(
            color: unlocked
                ? tier.withValues(alpha: 0.9)
                : Cyber.line.withValues(alpha: 0.35),
            width: unlocked ? 1.8 : 1,
          ),
        ),
      ),
      child: Center(
        child: Icon(
          unlocked ? icon : Icons.lock,
          size: size * 0.452,
          color: unlocked ? tier : Cyber.muted.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
