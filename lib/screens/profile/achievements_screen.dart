import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/achievement.dart';
import '../../widgets/cyber/cyber_underline_tabs.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../predictions/widgets/history_hud.dart' show HistoryHeaderBar;
import 'widgets/achievement_badge.dart';

/// Opens the full achievements page (fade transition, matching the other
/// profile sub-screens).
void showAchievementsScreen(BuildContext context, AchievementStats stats) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (ctx, a, b) => AchievementsScreen(stats: stats),
      transitionsBuilder: (ctx, animation, b, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// The full achievements catalogue, grouped under PREDICTION / PICKS / GAMES
/// tabs. Each tab shows its unlock count + meter and a grid of badges that
/// re-cascade in when the tab changes. Tapping a badge opens its detail sheet.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({required this.stats, super.key});

  final AchievementStats stats;

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with SingleTickerProviderStateMixin {
  static const List<AchievementTab> _tabs = [
    AchievementTab.prediction,
    AchievementTab.picks,
    AchievementTab.games,
  ];

  late final AnimationController _entrance;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _select(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    _entrance.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final tab = _tabs[_index];
    final badges = achievementsForTab(tab);
    final unlocked = unlockedAchievementCountForTab(stats, tab);

    return Scaffold(
      backgroundColor: Cyber.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Cyber.bg)),
          const Positioned.fill(child: CyberTextureOverlay()),
          SafeArea(
            child: Column(
              children: [
                HistoryHeaderBar(
                  title: 'ACHIEVEMENTS',
                  accent: Cyber.gold,
                  onBack: () => Navigator.of(context).pop(),
                ),
                CyberUnderlineTabs(
                  labels: [for (final t in _tabs) t.label],
                  activeIndex: _index,
                  onTap: _select,
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 28),
                    children: [
                      Row(
                        children: [
                          Text(
                            'UNLOCKED',
                            style: Cyber.label(
                              10,
                              color: Cyber.muted,
                              letterSpacing: 1.6,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$unlocked / ${badges.length}',
                            style: Cyber.label(
                              13,
                              color: Cyber.gold,
                              letterSpacing: 1,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      CyberProgressBar(
                        value: badges.isEmpty ? 0 : unlocked / badges.length,
                        accent: Cyber.gold,
                        trackColor: Cyber.bg,
                      ),
                      const SizedBox(height: 20),
                      AchievementBadgeGrid(
                        badges: badges,
                        stats: stats,
                        entrance: _entrance,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
