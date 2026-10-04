import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/prediction.dart';
import '../../../models/sport_match.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import 'prediction_helpers.dart';
import 'quiz_question_widgets.dart';
import 'score_prediction_picker.dart';

// ── Top-of-list notice (locked vs editable hint) ──────────────────────────────
class ReviewNotice extends StatelessWidget {
  const ReviewNotice({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Cyber.cyan.withValues(alpha: 0.08),
        border: Border.all(color: Cyber.cyan.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Cyber.body(13, color: const Color(0xffbed7ee)),
      ),
    );
  }
}

// ── Collapsible review card (one per question) ────────────────────────────────
class ReviewQuestionCard extends StatelessWidget {
  const ReviewQuestionCard({
    required this.index,
    required this.question,
    required this.match,
    required this.selected,
    required this.multiplier,
    required this.multiplierOwners,
    required this.votes,
    required this.expanded,
    required this.editable,
    required this.readOnly,
    required this.finished,
    required this.onToggle,
    required this.onSelect,
    required this.onScoreChanged,
    required this.onMultiplierTap,
    super.key,
  });

  final int index;
  final QuizQuestion question;
  final SportMatch match;
  final int? selected;
  final PredictionMultiplier? multiplier;
  final Map<PredictionMultiplier, String> multiplierOwners;
  final PredictionVoteBreakdown? votes;
  final bool expanded;
  final bool editable;
  final bool readOnly;
  final bool finished;
  final VoidCallback onToggle;
  final ValueChanged<int> onSelect;
  final void Function(int home, int away) onScoreChanged;
  final ValueChanged<PredictionMultiplier> onMultiplierTap;

  @override
  Widget build(BuildContext context) {
    final selectedLabel = answerLabel(question, selected);
    final correct = correctAnswer(question);
    final selectedCorrect = selected != null && selected == correct;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [panelTop, panelBottom],
        ),
        border: Border.all(color: panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Cyber.cyan.withValues(alpha: 0.14),
                          border: Border.all(color: Cyber.border),
                        ),
                        child: Text(
                          'Q$index',
                          style: Cyber.label(10, color: Cyber.cyan),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          question.text,
                          style: Cyber.display(
                            13.5,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ).copyWith(height: 1.25),
                        ),
                      ),
                      Icon(
                        expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Cyber.muted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'YOUR PICK',
                        style: Cyber.label(
                          9,
                          color: Cyber.muted,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          selectedLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Cyber.body(
                            13,
                            color: selected == null
                                ? Cyber.muted
                                : selectedCorrect && finished
                                ? Cyber.success
                                : Colors.white,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (multiplier != null) ...[
                        const SizedBox(width: 8),
                        MultiplierBadge(multiplier: multiplier!),
                      ],
                      if (finished && correct != null)
                        Icon(
                          selectedCorrect ? Icons.check_circle : Icons.cancel,
                          color: selectedCorrect ? Cyber.success : Cyber.danger,
                          size: 16,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(color: Color(0xff27334c), height: 1),
                  const SizedBox(height: 12),
                  if (editable) _editableBody() else _pollBody(),
                  if (readOnly && finished && correct != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'CORRECT ANSWER: ${answerLabel(question, correct)}',
                      style: Cyber.label(
                        10,
                        color: Cyber.success,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    EarnedXpLine(
                      earned: selectedCorrect
                          ? multiplier?.applyTo(question.reward) ??
                                question.reward
                          : 0,
                      boosted: multiplier != null,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editableBody() {
    final boostSelector = BoostSelector(
      questionId: question.id,
      selected: multiplier,
      owners: multiplierOwners,
      enabled: selected != null,
      onTap: onMultiplierTap,
    );
    if (question.isScorePrediction) {
      final score = selected == null
          ? (home: 0, away: 0)
          : decodeScore(selected!);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScorePredictionPicker(
            match: match,
            homeScore: score.home,
            awayScore: score.away,
            enabled: true,
            settled: false,
            correctHome: question.settledHomeScore,
            correctAway: question.settledAwayScore,
            onHomeChanged: (home) => onScoreChanged(home, score.away),
            onAwayChanged: (away) => onScoreChanged(score.home, away),
          ),
          const SizedBox(height: 12),
          boostSelector,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < question.options.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == question.options.length - 1 ? 0 : 9,
            ),
            child: _ReviewOptionChoice(
              label: question.options[i],
              selected: selected == i,
              onTap: () => onSelect(i),
            ),
          ),
        const SizedBox(height: 12),
        boostSelector,
      ],
    );
  }

  Widget _pollBody() {
    final answers = pollAnswers(question, votes, selected);
    if (answers.isEmpty) {
      return Text(
        'No crowd votes yet.',
        style: Cyber.body(12, color: Cyber.muted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (multiplier != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: MultiplierBadge(multiplier: multiplier!),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CROWD VOTES',
              style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.1),
            ),
            Text(
              '${votes?.totalVotes ?? 0} votes',
              style: Cyber.body(11, color: Cyber.muted),
            ),
          ],
        ),
        const SizedBox(height: 9),
        for (final answer in answers)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PollResultRow(
              label: answerLabel(question, answer),
              votes: votes?.votesFor(answer) ?? 0,
              share: votes?.shareFor(answer) ?? 0,
              selected: selected == answer,
              correct: finished && correctAnswer(question) == answer,
            ),
          ),
      ],
    );
  }
}

class MultiplierBadge extends StatelessWidget {
  const MultiplierBadge({required this.multiplier, super.key});

  final PredictionMultiplier multiplier;

  @override
  Widget build(BuildContext context) {
    final accent = multiplier == PredictionMultiplier.x2
        ? Cyber.gold
        : Cyber.cyan;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        border: Border.all(color: accent.withValues(alpha: 0.7)),
      ),
      child: Text(multiplier.label, style: Cyber.display(10, color: accent)),
    );
  }
}

class EarnedXpLine extends StatelessWidget {
  const EarnedXpLine({required this.earned, required this.boosted, super.key});

  final int earned;
  final bool boosted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          boosted ? Icons.bolt : Icons.stars_outlined,
          color: earned > 0 ? Cyber.gold : Cyber.muted,
          size: 15,
        ),
        const SizedBox(width: 7),
        Text(
          'EARNED XP: $earned',
          style: Cyber.label(
            10,
            color: earned > 0 ? Cyber.gold : Cyber.muted,
            letterSpacing: 1,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ],
    );
  }
}

class _ReviewOptionChoice extends StatelessWidget {
  const _ReviewOptionChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? Cyber.cyan.withValues(alpha: 0.12)
              : const Color(0xff0f1826),
          border: Border.all(
            color: selected ? Cyber.cyan : const Color(0xff283448),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? Cyber.cyan : Cyber.muted,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: Cyber.label(
                  12,
                  color: selected ? Colors.white : const Color(0xffc4cedd),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PollResultRow extends StatelessWidget {
  const _PollResultRow({
    required this.label,
    required this.votes,
    required this.share,
    required this.selected,
    required this.correct,
  });

  final String label;
  final int votes;
  final double share;
  final bool selected;
  final bool correct;

  @override
  Widget build(BuildContext context) {
    final accent = correct
        ? Cyber.success
        : selected
        ? Cyber.cyan
        : Cyber.muted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: Cyber.body(
                  12,
                  color: correct || selected ? Colors.white : Cyber.muted,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            if (selected)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  'YOU',
                  style: Cyber.label(9, color: Cyber.cyan, letterSpacing: 0.8),
                ),
              ),
            if (correct)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  'RIGHT',
                  style: Cyber.label(
                    8,
                    color: Cyber.success,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            Text(
              '$votes',
              style: Cyber.body(
                12,
                color: accent,
                weight: FontWeight.w800,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
        const SizedBox(height: 5),
        LinearProgressIndicator(
          value: share.clamp(0.0, 1.0),
          minHeight: 7,
          backgroundColor: const Color(0xff101827),
          valueColor: AlwaysStoppedAnimation<Color>(accent),
        ),
      ],
    );
  }
}

// ── Bottom docks ──────────────────────────────────────────────────────────────
class ReviewSaveDock extends StatelessWidget {
  const ReviewSaveDock({
    required this.enabled,
    required this.saving,
    required this.onSave,
    super.key,
  });

  final bool enabled;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 22),
        child: HudPagerButton(
          label: saving ? 'SAVING...' : 'SAVE UPDATES',
          focal: enabled,
          enabled: enabled,
          onTap: onSave,
        ),
      ),
    );
  }
}

/// Focal dock shown right after a fresh submit: chains the player straight into
/// the next match's quiz ("PREDICT XXX vs XXX"), or — when there's nothing left
/// to predict — drops them back to the matches list.
class PredictNextDock extends StatelessWidget {
  const PredictNextDock({required this.next, required this.onTap, super.key});

  final SportMatch? next;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final next = this.next;
    final label = next == null
        ? 'BACK TO MATCHES'
        : 'PREDICT ${next.home.shortName} vs ${next.away.shortName}';
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 22),
        child: HudPagerButton(
          label: label,
          focal: true,
          enabled: true,
          trailingIcon: Icons.keyboard_double_arrow_right,
          onTap: onTap,
        ),
      ),
    );
  }
}

/// Focal dock on a finished, settleable review: launches the settlement
/// reveal cinematic.
class SettleDock extends StatelessWidget {
  const SettleDock({required this.onSettle, super.key});

  final VoidCallback onSettle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 22),
        child: HudPagerButton(
          label: 'REVEAL RESULTS',
          focal: true,
          enabled: true,
          onTap: onSettle,
        ),
      ),
    );
  }
}
