import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/shootout/shootout_bloc.dart';
import '../../../blocs/shootout/shootout_event.dart';
import '../../../blocs/shootout/shootout_state.dart';
import '../../../config/enums.dart';
import '../../../config/theme.dart';
import '../../../models/cards.dart';
import '../../../models/match.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/match_widgets.dart';
import '../../../widgets/spotlight_walkthrough.dart';
import '../../game/widgets/match_phases.dart' show CountdownRing;
import 'penalty_goal_frame.dart';

class ShootoutPhase extends StatefulWidget {
  const ShootoutPhase({required this.state, required this.onQuit, super.key});

  final ShootoutState state;
  final VoidCallback onQuit;

  @override
  State<ShootoutPhase> createState() => _ShootoutPhaseState();
}

class _ShootoutPhaseState extends State<ShootoutPhase>
    with TickerProviderStateMixin {
  final _panelKey = GlobalKey();
  final _shootKey = GlobalKey();

  List<SpotlightStep> get _spotlightSteps => [
    SpotlightStep(
      targetKey: _panelKey,
      title: 'Penalties',
      body:
          'Your five squad players each take one kick — ratings tip the duel. Tap a goal zone to aim.',
      icon: Icons.sports_soccer,
      accent: Cyber.amber,
    ),
    SpotlightStep(
      targetKey: _shootKey,
      title: 'Confirm',
      body: 'Tap SHOOT or DIVE to take your turn.',
      icon: Icons.sports,
      accent: Cyber.cyan,
    ),
  ];

  late final AnimationController _scanner;

  @override
  void initState() {
    super.initState();
    _scanner = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return s.stage == ShootoutStage.result
        ? _buildResult(context, s)
        : _buildChoose(context, s);
  }

  String _kickLabel(ShootoutState s) => s.suddenDeath
      ? 'KICK ${s.sideKickIndex + 1} SD'
      : 'KICK ${s.sideKickIndex + 1} of 5';

  Widget _buildChoose(BuildContext context, ShootoutState s) {
    final playerTaking = s.playerTaking;
    final selected = s.selectedDirection;

    return MatchPhaseScaffold(
      title: s.suddenDeath ? 'SUDDEN DEATH' : 'PENALTY SHOOTOUT',
      subtitle: playerTaking ? '// Your Turn to Shoot' : '// Opponent Shooting',
      onQuit: widget.onQuit,
      scoreLabel: 'PEN ${s.playerScore}-${s.opponentScore}',
      spotlightKey: 'shootout',
      spotlightSteps: _spotlightSteps,
      spotlightDelay: const Duration(milliseconds: 500),
      bottomActionKey: _shootKey,
      bottomAction: CyberCtaButton(
        label: playerTaking ? 'SHOOT' : 'DIVE',
        primary: true,
        onPressed: selected == null
            ? null
            : () => context.read<ShootoutBloc>().add(ShootoutKickConfirmed()),
      ),
      children: [
        _ShootoutHeader(state: s, kickLabel: _kickLabel(s)),
        SpotlightTarget(
          spotlightKey: _panelKey,
          child: _ShooterActionPanel(state: s),
        ),
        PenaltyGoalMouth(
          playerTaking: playerTaking,
          selected: selected,
          onSelect: (dir) =>
              context.read<ShootoutBloc>().add(ShootoutDirectionSelected(dir)),
        ),
      ],
    );
  }

  Widget _buildResult(BuildContext context, ShootoutState s) {
    final kick = s.kicks.last;
    final goal = kick.scored;

    return MatchPhaseScaffold(
      title: s.suddenDeath ? 'SUDDEN DEATH' : 'PENALTY SHOOTOUT',
      subtitle: goal ? '// GOAL!' : '// SAVED!',
      onQuit: widget.onQuit,
      scoreLabel: 'PEN ${s.playerScore}-${s.opponentScore}',
      tutorialKey: null,
      tutorialSteps: const [],
      bottomAction: s.over
          ? CyberCtaButton(
              label: 'CONTINUE',
              primary: true,
              onPressed: () =>
                  context.read<ShootoutBloc>().add(ShootoutSummaryShown()),
            )
          : null,
      children: [
        // Spatial resolution: ball flight vs keeper dive on a drawn goal.
        PenaltyGoalScene(
          key: ValueKey('kick-scene-${s.kicks.length}'),
          kick: kick,
        ),
        // YOU vs CPU table — user always on the left, CPU on the right.
        _KickTable(kick: kick),
        // Kick history row
        _PenaltyHistoryRow(kicks: s.kicks),
        // Shootout-over banner OR auto-advance countdown.
        if (s.over)
          _WinnerBanner(winner: s.winner)
        else
          _NextKickCountdown(
            key: ValueKey('kick-countdown-${s.kicks.length}'),
            scanner: _scanner,
            seconds: 3,
            onComplete: () =>
                context.read<ShootoutBloc>().add(ShootoutNextKick()),
          ),
      ],
    );
  }
}

// ─── Shooter-context action panel for the choose screen ─────────────────────

class _ShooterActionPanel extends StatelessWidget {
  const _ShooterActionPanel({required this.state});

  final ShootoutState state;

  @override
  Widget build(BuildContext context) {
    final playerTaking = state.playerTaking;
    final Color accent = playerTaking ? Cyber.cyan : Cyber.amber;
    final IconData icon = playerTaking ? Icons.sports_soccer : Icons.pan_tool;
    final String title = playerTaking ? 'TAKE THE SHOT' : 'GO FOR THE SAVE';
    final shooter = state.currentShooter;
    final keeper = state.currentKeeper;
    final String description = playerTaking
        ? 'Pick a direction. The keeper will dive — outsmart them.'
        : 'Read the shooter. Dive the right way to make the save.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
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
          Text(
            title,
            textAlign: TextAlign.center,
            style: Cyber.display(22, color: accent, letterSpacing: 1.6)
                .copyWith(
                  shadows: [
                    Shadow(
                      color: accent.withValues(alpha: 0.6),
                      blurRadius: 18,
                    ),
                  ],
                ),
          ),
          const SizedBox(height: 12),
          // Whose kick it is: portrait + name + rating, vs the keeper in goal.
          Row(
            children: [
              _ShooterPortrait(card: shooter, accent: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playerTaking ? 'ON THE SPOT' : 'CPU SHOOTER',
                      style: Cyber.label(9, color: accent, letterSpacing: 1.6),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shooter.shortName.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.display(16, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${shooter.position.split('/').first} · OVR ${shooter.rating}',
                      style: const TextStyle(
                        color: Cyber.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(icon, color: accent, size: 26),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          // The keeper standing between them and the net.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              border: Border.all(color: accent.withValues(alpha: 0.55)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pan_tool, color: Cyber.gold, size: 13),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${playerTaking ? 'CPU KEEPER' : 'YOUR KEEPER'}: '
                    '${keeper.shortName.toUpperCase()} · OVR ${keeper.rating}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Cyber.gold,
                      fontFamily: 'Orbitron',
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
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

/// Compact clipped portrait with the card-icon fallback used app-wide.
class _ShooterPortrait extends StatelessWidget {
  const _ShooterPortrait({required this.card, required this.accent});

  final PlayerCard card;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final asset = card.resolvedPortraitAsset;
    return Container(
      width: 56,
      height: 66,
      decoration: BoxDecoration(
        color: Cyber.bg.withValues(alpha: 0.6),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      clipBehavior: Clip.hardEdge,
      child: asset != null
          ? Image.asset(
              asset,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, _, _) =>
                  Icon(card.icon, color: accent, size: 26),
            )
          : Icon(card.icon, color: accent, size: 26),
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
    // Name the player behind each action: the taker on the shooting side, the
    // keeper on the diving side.
    final String? userName = userShot
        ? kick.shooter?.shortName
        : kick.keeper?.shortName;
    final String? cpuName = userShot
        ? kick.keeper?.shortName
        : kick.shooter?.shortName;

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
                playerName: userName,
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
                playerName: cpuName,
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
    this.playerName,
  });

  final String heading;
  final Color headingColor;
  final String action;
  final String direction;
  final IconData icon;
  final String? playerName;

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
          if (playerName != null) ...[
            const SizedBox(height: 6),
            Text(
              playerName!.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'Orbitron',
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
          const SizedBox(height: 8),
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

// -- Shootout sub-widgets -----------------------------------------------------

class _ShootoutHeader extends StatelessWidget {
  const _ShootoutHeader({required this.state, required this.kickLabel});
  final ShootoutState state;
  final String kickLabel;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$kickLabel  -  YOU ${state.playerScore} - ${state.opponentScore} OPP',
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Orbitron',
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
          if (state.kicks.isNotEmpty) ...[
            const SizedBox(height: 10),
            _PenaltyHistoryRow(kicks: state.kicks),
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
    final bool scored = currentKick?.scored ?? false;
    final color = pending ? Cyber.muted : (scored ? Cyber.lime : Cyber.red);
    final icon = pending ? Icons.sports_soccer_outlined : Icons.sports_soccer;

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
        playerWon ? 'YOU WIN THE SHOOTOUT' : 'DEFEAT IN THE SHOOTOUT',
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
