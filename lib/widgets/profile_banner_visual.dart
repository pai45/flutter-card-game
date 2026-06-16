import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/profile_banner_option.dart';

/// Renders a profile banner: its asset when present, otherwise gradient-free
/// procedural art (solid accent base + chevron motif + faint scanlines).
///
/// Shared by the profile hero, the profile banner editor and the onboarding
/// profile-setup wizard so the look stays identical everywhere.
class ProfileBannerVisual extends StatelessWidget {
  const ProfileBannerVisual({required this.option, super.key});

  final ProfileBannerOption option;

  @override
  Widget build(BuildContext context) {
    final assetPath = option.assetPath;
    if (assetPath != null) {
      return Image.asset(
        assetPath,
        fit: BoxFit.cover,
        alignment: Alignment.center,
      );
    }
    return CustomPaint(
      painter: _ProfileBannerPlaceholderPainter(option: option),
      child: const SizedBox.expand(),
    );
  }
}

class _ProfileBannerPlaceholderPainter extends CustomPainter {
  const _ProfileBannerPlaceholderPainter({required this.option});

  final ProfileBannerOption option;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = Color.lerp(
      option.colors.first,
      const Color(0xff05070d),
      0.18,
    )!;
    canvas.drawRect(rect, Paint()..color = base);

    final darkPaint = Paint()..color = Colors.black.withValues(alpha: 0.20);
    final lightPaint = Paint()..color = Colors.white.withValues(alpha: 0.06);
    final accentPaint = Paint()
      ..color = option.accent.withValues(alpha: 0.30)
      ..strokeWidth = 1.4;

    for (var i = -2; i < 6; i++) {
      final start = size.width * (i / 5);
      final path = Path()
        ..moveTo(start, 0)
        ..lineTo(start + size.width * 0.34, 0)
        ..lineTo(start + size.width * 0.12, size.height)
        ..lineTo(start - size.width * 0.22, size.height)
        ..close();
      canvas.drawPath(path, i.isEven ? lightPaint : darkPaint);
    }

    for (var y = 18.0; y < size.height; y += 26) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y - 40), accentPaint);
    }
  }

  @override
  bool shouldRepaint(_ProfileBannerPlaceholderPainter oldDelegate) =>
      oldDelegate.option != option;
}

/// A lime check seal pinned to the top-left of a selected tile.
class SelectedCheckCorner extends StatelessWidget {
  const SelectedCheckCorner({this.size = 30, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Cyber.lime),
        child: Icon(Icons.check, color: Cyber.bg, size: size * 0.67),
      ),
    );
  }
}

/// A selectable banner tile (banner art + label overlay + lime selected
/// border/glow). Shared by the profile banner editor and the onboarding wizard.
class SelectableBannerTile extends StatelessWidget {
  const SelectableBannerTile({
    required this.banner,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final ProfileBannerOption banner;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? Cyber.lime : Cyber.line;
    return Semantics(
      button: true,
      selected: selected,
      label: banner.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: Cyber.panel,
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
            boxShadow: selected
                ? Cyber.glow(Cyber.lime, alpha: 0.18, blur: 14, spread: -2)
                : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ProfileBannerVisual(option: banner),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 30,
                child: ColoredBox(color: Cyber.bg.withValues(alpha: 0.5)),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: Text(
                  banner.label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.label(
                    10,
                    color: Colors.white,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
              if (selected) const SelectedCheckCorner(),
            ],
          ),
        ),
      ),
    );
  }
}
