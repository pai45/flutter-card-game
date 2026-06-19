import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../predictions/widgets/history_hud.dart' show HistoryStatCell;
import 'profile_card.dart';
import '../../../widgets/streak_widgets.dart';

/// One cell of a [ProfileStatBand]. Pass [value] for an animated count-up
/// number (with an optional [suffix] like `%`), or [text] for a static string
/// such as a streak with an icon.
class ProfileStat {
  const ProfileStat.number(
    this.label,
    int this.value, {
    this.suffix = '',
    this.valueColor,
  }) : text = null;

  const ProfileStat.text(this.label, String this.text, {this.valueColor})
    : value = null,
      suffix = '';

  final String label;
  final int? value;
  final String? text;
  final String suffix;
  final Color? valueColor;
}

/// A career/picks telemetry band: an accent-titled header with an optional
/// "History" link, over a row of matte HUD stat cells. Reuses
/// [HistoryStatCell] for the cells and animates the numeric values up.
class ProfileStatBand extends StatelessWidget {
  const ProfileStatBand({
    required this.title,
    required this.accent,
    required this.icon,
    required this.stats,
    this.streak = 0,
    this.onViewHistory,
    super.key,
  });

  final String title;
  final Color accent;
  final Widget icon;
  final List<ProfileStat> stats;
  final int streak;
  final VoidCallback? onViewHistory;

  @override
  Widget build(BuildContext context) {
    return ProfileCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(width: 20, height: 20, child: Center(child: icon)),
              const SizedBox(width: 9),
              Text(
                title,
                style: Cyber.display(15, color: accent, letterSpacing: 1),
              ),
              if (streak > 0) ...[
                const SizedBox(width: StreakTheme.space8),
                StreakBadge(value: streak),
              ],
              const Spacer(),
              if (onViewHistory != null)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onViewHistory,
                  child: Row(
                    children: [
                      Text(
                        'HISTORY',
                        style: Cyber.label(
                          10,
                          color: accent.withValues(alpha: 0.9),
                          letterSpacing: 1.4,
                        ),
                      ),
                      Icon(Icons.chevron_right, color: accent, size: 18),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _StatCell(stat: stats[i], accent: accent),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.stat, required this.accent});

  final ProfileStat stat;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final value = stat.value;
    if (value == null) {
      return HistoryStatCell(
        label: stat.label,
        value: stat.text ?? '',
        accent: accent,
        valueColor: stat.valueColor,
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => HistoryStatCell(
        label: stat.label,
        value: '${v.round()}${stat.suffix}',
        accent: accent,
        valueColor: stat.valueColor,
      ),
    );
  }
}
