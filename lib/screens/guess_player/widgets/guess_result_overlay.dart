import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../widgets/cyber/cyber_cta_button.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

class GuessResultOverlay extends StatelessWidget {
  const GuessResultOverlay({
    required this.won,
    required this.playerName,
    required this.xpEarned,
    required this.onContinue,
    super.key,
  });

  final bool won;
  final String playerName;
  final int xpEarned;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: AppTheme.backgroundPrimary.withValues(alpha: 0.85),
        child: Center(
          child: CyberPanel(
            accent: won ? Cyber.success : Cyber.danger,
            glow: true,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  won ? Icons.check_circle_outline : Icons.cancel_outlined,
                  size: 64,
                  color: won ? Cyber.success : Cyber.danger,
                ),
                const SizedBox(height: 16),
                Text(
                  won ? 'CORRECT!' : 'GAME OVER',
                  style: Cyber.display(
                    24,
                    color: won ? Cyber.success : Cyber.danger,
                    weight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  won
                      ? 'You guessed the player.'
                      : 'Out of hearts. Better luck tomorrow.',
                  style: Cyber.body(14, color: Cyber.muted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  playerName.toUpperCase(),
                  style: Cyber.display(20, color: Colors.white),
                ),
                const SizedBox(height: 24),
                if (won) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Cyber.gold, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '+$xpEarned XP',
                        style: Cyber.display(
                          18,
                          color: Cyber.gold,
                          weight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
                HudCtaButton(
                  label: 'CONTINUE',
                  accent: won ? Cyber.success : Cyber.danger,
                  onTap: onContinue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
