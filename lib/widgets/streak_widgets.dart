import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/streak.dart';
import 'cyber/cyber_widgets.dart';

/// Visual state of the player's overall streak flame, derived from the local
/// day. `live` = secured today, `pending` = alive but not yet secured,
/// `atRisk` = pending late in the day, `cold` = no run.
enum StreakFlameState { cold, pending, live, atRisk }

StreakFlameState streakFlameState(StreakSnapshot streak, DateTime now) {
  if (streak.activeOn(StreakCategory.overall, now)) return StreakFlameState.live;
  if (streak.current(StreakCategory.overall, now: now) == 0) {
    return StreakFlameState.cold;
  }
  return streak.atRisk(now)
      ? StreakFlameState.atRisk
      : StreakFlameState.pending;
}

Color streakFlameColor(StreakFlameState state) => switch (state) {
  StreakFlameState.live => Cyber.gold,
  StreakFlameState.pending => Cyber.amber,
  StreakFlameState.atRisk => Cyber.danger,
  StreakFlameState.cold => Cyber.muted,
};

/// Tier accent for a milestone: gold rewards, violet for the elite packs.
Color streakMilestoneAccent(StreakMilestone milestone) =>
    milestone.rewardType == StreakRewardType.pack ? Cyber.violet : Cyber.gold;

IconData streakRewardIcon(StreakRewardType type) => switch (type) {
  StreakRewardType.coins => Icons.monetization_on,
  StreakRewardType.card => Icons.style,
  StreakRewardType.pack => Icons.inventory_2,
};

/// The streak's signature glyph. A live flame flickers, an at-risk flame
/// throbs danger-red; pending and cold flames stay still so the pulse keeps
/// meaning "look at this".
class StreakFlame extends StatelessWidget {
  const StreakFlame({
    required this.state,
    this.size = 22,
    this.animate = true,
    super.key,
  });

  final StreakFlameState state;
  final double size;

  /// Set false on persistent chrome (top bar, feed tile): always-on elements
  /// never pulse, they only change colour.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final color = streakFlameColor(state);
    final icon = state == StreakFlameState.live
        ? Icons.local_fire_department
        : Icons.local_fire_department_outlined;
    final animate =
        this.animate &&
        !MediaQuery.disableAnimationsOf(context) &&
        (state == StreakFlameState.live || state == StreakFlameState.atRisk);
    Widget glyph(double t) => Icon(
      icon,
      size: size,
      color: state == StreakFlameState.atRisk
          ? Color.lerp(color.withValues(alpha: 0.55), color, t)
          : color,
      shadows: state == StreakFlameState.live
          ? [Shadow(color: color.withValues(alpha: 0.35 + 0.3 * t), blurRadius: 10)]
          : null,
    );
    if (!animate) return glyph(1);
    return CyberPulse(
      period: state == StreakFlameState.atRisk
          ? const Duration(milliseconds: 620)
          : const Duration(milliseconds: 1100),
      builder: (context, t) => Transform.scale(
        scale: state == StreakFlameState.live ? 1 + 0.06 * t : 1,
        alignment: Alignment.bottomCenter,
        child: glyph(t),
      ),
    );
  }
}

class StreakBadge extends StatelessWidget {
  const StreakBadge({
    required this.value,
    this.compact = false,
    this.scale = 1,
    super.key,
  }) : assert(scale > 0);

  final int value;
  final bool compact;
  final double scale;

  @override
  Widget build(BuildContext context) {
    if (value <= 0) return const SizedBox.shrink();
    return Semantics(
      label: '$value day streak',
      child: SizedBox(
        height: 26 * scale,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_outlined,
              color: Cyber.gold,
              size: 16 * scale,
            ),
            if (!compact) SizedBox(width: 4 * scale),
            if (!compact)
              Text(
                '$value',
                style: Cyber.label(
                  11,
                  color: Cyber.gold,
                  letterSpacing: 0.4,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ).apply(fontSizeFactor: scale),
              ),
          ],
        ),
      ),
    );
  }
}

/// Banked shields as a row of [streakShieldCap] shield glyphs — armed shields
/// lit cyan, empty slots outlined.
class StreakShieldPips extends StatelessWidget {
  const StreakShieldPips({required this.shields, this.size = 14, super.key});

  final int shields;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$shields of $streakShieldCap streak shields',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < streakShieldCap; i++) ...[
            if (i > 0) SizedBox(width: size * 0.22),
            Icon(
              i < shields ? Icons.shield : Icons.shield_outlined,
              size: size,
              color: i < shields
                  ? Cyber.cyan
                  : Cyber.line.withValues(alpha: 0.8),
            ),
          ],
        ],
      ),
    );
  }
}

class StreakActivityMarker extends StatelessWidget {
  const StreakActivityMarker({
    required this.activity,
    this.showLabel = false,
    this.size = 6,
    super.key,
  });

  final StreakActivity activity;
  final bool showLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final marker = Transform.rotate(
      angle: 0.785398,
      child: SizedBox.square(
        dimension: size,
        child: ColoredBox(color: streakActivityColor(activity)),
      ),
    );
    if (!showLabel) return marker;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        marker,
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            streakActivityLabel(activity),
            style: Cyber.body(13, weight: FontWeight.w800, height: 1.3),
          ),
        ),
      ],
    );
  }
}

/// A seven-day "fuse" ending today: lit nodes for active days, cyan shields for
/// bridged days, a pending ring for today and dim slots for misses. Consecutive
/// chain days are joined so an unbroken run reads as one burning line.
class StreakWeekChain extends StatelessWidget {
  const StreakWeekChain({
    required this.streak,
    required this.now,
    this.category = StreakCategory.overall,
    this.accent = Cyber.gold,
    this.compact = false,
    super.key,
  });

  final StreakSnapshot streak;
  final DateTime now;
  final StreakCategory category;
  final Color accent;
  final bool compact;

  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(now);
    final days = [
      for (var offset = 6; offset >= 0; offset--)
        DateTime(today.year, today.month, today.day - offset),
    ];
    bool active(DateTime day) => streak.activeOn(category, day);
    bool shielded(DateTime day) =>
        category == StreakCategory.overall && streak.shieldedOn(day);
    bool inChain(DateTime day) => active(day) || shielded(day);
    final node = compact ? 18.0 : 26.0;

    return Row(
      children: [
        for (var i = 0; i < days.length; i++)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!compact) ...[
                  Text(
                    i == days.length - 1 ? 'NOW' : _weekdays[days[i].weekday - 1],
                    style: Cyber.label(
                      8,
                      color: i == days.length - 1 ? accent : Cyber.muted,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                SizedBox(
                  height: node,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _ChainLink(
                              lit:
                                  i > 0 &&
                                  inChain(days[i]) &&
                                  inChain(days[i - 1]),
                              accent: accent,
                            ),
                          ),
                          Expanded(
                            child: _ChainLink(
                              lit:
                                  i < days.length - 1 &&
                                  inChain(days[i]) &&
                                  inChain(days[i + 1]),
                              accent: accent,
                            ),
                          ),
                        ],
                      ),
                      _ChainNode(
                        size: node,
                        accent: accent,
                        active: active(days[i]),
                        shielded: shielded(days[i]),
                        today: i == days.length - 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ChainLink extends StatelessWidget {
  const _ChainLink({required this.lit, required this.accent});

  final bool lit;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    height: 2,
    color: lit ? accent.withValues(alpha: 0.7) : Cyber.line.withValues(alpha: 0.35),
  );
}

class _ChainNode extends StatelessWidget {
  const _ChainNode({
    required this.size,
    required this.accent,
    required this.active,
    required this.shielded,
    required this.today,
  });

  final double size;
  final Color accent;
  final bool active;
  final bool shielded;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final Color border;
    final Color fill;
    Widget? glyph;
    if (active) {
      border = accent;
      fill = accent;
      glyph = Icon(
        Icons.local_fire_department,
        size: size * 0.62,
        color: AppTheme.darkInk,
      );
    } else if (shielded) {
      border = Cyber.cyan;
      fill = Color.alphaBlend(Cyber.cyan.withValues(alpha: 0.16), Cyber.panel);
      glyph = Icon(Icons.shield, size: size * 0.56, color: Cyber.cyan);
    } else if (today) {
      border = accent.withValues(alpha: 0.8);
      fill = Cyber.panel;
      glyph = Icon(Icons.add, size: size * 0.56, color: accent);
    } else {
      border = Cyber.line.withValues(alpha: 0.55);
      fill = Cyber.bg;
    }
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: fill,
          shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(size * 0.22),
            side: BorderSide(color: border, width: today && !active ? 1.5 : 1),
          ),
        ),
        child: glyph == null ? null : Center(child: glyph),
      ),
    );
  }
}

Color streakActivityColor(StreakActivity activity) => switch (activity) {
  StreakActivity.predict => Cyber.cyan,
  StreakActivity.pick => Cyber.lime,
  StreakActivity.pitchDuel => Cyber.amber,
  StreakActivity.penaltyShootout => Cyber.violet,
  StreakActivity.guessPlayer => Cyber.amber,
};

IconData streakActivityIcon(StreakActivity activity) => switch (activity) {
  StreakActivity.predict => Icons.insights,
  StreakActivity.pick => Icons.show_chart,
  StreakActivity.pitchDuel => Icons.style,
  StreakActivity.penaltyShootout => Icons.sports_soccer,
  StreakActivity.guessPlayer => Icons.person_search,
};

/// Clipped "moment" plate shared by every streak/quest reveal and the streak
/// reminder popup. Moment screens are allowed their glow; the plate itself
/// stays a flat card fill with an accent border and top stripe.
class StreakMomentPanel extends StatelessWidget {
  const StreakMomentPanel({
    required this.accent,
    required this.child,
    super.key,
  });

  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: Cyber.glow(accent, alpha: 0.2, blur: 40, spread: -8),
      ),
      child: ChamferedActionSurface(
        clipper: const HudChamferClipper(bigCut: 20, smallCut: 6),
        borderColor: accent.withValues(alpha: 0.8),
        borderWidth: 1.5,
        child: ColoredBox(
          color: Cyber.card,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 32,
                right: 32,
                child: Container(
                  height: 2,
                  color: accent.withValues(alpha: 0.85),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
