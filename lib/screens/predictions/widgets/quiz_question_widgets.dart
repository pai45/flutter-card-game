import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/prediction.dart';
import '../../../models/sport_match.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import 'prediction_helpers.dart';
import 'score_prediction_picker.dart';

/// Opacity used for the per-question background image behind a panel. Exposed
/// so the answer screen can match the same wash on the screen-wide backdrop.
const double quizPanelBackgroundOpacity = 0.5;

// ── Question panel backdrop + frame ───────────────────────────────────────────
class _QuizQuestionPanelFrame extends StatelessWidget {
  const _QuizQuestionPanelFrame({
    required this.backgroundAsset,
    required this.margin,
    required this.padding,
    required this.child,
  });

  final String? backgroundAsset;
  final EdgeInsets margin;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hasBackground = backgroundAsset != null;

    return Container(
      width: double.infinity,
      margin: margin,
      decoration: BoxDecoration(
        color: hasBackground
            ? panelBottom.withValues(alpha: quizSurfaceOpacity)
            : null,
        gradient: hasBackground
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [panelTop, panelBottom],
              ),
        border: Border.all(color: panelBorder),
      ),
      clipBehavior: Clip.hardEdge,
      child: Padding(padding: padding, child: child),
    );
  }
}

class QuestionPanel extends StatelessWidget {
  const QuestionPanel({
    required this.index,
    required this.question,
    required this.selected,
    required this.settled,
    required this.enabled,
    required this.selectedMultiplier,
    required this.multiplierOwners,
    required this.multiplierEnabled,
    required this.questionProgress,
    required this.optionsProgress,
    required this.onSelect,
    required this.onMultiplierTap,
    super.key,
  });

  final int index;
  final QuizQuestion question;
  final int? selected;
  final bool settled;
  final bool enabled;
  final PredictionMultiplier? selectedMultiplier;
  final Map<PredictionMultiplier, String> multiplierOwners;
  final bool multiplierEnabled;
  final double questionProgress;
  final double optionsProgress;
  final ValueChanged<int> onSelect;
  final ValueChanged<PredictionMultiplier> onMultiplierTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _QuizQuestionPanelFrame(
          backgroundAsset: question.backgroundAsset,
          margin: const EdgeInsets.only(top: 42),
          padding: const EdgeInsets.fromLTRB(18, 28, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _WordRevealText(
                      text: question.text,
                      progress: questionProgress,
                      style: Cyber.display(
                        16,
                        letterSpacing: 0.3,
                      ).copyWith(height: 1.25),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < question.options.length; i++)
                _StaggeredReveal(
                  progress: _itemProgress(
                    optionsProgress,
                    i,
                    question.options.length,
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: i == question.options.length - 1 ? 0 : 10,
                    ),
                    child: IgnorePointer(
                      ignoring: !enabled,
                      child: _OptionTile(
                        tileKey: ValueKey('quiz-option-${question.id}-$i'),
                        letter: String.fromCharCode(65 + i),
                        label: question.options[i],
                        state: _optionState(i),
                        onTap: () => onSelect(i),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BoostSelector(
                questionId: question.id,
                selected: selectedMultiplier,
                owners: multiplierOwners,
                enabled: multiplierEnabled,
                onTap: onMultiplierTap,
                showLabel: false,
              ),
              const SizedBox(width: 4),
              XpPill(
                reward:
                    selectedMultiplier?.applyTo(question.reward) ??
                    question.reward,
                multiplier: selectedMultiplier,
              ),
            ],
          ),
        ),
        // The numbered tab, dipping over the panel's top-left edge.
        Positioned(
          left: 14,
          top: 30,
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Cyber.cyan.withValues(alpha: 0.16),
              border: Border.all(color: Cyber.border),
            ),
            child: Text('$index', style: Cyber.display(15, color: Cyber.cyan)),
          ),
        ),
      ],
    );
  }

  OptionVisual _optionState(int i) {
    if (settled) {
      if (i == question.settledOptionIndex) return OptionVisual.correct;
      if (i == selected) return OptionVisual.wrong;
      return OptionVisual.idle;
    }
    return i == selected ? OptionVisual.selected : OptionVisual.idle;
  }
}

// ── Score prediction question (Q1 on football fixtures) ───────────────────────
class _WordRevealText extends StatelessWidget {
  const _WordRevealText({
    required this.text,
    required this.progress,
    required this.style,
  });

  final String text;
  final double progress;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final words = text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return const SizedBox.shrink();

    return Semantics(
      label: text,
      child: Wrap(
        spacing: 5,
        runSpacing: 2,
        children: [
          for (var i = 0; i < words.length; i++)
            _StaggeredReveal(
              progress: _itemProgress(progress, i, words.length),
              child: Text(words[i], style: style),
            ),
        ],
      ),
    );
  }
}

class _StaggeredReveal extends StatelessWidget {
  const _StaggeredReveal({required this.progress, required this.child});

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 10 * (1 - t)), child: child),
    );
  }
}

double _itemProgress(double progress, int index, int total) {
  if (total <= 1) return progress.clamp(0.0, 1.0);
  final step = 1 / total;
  return ((progress - step * index) / step).clamp(0.0, 1.0);
}

class ScoreQuestionPanel extends StatelessWidget {
  const ScoreQuestionPanel({
    super.key,
    required this.index,
    required this.question,
    required this.match,
    required this.homeScore,
    required this.awayScore,
    required this.settled,
    required this.editable,
    required this.selectedMultiplier,
    required this.multiplierOwners,
    required this.multiplierEnabled,
    required this.questionProgress,
    required this.controlProgress,
    required this.onHomeChanged,
    required this.onAwayChanged,
    required this.onMultiplierTap,
  });

  final int index;
  final QuizQuestion question;
  final SportMatch match;
  final int homeScore;
  final int awayScore;
  final bool settled;
  final bool editable;
  final PredictionMultiplier? selectedMultiplier;
  final Map<PredictionMultiplier, String> multiplierOwners;
  final bool multiplierEnabled;
  final double questionProgress;
  final double controlProgress;
  final ValueChanged<int> onHomeChanged;
  final ValueChanged<int> onAwayChanged;
  final ValueChanged<PredictionMultiplier> onMultiplierTap;

  bool get _correct =>
      settled &&
      question.settledHomeScore == homeScore &&
      question.settledAwayScore == awayScore;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _QuizQuestionPanelFrame(
            backgroundAsset: question.backgroundAsset,
            margin: const EdgeInsets.only(top: 42),
            padding: const EdgeInsets.fromLTRB(18, 30, 18, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _WordRevealText(
                        text: question.text,
                        progress: questionProgress,
                        style: Cyber.display(
                          16,
                          letterSpacing: 0.3,
                        ).copyWith(height: 1.25),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _StaggeredReveal(
                  progress: controlProgress,
                  child: ScorePredictionPicker(
                    match: match,
                    homeScore: homeScore,
                    awayScore: awayScore,
                    enabled: editable,
                    settled: settled,
                    correctHome: question.settledHomeScore,
                    correctAway: question.settledAwayScore,
                    onHomeChanged: onHomeChanged,
                    onAwayChanged: onAwayChanged,
                  ),
                ),
                if (settled) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        _correct ? Icons.check_circle : Icons.cancel,
                        size: 16,
                        color: _correct ? Cyber.success : Cyber.danger,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _correct
                            ? 'EXACT SCORE — CORRECT'
                            : 'ACTUAL: ${question.settledHomeScore}–${question.settledAwayScore}',
                        style: Cyber.label(
                          11,
                          color: _correct ? Cyber.success : Cyber.danger,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BoostSelector(
                  questionId: question.id,
                  selected: selectedMultiplier,
                  owners: multiplierOwners,
                  enabled: multiplierEnabled,
                  onTap: onMultiplierTap,
                  showLabel: false,
                ),
                const SizedBox(width: 4),
                XpPill(
                  reward:
                      selectedMultiplier?.applyTo(question.reward) ??
                      question.reward,
                  multiplier: selectedMultiplier,
                ),
              ],
            ),
          ),
          Positioned(
            left: 14,
            top: 30,
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Cyber.cyan.withValues(alpha: 0.16),
                border: Border.all(color: Cyber.border),
              ),
              child: Text(
                '$index',
                style: Cyber.display(15, color: Cyber.cyan),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BoostSelector extends StatelessWidget {
  const BoostSelector({
    required this.questionId,
    required this.selected,
    required this.owners,
    required this.enabled,
    required this.onTap,
    this.showLabel = true,
    super.key,
  });

  final String questionId;
  final PredictionMultiplier? selected;
  final Map<PredictionMultiplier, String> owners;
  final bool enabled;
  final ValueChanged<PredictionMultiplier> onTap;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (showLabel)
          Text(
            'BOOST',
            style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.1),
          ),
        for (final multiplier in PredictionMultiplier.values)
          _MultiplierChip(
            multiplier: multiplier,
            active: selected == multiplier,
            claimedElsewhere:
                owners[multiplier] != null && owners[multiplier] != questionId,
            enabled: enabled,
            onTap: () => onTap(multiplier),
          ),
      ],
    );
  }
}

class _MultiplierChip extends StatefulWidget {
  const _MultiplierChip({
    required this.multiplier,
    required this.active,
    required this.claimedElsewhere,
    required this.enabled,
    required this.onTap,
  });

  final PredictionMultiplier multiplier;
  final bool active;
  final bool claimedElsewhere;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_MultiplierChip> createState() => _MultiplierChipState();
}

class _MultiplierChipState extends State<_MultiplierChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  @override
  void didUpdateWidget(covariant _MultiplierChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      _pop
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.multiplier == PredictionMultiplier.x2
        ? Cyber.gold
        : Cyber.cyan;
    final active = widget.active;
    final claimedElsewhere = widget.claimedElsewhere;
    final enabled = widget.enabled;
    return AnimatedBuilder(
      animation: _pop,
      builder: (context, child) {
        final t = Curves.easeOutBack.transform(_pop.value);
        final scale = active
            ? 1 + 0.14 * (1 - (t - 1).abs()).clamp(0.0, 1.0)
            : 1.0;
        return Transform.scale(scale: scale, child: child);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? widget.onTap : null,
        child: SizedBox(
          height: 30,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: active
                  ? accent.withValues(alpha: 0.22)
                  : claimedElsewhere
                  ? const Color(0xff0c1220)
                  : const Color(0xff121b2c),
              border: Border.all(
                color: active
                    ? accent
                    : claimedElsewhere
                    ? Cyber.line
                    : accent.withValues(alpha: enabled ? 0.45 : 0.18),
                width: active ? 1.5 : 1,
              ),
              boxShadow: active
                  ? Cyber.glow(accent, alpha: 0.35, blur: 12)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  active
                      ? Icons.bolt
                      : claimedElsewhere
                      ? Icons.swap_horiz
                      : Icons.bolt_outlined,
                  size: 14,
                  color: enabled || active
                      ? accent
                      : Cyber.muted.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 5),
                Text(
                  widget.multiplier.label,
                  style: Cyber.display(
                    11,
                    color: enabled || active
                        ? active
                              ? Colors.white
                              : accent
                        : Cyber.muted.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class XpPill extends StatelessWidget {
  const XpPill({required this.reward, this.multiplier, super.key});
  final int reward;
  final PredictionMultiplier? multiplier;

  @override
  Widget build(BuildContext context) {
    final accent = multiplier == PredictionMultiplier.x2
        ? Cyber.gold
        : multiplier == PredictionMultiplier.x15
        ? Cyber.cyan
        : Cyber.violet;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: Container(
        key: ValueKey('xp-$reward-${multiplier?.jsonKey ?? 'base'}'),
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Cyber.violet, Color.lerp(Cyber.violet, accent, 0.45)!],
          ),
          boxShadow: Cyber.glow(
            accent,
            alpha: multiplier == null ? 0.4 : 0.65,
            blur: 12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$reward',
              style: Cyber.display(
                13,
                color: Colors.white,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            const SizedBox(width: 4),
            Text(
              'xp',
              style: Cyber.label(10, color: Colors.white, letterSpacing: 0.5),
            ),
            if (multiplier != null) ...[
              const SizedBox(width: 6),
              Text(
                multiplier!.label,
                style: Cyber.label(9, color: accent, letterSpacing: 0.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum OptionVisual { idle, selected, correct, wrong }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.tileKey,
    required this.letter,
    required this.label,
    required this.state,
    required this.onTap,
  });

  final Key tileKey;
  final String letter;
  final String label;
  final OptionVisual state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = switch (state) {
      OptionVisual.selected => Cyber.cyan,
      OptionVisual.correct => Cyber.success,
      OptionVisual.wrong => Cyber.danger,
      OptionVisual.idle => Cyber.muted,
    };
    final active = state != OptionVisual.idle;
    final fill = active
        ? Color.alphaBlend(accent.withValues(alpha: 0.10), optionFill)
        : optionFill;
    return GestureDetector(
      key: tileKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
        decoration: BoxDecoration(
          color: fill.withValues(alpha: quizSurfaceOpacity),
          border: Border.all(
            color: active ? accent : optionBorder,
            width: active ? 1.5 : 1,
          ),
          boxShadow: state == OptionVisual.selected
              ? Cyber.glow(accent)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? accent.withValues(alpha: 0.20) : letterFill,
                border: Border.all(color: accent.withValues(alpha: 0.6)),
              ),
              child: Text(
                letter,
                style: Cyber.display(13, color: active ? accent : Cyber.muted),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: Cyber.label(
                  12.5,
                  color: active ? Colors.white : const Color(0xffc4cedd),
                  letterSpacing: 0.6,
                ),
              ),
            ),
            if (state == OptionVisual.correct)
              const Icon(Icons.check_circle, color: Cyber.success, size: 18),
            if (state == OptionVisual.wrong)
              const Icon(Icons.cancel, color: Cyber.danger, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Bottom dock: progress segments + PREVIOUS/NEXT + helper ───────────────────
/// The forward action shown on the right of the dock.
class PrimaryAction {
  const PrimaryAction(
    this.label, {
    required this.enabled,
    this.isNext = false,
    this.onTap,
  });

  final String label;
  final bool enabled;
  final bool isNext;
  final VoidCallback? onTap;
}

class BottomDock extends StatelessWidget {
  const BottomDock({
    required this.questions,
    required this.answers,
    required this.index,
    required this.canGoPrevious,
    required this.onPrevious,
    required this.primary,
    required this.helper,
    super.key,
  });

  final List<QuizQuestion> questions;
  final Map<String, int> answers;
  final int index;
  final bool canGoPrevious;
  final VoidCallback onPrevious;
  final PrimaryAction primary;
  final String helper;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                for (var i = 0; i < questions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: HudProgressSegment(
                      answered:
                          answers.containsKey(questions[i].id) ||
                          questions[i].isScorePrediction,
                      current: i == index,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (canGoPrevious) ...[
                  Expanded(
                    child: HudPagerButton(
                      label: 'PREVIOUS',
                      leadingIcon: Icons.arrow_back,
                      focal: false,
                      enabled: true,
                      onTap: onPrevious,
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: HudPagerButton(
                    label: primary.label,
                    trailingIcon: primary.isNext ? Icons.arrow_forward : null,
                    focal: primary.enabled,
                    enabled: primary.enabled,
                    onTap: primary.onTap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              helper,
              textAlign: TextAlign.center,
              style: Cyber.body(12, color: const Color(0xFF90A1B9)),
            ),
          ],
        ),
      ),
    );
  }
}
