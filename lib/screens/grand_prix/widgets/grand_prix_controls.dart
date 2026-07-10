import 'package:flutter/material.dart';

import '../../../config/theme.dart';

/// The race control pad: [◀][▶] steering on the left, [BRAKE][ACCEL] pedals on
/// the right. Each pad is a raw [Listener] (not a GestureDetector) so
/// multi-touch works — steering and throttle must be holdable simultaneously.
/// Pads are calm plates; pressed state is an accent fill, never a glow.
class GrandPrixControls extends StatelessWidget {
  const GrandPrixControls({
    required this.onLeft,
    required this.onRight,
    required this.onThrottle,
    required this.onBrake,
    super.key,
  });

  final ValueChanged<bool> onLeft;
  final ValueChanged<bool> onRight;
  final ValueChanged<bool> onThrottle;
  final ValueChanged<bool> onBrake;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Cyber.bg.withValues(alpha: 0.94),
            Cyber.bg.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Row(
        children: [
          _HoldPad(
            icon: Icons.chevron_left,
            accent: Cyber.cyan,
            onHold: onLeft,
          ),
          const SizedBox(width: 10),
          _HoldPad(
            icon: Icons.chevron_right,
            accent: Cyber.cyan,
            onHold: onRight,
          ),
          const Spacer(),
          _HoldPad(
            icon: Icons.stacked_line_chart,
            label: 'BRAKE',
            accent: Cyber.danger,
            wide: true,
            onHold: onBrake,
          ),
          const SizedBox(width: 10),
          _HoldPad(
            icon: Icons.keyboard_double_arrow_up,
            label: 'ACCEL',
            accent: Cyber.success,
            wide: true,
            onHold: onThrottle,
          ),
        ],
      ),
    );
  }
}

class _HoldPad extends StatefulWidget {
  const _HoldPad({
    required this.icon,
    required this.accent,
    required this.onHold,
    this.label,
    this.wide = false,
  });

  final IconData icon;
  final String? label;
  final Color accent;
  final bool wide;
  final ValueChanged<bool> onHold;

  @override
  State<_HoldPad> createState() => _HoldPadState();
}

class _HoldPadState extends State<_HoldPad> {
  bool _down = false;

  void _set(bool down) {
    if (_down == down) return;
    setState(() => _down = down);
    widget.onHold(down);
  }

  @override
  void dispose() {
    if (_down) widget.onHold(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: widget.wide ? 92 : 64,
        height: 68,
        decoration: BoxDecoration(
          color: _down
              ? accent.withValues(alpha: 0.28)
              : Cyber.panel.withValues(alpha: 0.85),
          border: Border.all(
            color: accent.withValues(alpha: _down ? 0.9 : 0.4),
            width: _down ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.icon,
              color: _down ? accent : accent.withValues(alpha: 0.75),
              size: widget.label == null ? 30 : 22,
            ),
            if (widget.label != null) ...[
              const SizedBox(height: 3),
              Text(
                widget.label!,
                style: TextStyle(
                  color: _down ? accent : Cyber.muted,
                  fontFamily: Cyber.displayFont,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
