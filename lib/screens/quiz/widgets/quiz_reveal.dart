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

/// Answer-all-then-settle reveal for a finished Football Quiz run. Mirrors the
/// prediction [SettlementRevealOverlay] beats — header → verdict flips with an
/// XP ticker → summary with a level line — but is framed for the standalone
/// quiz (no fixture) and adds a "MODE CLEARED / UNLOCKED" capstone when a tier
/// is beaten for the first time.
///
/// Reuses the generic [SettlementQuestionResult] data class. Rewards are
/// credited by the caller before this shows, so skipping changes nothing.
class QuizRevealOverlay extends StatefulWidget {
  const QuizRevealOverlay({
    required this.mode,
    required this.setNumber,
    required this.results,
    required this.totalXp,
    required this.xpBefore,
    required this.newlyCleared,
    required this.unlocked,
    required this.passed,
    required this.onRetry,
    required this.onDone,
    super.key,
  });

  final QuizMode mode;
  final int setNumber;
  final List<SettlementQuestionResult> results;
  final int totalXp;
  final int xpBefore;

  /// True when this run cleared [mode] for the first time.
  final bool newlyCleared;

  /// The mode this run just unlocked (gated directly on [mode]), if any.
  final QuizMode? unlocked;
  final bool passed;
  final VoidCallback onRetry;
  final VoidCallback onDone;

  @override
  State<QuizRevealOverlay> createState() => _QuizRevealOverlayState();
}

class _QuizRevealOverlayState extends State<QuizRevealOverlay> {
  /// 0 = header beat, 1..n = that many verdicts stamped, n+1 = summary.
  int _stage = 0;
  int _run = 0;
  bool _started = false;

  Color get _accent => widget.mode.accent;
  int get _summaryStage => widget.results.length + 1;
  bool get _onSummary => _stage >= _summaryStage;

  int get _revealedXp {
    if (_onSummary) return widget.totalXp;
    var sum = 0;
    for (var i = 0; i < _stage - 1 && i < widget.results.length; i++) {
      sum += widget.results[i].earnedXp;
    }
    return sum;
  }

  int get _correctCount =>
      widget.results.where((result) => result.correct).length;
  bool get _perfect =>
      widget.results.isNotEmpty && _correctCount == widget.results.length;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.passed) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _stage = _summaryStage;
      } else {
        _play();
      }
    } else {
      _stage = _summaryStage;
      playSound(SoundEffect.quizFail);
    }
  }

  Future<void> _play() async {
    final run = ++_run;
    playSound(SoundEffect.whoosh);
    await Future<void>.delayed(const Duration(milliseconds: 420));
    for (var i = 0; i < widget.results.length; i++) {
      if (!mounted || run != _run) return;
      playSound(
        widget.results[i].correct
            ? SoundEffect.quizCorrect
            : SoundEffect.quizWrong,
      );
      setState(() => _stage = i + 1);
      await Future<void>.delayed(const Duration(milliseconds: 240));
    }
    if (!mounted || run != _run) return;
    _enterSummary();
  }

  void _enterSummary() {
    _run++;
    playSound(_perfect ? SoundEffect.quizPerfect : SoundEffect.quizPass);
    if (widget.unlocked != null) playSound(SoundEffect.quizUnlock);
    setState(() => _stage = _summaryStage);
  }

  void _skipToSummary() {
    if (_onSummary) return;
    _enterSummary();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return ColoredBox(
      color: Cyber.bg.withValues(alpha: 0.98),
      child: SafeArea(
        child: AnimatedSwitcher(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _onSummary
              ? (widget.passed ? _summary() : _failSummary())
              : _flips(),
        ),
      ),
    );
  }

  // ── Beats 1–2: header + verdict flips ───────────────────────────────────────
  Widget _flips() {
    return Column(
      key: const ValueKey('quiz-flips'),
      children: [
        const SizedBox(height: 26),
        _RevealIn(
          child: Text(
            'RESULTS ARE IN',
            style: Cyber.display(20, color: Colors.white, letterSpacing: 2.4)
                .copyWith(
                  shadows: [
                    Shadow(
                      color: _accent.withValues(alpha: 0.6),
                      blurRadius: 18,
                    ),
                  ],
                ),
          ),
        ),
        const SizedBox(height: 8),
        _RevealIn(
          delayFactor: 0.35,
          child: Text(
            '${widget.mode.label} QUIZ',
            style: Cyber.label(12, color: _accent, letterSpacing: 2.2),
          ),
        ),
        const SizedBox(height: 18),
        _RevealIn(
          delayFactor: 0.6,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'SCORING ${widget.results.length} ANSWERS',
                style: Cyber.label(10, color: Cyber.muted, letterSpacing: 1.4),
              ),
              const SizedBox(width: 12),
              _XpTicker(value: _revealedXp, accent: _accent),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            itemCount: _stage.clamp(0, widget.results.length),
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _VerdictRow(
              index: i + 1,
              result: widget.results[i],
              accent: _accent,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextButton.icon(
            key: const ValueKey('quiz-skip-results'),
            onPressed: _skipToSummary,
            icon: const Icon(Icons.fast_forward, size: 16),
            label: Text(
              'SKIP RESULTS',
              style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.4),
            ),
            style: TextButton.styleFrom(foregroundColor: Cyber.muted),
          ),
        ),
      ],
    );
  }

  // ── Beat 3: summary ─────────────────────────────────────────────────────────
  Widget _summary() {
    final progressBefore = levelProgress(widget.xpBefore);
    final progressAfter = levelProgress(widget.xpBefore + widget.totalXp);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Stack(
      key: const ValueKey('quiz-summary'),
      alignment: Alignment.center,
      children: [
        if (_perfect && !reduceMotion)
          const Positioned.fill(
            child: PackRevealBackground(rarity: 'platinum', pulseOpacity: 0.12),
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
                        _perfect ? 'PERFECT SET' : 'SET CLEARED',
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
                      child: Text(
                        '$_correctCount / ${widget.results.length} CORRECT',
                        textAlign: TextAlign.center,
                        style:
                            Cyber.label(
                              12,
                              color: Cyber.muted,
                              letterSpacing: 1.6,
                            ).copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                      ),
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
                          unlocked: widget.unlocked,
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _failSummary() {
    final wrong = widget.results.length - _correctCount;
    return ListView(
      key: const ValueKey('quiz-failed-summary'),
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RevealIn(
                  child: Text(
                    'SET NOT CLEARED',
                    textAlign: TextAlign.center,
                    style:
                        Cyber.display(
                          24,
                          color: Cyber.danger,
                          letterSpacing: 2.2,
                        ).copyWith(
                          shadows: [
                            Shadow(
                              color: Cyber.danger.withValues(alpha: 0.55),
                              blurRadius: 22,
                            ),
                          ],
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                _RevealIn(
                  delayFactor: 0.2,
                  child: Text(
                    '$_correctCount / ${widget.results.length} CORRECT · $wrong WRONG',
                    textAlign: TextAlign.center,
                    style:
                        Cyber.label(
                          12,
                          color: Cyber.muted,
                          letterSpacing: 1.4,
                        ).copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ),
                const SizedBox(height: 24),
                _RevealIn(
                  delayFactor: 0.35,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Cyber.danger.withValues(alpha: 0.08),
                      border: Border.all(
                        color: Cyber.danger.withValues(alpha: 0.42),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          color: Cyber.danger,
                          size: 24,
                        ),
                        const SizedBox(height: 9),
                        Text(
                          'PASS SCORE · 5 / ${widget.results.length}',
                          style: Cyber.display(12, color: Cyber.danger),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Correct answers stay hidden until this set is cleared.',
                          textAlign: TextAlign.center,
                          style: Cyber.body(13, color: Cyber.muted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                _RevealIn(
                  delayFactor: 0.55,
                  child: HudCtaButton(
                    label: 'RETRY · 25 COINS',
                    icon: Icons.replay,
                    accent: _accent,
                    onTap: widget.onRetry,
                    tapSound: SoundEffect.uiTap,
                  ),
                ),
                const SizedBox(height: 16),
                _RevealIn(
                  delayFactor: 0.75,
                  child: TextButton(
                    onPressed: widget.onDone,
                    style: TextButton.styleFrom(foregroundColor: Cyber.muted),
                    child: Text(
                      'BACK TO SETS',
                      style: Cyber.label(
                        10,
                        color: Cyber.muted,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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

/// Running XP counter shown while verdicts flip; retargets as each correct
/// answer lands.
class _XpTicker extends StatelessWidget {
  const _XpTicker({required this.value, required this.accent});

  final int value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Cyber.violet, accent]),
        boxShadow: Cyber.glow(accent, alpha: 0.4, blur: 10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text(
              '+${v.round()}',
              style: Cyber.display(
                12,
                color: Colors.white,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'xp',
            style: Cyber.label(9, color: Colors.white, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

/// One scored question stamping correct/wrong: row slides in, then the stamp
/// scales down onto it.
class _VerdictRow extends StatelessWidget {
  const _VerdictRow({
    required this.index,
    required this.result,
    required this.accent,
  });

  final int index;
  final SettlementQuestionResult result;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final stampAccent = result.correct ? Cyber.success : Cyber.danger;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        final enter = (t / 0.45).clamp(0.0, 1.0);
        final stamp = ((t - 0.45) / 0.55).clamp(0.0, 1.0);
        final stamped = stamp > 0;
        return Opacity(
          opacity: enter,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - enter)),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
              decoration: BoxDecoration(
                color: stamped
                    ? stampAccent.withValues(alpha: 0.07 * stamp)
                    : const Color(0xff121b2c),
                border: Border.all(
                  color: stamped
                      ? Color.lerp(const Color(0xff2a3550), stampAccent, stamp)!
                      : const Color(0xff2a3550),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      border: Border.all(color: Cyber.border),
                    ),
                    child: Text(
                      'Q$index',
                      style: Cyber.label(9, color: accent),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Cyber.display(
                            11.5,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          result.correct
                              ? result.pickedLabel.toUpperCase()
                              : '${result.pickedLabel} · ANS ${result.correctLabel}'
                                    .toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Cyber.body(
                            11,
                            color: result.correct ? Cyber.success : Cyber.muted,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (result.correct)
                    Transform.scale(
                      scale: stamped ? 1 + 0.8 * (1 - stamp) : 0,
                      child: _XpStamp(earned: result.earnedXp, accent: accent),
                    ),
                  const SizedBox(width: 8),
                  Transform.scale(
                    scale: stamped ? 1 + 1.1 * (1 - stamp) : 0,
                    child: Opacity(
                      opacity: stamp,
                      child: Icon(
                        result.correct ? Icons.check_circle : Icons.cancel,
                        color: stampAccent,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _XpStamp extends StatelessWidget {
  const _XpStamp({required this.earned, required this.accent});

  final int earned;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent.withValues(alpha: 0.7)),
      ),
      child: Text(
        '+$earned XP',
        style: Cyber.display(
          10,
          color: accent,
        ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
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

/// "MODE CLEARED" capstone, naming the tier this run just opened (if any).
class _ClearBanner extends StatelessWidget {
  const _ClearBanner({
    required this.mode,
    required this.setNumber,
    required this.unlocked,
  });

  final QuizMode mode;
  final int setNumber;
  final QuizMode? unlocked;

  @override
  Widget build(BuildContext context) {
    final unlocked = this.unlocked;
    final accent = mode.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        border: Border.all(color: accent.withValues(alpha: 0.6)),
        boxShadow: Cyber.glow(accent, alpha: 0.28, blur: 14),
      ),
      child: Column(
        children: [
          Row(
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
              Text(
                setNumber < kQuizSetCount
                    ? 'SET ${setNumber + 1} UNLOCKED'
                    : '${mode.label} LADDER COMPLETE',
                style: Cyber.display(13, color: accent, letterSpacing: 1.6),
              ),
            ],
          ),
          if (unlocked != null) ...[
            const SizedBox(height: 6),
            Text(
              '${unlocked.label} MODE UNLOCKED',
              style: Cyber.label(
                10,
                color: unlocked.accent,
                letterSpacing: 1.6,
              ),
            ),
          ],
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
