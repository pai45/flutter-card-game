import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/shootout/shootout_bloc.dart';
import '../../../blocs/shootout/shootout_event.dart';
import '../../../blocs/shootout/shootout_state.dart';
import '../../../config/theme.dart';
import '../../../models/cards.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/match_widgets.dart';

/// Pre-shootout intro: both five-man lineups in kick order, then BEGIN.
class ShootoutLineupPhase extends StatefulWidget {
  const ShootoutLineupPhase({
    required this.state,
    required this.onQuit,
    super.key,
  });

  final ShootoutState state;
  final VoidCallback onQuit;

  @override
  State<ShootoutLineupPhase> createState() => _ShootoutLineupPhaseState();
}

class _ShootoutLineupPhaseState extends State<ShootoutLineupPhase> {
  @override
  void initState() {
    super.initState();
    // Tension cue under the lineup reveal.
    playSound(SoundEffect.riser);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return MatchPhaseScaffold(
      title: 'PENALTY SHOOTOUT',
      subtitle: '// Squad Lineups',
      onQuit: widget.onQuit,
      // No score yet — it begins on the kick screen. Clean HUD backdrop here.
      showStadium: false,
      bottomAction: CyberCtaButton(
        label: 'BEGIN SHOOTOUT',
        primary: true,
        onPressed: () => context.read<ShootoutBloc>().add(ShootoutStarted()),
      ),
      children: [
        const _LineupBriefing(),
        _SquadPanel(
          label: 'YOUR SQUAD',
          accent: Cyber.cyan,
          shooters: s.playerShooters,
          keeper: s.playerKeeper,
        ),
        _SquadPanel(
          label: 'CPU SQUAD',
          accent: Cyber.amber,
          shooters: s.cpuShooters,
          keeper: s.cpuKeeper,
        ),
      ],
    );
  }
}

class _LineupBriefing extends StatelessWidget {
  const _LineupBriefing();

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '5 KICKS EACH · SUDDEN DEATH IF LEVEL',
            style: Cyber.label(11, color: Cyber.cyan, letterSpacing: 1.6),
          ),
          const SizedBox(height: 6),
          const Text(
            'Every squad player takes one kick — ratings tip each duel. '
            'Your keeper guards the net on CPU kicks.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SquadPanel extends StatelessWidget {
  const _SquadPanel({
    required this.label,
    required this.accent,
    required this.shooters,
    required this.keeper,
  });

  final String label;
  final Color accent;
  final List<PlayerCard> shooters;
  final PlayerCard keeper;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Cyber.label(11, color: accent, letterSpacing: 2),
                ),
              ),
              Text(
                'GK ${keeper.shortName.toUpperCase()}',
                style: Cyber.label(9, color: Cyber.gold, letterSpacing: 1.2),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < shooters.length; i++) ...[
            _ShooterRow(order: i + 1, card: shooters[i], accent: accent),
            if (i < shooters.length - 1)
              Divider(
                height: 12,
                thickness: 1,
                color: Cyber.line.withValues(alpha: 0.6),
              ),
          ],
        ],
      ),
    );
  }
}

class _ShooterRow extends StatelessWidget {
  const _ShooterRow({
    required this.order,
    required this.card,
    required this.accent,
  });

  final int order;
  final PlayerCard card;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isKeeper = card.isGoalkeeper;
    return Row(
      children: [
        SizedBox(
          width: 22,
          child: Text(
            '$order',
            style: Cyber.display(13, color: Cyber.muted).copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Expanded(
          child: Text(
            card.shortName.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Orbitron',
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            isKeeper ? 'GK' : card.position.split('/').first,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: isKeeper ? Cyber.gold : Cyber.muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${card.rating}',
          style: Cyber.display(14, color: accent).copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
