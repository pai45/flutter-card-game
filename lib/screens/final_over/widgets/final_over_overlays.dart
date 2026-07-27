import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../widgets/cyber/cyber_cta_button.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// Between-over beat: new bowler walks in. Auto-dismisses.
class FinalOverBowlerRevealOverlay extends StatelessWidget {
  const FinalOverBowlerRevealOverlay({
    required this.overNumber,
    required this.bowlerName,
    required this.onDone,
    super.key,
  });

  final int overNumber;
  final String bowlerName;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDone,
      child: ColoredBox(
        color: Cyber.bg.withValues(alpha: 0.88),
        child: Center(
          child: CyberPanel(
            accent: Cyber.magenta,
            glow: true,
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'OVER $overNumber',
                  style: Cyber.label(11, color: Cyber.muted, letterSpacing: 2.4),
                ),
                const SizedBox(height: 10),
                Text(
                  bowlerName,
                  style: Cyber.display(
                    34,
                    color: Colors.white,
                    letterSpacing: 2,
                  ).copyWith(
                    shadows: Cyber.glow(Cyber.magenta, alpha: 0.45, blur: 18)
                        .map(
                          (s) => Shadow(
                            color: s.color,
                            blurRadius: s.blurRadius,
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'TAKES THE BALL',
                  style: Cyber.label(10, color: Cyber.magenta, letterSpacing: 2),
                ),
              ],
            ),
          ),
        ),
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
