import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../data/final_over_kits.dart';
import '../../../models/cards.dart';
import '../../../models/final_over.dart';
import '../../../utils/card_helpers.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_cta_button.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// The walk to the crease: CHASE SET → the target and the objective → a 3·2·1
/// ring. Under five seconds, and a tap skips straight to the end of it.
class FinalOverIntroOverlay extends StatefulWidget {
  const FinalOverIntroOverlay({
    required this.config,
    required this.onDone,
    super.key,
  });

  final FinalOverMatchConfig config;
  final VoidCallback onDone;

  @override
  State<FinalOverIntroOverlay> createState() => _FinalOverIntroOverlayState();
}

class _FinalOverIntroOverlayState extends State<FinalOverIntroOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanner = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  bool _counting = false;
  int _seconds = 3;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    playSound(SoundEffect.commit);
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 1600), _startCountdown);
    _scanner.addStatusListener((status) {
      if (status != AnimationStatus.completed || !_counting) return;
      if (_seconds <= 1) {
        _finish();
      } else {
        setState(() => _seconds -= 1);
        playSound(SoundEffect.countdownTick);
        _scanner.forward(from: 0);
      }
    });
  }

  void _startCountdown() {
    if (!mounted || _done) return;
    setState(() => _counting = true);
    playSound(SoundEffect.countdownTick);
    _scanner.forward(from: 0);
  }

  void _finish() {
    if (_done) return;
    _done = true;
    playSound(SoundEffect.bannerSlam);
    HapticFeedback.heavyImpact();
    widget.onDone();
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final kit = finalOverKitById(config.kitId);
    final rival = finalOverOpponentKit(config.kitId);
    final squad = cardsByIds(batsmen, config.batsmanIds);

    return GestureDetector(
      onTap: _finish,
      child: ColoredBox(
        color: Cyber.bg.withValues(alpha: 0.96),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'FINAL OVER',
                style: Cyber.label(10, color: Cyber.muted, letterSpacing: 3),
              ),
              const SizedBox(height: 6),
              Text(
                '${config.tier.label} CHASE',
                style: Cyber.display(13, color: Cyber.gold, letterSpacing: 2),
              ),
              const SizedBox(height: 22),

              // The whole game in one number.
              Text(
                '${config.target}',
                style: Cyber.display(
                  62,
                  color: Colors.white,
                  letterSpacing: 2,
                ).copyWith(
                  shadows: [
                    Shadow(
                      color: Cyber.cyan.withValues(alpha: 0.5),
                      blurRadius: 26,
                    ),
                  ],
                ),
              ),
              Text(
                'TO WIN · 6 BALLS · 2 WICKETS',
                style: Cyber.label(9, color: Cyber.cyan, letterSpacing: 2),
              ),

              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Row(
                  children: [
                    Expanded(
                      child: _SideCard(
                        kit: kit,
                        label: 'YOU',
                        role: 'BATTING',
                        accent: Cyber.cyan,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        'VS',
                        style: Cyber.display(24, color: Cyber.gold).copyWith(
                          shadows: [
                            Shadow(
                              color: Cyber.gold.withValues(alpha: 0.6),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: _SideCard(
                        kit: rival,
                        label: rival.name,
                        role: 'BOWLING',
                        accent: Cyber.magenta,
                      ),
                    ),
                  ],
                ),
              ),

              if (squad.isNotEmpty) ...[
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: Row(
                    children: [
                      for (var i = 0; i < squad.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: CyberPlayerCardTile(
                            card: squad[i],
                            selected: false,
                            size: VisualCardSize.sm,
                            onTap: () {},
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 26),
              SizedBox(
                height: 120,
                child: _counting
                    ? CountdownRing(
                        seconds: _seconds,
                        scanner: _scanner,
                        accent: Cyber.gold,
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 8),
              Text(
                'TAP TO SKIP',
                style: Cyber.label(8, color: Cyber.muted, letterSpacing: 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideCard extends StatelessWidget {
  const _SideCard({
    required this.kit,
    required this.label,
    required this.role,
    required this.accent,
  });

  final FinalOverKit kit;
  final String label;
  final String role;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: accent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        children: [
          // A swatch of the kit — the same colours you'll see on the pitch.
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: kit.primary,
              shape: BoxShape.circle,
              border: Border.all(color: kit.secondary, width: 2),
            ),
            alignment: Alignment.center,
            child: Container(width: 10, height: 10, color: kit.accent),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Cyber.display(12, color: Colors.white, letterSpacing: 1),
          ),
          const SizedBox(height: 6),
          CyberChip(label: role, color: accent),
        ],
      ),
    );
  }
}

/// Pause. The chase is frozen exactly where it stood — the engine's clock does
/// not advance, so nothing is lost.
class FinalOverPauseOverlay extends StatelessWidget {
  const FinalOverPauseOverlay({
    required this.onResume,
    required this.onQuit,
    super.key,
  });

  final VoidCallback onResume;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Cyber.bg.withValues(alpha: 0.92),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: CyberPanel(
                accent: Cyber.cyan,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'CHASE PAUSED',
                      textAlign: TextAlign.center,
                      style: Cyber.display(
                        26,
                        color: Colors.white,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The over is held exactly where you left it.',
                      textAlign: TextAlign.center,
                      style: Cyber.body(12, color: Cyber.muted),
                    ),
                    const SizedBox(height: 20),
                    HudCtaButton(
                      label: 'RESUME',
                      icon: Icons.play_arrow_rounded,
                      accent: Cyber.cyan,
                      onTap: onResume,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: onQuit,
                      child: Text(
                        'QUIT WITHOUT REWARD',
                        style: Cyber.label(
                          10,
                          color: Cyber.danger,
                          letterSpacing: 1.6,
                        ),
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
}
