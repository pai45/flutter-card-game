import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// A tooltip customized to fit the angular, sharp cyber theme.
class CyberTooltip extends StatelessWidget {
  const CyberTooltip({
    required this.message,
    required this.child,
    this.accentColor = Cyber.cyan,
    this.triggerMode = TooltipTriggerMode.tap,
    this.preferBelow = false,
    super.key,
  });

  final String message;
  final Widget child;
  final Color accentColor;
  final TooltipTriggerMode triggerMode;
  final bool preferBelow;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      triggerMode: triggerMode,
      waitDuration: Duration.zero,
      showDuration: const Duration(milliseconds: 2400),
      exitDuration: const Duration(milliseconds: 120),
      constraints: const BoxConstraints(minHeight: 40, maxWidth: 280),
      decoration: ShapeDecoration(
        color: Cyber.panel2,
        shape: BeveledRectangleBorder(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
          side: BorderSide(
            color: accentColor.withValues(alpha: 0.72),
            width: 1,
          ),
        ),
      ),
      textStyle: Cyber.label(
        9.5,
        color: AppTheme.textPrimary,
      ).copyWith(height: 1.3, letterSpacing: 1.2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      verticalOffset: 12,
      preferBelow: preferBelow,
      child: child,
    );
  }
}
