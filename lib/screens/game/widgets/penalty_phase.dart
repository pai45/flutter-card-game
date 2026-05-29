import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/game/game_bloc.dart';
import '../../../blocs/game/game_event.dart';
import '../../../blocs/game/game_state.dart';
import '../../../config/enums.dart';
import '../../../config/theme.dart';
import '../../../config/tutorial_steps.dart';
import '../../../models/match.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/match_widgets.dart';
import 'match_phases.dart' show CountdownRing;

class PenaltyPhase extends StatefulWidget {
  const PenaltyPhase({required this.state, required this.onQuit, super.key});

  final GameState state;
  final VoidCallback onQuit;

  @override
  State<PenaltyPhase> createState() => _PenaltyPhaseState();
}

class _PenaltyPhaseState extends State<PenaltyPhase>
    with TickerProviderStateMixin {
  late AnimationController _revealCtrl;
  late Animation<double> _revealScale;
  late final AnimationController _scanner;

  @override
  void initState() {
    super.initState();
    _revealCtrl = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _revealScale = CurvedAnimation(
      parent: _revealCtrl,
      curve: Curves.easeOutBack,
    );
    _scanner = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    if (widget.state.penaltyKickPhase == 'result') _revealCtrl.value = 1;
  }

  @override
  void didUpdateWidget(PenaltyPhase old) {
    super.didUpdateWidget(old);
    if (old.state.penaltyKickPhase != 'result' &&
        widget.state.penaltyKickPhase == 'result') {
      _revealCtrl.forward(from: 0);
      final scored =
          widget.state.penaltyKicks.isNotEmpty &&
          widget.state.penaltyKicks.last.scored;
      playSound(scored ? SoundEffect.goal : SoundEffect.cardSlam);
    } else if (old.state.penaltyKickPhase == 'result' &&
        widget.state.penaltyKickPhase == 'choose') {
      _revealCtrl.reset();
    }
  }

  @override
  void dispose() {
    _revealCtrl.dispose();
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return s.penaltyKickPhase == 'result'
        ? _buildResult(context, s)
        : _buildChoose(context, s);
  }

  Widget _buildChoose(BuildContext context, GameState s) {
    final playerTaking = s.penaltyRound.isEven;
    final selected = s.penaltyPlayerDirection;
    final totalLabel = s.penaltySuddenDeath ? 'SD' : 'of 6';
    final kickLabel = 'KICK ${s.penaltyRound + 1} $totalLabel';

    return MatchPhaseScaffold(
      title: s.penaltySuddenDeath ? 'SUDDEN DEATH' : 'PENALTY SHOOTOUT',
      subtitle: playerTaking ? '// Your Turn to Shoot' : '// Opponent Shooting',
      state: s,
      onQuit: widget.onQuit,
      scoreLabel: 'PEN ${s.penaltyPlayerScore}-${s.penaltyOpponentScore}',
      tutorialKey: 'penalty',
      tutorialSteps: penaltyTutorialSteps,
      bottomAction: CyberCtaButton(
        label: playerTaking ? 'SHOOT' : 'DIVE',
        primary: true,
        onPressed: selected == null
            ? null
            : () => context.read<GameBloc>().add(PenaltyKickConfirmed()),
      ),
      children: [
        // Progress + history row
        _PenaltyHeader(state: s, kickLabel: kickLabel),
        // Scenario-style action panel — TAKE THE SHOT / GO FOR THE SAVE.
        _PenaltyActionPanel(playerTaking: playerTaking),
        // Direction buttons
        _DirectionButtons(
          playerTaking: playerTaking,
          selected: selected,
          onSelect: (dir) =>
              context.read<GameBloc>().add(PenaltyDirectionSelected(dir)),
        ),
      ],
    );
  }

  Widget _buildResult(BuildContext context, GameState s) {
    final kick = s.penaltyKicks.last;
    final goal = kick.scored;

    return MatchPhaseScaffold(
      title: s.penaltySuddenDeath ? 'SUDDEN DEATH' : 'PENALTY SHOOTOUT',
      subtitle: goal ? '// GOAL!' : '// SAVED!',
      state: s,
      onQuit: widget.onQuit,
      scoreLabel: 'PEN ${s.penaltyPlayerScore}-${s.penaltyOpponentScore}',
      tutorialKey: null,
      tutorialSteps: const [],
      bottomAction: s.penaltyPhaseOver
          ? CyberCtaButton(
              label: 'See Final Result',
              primary: true,
              onPressed: () => context.read<GameBloc>().add(MatchFinished()),
            )
          : null,
      children: [
        // Animated result reveal with goal/save flash + shake on a save.
        AnimatedBuilder(
          animation: _revealCtrl,
          builder: (context, child) {
            final t = _revealCtrl.value;
            final flash = (1 - t).clamp(0.0, 1.0) * 0.4;
            final shakeX = goal ? 0.0 : sin(t * pi * 5) * 6 * (1 - t);
            return Transform.translate(
              offset: Offset(shakeX, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: (goal ? Cyber.success : Cyber.danger).withValues(
                    alpha: flash,
                  ),
                ),
                child: child,
              ),
            );
          },
          child: ScaleTransition(
            scale: _revealScale,
            child: _KickResultCard(kick: kick),
          ),
        ),
        // YOU vs CPU table — user always on the left, CPU on the right.
        _KickTable(kick: kick),
        // Kick history row
        _PenaltyHistoryRow(kicks: s.penaltyKicks),
        // Shootout-over banner OR auto-advance countdown.
        if (s.penaltyPhaseOver)
          _WinnerBanner(winner: s.penaltyWinner)
        else
          _NextKickCountdown(
            key: ValueKey('kick-countdown-${s.penaltyKicks.length}'),
            scanner: _scanner,
            seconds: 3,
            onComplete: () => context.read<GameBloc>().add(PenaltyNextKick()),
          ),
      ],
    );
  }
}

// ─── Scenario-style action panel for the choose screen ──────────────────────

class _PenaltyActionPanel extends StatelessWidget {
  const _PenaltyActionPanel({required this.playerTaking});

  final bool playerTaking;

  @override
  Widget build(BuildContext context) {
    final Color accent = playerTaking ? Cyber.cyan : Cyber.amber;
    final IconData icon = playerTaking ? Icons.sports_soccer : Icons.pan_tool;
    final String title = playerTaking ? 'TAKE THE SHOT' : 'GO FOR THE SAVE';
    final String description = playerTaking
        ? 'Pick a direction. The keeper will dive — outsmart them.'
        : 'Read the shooter. Dive the right way to make the save.';
    final String status = playerTaking
        ? 'YOUR TURN TO SHOOT'
        : 'OPPONENT SHOOTING';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        border: Border.all(color: accent.withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.18), blurRadius: 18),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
              border: Border.all(color: accent.withValues(alpha: 0.7)),
            ),
            child: Icon(icon, color: accent, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Cyber.display(24, color: accent, letterSpacing: 1.6)
                .copyWith(
                  shadows: [
                    Shadow(
                      color: accent.withValues(alpha: 0.6),
                      blurRadius: 18,
                    ),
                  ],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              border: Border.all(color: accent.withValues(alpha: 0.55)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: accent, size: 14),
                const SizedBox(width: 8),
                Text(
                  status,
                  style: TextStyle(
                    color: accent,
                    fontFamily: 'Orbitron',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── YOU vs CPU result table ─────────────────────────────────────────────────

class _KickTable extends StatelessWidget {
  const _KickTable({required this.kick});
  final PenaltyKick kick;

  String _dirLabel(PenaltyDirection d) => switch (d) {
    PenaltyDirection.left => 'LEFT',
    PenaltyDirection.center => 'CENTER',
    PenaltyDirection.right => 'RIGHT',
  };

  @override
  Widget build(BuildContext context) {
    // User is always on the LEFT, CPU on the RIGHT — regardless of who shot.
    final bool userShot = kick.byPlayer;
    final PenaltyDirection userDir = userShot
        ? kick.shootDirection
        : kick.diveDirection;
    final PenaltyDirection cpuDir = userShot
        ? kick.diveDirection
        : kick.shootDirection;
    final String userAction = userShot ? 'SHOT' : 'DIVED';
    final String cpuAction = userShot ? 'DIVED' : 'SHOT';
    final IconData userIcon = userShot ? Icons.sports_soccer : Icons.pan_tool;
    final IconData cpuIcon = userShot ? Icons.pan_tool : Icons.sports_soccer;

    return CyberPanel(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _KickTableCell(
                heading: 'YOU',
                headingColor: Cyber.cyan,
                action: userAction,
                direction: _dirLabel(userDir),
                icon: userIcon,
              ),
            ),
            const VerticalDivider(color: Cyber.line, thickness: 1, width: 1),
            Expanded(
              child: _KickTableCell(
                heading: 'CPU',
                headingColor: Cyber.amber,
                action: cpuAction,
                direction: _dirLabel(cpuDir),
                icon: cpuIcon,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KickTableCell extends StatelessWidget {
  const _KickTableCell({
    required this.heading,
    required this.headingColor,
    required this.action,
    required this.direction,
    required this.icon,
  });

  final String heading;
  final Color headingColor;
  final String action;
  final String direction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            heading,
            style: TextStyle(
              color: headingColor,
              fontFamily: 'Orbitron',
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          Icon(icon, color: headingColor, size: 26),
          const SizedBox(height: 8),
          Text(
            action,
            style: const TextStyle(
              color: Cyber.muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            direction,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Orbitron',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Auto-advance countdown that replaces the "Next Kick" button ────────────

class _NextKickCountdown extends StatefulWidget {
  const _NextKickCountdown({
    required this.scanner,
    required this.seconds,
    required this.onComplete,
    super.key,
  });

  final Animation<double> scanner;
  final int seconds;
  final VoidCallback onComplete;

  @override
  State<_NextKickCountdown> createState() => _NextKickCountdownState();
}

class _NextKickCountdownState extends State<_NextKickCountdown> {
  late int _seconds = widget.seconds;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  Future<void> _tick() async {
    for (var i = widget.seconds; i > 0; i--) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted || _fired) return;
      setState(() => _seconds = i - 1);
    }
    if (!mounted || _fired) return;
    _fired = true;
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),
        CountdownRing(
          seconds: _seconds,
          scanner: widget.scanner,
          accent: Cyber.cyan,
        ),
        const SizedBox(height: 8),
        Text(
          'Next kick in...',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Cyber.cyan.withValues(alpha: 0.7),
            fontFamily: 'Orbitron',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

// -- Penalty sub-widgets -------------------------------------------------------

class _PenaltyHeader extends StatelessWidget {
  const _PenaltyHeader({required this.state, required this.kickLabel});
  final GameState state;
  final String kickLabel;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$kickLabel  -  YOU ${state.penaltyPlayerScore} - ${state.penaltyOpponentScore} OPP',
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Orbitron',
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
          if (state.penaltyKicks.isNotEmpty) ...[
            const SizedBox(height: 10),
            _PenaltyHistoryRow(kicks: state.penaltyKicks),
          ],
        ],
      ),
    );
  }
}

class _PenaltyHistoryRow extends StatelessWidget {
  const _PenaltyHistoryRow({required this.kicks});
  final List<PenaltyKick> kicks;

  @override
  Widget build(BuildContext context) {
    final playerKicks = kicks.where((kick) => kick.byPlayer).toList();
    final opponentKicks = kicks.where((kick) => !kick.byPlayer).toList();
    final slotCount = max(5, max(playerKicks.length, opponentKicks.length));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _PenaltySideHistory(
            label: 'YOU',
            kicks: playerKicks,
            slotCount: slotCount,
            alignEnd: false,
          ),
        ),
        Container(
          width: 1,
          height: 54,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          color: Cyber.line.withValues(alpha: 0.75),
        ),
        Expanded(
          child: _PenaltySideHistory(
            label: 'CPU',
            kicks: opponentKicks,
            slotCount: slotCount,
            alignEnd: true,
          ),
        ),
      ],
    );
  }
}

class _PenaltySideHistory extends StatelessWidget {
  const _PenaltySideHistory({
    required this.label,
    required this.kicks,
    required this.slotCount,
    required this.alignEnd,
  });

  final String label;
  final List<PenaltyKick> kicks;
  final int slotCount;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      for (var index = 0; index < slotCount; index++)
        _PenaltyAttemptIcon(kick: index < kicks.length ? kicks[index] : null),
    ];

    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: alignEnd ? Cyber.amber : Cyber.cyan,
            fontFamily: 'Orbitron',
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: alignEnd ? WrapAlignment.end : WrapAlignment.start,
          children: children,
        ),
      ],
    );
  }
}

class _PenaltyAttemptIcon extends StatelessWidget {
  const _PenaltyAttemptIcon({required this.kick});

  final PenaltyKick? kick;

  @override
  Widget build(BuildContext context) {
    final currentKick = kick;
    final bool pending = currentKick == null;
    final bool playerKick = currentKick?.byPlayer ?? true;
    final bool scored = currentKick?.scored ?? false;
    final color = pending
        ? Cyber.muted
        : playerKick
        ? (scored ? Cyber.lime : Cyber.red)
        : (scored ? Cyber.red : Cyber.lime);
    final icon = pending
        ? Icons.sports_soccer_outlined
        : scored
        ? Icons.sports_soccer
        : Icons.pan_tool;

    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: pending ? Colors.transparent : color.withValues(alpha: 0.16),
        border: Border.all(
          color: color.withValues(alpha: pending ? 0.35 : 0.7),
          width: pending ? 1 : 1.3,
        ),
      ),
      child: Icon(
        icon,
        size: 15,
        color: color.withValues(alpha: pending ? 0.45 : 1),
      ),
    );
  }
}

class _DirectionButtons extends StatelessWidget {
  const _DirectionButtons({
    required this.playerTaking,
    required this.selected,
    required this.onSelect,
  });
  final bool playerTaking;
  final PenaltyDirection? selected;
  final ValueChanged<PenaltyDirection> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < PenaltyDirection.values.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _DirectionButton(
              direction: PenaltyDirection.values[i],
              playerTaking: playerTaking,
              selected: selected == PenaltyDirection.values[i],
              onTap: () => onSelect(PenaltyDirection.values[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _DirectionButton extends StatelessWidget {
  const _DirectionButton({
    required this.direction,
    required this.playerTaking,
    required this.selected,
    required this.onTap,
  });
  final PenaltyDirection direction;
  final bool playerTaking;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = switch (direction) {
      PenaltyDirection.left => playerTaking ? '< LEFT' : '< DIVE',
      PenaltyDirection.center => playerTaking ? 'CENTER' : 'STAY',
      PenaltyDirection.right => playerTaking ? 'RIGHT >' : 'DIVE >',
    };
    final icon = switch (direction) {
      PenaltyDirection.left => Icons.arrow_back,
      PenaltyDirection.center =>
        playerTaking ? Icons.sports_soccer : Icons.pan_tool,
      PenaltyDirection.right => Icons.arrow_forward,
    };

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 96,
        decoration: BoxDecoration(
          color: selected ? Cyber.cyan.withValues(alpha: 0.12) : Cyber.panel,
          border: Border.all(
            color: selected ? Cyber.cyan : Cyber.line,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Cyber.cyan.withValues(alpha: 0.25),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: selected ? Cyber.cyan : Colors.white54),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Cyber.cyan : Colors.white54,
                fontFamily: 'Orbitron',
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KickResultCard extends StatelessWidget {
  const _KickResultCard({required this.kick});
  final PenaltyKick kick;

  @override
  Widget build(BuildContext context) {
    final goal = kick.scored;
    final color = goal ? Cyber.lime : Cyber.red;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            goal ? Icons.sports_soccer : Icons.pan_tool,
            size: 52,
            color: color,
          ),
          const SizedBox(height: 12),
          Text(
            goal ? 'GOAL' : 'SAVED',
            style: TextStyle(
              color: color,
              fontFamily: 'Orbitron',
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            kick.byPlayer ? 'You scored' : 'Opponent scored',
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WinnerBanner extends StatelessWidget {
  const _WinnerBanner({required this.winner});
  final String? winner;

  @override
  Widget build(BuildContext context) {
    final playerWon = winner == 'player';
    final color = playerWon ? Cyber.lime : Cyber.red;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        playerWon ? 'YOU WIN ON PENALTIES' : 'DEFEAT ON PENALTIES',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontFamily: 'Orbitron',
          fontSize: 16,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
