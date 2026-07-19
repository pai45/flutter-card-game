import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/game/game_bloc.dart';
import '../../../config/theme.dart';
import '../../../models/grand_prix.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/level_up_celebration.dart';

/// Post-race cinematic, modelled on the Football Chess full-time screen: a
/// sequenced reveal — verdict banner → giant finishing position + places
/// gained → race stat rows (lap time/PB, launch grade, MVP move) → XP
/// count-up — over a fixed RACE AGAIN / EXIT dock. A level-up crossing plays
/// the shared celebration after the sequence.
class GrandPrixResultOverlay extends StatefulWidget {
  const GrandPrixResultOverlay({
    required this.result,
    required this.circuitName,
    required this.onExit,
    required this.onRaceAgain,
    super.key,
  });

  final GrandPrixResult result;
  final String circuitName;
  final VoidCallback onExit;
  final VoidCallback onRaceAgain;

  @override
  State<GrandPrixResultOverlay> createState() => _GrandPrixResultState();
}

class _GrandPrixResultState extends State<GrandPrixResultOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _seq = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  late final Animation<double> _banner = CurvedAnimation(
    parent: _seq,
    curve: const Interval(0.0, 0.20, curve: Curves.easeOut),
  );
  late final Animation<double> _position = CurvedAnimation(
    parent: _seq,
    curve: const Interval(0.10, 0.36, curve: Curves.easeOutBack),
  );
  late final Animation<double> _statRows = CurvedAnimation(
    parent: _seq,
    curve: const Interval(0.28, 0.52, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _xpPanel = CurvedAnimation(
    parent: _seq,
    curve: const Interval(0.40, 0.62, curve: Curves.easeOutCubic),
  );

  bool _showLevelUp = false;

  @override
  void initState() {
    super.initState();
    if (WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations) {
      _seq.value = 1;
      _maybeLevelUp();
    } else {
      _seq.forward();
      _seq.addStatusListener((status) {
        if (status == AnimationStatus.completed) _maybeLevelUp();
      });
    }
  }

  void _maybeLevelUp() {
    if (!mounted) return;
    if (context.read<GameBloc>().state.pendingLevelUps.isNotEmpty) {
      setState(() => _showLevelUp = true);
    }
  }

  @override
  void dispose() {
    _seq.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final (verdictText, accent, icon) = result.retired
        ? ('RETIRED', Cyber.danger, Icons.warning_amber_rounded)
        : switch (result.verdict) {
            GrandPrixVerdict.win => ('WIN', Cyber.gold, Icons.emoji_events),
            GrandPrixVerdict.podium =>
              ('PODIUM', Cyber.violet, Icons.military_tech),
            GrandPrixVerdict.points => ('POINTS', Cyber.cyan, Icons.flag),
            GrandPrixVerdict.finished =>
              ('FINISHED', Cyber.amber, Icons.sports_score),
          };
    final game = context.watch<GameBloc>().state;
    final prog = game.progression;

    return Positioned.fill(
      child: Container(
        color: Cyber.bg.withValues(alpha: 0.94),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _seq,
                      builder: (context, _) {
                        final xpT =
                            ((_seq.value - 0.48) / 0.42).clamp(0.0, 1.0);
                        final shownXp = (result.xp * xpT).round();
                        final barFill = (prog.xpToNextLevel == 0
                                ? 0.0
                                : prog.xpIntoLevel / prog.xpToNextLevel) *
                            xpT;
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                          child: Column(
                            children: [
                              FadeTransition(
                                opacity: _banner,
                                child: _VerdictBanner(
                                  verdict: verdictText,
                                  accent: accent,
                                  icon: icon,
                                  circuitName: result.laps > 1
                                      ? '${widget.circuitName} · '
                                          '${result.laps} LAPS'
                                      : widget.circuitName,
                                ),
                              ),
                              const SizedBox(height: 18),
                              ScaleTransition(
                                scale: _position,
                                child: _PositionReadout(result: result),
                              ),
                              const SizedBox(height: 18),
                              FadeTransition(
                                opacity: _statRows,
                                child: _RaceStats(
                                  result: result,
                                ),
                              ),
                              const SizedBox(height: 16),
                              FadeTransition(
                                opacity: _xpPanel,
                                child: SlideTransition(
                                  position: Tween(
                                    begin: const Offset(0, 0.4),
                                    end: Offset.zero,
                                  ).animate(_xpPanel),
                                  child: _XpPanel(
                                    shownXp: shownXp,
                                    barFill: barFill.clamp(0.0, 1.0),
                                    level: prog.playerLevel,
                                    into: prog.xpIntoLevel,
                                    span: prog.xpToNextLevel,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  _Dock(
                    onExit: widget.onExit,
                    onRaceAgain: widget.onRaceAgain,
                  ),
                ],
              ),
              if (_showLevelUp)
                LevelUpCelebration(
                  levels: game.pendingLevelUps,
                  progression: game.progression,
                  xpEarned: game.lastMatchXP ?? 0,
                  onDismissed: () => setState(() => _showLevelUp = false),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerdictBanner extends StatelessWidget {
  const _VerdictBanner({
    required this.verdict,
    required this.accent,
    required this.icon,
    required this.circuitName,
  });

  final String verdict;
  final Color accent;
  final IconData icon;
  final String circuitName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent, width: 1.5),
        boxShadow: Cyber.glow(accent),
      ),
      child: Column(
        children: [
          Icon(icon, color: accent, size: 34),
          const SizedBox(height: 6),
          Text(verdict, style: Cyber.display(34, color: accent, letterSpacing: 3)),
          const SizedBox(height: 4),
          Text(
            circuitName,
            style: Cyber.label(9, color: Cyber.muted, letterSpacing: 2),
          ),
        ],
      ),
    );
  }
}

class _PositionReadout extends StatelessWidget {
  const _PositionReadout({required this.result});

  final GrandPrixResult result;

  @override
  Widget build(BuildContext context) {
    if (result.retired) {
      return Column(
        children: [
          Text(
            'DNF',
            style: Cyber.display(64, color: Cyber.danger).copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'GAME OVER · STUCK ON TRACK',
            style: Cyber.label(10, color: Cyber.danger, letterSpacing: 1.8),
          ),
        ],
      );
    }
    final gained = result.placesGained;
    final (deltaText, deltaColor) = gained > 0
        ? ('▲ $gained PLACES GAINED', Cyber.success)
        : gained < 0
            ? ('▼ ${-gained} PLACES LOST', Cyber.danger)
            : ('HELD POSITION', Cyber.muted);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'P${result.position}',
              style: Cyber.display(64, color: Cyber.cyan).copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              '/${result.fieldSize}',
              style: Cyber.display(28, color: Cyber.muted).copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          deltaText,
          style: Cyber.label(10, color: deltaColor, letterSpacing: 1.8),
        ),
      ],
    );
  }
}

class _RaceStats extends StatelessWidget {
  const _RaceStats({required this.result});

  final GrandPrixResult result;

  @override
  Widget build(BuildContext context) {
    final launch = switch (result.launchGrade) {
      LaunchGrade.perfect => ('PERFECT', Cyber.gold),
      LaunchGrade.great => ('GREAT', Cyber.success),
      LaunchGrade.good => ('GOOD', Cyber.cyan),
      LaunchGrade.slow => ('SLOW', Cyber.amber),
      LaunchGrade.jump => ('JUMP START', Cyber.danger),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Cyber.panel.withValues(alpha: 0.85),
        border: Border.all(color: Cyber.border),
      ),
      child: Column(
        children: [
          _StatRow(
            label: result.laps > 1 ? 'RACE TIME' : 'LAP TIME',
            valueWidget: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatLapTime(result.lapTimeMs),
                  style: Cyber.display(13, color: Colors.white).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (result.personalBest) ...[
                  const SizedBox(width: 8),
                  const CyberChip(label: 'PB', color: Cyber.gold),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          _StatRow(
            label: 'LAUNCH',
            valueWidget: CyberChip(label: launch.$1, color: launch.$2),
          ),
          if (result.bestOvertakeName != null) ...[
            const SizedBox(height: 10),
            _StatRow(
              label: 'MVP MOVE',
              valueWidget: Text(
                'PASSED ${result.bestOvertakeName!.toUpperCase()}',
                style: Cyber.label(10, color: Cyber.cyan, letterSpacing: 1),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.valueWidget});

  final String label;
  final Widget valueWidget;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.6),
        ),
        const Spacer(),
        valueWidget,
      ],
    );
  }
}

class _XpPanel extends StatelessWidget {
  const _XpPanel({
    required this.shownXp,
    required this.barFill,
    required this.level,
    required this.into,
    required this.span,
  });

  final int shownXp;
  final double barFill;
  final int level;
  final int into;
  final int span;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Cyber.panel.withValues(alpha: 0.85),
        border: Border.all(color: Cyber.violet.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '+$shownXp XP',
            style: const TextStyle(
              fontFamily: Cyber.displayFont,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: Cyber.violet,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 12),
          CyberProgressBar(
            value: barFill,
            accent: Cyber.violet,
            height: 6,
            radius: 3,
            animate: false,
            trackColor: Cyber.violet.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 8),
          Text(
            '$into / $span XP · LEVEL $level',
            style: Cyber.label(9, color: Cyber.muted, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

class _Dock extends StatelessWidget {
  const _Dock({required this.onExit, required this.onRaceAgain});

  final VoidCallback onExit;
  final VoidCallback onRaceAgain;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: CyberCtaButton(
              label: 'EXIT',
              onPressed: () {
                playSound(SoundEffect.uiTap);
                onExit();
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CyberCtaButton(
              label: 'RACE AGAIN',
              primary: true,
              onPressed: () {
                playSound(SoundEffect.playMatch);
                onRaceAgain();
              },
            ),
          ),
        ],
      ),
    );
  }
}
