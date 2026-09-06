import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../data/rival_roster.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../leaderboard/widgets/rank_widgets.dart';

class RivalSearchResultCard extends StatelessWidget {
  const RivalSearchResultCard({
    required this.seed,
    this.isFriend = false,
    required this.onView,
    this.onToggleFriend,
    super.key,
  });

  final RivalSeed seed;
  final bool isFriend;
  final VoidCallback onView;
  final VoidCallback? onToggleFriend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cutCornerDecoration(
        color: Cyber.panel.withValues(alpha: 0.5),
        borderColor: Cyber.cyan.withValues(alpha: 0.45),
        cut: 14,
      ),
      child: Column(
        children: [
          Row(
            children: [
              RivalAvatar(name: seed.name, size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            seed.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Cyber.display(18, letterSpacing: 0.5),
                          ),
                        ),
                        if (seed.isPro) ...[
                          const SizedBox(width: 8),
                          CyberChip(label: 'PRO', color: Cyber.violet),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'LVL ${rivalLevelFor(seed)}  //  ${playerTagForName(seed.name)}',
                      style: Cyber.label(
                        10,
                        color: Cyber.muted,
                        letterSpacing: 1.2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: CyberCtaButton(label: 'View', onPressed: onView),
              ),
              if (onToggleFriend != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: CyberCtaButton(
                    label: isFriend ? 'Friend ✓' : 'Add Friend',
                    primary: !isFriend,
                    onPressed: onToggleFriend!,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
