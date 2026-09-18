import 'dart:math' as math;

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
/// the lower-key tab variant — reach for it on dense catalogue screens that
/// already carry their own focal element.
///
/// Pass [minTabWidth] to keep each tab at least that wide; when the row would
/// overflow, the bar scrolls horizontally instead of crushing labels.
class CyberUnderlineTabs extends StatelessWidget {
  const CyberUnderlineTabs({
    required this.labels,
    required this.activeIndex,
    required this.onTap,
    this.accent = Cyber.cyan,
    this.height = 50,
    this.icons,
    this.iconColors,
    this.minTabWidth,
    this.locked,
    super.key,
  }) : assert(icons == null || icons.length == labels.length),
       assert(iconColors == null || iconColors.length == labels.length),
       assert(locked == null || locked.length == labels.length);

  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onTap;
  final Color accent;
  final double height;
  final List<IconData>? icons;

  /// Optional identity color for each icon. Inactive icons keep a subdued
  /// version of their color while the active icon renders at full strength.
  /// Labels and the live underline continue to use [accent].
  final List<Color>? iconColors;

  /// When set, each tab is at least this wide. Overflow scrolls horizontally.
  final double? minTabWidth;

  /// Per-tab locked teaser flags: a locked tab reads dimmed with a lock seal
  /// but stays tappable, so the owner can open an unlock sheet instead.
  final List<bool>? locked;

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
          final count = labels.length;
          final equalWidth = constraints.maxWidth / count;
          final tabWidth = minTabWidth == null
              ? equalWidth
              : math.max(equalWidth, minTabWidth!);
          final contentWidth = tabWidth * count;
          final needsScroll = contentWidth > constraints.maxWidth + 0.5;

          final row = SizedBox(
            width: contentWidth,
            height: height,
            child: Stack(
              children: [
                Row(
                  children: [
                    for (var i = 0; i < count; i++)
                      SizedBox(
                        width: tabWidth,
                        child: _UnderlineTab(
                          label: labels[i],
                          icon: icons?[i],
                          iconColor: iconColors?[i],
                          locked: locked?[i] ?? false,
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
                // A negative index intentionally leaves action-only strips with
                // no selected shortcut (for example, Motorsport via All Sports).
                if (activeIndex >= 0 && activeIndex < count)
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
            ),
          );

          if (!needsScroll) return row;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: row,
          );
        },
      ),
    );
  }
}

/// Pins an underline tab strip once the chrome above it has scrolled away —
/// match detail's PREDICT / PICKS strip and the hub + leaderboard sport strips.
/// Adds scroll behaviour only: the strip's underline stays its one glow, and the
/// solid ground keeps the translucent strip from ghosting over scrolled content.
class CyberPinnedTabsDelegate extends SliverPersistentHeaderDelegate {
  const CyberPinnedTabsDelegate({required this.child, this.height = 50});

  final Widget child;
  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(color: Cyber.bg, child: child);
  }

  @override
  bool shouldRebuild(covariant CyberPinnedTabsDelegate oldDelegate) =>
      oldDelegate.child != child || oldDelegate.height != height;
}

class _UnderlineTab extends StatefulWidget {
  const _UnderlineTab({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.active,
    required this.accent,
    required this.onTap,
    this.locked = false,
  });

  final String label;
  final IconData? icon;
  final Color? iconColor;
  final bool locked;
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
    final labelColor = widget.active ? widget.accent : Cyber.muted;
    final iconColor = widget.locked
        ? Cyber.muted.withValues(alpha: 0.4)
        : widget.iconColor == null
        ? labelColor
        : widget.iconColor!.withValues(alpha: widget.active ? 1 : 0.58);
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
            child: Semantics(
              button: true,
              selected: widget.active,
              label: widget.locked ? '${widget.label}, locked' : widget.label,
              child: ExcludeSemantics(
                child: widget.icon == null
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          style: TextStyle(
                            color: labelColor,
                            fontFamily: Cyber.displayFont,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      )
                    : Tooltip(
                        message: widget.locked
                            ? '${widget.label} - locked'
                            : widget.label,
                        child: widget.locked
                            ? _LockedIcon(icon: widget.icon!, color: iconColor)
                            : Icon(widget.icon, color: iconColor, size: 21),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A locked teaser glyph: the sport icon dimmed, sealed with a small padlock.
/// Flat on purpose - a locked tab is never the live element, so it never glows.
class _LockedIcon extends StatelessWidget {
  const _LockedIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 26,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Icon(icon, color: color, size: 21),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                color: Cyber.bg,
                border: Border.all(color: Cyber.gold.withValues(alpha: 0.55)),
              ),
              child: const Icon(Icons.lock, size: 9, color: Cyber.gold),
            ),
          ),
        ],
      ),
    );
  }
}
