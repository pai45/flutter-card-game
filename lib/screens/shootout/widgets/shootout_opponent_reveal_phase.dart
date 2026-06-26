import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/shootout/shootout_bloc.dart';
import '../../../blocs/shootout/shootout_event.dart';
import '../../../blocs/shootout/shootout_state.dart';
import '../../../config/theme.dart';
import '../../../data/random_opponent_names.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/match_widgets.dart';

/// Random-opponent draw that precedes the squad face-off.
class ShootoutOpponentRevealPhase extends StatefulWidget {
  const ShootoutOpponentRevealPhase({
    required this.state,
    required this.onQuit,
    super.key,
  });

  final ShootoutState state;
  final VoidCallback onQuit;

  @override
  State<ShootoutOpponentRevealPhase> createState() =>
      _ShootoutOpponentRevealPhaseState();
}

class _ShootoutOpponentRevealPhaseState
    extends State<ShootoutOpponentRevealPhase>
    with SingleTickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _draw.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _locked = true);
        playSound(SoundEffect.cardReveal);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _draw.value = 1;
        setState(() => _locked = true);
      } else {
        playSound(SoundEffect.riser);
        _draw.forward();
      }
    });
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MatchPhaseScaffold(
      title: 'PENALTY SHOOTOUT',
      subtitle: '// Opponent Draw',
      onQuit: widget.onQuit,
      showStadium: false,
      centerContent: true,
      bottomAction: CyberCtaButton(
        label: 'SQUAD CLASH',
        primary: true,
        onPressed: _locked
            ? () => context.read<ShootoutBloc>().add(
                ShootoutOpponentRevealCompleted(),
              )
            : null,
      ),
      children: [
        _OpponentDrawCard(
          selectedName: widget.state.opponentName,
          animation: _draw,
          locked: _locked,
        ),
      ],
    );
  }
}

class _OpponentDrawCard extends StatelessWidget {
  const _OpponentDrawCard({
    required this.selectedName,
    required this.animation,
    required this.locked,
  });

  final String selectedName;
  final Animation<double> animation;
  final bool locked;

  String _tickerName() {
    if (locked) return selectedName;
    final eased = Curves.easeOutCubic.transform(animation.value);
    final index = (eased * 160).floor() % randomOpponentNames.length;
    return randomOpponentNames[index];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final name = _tickerName();
        final pulse = locked
            ? 1.0
            : 0.65 + math.sin(animation.value * 6).abs() * 0.35;
        return CyberPanel(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'OPPONENT DRAW',
                textAlign: TextAlign.center,
                style: Cyber.display(28, color: Cyber.gold, letterSpacing: 2.4),
              ),
              const SizedBox(height: 8),
              Text(
                locked
                    ? 'Random opponent locked. Prepare your squad.'
                    : 'Searching the global penalty queue...',
                textAlign: TextAlign.center,
                style: Cyber.body(12, color: Cyber.muted, letterSpacing: 0.4),
              ),
              const SizedBox(height: 22),
              _NameSlot(name: name, locked: locked, pulse: pulse),
              const SizedBox(height: 18),
              _DrawMeter(progress: animation.value, locked: locked),
              const SizedBox(height: 14),
              AnimatedOpacity(
                opacity: locked ? 1 : 0,
                duration: const Duration(milliseconds: 260),
                child: Text(
                  'SELECTED',
                  style: Cyber.label(11, color: Cyber.lime, letterSpacing: 2),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NameSlot extends StatelessWidget {
  const _NameSlot({
    required this.name,
    required this.locked,
    required this.pulse,
  });

  final String name;
  final bool locked;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final accent = locked ? Cyber.lime : Cyber.cyan;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Cyber.bg.withValues(alpha: 0.72),
        border: Border.all(
          color: accent.withValues(alpha: locked ? 0.95 : 0.45 + pulse * 0.3),
          width: locked ? 1.6 : 1.1,
        ),
        boxShadow: locked ? Cyber.glow(accent.withValues(alpha: 0.9)) : null,
      ),
      child: Column(
        children: [
          Icon(
            locked ? Icons.person_pin_circle : Icons.casino,
            color: accent,
            size: 30,
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 90),
            child: Text(
              name.toUpperCase(),
              key: ValueKey(name),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Cyber.display(
                locked ? 24 : 22,
                color: accent,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawMeter extends StatelessWidget {
  const _DrawMeter({required this.progress, required this.locked});

  final double progress;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CyberProgressBar(
          value: locked ? 1 : progress.clamp(0.0, 1.0),
          accent: locked ? Cyber.lime : Cyber.gold,
          height: 6,
          radius: 2,
          animate: false,
          trackColor: Cyber.line.withValues(alpha: 0.45),
        ),
        const SizedBox(height: 8),
        Text(
          locked ? 'DRAW COMPLETE' : 'LUCKY DRAW IN PROGRESS',
          style: Cyber.label(
            9,
            color: locked ? Cyber.lime : Cyber.gold,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}
