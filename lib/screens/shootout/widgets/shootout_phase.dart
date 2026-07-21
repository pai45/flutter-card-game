import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/shootout/shootout_bloc.dart';
import '../../../blocs/shootout/shootout_event.dart';
import '../../../blocs/shootout/shootout_state.dart';
import '../../../config/enums.dart';
import '../../../config/theme.dart';
import '../../../models/cards.dart';
import '../../../models/match.dart';
import '../../../utils/game_audio_mappings.dart';
import '../../../utils/sound_effects.dart';
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

class _ShootoutPhaseState extends State<ShootoutPhase> {
  final _arenaKey = GlobalKey();
  final _confirmKey = GlobalKey();

  List<SpotlightStep> _stepsFor(ShootoutState state) {
    final shooting = state.turnRole == ShootoutTurnRole.shooting;
    return [
      SpotlightStep(
        targetKey: _arenaKey,
        title: shooting ? 'Your shot' : 'You are the keeper',
        body: shooting
            ? 'Tap a goal target, then confirm where you want to shoot.'
            : 'Use the visible dive pads to choose left, center, or right.',
        icon: shooting ? Icons.sports_soccer : Icons.shield_outlined,
        accent: shooting ? Cyber.cyan : Cyber.amber,
      ),
      SpotlightStep(
        targetKey: _confirmKey,
        title: shooting ? 'Take the shot' : 'Commit the dive',
        body: 'Your direction is only locked after you confirm it.',
        icon: shooting ? Icons.bolt : Icons.sports_handball,
        accent: Cyber.cyan,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return s.stage == ShootoutStage.result
        ? _buildResult(context, s)
        : _buildChoose(context, s);
  }

  String _directionLabel(PenaltyDirection direction) => switch (direction) {
    PenaltyDirection.left => 'LEFT',
    PenaltyDirection.center => 'CENTER',
    PenaltyDirection.right => 'RIGHT',
  };

  String _confirmLabel(ShootoutState s) {
    final selected = s.selectedDirection;
    if (selected == null) {
      return s.playerTaking ? 'CHOOSE SHOT TARGET' : 'CHOOSE DIVE DIRECTION';
    }
    final direction = _directionLabel(selected);
    return s.playerTaking
        ? 'TAKE SHOT · $direction'
        : 'COMMIT DIVE · $direction';
  }

  void _confirmKick(BuildContext context, ShootoutState state) {
    HapticFeedback.mediumImpact();
    playSound(shootoutCommitSound(state.turnRole));
    context.read<ShootoutBloc>().add(ShootoutKickConfirmed());
  }

  Widget _buildChoose(BuildContext context, ShootoutState s) {
    final playerTaking = s.playerTaking;
    final selected = s.selectedDirection;

    return MatchPhaseScaffold(
      title: s.suddenDeath ? 'SUDDEN DEATH' : 'PENALTY SHOOTOUT',
      subtitle: playerTaking
          ? '// ATTACK — YOUR SHOT'
          : '// DEFEND — YOU’RE IN GOAL',
      onQuit: widget.onQuit,
      scoreLabel: 'PEN ${s.playerScore}-${s.opponentScore}',
      spotlightKey: playerTaking ? 'shootout-attack' : 'shootout-defence',
      spotlightSteps: _stepsFor(s),
      spotlightDelay: const Duration(milliseconds: 500),
      bottomActionKey: _confirmKey,
      bottomAction: CyberCtaButton(
        label: _confirmLabel(s),
        primary: true,
        onPressed: selected == null ? null : () => _confirmKick(context, s),
      ),
      children: [
        _ShooterActionPanel(state: s),
        SpotlightTarget(
          spotlightKey: _arenaKey,
          child: PenaltyInteractionArena(
            role: s.turnRole,
            keeper: s.currentKeeper,
            selected: selected,
            onSelect: (dir) => context.read<ShootoutBloc>().add(
              ShootoutDirectionSelected(dir),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResult(BuildContext context, ShootoutState s) {
    final kick = s.kicks.last;
    final goal = kick.scored;
    final resultSubtitle = switch ((kick.byPlayer, goal)) {
      (true, true) => '// GOAL',
      (true, false) => '// SHOT SAVED',
      (false, true) => '// GOAL CONCEDED',
      (false, false) => '// YOU SAVED IT',
    };

    return MatchPhaseScaffold(
      title: s.suddenDeath ? 'SUDDEN DEATH' : 'PENALTY SHOOTOUT',
      subtitle: resultSubtitle,
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
          : _NextKickAction(
              key: ValueKey('kick-next-action-${s.kicks.length}'),
              nextRole: s.turnRole,
              onComplete: () =>
                  context.read<ShootoutBloc>().add(ShootoutNextKick()),
            ),
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
        // Shootout-over banner. Other kicks advance from the docked action.
        if (s.over) _WinnerBanner(winner: s.winner),
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
          _TurnRoleBanner(role: state.turnRole),
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

class _TurnRoleBanner extends StatelessWidget {
  const _TurnRoleBanner({required this.role});

  final ShootoutTurnRole role;

  @override
  Widget build(BuildContext context) {
    final shooting = role == ShootoutTurnRole.shooting;
    final accent = shooting ? Cyber.cyan : Cyber.amber;
    return Semantics(
      key: const ValueKey('turn-role-banner'),
      liveRegion: true,
      label: shooting
          ? 'Attack. Your shot. Tap where you want to shoot.'
          : 'Defend. You are in goal. Choose where your keeper dives.',
      child: TweenAnimationBuilder<double>(
        key: ValueKey(role),
        tween: Tween<double>(begin: 0, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 8),
            child: child,
          ),
        ),
        child: Container(
          key: ValueKey(role),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.09),
            border: Border.all(color: accent.withValues(alpha: 0.34)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.45)),
                ),
                child: Icon(
                  shooting ? Icons.sports_soccer : Icons.shield_outlined,
                  color: accent,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shooting ? 'ATTACK' : 'DEFEND',
                      style: Cyber.label(8, color: accent, letterSpacing: 1.8),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      shooting ? 'YOUR SHOT' : 'YOU’RE IN GOAL',
                      style: Cyber.display(14, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shooting
                          ? 'Tap where you want to shoot.'
                          : 'Choose where your keeper dives.',
                      style: Cyber.body(11, color: Cyber.muted),
                    ),
                  ],
                ),
              ),
              Icon(
                shooting ? Icons.north_east : Icons.sports_handball,
                color: accent.withValues(alpha: 0.85),
                size: 20,
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label:
                'Shot ${_dirLabel(kick.shootDirection)}, dive ${_dirLabel(kick.diveDirection)}',
            child: Text(
              'SHOT: ${_dirLabel(kick.shootDirection)} · '
              'DIVE: ${_dirLabel(kick.diveDirection)}',
              textAlign: TextAlign.center,
              style: Cyber.display(13, letterSpacing: 1),
            ),
          ),
          const SizedBox(height: 10),
          Row(
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
              Container(
                width: 1,
                height: 42,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: Cyber.line,
              ),
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
        ],
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
    return Row(
      children: [
        Icon(icon, color: headingColor, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                heading,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Cyber.label(8, color: headingColor, letterSpacing: 1.2),
              ),
              const SizedBox(height: 3),
              Text(
                '${playerName?.toUpperCase() ?? 'PLAYER'} · $action $direction',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Cyber.body(
                  10,
                  color: Colors.white70,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Auto-advance countdown that replaces the "Next Kick" button ────────────

class _NextKickAction extends StatefulWidget {
  const _NextKickAction({
    required this.nextRole,
    required this.onComplete,
    super.key,
  });

  final ShootoutTurnRole nextRole;
  final VoidCallback onComplete;

  @override
  State<_NextKickAction> createState() => _NextKickActionState();
}

class _NextKickActionState extends State<_NextKickAction> {
  static const _countdownSeconds = 2;
  int _seconds = _countdownSeconds;
  bool _started = false;
  bool _revealed = false;
  bool _fired = false;
  Timer? _revealTimer;
  Timer? _countdownTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    _revealTimer = Timer(
      Duration(milliseconds: reduceMotion ? 120 : 1250),
      _reveal,
    );
  }

  void _reveal() {
    if (!mounted || _fired) return;
    setState(() => _revealed = true);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _fired) {
        timer.cancel();
        return;
      }
      if (_seconds <= 1) {
        _complete();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  void _complete() {
    if (_fired) return;
    _fired = true;
    _revealTimer?.cancel();
    _countdownTimer?.cancel();
    widget.onComplete();
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final next = widget.nextRole == ShootoutTurnRole.shooting
        ? 'ATTACK'
        : 'DEFEND';
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: _revealed
          ? CyberCtaButton(
              key: const ValueKey('next-kick-ready'),
              label: 'NEXT: $next · $_seconds',
              primary: true,
              onPressed: _complete,
            )
          : Semantics(
              liveRegion: true,
              label: 'Resolving kick',
              child: Container(
                key: const ValueKey('next-kick-resolving'),
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Cyber.panel2.withValues(alpha: 0.9),
                  border: Border.all(color: Cyber.cyan.withValues(alpha: 0.22)),
                ),
                child: Text(
                  'RESOLVING KICK…',
                  style: Cyber.label(11, color: Cyber.muted),
                ),
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
            activeIndex: null,
            activeColor: Cyber.cyan,
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
            activeIndex: null,
            activeColor: Cyber.amber,
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
    required this.activeIndex,
    required this.activeColor,
  });

  final String label;
  final List<PenaltyKick> kicks;
  final int slotCount;
  final bool alignEnd;
  final int? activeIndex;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      for (var index = 0; index < slotCount; index++)
        _PenaltyAttemptIcon(
          kick: index < kicks.length ? kicks[index] : null,
          active: activeIndex == index,
          activeColor: activeColor,
        ),
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
  const _PenaltyAttemptIcon({
    required this.kick,
    required this.active,
    required this.activeColor,
  });

  final PenaltyKick? kick;
  final bool active;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final currentKick = kick;
    final bool pending = currentKick == null;
    final bool scored = currentKick?.scored ?? false;
    final color = active
        ? activeColor
        : pending
        ? Cyber.muted
        : (scored ? Cyber.lime : Cyber.red);
    final icon = pending ? Icons.sports_soccer_outlined : Icons.sports_soccer;

    return Semantics(
      label: active ? 'Current kick' : null,
      child: Container(
        key: active ? const ValueKey('active-penalty-slot') : null,
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? color.withValues(alpha: 0.18)
              : pending
              ? Colors.transparent
              : color.withValues(alpha: 0.16),
          border: Border.all(
            color: color.withValues(
              alpha: active
                  ? 0.95
                  : pending
                  ? 0.35
                  : 0.7,
            ),
            width: active
                ? 2
                : pending
                ? 1
                : 1.3,
          ),
        ),
        child: Icon(
          icon,
          size: 15,
          color: color.withValues(
            alpha: active
                ? 1
                : pending
                ? 0.45
                : 1,
          ),
        ),
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
