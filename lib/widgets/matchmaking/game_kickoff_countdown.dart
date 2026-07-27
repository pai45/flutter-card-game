import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../utils/sound_effects.dart';

/// Pitch Duel-style 3-2-1 slam then a GO stamp. Used after matchmaking locks.
class GameKickoffCountdown extends StatefulWidget {
  const GameKickoffCountdown({
    required this.onComplete,
    this.goLabel = 'GO!',
    this.background,
    super.key,
  });

  final VoidCallback onComplete;

  /// Stamp text after the countdown (e.g. KICK OFF!, TIP OFF!).
  final String goLabel;

  /// Optional full-bleed bed behind the numbers. Defaults to dark Cyber.bg.
  final Widget? background;

  @override
  State<GameKickoffCountdown> createState() => _GameKickoffCountdownState();
}

class _GameKickoffCountdownState extends State<GameKickoffCountdown>
    with TickerProviderStateMixin {
  int _stage = 0; // 0 = countdown, 1 = go stamp
  int _countdown = 3;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _kickoff = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 680),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onComplete();
      });
      return;
    }
    _runCountdown();
  }

  Future<void> _runCountdown() async {
    for (var i = 3; i > 0; i--) {
      if (!mounted) return;
      setState(() {
        _stage = 0;
        _countdown = i;
      });
      _pulse
        ..reset()
        ..forward();
      playSound(SoundEffect.countdownTick);
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;
    setState(() => _stage = 1);
    _kickoff.forward();
    playSound(SoundEffect.goal);
    await Future<void>.delayed(const Duration(milliseconds: 780));
    if (mounted) widget.onComplete();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _kickoff.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _kickoff]),
        builder: (context, _) => Stack(
          fit: StackFit.expand,
          children: [
            widget.background ?? const ColoredBox(color: Cyber.bg),
            if (_stage == 0) _buildCountdown(),
            if (_stage == 1) _buildGoStamp(),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdown() {
    final p = _pulse.value;

    final double scale;
    final double opacity;
    if (p < 0.25) {
      scale = 2.0 - Curves.easeOutBack.transform(p / 0.25);
      opacity = 1.0;
    } else if (p < 0.82) {
      scale = 1.0;
      opacity = 1.0;
    } else {
      final t = (p - 0.82) / 0.18;
      scale = 1.0 + 0.18 * t;
      opacity = 1.0 - t;
    }
    final glow = (1 - (p / 0.45).clamp(0.0, 1.0)) * 0.85 + 0.15;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'MATCH STARTING IN',
            style: Cyber.label(
              11,
              color: Cyber.cyan.withValues(alpha: 0.55),
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 18),
          Transform.scale(
            scale: scale.clamp(0.4, 2.5),
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Text(
                '$_countdown',
                style: Cyber.display(
                  128,
                  color: Cyber.lime,
                  letterSpacing: 0,
                ).copyWith(
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: Cyber.lime.withValues(alpha: glow),
                      blurRadius: 52,
                    ),
                    Shadow(
                      color: Cyber.cyan.withValues(alpha: glow * 0.55),
                      blurRadius: 80,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoStamp() {
    final k = Curves.easeOutBack.transform(_kickoff.value);
    final flash = (1 - (_kickoff.value / 0.38).clamp(0.0, 1.0)) * 0.55;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Cyber.lime.withValues(alpha: flash.clamp(0.0, 1.0))),
        Center(
          child: Transform.translate(
            offset: Offset(0, -90 * (1 - k.clamp(0.0, 1.0))),
            child: Transform.scale(
              scale: (0.35 + 0.65 * k).clamp(0.0, 1.5),
              child: Opacity(
                opacity: k.clamp(0.0, 1.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Cyber.lime.withValues(alpha: 0.13),
                    border: Border.all(color: Cyber.lime, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Cyber.lime.withValues(alpha: 0.6),
                        blurRadius: 44,
                      ),
                    ],
                  ),
                  child: Text(
                    widget.goLabel,
                    style:
                        Cyber.display(
                          42,
                          color: Cyber.lime,
                          letterSpacing: 4,
                        ).copyWith(
                          shadows: [
                            const Shadow(color: Cyber.lime, blurRadius: 22),
                          ],
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
