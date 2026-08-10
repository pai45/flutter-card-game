import 'dart:async';

import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/progression.dart';
import '../../../models/quiz_trivia.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/card_unpack_animation.dart';
import '../../../widgets/cyber/cyber_cta_button.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../predictions/widgets/settlement_reveal.dart'
    show SettlementQuestionResult;

/// End-of-run summary for a Knowledge Arena set.
///
/// Every answer was already judged in-play by the SIGNAL LOCK cinematic, so
/// this is a payoff rather than a settlement: the mastery stars stamp in one at
/// a time, the XP total counts up, and the level bar catches up.
///
/// There is no fail state — finishing a set always clears it and always pays
/// XP for what you got right. Stars are the reason to come back.
class QuizRevealOverlay extends StatefulWidget {
  const QuizRevealOverlay({
    required this.mode,
    required this.setNumber,
    required this.results,
    required this.totalXp,
    required this.xpBefore,
    required this.newlyCleared,
    required this.stars,
    required this.starsGained,
    required this.bestBefore,
    required this.bestStreak,
    required this.onRetry,
    required this.onDone,
    super.key,
  });

  final QuizMode mode;
  final int setNumber;
  final List<SettlementQuestionResult> results;
  final int totalXp;
  final int xpBefore;

  /// True when this run completed the set for the first time.
  final bool newlyCleared;

  /// Mastery stars held for this set after the run (0–3).
  final int stars;

  /// Stars added by this run on top of the previous best.
  final int starsGained;

  /// Best correct-answer count before this run, for the NEW BEST chip.
  final int bestBefore;
  final int bestStreak;
  final VoidCallback onRetry;
  final VoidCallback onDone;

  @override
  State<QuizRevealOverlay> createState() => _QuizRevealOverlayState();
}

class _QuizRevealOverlayState extends State<QuizRevealOverlay> {
  int _starsShown = 0;
  int _run = 0;
  bool _started = false;

  Color get _accent => widget.mode.accent;
  int get _correctCount =>
      widget.results.where((result) => result.correct).length;
  bool get _perfect => widget.stars >= 3;
  bool get _newBest => _correctCount > widget.bestBefore;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _starsShown = widget.stars;
      playSound(_perfect ? SoundEffect.quizPerfect : SoundEffect.quizPass);
      return;
    }
    _play();
  }

  Future<void> _play() async {
    final run = ++_run;
    playSound(SoundEffect.whoosh);
    await Future<void>.delayed(const Duration(milliseconds: 420));
    for (var i = 0; i < widget.stars; i++) {
      if (!mounted || run != _run) return;
      playSound(
        i == 2 ? SoundEffect.quizPerfect : SoundEffect.quizCorrect,
      );
      setState(() => _starsShown = i + 1);
      await Future<void>.delayed(const Duration(milliseconds: 260));
    }
    if (!mounted || run != _run) return;
    if (!_perfect) playSound(SoundEffect.quizPass);
    if (widget.newlyCleared) playSound(SoundEffect.quizUnlock);
  }

  @override
  Widget build(BuildContext context) {
    final progressBefore = levelProgress(widget.xpBefore);
    final progressAfter = levelProgress(widget.xpBefore + widget.totalXp);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return ColoredBox(
      color: Cyber.bg.withValues(alpha: 0.98),
      child: SafeArea(
        child: Stack(
          key: const ValueKey('quiz-summary'),
          alignment: Alignment.center,
          children: [
            if (_perfect && !reduceMotion)
              const Positioned.fill(
                child: PackRevealBackground(
                  rarity: 'platinum',
                  pulseOpacity: 0.12,
                ),
              ),
            if (_perfect && !reduceMotion) const Center(child: PackBurst()),
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _RevealIn(
                          child: Text(
                            _perfect ? 'FLAWLESS SET' : 'SET CLEARED',
                            textAlign: TextAlign.center,
                            style:
                                Cyber.display(
                                  25,
                                  color: _perfect ? Cyber.gold : Cyber.success,
                                  letterSpacing: 2.2,
                                ).copyWith(
                                  shadows: reduceMotion
                                      ? null
                                      : [
                                          Shadow(
                                            color:
                                                (_perfect
                                                        ? Cyber.gold
                                                        : Cyber.success)
                                                    .withValues(alpha: 0.55),
                                            blurRadius: 20,
                                          ),
                                        ],
                                ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _RevealIn(
                          delayFactor: 0.2,
                          child: _ScoreLine(
                            correct: _correctCount,
                            total: widget.results.length,
                            bestStreak: widget.bestStreak,
                            newBest: _newBest,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _StarAward(
                          shown: _starsShown,
                          gained: widget.starsGained,
                        ),
                        const SizedBox(height: 24),
                        _RevealIn(
                          delayFactor: 0.35,
                          child: _XpTotal(xp: widget.totalXp),
                        ),
                        if (widget.newlyCleared) ...[
                          const SizedBox(height: 18),
                          _RevealIn(
                            delayFactor: 0.5,
                            child: _ClearBanner(
                              mode: widget.mode,
                              setNumber: widget.setNumber,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        _RevealIn(
                          delayFactor: 0.65,
                          child: _LevelLine(
                            before: progressBefore,
                            after: progressAfter,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _RevealIn(
                          delayFactor: 0.75,
                          child: _AnswerReview(
                            results: widget.results,
                            accent: _accent,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _RevealIn(
                          delayFactor: 0.85,
                          child: HudCtaButton(
                            label: 'CONTINUE TO SETS',
                            icon: Icons.arrow_forward,
                            accent: _accent,
                            onTap: widget.onDone,
                            tapSound: SoundEffect.uiTap,
                          ),
                        ),
                        if (!_perfect) ...[
                          const SizedBox(height: 10),
                          _RevealIn(
                            delayFactor: 0.95,
                            child: HudPagerButton(
                              key: const ValueKey('quiz-replay'),
                              label:
                                  'REPLAY FOR 3 STARS · $kQuizEntryCost COINS',
                              leadingIcon: Icons.replay,
                              focal: false,
                              enabled: true,
                              onTap: widget.onRetry,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Score, best streak and a NEW BEST flag on one tabular line.
class _ScoreLine extends StatelessWidget {
  const _ScoreLine({
    required this.correct,
    required this.total,
    required this.bestStreak,
    required this.newBest,
  });

  final int correct;
  final int total;
  final int bestStreak;
  final bool newBest;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 6,
      children: [
        Text(
          '$correct / $total CORRECT',
          style: Cyber.label(12, color: Cyber.muted, letterSpacing: 1.6)
              .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        if (bestStreak >= 2)
          Text(
            'BEST STREAK ×$bestStreak',
            style:
                Cyber.label(
                  12,
                  color: bestStreak >= 5 ? Cyber.gold : Cyber.amber,
                  letterSpacing: 1.6,
                ).copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
        if (newBest)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Cyber.gold.withValues(alpha: 0.13),
              border: Border.all(color: Cyber.gold.withValues(alpha: 0.6)),
            ),
            child: Text(
              'NEW BEST',
              style: Cyber.label(9, color: Cyber.gold, letterSpacing: 1.3),
            ),
          ),
      ],
    );
  }
}

/// The mastery beat: three chamfered plates, each stamping down as it is
/// awarded. Only earned plates light, and only a full sweep glows.
class _StarAward extends StatelessWidget {
  const _StarAward({required this.shown, required this.gained});

  final int shown;
  final int gained;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              _StarPlate(earned: i < shown, complete: shown >= 3),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          gained > 0
              ? '+$gained ${gained == 1 ? 'STAR' : 'STARS'} EARNED'
              : shown == 0
              ? 'NO STARS YET · REPLAY TO EARN'
              : 'SET RECORD HELD',
          style: Cyber.label(
            9.5,
            color: gained > 0 ? Cyber.gold : Cyber.muted,
            letterSpacing: 1.6,
          ),
        ),
      ],
    );
  }
}

class _StarPlate extends StatelessWidget {
  const _StarPlate({required this.earned, required this.complete});

  final bool earned;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: earned ? 1 : 0),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Transform.scale(
        // Stamps down from oversized onto the plate.
        scale: earned && !reduceMotion ? 1 + 1.1 * (1 - t) : 1,
        child: child,
      ),
      child: ClipPath(
        clipper: const HudChamferClipper(bigCut: 9, smallCut: 3),
        child: Container(
          width: 62,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: earned
                ? Color.alphaBlend(
                    Cyber.gold.withValues(alpha: 0.14),
                    Cyber.panel,
                  )
                : Cyber.panel,
            border: Border.all(
              color: earned
                  ? Cyber.gold.withValues(alpha: 0.75)
                  : Cyber.borderMuted,
            ),
            boxShadow: earned && complete
                ? Cyber.glow(Cyber.gold, alpha: 0.3, blur: 16)
                : null,
          ),
          child: Icon(
            earned ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 30,
            color: earned ? Cyber.gold : Cyber.border,
          ),
        ),
      ),
    );
  }
}

/// Slide-up + fade entrance, staggered by [delayFactor] of its duration.
class _RevealIn extends StatelessWidget {
  const _RevealIn({required this.child, this.delayFactor = 0});

  final Widget child;
  final double delayFactor;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduceMotion
          ? Duration.zero
          : Duration(milliseconds: (420 * (1 + delayFactor)).round()),
      curve: Interval(
        delayFactor / (1 + delayFactor),
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: reduceMotion ? Offset.zero : Offset(0, 14 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _AnswerReview extends StatelessWidget {
  const _AnswerReview({required this.results, required this.accent});

  final List<SettlementQuestionResult> results;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: accent.withValues(alpha: 0.08),
      ),
      child: Material(
        color: Cyber.panel2.withValues(alpha: 0.92),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: accent.withValues(alpha: 0.42)),
        ),
        child: ExpansionTile(
          key: const ValueKey('quiz-answer-review'),
          iconColor: accent,
          collapsedIconColor: accent,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          title: Text(
            'REVIEW RESULTS',
            style: Cyber.display(11, color: accent, letterSpacing: 1.1),
          ),
          subtitle: Text(
            'Selected and correct answers',
            style: Cyber.body(11, color: Cyber.muted),
          ),
          children: [
            for (var i = 0; i < results.length; i++)
              _AnswerReviewRow(index: i + 1, result: results[i]),
          ],
        ),
      ),
    );
  }
}

class _AnswerReviewRow extends StatelessWidget {
  const _AnswerReviewRow({required this.index, required this.result});

  final int index;
  final SettlementQuestionResult result;

  @override
  Widget build(BuildContext context) {
    final color = result.correct ? Cyber.success : Cyber.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Cyber.borderMuted)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            result.correct ? Icons.check_circle : Icons.cancel,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Q$index · ${result.text}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.body(11.5, weight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  result.correct
                      ? 'YOUR ANSWER · ${result.pickedLabel}'
                      : 'YOUR ANSWER · ${result.pickedLabel}  /  CORRECT · ${result.correctLabel}',
                  style: Cyber.body(10.5, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _XpTotal extends StatelessWidget {
  const _XpTotal({required this.xp});

  final int xp;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: xp.toDouble()),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        '+${v.round()} XP',
        textAlign: TextAlign.center,
        style: Cyber.display(40, color: Cyber.gold, letterSpacing: 1.5)
            .copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              shadows: [
                Shadow(
                  color: Cyber.gold.withValues(alpha: 0.55),
                  blurRadius: 26,
                ),
              ],
            ),
      ),
    );
  }
}

/// Capstone naming the set this run just opened.
class _ClearBanner extends StatelessWidget {
  const _ClearBanner({required this.mode, required this.setNumber});

  final QuizMode mode;
  final int setNumber;

  @override
  Widget build(BuildContext context) {
    final accent = mode.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        border: Border.all(color: accent.withValues(alpha: 0.6)),
        boxShadow: Cyber.glow(accent, alpha: 0.28, blur: 14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            setNumber < kQuizSetCount
                ? Icons.lock_open
                : Icons.workspace_premium,
            color: accent,
            size: 16,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              setNumber < kQuizSetCount
                  ? 'SET ${setNumber + 1} UNLOCKED'
                  : '${mode.label} LADDER COMPLETE',
              style: Cyber.display(13, color: accent, letterSpacing: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Level readout + bar filling from the pre-run position to the post-run one.
class _LevelLine extends StatelessWidget {
  const _LevelLine({required this.before, required this.after});

  final LevelProgress before;
  final LevelProgress after;

  @override
  Widget build(BuildContext context) {
    final leveled = after.level > before.level;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LEVEL ${after.level}',
              style: Cyber.label(
                10,
                color: leveled ? Cyber.gold : Cyber.muted,
                letterSpacing: 1.3,
              ),
            ),
            Text(
              '${after.intoLevel} / ${after.levelSpan} XP',
              style: Cyber.label(
                9,
                color: Cyber.muted,
                letterSpacing: 0.8,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
        const SizedBox(height: 7),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: leveled ? 0 : before.pct, end: after.pct),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, pct, _) => CyberProgressBar(
            value: pct,
            accent: leveled ? Cyber.gold : Cyber.cyan,
            height: 8,
            animate: false,
          ),
        ),
      ],
    );
  }
}
