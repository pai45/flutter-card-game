import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// Responsive multi-touch controls. Analogue steering belongs to one pointer;
/// pedals retain every owning pointer until release/cancel. Phase-keyed rebuilds
/// release controls on pause, coaching, finish and a control-layout change.
class GrandPrixControls extends StatelessWidget {
  const GrandPrixControls({
    required this.onLeft,
    required this.onRight,
    required this.onThrottle,
    required this.onBrake,
    this.onSteer,
    this.onDeploy,
    this.classicControls = false,
    super.key,
  });

  final ValueChanged<bool> onLeft, onRight, onThrottle, onBrake;
  final ValueChanged<double>? onSteer;
  final ValueChanged<bool>? onDeploy;
  final bool classicControls;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      color: Cyber.bg.withValues(alpha: 0.88),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: classicControls || onSteer == null
                  ? Row(
                      children: [
                        Expanded(
                          child: _HoldPad(
                            label: 'LEFT',
                            icon: Icons.chevron_left,
                            accent: Cyber.cyan,
                            onHold: onLeft,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _HoldPad(
                            label: 'RIGHT',
                            icon: Icons.chevron_right,
                            accent: Cyber.cyan,
                            onHold: onRight,
                          ),
                        ),
                      ],
                    )
                  : _SteeringPad(onSteer: onSteer!),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: _HoldPad(
                label: 'BRAKE',
                icon: Icons.pause,
                accent: Cyber.danger,
                onHold: onBrake,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: 3,
              child: _HoldPad(
                label: 'ACCEL',
                icon: Icons.keyboard_double_arrow_up,
                accent: Cyber.success,
                onHold: onThrottle,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: 2,
              child: _HoldPad(
                label: 'ERS',
                icon: Icons.bolt,
                accent: Cyber.cyan,
                onHold: onDeploy ?? (_) {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SteeringPad extends StatefulWidget {
  const _SteeringPad({required this.onSteer});
  final ValueChanged<double> onSteer;
  @override
  State<_SteeringPad> createState() => _SteeringPadState();
}

class _SteeringPadState extends State<_SteeringPad> {
  int? _pointer;
  double _value = 0;
  void _semanticSteer(double delta) {
    setState(() => _value = (_value + delta).clamp(-1.0, 1.0));
    widget.onSteer(_value);
  }

  void _move(PointerEvent event, double width) {
    if (!mounted || event.pointer != _pointer) return;
    final value = ((event.localPosition.dx - width / 2) / (width * 0.4)).clamp(
      -1.0,
      1.0,
    );
    setState(() => _value = value.abs() < 0.06 ? 0 : value);
    widget.onSteer(_value);
  }

  void _release(PointerEvent event) {
    if (!mounted || event.pointer != _pointer) return;
    _pointer = null;
    setState(() => _value = 0);
    widget.onSteer(0);
  }

  @override
  void dispose() {
    if (_pointer != null || _value != 0) widget.onSteer(0);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Steering, drag left or right',
    value: '${(_value * 100).round()}',
    increasedValue: '${((_value + .25).clamp(-1.0, 1.0) * 100).round()}',
    decreasedValue: '${((_value - .25).clamp(-1.0, 1.0) * 100).round()}',
    onIncrease: () => _semanticSteer(.25),
    onDecrease: () => _semanticSteer(-.25),
    onTap: () => _semanticSteer(-_value),
    child: LayoutBuilder(
      builder: (context, constraints) => Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (_pointer != null) return;
          _pointer = event.pointer;
          _move(event, constraints.maxWidth);
        },
        onPointerMove: (event) => _move(event, constraints.maxWidth),
        onPointerUp: _release,
        onPointerCancel: _release,
        child: CyberPanel(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          accent: Cyber.cyan,
          child: SizedBox(
            height: 52,
            child: Column(
              children: [
                Text('STEER', style: Cyber.label(8, color: Cyber.muted)),
                const SizedBox(height: 8),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(height: 2, color: Cyber.border),
                      Align(
                        alignment: Alignment(_value, 0),
                        child: Container(
                          width: 18,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _pointer == null
                                ? Cyber.panel2
                                : Cyber.cyan.withValues(alpha: 0.2),
                            border: Border.all(
                              color: _pointer == null
                                  ? Cyber.border
                                  : Cyber.cyan,
                            ),
                          ),
                          child: const Icon(
                            Icons.drag_indicator,
                            size: 16,
                            color: Cyber.cyan,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _HoldPad extends StatefulWidget {
  const _HoldPad({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onHold,
  });
  final String label;
  final IconData icon;
  final Color accent;
  final ValueChanged<bool> onHold;
  @override
  State<_HoldPad> createState() => _HoldPadState();
}

class _HoldPadState extends State<_HoldPad> {
  final Set<int> _pointers = {};
  bool _semanticHold = false;
  bool get _down => _pointers.isNotEmpty || _semanticHold;
  void _change(PointerEvent event, bool down) {
    if (!mounted) return;
    final wasDown = _down;
    setState(() {
      if (down) {
        _pointers.add(event.pointer);
      } else {
        _pointers.remove(event.pointer);
      }
    });
    if (_down != wasDown) widget.onHold(_down);
  }

  @override
  void dispose() {
    if (_down) widget.onHold(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Hold ${widget.label}',
    toggled: _down,
    onTap: () {
      setState(() => _semanticHold = !_semanticHold);
      widget.onHold(_down);
    },
    child: Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) => _change(event, true),
      onPointerUp: (event) => _change(event, false),
      onPointerCancel: (event) => _change(event, false),
      child: CyberPanel(
        accent: widget.accent,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: SizedBox(
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _down ? widget.accent.withValues(alpha: 0.2) : Cyber.panel,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 22, color: widget.accent),
                const SizedBox(height: 4),
                FittedBox(
                  child: Text(
                    widget.label,
                    style: Cyber.label(
                      8,
                      color: _down ? widget.accent : Cyber.muted,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
