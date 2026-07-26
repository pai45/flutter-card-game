import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/prediction.dart';
import '../../../models/progression.dart';
import '../../../models/sport_match.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/card_unpack_animation.dart';
import '../../../widgets/cyber/cyber_cta_button.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../shop/widgets/shop_card.dart' show CoinIcon;

/// One scored quiz question, precomputed by the caller so the reveal stays
/// presentation-only.
class SettlementQuestionResult {
  const SettlementQuestionResult({
    required this.text,
    required this.pickedLabel,
    required this.correctLabel,
    required this.correct,
    required this.earnedXp,
    this.multiplier,
  });

  final String text;
  final String pickedLabel;
  final String correctLabel;
  final bool correct;

  /// XP this question paid out (0 when wrong; boosted when a multiplier hit).
  final int earnedXp;
  final PredictionMultiplier? multiplier;
}

class PredictionQuestionAnalytics {
  const PredictionQuestionAnalytics({
    required this.index,
    required this.question,
    required this.actualAnswer,
    required this.correctVotes,
    required this.totalVotes,
  });

  final int index;
  final String question;
  final String actualAnswer;
  final int correctVotes;
  final int totalVotes;

  double? get correctVoteShare =>
      totalVotes == 0 ? null : correctVotes / totalVotes;
}

/// Immutable, already-computed match intelligence consumed by the settlement
/// reveal. Keeping the arithmetic out of the animation makes every beat
/// deterministic and straightforward to test.
class PredictionSettlementAnalytics {
  const PredictionSettlementAnalytics({
    required this.playerCorrect,
    required this.totalQuestions,
    required this.playerRank,
    required this.rivalCount,
    required this.beatenShare,
    required this.scoreDistribution,
    required this.crowdCorrectVotes,
    required this.crowdTotalVotes,
    required this.questions,
  });

  final int playerCorrect;
  final int totalQuestions;
  final int playerRank;
  final int rivalCount;
  final double? beatenShare;
  final Map<int, int> scoreDistribution;
  final int crowdCorrectVotes;
  final int crowdTotalVotes;
  final List<PredictionQuestionAnalytics> questions;

  int get fieldSize => rivalCount + 1;
  double get playerAccuracy =>
      totalQuestions == 0 ? 0 : playerCorrect / totalQuestions;
  double? get crowdAccuracy =>
      crowdTotalVotes == 0 ? null : crowdCorrectVotes / crowdTotalVotes;
}

/// Full-screen settlement cinematic for a finished prediction, mirroring the
/// quiz's staged reveal language:
///   1. header beat — RESULTS ARE IN + fixture recap;
///   2. verdict flips — questions stamp correct/wrong one by one while the
///      XP counter ticks up (boosted hits get the gold sting);
///   3. summary beat — total XP count-up, crowd comparison, level progress,
///      PERFECT QUIZ burst when everything hit;
///   4. level-up moment when the credited XP crossed a level.
///
/// Tapping during the flips skips straight to the summary; rewards are
/// identical either way (the caller credits XP before showing this).
class SettlementRevealOverlay extends StatefulWidget {
  const SettlementRevealOverlay({
    required this.match,
    required this.results,
    required this.totalXp,
    required this.xpBefore,
    required this.analytics,
    required this.onDone,
    this.contestRank = 0,
    this.contestPrizeOz = 0,
    this.contestField = 0,
    super.key,
  });

  final SportMatch match;
  final List<SettlementQuestionResult> results;
  final int totalXp;
  final int xpBefore;

  final PredictionSettlementAnalytics analytics;
  final VoidCallback onDone;

  /// Paid-contest result. [contestRank] 0 = not a contest (beat hidden);
  /// [contestPrizeOz] > 0 means the player finished on the podium.
  final int contestRank;
  final int contestPrizeOz;
  final int contestField;

  bool get isContest => contestRank > 0;

  @override
  State<SettlementRevealOverlay> createState() =>
      _SettlementRevealOverlayState();
}

class _SettlementRevealOverlayState extends State<SettlementRevealOverlay> {
  /// 0 = header beat, 1..n = that many verdicts stamped, n+1 = summary.
  int _stage = 0;
  int _run = 0;
  bool _showAnalytics = false;

  int get _summaryStage => widget.results.length + 1;
  bool get _onSummary => _stage >= _summaryStage;

  int get _revealedXp {
    var sum = 0;
    for (var i = 0; i < _stage - 1 && i < widget.results.length; i++) {
      sum += widget.results[i].earnedXp;
    }
    return _onSummary ? widget.totalXp : sum;
  }

  int get _correctCount =>
      widget.results.where((result) => result.correct).length;
  bool get _perfect =>
      widget.results.isNotEmpty && _correctCount == widget.results.length;

  @override
  void initState() {
    super.initState();
    _play();
  }

  Future<void> _play() async {
    final run = ++_run;
    playSound(SoundEffect.whoosh);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    for (var i = 0; i < widget.results.length; i++) {
      if (!mounted || run != _run) return;
      final result = widget.results[i];
      playSound(
        result.correct
            ? result.multiplier != null
                  ? SoundEffect.rarityGold
                  : SoundEffect.cardReveal
            : SoundEffect.cardSlam,
      );
      setState(() => _stage = i + 1);
      await Future<void>.delayed(const Duration(milliseconds: 820));
    }
    if (!mounted || run != _run) return;
    _enterSummary();
  }

  void _enterSummary() {
    _run++;
    playSound(
      widget.contestPrizeOz > 0
          ? SoundEffect.rarityGold
          : _perfect
          ? SoundEffect.rarityPlatinum
          : SoundEffect.matchWin,
    );
    setState(() => _stage = _summaryStage);
  }

  void _skipToSummary() {
    if (_onSummary) return;
    _enterSummary();
  }

  void _continue() {
    if (_showAnalytics) {
      widget.onDone();
      return;
    }
    playSound(SoundEffect.uiTap);
    setState(() => _showAnalytics = true);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _skipToSummary,
      child: ColoredBox(
        color: Cyber.bg.withValues(alpha: 0.97),
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _showAnalytics
                ? _analytics()
                : _onSummary
                ? _summary()
                : _flips(),
          ),
        ),
      ),
    );
  }

  // ── Beats 1–2: header + verdict flips ───────────────────────────────────────
  Widget _flips() {
    return Column(
      key: const ValueKey('settlement-flips'),
      children: [
        const SizedBox(height: 26),
        _RevealIn(
          child: Text(
            'RESULTS ARE IN',
            style: Cyber.display(20, color: Colors.white, letterSpacing: 2.4)
                .copyWith(
                  shadows: [
                    Shadow(
                      color: Cyber.cyan.withValues(alpha: 0.6),
                      blurRadius: 18,
                    ),
                  ],
                ),
          ),
        ),
        const SizedBox(height: 10),
        _RevealIn(delayFactor: 0.35, child: _FixtureRecap(match: widget.match)),
        const SizedBox(height: 18),
        _RevealIn(
          delayFactor: 0.6,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'SETTLING ${widget.results.length} FUTURES',
                style: Cyber.label(10, color: Cyber.muted, letterSpacing: 1.4),
              ),
              const SizedBox(width: 12),
              _XpTicker(value: _revealedXp),
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
            itemBuilder: (context, i) =>
                _VerdictRow(index: i + 1, result: widget.results[i]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Text(
            'TAP TO SKIP',
            style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.4),
          ),
        ),
      ],
    );
  }

  // ── Beat 3: summary ─────────────────────────────────────────────────────────
  Widget _summary() {
    final progressBefore = levelProgress(widget.xpBefore);
    final progressAfter = levelProgress(widget.xpBefore + widget.totalXp);
    final beaten = widget.analytics.beatenShare;
    return Stack(
      key: const ValueKey('settlement-summary'),
      alignment: Alignment.center,
      children: [
        if (_perfect)
          const Positioned.fill(
            child: PackRevealBackground(rarity: 'platinum', pulseOpacity: 0.12),
          ),
        if (_perfect) const Center(child: PackBurst()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RevealIn(
                child: Text(
                  _perfect ? 'PERFECT QUIZ' : 'PREDICTION SETTLED',
                  textAlign: TextAlign.center,
                  style:
                      Cyber.display(
                        24,
                        color: _perfect ? Cyber.gold : Colors.white,
                        letterSpacing: 2.2,
                      ).copyWith(
                        shadows: [
                          Shadow(
                            color: (_perfect ? Cyber.gold : Cyber.cyan)
                                .withValues(alpha: 0.65),
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
                  '$_correctCount / ${widget.results.length} CORRECT',
                  textAlign: TextAlign.center,
                  style: Cyber.label(12, color: Cyber.muted, letterSpacing: 1.6)
                      .copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ),
              const SizedBox(height: 26),
              _RevealIn(delayFactor: 0.35, child: _XpTotal(xp: widget.totalXp)),
              if (widget.isContest) ...[
                const SizedBox(height: 20),
                _RevealIn(
                  delayFactor: 0.45,
                  child: _ContestPrizeBeat(
                    rank: widget.contestRank,
                    field: widget.contestField,
                    prizeOz: widget.contestPrizeOz,
                  ),
                ),
              ],
              if (beaten != null) ...[
                const SizedBox(height: 18),
                _RevealIn(
                  delayFactor: 0.55,
                  child: Text(
                    'YOU BEAT ${(beaten * 100).round()}% OF PREDICTORS',
                    textAlign: TextAlign.center,
                    style:
                        Cyber.label(
                          11,
                          color: Cyber.cyan,
                          letterSpacing: 1.3,
                        ).copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ),
              ],
              const SizedBox(height: 30),
              _RevealIn(
                delayFactor: 0.7,
                child: _LevelLine(before: progressBefore, after: progressAfter),
              ),
              const SizedBox(height: 34),
              _RevealIn(
                delayFactor: 0.85,
                child: HudCtaButton(
                  label: 'CONTINUE',
                  icon: Icons.arrow_forward,
                  onTap: _continue,
                  tapSound: SoundEffect.uiTap,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _analytics() => _MatchIntelPage(
    key: const ValueKey('settlement-match-intel'),
    match: widget.match,
    analytics: widget.analytics,
    onDone: _continue,
  );
}

class _MatchIntelPage extends StatelessWidget {
  const _MatchIntelPage({
    required this.match,
    required this.analytics,
    required this.onDone,
    super.key,
  });

  final SportMatch match;
  final PredictionSettlementAnalytics analytics;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final beaten = analytics.beatenShare;
    return Stack(
      fit: StackFit.expand,
      children: [
        const IgnorePointer(child: CyberTextureOverlay()),
        Column(
          children: [
            const SizedBox(height: 20),
            Text(
              'MATCH INTEL // FINAL',
              textAlign: TextAlign.center,
              style: Cyber.display(20, color: Colors.white, letterSpacing: 2.2),
            ),
            const SizedBox(height: 8),
            _FixtureRecap(match: match),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _IntelMetric(
                          label: 'YOUR SCORE',
                          value:
                              '${analytics.playerCorrect}/${analytics.totalQuestions}',
                          accent: Cyber.cyan,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _IntelMetric(
                          label: 'FIELD RANK',
                          value: analytics.rivalCount == 0
                              ? '—'
                              : '#${analytics.playerRank}/${analytics.fieldSize}',
                          accent: Cyber.success,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _IntelMetric(
                          label: 'PERCENTILE',
                          value: beaten == null
                              ? '—'
                              : 'TOP ${(100 - beaten * 100).clamp(1, 100).round()}%',
                          accent: Cyber.violet,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _FieldDistributionPanel(analytics: analytics),
                  const SizedBox(height: 12),
                  _AccuracyComparisonPanel(analytics: analytics),
                  const SizedBox(height: 12),
                  _RealityAlignmentPanel(analytics: analytics),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: HudCtaButton(
                label: 'DONE',
                icon: Icons.check,
                onTap: onDone,
                tapSound: SoundEffect.uiTap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _IntelMetric extends StatelessWidget {
  const _IntelMetric({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: accent,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: Cyber.display(
              14,
              color: accent,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: Cyber.label(7.5, color: Cyber.muted, letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }
}

class _FieldDistributionPanel extends StatelessWidget {
  const _FieldDistributionPanel({required this.analytics});

  final PredictionSettlementAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.cyan,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'YOU VS FIELD',
            style: Cyber.label(10, color: Cyber.cyan, letterSpacing: 1.6),
          ),
          const SizedBox(height: 4),
          Text(
            'SCORE DISTRIBUTION // CORRECT PICKS',
            style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1),
          ),
          const SizedBox(height: 14),
          if (analytics.rivalCount == 0)
            const _IntelEmpty(message: 'NO FIELD DATA FOR THIS MATCH')
          else
            _ScoreDistributionChart(analytics: analytics),
        ],
      ),
    );
  }
}

class _ScoreDistributionChart extends StatelessWidget {
  const _ScoreDistributionChart({required this.analytics});

  final PredictionSettlementAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final maxCount = analytics.scoreDistribution.values.fold<int>(
      1,
      (highest, count) => max(highest, count),
    );
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var score = 0; score <= analytics.totalQuestions; score++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _DistributionColumn(
                  score: score,
                  count: analytics.scoreDistribution[score] ?? 0,
                  maxCount: maxCount,
                  playerBin: score == analytics.playerCorrect,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DistributionColumn extends StatelessWidget {
  const _DistributionColumn({
    required this.score,
    required this.count,
    required this.maxCount,
    required this.playerBin,
  });

  final int score;
  final int count;
  final int maxCount;
  final bool playerBin;

  @override
  Widget build(BuildContext context) {
    final accent = playerBin ? Cyber.cyan : Cyber.line;
    final heightFactor = count == 0
        ? 0.03
        : (count / maxCount).clamp(0.08, 1.0);
    return Column(
      children: [
        SizedBox(
          height: 20,
          child: playerBin
              ? Text(
                  'YOU',
                  style: Cyber.label(
                    7.5,
                    color: Cyber.cyan,
                    letterSpacing: 0.8,
                  ),
                )
              : Text(
                  '$count',
                  style: Cyber.label(
                    7.5,
                    color: Cyber.muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: heightFactor,
              widthFactor: 0.65,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: playerBin ? 0.92 : 0.5),
                  border: Border.all(color: accent),
                  boxShadow: playerBin
                      ? Cyber.glow(Cyber.cyan, alpha: 0.35, blur: 10)
                      : null,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$score',
          style: Cyber.display(
            9,
            color: accent,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ],
    );
  }
}

class _AccuracyComparisonPanel extends StatelessWidget {
  const _AccuracyComparisonPanel({required this.analytics});

  final PredictionSettlementAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.violet,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ACCURACY DUEL',
            style: Cyber.label(10, color: Cyber.violet, letterSpacing: 1.6),
          ),
          const SizedBox(height: 14),
          _AccuracyBar(
            label: 'YOU',
            value: analytics.playerAccuracy,
            accent: Cyber.cyan,
          ),
          const SizedBox(height: 12),
          if (analytics.crowdAccuracy case final crowd?)
            _AccuracyBar(label: 'CROWD', value: crowd, accent: Cyber.violet)
          else
            const _IntelEmpty(message: 'NO CROWD VOTES RECORDED'),
        ],
      ),
    );
  }
}

class _AccuracyBar extends StatelessWidget {
  const _AccuracyBar({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final double value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(label, style: Cyber.label(9, color: accent, letterSpacing: 1)),
            const Spacer(),
            Text(
              '${(value * 100).round()}%',
              style: Cyber.display(
                11,
                color: accent,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
        const SizedBox(height: 6),
        CyberProgressBar(value: value, accent: accent, height: 8),
      ],
    );
  }
}

class _RealityAlignmentPanel extends StatelessWidget {
  const _RealityAlignmentPanel({required this.analytics});

  final PredictionSettlementAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final crowdAccuracy = analytics.crowdAccuracy;
    return CyberPanel(
      accent: Cyber.success,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'CROWD VS REALITY',
                  style: Cyber.label(
                    10,
                    color: Cyber.success,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              if (crowdAccuracy != null)
                Text(
                  '${(crowdAccuracy * 100).round()}% OVERALL',
                  style: Cyber.label(
                    8.5,
                    color: Cyber.success,
                    letterSpacing: 0.8,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (analytics.questions.isEmpty)
            const _IntelEmpty(message: 'NO SETTLED CROWD SIGNAL')
          else
            for (final question in analytics.questions) ...[
              _RealityQuestionBar(question: question),
              if (question != analytics.questions.last)
                const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _RealityQuestionBar extends StatelessWidget {
  const _RealityQuestionBar({required this.question});

  final PredictionQuestionAnalytics question;

  @override
  Widget build(BuildContext context) {
    final share = question.correctVoteShare;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Q${question.index}',
              style: Cyber.label(9, color: Cyber.success, letterSpacing: 0.8),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'REAL: ${question.actualAnswer.toUpperCase()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Cyber.body(10.5, color: Cyber.muted),
              ),
            ),
            Text(
              share == null ? 'NO VOTES' : '${(share * 100).round()}%',
              style: Cyber.display(
                10,
                color: share == null ? Cyber.muted : Cyber.success,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
        const SizedBox(height: 6),
        CyberProgressBar(
          value: share ?? 0,
          accent: share == null ? Cyber.muted : Cyber.success,
          height: 7,
        ),
        const SizedBox(height: 4),
        Text(
          share == null
              ? 'NO AUDIENCE SAMPLE'
              : '${question.correctVotes} OF ${question.totalVotes} VOTES MATCHED REALITY',
          style: Cyber.label(
            7.5,
            color: Cyber.muted,
            letterSpacing: 0.7,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _IntelEmpty extends StatelessWidget {
  const _IntelEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1),
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
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: (420 * (1 + delayFactor)).round()),
      curve: Interval(
        delayFactor / (1 + delayFactor),
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _FixtureRecap extends StatelessWidget {
  const _FixtureRecap({required this.match});

  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final score = match.hasScore
        ? '${match.homeScore ?? '-'}  ·  ${match.awayScore ?? '-'}'
        : 'FULL TIME';
    return Column(
      children: [
        Text(
          '${match.home.shortName}  vs  ${match.away.shortName}',
          style: Cyber.body(14, color: Colors.white, weight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          score,
          style: Cyber.display(
            13,
            color: Cyber.gold,
            letterSpacing: 1.2,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ],
    );
  }
}

/// Running XP counter shown while verdicts flip; retargets smoothly as each
/// correct answer lands.
class _XpTicker extends StatelessWidget {
  const _XpTicker({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Cyber.violet, Cyber.cyan]),
        boxShadow: Cyber.glow(Cyber.violet, alpha: 0.4, blur: 10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 420),
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

/// One settled question stamping its verdict: the row slides in, then the
/// correct/wrong stamp scales down onto it.
class _VerdictRow extends StatelessWidget {
  const _VerdictRow({required this.index, required this.result});

  final int index;
  final SettlementQuestionResult result;

  @override
  Widget build(BuildContext context) {
    final accent = result.correct ? Cyber.success : Cyber.danger;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 640),
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
                    ? accent.withValues(alpha: 0.07 * stamp)
                    : const Color(0xff121b2c),
                border: Border.all(
                  color: stamped
                      ? Color.lerp(const Color(0xff2a3550), accent, stamp)!
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
                      color: Cyber.cyan.withValues(alpha: 0.14),
                      border: Border.all(color: Cyber.border),
                    ),
                    child: Text(
                      'Q$index',
                      style: Cyber.label(9, color: Cyber.cyan),
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
                      child: _XpStamp(
                        earned: result.earnedXp,
                        multiplier: result.multiplier,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Transform.scale(
                    scale: stamped ? 1 + 1.1 * (1 - stamp) : 0,
                    child: Opacity(
                      opacity: stamp,
                      child: Icon(
                        result.correct ? Icons.check_circle : Icons.cancel,
                        color: accent,
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
  const _XpStamp({required this.earned, required this.multiplier});

  final int earned;
  final PredictionMultiplier? multiplier;

  @override
  Widget build(BuildContext context) {
    final boosted = multiplier != null;
    final accent = boosted ? Cyber.gold : Cyber.cyan;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent.withValues(alpha: 0.7)),
      ),
      child: Text(
        boosted ? '+$earned XP ${multiplier!.label}' : '+$earned XP',
        style: Cyber.display(
          10,
          color: accent,
        ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
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
      duration: const Duration(milliseconds: 900),
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

/// Paid-contest payoff beat: finishing place in the field, and the Oz coins
/// won. On the podium this is a gold "moment" (glow allowed); off it, a calm
/// muted readout so the glow rule keeps its meaning.
class _ContestPrizeBeat extends StatelessWidget {
  const _ContestPrizeBeat({
    required this.rank,
    required this.field,
    required this.prizeOz,
  });

  final int rank;
  final int field;
  final int prizeOz;

  String get _ordinal {
    if (rank >= 11 && rank <= 13) return '${rank}TH';
    return switch (rank % 10) {
      1 => '${rank}ST',
      2 => '${rank}ND',
      3 => '${rank}RD',
      _ => '${rank}TH',
    };
  }

  @override
  Widget build(BuildContext context) {
    final won = prizeOz > 0;
    final accent = won ? Cyber.gold : Cyber.muted;
    final fieldLabel = field > 0 ? ' OF $field' : '';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 15),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: won ? 0.10 : 0.06),
        border: Border.all(color: accent.withValues(alpha: won ? 0.6 : 0.3)),
        boxShadow: won ? Cyber.glow(Cyber.gold, alpha: 0.22, blur: 16) : null,
      ),
      child: Column(
        children: [
          Text(
            won
                ? 'CONTEST · $_ordinal PLACE$fieldLabel'
                : 'FINISHED $_ordinal$fieldLabel',
            textAlign: TextAlign.center,
            style: Cyber.label(
              10,
              color: accent,
              letterSpacing: 1.6,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 8),
          if (won)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CoinIcon(size: 26),
                const SizedBox(width: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: prizeOz.toDouble()),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Text(
                    '+${v.round()}',
                    style:
                        Cyber.display(
                          30,
                          color: Cyber.gold,
                          letterSpacing: 1,
                        ).copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                          shadows: [
                            Shadow(
                              color: Cyber.gold.withValues(alpha: 0.5),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'OZ',
                    style: Cyber.label(11, color: Cyber.gold, letterSpacing: 1),
                  ),
                ),
              ],
            )
          else
            Text(
              'TOP 3 WIN COINS · NO PRIZE',
              textAlign: TextAlign.center,
              style: Cyber.label(10, color: Cyber.muted, letterSpacing: 1.2),
            ),
        ],
      ),
    );
  }
}

/// Level readout + progress bar filling from the pre-settlement position to
/// the post-settlement one.
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
          duration: const Duration(milliseconds: 900),
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
