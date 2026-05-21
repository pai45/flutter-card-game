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

class PenaltyPhase extends StatefulWidget {
  const PenaltyPhase({required this.state, required this.onQuit, super.key});

  final GameState state;
  final VoidCallback onQuit;

  @override
  State<PenaltyPhase> createState() => _PenaltyPhaseState();
}

class _PenaltyPhaseState extends State<PenaltyPhase>
    with SingleTickerProviderStateMixin {
  late AnimationController _revealCtrl;
  late Animation<double> _revealScale;

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
        // Instructions
        CyberPanel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Text(
            playerTaking
                ? 'Pick your shoot direction. The keeper will dive - outsmart them.'
                : 'Pick your dive direction. Try to read the opponent\'s shot.',
            style: const TextStyle(color: Cyber.muted, fontSize: 13, height: 1.4),
          ),
        ),
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
          : CyberCtaButton(
              label: 'Next Kick',
              primary: false,
              onPressed: () => context.read<GameBloc>().add(PenaltyNextKick()),
            ),
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
        // Direction breakdown
        _DirectionBreakdown(kick: kick),
        // Kick history row
        _PenaltyHistoryRow(kicks: s.penaltyKicks),
        // Shootout-over banner or next kick
        if (s.penaltyPhaseOver) _WinnerBanner(winner: s.penaltyWinner),
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
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: kicks.map((k) {
        final color = k.byPlayer
            ? (k.scored ? Cyber.lime : Cyber.red)
            : (k.scored ? Cyber.red : Cyber.lime);
        return Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Icon(
            k.scored ? Icons.sports_soccer : Icons.pan_tool,
            size: 14,
            color: color,
          ),
        );
      }).toList(),
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
          color: selected
              ? Cyber.cyan.withValues(alpha: 0.12)
              : Cyber.panel,
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
            Icon(
              icon,
              size: 26,
              color: selected ? Cyber.cyan : Colors.white54,
            ),
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

class _DirectionBreakdown extends StatelessWidget {
  const _DirectionBreakdown({required this.kick});
  final PenaltyKick kick;

  String _dirLabel(PenaltyDirection d) => switch (d) {
    PenaltyDirection.left => 'LEFT',
    PenaltyDirection.center => 'CENTER',
    PenaltyDirection.right => 'RIGHT',
  };

  @override
  Widget build(BuildContext context) {
    final shootLabel = kick.byPlayer ? 'You shot' : 'Opponent shot';
    final diveLabel = kick.byPlayer ? 'Keeper dived' : 'You dived';
    final match = kick.shootDirection == kick.diveDirection;

    return CyberPanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shootLabel,
                  style: const TextStyle(color: Cyber.muted, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  _dirLabel(kick.shootDirection),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Orbitron',
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            match ? Icons.compare_arrows : Icons.close,
            color: match ? Cyber.red : Cyber.lime,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  diveLabel,
                  style: const TextStyle(color: Cyber.muted, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  _dirLabel(kick.diveDirection),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Orbitron',
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
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
