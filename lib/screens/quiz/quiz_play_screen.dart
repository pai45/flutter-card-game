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
import '../../widgets/cyber/cyber_widgets.dart';
import '../predictions/widgets/settlement_reveal.dart'
    show SettlementQuestionResult;
import 'widgets/quiz_reveal.dart';

/// A single Quiz run for one [QuizMode]: a gamified, one-question-at-a-
/// time flow (numbered HUD panel, A/B/C/D options, progress segments, a docked
/// PREVIOUS + NEXT→SUBMIT pair) that ends in the answer-all-then-settle
/// [QuizRevealOverlay]. XP is credited (XP-only — never coins) on submit and the
/// run is folded into [QuizCubit] progress.
class QuizPlayScreen extends StatefulWidget {
  const QuizPlayScreen({required this.sport, required this.mode, this.setNumber = 1, super.key});

  final Sport sport;
  final QuizMode mode;
  final int setNumber;

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  late List<TriviaQuestion> _questions;
  int _index = 0;

  /// question index → chosen option index.
  final Map<int, int> _answers = {};
  bool _submitting = false;
  bool _retrying = false;

  // Settlement reveal payload (null until submitted).
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

  int get _bankedXp => _answers.length * _mode.reward;
  int get _potentialXp => _questions.length * _mode.reward;

  @override
  void initState() {
    super.initState();
    _questions = buildQuizSet(_sport, _mode, _setNumber);
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

  Future<void> _submit() async {
    if (!_allAnswered || _submitting) return;
    setState(() => _submitting = true);
    playSound(SoundEffect.matchWin);
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
    // Credit up front (XP-only) so skipping the cinematic changes nothing.
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
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    playSound(SoundEffect.playMatch);
    setState(() {
      _questions = buildQuizSet(_sport, _mode, _setNumber);
      _index = 0;
      _answers.clear();
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
    return Scaffold(
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
                  mode: _mode,
                  setNumber: _setNumber,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 8),
                _QuizHeader(
                  mode: _mode,
                  index: _index,
                  total: _questions.length,
                  banked: _bankedXp,
                  potential: _potentialXp,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, anim) {
                      final slide = Tween<Offset>(
                        begin: const Offset(0.08, 0),
                        end: Offset.zero,
                      ).animate(anim);
                      return FadeTransition(
                        opacity: anim,
                        child: SlideTransition(position: slide, child: child),
                      );
                    },
                    child: SingleChildScrollView(
                      key: ValueKey(question.id),
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
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
                _BottomDock(
                  total: _questions.length,
                  index: _index,
                  answeredIndices: _answers.keys.toSet(),
                  canGoPrevious: _index > 0,
                  onPrevious: _previous,
                  isLast: _isLast,
                  primaryEnabled: _isLast ? _allAnswered : _currentAnswered,
                  onPrimary: _isLast ? _submit : _next,
                  helper: _helperText(),
                ),
              ],
            ),
          ),
          if (_revealResults != null)
            Positioned.fill(
              child: QuizRevealOverlay(
                mode: _mode,
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
    );
  }

  String _helperText() {
    if (_allAnswered) {
      return 'All ${_questions.length} answered — lock it in';
    }
    final left = _questions.length - _answers.length;
    return '$left of ${_questions.length} to go · pass for +${_mode.reward} XP/correct';
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.mode,
    required this.setNumber,
    required this.onBack,
  });

  final QuizMode mode;
  final int setNumber;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.fromLTRB(8, 10, 18, 10),
      child: Row(
        children: [
          GestureDetector(
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
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'FOOTBALL QUIZ',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.display(15, color: Colors.white, letterSpacing: 1.2),
            ),
          ),
          CyberChip(
            label: '${mode.label} · SET $setNumber',
            color: mode.accent,
          ),
        ],
      ),
    );
  }
}

// ── Header: corner brackets + question counter + XP pot ───────────────────────
class _QuizHeader extends StatelessWidget {
  const _QuizHeader({
    required this.mode,
    required this.index,
    required this.total,
    required this.banked,
    required this.potential,
  });

  final QuizMode mode;
  final int index;
  final int total;
  final int banked;
  final int potential;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
      child: CustomPaint(
        painter: _CornerBracketsPainter(accent: mode.accent),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Row(
            children: [
              Icon(mode.icon, color: mode.accent, size: 20),
              const SizedBox(width: 10),
              Text(
                'QUESTION ${index + 1}',
                style: Cyber.display(
                  15,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              Text(
                ' / $total',
                style: Cyber.label(
                  12,
                  color: Cyber.muted,
                  letterSpacing: 1,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              const Spacer(),
              const Icon(Icons.bolt, size: 14, color: Cyber.gold),
              const SizedBox(width: 3),
              Text(
                '$banked',
                style: Cyber.display(
                  13,
                  color: Cyber.gold,
                  letterSpacing: 0.6,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              Text(
                '/$potential XP',
                style: Cyber.label(
                  10,
                  color: Cyber.muted,
                  letterSpacing: 1,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Faint HUD corner ticks (top-left + top-right) framing the header.
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

// ── The single question panel ─────────────────────────────────────────────────
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
          padding: const EdgeInsets.fromLTRB(18, 28, 18, 18),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xff1b2336), Color(0xff131b2a)],
            ),
            border: Border.fromBorderSide(BorderSide(color: Color(0xff2a3550))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                question.prompt,
                style: Cyber.display(
                  16,
                  letterSpacing: 0.3,
                ).copyWith(height: 1.3),
              ),
              const SizedBox(height: 18),
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
        // Numbered tab dipping over the panel's top-left edge.
        Positioned(
          left: 14,
          top: 4,
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: mode.accent.withValues(alpha: 0.16),
              border: Border.all(color: Cyber.border),
            ),
            child: Text(
              '$number',
              style: Cyber.display(15, color: mode.accent),
            ),
          ),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.14)
              : const Color(0xff0f1826),
          border: Border.all(
            color: selected ? accent : const Color(0xff283448),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? Cyber.glow(accent, alpha: 0.22, blur: 12)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.05),
                border: Border.all(
                  color: selected ? accent : const Color(0xff324056),
                ),
              ),
              child: Text(
                letter,
                style: Cyber.display(
                  12,
                  color: selected ? accent : Cyber.muted,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Cyber.body(
                  14,
                  color: selected ? Colors.white : const Color(0xffc4cedd),
                  weight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
            if (selected) Icon(Icons.check_circle, color: accent, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Bottom dock: progress segments + PREVIOUS / NEXT-SUBMIT ────────────────────
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                for (var i = 0; i < total; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: HudProgressSegment(
                      answered: answeredIndices.contains(i),
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
                    label: isLast ? 'SUBMIT QUIZ' : 'NEXT',
                    trailingIcon: isLast ? null : Icons.arrow_forward,
                    focal: primaryEnabled,
                    enabled: primaryEnabled,
                    onTap: primaryEnabled ? onPrimary : null,
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
