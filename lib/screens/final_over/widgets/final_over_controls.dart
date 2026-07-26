import 'package:final_over/final_over.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../games/final_over/final_over_game.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// The deck. It has two faces:
///   • while the ball is coming — a slim status strip. The hit itself is no
///     longer a button here: the player taps or swipes ANYWHERE over the pitch
///     (see `FinalOverSwingSurface`) — a tap drives it, a swipe places it, a
///     flick up lofts it.
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

/// The batting face is now just a read-out. Since the swing moved onto the
/// pitch (`FinalOverSwingSurface`), this strip only coaches: what to do while
/// the ball comes, that the shot is played, and — for rookies — a recommended
/// flick derived from the delivery's line and length.
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
      animation: Listenable.merge([game.phase, game.canSwing]),
      builder: (context, _) {
        final live = game.canSwing.value;
        final committed = game.state.swingIntent != null;
        final delivery = game.state.currentDelivery;
        final recommendDirection = rookieAssist && live && delivery != null
            ? _directionForLine(delivery.line)
            : null;
        final recommendElevation = rookieAssist && live && delivery != null
            ? _elevationForLength(delivery.length)
            : null;
        return _BattingStatusStrip(
          phase: game.phase.value,
          live: live,
          committed: committed,
          verbose: showHints,
          recommendDirection: recommendDirection,
          recommendElevation: recommendElevation,
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

class _BattingStatusStrip extends StatelessWidget {
  const _BattingStatusStrip({
    required this.phase,
    required this.live,
    required this.committed,
    required this.verbose,
    this.recommendDirection,
    this.recommendElevation,
  });

  final MatchPhase phase;
  final bool live;
  final bool committed;
  final bool verbose;
  final ShotDirection? recommendDirection;
  final Elevation? recommendElevation;

  @override
  Widget build(BuildContext context) {
    final (label, helper, icon, accent) = _content();
    return Semantics(
      liveRegion: true,
      label: '$label. $helper',
      child: SizedBox(
        height: 34,
        child: ChamferedActionSurface(
          clipper: const HudChamferClipper(bigCut: 10, smallCut: 3),
          borderColor: live ? accent.withValues(alpha: 0.55) : Cyber.line,
          child: ColoredBox(
            color: Cyber.panel.withValues(alpha: 0.88),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(icon, color: accent, size: 15),
                  const SizedBox(width: 8),
                  Text(label, style: Cyber.display(10, color: Colors.white)),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 12, color: Cyber.line),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      helper,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.label(
                        7.5,
                        color: live ? accent : Cyber.muted,
                        letterSpacing: 1.1,
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

  (String, String, IconData, Color) _content() {
    if (committed) {
      return (
        'SHOT PLAYED',
        'TRACK THE BALL',
        Icons.check_rounded,
        Cyber.success,
      );
    }
    if (live) {
      final recommend = recommendDirection != null
          ? 'TRY ${_directionLabel(recommendDirection!)}'
                '${recommendElevation != null ? ' · ${_elevationLabel(recommendElevation!)}' : ''}'
          : verbose
          ? 'SWIPE AIMS · FLICK UP LOFTS'
          : 'TAP OR SWIPE THE PITCH';
      return ('TAP TO HIT', recommend, Icons.sports_cricket_rounded, Cyber.cyan);
    }
    return switch (phase) {
      MatchPhase.bowlerRunUp => (
        'WATCH THE RELEASE',
        'HIT AS IT REACHES THE BAT',
        Icons.visibility_rounded,
        Cyber.cyan,
      ),
      MatchPhase.incomingBall => (
        'SWING CLOSED',
        'THE BALL HAS PASSED',
        Icons.timer_off_rounded,
        Cyber.muted,
      ),
      MatchPhase.contact ||
      MatchPhase.cameraTransition ||
      MatchPhase.fieldPlay => (
        'TRACK THE BALL',
        'RUN WHEN THE CALL APPEARS',
        Icons.radar_rounded,
        Cyber.cyan,
      ),
      _ => (
        'READ THE BALL',
        'TAP TO DRIVE · SWIPE TO PLACE',
        Icons.sports_cricket_rounded,
        Cyber.muted,
      ),
    };
  }
}

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
    this.height = 46,
    this.big = false,
    this.glow = false,
  });

  final String label;
  final IconData? icon;
  final Color accent;

  /// Fires on pointer *down*, always.
  final VoidCallback onTap;
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
    final on = _down;
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
        borderColor: accent.withValues(alpha: on ? 0.9 : 0.4),
        borderWidth: on ? 1.6 : 1,
        glowColor: accent,
        glow: widget.glow ? 1 : 0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          height: widget.height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on
                ? accent.withValues(alpha: 0.26)
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

String _directionLabel(ShotDirection direction) => switch (direction) {
  ShotDirection.offSide => 'OFF',
  ShotDirection.straight => 'STRAIGHT',
  ShotDirection.legSide => 'LEG',
};

String _elevationLabel(Elevation elevation) => switch (elevation) {
  Elevation.ground => 'GROUND',
  Elevation.loft => 'LOFT',
};
