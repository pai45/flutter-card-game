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
    super.key,
  });

  final int activeIndex;
  final Sport selectedSport;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return CyberUnderlineTabs(
      labels: sportTabLabels,
      icons: sportTabIcons,
      activeIndex: activeIndex,
      accent: sportModuleFor(selectedSport).accent,
      onTap: onTap,
    );
  }
}

/// MATCH / GAMES browse strip: TRENDING, four direct sports, then MORE.
///
/// Motorsport remains available in All Sports without squeezing the primary
/// shortcuts. MORE is an action, not a selectable destination.
class SportHubTabs extends StatelessWidget {
  const SportHubTabs({
    required this.activeIndex,
    required this.onTap,
    required this.onMore,
    super.key,
  });

  final int activeIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onMore;

  static final _visibleSports = sportTabOrder
      .where((sport) => sport != Sport.motorsport)
      .toList(growable: false);

  static final _labels = <String>[
    'TRENDING',
    for (final sport in _visibleSports)
      sportModuleFor(sport).label.toUpperCase(),
    'ALL SPORTS',
  ];

  static final _icons = <IconData>[
    Icons.local_fire_department_rounded,
    for (final sport in _visibleSports) sportModuleFor(sport).icon,
    Icons.more_horiz_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final selectedSport = sportForHubIndex(activeIndex);
    final selectedShortcut = selectedSport == null
        ? -1
        : _visibleSports.indexOf(selectedSport);
    final visibleActiveIndex = activeIndex == hubTrendingTabIndex
        ? hubTrendingTabIndex
        : selectedShortcut < 0
        ? -1
        : selectedShortcut + 1;
    final moreIndex = _labels.length - 1;
    return CyberUnderlineTabs(
      labels: _labels,
      icons: _icons,
      activeIndex: visibleActiveIndex,
      accent: selectedSport == null
          ? Cyber.cyan
          : sportModuleFor(selectedSport).accent,
      onTap: (index) {
        if (index == moreIndex) {
          onMore();
          return;
        }
        if (index == hubTrendingTabIndex) {
          onTap(hubTrendingTabIndex);
          return;
        }
        onTap(hubIndexForSport(_visibleSports[index - 1]));
      },
    );
  }
}
