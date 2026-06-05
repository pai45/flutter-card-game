import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/prediction/prediction_cubit.dart';
import '../../blocs/prediction/prediction_state.dart';
import '../../config/theme.dart';
import '../../models/prediction.dart';
import '../../models/sport_match.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import 'widgets/score_prediction_picker.dart';

/// The prediction quiz for one fixture, built as a gamified single-question
/// flow that mirrors the design reference:
///   • a HUD header (corner brackets, kickoff time, team badges + split bar);
///   • a "QUIZ LOCKS IN hh:mm:ss" countdown to kickoff;
///   • ONE question at a time — a numbered panel, an XP pill and A/B/C options;
///   • a progress-dot row + a chamfered NEXT button (SUBMIT on the last one);
///   • a full-screen SUBMITTED celebration when the quiz is sent.
///
/// Editable until kickoff; once live/finished the same paginated UI becomes a
/// read-only review (settled answers show correct/wrong), with a demo
/// SETTLE & CLAIM action on the final page that credits coins.
class MatchPredictionScreen extends StatefulWidget {
  const MatchPredictionScreen({required this.match, super.key});

  final SportMatch match;

  @override
  State<MatchPredictionScreen> createState() => _MatchPredictionScreenState();
}

class _MatchPredictionScreenState extends State<MatchPredictionScreen> {
  PredictionQuiz? _quiz;
  bool _loading = true;
  bool _submitting = false;
  int _index = 0;
  final Map<String, int> _answers = {};
  Timer? _ticker;
  DateTime _now = DateTime.now();

  SportMatch get _match => widget.match;
  bool get _editable => _match.predictable;

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final cubit = context.read<PredictionCubit>();
    final quiz = await cubit.quizFor(_match.id);
    final existing = cubit.state.predictionFor(_match.id);
    if (existing != null) _answers.addAll(existing.answers);
    if (!mounted) return;
    setState(() {
      _quiz = quiz;
      _loading = false;
      _ensureScoreDefaults();
    });
  }

  void _ensureScoreDefaults() {
    for (final q in _questions) {
      if (q.isScorePrediction && !_answers.containsKey(q.id)) {
        _answers[q.id] = ScoreAnswer.encode(0, 0);
      }
    }
  }

  (int home, int away) _scoreFor(String questionId) {
    final encoded = _answers[questionId];
    if (encoded != null) return ScoreAnswer.decode(encoded);
    return (0, 0);
  }

  List<QuizQuestion> get _questions => _quiz?.questions ?? const [];
  bool get _allAnswered {
    if (_quiz == null) return false;
    return _questions.every(
      (q) => q.isScorePrediction || _answers.containsKey(q.id),
    );
  }
  bool get _isLast => _index >= _questions.length - 1;

  Duration get _untilLock {
    final d = _match.kickoff.difference(_now);
    return d.isNegative ? Duration.zero : d;
  }

  void _select(String questionId, int optionIndex) {
    if (!_editable) return;
    playSound(SoundEffect.cardSelect);
    setState(() => _answers[questionId] = optionIndex);
  }

  void _setScore(String questionId, {int? home, int? away}) {
    if (!_editable) return;
    final (currentHome, currentAway) = _scoreFor(questionId);
    playSound(SoundEffect.uiTap);
    setState(() {
      _answers[questionId] = ScoreAnswer.encode(
        home ?? currentHome,
        away ?? currentAway,
      );
    });
  }

  void _previous() {
    if (_index <= 0) return;
    playSound(SoundEffect.uiTap);
    setState(() => _index--);
  }

  void _next() {
    if (_isLast) return;
    playSound(SoundEffect.uiTap);
    setState(() => _index++);
  }

  Future<void> _submit() async {
    if (!_allAnswered || _submitting) return;
    _ensureScoreDefaults();
    playSound(SoundEffect.matchWin);
    setState(() => _submitting = true);
    await context.read<PredictionCubit>().submit(_match.id, Map.of(_answers));
    // The overlay drives the celebration; it pops the screen when done.
  }

  Future<void> _settle() async {
    final reward = await context.read<PredictionCubit>().settle(_match.id);
    if (!mounted) return;
    if (reward > 0) {
      context.read<GameBloc>().add(CoinsAdded(reward));
      playSound(SoundEffect.coins);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: Stack(
        children: [
          const Positioned.fill(
            child: CyberPlainBackground(child: SizedBox.expand()),
          ),
          SafeArea(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Cyber.cyan),
                  )
                : BlocBuilder<PredictionCubit, PredictionState>(
                    builder: (context, state) =>
                        _content(state.predictionFor(_match.id)),
                  ),
          ),
          if (_submitting)
            Positioned.fill(
              child: _SubmittedOverlay(
                potentialXp: _quiz?.maxReward ?? 0,
                count: _questions.length,
                onDone: () {
                  if (mounted) Navigator.of(context).pop();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _content(UserPrediction? prediction) {
    if (_quiz == null || _questions.isEmpty) {
      return Column(
        children: [
          _QuizTopBar(onClose: () => Navigator.of(context).maybePop()),
          _QuizHeader(match: _match),
          Expanded(
            child: Center(
              child: Text(
                'No quiz available for this match yet.',
                style: Cyber.body(13, color: Cyber.muted),
              ),
            ),
          ),
        ],
      );
    }

    final settled = prediction?.status == PredictionStatus.settled;
    final question = _questions[_index];
    final primary = _primaryButton(prediction, settled);

    return Column(
      children: [
        _QuizTopBar(onClose: () => Navigator.of(context).maybePop()),
        _QuizHeader(match: _match),
        _LockLine(match: _match, untilLock: _untilLock),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) {
              final slide = Tween<Offset>(
                begin: const Offset(0.10, 0),
                end: Offset.zero,
              ).animate(anim);
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: question.isScorePrediction
                ? _ScoreQuestionPanel(
                    key: ValueKey(question.id),
                    index: _index + 1,
                    question: question,
                    match: _match,
                    homeScore: _scoreFor(question.id).$1,
                    awayScore: _scoreFor(question.id).$2,
                    settled: settled,
                    editable: _editable,
                    onHomeChanged: (s) =>
                        _setScore(question.id, home: s),
                    onAwayChanged: (s) =>
                        _setScore(question.id, away: s),
                  )
                : SingleChildScrollView(
                    key: ValueKey(question.id),
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                    child: _QuestionPanel(
                      index: _index + 1,
                      question: question,
                      selected: _answers[question.id],
                      settled: settled,
                      onSelect: (opt) => _select(question.id, opt),
                    ),
                  ),
          ),
        ),
        _BottomDock(
          questions: _questions,
          answers: _answers,
          index: _index,
          canGoPrevious: _index > 0,
          onPrevious: _previous,
          primary: primary,
          helper: _helperText(prediction, settled),
        ),
      ],
    );
  }

  /// The forward CTA's state for the current page. NEXT pages forward; the
  /// final page becomes SUBMIT (editable), SETTLE & CLAIM (finished demo) or
  /// DONE (locked review).
  _PrimaryAction _primaryButton(UserPrediction? prediction, bool settled) {
    final canSettle = _match.status == MatchStatus.finished &&
        (_quiz?.settleable ?? false) &&
        prediction != null &&
        !settled;
    if (_isLast && canSettle) {
      return _PrimaryAction('SETTLE & CLAIM', enabled: true, onTap: _settle);
    }
    if (!_editable) {
      if (_isLast) {
        return _PrimaryAction(
          'DONE',
          enabled: true,
          onTap: () {
            playSound(SoundEffect.uiTap);
            Navigator.of(context).maybePop();
          },
        );
      }
      return _PrimaryAction('NEXT', enabled: true, isNext: true, onTap: _next);
    }
    if (_isLast) {
      return _PrimaryAction(
        'SUBMIT QUIZ',
        enabled: _allAnswered,
        onTap: _allAnswered ? _submit : null,
      );
    }
    return _PrimaryAction('NEXT', enabled: true, isNext: true, onTap: _next);
  }

  String _helperText(UserPrediction? prediction, bool settled) {
    if (settled) {
      final correct = prediction?.correctCount ?? 0;
      final reward = prediction?.rewardEarned ?? 0;
      return '$correct / ${_questions.length} correct  ·  +$reward COINS';
    }
    if (!_editable) {
      return 'Predictions are locked — match in progress';
    }
    if (_allAnswered) {
      return 'All ${_questions.length} futures locked in — submit your quiz';
    }
    return 'Complete all ${_questions.length} futures to submit your quiz';
  }
}

// ── Top bar (collapse chevron) ────────────────────────────────────────────────
class _QuizTopBar extends StatelessWidget {
  const _QuizTopBar({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 0),
      child: Row(
        children: [
          const Spacer(),
          IconButton(
            onPressed: () {
              playSound(SoundEffect.uiTap);
              onClose();
            },
            icon: const Icon(Icons.keyboard_arrow_down, color: Cyber.muted),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

// ── Header: corner brackets + kickoff time + team badges + split bar ──────────
class _QuizHeader extends StatelessWidget {
  const _QuizHeader({required this.match});
  final SportMatch match;

  String get _statusLabel => switch (match.status) {
        MatchStatus.upcoming => _formatTime(match.kickoff),
        MatchStatus.live =>
          match.liveMinute != null ? "LIVE ${match.liveMinute}'" : 'LIVE',
        MatchStatus.finished => 'FINISHED',
      };

  Color get _statusColor => switch (match.status) {
        MatchStatus.upcoming => Cyber.gold,
        MatchStatus.live => Cyber.danger,
        MatchStatus.finished => Cyber.muted,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
      child: CustomPaint(
        painter: const _CornerBracketsPainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
          child: Column(
            children: [
              Text(
                _statusLabel,
                style: Cyber.display(15, color: _statusColor, letterSpacing: 1.5)
                    .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _HeaderBadge(team: match.home, cutBottomRight: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      match.home.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.body(15, weight: FontWeight.w700),
                    ),
                  ),
                  Text('-', style: Cyber.display(16, color: Cyber.muted)),
                  Expanded(
                    child: Text(
                      match.away.name,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.body(15, weight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _HeaderBadge(team: match.away, cutBottomRight: false),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Container(height: 4, color: match.home.color)),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Container(
                      height: 4,
                      color: match.away.color.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({required this.team, required this.cutBottomRight});
  final SportTeam team;
  final bool cutBottomRight;

  @override
  Widget build(BuildContext context) {
    final light = team.color.computeLuminance() > 0.55;
    final textColor = light ? const Color(0xff15202e) : Colors.white;
    final accentEdge = light
        ? Color.lerp(team.color, Colors.black, 0.28)!
        : Color.lerp(team.color, Colors.white, 0.5)!;

    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(8),
        topRight: const Radius.circular(8),
        bottomLeft: Radius.circular(cutBottomRight ? 8 : 2),
        bottomRight: Radius.circular(cutBottomRight ? 2 : 8),
      ),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [team.color, Color.lerp(team.color, Colors.black, 0.34)!],
          ),
          border: Border(bottom: BorderSide(color: accentEdge, width: 3)),
        ),
        child: Text(
          team.shortName,
          style: TextStyle(
            color: textColor,
            fontFamily: Cyber.displayFont,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

/// Faint HUD corner ticks framing the team header (top-left + top-right).
class _CornerBracketsPainter extends CustomPainter {
  const _CornerBracketsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const len = 16.0;
    final paint = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    // top-left
    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, len), paint);
    // top-right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - len, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketsPainter oldDelegate) => false;
}

// ── Lock countdown line ───────────────────────────────────────────────────────
class _LockLine extends StatelessWidget {
  const _LockLine({required this.match, required this.untilLock});
  final SportMatch match;
  final Duration untilLock;

  @override
  Widget build(BuildContext context) {
    final (icon, text, color) = switch (match.status) {
      MatchStatus.upcoming when untilLock > Duration.zero => (
          Icons.lock_clock,
          'QUIZ LOCKS IN ${_formatCountdown(untilLock)}',
          Cyber.gold,
        ),
      MatchStatus.finished => (
          Icons.flag_outlined,
          'MATCH ENDED',
          Cyber.muted,
        ),
      _ => (Icons.lock_outline, 'PREDICTIONS LOCKED', Cyber.danger),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: Cyber.label(11, color: color, letterSpacing: 1.4)
                .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}

// ── The single question panel ─────────────────────────────────────────────────
class _QuestionPanel extends StatelessWidget {
  const _QuestionPanel({
    required this.index,
    required this.question,
    required this.selected,
    required this.settled,
    required this.onSelect,
  });

  final int index;
  final QuizQuestion question;
  final int? selected;
  final bool settled;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_panelTop, _panelBottom],
            ),
            border: Border.all(color: _panelBorder),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      question.text.toUpperCase(),
                      style: Cyber.display(16, letterSpacing: 0.3)
                          .copyWith(height: 1.25),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _XpPill(reward: question.reward),
                ],
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < question.options.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == question.options.length - 1 ? 0 : 10,
                  ),
                  child: _OptionTile(
                    letter: String.fromCharCode(65 + i),
                    label: question.options[i],
                    state: _optionState(i),
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
        // The numbered tab, dipping over the panel's top-left edge.
        Positioned(
          left: 14,
          top: 0,
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Cyber.cyan.withValues(alpha: 0.16),
              border: Border.all(color: Cyber.cyan.withValues(alpha: 0.6)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$index',
              style: Cyber.display(15, color: Cyber.cyan),
            ),
          ),
        ),
      ],
    );
  }

  _OptionVisual _optionState(int i) {
    if (settled) {
      if (i == question.settledOptionIndex) return _OptionVisual.correct;
      if (i == selected) return _OptionVisual.wrong;
      return _OptionVisual.idle;
    }
    return i == selected ? _OptionVisual.selected : _OptionVisual.idle;
  }
}

// ── Score prediction question (Q1 on football fixtures) ───────────────────────
class _ScoreQuestionPanel extends StatelessWidget {
  const _ScoreQuestionPanel({
    super.key,
    required this.index,
    required this.question,
    required this.match,
    required this.homeScore,
    required this.awayScore,
    required this.settled,
    required this.editable,
    required this.onHomeChanged,
    required this.onAwayChanged,
  });

  final int index;
  final QuizQuestion question;
  final SportMatch match;
  final int homeScore;
  final int awayScore;
  final bool settled;
  final bool editable;
  final ValueChanged<int> onHomeChanged;
  final ValueChanged<int> onAwayChanged;

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
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_panelTop, _panelBottom],
              ),
              border: Border.all(color: _panelBorder),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        question.text.toUpperCase(),
                        style: Cyber.display(16, letterSpacing: 0.3)
                            .copyWith(height: 1.25),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _XpPill(reward: question.reward),
                  ],
                ),
                const SizedBox(height: 24),
                ScorePredictionPicker(
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
            left: 14,
            top: 0,
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Cyber.cyan.withValues(alpha: 0.16),
                border: Border.all(color: Cyber.cyan.withValues(alpha: 0.6)),
                borderRadius: BorderRadius.circular(4),
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

class _XpPill extends StatelessWidget {
  const _XpPill({required this.reward});
  final int reward;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Cyber.violet, Color.lerp(Cyber.violet, Cyber.cyan, 0.35)!],
        ),
        borderRadius: BorderRadius.circular(4),
        boxShadow: Cyber.glow(Cyber.violet, alpha: 0.4, blur: 10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$reward',
            style: Cyber.display(13, color: Colors.white)
                .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const SizedBox(width: 4),
          Text(
            'xp',
            style: Cyber.label(10, color: Colors.white, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

enum _OptionVisual { idle, selected, correct, wrong }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.letter,
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String letter;
  final String label;
  final _OptionVisual state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = switch (state) {
      _OptionVisual.selected => Cyber.cyan,
      _OptionVisual.correct => Cyber.success,
      _OptionVisual.wrong => Cyber.danger,
      _OptionVisual.idle => Cyber.muted,
    };
    final active = state != _OptionVisual.idle;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
        decoration: BoxDecoration(
          color: active
              ? accent.withValues(alpha: 0.10)
              : _optionFill,
          border: Border.all(
            color: active ? accent : _optionBorder,
            width: active ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
          boxShadow:
              state == _OptionVisual.selected ? Cyber.glow(accent) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? accent.withValues(alpha: 0.20) : _letterFill,
                border: Border.all(color: accent.withValues(alpha: 0.6)),
                borderRadius: BorderRadius.circular(3),
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
            if (state == _OptionVisual.correct)
              const Icon(Icons.check_circle, color: Cyber.success, size: 18),
            if (state == _OptionVisual.wrong)
              const Icon(Icons.cancel, color: Cyber.danger, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Bottom dock: progress segments + PREVIOUS/NEXT + helper ───────────────────
/// The forward action shown on the right of the dock.
class _PrimaryAction {
  const _PrimaryAction(
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

class _BottomDock extends StatelessWidget {
  const _BottomDock({
    required this.questions,
    required this.answers,
    required this.index,
    required this.canGoPrevious,
    required this.onPrevious,
    required this.primary,
    required this.helper,
  });

  final List<QuizQuestion> questions;
  final Map<String, int> answers;
  final int index;
  final bool canGoPrevious;
  final VoidCallback onPrevious;
  final _PrimaryAction primary;
  final String helper;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Fades up into the page instead of a hard divider (per the reference).
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xFF010517), Color(0xF2010517), Color(0x00010517)],
        ),
      ),
      child: SafeArea(
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
                      child: _ProgressSegment(
                        answered: answers.containsKey(questions[i].id) ||
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
                      child: _QuizButton(
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
                    child: _QuizButton(
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
      ),
    );
  }
}

class _ProgressSegment extends StatelessWidget {
  const _ProgressSegment({required this.answered, required this.current});
  final bool answered;
  final bool current;

  @override
  Widget build(BuildContext context) {
    // Current = amber "you are here"; already-answered+left = green; else slate.
    final Gradient? gradient = current
        ? const LinearGradient(colors: [_segAmberA, _segAmberB])
        : answered
            ? const LinearGradient(colors: [_segGreenA, _segGreenB])
            : null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: 8,
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? _segTrack : null,
        borderRadius: BorderRadius.circular(2),
        boxShadow:
            current ? Cyber.glow(Cyber.amber, alpha: 0.35, blur: 8) : null,
      ),
    );
  }
}

// ── PREVIOUS / NEXT button (angular HUD silhouette) ───────────────────────────
class _QuizButton extends StatelessWidget {
  const _QuizButton({
    required this.label,
    required this.focal,
    required this.enabled,
    required this.onTap,
    this.leadingIcon,
    this.trailingIcon,
  });

  final String label;
  final bool focal;
  final bool enabled;
  final VoidCallback? onTap;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final Color content = !enabled
        ? Cyber.muted
        : focal
            ? const Color(0xff06121b)
            : Cyber.cyan;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: SizedBox(
        height: 56,
        child: CustomPaint(
          painter: _HudBtnPainter(focal: focal, enabled: enabled),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leadingIcon != null) ...[
                Icon(leadingIcon, color: content, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: Cyber.body(16, color: content, weight: FontWeight.w800)
                    .copyWith(letterSpacing: 0.8),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                Icon(trailingIcon, color: content, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HudBtnPainter extends CustomPainter {
  const _HudBtnPainter({required this.focal, required this.enabled});
  final bool focal;
  final bool enabled;

  static const _clipper = HudChamferClipper(bigCut: 14, smallCut: 7);

  @override
  void paint(Canvas canvas, Size size) {
    final path = _clipper.buildPath(size);
    if (focal) {
      // Bright glowing forward CTA (NEXT / SUBMIT).
      canvas.drawPath(
        path,
        Paint()
          ..color = Cyber.cyan.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13),
      );
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(Cyber.cyan, Colors.white, 0.28)!, Cyber.cyan],
          ).createShader(Offset.zero & size),
      );
    } else {
      // Calm dark plate (PREVIOUS, or a disabled SUBMIT).
      canvas.drawPath(
        path,
        Paint()
          ..color =
              enabled ? const Color(0xff1b2336) : const Color(0xff141a26),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = enabled
              ? Cyber.cyan.withValues(alpha: 0.45)
              : Cyber.line.withValues(alpha: 0.3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HudBtnPainter old) =>
      old.focal != focal || old.enabled != enabled;
}

// ── SUBMITTED celebration overlay ─────────────────────────────────────────────
class _SubmittedOverlay extends StatefulWidget {
  const _SubmittedOverlay({
    required this.potentialXp,
    required this.count,
    required this.onDone,
  });

  final int potentialXp;
  final int count;
  final VoidCallback onDone;

  @override
  State<_SubmittedOverlay> createState() => _SubmittedOverlayState();
}

class _SubmittedOverlayState extends State<_SubmittedOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        // Ring + tick pop in over the first ~45%, hold, then fade the scrim.
        final pop = Curves.elasticOut.transform((t / 0.45).clamp(0.0, 1.0));
        final scrim = (t < 0.85 ? 1.0 : (1 - (t - 0.85) / 0.15)).clamp(0.0, 1.0);
        return Opacity(
          opacity: scrim,
          child: Container(
            color: Cyber.bg.withValues(alpha: 0.86),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: pop,
                  child: Container(
                    width: 110,
                    height: 110,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Cyber.cyan.withValues(alpha: 0.12),
                      border: Border.all(color: Cyber.cyan, width: 2.5),
                      boxShadow: Cyber.glow(Cyber.cyan, alpha: 0.7, blur: 26),
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Cyber.cyan, size: 58),
                  ),
                ),
                const SizedBox(height: 24),
                Opacity(
                  opacity: ((t - 0.25) / 0.25).clamp(0.0, 1.0),
                  child: Column(
                    children: [
                      Text(
                        'PREDICTION SUBMITTED',
                        style: Cyber.display(20, color: Colors.white,
                                letterSpacing: 2)
                            .copyWith(shadows: [
                          Shadow(
                            color: Cyber.cyan.withValues(alpha: 0.6),
                            blurRadius: 16,
                          ),
                        ]),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${widget.count} FUTURES LOCKED · UP TO ${widget.potentialXp} XP',
                        style: Cyber.label(12, color: Cyber.gold,
                                letterSpacing: 1.4)
                            .copyWith(fontFeatures: const [
                          FontFeature.tabularFigures()
                        ]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Helpers + palette ─────────────────────────────────────────────────────────
String _formatTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String _formatCountdown(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) return '${h.toString().padLeft(2, '0')}:$m:$s';
  return '$m:$s';
}

const _panelTop = Color(0xff1b2336);
const _panelBottom = Color(0xff131b2a);
const _panelBorder = Color(0xff2a3550);
const _optionFill = Color(0xff0f1826);
const _optionBorder = Color(0xff283448);
const _letterFill = Color(0xff1a2434);

// Progress-segment palette (green = done, amber = current, slate = pending).
const _segGreenA = Color(0xFF00C850);
const _segGreenB = Color(0xFF009865);
const _segAmberA = Color(0xFFFFB13D);
const _segAmberB = Color(0xFFFF7A1A);
const _segTrack = Color(0xFF314158);
