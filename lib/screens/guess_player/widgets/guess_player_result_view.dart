import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../blocs/guess_player/guess_player_cubit.dart';
import '../../../config/theme.dart';
import '../../../models/guess_player.dart';
import '../../../models/progression.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_cta_button.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/level_up_celebration.dart';

String buildGuessPlayerShareText({
  required GuessPlayerDayRecord record,
  required GuessPlayerPuzzle puzzle,
}) {
  final guessCount = record.guessedPlayerIds.length.clamp(0, 6);
  final revealed = record.revealedClueCount.clamp(1, 6);
  final verdict = record.effectiveWon ? '$guessCount/6' : 'X/6';
  final grid = <String>[
    for (var index = 0; index < 6; index++)
      '${index < revealed ? '🟪' : '⬛'}'
          '${index < guessCount ? (record.effectiveWon && index == guessCount - 1 ? '🟩' : '🟥') : '⬛'}',
  ].join('\n');
  return 'PITCH DUEL · ${puzzle.sport.name.toUpperCase()} · ${record.dayKey}\n'
      'GUESS THE PLAYER $verdict\n'
      '$grid\n'
      'SCORE ${record.score} · +${record.xpEarned} XP';
}

class GuessPlayerResultView extends StatefulWidget {
  const GuessPlayerResultView({
    required this.state,
    required this.onHome,
    this.xpBefore,
    super.key,
  });

  final GuessPlayerState state;
  final int? xpBefore;
  final VoidCallback onHome;

  @override
  State<GuessPlayerResultView> createState() => _GuessPlayerResultViewState();
}

class _GuessPlayerResultViewState extends State<GuessPlayerResultView> {
  Timer? _levelTimer;
  bool _showLevelUp = false;
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;
    final before = widget.xpBefore;
    final earned = widget.state.activeRecord?.xpEarned ?? 0;
    if (before == null || earned <= 0) return;
    final crossed = levelFromXp(before + earned) > levelFromXp(before);
    if (!crossed) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _showLevelUp = true;
      return;
    }
    _levelTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showLevelUp = true);
    });
  }

  @override
  void dispose() {
    _levelTimer?.cancel();
    super.dispose();
  }

  Future<void> _share() async {
    final record = widget.state.activeRecord;
    final puzzle = widget.state.puzzle;
    if (record == null || puzzle == null) return;
    playSound(SoundEffect.uiTap);
    await SharePlus.instance.share(
      ShareParams(
        title: 'Pitch Duel · Guess the Player',
        subject: 'Daily Career Intel',
        text: buildGuessPlayerShareText(record: record, puzzle: puzzle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.state.activeRecord;
    final target = widget.state.targetPlayer;
    if (record == null || target == null) {
      return CyberNoDataState(
        icon: Icons.manage_search_rounded,
        title: 'DEBRIEF UNAVAILABLE',
        message: 'This archived player could not be reconstructed.',
        accent: Cyber.danger,
        actionLabel: 'BACK TO HOME',
        onAction: widget.onHome,
      );
    }

    final won = record.effectiveWon;
    final accent = won ? Cyber.success : Cyber.danger;
    final title = switch (record.status) {
      GuessPlayerResultStatus.won => 'IDENTITY CONFIRMED',
      GuessPlayerResultStatus.gaveUp => 'PLAYER DECLASSIFIED',
      GuessPlayerResultStatus.lost => 'SIGNAL LOST',
      GuessPlayerResultStatus.legacy => 'ARCHIVED RESULT',
      GuessPlayerResultStatus.expired => 'INTEL EXPIRED',
      GuessPlayerResultStatus.inProgress => 'SCAN IN PROGRESS',
    };
    final beforeXp = widget.xpBefore;
    final afterXp = beforeXp == null ? null : beforeXp + record.xpEarned;
    final levels = beforeXp == null || afterXp == null
        ? const <int>[]
        : [
            for (
              var level = levelFromXp(beforeXp) + 1;
              level <= levelFromXp(afterXp);
              level++
            )
              level,
          ];

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CyberSlideUpFadeIn(
                      child: CyberPanel(
                        accent: accent,
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            Icon(
                              won
                                  ? Icons.verified_rounded
                                  : Icons.gpp_bad_rounded,
                              color: accent,
                              size: 42,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: Cyber.display(
                                21,
                                color: accent,
                                letterSpacing: 1.7,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              won
                                  ? 'Career signature decoded.'
                                  : record.status ==
                                        GuessPlayerResultStatus.gaveUp
                                  ? 'The remaining intel has been unlocked.'
                                  : 'No attempts remain. Study the debrief and return tomorrow.',
                              textAlign: TextAlign.center,
                              style: Cyber.body(12.5, color: Cyber.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    CyberSlideUpFadeIn(
                      delay: const Duration(milliseconds: 100),
                      child: Center(
                        child: SizedBox(
                          width: 220,
                          child: CyberPlayerCardTile(
                            card: target,
                            selected: false,
                            size: VisualCardSize.md,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      target.name.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: Cyber.display(
                        19,
                        color: AppTheme.textPrimary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ResultMetrics(
                      record: record,
                      animate: widget.xpBefore != null,
                    ),
                    if (record.xpEarned > 0 && afterXp != null) ...[
                      const SizedBox(height: 14),
                      _XpProgress(
                        previousTotalXp: beforeXp!,
                        totalXp: afterXp,
                        animate: widget.xpBefore != null,
                      ),
                    ],
                    if (widget.xpBefore != null) ...[
                      const SizedBox(height: 12),
                      _StreakBeat(
                        won: won,
                        solveStreak: widget.state.archive.solveStreak(
                          widget.state.currentDayKey,
                        ),
                      ),
                    ],
                    if (!record.legacy) ...[
                      const SizedBox(height: 18),
                      _ClueDebrief(state: widget.state),
                    ],
                    if (widget.state.guesses.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _GuessDebrief(state: widget.state),
                    ],
                    if (record.legacy) ...[
                      const SizedBox(height: 12),
                      CyberPanel(
                        accent: Cyber.muted,
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'LEGACY LOG · DETAILED GUESSES AND SCORE WERE NOT STORED IN V1.',
                          textAlign: TextAlign.center,
                          style: Cyber.label(8.5, color: Cyber.muted),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    HudCtaButton(
                      label: 'RETURN TO INTEL HUB',
                      icon: Icons.home_rounded,
                      accent: won ? Cyber.success : Cyber.cyan,
                      tapSound: SoundEffect.uiTap,
                      onTap: widget.onHome,
                    ),
                    const SizedBox(height: 8),
                    Semantics(
                      button: true,
                      label: 'Share spoiler free result',
                      child: InkWell(
                        onTap: _share,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.ios_share_rounded,
                                color: Cyber.magenta,
                                size: 17,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'SHARE SPOILER-FREE RESULT',
                                style: Cyber.label(9, color: Cyber.magenta),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_showLevelUp && levels.isNotEmpty)
          Positioned.fill(
            child: LevelUpCelebration(
              levels: levels,
              progression: PlayerProgression(totalXP: afterXp!),
              xpEarned: record.xpEarned,
              onDismissed: () => setState(() => _showLevelUp = false),
            ),
          ),
      ],
    );
  }
}

class _ResultMetrics extends StatelessWidget {
  const _ResultMetrics({required this.record, required this.animate});

  final GuessPlayerDayRecord record;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final tries = record.guessedPlayerIds.length.clamp(0, 6);
    return Row(
      children: [
        Expanded(
          child: _Metric(
            label: 'SCORE',
            value: '${record.score}',
            tickTo: record.score,
            animate: animate,
            accent: Cyber.gold,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Metric(label: 'TRIES', value: '$tries/6', accent: Cyber.cyan),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Metric(
            label: 'REWARD',
            value: '+${record.xpEarned} XP',
            tickTo: record.xpEarned,
            prefix: '+',
            suffix: ' XP',
            animate: animate,
            accent: record.xpEarned > 0 ? Cyber.success : Cyber.muted,
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.accent,
    this.tickTo,
    this.prefix = '',
    this.suffix = '',
    this.animate = false,
  });

  final String label;
  final String value;
  final Color accent;
  final int? tickTo;
  final String prefix;
  final String suffix;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.border,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      child: Column(
        children: [
          if (animate &&
              tickTo != null &&
              !MediaQuery.disableAnimationsOf(context))
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: tickTo),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, current, _) =>
                  _MetricValue(value: '$prefix$current$suffix', accent: accent),
            )
          else
            _MetricValue(value: value, accent: accent),
          const SizedBox(height: 4),
          Text(label, style: Cyber.label(7.5, color: Cyber.muted)),
        ],
      ),
    );
  }
}

class _MetricValue extends StatelessWidget {
  const _MetricValue({required this.value, required this.accent});

  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      maxLines: 1,
      style: Cyber.display(
        13,
        color: accent,
      ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }
}

class _XpProgress extends StatelessWidget {
  const _XpProgress({
    required this.previousTotalXp,
    required this.totalXp,
    required this.animate,
  });

  final int previousTotalXp;
  final int totalXp;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    if (animate && !MediaQuery.disableAnimationsOf(context)) {
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(
          begin: previousTotalXp.toDouble(),
          end: totalXp.toDouble(),
        ),
        duration: const Duration(milliseconds: 850),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) =>
            _XpProgressPanel(totalXp: value.round()),
      );
    }
    return _XpProgressPanel(totalXp: totalXp);
  }
}

class _XpProgressPanel extends StatelessWidget {
  const _XpProgressPanel({required this.totalXp});

  final int totalXp;

  @override
  Widget build(BuildContext context) {
    final progress = levelProgress(totalXp);
    return CyberPanel(
      accent: Cyber.gold,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'LEVEL ${progress.level}',
                style: Cyber.display(10.5, color: Cyber.gold),
              ),
              const Spacer(),
              Text(
                '${progress.intoLevel}/${progress.levelSpan} XP',
                style: Cyber.label(
                  8.5,
                  color: Cyber.muted,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CyberProgressBar(value: progress.pct, accent: Cyber.gold, height: 8),
        ],
      ),
    );
  }
}

class _StreakBeat extends StatelessWidget {
  const _StreakBeat({required this.won, required this.solveStreak});

  final bool won;
  final int solveStreak;

  @override
  Widget build(BuildContext context) {
    return CyberSlideUpFadeIn(
      delay: const Duration(milliseconds: 250),
      child: CyberPanel(
        accent: Cyber.amber,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.local_fire_department_rounded,
              color: Cyber.amber,
              size: 18,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                won
                    ? 'SOLVE STREAK · $solveStreak ${solveStreak == 1 ? 'DAY' : 'DAYS'}'
                    : 'DAILY GAME STREAK · ACTIVITY RECORDED',
                style: Cyber.label(8.5, color: Cyber.amber),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClueDebrief extends StatelessWidget {
  const _ClueDebrief({required this.state});

  final GuessPlayerState state;

  @override
  Widget build(BuildContext context) {
    final clues = state.puzzle?.clues ?? const <GuessPlayerClue>[];
    return CyberPanel(
      accent: Cyber.magenta,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'FULL CAREER INTEL',
            style: Cyber.display(11, color: Cyber.magenta),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < clues.length; index++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: index == clues.length - 1
                    ? null
                    : const Border(
                        bottom: BorderSide(color: Cyber.borderSubtle),
                      ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${index + 1}',
                      style: Cyber.display(10, color: Cyber.cyan),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      clues[index].label,
                      style: Cyber.label(8, color: Cyber.muted),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      clues[index].value,
                      textAlign: TextAlign.right,
                      style: Cyber.display(9.5, color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GuessDebrief extends StatelessWidget {
  const _GuessDebrief({required this.state});

  final GuessPlayerState state;

  @override
  Widget build(BuildContext context) {
    final targetId = state.targetPlayer?.id;
    return CyberPanel(
      accent: Cyber.border,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'SCAN HISTORY',
            style: Cyber.display(11, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < state.guesses.length; index++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(
                    state.guesses[index].id == targetId
                        ? Icons.check_circle
                        : Icons.cancel,
                    color: state.guesses[index].id == targetId
                        ? Cyber.success
                        : Cyber.danger,
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.guesses[index].name.toUpperCase(),
                      style: Cyber.body(
                        11.5,
                        color: AppTheme.textPrimary,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    'TRY ${index + 1}',
                    style: Cyber.label(8, color: Cyber.muted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
