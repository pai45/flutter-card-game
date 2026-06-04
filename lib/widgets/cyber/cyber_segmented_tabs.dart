import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../utils/sound_effects.dart';

/// Top segmented tab bar with an animated underline indicator — the shared
/// pattern behind the prediction home (MATCHES / PICK / GAMES) and reusable on
/// any landing surface. Active label uses the system cyan; the indicator glows
/// (it's the one "live" element here), everything else stays calm per the glow
/// rule.
class CyberSegmentedTabs extends StatelessWidget {
  const CyberSegmentedTabs({
    required this.items,
    required this.activeIndex,
    required this.onTap,
    this.accent = Cyber.cyan,
    this.height = 50,
    super.key,
  });

  final List<String> items;
  final int activeIndex;
  final ValueChanged<int> onTap;
  final Color accent;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Cyber.bg.withValues(alpha: 0.4),
        border: Border(
          bottom: BorderSide(color: accent.withValues(alpha: 0.22)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / items.length;
          return Stack(
            children: [
              Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _Tab(
                        label: items[i],
                        active: activeIndex == i,
                        accent: accent,
                        onTap: () {
                          playSound(SoundEffect.uiTap);
                          onTap(i);
                        },
                      ),
                    ),
                ],
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: tabWidth * activeIndex + tabWidth * 0.18,
                bottom: 0,
                width: tabWidth * 0.64,
                height: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent,
                    boxShadow: Cyber.glow(accent, alpha: 0.7, blur: 10),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? accent : Cyber.muted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.07) : Colors.transparent,
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontFamily: Cyber.displayFont,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
