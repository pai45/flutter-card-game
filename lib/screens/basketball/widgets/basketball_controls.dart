import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../games/basketball/basketball_game.dart';

/// The Hoop Duel control deck: a MOVE pad (◀ away / ▶ to rim) on the left and
/// a contextual ACTION pad on the right. Both are raw [Listener]s (not
/// GestureDetectors) so move-hold and action-hold register simultaneously —
/// the same multi-touch reason Grand Prix uses hold pads. Double-tap a move
/// arrow to burst-drive; hold ACTION and release for a jump shot; tap it for a
/// layup / pump-fake / steal by context; swipe it away from the rim to
/// step-back. Pads are calm plates; pressed state is an accent fill, never a
/// glow (only the on-court ball-handler glows).
class BasketballControls extends StatelessWidget {
  const BasketballControls({required this.game, this.showHints = false, super.key});

  final BasketballGame game;
  final bool showHints;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
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
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _MovePad(game: game, showHint: showHints),
          const Spacer(),
          _ActionPad(game: game, showHint: showHints),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Move pad
// ---------------------------------------------------------------------------

class _MovePad extends StatefulWidget {
  const _MovePad({required this.game, required this.showHint});

  final BasketballGame game;
  final bool showHint;

  @override
  State<_MovePad> createState() => _MovePadState();
}

class _MovePadState extends State<_MovePad> {
  bool _left = false;
  bool _right = false;
  DateTime? _lastTapAway;
  DateTime? _lastTapRim;

  void _apply() {
    final axis = (_right ? 1.0 : 0.0) - (_left ? 1.0 : 0.0);
    widget.game.setMoveAxis(axis);
  }

  void _set({bool? left, bool? right}) {
    if (left != null) _left = left;
    if (right != null) _right = right;
    _apply();
    if (mounted) setState(() {});
  }

  void _maybeBurst(bool toRim) {
    final now = DateTime.now();
    final last = toRim ? _lastTapRim : _lastTapAway;
    if (last != null && now.difference(last).inMilliseconds < 260) {
      widget.game.tapBurst();
      HapticFeedback.lightImpact();
    }
    if (toRim) {
      _lastTapRim = now;
    } else {
      _lastTapAway = now;
    }
  }

  @override
  void dispose() {
    widget.game.setMoveAxis(0);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showHint) const _HintLabel('MOVE'),
        Row(
          children: [
            _DirButton(
              icon: Icons.chevron_left,
              down: _left,
              onDown: () {
                _maybeBurst(false);
                _set(left: true);
              },
              onUp: () => _set(left: false),
            ),
            const SizedBox(width: 10),
            _DirButton(
              icon: Icons.chevron_right,
              down: _right,
              onDown: () {
                _maybeBurst(true);
                _set(right: true);
              },
              onUp: () => _set(right: false),
            ),
          ],
        ),
      ],
    );
  }
}

class _DirButton extends StatelessWidget {
  const _DirButton({
    required this.icon,
    required this.down,
    required this.onDown,
    required this.onUp,
  });

  final IconData icon;
  final bool down;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => onDown(),
      onPointerUp: (_) => onUp(),
      onPointerCancel: (_) => onUp(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: 64,
        height: 68,
        decoration: BoxDecoration(
          color: down
              ? Cyber.cyan.withValues(alpha: 0.26)
              : Cyber.panel.withValues(alpha: 0.85),
          border: Border.all(
            color: Cyber.cyan.withValues(alpha: down ? 0.9 : 0.4),
            width: down ? 1.6 : 1,
          ),
        ),
        child: Icon(
          icon,
          color: down ? Cyber.cyan : Cyber.cyan.withValues(alpha: 0.75),
          size: 32,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action pad
// ---------------------------------------------------------------------------

class _ActionPad extends StatefulWidget {
  const _ActionPad({required this.game, required this.showHint});

  final BasketballGame game;
  final bool showHint;

  @override
  State<_ActionPad> createState() => _ActionPadState();
}

class _ActionPadState extends State<_ActionPad> {
  bool _down = false;
  Offset _start = Offset.zero;
  bool _swiped = false;

  void _onDown(PointerDownEvent event) {
    _down = true;
    _swiped = false;
    _start = event.position;
    widget.game.actionPressed();
    if (mounted) setState(() {});
  }

  void _onMove(PointerMoveEvent event) {
    if (!_down || _swiped) return;
    final delta = event.position - _start;
    // Swipe away from the rim (leftward) with intent → step-back.
    if (delta.dx < -34 && delta.dx.abs() > delta.dy.abs()) {
      _swiped = true;
      widget.game.swipeBack();
      HapticFeedback.selectionClick();
      _down = false;
      if (mounted) setState(() {});
    }
  }

  void _onUp(PointerUpEvent event) {
    if (!_down) return;
    _down = false;
    widget.game.actionReleased();
    if (mounted) setState(() {});
  }

  void _onCancel(PointerCancelEvent event) {
    if (!_down) return;
    _down = false;
    widget.game.actionReleased();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (widget.showHint) const _HintLabel('SHOOT / DEFEND'),
        Listener(
          onPointerDown: _onDown,
          onPointerMove: _onMove,
          onPointerUp: _onUp,
          onPointerCancel: _onCancel,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            width: 150,
            height: 68,
            decoration: BoxDecoration(
              color: _down
                  ? Cyber.gold.withValues(alpha: 0.26)
                  : Cyber.panel.withValues(alpha: 0.85),
              border: Border.all(
                color: Cyber.gold.withValues(alpha: _down ? 0.9 : 0.45),
                width: _down ? 1.7 : 1,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.sports_basketball,
                    color: _down ? Cyber.gold : Cyber.gold.withValues(alpha: 0.8),
                    size: 26,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'HOLD · TAP · SWIPE',
                    style: TextStyle(
                      color: _down ? Cyber.gold : Cyber.muted,
                      fontFamily: Cyber.displayFont,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HintLabel extends StatelessWidget {
  const _HintLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.4, end: 1),
        duration: const Duration(milliseconds: 700),
        builder: (context, t, child) => Opacity(
          opacity: (0.5 + 0.5 * t).clamp(0.0, 1.0),
          child: child,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Cyber.bg.withValues(alpha: 0.7),
            border: Border.all(color: Cyber.gold.withValues(alpha: 0.5)),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Cyber.gold,
              fontFamily: Cyber.displayFont,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}
