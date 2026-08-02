import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/progression.dart';
import 'cyber/cyber_widgets.dart';

class PlayerLevelBadge extends StatefulWidget {
  const PlayerLevelBadge({
    required this.progression,
    this.track,
    this.onTap,
    this.flatStyle = false,
    super.key,
  });

  final PlayerProgression progression;
  /// When set, shows that track's level/XP instead of the profile total.
  final ProgressTrack? track;
  final VoidCallback? onTap;
  final bool flatStyle;

  @override
  State<PlayerLevelBadge> createState() => _PlayerLevelBadgeState();
}

class _PlayerLevelBadgeState extends State<PlayerLevelBadge> {
  bool _expanded = false;

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final xp = track == null
        ? widget.progression.totalXP
        : widget.progression.xpFor(track);
    final level = track == null
        ? widget.progression.playerLevel
        : widget.progression.levelFor(track);
    final band = levelProgress(xp);
    final progress = (band.intoLevel / band.levelSpan).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: _toggleExpanded,
      child: Semantics(
        button: true,
        toggled: _expanded,
        label: track == null ? 'Player level' : '${track.displayLabel} level',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutBack,
          width: _expanded ? 222 : 132,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: Cyber.panel,
            border: Border.all(
              color: _expanded
                  ? AppTheme.primary950
                  : AppTheme.primary950.withValues(alpha: 0.9),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 34,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                      '$level',
                      style: Cyber.display(24, color: Cyber.gold),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 32,
                margin: const EdgeInsets.symmetric(horizontal: 7),
                color: Cyber.cyan.withValues(alpha: 0.22),
              ),
              SizedBox(
                width: 46,
                child: _XpMeter(
                  progress: progress,
                  label: '${band.intoLevel}/${band.levelSpan}',
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _expanded
                    ? Padding(
                        key: const ValueKey('expanded-level-details'),
                        padding: const EdgeInsets.only(left: 10),
                        child: SizedBox(
                          width: 76,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NEXT',
                                style: Cyber.label(
                                  8,
                                  color: Cyber.cyan,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${band.toNextLevel} XP',
                                overflow: TextOverflow.ellipsis,
                                style: Cyber.label(
                                  13,
                                  color: Cyber.gold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                track == null
                                    ? 'TOTAL $xp'
                                    : '${track.shortLabel} $xp',
                                overflow: TextOverflow.ellipsis,
                                style: Cyber.body(
                                  8,
                                  color: Cyber.muted,
                                  weight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.shrink(
                        key: ValueKey('collapsed-level-details'),
                      ),
              ),
              const Spacer(),
              AnimatedRotation(
                duration: const Duration(milliseconds: 240),
                turns: _expanded ? 0.5 : 0,
                child: Icon(
                  Icons.expand_more,
                  size: 14,
                  color: _expanded
                      ? AppTheme.primary950
                      : Cyber.cyan.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _XpMeter extends StatelessWidget {
  const _XpMeter({required this.progress, required this.label});

  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CyberProgressBar(
          value: progress,
          height: 5,
          radius: 0,
          animate: false,
          trackColor: Cyber.cyan.withValues(alpha: 0.15),
          trackBorderColor: Cyber.cyan.withValues(alpha: 0.16),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: Cyber.label(
            8,
            color: Cyber.muted,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
