import 'package:flutter/material.dart';


import '../config/theme.dart';
import '../models/streak.dart';
import '../screens/predictions/widgets/history_hud.dart' show CutChipBorder;

class StreakElevatedSurface extends StatelessWidget {
  const StreakElevatedSurface({
    required this.child,
    this.padding = StreakTheme.cardPadding,
    this.borderColor = StreakTheme.primary,
    this.color = StreakTheme.surface,
    this.gradient,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color borderColor;
  final Color color;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        shape: CutChipBorder(
          cut: StreakTheme.cardCut,
          side: BorderSide(color: borderColor, width: StreakTheme.borderWidth),
        ),
        shadows: const [
          BoxShadow(
            color: StreakTheme.hardShadow,
            offset: Offset(0, StreakTheme.hardShadowDrop),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class StreakBadge extends StatelessWidget {
  const StreakBadge({required this.value, this.compact = false, super.key});

  final int value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (value <= 0) return const SizedBox.shrink();
    return Semantics(
      label: '$value day streak',
      child: SizedBox(
        height: StreakTheme.badgeHeight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_outlined,
              color: StreakTheme.primary,
              size: StreakTheme.badgeIconSize,
            ),
            if (!compact) const SizedBox(width: StreakTheme.space4),
            if (!compact)
              Text(
                '$value',
                style: StreakTheme.badge(color: StreakTheme.primary),
              ),
          ],
        ),
      ),
    );
  }
}

class StreakActivityMarker extends StatelessWidget {
  const StreakActivityMarker({
    required this.activity,
    this.showLabel = false,
    super.key,
  });

  final StreakActivity activity;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final color = streakActivityColor(activity);
    final marker = Container(
      width: StreakTheme.markerSize,
      height: StreakTheme.markerSize,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    if (!showLabel) return marker;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        marker,
        const SizedBox(width: StreakTheme.space6),
        Flexible(
          child: Text(
            streakActivityLabel(activity),
            style: StreakTheme.bodyStrong(),
          ),
        ),
      ],
    );
  }
}

class StreakProgressBar extends StatelessWidget {
  const StreakProgressBar({
    required this.value,
    this.color = StreakTheme.primary,
    super.key,
  });

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        height: StreakTheme.progressHeight,
        child: LinearProgressIndicator(
          value: value.clamp(0, 1),
          backgroundColor: StreakTheme.locked,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    );
  }
}

enum StreakMilestoneVisualState { locked, reached, claimable, claimed }

class StreakMilestoneCard extends StatelessWidget {
  const StreakMilestoneCard({
    required this.milestone,
    required this.state,
    this.onClaim,
    super.key,
  });

  final StreakMilestone milestone;
  final StreakMilestoneVisualState state;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      StreakMilestoneVisualState.claimed => StreakTheme.success,
      StreakMilestoneVisualState.claimable => StreakTheme.primary,
      StreakMilestoneVisualState.reached => StreakTheme.secondary,
      StreakMilestoneVisualState.locked => StreakTheme.locked,
    };
    final status = switch (state) {
      StreakMilestoneVisualState.claimed => 'CLAIMED',
      StreakMilestoneVisualState.claimable => 'READY',
      StreakMilestoneVisualState.reached => 'REACHED',
      StreakMilestoneVisualState.locked => 'LOCKED',
    };
    return StreakElevatedSurface(
      borderColor: color,
      gradient: state == StreakMilestoneVisualState.locked
          ? null
          : StreakTheme.milestoneGradient,
      child: Row(
        children: [
          Icon(
            _rewardIcon(milestone.rewardType),
            color: color,
            size: StreakTheme.badgeIconSize,
          ),
          const SizedBox(width: StreakTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${milestone.days} DAYS',
                  style: StreakTheme.sectionTitle(color: color),
                ),
                const SizedBox(height: StreakTheme.space4),
                Text(milestone.rewardLabel, style: StreakTheme.bodyStrong()),
              ],
            ),
          ),
          if (state == StreakMilestoneVisualState.claimable)
            StreakClaimButton(onPressed: onClaim)
          else
            Text(status, style: StreakTheme.label(color: color)),
        ],
      ),
    );
  }
}

class StreakClaimButton extends StatelessWidget {
  const StreakClaimButton({
    required this.onPressed,
    this.label = 'CLAIM',
    super.key,
  });

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: StreakTheme.buttonHeight,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: StreakTheme.primary,
          foregroundColor: StreakTheme.selectedInk,
          padding: StreakTheme.buttonPadding,
          shape: const BeveledRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(StreakTheme.cardCut),
            ),
          ),
          textStyle: StreakTheme.badge(color: StreakTheme.selectedInk),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

Color streakActivityColor(StreakActivity activity) =>
    StreakTheme.activityColor(switch (activity) {
      StreakActivity.predict => StreakActivityVisual.predict,
      StreakActivity.pick => StreakActivityVisual.pick,
      StreakActivity.pitchDuel => StreakActivityVisual.pitchDuel,
      StreakActivity.penaltyShootout => StreakActivityVisual.penaltyShootout,
    });

IconData _rewardIcon(StreakRewardType type) => switch (type) {
  StreakRewardType.coins => Icons.monetization_on,
  StreakRewardType.card => Icons.style,
  StreakRewardType.pack => Icons.inventory_2,
};
