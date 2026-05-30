import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/progression.dart';

class PlayerLevelBadge extends StatefulWidget {
  const PlayerLevelBadge({
    required this.progression,
    this.onTap,
    super.key,
  });

  final PlayerProgression progression;
  final VoidCallback? onTap;

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
    final progress = (widget.progression.xpIntoLevel /
            widget.progression.xpToNextLevel)
        .clamp(0.0, 1.0);

    return GestureDetector(
      onTap: _toggleExpanded,
      child: Semantics(
        button: true,
        toggled: _expanded,
        label: 'Player level',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutBack,
          width: _expanded ? 222 : 132,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Cyber.cyan.withValues(alpha: _expanded ? 0.22 : 0.12),
                Cyber.panel,
                Cyber.bg2,
              ],
            ),
            border: Border.all(
              color: _expanded
                  ? Cyber.gold.withValues(alpha: 0.85)
                  : Cyber.cyan.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: (_expanded ? Cyber.gold : Cyber.cyan).withValues(
                  alpha: _expanded ? 0.30 : 0.14,
                ),
                blurRadius: _expanded ? 22 : 12,
                spreadRadius: _expanded ? -4 : -8,
              ),
            ],
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
                      '${widget.progression.playerLevel}',
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
                  label:
                      '${widget.progression.xpIntoLevel}/${widget.progression.xpToNextLevel}',
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
                                '${widget.progression.xpRemainingToNextLevel} XP',
                                overflow: TextOverflow.ellipsis,
                                style: Cyber.label(
                                  13,
                                  color: Cyber.gold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'TOTAL ${widget.progression.totalXP}',
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
                  color: _expanded ? Cyber.gold : Cyber.cyan,
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
        SizedBox(
          height: 5,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Cyber.cyan.withValues(alpha: 0.15),
                  border: Border.all(
                    color: Cyber.cyan.withValues(alpha: 0.16),
                  ),
                ),
              ),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: Cyber.cyan,
                    boxShadow: [
                      BoxShadow(
                        color: Cyber.cyan.withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
