import 'package:flutter/material.dart';

import '../config/enums.dart';
import '../config/theme.dart';

/// Premium dark bottom navigation shared by the landing surfaces (Game / Shop /
/// Top). Each tab carries its own active accent — the Top tab glows gold to read
/// as the "reward" surface, the others stay on the cyan system accent.
class LandingBottomNavigation extends StatelessWidget {
  const LandingBottomNavigation({
    required this.selectedIndex,
    required this.onNavigate,
    super.key,
  });

  /// 0 = Game, 1 = Shop, 2 = Top (leaderboard).
  final int selectedIndex;
  final ValueChanged<AppSection> onNavigate;

  static const List<_NavSpec> _items = [
    _NavSpec(
      section: AppSection.game,
      icon: Icons.sports_esports_outlined,
      activeIcon: Icons.sports_esports,
      label: 'GAME',
      accent: Cyber.cyan,
    ),
    _NavSpec(
      section: AppSection.shop,
      icon: Icons.storefront_outlined,
      activeIcon: Icons.storefront,
      label: 'SHOP',
      accent: Cyber.cyan,
    ),
    _NavSpec(
      section: AppSection.leaderboard,
      icon: Icons.emoji_events_outlined,
      activeIcon: Icons.emoji_events,
      label: 'TOP',
      accent: Cyber.gold,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 72,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff10192b), Color(0xff070b14)],
          ),
          border: Border.all(color: Cyber.line),
          boxShadow: [
            BoxShadow(
              color: Cyber.cyan.withValues(alpha: 0.12),
              blurRadius: 20,
              spreadRadius: -6,
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: _NavItem(
                  spec: _items[i],
                  active: selectedIndex == i,
                  onTap: () => onNavigate(_items[i].section),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavSpec {
  const _NavSpec({
    required this.section,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.accent,
  });

  final AppSection section;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color accent;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.spec,
    required this.active,
    required this.onTap,
  });

  final _NavSpec spec;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = active ? spec.accent : Cyber.muted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: active ? spec.accent.withValues(alpha: 0.10) : null,
          border: Border.all(
            color: active
                ? spec.accent.withValues(alpha: 0.45)
                : Colors.transparent,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: spec.accent.withValues(alpha: 0.28),
                    blurRadius: 16,
                    spreadRadius: -4,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? spec.activeIcon : spec.icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              spec.label,
              style: TextStyle(
                color: color,
                fontFamily: Cyber.displayFont,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
