import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/grand_prix/grand_prix_cubit.dart';
import '../../../blocs/grand_prix/grand_prix_state.dart';
import '../../../config/theme.dart';
import '../../../games/grand_prix/grand_prix_engine.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_cta_button.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

class GrandPrixMomentToast extends StatelessWidget {
  const GrandPrixMomentToast({required this.moment, super.key});
  final ValueNotifier<GrandPrixMoment?> moment;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Align(
      alignment: const Alignment(0, -0.1),
      child: ValueListenableBuilder<GrandPrixMoment?>(
        valueListenable: moment,
        builder: (context, value, _) => AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          child: value == null
              ? const SizedBox.shrink()
              : Padding(
                  key: ObjectKey(value),
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: CyberPanel(
                    accent: value.kind == GrandPrixMomentKind.recovery
                        ? Cyber.amber
                        : Cyber.cyan,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          value.label,
                          style: Cyber.display(14, color: Cyber.cyan),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          value.detail.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: Cyber.label(
                            8,
                            color: Cyber.muted,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    ),
  );
}

class GrandPrixGridCoach extends StatelessWidget {
  const GrandPrixGridCoach({required this.onReady, super.key});
  final VoidCallback onReady;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Cyber.bg.withValues(alpha: 0.94),
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: CyberPanel(
            accent: Cyber.f1Red,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'FIND YOUR RACING LINE',
                  style: Cyber.display(20, color: Cyber.cyan),
                ),
                const SizedBox(height: 8),
                Text(
                  'Twenty cars. Every corner is a chance to move up.',
                  style: Cyber.bodyFor(context, 12, color: Cyber.muted),
                ),
                const SizedBox(height: 20),
                for (final step in const [
                  (
                    Icons.touch_app,
                    'STEER',
                    'Drag your left thumb. Small inputs hold the line.',
                  ),
                  (
                    Icons.traffic,
                    'LIGHTS OUT',
                    'Wait for five red lights to go dark, then hold ACCEL.',
                  ),
                  (
                    Icons.turn_right,
                    'BRAKE · TURN · ACCEL',
                    'Brake before the bend. Steer in, then accelerate out.',
                  ),
                  (
                    Icons.bolt,
                    'TOW · DEPLOY',
                    'Follow a rival, pull out and hold ERS to attack. Braking recharges it.',
                  ),
                ]) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(step.$1, color: Cyber.cyan, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.$2,
                              style: Cyber.label(9, color: AppTheme.whiteColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              step.$3,
                              style: Cyber.bodyFor(
                                context,
                                12,
                                color: Cyber.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                HudCtaButton(
                  label: 'TO THE GRID',
                  accent: Cyber.f1Red,
                  onTap: onReady,
                ),
                const SizedBox(height: 8),
                Text(
                  'KEYBOARD: WASD / ARROWS · SPACE ERS · ESC PAUSE',
                  textAlign: TextAlign.center,
                  style: Cyber.label(7, color: Cyber.muted, letterSpacing: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class GrandPrixPauseLayer extends StatefulWidget {
  const GrandPrixPauseLayer({
    required this.onResume,
    required this.onExit,
    super.key,
  });
  final VoidCallback onResume, onExit;
  @override
  State<GrandPrixPauseLayer> createState() => _GrandPrixPauseLayerState();
}

class _GrandPrixPauseLayerState extends State<GrandPrixPauseLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanner;
  @override
  void initState() {
    super.initState();
    _scanner = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  Timer? _timer;
  int? _seconds;
  void _resume() {
    if (_seconds != null) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      widget.onResume();
      return;
    }
    setState(() => _seconds = 3);
    _scanner.repeat();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_seconds == 1) {
        timer.cancel();
        widget.onResume();
      } else {
        setState(() => _seconds = _seconds! - 1);
        playSound(SoundEffect.countdownTick);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Cyber.bg.withValues(alpha: 0.94),
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: _seconds != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CountdownRing(
                      seconds: _seconds!,
                      scanner: _scanner,
                      accent: Cyber.cyan,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'BACK TO THE RACE',
                      style: Cyber.label(10, color: Cyber.muted),
                    ),
                  ],
                )
              : BlocBuilder<GrandPrixCubit, GrandPrixState>(
                  builder: (context, state) {
                    final cubit = context.read<GrandPrixCubit>();
                    return CyberPanel(
                      accent: Cyber.f1Red,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'RACE PAUSED',
                            style: Cyber.display(24, color: Cyber.cyan),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Take a breath. Your race is waiting.',
                            style: Cyber.bodyFor(
                              context,
                              12,
                              color: Cyber.muted,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _Preference(
                            label: 'STEERING',
                            value: state.stats.classicControls
                                ? 'BUTTONS'
                                : 'ANALOGUE',
                            onTap: () => cubit.setDrivingPreferences(
                              classicControls: !state.stats.classicControls,
                            ),
                          ),
                          _Preference(
                            label: 'HAPTICS',
                            value: state.stats.hapticsEnabled ? 'ON' : 'OFF',
                            onTap: () => cubit.setDrivingPreferences(
                              hapticsEnabled: !state.stats.hapticsEnabled,
                            ),
                          ),
                          _Preference(
                            label: 'EFFECTS',
                            value: state.stats.reducedEffects
                                ? 'REDUCED'
                                : 'FULL',
                            onTap: () => cubit.setDrivingPreferences(
                              reducedEffects: !state.stats.reducedEffects,
                            ),
                          ),
                          ValueListenableBuilder<bool>(
                            valueListenable: AudioController.instance.muted,
                            builder: (context, muted, _) => _Preference(
                              label: 'SOUND',
                              value: muted ? 'OFF' : 'ON',
                              onTap: AudioController.instance.toggleMute,
                            ),
                          ),
                          const SizedBox(height: 16),
                          HudCtaButton(
                            label: 'RESUME RACE',
                            onTap: _resume,
                            accent: Cyber.cyan,
                          ),
                          const SizedBox(height: 12),
                          _Preference(
                            label: 'LEAVE RACE',
                            value: 'EXIT',
                            onTap: widget.onExit,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    ),
  );
}

class _Preference extends StatelessWidget {
  const _Preference({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label, value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Semantics(
      button: true,
      label: '$label $value',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: CyberPanel(
          accent: Cyber.border,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(label, style: Cyber.label(9, color: Cyber.muted)),
              const Spacer(),
              Text(value, style: Cyber.label(9, color: Cyber.cyan)),
            ],
          ),
        ),
      ),
    ),
  );
}
