import 'package:flutter/material.dart';

import '../../config/sport_modules.dart';
import '../../config/theme.dart';
import '../../models/sport_match.dart';
import 'cyber_underline_tabs.dart';

/// Same sport strip used on the MATCH / GAMES hub (Football, Cricket,
/// Basketball, Tennis, Motorsport) via [CyberUnderlineTabs].
class SportUnderlineTabs extends StatelessWidget {
  const SportUnderlineTabs({
    required this.activeIndex,
    required this.selectedSport,
    required this.onTap,
    this.trailingAction,
    super.key,
  });

  final int activeIndex;
  final Sport selectedSport;
  final ValueChanged<int> onTap;
  final Widget? trailingAction;

  @override
  Widget build(BuildContext context) {
    final tabs = CyberUnderlineTabs(
      labels: sportTabLabels,
      icons: sportTabIcons,
      iconColors: sportTabColors,
      activeIndex: activeIndex,
      accent: sportModuleFor(selectedSport).accent,
      onTap: onTap,
    );
    return CyberUnderlineTabsWithAction(
      tabs: tabs,
      accent: sportModuleFor(selectedSport).accent,
      action: trailingAction,
    );
  }
}

/// MATCH / GAMES browse strip: TRENDING, Football, Cricket, Basketball,
/// Motorsport, then MORE. MORE is an action, not a selectable destination.
///
/// With sport unlocks active, pass [sports] (the unlocked sports, home sport
/// first) and [lockedSports]: locked sports trail as dimmed padlocked teasers
/// that call [onLockedSportTap] instead of switching tab, and [showTrending]
/// hides the cross-sport TRENDING feed while only one sport is open.
class SportHubTabs extends StatelessWidget {
  const SportHubTabs({
    required this.activeIndex,
    required this.onTap,
    required this.onMore,
    this.trailingAction,
    this.sports,
    this.lockedSports = const [],
    this.showTrending = true,
    this.onLockedSportTap,
    super.key,
  });

  final int activeIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onMore;
  final Widget? trailingAction;
  final List<Sport>? sports;
  final List<Sport> lockedSports;
  final bool showTrending;
  final ValueChanged<Sport>? onLockedSportTap;

  /// The sports that get a shortcut on the compact strip. Everything else is
  /// reached through ALL SPORTS: the strip also carries TRENDING, the overflow
  /// and the search action, so only a few sports fit before the icons crowd.
  /// Curated rather than "all" or "all but one" — which sports earn a shortcut
  /// is a product call, and the strip should not silently grow when a sport is
  /// added to [sportTabOrder].
  static const _shortcutSports = <Sport>{
    Sport.football,
    Sport.cricket,
    Sport.basketball,
    Sport.motorsport,
  };

  /// Ordered by the canonical [sportTabOrder] so the strip never disagrees with
  /// the ALL SPORTS router, the collection, the leaderboard or the shop.
  static final _visibleSports = sportTabOrder
      .where(_shortcutSports.contains)
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final open = sports ?? _visibleSports;
    final strip = [...open, ...lockedSports];
    final lead = showTrending ? 1 : 0;
    final labels = <String>[
      if (showTrending) 'TRENDING',
      for (final sport in strip) sportModuleFor(sport).label.toUpperCase(),
      'ALL SPORTS',
    ];
    final icons = <IconData>[
      if (showTrending) Icons.local_fire_department_rounded,
      for (final sport in strip) sportModuleFor(sport).icon,
      Icons.more_horiz_rounded,
    ];
    final iconColors = <Color>[
      if (showTrending) Cyber.cyan,
      for (final sport in strip) sportModuleFor(sport).accent,
      Cyber.muted,
    ];
    final locked = <bool>[
      if (showTrending) false,
      for (final sport in strip) lockedSports.contains(sport),
      false,
    ];

    final selectedSport = sportForHubIndex(activeIndex);
    final selectedShortcut = selectedSport == null
        ? -1
        : open.indexOf(selectedSport);
    final visibleActiveIndex = activeIndex == hubTrendingTabIndex
        ? (showTrending ? 0 : -1)
        : selectedShortcut < 0
        ? -1
        : selectedShortcut + lead;
    final moreIndex = labels.length - 1;
    final accent = selectedSport == null
        ? Cyber.cyan
        : sportModuleFor(selectedSport).accent;
    final tabs = CyberUnderlineTabs(
      labels: labels,
      icons: icons,
      iconColors: iconColors,
      locked: lockedSports.isEmpty ? null : locked,
      activeIndex: visibleActiveIndex,
      accent: accent,
      onTap: (index) {
        if (index == moreIndex) {
          onMore();
          return;
        }
        if (showTrending && index == 0) {
          onTap(hubTrendingTabIndex);
          return;
        }
        final sport = strip[index - lead];
        if (lockedSports.contains(sport)) {
          onLockedSportTap?.call(sport);
          return;
        }
        onTap(hubIndexForSport(sport));
      },
    );
    return CyberUnderlineTabsWithAction(
      tabs: tabs,
      accent: accent,
      action: trailingAction,
    );
  }
}

/// Keeps the optional catalogue action in the same bordered cell across sport
/// strips. It deliberately stays calm: the selected tab retains the strip's
/// only persistent glow.
class CyberUnderlineTabsWithAction extends StatelessWidget {
  const CyberUnderlineTabsWithAction({
    required this.tabs,
    required this.accent,
    required this.action,
    super.key,
  });

  final Widget tabs;
  final Color accent;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    if (action == null) return tabs;
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          Expanded(child: tabs),
          Container(
            width: 48,
            height: 50,
            decoration: BoxDecoration(
              color: Cyber.bg.withValues(alpha: 0.4),
              border: Border(
                left: BorderSide(color: accent.withValues(alpha: 0.22)),
                bottom: BorderSide(color: accent.withValues(alpha: 0.22)),
              ),
            ),
            child: Center(child: action),
          ),
        ],
      ),
    );
  }
}
