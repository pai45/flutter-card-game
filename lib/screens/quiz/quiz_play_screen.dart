import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/quiz/quiz_cubit.dart';
import '../../config/theme.dart';
import '../../models/oz_coin_ledger.dart';
import '../../models/quiz_trivia.dart';
import '../../models/sport_match.dart';
import '../../models/xp_ledger.dart';
import '../../services/quiz_trivia_bank.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../predictions/widgets/settlement_reveal.dart'
    show SettlementQuestionResult;
import 'widgets/quiz_reveal.dart';

enum _QuizPlayStage { answering, review }

class QuizPlayScreen extends StatefulWidget {
  const QuizPlayScreen({
    required this.sport,
    required this.mode,
    this.setNumber = 1,
    super.key,
  });

  final Sport sport;
  final QuizMode mode;
  final int setNumber;

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  late List<TriviaQuestion> _questions;
  final Map<int, int> _answers = {};
  int _index = 0;
  _QuizPlayStage _stage = _QuizPlayStage.answering;
  bool _submitting = false;
  bool _retrying = false;

  List<SettlementQuestionResult>? _revealResults;
  int _revealXp = 0;
  int _revealXpBefore = 0;
  bool _revealNewlyCleared = false;
  bool _revealPassed = false;
  QuizMode? _revealUnlocked;

  QuizMode get _mode => widget.mode;
  Sport get _sport => widget.sport;
  int get _setNumber => widget.setNumber;
  bool get _isLast => _index >= _questions.length - 1;
  bool get _currentAnswered => _answers.containsKey(_index);
  bool get _allAnswered => _answers.length == _questions.length;
  int get _potentialXp => _questions.length * _mode.reward;

  @override
  void initState() {
    super.initState();
    _questions = buildQuizSet(_sport, _mode, _setNumber);
    AudioController.instance.enterScene(AudioScene.quiz);
  }

  @override
  void dispose() {
    AudioController.instance.leaveScene(AudioScene.quiz);
    super.dispose();
  }

  void _select(int option) {
    if (_submitting) return;
    playSound(SoundEffect.cardSelect);
    HapticFeedback.selectionClick();
    setState(() => _answers[_index] = option);
  }

  void _previous() {
    if (_index <= 0) return;
    playSound(SoundEffect.uiTap);
    setState(() => _index--);
  }

  void _next() {
    if (_isLast || !_currentAnswered) return;
    playSound(SoundEffect.uiTap);
    setState(() => _index++);
  }

  void _showReview() {
    if (!_allAnswered) return;
    playSound(SoundEffect.uiTap);
    HapticFeedback.selectionClick();
    setState(() => _stage = _QuizPlayStage.review);
  }

  void _openQuestion(int index) {
    playSound(SoundEffect.uiTap);
    setState(() {
      _index = index;
      _stage = _QuizPlayStage.answering;
    });
  }

  Future<void> _requestExit() async {
    if (_revealResults != null || _answers.isEmpty) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Cyber.panel,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text(
          'EXIT QUIZ?',
          style: Cyber.display(17, color: Colors.white),
        ),
        content: Text(
          'Your answers will be lost and the $kQuizEntryCost coin entry fee will not be refunded.',
          style: Cyber.body(13, color: Cyber.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('KEEP PLAYING'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Cyber.danger,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('EXIT QUIZ'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _submit() async {
    if (!_allAnswered || _submitting) return;
    setState(() => _submitting = true);
    playSound(SoundEffect.quizSubmit);
    HapticFeedback.mediumImpact();

    final results = <SettlementQuestionResult>[];
    var correct = 0;
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final picked = _answers[i];
      final isCorrect = picked == q.correctIndex;
      final earned = isCorrect ? _mode.reward : 0;
      if (isCorrect) correct++;
      results.add(
        SettlementQuestionResult(
          text: q.prompt,
          pickedLabel: q.labelFor(picked),
          correctLabel: q.correctLabel,
          correct: isCorrect,
          earnedXp: earned,
        ),
      );
    }

    final passed = quizSetPassed(correct: correct, total: _questions.length);
    final totalXp = passed ? correct * _mode.reward : 0;
    final xpBefore = context.read<GameBloc>().state.progression.totalXP;
    if (totalXp > 0) {
      context.read<GameBloc>().add(
        PredictionXpAdded(
          totalXp,
          source: XpTransactionSource.quiz,
          title: '${_sport.name.toUpperCase()} QUIZ REWARD',
          details: '${_mode.label} SET $_setNumber',
        ),
      );
    }
    final outcome = await context.read<QuizCubit>().recordResult(
      _sport,
      _mode,
      setNumber: _setNumber,
      correct: correct,
      total: _questions.length,
    );

    if (!mounted) return;
    setState(() {
      _revealResults = results;
      _revealXp = totalXp;
      _revealXpBefore = xpBefore;
      _revealNewlyCleared = outcome.newlyCleared;
      _revealPassed = passed;
      _revealUnlocked = outcome.unlocked;
    });
  }

  Future<void> _retry() async {
    if (_retrying) return;
    final game = context.read<GameBloc>();
    if (game.state.coins < kQuizEntryCost) {
      _showMessage('Need $kQuizEntryCost coins to retry this quiz set.');
      return;
    }
    setState(() => _retrying = true);
    game.add(
      CoinsSpent(
        kQuizEntryCost,
        source: OzCoinTransactionSource.quizEntry,
        title: '${_sport.name.toUpperCase()} QUIZ ENTRY',
        subtitle: '${_mode.label} SET $_setNumber RETRY',
      ),
    );
    playSound(SoundEffect.coinSpend);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    playSound(SoundEffect.playMatch);
    setState(() {
      _questions = buildQuizSet(_sport, _mode, _setNumber);
      _index = 0;
      _answers.clear();
      _stage = _QuizPlayStage.answering;
      _submitting = false;
      _retrying = false;
      _revealResults = null;
      _revealXp = 0;
      _revealXpBefore = 0;
      _revealNewlyCleared = false;
      _revealPassed = false;
      _revealUnlocked = null;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1700),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final question = _questions[_index];
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final canPop = _answers.isEmpty || _revealResults != null;

    return PopScope<void>(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: Scaffold(
        backgroundColor: Cyber.bg,
        body: Stack(
          children: [
            const Positioned.fill(
              child: CyberPlainBackground(child: SizedBox.expand()),
            ),
            SafeArea(
              child: Column(
                children: [
                  _TopBar(
                    sport: _sport,
                    mode: _mode,
                    setNumber: _setNumber,
                    reviewing: _stage == _QuizPlayStage.review,
                    onBack: _requestExit,
                  ),
                  const SizedBox(height: 8),
                  _QuizHeader(
                    mode: _mode,
                    index: _index,
                    total: _questions.length,
                    answered: _answers.length,
                    potential: _potentialXp,
                    reviewing: _stage == _QuizPlayStage.review,
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 240),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        if (reduceMotion) return child;
                        final slide = Tween<Offset>(
                          begin: const Offset(0.05, 0),
                          end: Offset.zero,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(position: slide, child: child),
                        );
                      },
                      child: _stage == _QuizPlayStage.review
                          ? _QuizReviewPanel(
                              key: const ValueKey('quiz-review-stage'),
                              mode: _mode,
                              questions: _questions,
                              answers: _answers,
                              onOpenQuestion: _openQuestion,
                            )
                          : SingleChildScrollView(
                              key: ValueKey(question.id),
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                12,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 430,
                                  ),
                                  child: _QuestionPanel(
                                    number: _index + 1,
                                    mode: _mode,
                                    question: question,
                                    selected: _answers[_index],
                                    onSelect: _select,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  if (_stage == _QuizPlayStage.review)
                    _ReviewDock(
                      submitting: _submitting,
                      onBack: () => _openQuestion(_questions.length - 1),
                      onSubmit: _submit,
                    )
                  else
                    _BottomDock(
                      total: _questions.length,
                      index: _index,
                      answeredIndices: _answers.keys.toSet(),
                      canGoPrevious: _index > 0,
                      onPrevious: _previous,
                      isLast: _isLast,
                      primaryEnabled: _currentAnswered,
                      onPrimary: _isLast ? _showReview : _next,
                      helper: _helperText(),
                    ),
                ],
              ),
            ),
            if (_revealResults != null)
              Positioned.fill(
                child: QuizRevealOverlay(
                  mode: _mode,
                  setNumber: _setNumber,
                  results: _revealResults!,
                  totalXp: _revealXp,
                  xpBefore: _revealXpBefore,
                  newlyCleared: _revealNewlyCleared,
                  unlocked: _revealUnlocked,
                  passed: _revealPassed,
                  onRetry: _retry,
                  onDone: () => Navigator.of(context).maybePop(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _helperText() {
    if (_isLast && _currentAnswered) {
      return 'All ${_questions.length} answered · review before locking in';
    }
    final left = _questions.length - _answers.length;
    return '$left of ${_questions.length} unanswered · earn +${_mode.reward} XP per correct after passing';
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.sport,
    required this.mode,
    required this.setNumber,
    required this.reviewing,
    required this.onBack,
  });

  final Sport sport;
  final QuizMode mode;
  final int setNumber;
  final bool reviewing;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Cyber.borderMuted)),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Exit quiz',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                playSound(SoundEffect.uiTap);
                onBack();
              },
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.arrow_back, color: Color(0xffd9e5f6)),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '${sport.name.toUpperCase()} QUIZ',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.display(15, color: Colors.white, letterSpacing: 1.2),
            ),
          ),
          const SizedBox(width: 8),
          CyberChip(
            label: reviewing ? 'REVIEW' : '${mode.label} · SET $setNumber',
            color: mode.accent,
          ),
        ],
      ),
    );
  }
}

class _QuizHeader extends StatelessWidget {
  const _QuizHeader({
    required this.mode,
    required this.index,
    required this.total,
    required this.answered,
    required this.potential,
    required this.reviewing,
  });

  final QuizMode mode;
  final int index;
  final int total;
  final int answered;
  final int potential;
  final bool reviewing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: reviewing
          ? 'Review answers, $answered of $total answered, maximum reward $potential XP'
          : 'Question ${index + 1} of $total, $answered answered, maximum reward $potential XP',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: CustomPaint(
          painter: _CornerBracketsPainter(accent: mode.accent),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            child: Row(
              children: [
                Expanded(
                  child: _HudMetric(
                    label: reviewing ? 'STAGE' : 'QUESTION',
                    value: reviewing ? 'REVIEW' : '${index + 1}/$total',
                    icon: mode.icon,
                    color: mode.accent,
                  ),
                ),
                const _MetricDivider(),
                Expanded(
                  child: _HudMetric(
                    label: 'ANSWERED',
                    value: '$answered/$total',
                    icon: Icons.check_circle_outline,
                    color: answered == total ? Cyber.success : Cyber.cyan,
                  ),
                ),
                const _MetricDivider(),
                Expanded(
                  child: _HudMetric(
                    label: 'MAX REWARD',
                    value: '$potential XP',
                    icon: Icons.bolt,
                    color: Cyber.gold,
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

class _HudMetric extends StatelessWidget {
  const _HudMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Cyber.label(7.5, color: Cyber.muted, letterSpacing: 0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          style: Cyber.display(11.5, color: color, letterSpacing: 0.5),
        ),
      ],
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 34,
    margin: const EdgeInsets.symmetric(horizontal: 5),
    color: Cyber.border,
  );
}

class _CornerBracketsPainter extends CustomPainter {
  const _CornerBracketsPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    const len = 16.0;
    final paint = Paint()
      ..color = accent.withValues(alpha: 0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, len), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - len, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketsPainter old) =>
      old.accent != accent;
}

class _QuestionPanel extends StatelessWidget {
  const _QuestionPanel({
    required this.number,
    required this.mode,
    required this.question,
    required this.selected,
    required this.onSelect,
  });

  final int number;
  final QuizMode mode;
  final TriviaQuestion question;
  final int? selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.fromLTRB(18, 31, 18, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xff1b2336), Color(0xff111a29)],
            ),
            border: Border.all(color: mode.accent.withValues(alpha: 0.34)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SELECT ONE ANSWER',
                style: Cyber.label(8.5, color: mode.accent, letterSpacing: 1.4),
              ),
              const SizedBox(height: 10),
              Text(
                question.prompt,
                style: Cyber.display(
                  18,
                  letterSpacing: 0.2,
                ).copyWith(height: 1.32),
              ),
              const SizedBox(height: 22),
              for (var i = 0; i < question.options.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == question.options.length - 1 ? 0 : 10,
                  ),
                  child: _OptionTile(
                    key: ValueKey('quiz-option-$i'),
                    letter: String.fromCharCode(65 + i),
                    label: question.options[i],
                    selected: selected == i,
                    accent: mode.accent,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          left: 14,
          top: 0,
          child: Container(
            constraints: const BoxConstraints(minWidth: 42, minHeight: 34),
            padding: const EdgeInsets.symmetric(horizontal: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color.lerp(Cyber.panel, mode.accent, 0.14),
              border: Border.all(color: mode.accent),
              boxShadow: Cyber.glow(mode.accent, alpha: 0.16, blur: 10),
            ),
            child: Text(
              number.toString().padLeft(2, '0'),
              style: Cyber.display(14, color: mode.accent),
            ),
          ),
        ),
      ],
    );
  }
}

class _OptionTile extends StatefulWidget {
  const _OptionTile({
    super.key,
    required this.letter,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String letter;
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile> {
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final border = selected || _focused
        ? widget.accent
        : const Color(0xff304058);

    return Semantics(
      button: true,
      selected: selected,
      label: 'Answer ${widget.letter}: ${widget.label}',
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: reduceMotion || !_pressed ? 1 : 0.985,
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 100),
            child: AnimatedContainer(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              constraints: const BoxConstraints(minHeight: 58),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              decoration: BoxDecoration(
                color: selected
                    ? widget.accent.withValues(alpha: 0.15)
                    : _focused
                    ? widget.accent.withValues(alpha: 0.07)
                    : const Color(0xff0d1725),
                border: Border.all(color: border, width: selected ? 1.6 : 1),
                boxShadow: selected
                    ? Cyber.glow(widget.accent, alpha: 0.18, blur: 12)
                    : null,
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 160),
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? widget.accent.withValues(alpha: 0.22)
                          : Colors.white.withValues(alpha: 0.04),
                      border: Border.all(color: border),
                    ),
                    child: Text(
                      widget.letter,
                      style: Cyber.display(
                        12,
                        color: selected ? widget.accent : Cyber.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: Cyber.body(
                        14.5,
                        color: selected
                            ? Colors.white
                            : const Color(0xffc8d3e2),
                        weight: selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    color: selected ? widget.accent : Cyber.border,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizReviewPanel extends StatelessWidget {
  const _QuizReviewPanel({
    super.key,
    required this.mode,
    required this.questions,
    required this.answers,
    required this.onOpenQuestion,
  });

  final QuizMode mode;
  final List<TriviaQuestion> questions;
  final Map<int, int> answers;
  final ValueChanged<int> onOpenQuestion;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CyberPanel(
                  accent: mode.accent,
                  glow: true,
                  child: Row(
                    children: [
                      Icon(
                        Icons.fact_check_outlined,
                        color: mode.accent,
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'REVIEW YOUR ANSWERS',
                              style: Cyber.display(16),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Nothing is scored until you lock in the full set.',
                              style: Cyber.body(12, color: Cyber.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < questions.length; i++) ...[
                  _ReviewRow(
                    key: ValueKey('quiz-review-$i'),
                    number: i + 1,
                    question: questions[i],
                    selected: answers[i],
                    accent: mode.accent,
                    onTap: () => onOpenQuestion(i),
                  ),
                  if (i != questions.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    super.key,
    required this.number,
    required this.question,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final int number;
  final TriviaQuestion question;
  final int? selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final answered = selected != null;
    return Semantics(
      button: true,
      label:
          'Question $number, ${answered ? 'selected ${question.labelFor(selected)}' : 'unanswered'}, edit answer',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Cyber.panel2,
            border: Border.all(
              color: answered ? accent.withValues(alpha: 0.42) : Cyber.danger,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  border: Border.all(color: accent.withValues(alpha: 0.55)),
                ),
                child: Text(
                  number.toString().padLeft(2, '0'),
                  style: Cyber.display(11, color: accent),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.prompt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.body(12, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      answered
                          ? 'ANSWER · ${question.labelFor(selected)}'
                          : 'UNANSWERED',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.label(
                        8,
                        color: answered ? Cyber.muted : Cyber.danger,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.edit_outlined, color: accent, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomDock extends StatelessWidget {
  const _BottomDock({
    required this.total,
    required this.index,
    required this.answeredIndices,
    required this.canGoPrevious,
    required this.onPrevious,
    required this.isLast,
    required this.primaryEnabled,
    required this.onPrimary,
    required this.helper,
  });

  final int total;
  final int index;
  final Set<int> answeredIndices;
  final bool canGoPrevious;
  final VoidCallback onPrevious;
  final bool isLast;
  final bool primaryEnabled;
  final VoidCallback onPrimary;
  final String helper;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Cyber.bg.withValues(alpha: 0.96),
          border: const Border(top: BorderSide(color: Cyber.borderMuted)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    for (var i = 0; i < total; i++) ...[
                      if (i > 0) const SizedBox(width: 5),
                      Expanded(
                        child: Semantics(
                          label:
                              'Question ${i + 1}, ${i == index
                                  ? 'current'
                                  : answeredIndices.contains(i)
                                  ? 'answered'
                                  : 'unanswered'}',
                          child: HudProgressSegment(
                            answered: answeredIndices.contains(i),
                            current: i == index,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
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
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: HudPagerButton(
                        label: isLast ? 'REVIEW ANSWERS' : 'NEXT',
                        trailingIcon: isLast
                            ? Icons.fact_check_outlined
                            : Icons.arrow_forward,
                        focal: primaryEnabled,
                        enabled: primaryEnabled,
                        onTap: primaryEnabled ? onPrimary : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  helper,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.body(11, color: const Color(0xFF90A1B9)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewDock extends StatelessWidget {
  const _ReviewDock({
    required this.submitting,
    required this.onBack,
    required this.onSubmit,
  });

  final bool submitting;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Cyber.bg.withValues(alpha: 0.97),
          border: const Border(top: BorderSide(color: Cyber.borderMuted)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HudCtaButton(
                  key: const ValueKey('quiz-lock-answers'),
                  label: submitting ? 'SCORING...' : 'LOCK IN ANSWERS',
                  helper: 'FINAL SUBMISSION · ANSWERS CANNOT CHANGE',
                  icon: Icons.lock_outline,
                  height: 64,
                  enabled: !submitting,
                  onTap: submitting ? null : onSubmit,
                ),
                const SizedBox(height: 7),
                TextButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('BACK TO QUESTIONS'),
                  style: TextButton.styleFrom(foregroundColor: Cyber.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
