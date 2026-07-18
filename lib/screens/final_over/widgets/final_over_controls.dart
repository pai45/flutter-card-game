import 'package:final_over/final_over.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../games/final_over/final_over_game.dart';
import '../../../widgets/cyber/cyber_cta_button.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// The deck. It has two faces, because the game has two questions:
///   • while the ball is coming — HOW do you hit it (ground/loft × off/straight/
///     leg, with a power shot when it's charged),
///   • once you've hit it — DO you run.
///
/// Plates, not buttons. Pressed is an accent *fill*, never a glow — the only
/// glow down here is the RUN plate when the risk is real, because that is the
/// decision the whole game hangs on.
class FinalOverControls extends StatelessWidget {
  const FinalOverControls({
    required this.game,
    required this.showHints,
    this.rookieAssist = false,
    super.key,
  });

  final FinalOverGame game;
  final bool showHints;
  final bool rookieAssist;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Cyber.bg.withValues(alpha: 0.96),
            Cyber.bg.withValues(alpha: 0.80),
            Cyber.bg.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge([game.phase, game.canRun]),
        builder: (context, _) {
          final running =
              _isRunningPhase(game.phase.value) || game.canRun.value;
          return AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: running
                  ? _RunningDeck(key: const ValueKey('run'), game: game)
                  : _BattingDeck(
                      key: const ValueKey('bat'),
                      game: game,
                      showHints: showHints,
                      rookieAssist: rookieAssist,
                    ),
            ),
          );
        },
      ),
    );
  }

  static bool _isRunningPhase(MatchPhase phase) =>
      phase == MatchPhase.runDecision ||
      phase == MatchPhase.runnersMoving ||
      phase == MatchPhase.throwInProgress;
}

// ── Batting ───────────────────────────────────────────────────────────────────

class _BattingDeck extends StatelessWidget {
  const _BattingDeck({
    required this.game,
    required this.showHints,
    required this.rookieAssist,
    super.key,
  });

  final FinalOverGame game;
  final bool showHints;
  final bool rookieAssist;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        game.phase,
        game.preparationSeconds,
        game.canConfigureShot,
        game.canSwing,
        game.elevation,
        game.selectedDirection,
        game.powerArmed,
        game.successfulContact,
      ]),
      builder: (context, _) {
        final phase = game.phase.value;
        final configuring = game.canConfigureShot.value;
        final live = game.canSwing.value;
        final delivery = game.state.currentDelivery;
        final suggestedDirection = rookieAssist && delivery != null
            ? _directionForLine(delivery.line)
            : null;
        final suggestedElevation = rookieAssist && delivery != null
            ? _elevationForLength(delivery.length)
            : null;
        final setup = configuring && delivery != null;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
          child: setup
              ? Column(
                  key: const ValueKey('shot-setup'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SetupHeader(
                      seconds: game.preparationSeconds.value,
                      delivery: delivery,
                      elevation: game.elevation.value,
                      suggestedElevation: suggestedElevation,
                      onGround: () {
                        game.selectElevation(Elevation.ground);
                        HapticFeedback.selectionClick();
                      },
                      onLoft: () {
                        game.selectElevation(Elevation.loft);
                        HapticFeedback.selectionClick();
                      },
                    ),
                    const SizedBox(height: 6),
                    _ShotAimFan(
                      selected: game.selectedDirection.value,
                      suggested: suggestedDirection,
                      showHint: showHints,
                      onSelected: game.selectDirection,
                    ),
                  ],
                )
              : _LockedBattingDeck(
                  key: const ValueKey('shot-locked'),
                  phase: phase,
                  live: live,
                  shotCommitted: game.state.swingIntent != null,
                  elevation: game.elevation.value,
                  direction: game.selectedDirection.value,
                  overdriveArmed: game.powerArmed.value,
                  onPressStart: game.beginSwing,
                  onPressEnd: () {
                    game.releaseSwing();
                    HapticFeedback.lightImpact();
                  },
                  onPressCancel: game.cancelSwing,
                ),
        );
      },
    );
  }

  static ShotDirection _directionForLine(DeliveryLine line) => switch (line) {
    DeliveryLine.wideOff || DeliveryLine.off => ShotDirection.offSide,
    DeliveryLine.middle => ShotDirection.straight,
    DeliveryLine.leg || DeliveryLine.wideLeg => ShotDirection.legSide,
  };

  static Elevation? _elevationForLength(DeliveryLength length) =>
      switch (length) {
        DeliveryLength.yorker || DeliveryLength.full => Elevation.ground,
        DeliveryLength.short => Elevation.loft,
        DeliveryLength.good => null,
      };
}

class _SetupHeader extends StatelessWidget {
  const _SetupHeader({
    required this.seconds,
    required this.delivery,
    required this.elevation,
    required this.suggestedElevation,
    required this.onGround,
    required this.onLoft,
  });

  final int seconds;
  final DeliverySpec delivery;
  final Elevation elevation;
  final Elevation? suggestedElevation;
  final VoidCallback onGround;
  final VoidCallback onLoft;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: Row(
      children: [
        Container(
          width: 32,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Cyber.gold.withValues(alpha: 0.16),
            border: Border.all(color: Cyber.gold.withValues(alpha: 0.75)),
          ),
          child: Text(
            '$seconds',
            style: Cyber.display(
              16,
              color: Cyber.gold,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_lineLabel(delivery.line)} · '
                  '${_lengthLabel(delivery.length)}',
                  maxLines: 1,
                  style: Cyber.display(9.5, color: Colors.white),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'SHOT TYPE',
                style: Cyber.label(7, color: Cyber.cyan, letterSpacing: 1.1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _Plate(
            key: const ValueKey('shot-type-ground'),
            label: 'GROUND',
            icon: Icons.trending_flat_rounded,
            accent: Cyber.cyan,
            selected: elevation == Elevation.ground,
            suggested: suggestedElevation == Elevation.ground,
            height: 38,
            onTap: onGround,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: _Plate(
            key: const ValueKey('shot-type-loft'),
            label: 'LOFT',
            icon: Icons.trending_up_rounded,
            accent: Cyber.violet,
            selected: elevation == Elevation.loft,
            suggested: suggestedElevation == Elevation.loft,
            height: 38,
            onTap: onLoft,
          ),
        ),
      ],
    ),
  );
}

class _LockedBattingDeck extends StatelessWidget {
  const _LockedBattingDeck({
    required this.phase,
    required this.live,
    required this.shotCommitted,
    required this.elevation,
    required this.direction,
    required this.overdriveArmed,
    required this.onPressStart,
    required this.onPressEnd,
    required this.onPressCancel,
    super.key,
  });

  final MatchPhase phase;
  final bool live;
  final bool shotCommitted;
  final Elevation elevation;
  final ShotDirection direction;
  final bool overdriveArmed;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;
  final VoidCallback onPressCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LockedShotStrip(
          elevation: elevation,
          direction: direction,
          overdriveArmed: overdriveArmed,
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 58,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 120),
            child: live
                ? HudHoldCtaButton(
                    key: const ValueKey('swing-live'),
                    label: 'HOLD TO SWING',
                    pressedLabel: 'RELEASE TO SWING',
                    helper: 'RELEASE AT THE BAT',
                    pressedHelper: 'TIME THE RELEASE',
                    icon: Icons.sports_cricket_rounded,
                    height: 58,
                    glow: true,
                    enabled: true,
                    onPressStart: onPressStart,
                    onPressEnd: onPressEnd,
                    onPressCancel: onPressCancel,
                  )
                : _ReadyStatus(
                    key: ValueKey<String>(_statusLabel),
                    label: _statusLabel,
                    helper: _statusHelper,
                    icon: _statusIcon,
                    accent: shotCommitted ? Cyber.success : Cyber.cyan,
                  ),
          ),
        ),
      ],
    );
  }

  String get _statusLabel {
    if (shotCommitted) return 'SHOT PLAYED';
    return switch (phase) {
      MatchPhase.bowlerRunUp => 'WATCH THE RELEASE',
      MatchPhase.incomingBall => 'SWING WINDOW CLOSED',
      MatchPhase.contact ||
      MatchPhase.cameraTransition ||
      MatchPhase.fieldPlay => 'TRACK THE BALL',
      _ => 'SETTING THE FIELD',
    };
  }

  String get _statusHelper {
    if (shotCommitted) return 'TRACK THE BALL';
    return switch (phase) {
      MatchPhase.bowlerRunUp => 'HOLD WHEN THE BALL LEAVES THE HAND',
      MatchPhase.incomingBall => 'THE BALL HAS PASSED THE BAT',
      MatchPhase.contact ||
      MatchPhase.cameraTransition ||
      MatchPhase.fieldPlay => 'RUN WHEN THE CALL APPEARS',
      _ => 'NEXT BALL INCOMING',
    };
  }

  IconData get _statusIcon {
    if (shotCommitted) return Icons.check_rounded;
    return switch (phase) {
      MatchPhase.bowlerRunUp => Icons.visibility_rounded,
      MatchPhase.incomingBall => Icons.timer_off_rounded,
      MatchPhase.contact ||
      MatchPhase.cameraTransition ||
      MatchPhase.fieldPlay => Icons.radar_rounded,
      _ => Icons.sports_cricket_rounded,
    };
  }
}

class _LockedShotStrip extends StatelessWidget {
  const _LockedShotStrip({
    required this.elevation,
    required this.direction,
    required this.overdriveArmed,
  });

  final Elevation elevation;
  final ShotDirection direction;
  final bool overdriveArmed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 30,
    child: ChamferedActionSurface(
      clipper: const HudChamferClipper(bigCut: 8, smallCut: 3),
      borderColor: Cyber.cyan.withValues(alpha: 0.42),
      child: ColoredBox(
        color: Cyber.panel.withValues(alpha: 0.88),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Text(
                'SHOT LOCKED',
                style: Cyber.label(7, color: Cyber.cyan, letterSpacing: 1.2),
              ),
              const SizedBox(width: 8),
              Container(width: 1, height: 12, color: Cyber.line),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_elevationLabel(elevation)}  •  '
                  '${_directionLabel(direction)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.display(9.5, color: Colors.white),
                ),
              ),
              if (overdriveArmed) ...[
                const Icon(Icons.bolt_rounded, size: 14, color: Cyber.gold),
                const SizedBox(width: 2),
                Text('OD', style: Cyber.label(7, color: Cyber.gold)),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _ReadyStatus extends StatelessWidget {
  const _ReadyStatus({
    required this.label,
    required this.helper,
    required this.icon,
    required this.accent,
    super.key,
  });

  final String label;
  final String helper;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: '$label. $helper',
    child: ChamferedActionSurface(
      clipper: const HudChamferClipper(bigCut: 12, smallCut: 4),
      borderColor: Cyber.line,
      child: ColoredBox(
        color: Cyber.panel.withValues(alpha: 0.88),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.display(11, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      helper,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.label(
                        7,
                        color: Cyber.muted,
                        letterSpacing: 1,
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
  );
}

class _ShotAimFan extends StatefulWidget {
  const _ShotAimFan({
    required this.selected,
    required this.suggested,
    required this.showHint,
    required this.onSelected,
  });

  static const keyValue = ValueKey<String>('final-over-shot-aim');

  final ShotDirection selected;
  final ShotDirection? suggested;
  final bool showHint;
  final ValueChanged<ShotDirection> onSelected;

  @override
  State<_ShotAimFan> createState() => _ShotAimFanState();
}

class _ShotAimFanState extends State<_ShotAimFan>
    with SingleTickerProviderStateMixin {
  static const _minimumDrag = 12.0;

  late final AnimationController _hintController;
  Offset? _dragOrigin;
  ShotDirection? _dragSelection;
  ShotDirection? _preview;
  bool _qualifiedDrag = false;
  bool _pointerCancelled = false;
  bool _interacted = false;

  ShotDirection get _effectiveDirection => _preview ?? widget.selected;

  @override
  void initState() {
    super.initState();
    _hintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    if (widget.showHint) _hintController.repeat();
  }

  @override
  void didUpdateWidget(covariant _ShotAimFan oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dragOrigin == null && oldWidget.selected != widget.selected) {
      _preview = null;
    }
    if (oldWidget.showHint != widget.showHint && !_interacted) {
      if (widget.showHint) {
        _hintController.repeat();
      } else {
        _hintController.stop();
      }
    }
  }

  @override
  void dispose() {
    _hintController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _dragOrigin = details.localPosition;
      _dragSelection = widget.selected;
      _preview = widget.selected;
      _qualifiedDrag = false;
      _pointerCancelled = false;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final origin = _dragOrigin;
    if (origin == null) return;
    final delta = details.localPosition - origin;
    final distance = delta.distance;
    if (distance < _minimumDrag || delta.dy > 8) return;

    final next = delta.dx < -distance * .34
        ? ShotDirection.offSide
        : delta.dx > distance * .34
        ? ShotDirection.legSide
        : ShotDirection.straight;
    if (_preview == next && _qualifiedDrag) return;
    HapticFeedback.selectionClick();
    setState(() {
      _preview = next;
      _qualifiedDrag = true;
    });
  }

  void _onPanEnd(DragEndDetails _) {
    if (_pointerCancelled) {
      _cancelDrag();
      return;
    }
    final selected = _preview;
    if (_qualifiedDrag && selected != null) {
      _commit(selected, haptic: false);
    } else {
      setState(() => _preview = null);
    }
    _dragOrigin = null;
    _dragSelection = null;
    _qualifiedDrag = false;
  }

  void _onPanCancel() => _cancelDrag();

  void _cancelDrag() {
    final selection = _dragSelection;
    setState(() {
      _dragOrigin = null;
      _dragSelection = null;
      _preview = null;
      _qualifiedDrag = false;
      _pointerCancelled = false;
    });
    if (selection != null) widget.onSelected(selection);
  }

  void _commit(ShotDirection direction, {bool haptic = true}) {
    if (haptic) HapticFeedback.selectionClick();
    _hintController.stop();
    setState(() {
      _interacted = true;
      _preview = direction;
    });
    widget.onSelected(direction);
  }

  void _cycle(int delta) {
    const directions = ShotDirection.values;
    final current = directions.indexOf(_effectiveDirection);
    final next = (current + delta).clamp(0, directions.length - 1);
    _commit(directions[next]);
  }

  @override
  Widget build(BuildContext context) {
    final direction = _effectiveDirection;
    final showGhost = widget.showHint && !_interacted;
    return Semantics(
      key: _ShotAimFan.keyValue,
      container: true,
      explicitChildNodes: true,
      label: 'Shot direction',
      value: _directionLabel(direction),
      hint: 'Swipe up-left for off, up for straight, or up-right for leg',
      increasedValue: direction == ShotDirection.legSide
          ? null
          : _directionLabel(ShotDirection.values[direction.index + 1]),
      decreasedValue: direction == ShotDirection.offSide
          ? null
          : _directionLabel(ShotDirection.values[direction.index - 1]),
      onIncrease: direction == ShotDirection.legSide ? null : () => _cycle(1),
      onDecrease: direction == ShotDirection.offSide ? null : () => _cycle(-1),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onPanCancel: _onPanCancel,
        child: Listener(
          onPointerCancel: (_) => _pointerCancelled = true,
          child: ChamferedActionSurface(
            clipper: const HudChamferClipper(bigCut: 10, smallCut: 3),
            borderColor: Cyber.cyan.withValues(alpha: 0.48),
            child: ColoredBox(
              color: Cyber.panel.withValues(alpha: 0.88),
              child: SizedBox(
                height: 64,
                child: AnimatedBuilder(
                  animation: _hintController,
                  builder: (context, _) => Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: _ShotAimFanPainter(
                          selected: direction,
                          suggested: widget.suggested,
                          showHint:
                              showGhost &&
                              !MediaQuery.disableAnimationsOf(context),
                          hintProgress: _hintController.value,
                        ),
                      ),
                      Row(
                        children: [
                          for (final entry in const [
                            (ShotDirection.offSide, 'OFF'),
                            (ShotDirection.straight, 'STRAIGHT'),
                            (ShotDirection.legSide, 'LEG'),
                          ])
                            Expanded(
                              child: Semantics(
                                button: true,
                                selected: direction == entry.$1,
                                label: 'Aim ${entry.$2.toLowerCase()}',
                                child: InkWell(
                                  onTap: () => _commit(entry.$1),
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 5),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            entry.$2,
                                            style: Cyber.display(
                                              9,
                                              color: direction == entry.$1
                                                  ? Colors.white
                                                  : widget.suggested == entry.$1
                                                  ? Cyber.cyan
                                                  : Cyber.muted,
                                            ),
                                          ),
                                          if (widget.suggested == entry.$1)
                                            Text(
                                              'REC',
                                              style: Cyber.label(
                                                6,
                                                color: Cyber.cyan,
                                                letterSpacing: .8,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 3,
                        child: IgnorePointer(
                          child: Text(
                            showGhost
                                ? 'SWIPE TOWARD YOUR SHOT'
                                : 'DRAG TO AIM',
                            textAlign: TextAlign.center,
                            style: Cyber.label(
                              7,
                              color: Cyber.muted,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShotAimFanPainter extends CustomPainter {
  const _ShotAimFanPainter({
    required this.selected,
    required this.suggested,
    required this.showHint,
    required this.hintProgress,
  });

  final ShotDirection selected;
  final ShotDirection? suggested;
  final bool showHint;
  final double hintProgress;

  Offset _target(ShotDirection direction, Size size) => switch (direction) {
    ShotDirection.offSide => Offset(size.width * .19, 27),
    ShotDirection.straight => Offset(size.width * .5, 23),
    ShotDirection.legSide => Offset(size.width * .81, 27),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width * .5, size.height - 13);
    for (final direction in ShotDirection.values) {
      final target = _target(direction, size);
      final isSelected = direction == selected;
      final isSuggested = direction == suggested;
      canvas.drawLine(
        origin,
        target,
        Paint()
          ..color = isSelected
              ? Cyber.cyan.withValues(alpha: .92)
              : isSuggested
              ? Cyber.cyan.withValues(alpha: .42)
              : Cyber.line.withValues(alpha: .55)
          ..strokeWidth = isSelected ? 2 : (isSuggested ? 1.4 : 1)
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        target,
        isSelected ? 3.4 : 2,
        Paint()
          ..color = isSelected
              ? Cyber.cyan
              : isSuggested
              ? Cyber.cyan.withValues(alpha: .62)
              : Cyber.muted.withValues(alpha: .42),
      );
      if (isSelected) _drawArrowHead(canvas, origin, target);
    }

    canvas.drawCircle(origin, 4, Paint()..color = Cyber.gold);
    canvas.drawCircle(
      origin,
      7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Cyber.gold.withValues(alpha: .45),
    );

    if (showHint) {
      final t = Curves.easeInOutCubic.transform(hintProgress);
      final point = Offset.lerp(origin, _target(selected, size), t)!;
      final alpha = .28 + .62 * (1 - (t * 2 - 1).abs());
      canvas.drawCircle(
        point,
        3.2,
        Paint()..color = Cyber.gold.withValues(alpha: alpha),
      );
    }
  }

  void _drawArrowHead(Canvas canvas, Offset origin, Offset target) {
    final delta = target - origin;
    final length = delta.distance;
    if (length == 0) return;
    final unit = delta / length;
    final perpendicular = Offset(-unit.dy, unit.dx);
    final base = target - unit * 7;
    final path = Path()
      ..moveTo(target.dx, target.dy)
      ..lineTo((base + perpendicular * 3).dx, (base + perpendicular * 3).dy)
      ..moveTo(target.dx, target.dy)
      ..lineTo((base - perpendicular * 3).dx, (base - perpendicular * 3).dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = Cyber.cyan
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _ShotAimFanPainter oldDelegate) =>
      oldDelegate.selected != selected ||
      oldDelegate.suggested != suggested ||
      oldDelegate.showHint != showHint ||
      oldDelegate.hintProgress != hintProgress;
}

String _lineLabel(DeliveryLine line) => switch (line) {
  DeliveryLine.wideOff => 'WIDE OFF',
  DeliveryLine.off => 'OFF',
  DeliveryLine.middle => 'MIDDLE',
  DeliveryLine.leg => 'LEG',
  DeliveryLine.wideLeg => 'WIDE LEG',
};

String _lengthLabel(DeliveryLength length) => switch (length) {
  DeliveryLength.yorker => 'YORKER',
  DeliveryLength.full => 'FULL',
  DeliveryLength.good => 'GOOD',
  DeliveryLength.short => 'SHORT',
};

String _directionLabel(ShotDirection direction) => switch (direction) {
  ShotDirection.offSide => 'OFF',
  ShotDirection.straight => 'STRAIGHT',
  ShotDirection.legSide => 'LEG',
};

String _elevationLabel(Elevation elevation) => switch (elevation) {
  Elevation.ground => 'GROUND',
  Elevation.loft => 'LOFT',
};

// ── Running ───────────────────────────────────────────────────────────────────

class _RunningDeck extends StatelessWidget {
  const _RunningDeck({required this.game, super.key});

  final FinalOverGame game;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        game.risk,
        game.runProgress,
        game.completedRuns,
        game.canRun,
        game.canTurnBack,
      ]),
      builder: (context, _) {
        final risk = game.risk.value;
        final (riskLabel, riskColor) = switch (risk) {
          RiskLevel.safe => ('SAFE', Cyber.success),
          RiskLevel.close => ('CLOSE', Cyber.amber),
          RiskLevel.danger => ('DANGER', Cyber.danger),
        };
        final running = game.runProgress.value > 0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Risk radar + runs banked.
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: riskColor.withValues(alpha: 0.14),
                    border: Border.all(color: riskColor.withValues(alpha: 0.7)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: riskColor,
                          boxShadow: risk == RiskLevel.danger
                              ? Cyber.glow(riskColor, alpha: 0.8, blur: 7)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        riskLabel,
                        style: Cyber.label(
                          9,
                          color: riskColor,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '${game.completedRuns.value}/3 RUNS',
                  style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.4),
                ),
              ],
            ),
            if (running) ...[
              const SizedBox(height: 6),
              CyberProgressBar(
                value: game.runProgress.value,
                accent: riskColor,
                height: 4,
                animate: false,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _Plate(
                    label: game.canTurnBack.value ? 'TURN BACK' : 'HOLD',
                    icon: game.canTurnBack.value
                        ? Icons.u_turn_left_rounded
                        : Icons.pan_tool_rounded,
                    accent: Cyber.muted,
                    height: 58,
                    onTap: () {
                      if (game.canTurnBack.value) {
                        game.turnBack();
                      } else {
                        game.holdBall();
                      }
                      HapticFeedback.selectionClick();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: _Plate(
                    label: running ? 'RUN AGAIN' : 'RUN',
                    icon: Icons.directions_run_rounded,
                    accent: riskColor,
                    height: 58,
                    big: true,
                    // The one glow on the deck: taking a run when it's tight is
                    // the game's real decision, so the game shouts about it.
                    glow: risk != RiskLevel.safe,
                    onTap: () {
                      game.startRun();
                      HapticFeedback.mediumImpact();
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ── The plate ─────────────────────────────────────────────────────────────────

class _Plate extends StatefulWidget {
  const _Plate({
    required this.label,
    required this.accent,
    required this.onTap,
    this.icon,
    this.selected = false,
    this.suggested = false,
    this.height = 46,
    this.big = false,
    this.glow = false,
    super.key,
  });

  final String label;
  final IconData? icon;
  final Color accent;

  /// Fires on pointer *down*, always. For a tap plate that is the whole story;
  /// for a swing plate it starts the backlift and [onRelease] plays the shot.
  final VoidCallback onTap;
  final bool selected;
  final bool suggested;
  final double height;
  final bool big;
  final bool glow;

  @override
  State<_Plate> createState() => _PlateState();
}

class _PlateState extends State<_Plate> {
  bool _down = false;

  void _release() {
    if (!_down) return;
    setState(() => _down = false);
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.selected || _down;
    final accent = widget.accent;

    return Listener(
      onPointerDown: (_) {
        setState(() => _down = true);
        widget.onTap();
      },
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: ChamferedActionSurface(
        clipper: const HudChamferClipper(bigCut: 10, smallCut: 3),
        borderColor: widget.suggested && !on
            ? widget.accent.withValues(alpha: 0.72)
            : accent.withValues(alpha: on ? 0.9 : 0.4),
        borderWidth: on || widget.suggested ? 1.6 : 1,
        glowColor: accent,
        glow: widget.glow ? 1 : 0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          height: widget.height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on
                ? accent.withValues(alpha: 0.26)
                : widget.suggested
                ? widget.accent.withValues(alpha: 0.10)
                : Cyber.panel.withValues(alpha: 0.85),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: widget.big ? 17 : 14, color: accent),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.display(
                    widget.big ? 13 : 10.5,
                    color: on ? Colors.white : accent,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
