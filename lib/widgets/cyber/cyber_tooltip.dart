import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// A tooltip customized to fit the angular, sharp cyber theme.
class CyberTooltip extends StatelessWidget {
  const CyberTooltip({
    required this.message,
    required this.child,
    this.accentColor = Cyber.cyan,
    super.key,
  });

  final String message;
  final Widget child;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      decoration: BoxDecoration(
        color: const Color(0xff0B1220), // Dark background matching panels
        border: Border.all(color: accentColor),
        borderRadius: BorderRadius.zero, // Sharp edges per theme requirement
        boxShadow: Cyber.glow(accentColor, alpha: 0.15),
      ),
      textStyle: TextStyle(
        color: accentColor,
        fontFamily: Cyber.displayFont,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      verticalOffset: 32, // Distance from the child
      preferBelow: false,
      child: child,
    );
  }
}
