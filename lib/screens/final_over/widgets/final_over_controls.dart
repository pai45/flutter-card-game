import 'package:final_over/final_over.dart';
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
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
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
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: running
                ? _RunningDeck(key: const ValueKey('run'), game: game)
                : _BattingDeck(
                    key: const ValueKey('bat'),
                    game: game,
                    showHints: showHints,
                    rookieAssist: rookieAssist,
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
        game.powerSegments,
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
        final overdriveReady =
            game.powerSegments.value >= game.overdriveRequirement;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (configuring && delivery != null)
              _DeliveryBrief(
                seconds: game.preparationSeconds.value,
                delivery: delivery,
              )
            else if (phase == MatchPhase.bowlerRunUp)
              _Hint(
                'LOCKED · ${_elevationLabel(game.elevation.value)} · '
                '${_directionLabel(game.selectedDirection.value)}',
              )
            else if (live && (showHints || !game.successfulContact.value))
              const _Hint('HOLD HIT · RELEASE AT BAT'),
            Row(
              children: [
                Expanded(
                  child: _Plate(
                    label: 'GROUND',
                    icon: Icons.trending_flat_rounded,
                    accent: Cyber.cyan,
                    selected: game.elevation.value == Elevation.ground,
                    suggested: suggestedElevation == Elevation.ground,
                    enabled: configuring,
                    onTap: () {
                      game.selectElevation(Elevation.ground);
                      HapticFeedback.selectionClick();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Plate(
                    label: 'LOFT',
                    icon: Icons.trending_up_rounded,
                    accent: Cyber.violet,
                    selected: game.elevation.value == Elevation.loft,
                    suggested: suggestedElevation == Elevation.loft,
                    enabled: configuring,
                    onTap: () {
                      game.selectElevation(Elevation.loft);
                      HapticFeedback.selectionClick();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                _Plate(
                  label: game.powerArmed.value ? 'ARMED' : 'OVERDRIVE',
                  icon: Icons.bolt_rounded,
                  accent: Cyber.gold,
                  selected: game.powerArmed.value,
                  enabled: configuring && overdriveReady,
                  width: 92,
                  onTap: () {
                    game.activatePowerShot();
                    HapticFeedback.mediumImpact();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final entry in const [
                  (ShotDirection.offSide, 'OFF'),
                  (ShotDirection.straight, 'STRAIGHT'),
                  (ShotDirection.legSide, 'LEG'),
                ]) ...[
                  Expanded(
                    child: _Plate(
                      label: entry.$2,
                      accent: Cyber.cyan,
                      selected: game.selectedDirection.value == entry.$1,
                      suggested: suggestedDirection == entry.$1,
                      enabled: configuring,
                      onTap: () {
                        game.selectDirection(entry.$1);
                        HapticFeedback.selectionClick();
                      },
                    ),
                  ),
                  if (entry.$1 != ShotDirection.legSide)
                    const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 8),
            HudHoldCtaButton(
              label: live ? 'HIT' : 'WAIT',
              icon: Icons.sports_cricket_rounded,
              height: 58,
              glow: live,
              enabled: live,
              onPressStart: game.beginSwing,
              onPressEnd: () {
                game.releaseSwing();
                HapticFeedback.lightImpact();
              },
              onPressCancel: game.cancelSwing,
            ),
          ],
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

class _DeliveryBrief extends StatelessWidget {
  const _DeliveryBrief({required this.seconds, required this.delivery});

  final int seconds;
  final DeliverySpec delivery;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Cyber.gold.withValues(alpha: 0.16),
            border: Border.all(color: Cyber.gold.withValues(alpha: 0.75)),
          ),
          child: Text('$seconds', style: Cyber.display(18, color: Cyber.gold)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${_lineLabel(delivery.line)} · '
            '${_lengthLabel(delivery.length)}',
            style: Cyber.display(13, color: Colors.white),
          ),
        ),
        Text(
          'SELECT SHOT',
          style: Cyber.label(8, color: Cyber.cyan, letterSpacing: 1.2),
        ),
      ],
    ),
  );
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
  DeliveryLength.good => 'GOOD LENGTH',
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
    this.enabled = true,
    this.height = 46,
    this.width,
    this.big = false,
    this.glow = false,
  });

  final String label;
  final IconData? icon;
  final Color accent;

  /// Fires on pointer *down*, always. For a tap plate that is the whole story;
  /// for a swing plate it starts the backlift and [onRelease] plays the shot.
  final VoidCallback onTap;
  final bool selected;
  final bool suggested;
  final bool enabled;
  final double height;
  final double? width;
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
    final accent = widget.enabled ? widget.accent : Cyber.muted;

    return Listener(
      onPointerDown: widget.enabled
          ? (_) {
              setState(() => _down = true);
              widget.onTap();
            }
          : null,
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: Opacity(
        opacity: widget.enabled ? 1 : 0.4,
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
            width: widget.width,
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
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Cyber.gold.withValues(alpha: 0.10),
        border: Border.all(color: Cyber.gold.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Cyber.label(8, color: Cyber.gold, letterSpacing: 1.2),
      ),
    ),
  );
}
