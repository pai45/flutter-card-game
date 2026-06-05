import 'package:flutter/material.dart';

import '../config/enums.dart';
import '../config/theme.dart';
import '../utils/sound_effects.dart';

/// Premium dark bottom navigation shared by the landing surfaces (Game / Shop /
/// Top). Each tab carries its own active accent — the Top tab glows gold to read
/// as the "reward" surface, the others stay on the cyan system accent.
class LandingBottomNavigation extends StatelessWidget {
  const LandingBottomNavigation({
    required this.selectedIndex,
    required this.onNavigate,
    this.includeShop = true,
    this.onPredictionTabTap,
    super.key,
  });

  /// With [includeShop] true: 0 = Home, 1 = Leaderboard, 2 = Shop, 3 = Profile.
  /// With [includeShop] false: 0 = Matches, 1 = Shop, 2 = Top, 3 = Profile.
  final int selectedIndex;
  final ValueChanged<AppSection> onNavigate;
  final bool includeShop;
  final ValueChanged<int>? onPredictionTabTap;

  static const List<_NavSpec> _items = [
    _NavSpec(
      section: AppSection.predictions,
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'HOME',
      accent: Cyber.cyan,
    ),
    _NavSpec(
      section: AppSection.leaderboard,
      icon: Icons.emoji_events_outlined,
      activeIcon: Icons.emoji_events,
      label: 'TOP',
      accent: Cyber.gold,
    ),
    _NavSpec(
      section: AppSection.shop,
      icon: Icons.storefront_outlined,
      activeIcon: Icons.storefront,
      label: 'SHOP',
      accent: Cyber.cyan,
    ),
    _NavSpec(
      section: AppSection.profile,
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'PROFILE',
      accent: Cyber.cyan,
    ),
  ];

  static const List<_NavSpec> _predictionItems = [
    _NavSpec(
      section: AppSection.predictions,
      icon: Icons.sports_esports,
      activeIcon: Icons.sports_esports,
      label: 'MATCHES',
      accent: Color(0xffc27aff),
      predictionTabIndex: 0,
      iconKind: _NavIconKind.matches,
      activeFontSize: 12,
    ),
    _NavSpec(
      section: AppSection.shop,
      icon: Icons.storefront_outlined,
      activeIcon: Icons.storefront,
      label: 'SHOP',
      accent: Color(0xffc27aff),
    ),
    _NavSpec(
      section: AppSection.leaderboard,
      icon: Icons.emoji_events_outlined,
      activeIcon: Icons.emoji_events_outlined,
      label: 'TOP',
      accent: Color(0xffc27aff),
    ),
    _NavSpec(
      section: AppSection.profile,
      icon: Icons.person_outline,
      activeIcon: Icons.person_outline,
      label: 'PROFILE',
      accent: Color(0xffc27aff),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final items = includeShop ? _items : _predictionItems;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xf90e162b), Color(0xf91c283c)],
        ),
        border: Border.all(color: const Color(0x4cf0b000)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 1, color: Cyber.gold.withValues(alpha: 0.28)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: SizedBox(
                height: 60,
                child: Row(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      Expanded(
                        child: _NavItem(
                          spec: items[i],
                          active: selectedIndex == i,
                          onTap: () {
                            final tabIndex = items[i].predictionTabIndex;
                            if (tabIndex != null &&
                                onPredictionTabTap != null) {
                              onPredictionTabTap!(tabIndex);
                            } else {
                              onNavigate(items[i].section);
                            }
                          },
                        ),
                      ),
                      if (i != items.length - 1) const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _NavIconKind { material, matches }

class _NavSpec {
  const _NavSpec({
    required this.section,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.accent,
    this.predictionTabIndex,
    this.iconKind = _NavIconKind.material,
    this.activeFontSize = 10,
  });

  final AppSection section;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color accent;
  final int? predictionTabIndex;
  final _NavIconKind iconKind;
  final double activeFontSize;
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
    final Color color = active ? spec.accent : _inactive;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        playSound(SoundEffect.uiTap);
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? spec.accent.withValues(alpha: 0.035)
              : Colors.transparent,
          border: Border.all(
            color: active
                ? spec.accent.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.035),
            width: active ? 1 : 1.1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _NavIcon(spec: spec, color: color, active: active),
            const SizedBox(height: 6),
            SizedBox(
              height: active ? 16 : 15,
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  spec.label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.clip,
                  style: Cyber.label(
                    active ? spec.activeFontSize : 10,
                    color: color,
                    weight: active ? FontWeight.w900 : FontWeight.w600,
                    letterSpacing: 0,
                    height: active ? 1.25 : 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.spec,
    required this.color,
    required this.active,
  });

  final _NavSpec spec;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    if (spec.iconKind == _NavIconKind.matches) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CustomPaint(painter: _MatchesIconPainter(color)),
      );
    }

    return Icon(active ? spec.activeIcon : spec.icon, color: color, size: 20);
  }
}

class _MatchesIconPainter extends CustomPainter {
  const _MatchesIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final lightStroke = Paint()
      ..color = color.withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawLine(
      Offset(w * 0.22, h * 0.22),
      Offset(w * 0.77, h * 0.78),
      stroke,
    );
    canvas.drawLine(
      Offset(w * 0.78, h * 0.22),
      Offset(w * 0.23, h * 0.78),
      stroke,
    );
    canvas.drawLine(
      Offset(w * 0.13, h * 0.62),
      Offset(w * 0.32, h * 0.82),
      lightStroke,
    );
    canvas.drawLine(
      Offset(w * 0.68, h * 0.82),
      Offset(w * 0.87, h * 0.62),
      lightStroke,
    );
    canvas.drawLine(
      Offset(w * 0.30, h * 0.13),
      Offset(w * 0.40, h * 0.24),
      lightStroke,
    );
    canvas.drawLine(
      Offset(w * 0.70, h * 0.13),
      Offset(w * 0.60, h * 0.24),
      lightStroke,
    );
  }

  @override
  bool shouldRepaint(covariant _MatchesIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

const _inactive = Color(0xff6a7282);
