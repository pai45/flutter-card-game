import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../widgets/cyber/fixture_card.dart' show kFixtureShadow;
import '../../predictions/widgets/history_hud.dart' show CutChipBorder;

/// Shared elevated surface for the profile sections: a flat dark fill with a
/// cut-corner border and a hard (un-blurred) drop shadow — depth without any
/// gradient, matching the FixtureCard language used across the app. No glow:
/// these are always-on chrome, so per the glow rule they read through fill +
/// border + shadow only.
class ProfileCard extends StatelessWidget {
  const ProfileCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: Cyber.card,
        shape: CutChipBorder(
          cut: 12,
          side: BorderSide(color: borderColor ?? Cyber.border),
        ),
        shadows: const [BoxShadow(color: kFixtureShadow, offset: Offset(0, 5))],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
