import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/progression.dart';

class PlayerLevelBadge extends StatelessWidget {
  const PlayerLevelBadge({
    required this.progression,
    this.onTap,
    super.key,
  });

  final PlayerProgression progression;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'LVL',
                style: Cyber.label(
                  8,
                  color: Cyber.cyan,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                '${progression.playerLevel}',
                style: Cyber.display(24, color: Cyber.gold),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // XP bar
              SizedBox(
                width: 70,
                height: 4,
                child: LayoutBuilder(
                  builder: (_, constraints) => Stack(
                    children: [
                      Container(
                        width: constraints.maxWidth,
                        color: Cyber.cyan.withValues(alpha: 0.15),
                      ),
                      Container(
                        width: constraints.maxWidth *
                            (progression.xpIntoLevel /
                                progression.xpToNextLevel)
                                .clamp(0.0, 1.0),
                        color: Cyber.cyan,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${progression.xpIntoLevel}/${progression.xpToNextLevel} XP',
                style: Cyber.label(
                  8,
                  color: Cyber.muted,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
