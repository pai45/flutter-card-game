import 'package:flutter/material.dart';

import 'package:final_over/app/theme.dart';

class ArcadeButton extends StatelessWidget {
  const ArcadeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = FinalOverPalette.cyan,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final button = Semantics(
      button: true,
      label: label,
      child: SizedBox(
        height: 58,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 22),
          label: Text(label),
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: FinalOverPalette.night,
            disabledBackgroundColor: FinalOverPalette.muted.withValues(
              alpha: .25,
            ),
            textStyle: Theme.of(context).textTheme.labelLarge,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.white.withValues(alpha: .42)),
            ),
          ),
        ),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}
