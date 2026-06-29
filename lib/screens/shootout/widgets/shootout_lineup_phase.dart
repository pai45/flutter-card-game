import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/shootout/shootout_bloc.dart';
import '../../../blocs/shootout/shootout_event.dart';
import '../../../blocs/shootout/shootout_state.dart';
import '../../../config/theme.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/cyber/squad_faceoff.dart';
import '../../../widgets/match_widgets.dart';

/// Pre-shootout face-off: both five-man squads square up across a glowing VS.
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

class _ShootoutLineupPhaseState extends State<ShootoutLineupPhase>
    with SingleTickerProviderStateMixin {
  // Drives the staggered face-off reveal: your squad slides in, the VS stamps,
  // then the opponent squad answers — all off this single controller.
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );

  @override
  void initState() {
    super.initState();
    // Tension cue under the face-off reveal.
    playSound(SoundEffect.riser);
    _reveal.forward();
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MatchPhaseScaffold(
      title: 'PENALTY SHOOTOUT',
      subtitle: '// Face-Off',
      onQuit: widget.onQuit,
      // No score yet — it begins on the kick screen. Clean HUD backdrop here.
      showStadium: false,
      // Centre the face-off in the page rather than top-aligning it.
      centerContent: true,
      bottomAction: CyberCtaButton(
        label: 'BEGIN SHOOTOUT',
        primary: true,
        onPressed: () => context.read<ShootoutBloc>().add(ShootoutStarted()),
      ),
      children: [
        SquadFaceoff(
          reveal: _reveal,
          topLabel: 'YOUR SQUAD',
          topSquad: widget.state.playerShooters,
          topAccent: Cyber.cyan,
          bottomLabel: '${widget.state.opponentName.toUpperCase()} SQUAD',
          bottomSquad: widget.state.cpuShooters,
          bottomAccent: Cyber.amber,
          showTopPips: true,
        ),
      ],
    );
  }
}
