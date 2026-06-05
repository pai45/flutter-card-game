import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../utils/sound_effects.dart';

/// One tab in [CyberSegmentedTabs]: a label plus an icon builder. The builder
/// receives the resolved colour + size so the active/inactive tint stays
/// centralised in the bar (dark-on-cyan when active, muted when not).
class CyberTab {
  const CyberTab({required this.label, required this.icon});

  final String label;
  final Widget Function(Color color, double size) icon;
}

/// Top segmented tab bar (MATCHES / PICK / GAMES). A calm dark bar with the
/// ACTIVE tab raised as a bright, glowing trapezoid — square top, chamfered
/// bottom — that dips below the bar baseline. Per the glow rule, only the
/// active tab glows; the inactive tabs are plain icon + label.
class CyberSegmentedTabs extends StatelessWidget {
  const CyberSegmentedTabs({
    required this.tabs,
    required this.activeIndex,
    required this.onTap,
    this.accent = Cyber.cyan,
    super.key,
  });

  final List<CyberTab> tabs;
  final int activeIndex;
  final ValueChanged<int> onTap;
  final Color accent;

  static const double _barHeight = 58;
  static const double _activeHeight = 74;
  static const double _chamfer = 22;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _activeHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segW = constraints.maxWidth / tabs.length;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Calm dark bar that the inactive tabs sit on.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: _barHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _barFill,
                    border: Border(
                      top: BorderSide(color: accent.withValues(alpha: 0.14)),
                      bottom: BorderSide(color: accent.withValues(alpha: 0.20)),
                    ),
                  ),
                ),
              ),
              // The raised, glowing active tab (slides between segments).
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                left: segW * activeIndex,
                top: 0,
                width: segW,
                height: _activeHeight,
                child: CustomPaint(
                  painter: _ActiveTabPainter(accent: accent, chamfer: _chamfer),
                ),
              ),
              // Tab contents (icon + label), aligned within the bar baseline.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: _barHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < tabs.length; i++)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            playSound(SoundEffect.uiTap);
                            onTap(i);
                          },
                          child: _TabContent(
                            tab: tabs[i],
                            active: i == activeIndex,
                            accent: accent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TabContent extends StatelessWidget {
  const _TabContent({
    required this.tab,
    required this.active,
    required this.accent,
  });

  final CyberTab tab;
  final bool active;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final color = active ? _activeInk : Cyber.muted;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        tab.icon(color, 24),
        const SizedBox(height: 5),
        Text(
          tab.label,
          style: TextStyle(
            color: color,
            fontFamily: Cyber.displayFont,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
          ),
        ),
      ],
    );
  }
}

/// Paints the active tab: a chamfered-bottom trapezoid filled with a bright
/// vertical cyan gradient, a soft cyan glow halo, and a top sheen line.
class _ActiveTabPainter extends CustomPainter {
  const _ActiveTabPainter({required this.accent, required this.chamfer});

  final Color accent;
  final double chamfer;

  /// Horizontal inset so the plate floats with a small gap either side.
  static const double margin = 6;

  Path _path(Size s) {
    const l = margin;
    final r = s.width - margin;
    final h = s.height;
    return Path()
      ..moveTo(l, 0)
      ..lineTo(r, 0)
      ..lineTo(r, h - chamfer)
      ..lineTo(r - chamfer, h)
      ..lineTo(l + chamfer, h)
      ..lineTo(l, h - chamfer)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _path(size);

    // Glow halo behind the tab.
    canvas.drawPath(
      path,
      Paint()
        ..color = accent.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11),
    );

    // Bright vertical gradient fill.
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(accent, Colors.white, 0.22)!, accent],
        ).createShader(Offset.zero & size),
    );

    // Top sheen.
    canvas.drawLine(
      const Offset(margin, 1),
      Offset(size.width - margin, 1),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _ActiveTabPainter old) =>
      old.accent != accent || old.chamfer != chamfer;
}

const _barFill = Color(0xff1b2336);
const _activeInk = Color(0xff09131d); // dark ink for icon/label on the cyan tab
