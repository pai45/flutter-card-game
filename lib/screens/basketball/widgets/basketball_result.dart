import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/game/game_bloc.dart';
import '../../../config/theme.dart';
import '../../../models/basketball.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_cta_button.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/level_up_celebration.dart';

/// Full-time result reveal: verdict banner → score + grade plate → box-score
/// grid → XP count-up + record → CTAs. Staged like the quiz/settlement
/// reveals (timer-driven beats, tap skips to the end); XP was credited before
/// this overlay is shown, so skipping changes nothing.
class BasketballResultOverlay extends StatefulWidget {
  const BasketballResultOverlay({
    required this.summary,
    required this.xp,
    required this.stats,
    required this.onRematch,
    required this.onExit,
    super.key,
  });

  final BasketballMatchSummary summary;
  final int xp;
  final BasketballStats stats;
  final VoidCallback onRematch;
  final VoidCallback onExit;

  @override
  State<BasketballResultOverlay> createState() =>
      _BasketballResultOverlayState();
}

class _BasketballResultOverlayState extends State<BasketballResultOverlay> {
  static const _maxStage = 3;
  int _stage = 0;
  Timer? _timer;
  bool _showLevelUp = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 750), (timer) {
      if (!mounted) return;
      if (_stage >= _maxStage) {
        timer.cancel();
        return;
      }
      setState(() => _stage += 1);
      playSound(SoundEffect.cardSlam);
      if (_stage >= _maxStage) _maybeLevelUp();
    });
  }

  void _skip() {
    if (_stage >= _maxStage) return;
    _timer?.cancel();
    setState(() => _stage = _maxStage);
    _maybeLevelUp();
  }

  /// After the reveal lands, celebrate any levels this match's XP crossed —
  /// same beat as the Grand Prix result.
  void _maybeLevelUp() {
    if (!mounted) return;
    if (context.read<GameBloc>().state.pendingLevelUps.isNotEmpty) {
      setState(() => _showLevelUp = true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final won = summary.won;
    final accent = won ? Cyber.success : Cyber.danger;
    return GestureDetector(
      onTap: _skip,
      child: ColoredBox(
        color: Cyber.bg.withValues(alpha: 0.97),
        child: Stack(
          children: [
            SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RevealIn(
                      visible: _stage >= 0,
                      child: Column(
                        children: [
                          Text(
                            won ? 'VICTORY' : 'DEFEAT',
                            textAlign: TextAlign.center,
                            style: Cyber.display(
                              32,
                              color: accent,
                              letterSpacing: 4,
                            ).copyWith(
                              shadows: [
                                Shadow(
                                  color: accent.withValues(alpha: 0.55),
                                  blurRadius: 22,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (summary.buzzerBeater || summary.overtime)
                            CyberChip(
                              label: summary.buzzerBeater
                                  ? 'BUZZER BEATER'
                                  : 'OVERTIME',
                              color: Cyber.gold,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _RevealIn(
                      visible: _stage >= 1,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '${summary.playerScore}',
                            style: Cyber.display(40, color: Cyber.cyan)
                                .copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '—',
                              style: Cyber.display(20, color: Cyber.muted),
                            ),
                          ),
                          Text(
                            '${summary.cpuScore}',
                            style: Cyber.display(40, color: Cyber.magenta)
                                .copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 22),
                          _GradePlate(grade: summary.grade),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _RevealIn(
                      visible: _stage >= 2,
                      child: _BoxScoreGrid(box: summary.box),
                    ),
                    const SizedBox(height: 18),
                    _RevealIn(
                      visible: _stage >= 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _XpLine(xp: widget.xp),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              'RECORD ${widget.stats.wins}W — ${widget.stats.losses}L'
                              '${widget.stats.currentStreak > 1 ? ' · ${widget.stats.currentStreak} STRAIGHT' : ''}',
                              style: Cyber.label(
                                9,
                                color: Cyber.muted,
                                letterSpacing: 1.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          HudCtaButton(
                            label: 'REMATCH',
                            icon: Icons.replay,
                            accent: Cyber.gold,
                            tapSound: SoundEffect.playMatch,
                            onTap: widget.onRematch,
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              widget.onExit();
                            },
                            child: Text(
                              'BACK TO COURT LOBBY',
                              style: Cyber.label(
                                10,
                                color: Cyber.muted,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
            if (_showLevelUp)
              LevelUpCelebration(
                levels: context.read<GameBloc>().state.pendingLevelUps,
                progression: context.read<GameBloc>().state.progression,
                xpEarned: context.read<GameBloc>().state.lastMatchXP ?? 0,
                onDismissed: () => setState(() => _showLevelUp = false),
              ),
          ],
        ),
      ),
    );
  }
}

class _RevealIn extends StatelessWidget {
  const _RevealIn({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 340),
      opacity: visible ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
        offset: visible ? Offset.zero : const Offset(0, 0.08),
        child: child,
      ),
    );
  }
}

class _GradePlate extends StatelessWidget {
  const _GradePlate({required this.grade});

  final String grade;

  @override
  Widget build(BuildContext context) {
    final color = switch (grade) {
      'S' => Cyber.gold,
      'A' => Cyber.lime,
      'B' => Cyber.cyan,
      'C' => Cyber.amber,
      _ => Cyber.muted,
    };
    final elite = grade == 'S';
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Cyber.bg.withValues(alpha: 0.6),
        border: Border.all(color: color, width: 1.6),
        boxShadow: elite ? Cyber.glow(color, alpha: 0.5) : null,
      ),
      child: Text(
        grade,
        style: Cyber.display(26, color: color),
      ),
    );
  }
}

class _BoxScoreGrid extends StatelessWidget {
  const _BoxScoreGrid({required this.box});

  final BasketballBoxScore box;

  @override
  Widget build(BuildContext context) {
    final entries = <(String, String)>[
      ('FG', box.attempts == 0 ? '—' : '${box.fgPercent}%'),
      ('PERFECT', '${box.perfectReleases}'),
      ('3PT MADE', '${box.threesMade}'),
      ('DUNKS', '${box.dunks}'),
      ('BLOCKS', '${box.blocks}'),
      ('STEALS', '${box.steals}'),
      ('BOARDS', '${box.rebounds}'),
      ('BEST RUN', '${box.bestRun}'),
    ];
    return CyberPanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        children: [
          for (var row = 0; row < 2; row++) ...[
            if (row > 0) ...[
              const SizedBox(height: 10),
              const HudLine(),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                for (final entry in entries.sublist(row * 4, row * 4 + 4))
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          entry.$2,
                          style: Cyber.display(15).copyWith(
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          entry.$1,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Cyber.muted,
                            fontFamily: Cyber.displayFont,
                            fontSize: 6.8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _XpLine extends StatelessWidget {
  const _XpLine({required this.xp});

  final int xp;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => Text(
          '+${(xp * t).round()} XP',
          style: Cyber.display(22, color: Cyber.gold).copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
            shadows: [
              Shadow(
                color: Cyber.gold.withValues(alpha: 0.5),
                blurRadius: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
