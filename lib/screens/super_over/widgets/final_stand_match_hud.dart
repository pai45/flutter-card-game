import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../blocs/super_over/super_over_state.dart';
import '../../../config/theme.dart';
import '../../../data/super_over_batter_profiles.dart';
import '../../../models/super_over.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// Tennis Rally-inspired live presentation for Super Over.
///
/// This widget is intentionally presentation-only. The existing BLoC remains
/// authoritative for the over, intent, timing, score, and progression rules.
class FinalStandMatchHud extends StatelessWidget {
  const FinalStandMatchHud({
    required this.state,
    required this.onBatTap,
    required this.onExit,
    required this.onPause,
    required this.onSectorSelected,
    required this.onShotStyleSelected,
    super.key,
  });

  final SuperOverState state;
  final VoidCallback onBatTap;
  final VoidCallback onExit;
  final VoidCallback onPause;
  final ValueChanged<ShotSector> onSectorSelected;
  final ValueChanged<ShotStyle> onShotStyleSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth >= 620 ? 720.0 : 520.0;
            return Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: _MatchHeader(
                      state: state,
                      onExit: onExit,
                      onPause: onPause,
                    ),
                  ),
                ),
                if (state.phase != SuperOverPhase.targetReveal &&
                    state.lastOutcome == null)
                  Align(
                    alignment: const Alignment(0, -0.58),
                    child: _DeliveryCue(state: state),
                  ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Opacity(
                      opacity: state.settings.controlOpacity,
                      child: AnimatedSwitcher(
                        duration: state.settings.reducedMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 150),
                        child: state.lastOutcome == null
                            ? _ControlDock(
                                key: ValueKey('action-${state.ballsFaced}'),
                                state: state,
                                onBatTap: onBatTap,
                                onSectorSelected: onSectorSelected,
                                onShotStyleSelected: onShotStyleSelected,
                              )
                            : _BallCompleteCard(
                                key: ValueKey('complete-${state.ballsFaced}'),
                                state: state,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MatchHeader extends StatelessWidget {
  const _MatchHeader({
    required this.state,
    required this.onExit,
    required this.onPause,
  });

  final SuperOverState state;
  final VoidCallback onExit;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Flexible(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ClipPath(
                  clipper: const HudChamferClipper(bigCut: 7, smallCut: 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    color: Cyber.panel.withValues(alpha: .94),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        state.mode == SuperOverMode.chase
                            ? 'CHASE // SUPER OVER'
                            : 'SCORE ATTACK // SUPER OVER',
                        style: Cyber.display(
                          8,
                          color: Cyber.cyan,
                          letterSpacing: .9,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _HeaderButton(
              tooltip: 'Quit match',
              icon: Icons.close_rounded,
              onPressed: onExit,
            ),
            const SizedBox(width: 6),
            _HeaderButton(
              tooltip: 'Pause match',
              icon: Icons.pause_rounded,
              onPressed: onPause,
            ),
          ],
        ),
        const SizedBox(height: 6),
        _AngularPanel(
          fill: Cyber.bg.withValues(alpha: .94),
          border: Cyber.cyan.withValues(alpha: .46),
          cut: 11,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CURRENT SCORE',
                          style: Cyber.display(6.5, color: Cyber.muted),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${state.score} / ${state.wickets}',
                          style: Cyber.display(
                            23,
                            color: Colors.white,
                            letterSpacing: .2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 34,
                    color: Cyber.border.withValues(alpha: .76),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          state.mode == SuperOverMode.chase
                              ? 'TARGET ${state.cpuTarget + 1}'
                              : 'MAXIMISE THE OVER',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Cyber.display(6.5, color: Cyber.muted),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            _matchEquation(state),
                            style: Cyber.display(
                              12,
                              color: _equationColor(state),
                              letterSpacing: .35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              _OverStrip(state: state),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            width: 42,
            height: 34,
            decoration: BoxDecoration(
              color: Cyber.panel.withValues(alpha: .94),
              border: Border.all(color: Cyber.cyan.withValues(alpha: .42)),
            ),
            child: Icon(icon, size: 19, color: Cyber.cyan),
          ),
        ),
      ),
    );
  }
}

class _OverStrip extends StatelessWidget {
  const _OverStrip({required this.state});

  final SuperOverState state;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${state.ballsFaced} of 6 balls complete',
      child: Row(
        children: List.generate(6, (index) {
          final outcome = index < state.wagonWheel.length
              ? state.wagonWheel[index]
              : null;
          final current = index == state.wagonWheel.length && !state.isOver;
          final color = outcome == null ? Cyber.border : _outcomeColor(outcome);
          return Expanded(
            child: Container(
              key: ValueKey('final-stand-ball-${index + 1}'),
              height: 23,
              margin: EdgeInsets.only(right: index == 5 ? 0 : 2),
              decoration: BoxDecoration(
                color: outcome == null
                    ? const Color(0xFF101C29)
                    : color.withValues(alpha: .16),
                border: Border.all(
                  color: current
                      ? Cyber.cyan
                      : color.withValues(alpha: outcome == null ? .58 : .8),
                  width: current ? 1.4 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                outcome == null ? '${index + 1}' : _outcomeText(outcome),
                style: Cyber.display(
                  8.5,
                  color: outcome == null ? Cyber.muted : color,
                  letterSpacing: 0,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _DeliveryCue extends StatelessWidget {
  const _DeliveryCue({required this.state});

  final SuperOverState state;

  @override
  Widget build(BuildContext context) {
    final armed = state.canTap;
    return IgnorePointer(
      child: ClipPath(
        clipper: const HudChamferClipper(bigCut: 7, smallCut: 2),
        child: AnimatedContainer(
          duration: state.settings.reducedMotion
              ? Duration.zero
              : const Duration(milliseconds: 130),
          constraints: const BoxConstraints(maxWidth: 278),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          color: Cyber.bg.withValues(alpha: .88),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 16,
                color: armed ? Cyber.lime : Cyber.cyan,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  armed ? 'TIME // HIT NOW' : _deliveryCue(state),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.display(
                    7.5,
                    color: armed ? Cyber.lime : Colors.white,
                    letterSpacing: .7,
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

class _ControlDock extends StatelessWidget {
  const _ControlDock({
    required this.state,
    required this.onBatTap,
    required this.onSectorSelected,
    required this.onShotStyleSelected,
    super.key,
  });

  final SuperOverState state;
  final VoidCallback onBatTap;
  final ValueChanged<ShotSector> onSectorSelected;
  final ValueChanged<ShotStyle> onShotStyleSelected;

  @override
  Widget build(BuildContext context) {
    final targetReveal = state.phase == SuperOverPhase.targetReveal;
    return _AngularPanel(
      fill: Cyber.bg.withValues(alpha: .96),
      border: Cyber.cyan.withValues(alpha: .44),
      cut: 14,
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PlayerStatusStrip(state: state),
          const SizedBox(height: 6),
          if (targetReveal)
            _StartButton(state: state, onPressed: onBatTap)
          else ...[
            _FieldObjectiveStrip(state: state),
            const SizedBox(height: 7),
            _InputZones(
              state: state,
              onBatTap: onBatTap,
              onSectorSelected: onSectorSelected,
              onShotStyleSelected: onShotStyleSelected,
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayerStatusStrip extends StatelessWidget {
  const _PlayerStatusStrip({required this.state});

  final SuperOverState state;

  @override
  Widget build(BuildContext context) {
    final striker = state.striker;
    final index = striker == null ? 0 : state.battingOrder.indexOf(striker);
    final profile = striker == null
        ? null
        : SuperOverBatterProfiles.fromCard(
            striker,
            orderIndex: math.max(index, 0),
          );
    final rhythm = state.currentRhythm.clamp(0, 100);
    final rating = striker?.rating ?? 75;
    return SizedBox(
      height: 43,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Cyber.cyan.withValues(alpha: .11),
              border: Border.all(color: Cyber.cyan.withValues(alpha: .52)),
            ),
            child: Text(
              '${profile?.jerseyNumber ?? 1}',
              style: Cyber.display(11, color: Cyber.cyan, letterSpacing: 0),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.displayName ?? 'BATTER 01',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.body(
                    10,
                    weight: FontWeight.w800,
                    letterSpacing: .3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${profile?.archetypeLabel ?? 'ANCHOR'}  //  RTG $rating',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.body(7.5, color: Cyber.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('RHYTHM', style: Cyber.display(6, color: Cyber.muted)),
                    const Spacer(),
                    Text(
                      '$rhythm',
                      style: Cyber.display(6.5, color: Cyber.cyan),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Stack(
                  children: [
                    Container(height: 4, color: Cyber.border),
                    FractionallySizedBox(
                      widthFactor: rhythm / 100,
                      child: Container(
                        height: 4,
                        color: rhythm >= 70 ? Cyber.lime : Cyber.cyan,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${state.selectedSector.label} // ${state.selectedShotStyle.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.display(5.8, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Container(
            width: 76,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              color: state.finisherReady
                  ? Cyber.gold.withValues(alpha: .12)
                  : Colors.white.withValues(alpha: .025),
              border: Border.all(
                color: state.finisherReady
                    ? Cyber.gold.withValues(alpha: .55)
                    : Cyber.border,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.finisherActive
                      ? 'FINISHER ON'
                      : 'FINISHER ${state.finisherProgress}%',
                  maxLines: 1,
                  style: Cyber.display(
                    5.7,
                    color: state.finisherReady ? Cyber.gold : Cyber.muted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${math.max(0, 2 - state.wickets)} WKT LEFT',
                  style: Cyber.display(5.6, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldObjectiveStrip extends StatelessWidget {
  const _FieldObjectiveStrip({required this.state});

  final SuperOverState state;

  @override
  Widget build(BuildContext context) {
    final complete = state.objectiveComplete;
    final counts = List<int>.generate(
      3,
      (index) => state.fieldSectors.elementAtOrNull(index) ?? 0,
    );
    return SizedBox(
      height: 25,
      child: Row(
        children: [
          for (var i = 0; i < ShotSector.values.length; i++) ...[
            _FieldCell(
              sector: ShotSector.values[i],
              count: counts[i],
              open: state.openSector == ShotSector.values[i],
              packed: state.packedSectors.contains(ShotSector.values[i]),
              selected: state.selectedSector == ShotSector.values[i],
            ),
            if (i != 2) const SizedBox(width: 3),
          ],
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: Container(
              height: 25,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .025),
                border: Border.all(color: Cyber.border.withValues(alpha: .8)),
              ),
              child: Row(
                children: [
                  Icon(
                    complete ? Icons.check_rounded : Icons.flag_outlined,
                    size: 12,
                    color: complete ? Cyber.lime : Cyber.gold,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      state.objective.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.display(5.8, color: Colors.white70),
                    ),
                  ),
                  Text(
                    '${state.objectiveProgress}/${state.objective.target}',
                    style: Cyber.display(
                      6,
                      color: complete ? Cyber.lime : Cyber.gold,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldCell extends StatelessWidget {
  const _FieldCell({
    required this.sector,
    required this.count,
    required this.open,
    required this.packed,
    required this.selected,
  });

  final ShotSector sector;
  final int count;
  final bool open;
  final bool packed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = open
        ? Cyber.lime
        : packed
        ? Cyber.amber
        : Cyber.cyan;
    return Expanded(
      child: Container(
        height: 25,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? Cyber.cyan.withValues(alpha: .12)
              : Colors.white.withValues(alpha: .02),
          border: Border.all(
            color: selected ? Cyber.cyan : color.withValues(alpha: .4),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 4, height: 4, color: color),
              const SizedBox(width: 4),
              Text(
                '${sector.label} $count',
                style: Cyber.display(5.7, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputZones extends StatelessWidget {
  const _InputZones({
    required this.state,
    required this.onBatTap,
    required this.onSectorSelected,
    required this.onShotStyleSelected,
  });

  final SuperOverState state;
  final VoidCallback onBatTap;
  final ValueChanged<ShotSector> onSectorSelected;
  final ValueChanged<ShotStyle> onShotStyleSelected;

  @override
  Widget build(BuildContext context) {
    final aim = Expanded(
      child: _AimShotPanel(
        state: state,
        onSectorSelected: onSectorSelected,
        onShotStyleSelected: onShotStyleSelected,
      ),
    );
    final hit = _HitPanel(
      enabled: state.canTap,
      scale: state.settings.batButtonScale,
      onPressed: onBatTap,
    );
    final children = state.settings.leftHandedControls
        ? <Widget>[hit, const SizedBox(width: 8), aim]
        : <Widget>[aim, const SizedBox(width: 8), hit];
    return SizedBox(
      height: 108,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _AimShotPanel extends StatelessWidget {
  const _AimShotPanel({
    required this.state,
    required this.onSectorSelected,
    required this.onShotStyleSelected,
  });

  final SuperOverState state;
  final ValueChanged<ShotSector> onSectorSelected;
  final ValueChanged<ShotStyle> onShotStyleSelected;

  @override
  Widget build(BuildContext context) {
    return _AngularPanel(
      fill: Cyber.panel.withValues(alpha: .72),
      border: Cyber.cyan.withValues(alpha: .38),
      cut: 10,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 58,
                child: Text(
                  'AIM / SHOT',
                  style: Cyber.display(6.4, color: Cyber.muted),
                ),
              ),
              for (final style in ShotStyle.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _ShotToggle(
                      style: style,
                      selected: state.selectedShotStyle == style,
                      enabled: state.canSelectIntent,
                      onSelected: onShotStyleSelected,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: CustomPaint(
              painter: _AimGuidePainter(selected: state.selectedSector),
              child: Row(
                children: [
                  for (final sector in ShotSector.values)
                    Expanded(
                      child: _AimSectorButton(
                        sector: sector,
                        selected: state.selectedSector == sector,
                        enabled: state.canSelectIntent,
                        open: state.openSector == sector,
                        packed: state.packedSectors.contains(sector),
                        onSelected: onSectorSelected,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShotToggle extends StatelessWidget {
  const _ShotToggle({
    required this.style,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final ShotStyle style;
  final bool selected;
  final bool enabled;
  final ValueChanged<ShotStyle> onSelected;

  @override
  Widget build(BuildContext context) {
    final accent = style == ShotStyle.ground ? Cyber.cyan : Cyber.gold;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: InkWell(
        key: ValueKey('final-stand-shot-${style.name}'),
        onTap: enabled ? () => onSelected(style) : null,
        child: Container(
          height: 23,
          padding: const EdgeInsets.symmetric(horizontal: 3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: .16)
                : Colors.transparent,
            border: Border.all(
              color: selected ? accent : Cyber.border.withValues(alpha: .7),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              style.label,
              style: Cyber.display(
                5.6,
                color: selected ? accent : Colors.white54,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AimSectorButton extends StatelessWidget {
  const _AimSectorButton({
    required this.sector,
    required this.selected,
    required this.enabled,
    required this.open,
    required this.packed,
    required this.onSelected,
  });

  final ShotSector sector;
  final bool selected;
  final bool enabled;
  final bool open;
  final bool packed;
  final ValueChanged<ShotSector> onSelected;

  @override
  Widget build(BuildContext context) {
    final statusColor = open
        ? Cyber.lime
        : packed
        ? Cyber.amber
        : Cyber.cyan;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: InkWell(
        key: ValueKey('final-stand-aim-${sector.name}'),
        onTap: enabled ? () => onSelected(sector) : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                sector.label,
                style: Cyber.display(
                  6.4,
                  color: selected ? Cyber.cyan : Colors.white70,
                  letterSpacing: .35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AimGuidePainter extends CustomPainter {
  const _AimGuidePainter({required this.selected});

  final ShotSector selected;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 1.06);
    final radius = math.min(size.width * .46, size.height * 1.1);
    final guide = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Cyber.cyan.withValues(alpha: .18);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      guide,
    );
    for (final fraction in <double>[1 / 3, 2 / 3]) {
      final angle = math.pi + math.pi * fraction;
      canvas.drawLine(
        center,
        center + Offset.fromDirection(angle, radius),
        guide,
      );
    }
    final index = ShotSector.values.indexOf(selected);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 4),
      math.pi + index * math.pi / 3,
      math.pi / 3,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Cyber.cyan.withValues(alpha: .34),
    );
  }

  @override
  bool shouldRepaint(covariant _AimGuidePainter oldDelegate) =>
      oldDelegate.selected != selected;
}

class _HitPanel extends StatefulWidget {
  const _HitPanel({
    required this.enabled,
    required this.scale,
    required this.onPressed,
  });

  final bool enabled;
  final double scale;
  final VoidCallback onPressed;

  @override
  State<_HitPanel> createState() => _HitPanelState();
}

class _HitPanelState extends State<_HitPanel> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final width = (108 * widget.scale).clamp(94.0, 132.0);
    final activeColor = widget.enabled ? Cyber.lime : Cyber.border;
    return SizedBox(
      width: width,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sports_cricket, size: 11, color: Cyber.muted),
              const SizedBox(width: 4),
              Text('TIME / HIT', style: Cyber.display(7, color: Cyber.muted)),
            ],
          ),
          const SizedBox(height: 5),
          Expanded(
            child: Semantics(
              button: true,
              enabled: widget.enabled,
              label: widget.enabled
                  ? 'BAT. Tap to swing'
                  : 'BAT. Wait for release',
              child: GestureDetector(
                key: const ValueKey('final-stand-bat'),
                behavior: HitTestBehavior.opaque,
                onTapDown: widget.enabled
                    ? (_) => setState(() => _pressed = true)
                    : null,
                onTapCancel: widget.enabled
                    ? () => setState(() => _pressed = false)
                    : null,
                onTapUp: widget.enabled
                    ? (_) => setState(() => _pressed = false)
                    : null,
                onTap: widget.enabled ? widget.onPressed : null,
                child: AnimatedScale(
                  scale: _pressed ? .94 : 1,
                  duration: const Duration(milliseconds: 70),
                  child: CustomPaint(
                    painter: _HitDialPainter(
                      color: activeColor,
                      armed: widget.enabled,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'BAT',
                            style: Cyber.display(
                              15,
                              color: widget.enabled ? Cyber.lime : Cyber.muted,
                              letterSpacing: .6,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.enabled ? 'TAP TO SWING' : 'WAIT FOR BALL',
                            textAlign: TextAlign.center,
                            style: Cyber.display(
                              5.4,
                              color: widget.enabled
                                  ? Colors.white
                                  : Colors.white38,
                              letterSpacing: .35,
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
        ],
      ),
    );
  }
}

class _HitDialPainter extends CustomPainter {
  const _HitDialPainter({required this.color, required this.armed});

  final Color color;
  final bool armed;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * .44;
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = Cyber.panel.withValues(alpha: .84),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = armed ? 2 : 1.2
        ..color = color.withValues(alpha: armed ? .92 : .58),
    );
    canvas.drawCircle(
      center,
      radius * .67,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: .24),
    );
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      canvas.drawLine(
        center + Offset.fromDirection(angle, radius * .78),
        center + Offset.fromDirection(angle, radius * .94),
        Paint()
          ..strokeWidth = i % 3 == 0 ? 1.5 : 1
          ..color = color.withValues(alpha: i % 3 == 0 ? .76 : .32),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HitDialPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.armed != armed;
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.state, required this.onPressed});

  final SuperOverState state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const HudChamferClipper(bigCut: 10, smallCut: 3),
      child: SizedBox(
        key: const ValueKey('final-stand-start'),
        width: double.infinity,
        height: 48,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Cyber.gold,
            foregroundColor: Cyber.bg,
            shape: const RoundedRectangleBorder(),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                state.mode == SuperOverMode.chase
                    ? 'CHASE ${state.cpuTarget + 1}'
                    : 'SCORE ATTACK',
                style: Cyber.display(7, color: Cyber.bg),
              ),
              const SizedBox(width: 11),
              Container(
                width: 1,
                height: 16,
                color: Cyber.bg.withValues(alpha: .28),
              ),
              const SizedBox(width: 11),
              Text('START OVER', style: Cyber.display(11, color: Cyber.bg)),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_rounded, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}

class _BallCompleteCard extends StatelessWidget {
  const _BallCompleteCard({required this.state, super.key});

  final SuperOverState state;

  @override
  Widget build(BuildContext context) {
    final outcome = state.lastOutcome ?? ShotOutcome.dot;
    final record = state.ballRecords.lastOrNull;
    final color = _outcomeColor(outcome);
    return _AngularPanel(
      key: const ValueKey('final-stand-outcome'),
      fill: Cyber.bg.withValues(alpha: .95),
      border: color.withValues(alpha: .64),
      cut: 12,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .13),
              border: Border.all(color: color.withValues(alpha: .7)),
            ),
            child: Text(
              _outcomeText(outcome),
              style: Cyber.display(19, color: color, letterSpacing: 0),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _outcomeTitle(outcome),
                  style: Cyber.display(11, color: Colors.white),
                ),
                const SizedBox(height: 5),
                Text(
                  '${(state.timingTier ?? TimingTier.miss).name.toUpperCase()}  //  '
                  '${(state.shotSector ?? state.selectedSector).label}  //  '
                  '${record?.intent?.style.label ?? state.selectedShotStyle.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.display(6, color: Cyber.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${state.score}/${state.wickets}', style: Cyber.display(16)),
              const SizedBox(height: 4),
              Text(
                'AFTER ${state.ballsFaced}',
                style: Cyber.display(6, color: Cyber.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AngularPanel extends StatelessWidget {
  const _AngularPanel({
    required this.child,
    required this.fill,
    required this.border,
    required this.cut,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Widget child;
  final Color fill;
  final Color border;
  final double cut;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AngularPanelPainter(fill: fill, border: border, cut: cut),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _AngularPanelPainter extends CustomPainter {
  const _AngularPanelPainter({
    required this.fill,
    required this.border,
    required this.cut,
  });

  final Color fill;
  final Color border;
  final double cut;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width - 3, 0)
      ..lineTo(size.width, 3)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(3, size.height)
      ..lineTo(0, size.height - 3)
      ..lineTo(0, cut)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = border,
    );
  }

  @override
  bool shouldRepaint(covariant _AngularPanelPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.border != border ||
      oldDelegate.cut != cut;
}

String _matchEquation(SuperOverState state) {
  if (state.mode == SuperOverMode.scoreAttack) return '${state.score} RUNS';
  if (state.runsToWin <= 0) return 'TARGET CLEARED';
  return 'NEED ${state.runsToWin} // ${state.ballsLeft} BALLS';
}

Color _equationColor(SuperOverState state) {
  if (state.mode == SuperOverMode.scoreAttack ||
      state.runsToWin <= state.ballsLeft) {
    return Cyber.lime;
  }
  return Cyber.gold;
}

String _deliveryCue(SuperOverState state) {
  final plan = state.deliveryPlan;
  if (state.settings.difficulty == SuperOverDifficulty.allStar &&
      plan.disguised) {
    return '${plan.typeLabel} // DISGUISED';
  }
  return '${plan.typeLabel} // ${plan.lengthLabel} // ${plan.line.name.toUpperCase()}';
}

String _outcomeTitle(ShotOutcome outcome) => switch (outcome) {
  ShotOutcome.six => 'SIX RUNS',
  ShotOutcome.four => 'FOUR RUNS',
  ShotOutcome.three => 'THREE RUNS',
  ShotOutcome.two => 'TWO RUNS',
  ShotOutcome.one => 'ONE RUN',
  ShotOutcome.dot => 'DOT BALL',
  ShotOutcome.caught => 'CAUGHT',
  ShotOutcome.bowled => 'BOWLED',
};

String _outcomeText(ShotOutcome outcome) => switch (outcome) {
  ShotOutcome.six => '6',
  ShotOutcome.four => '4',
  ShotOutcome.three => '3',
  ShotOutcome.two => '2',
  ShotOutcome.one => '1',
  ShotOutcome.dot => '•',
  ShotOutcome.caught || ShotOutcome.bowled => 'W',
};

Color _outcomeColor(ShotOutcome outcome) => switch (outcome) {
  ShotOutcome.six => Cyber.gold,
  ShotOutcome.four => Cyber.cyan,
  ShotOutcome.caught || ShotOutcome.bowled => Cyber.danger,
  ShotOutcome.dot => Cyber.muted,
  _ => Cyber.cyan,
};
