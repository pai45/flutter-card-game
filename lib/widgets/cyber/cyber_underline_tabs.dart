import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../utils/sound_effects.dart';

/// Flat top tab bar with a sliding, glowing underline — the bar style used on
/// the shop (AVATAR / BANNER / COINS / PACKS / CARDS). A calm dark strip with a
/// bottom hairline; the active tab gets a faint accent wash, and the only glow
/// on the bar is the underline beneath it. Per the glow rule, that underline is
/// the single "live" element — it slides between tabs on change.
///
/// Compared with [CyberSegmentedTabs] (the raised glowing trapezoid), this is
/// the lower-key, text-only variant — reach for it on dense catalogue screens
/// that already carry their own focal element.
class CyberUnderlineTabs extends StatelessWidget {
  const CyberUnderlineTabs({
    required this.labels,
    required this.activeIndex,
    required this.onTap,
    this.accent = Cyber.cyan,
    this.height = 50,
    super.key,
  });

  final List<String> labels;
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
          final tabWidth = constraints.maxWidth / labels.length;
          return Stack(
            children: [
              Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: _UnderlineTab(
                        label: labels[i],
                        active: activeIndex == i,
                        accent: accent,
                        onTap: () {
                          if (i == activeIndex) return;
                          playSound(SoundEffect.uiTap);
                          onTap(i);
                        },
                      ),
                    ),
                ],
              ),
              // The bar's one glow: the active indicator slides between tabs.
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: tabWidth * activeIndex + tabWidth * 0.18,
                bottom: 0,
                width: tabWidth * 0.64,
                height: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.7),
                        blurRadius: 10,
                      ),
                    ],
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

class _UnderlineTab extends StatefulWidget {
  const _UnderlineTab({
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
  State<_UnderlineTab> createState() => _UnderlineTabState();
}

class _UnderlineTabState extends State<_UnderlineTab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? widget.accent : Cyber.muted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 150),
        scale: _pressed ? 0.97 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            color: widget.active
                ? widget.accent.withValues(alpha: 0.07)
                : Colors.transparent,
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.label,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontFamily: Cyber.displayFont,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
