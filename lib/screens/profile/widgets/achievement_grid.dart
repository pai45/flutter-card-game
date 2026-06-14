import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/achievement.dart';
import 'achievement_badge.dart';
import 'profile_card.dart';

/// The achievements teaser on the profile: a header with the unlocked/total
/// count and an arrow into the full achievements page, and a single row of
/// badges led by the ones you've already achieved. Badges
/// stagger in on first build (the gratification beat).
class AchievementGrid extends StatefulWidget {
  const AchievementGrid({
    required this.stats,
    required this.onViewAll,
    super.key,
  });

  final AchievementStats stats;
  final VoidCallback onViewAll;

  @override
  State<AchievementGrid> createState() => _AchievementGridState();
}

class _AchievementGridState extends State<AchievementGrid>
    with SingleTickerProviderStateMixin {
  static const int _previewCount = 4;

  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  /// The preview leads with the unlocked (achieved) badges, then fills any
  /// remaining slots with whatever is closest to unlocking.
  List<Achievement> _previewBadges(AchievementStats s) {
    final unlocked = achievementCatalog.where((a) => a.unlocked(s)).toList();
    final locked = achievementCatalog.where((a) => !a.unlocked(s)).toList()
      ..sort((a, b) => b.progress(s).compareTo(a.progress(s)));
    return [...unlocked, ...locked].take(_previewCount).toList();
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final total = achievementCatalog.length;
    final unlocked = unlockedAchievementCount(stats);

    return ProfileCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Cyber.gold, size: 18),
              const SizedBox(width: 9),
              Text(
                'ACHIEVEMENTS',
                style: Cyber.display(16, letterSpacing: 1.2),
              ),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onViewAll,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$unlocked / $total',
                      style: Cyber.label(
                        13,
                        color: Cyber.gold,
                        letterSpacing: 1,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      color: Cyber.gold,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AchievementBadgeGrid(
            badges: _previewBadges(stats),
            stats: stats,
            entrance: _entrance,
          ),
        ],
      ),
    );
  }
}
