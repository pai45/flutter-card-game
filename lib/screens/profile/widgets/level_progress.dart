import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/progression.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../predictions/widgets/history_hud.dart' show CutChipBorder;

/// Glowing level chip — the focal element on a hero card (the player/rival is
/// primary, so it earns the glow). Shared by the profile hero and the rival
/// dossier hero.
class LevelChip extends StatelessWidget {
  const LevelChip({required this.level, super.key});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: ShapeDecoration(
        color: Cyber.card,
        shape: CutChipBorder(
          cut: 7,
          side: BorderSide(
            color: Cyber.cyan.withValues(alpha: 0.85),
            width: 1.4,
          ),
        ),
        shadows: Cyber.glow(Cyber.cyan, alpha: 0.45, blur: 16, spread: 0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'LVL',
            style: Cyber.label(
              9,
              color: Cyber.cyan.withValues(alpha: 0.85),
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$level',
            style: Cyber.display(
              20,
              color: Cyber.cyan,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}

/// XP-into-level meter (label + count + [CyberProgressBar]). Shared by the
/// profile hero and the rival dossier hero.
class XpMeter extends StatelessWidget {
  const XpMeter({required this.progression, super.key});

  final PlayerProgression progression;

  @override
  Widget build(BuildContext context) {
    final p = levelProgress(progression.totalXP);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'XP',
              style: Cyber.label(10, color: Cyber.muted, letterSpacing: 1.4),
            ),
            const Spacer(),
            Text(
              '${p.intoLevel} / ${p.levelSpan}',
              style: Cyber.label(
                10,
                color: Cyber.muted,
                letterSpacing: 0.6,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        CyberProgressBar(
          value: p.pct,
          accent: Cyber.cyan,
          trackColor: Cyber.bg,
        ),
      ],
    );
  }
}
