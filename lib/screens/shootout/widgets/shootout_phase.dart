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

  String _directionLabel(PenaltyDirection direction) => switch (direction) {
    PenaltyDirection.left => 'LEFT',
    PenaltyDirection.center => 'CENTER',
    PenaltyDirection.right => 'RIGHT',
  };

  String _confirmLabel(ShootoutState s) {
    final selected = s.selectedDirection;
    if (selected == null) return s.playerTaking ? 'PICK A SIDE' : 'PICK A DIVE';
    final direction = _directionLabel(selected);
    if (s.playerTaking) return 'SHOOT $direction';
    return selected == PenaltyDirection.center
        ? 'STAY CENTER'
        : 'DIVE $direction';
  }

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
        label: _confirmLabel(s),
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
        // YOU vs opponent table — user always on the left, opponent on the right.
        _KickTable(kick: kick, opponentName: s.opponentName),
        // Kick history row
        _PenaltyHistoryRow(kicks: s.kicks, opponentName: s.opponentName),
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
    final Color keeperAccent = playerTaking ? Cyber.amber : Cyber.cyan;
    final String prompt = playerTaking ? 'CHOOSE YOUR CORNER' : 'READ THE SHOT';
    final shooter = state.currentShooter;
    final keeper = state.currentKeeper;
    final opponentFirst = state.opponentName.split(RegExp(r'\s+')).first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Cyber.panel.withValues(alpha: 0.68),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
        gradient: LinearGradient(
          colors: [
            Cyber.panel2.withValues(alpha: 0.72),
            Cyber.bg.withValues(alpha: 0.42),
          ],
        ),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.10), blurRadius: 18),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            prompt,
            textAlign: TextAlign.center,
            style: Cyber.display(15, color: accent, letterSpacing: 1.4)
                .copyWith(
                  shadows: [
                    Shadow(
                      color: accent.withValues(alpha: 0.45),
                      blurRadius: 14,
                    ),
                  ],
                ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DuelPlayerSummary(
                  label: playerTaking
                      ? 'SHOOTER'
                      : '${opponentFirst.toUpperCase()} SHOOTER',
                  card: shooter,
                  accent: accent,
                  alignEnd: false,
                ),
              ),
              _VersusBadge(accent: accent),
              Expanded(
                child: _DuelPlayerSummary(
                  label: playerTaking ? 'KEEPER' : 'YOUR KEEPER',
                  card: keeper,
                  accent: keeperAccent,
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DuelPlayerSummary extends StatelessWidget {
  const _DuelPlayerSummary({
    required this.label,
    required this.card,
    required this.accent,
    required this.alignEnd,
  });

  final String label;
  final PlayerCard card;
  final Color accent;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final textAlign = alignEnd ? TextAlign.right : TextAlign.left;
    return Row(
      textDirection: alignEnd ? TextDirection.rtl : TextDirection.ltr,
      children: [
        _ShooterPortrait(card: card, accent: accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: alignEnd
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: textAlign,
                style: Cyber.label(8, color: accent, letterSpacing: 1.4),
              ),
              const SizedBox(height: 4),
              Text(
                card.shortName.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: textAlign,
                style: Cyber.display(13, letterSpacing: 0.6),
              ),
              const SizedBox(height: 3),
              Text(
                '${card.position.split('/').first} / OVR ${card.rating}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: textAlign,
                style: const TextStyle(
                  color: Cyber.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VersusBadge extends StatelessWidget {
  const _VersusBadge({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.10),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Text(
        'VS',
        style: Cyber.label(9, color: accent, letterSpacing: 0.8),
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
      width: 44,
      height: 50,
      decoration: BoxDecoration(
        color: Cyber.bg.withValues(alpha: 0.6),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
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

// ─── YOU vs opponent result table ────────────────────────────────────────────

class _KickTable extends StatelessWidget {
  const _KickTable({required this.kick, required this.opponentName});
  final PenaltyKick kick;
  final String opponentName;

  String _dirLabel(PenaltyDirection d) => switch (d) {
    PenaltyDirection.left => 'LEFT',
    PenaltyDirection.center => 'CENTER',
    PenaltyDirection.right => 'RIGHT',
  };

  @override
  Widget build(BuildContext context) {
    // User is always on the LEFT, opponent on the RIGHT — regardless of who shot.
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
                heading: opponentName.toUpperCase(),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: Cyber.bg2.withValues(alpha: 0.50),
        border: Border.all(color: Cyber.cyan.withValues(alpha: 0.24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _ShootoutMetricPill(
                  label: kickLabel.toUpperCase(),
                  color: Cyber.cyan,
                  alignStart: true,
                ),
              ),
              const SizedBox(width: 8),
              _ShootoutMetricPill(
                label: 'YOU ${state.playerScore}',
                color: Cyber.cyan,
              ),
              const SizedBox(width: 8),
              _ShootoutMetricPill(
                label: 'OPP ${state.opponentScore}',
                color: Cyber.amber,
              ),
            ],
          ),
          if (state.kicks.isNotEmpty) ...[
            const SizedBox(height: 12),
            _PenaltyHistoryRow(
              kicks: state.kicks,
              opponentName: state.opponentName,
            ),
          ],
        ],
      ),
    );
  }
}

class _ShootoutMetricPill extends StatelessWidget {
  const _ShootoutMetricPill({
    required this.label,
    required this.color,
    this.alignStart = false,
  });

  final String label;
  final Color color;
  final bool alignStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      alignment: alignStart ? Alignment.centerLeft : Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color.withValues(alpha: 0.92),
          fontFamily: 'Orbitron',
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _PenaltyHistoryRow extends StatelessWidget {
  const _PenaltyHistoryRow({required this.kicks, required this.opponentName});
  final List<PenaltyKick> kicks;
  final String opponentName;

  @override
  Widget build(BuildContext context) {
    final playerKicks = kicks.where((kick) => kick.byPlayer).toList();
    final opponentKicks = kicks.where((kick) => !kick.byPlayer).toList();
    final slotCount = max(5, max(playerKicks.length, opponentKicks.length));
    final firstName = opponentName.split(RegExp(r'\s+')).first.toUpperCase();
    final opponentLabel = firstName.length <= 6 ? firstName : 'OPP';

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
            label: opponentLabel,
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
