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
import '../../services/quiz_bank.dart';
import '../../services/quiz_trivia_bank.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../predictions/widgets/settlement_reveal.dart'
    show SettlementQuestionResult;
import 'widgets/answer_verdict.dart';
import 'widgets/quiz_reveal.dart';

/// Where the current question sits in the lock → verdict → advance loop.
enum _QuestionPhase {
  /// An option can still be picked or changed.
  picking,

  /// The scan beat is running; the verdict is not shown yet.
  resolving,

  /// The verdict has landed and the answer is final.
  resolved,
}

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

class _QuizPlayScreenState extends State<QuizPlayScreen>
    with TickerProviderStateMixin {
  late List<TriviaQuestion> _questions;
  late final AnimationController _verdict;

  /// Drives the NEXT button's charge fill. When it tops up the next question is
  /// dealt automatically, so this doubles as the auto-advance timer.
  late final AnimationController _charge;

  final Map<int, int> _answers = {};
  int _index = 0;
  _QuestionPhase _phase = _QuestionPhase.picking;

  int _streak = 0;
  int _bestStreak = 0;
  int _earnedXp = 0;
  bool _xpBanked = false;

  int _verdictRun = 0;
  bool _submitting = false;
  bool _retrying = false;

  List<SettlementQuestionResult>? _revealResults;
  int _revealXp = 0;
  int _revealXpBefore = 0;
  bool _revealNewlyCleared = false;
  int _revealStars = 0;
  int _revealStarsGained = 0;
  int _revealBestBefore = 0;

  QuizMode get _mode => widget.mode;
  Sport get _sport => widget.sport;
  int get _setNumber => widget.setNumber;
  bool get _isLast => _index >= _questions.length - 1;
  bool get _currentAnswered => _answers.containsKey(_index);
  int get _potentialXp => _questions.length * _mode.reward;

  /// null until a question has been locked in.
  bool? _verdictFor(int index) {
    final picked = _answers[index];
    if (picked == null) return null;
    if (index == _index && _phase != _QuestionPhase.resolved) return null;
    return picked == _questions[index].correctIndex;
  }

  @override
  void initState() {
    super.initState();
    _questions = buildQuizSet(_sport, _mode, _setNumber);
    // The lobby preloads the bank before pushing here, so this is normally a
    // cache hit. Recover anyway (deep link, hot restart) rather than render an
    // empty quiz.
    if (_questions.isEmpty) _loadQuestions();
    _verdict = AnimationController(vsync: this, duration: kVerdictDuration);
    _charge = AnimationController(vsync: this, duration: kAutoAdvanceDelay)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _advance();
      });
    AudioController.instance.enterScene(AudioScene.quiz);
  }

  Future<void> _loadQuestions() async {
    await QuizBank.ensureLoaded(_sport, _mode);
    if (!mounted) return;
    setState(() => _questions = buildQuizSet(_sport, _mode, _setNumber));
  }

  @override
  void dispose() {
    _verdict.dispose();
    _charge.dispose();
    AudioController.instance.leaveScene(AudioScene.quiz);
    super.dispose();
  }

  void _select(int option) {
    if (_phase != _QuestionPhase.picking || _submitting) return;
    playSound(SoundEffect.cardSelect);
    HapticFeedback.selectionClick();
    setState(() => _answers[_index] = option);
  }

  /// Locks the pick and runs the SIGNAL LOCK cinematic. The scan beat plays
  /// first and gives nothing away; the verdict only lands once it completes.
  Future<void> _lockAnswer() async {
    if (_phase != _QuestionPhase.picking || !_currentAnswered) return;
    final correct = _answers[_index] == _questions[_index].correctIndex;
    final run = ++_verdictRun;

    // Streak and XP deliberately stay put until the verdict lands — updating
    // them here would leak the answer through the HUD during the scan beat.
    setState(() => _phase = _QuestionPhase.resolving);

    playSound(SoundEffect.countdownTick);
    HapticFeedback.selectionClick();

    if (MediaQuery.disableAnimationsOf(context)) {
      _verdict.value = 1;
      _landVerdict(correct);
      return;
    }

    _verdict.forward(from: 0);
    await Future<void>.delayed(
      Duration(
        milliseconds:
            (kVerdictDuration.inMilliseconds * kVerdictScanEnd).round(),
      ),
    );
    if (!mounted || run != _verdictRun) return;
    _landVerdict(correct);

    if (!correct) {
      // The real answer boots up after the tear settles.
      await Future<void>.delayed(
        Duration(
          milliseconds:
              (kVerdictDuration.inMilliseconds *
                      (kVerdictImpactEnd - kVerdictScanEnd))
                  .round(),
        ),
      );
      if (!mounted || run != _verdictRun) return;
      playSound(SoundEffect.uiConfirm);
    }
  }

  void _landVerdict(bool correct) {
    if (correct) {
      _streak++;
      if (_streak > _bestStreak) _bestStreak = _streak;
      _earnedXp += _mode.reward;
      playSound(SoundEffect.quizCorrect);
      HapticFeedback.mediumImpact();
      if (_streak >= 5) playSound(SoundEffect.quizPerfect);
    } else {
      _streak = 0;
      playSound(SoundEffect.quizWrong);
      HapticFeedback.heavyImpact();
    }
    setState(() => _phase = _QuestionPhase.resolved);
    // The last question never auto-advances — walking into the summary is the
    // player's call, not a timer's.
    if (!_isLast) _charge.forward(from: 0);
  }

  void _advance() {
    if (_phase != _QuestionPhase.resolved || _submitting) return;
    _charge.stop();
    if (_isLast) {
      _finish();
      return;
    }
    playSound(SoundEffect.uiTap);
    _verdict.value = 0;
    _charge.value = 0;
    setState(() {
      _index++;
      _phase = _QuestionPhase.picking;
    });
  }

  Future<void> _requestExit() async {
    if (_revealResults != null || _answers.isEmpty) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    // Don't let the next question get dealt behind the dialog.
    _charge.stop();
    final banked = _earnedXp;
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
          banked > 0
              ? 'Your +$banked XP is banked, but SET $_setNumber will not clear and the $kQuizEntryCost coin entry fee will not be refunded.'
              : 'SET $_setNumber will not clear and the $kQuizEntryCost coin entry fee will not be refunded.',
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
    if (confirmed == true && mounted) {
      _bankEarnedXp(partial: true);
      Navigator.of(context).pop();
    }
  }

  /// Credits everything earned so far. A partial run pays out but never records
  /// a result, so the set only clears once all questions are answered.
  void _bankEarnedXp({required bool partial}) {
    if (_xpBanked || _earnedXp <= 0) return;
    _xpBanked = true;
    context.read<GameBloc>().add(
      PredictionXpAdded(
        _earnedXp,
        source: XpTransactionSource.quiz,
        title: '${_sport.name.toUpperCase()} QUIZ REWARD',
        details: partial
            ? '${_mode.label} SET $_setNumber · PARTIAL RUN'
            : '${_mode.label} SET $_setNumber',
      ),
    );
  }

  Future<void> _finish() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    playSound(SoundEffect.quizSubmit);
    HapticFeedback.mediumImpact();

    final results = <SettlementQuestionResult>[];
    var correct = 0;
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final picked = _answers[i];
      final isCorrect = picked == q.correctIndex;
      if (isCorrect) correct++;
      results.add(
        SettlementQuestionResult(
          text: q.prompt,
          pickedLabel: q.labelFor(picked),
          correctLabel: q.correctLabel,
          correct: isCorrect,
          earnedXp: isCorrect ? _mode.reward : 0,
        ),
      );
    }

    final quiz = context.read<QuizCubit>();
    final bestBefore = quiz
        .setProgressFor(_sport, _mode, _setNumber)
        .bestCorrect;
    final xpBefore = context.read<GameBloc>().state.progression.totalXP;
    final totalXp = _earnedXp;
    _bankEarnedXp(partial: false);

    final outcome = await quiz.recordResult(
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
      _revealStarsGained = outcome.starsGained;
      _revealBestBefore = bestBefore;
      _revealStars = outcome.stars;
    });
  }

  Future<void> _retry() async {
    if (_retrying) return;
    final game = context.read<GameBloc>();
    if (game.state.coins < kQuizEntryCost) {
      _showMessage('Need $kQuizEntryCost coins to replay this quiz set.');
      return;
    }
    setState(() => _retrying = true);
    game.add(
      CoinsSpent(
        kQuizEntryCost,
        source: OzCoinTransactionSource.quizEntry,
        title: '${_sport.name.toUpperCase()} QUIZ ENTRY',
        subtitle: '${_mode.label} SET $_setNumber REPLAY',
      ),
    );
    playSound(SoundEffect.coinSpend);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    playSound(SoundEffect.playMatch);
    _verdictRun++;
    _verdict.value = 0;
    _charge.value = 0;
    setState(() {
      _questions = buildQuizSet(_sport, _mode, _setNumber);
      _index = 0;
      _answers.clear();
      _phase = _QuestionPhase.picking;
      _streak = 0;
      _bestStreak = 0;
      _earnedXp = 0;
      _xpBanked = false;
      _submitting = false;
      _retrying = false;
      _revealResults = null;
      _revealXp = 0;
      _revealXpBefore = 0;
      _revealNewlyCleared = false;
      _revealStars = 0;
      _revealStarsGained = 0;
      _revealBestBefore = 0;
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
    // The pool is still loading, or this set is past the authored range. Either
    // way there is nothing to deal — show the holding screen rather than index
    // into an empty list.
    if (_questions.isEmpty) return _buildAwaitingQuestions(context);

    final question = _questions[_index];
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final canPop = _answers.isEmpty || _revealResults != null;
    final verdict = _verdictFor(_index);

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
                    onBack: _requestExit,
                  ),
                  const SizedBox(height: 8),
                  _QuizHeader(
                    sport: _sport,
                    mode: _mode,
                    index: _index,
                    total: _questions.length,
                    streak: _streak,
                    earnedXp: _earnedXp,
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
                      child: SingleChildScrollView(
                        key: ValueKey(question.id),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 430),
                            child: AnimatedBuilder(
                              animation: _verdict,
                              builder: (context, _) => _QuestionPanel(
                                number: _index + 1,
                                mode: _mode,
                                question: question,
                                selected: _answers[_index],
                                phase: _phase,
                                verdict: verdict,
                                streak: _streak,
                                progress: _verdict.value,
                                onSelect: _select,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _BottomDock(
                    total: _questions.length,
                    index: _index,
                    charge: _charge,
                    answeredIndices: _answers.keys.toSet(),
                    verdicts: {
                      for (var i = 0; i < _questions.length; i++)
                        if (_verdictFor(i) != null) i: _verdictFor(i)!,
                    },
                    phase: _phase,
                    isLast: _isLast,
                    primaryEnabled: _phase == _QuestionPhase.picking
                        ? _currentAnswered
                        : _phase == _QuestionPhase.resolved && !_submitting,
                    onPrimary: _phase == _QuestionPhase.picking
                        ? _lockAnswer
                        : _advance,
                    helper: _helperText(),
                    debrief: verdict == null
                        ? null
                        : VerdictDebriefStrip(
                            correct: verdict,
                            xp: _mode.reward,
                            streak: _streak,
                            correctLabel: question.correctLabel,
                          ),
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
                  stars: _revealStars,
                  starsGained: _revealStarsGained,
                  bestBefore: _revealBestBefore,
                  bestStreak: _bestStreak,
                  onRetry: _retry,
                  onDone: () => Navigator.of(context).maybePop(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Shown while the pool loads, and as the terminal state for a set the
  /// question database doesn't reach yet. Keeps the quiz chrome so the screen
  /// still reads as the quiz, not an error page.
  Widget _buildAwaitingQuestions(BuildContext context) {
    final loading = !QuizBank.isLoaded(_sport, _mode);
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
                  sport: _sport,
                  mode: _mode,
                  setNumber: _setNumber,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Center(
                    child: loading
                        ? const CircularProgressIndicator(
                            color: AppTheme.textPrimary,
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.hourglass_empty,
                                  color: Cyber.muted,
                                  size: 34,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'SET NOT WRITTEN YET',
                                  textAlign: TextAlign.center,
                                  style: Cyber.label(
                                    11,
                                    color: Cyber.muted,
                                    letterSpacing: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'This ladder is still being built. '
                                  'Pick another set or sport.',
                                  textAlign: TextAlign.center,
                                  style: Cyber.body(12, color: Cyber.muted),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _helperText() {
    final left = _questions.length - _answers.length;
    if (_streak >= 2) {
      return 'Streak ×$_streak · $left of ${_questions.length} left · +${_mode.reward} XP per correct';
    }
    return '$left of ${_questions.length} left · +${_mode.reward} XP per correct · max $_potentialXp XP';
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.sport,
    required this.mode,
    required this.setNumber,
    required this.onBack,
  });

  final Sport sport;
  final QuizMode mode;
  final int setNumber;
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
            label: '${mode.label} · SET $setNumber',
            color: mode.accent,
          ),
        ],
      ),
    );
  }
}

class _QuizHeader extends StatelessWidget {
  const _QuizHeader({
    required this.sport,
    required this.mode,
    required this.index,
    required this.total,
    required this.streak,
    required this.earnedXp,
  });

  final Sport sport;
  final QuizMode mode;
  final int index;
  final int total;
  final int streak;
  final int earnedXp;

  @override
  Widget build(BuildContext context) {
    final streakAccent = streak >= 2 ? verdictStreakAccent(streak) : Cyber.muted;
    return Semantics(
      label:
          'Question ${index + 1} of $total, streak $streak, $earnedXp XP earned',
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
                    label: 'QUESTION',
                    value: '${index + 1}/$total',
                    icon: mode.iconFor(sport),
                    color: mode.accent,
                  ),
                ),
                const _MetricDivider(),
                Expanded(
                  child: _HudMetric(
                    label: 'STREAK',
                    value: streak > 0 ? '×$streak' : '—',
                    icon: Icons.bolt_outlined,
                    color: streakAccent,
                  ),
                ),
                const _MetricDivider(),
                Expanded(
                  child: _XpEarnedMetric(value: earnedXp),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// XP counter that ticks to its new value and pops when it grows — the payoff
/// beat for a correct answer lands here as well as on the tile.
class _XpEarnedMetric extends StatefulWidget {
  const _XpEarnedMetric({required this.value});

  final int value;

  @override
  State<_XpEarnedMetric> createState() => _XpEarnedMetricState();
}

class _XpEarnedMetricState extends State<_XpEarnedMetric>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
    reverseDuration: const Duration(milliseconds: 320),
  );

  @override
  void didUpdateWidget(covariant _XpEarnedMetric old) {
    super.didUpdateWidget(old);
    if (widget.value > old.value && !MediaQuery.disableAnimationsOf(context)) {
      _pop.forward().then((_) {
        if (mounted) _pop.reverse();
      });
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1, end: 1.16).animate(
        CurvedAnimation(parent: _pop, curve: Curves.easeOutBack),
      ),
      child: TweenAnimationBuilder<int>(
        tween: IntTween(begin: widget.value, end: widget.value),
        duration: const Duration(milliseconds: 260),
        builder: (context, value, _) => _HudMetric(
          label: 'XP EARNED',
          value: '$value XP',
          icon: Icons.bolt,
          color: Cyber.gold,
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
          style: Cyber.display(11.5, color: color, letterSpacing: 0.5).copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
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
    required this.phase,
    required this.verdict,
    required this.streak,
    required this.progress,
    required this.onSelect,
  });

  final int number;
  final QuizMode mode;
  final TriviaQuestion question;
  final int? selected;
  final _QuestionPhase phase;
  final bool? verdict;
  final int streak;
  final double progress;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scanning = phase == _QuestionPhase.resolving;
    final resolved = phase == _QuestionPhase.resolved;
    final wrong = resolved && verdict == false;
    // The correct answer only powers on after the tear has played out.
    final showKey = wrong && progress >= kVerdictImpactEnd;

    final panel = Stack(
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
                resolved
                    ? 'ANSWER LOCKED'
                    : scanning
                    ? 'VERIFYING SIGNAL...'
                    : 'SELECT ONE ANSWER',
                style: Cyber.label(
                  8.5,
                  color: scanning ? Cyber.cyan : mode.accent,
                  letterSpacing: 1.4,
                ),
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
                    // Only the picked tile carries the verdict; the answer key
                    // lights up separately when the player got it wrong.
                    verdict: resolved && selected == i ? verdict : null,
                    isAnswerKey: showKey && i == question.correctIndex,
                    dimmed: scanning && selected != i,
                    streak: streak,
                    progress: progress,
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
        if (scanning)
          Positioned.fill(child: VerdictScanline(progress: progress)),
      ],
    );

    return GlitchTear(progress: progress, active: wrong, child: panel);
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
    this.verdict,
    this.isAnswerKey = false,
    this.dimmed = false,
    this.streak = 0,
    this.progress = 0,
  });

  final String letter;
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  /// null while the question is still open; true/false once locked.
  final bool? verdict;

  /// True for the right answer on a question the player got wrong.
  final bool isAnswerKey;
  final bool dimmed;
  final int streak;
  final double progress;

  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile> {
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final verdict = widget.verdict;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final locked = verdict != null || widget.isAnswerKey;

    // Glow rule: exactly one live element. Before the lock that's the picked
    // tile; after it, the verdict tile (or the answer key on a miss).
    final Color accent = verdict == true
        ? verdictStreakAccent(widget.streak)
        : verdict == false
        ? Cyber.danger
        : widget.isAnswerKey
        ? Cyber.success
        : widget.accent;

    final border = locked || selected || _focused
        ? accent
        : const Color(0xff304058);

    // Broken-neon flicker on the wrong pick.
    final flicker = verdict == false && !reduceMotion
        ? 0.55 +
              0.45 *
                  (1 -
                      verdictBeat(
                        widget.progress,
                        kVerdictScanEnd,
                        kVerdictImpactEnd,
                      )).clamp(0.0, 1.0) *
                  ((widget.progress * 34).floor().isEven ? 0.0 : 1.0)
        : 1.0;

    final tile = AnimatedContainer(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 160),
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: verdict != null
            ? accent.withValues(alpha: 0.16)
            : widget.isAnswerKey
            ? accent.withValues(alpha: 0.1)
            : selected
            ? accent.withValues(alpha: 0.15)
            : _focused
            ? accent.withValues(alpha: 0.07)
            : const Color(0xff0d1725),
        border: Border.all(
          color: border.withValues(alpha: flicker),
          width: locked || selected ? 1.6 : 1,
        ),
        boxShadow: verdict == true
            ? Cyber.glow(accent, alpha: 0.28, blur: 18)
            : selected && verdict == null && !widget.isAnswerKey
            ? Cyber.glow(accent, alpha: 0.18, blur: 12)
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
              color: locked || selected
                  ? accent.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.04),
              border: Border.all(color: border),
            ),
            child: verdict == null
                ? Text(
                    widget.letter,
                    style: Cyber.display(
                      12,
                      color: selected || widget.isAnswerKey
                          ? accent
                          : Cyber.muted,
                    ),
                  )
                : Icon(
                    verdict ? Icons.check : Icons.close,
                    size: 17,
                    color: accent,
                  ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              widget.label,
              style: Cyber.body(
                14.5,
                color: locked || selected
                    ? Colors.white
                    : const Color(0xffc8d3e2),
                weight: locked || selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
          if (widget.isAnswerKey) ...[
            const SizedBox(width: 8),
            Text(
              '// CORRECT',
              style: Cyber.label(8, color: accent, letterSpacing: 1.2),
            ),
          ] else ...[
            const SizedBox(width: 8),
            Icon(
              verdict != null
                  ? (verdict ? Icons.verified : Icons.cancel)
                  : selected
                  ? Icons.check_circle
                  : Icons.circle_outlined,
              color: locked || selected ? accent : Cyber.border,
              size: 20,
            ),
          ],
        ],
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: verdict == null
          ? 'Answer ${widget.letter}: ${widget.label}'
          : 'Answer ${widget.letter}: ${widget.label}, ${verdict ? 'correct' : 'wrong'}',
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedOpacity(
            opacity: widget.dimmed ? 0.55 : 1,
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 140),
            child: AnimatedScale(
              scale: reduceMotion || !_pressed ? 1 : 0.985,
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 100),
              child: verdict == true && !reduceMotion
                  ? Stack(
                      clipBehavior: Clip.none,
                      children: [
                        tile,
                        Positioned.fill(
                          child: SignalLockFx(
                            progress: widget.progress,
                            accent: accent,
                            chevrons: widget.streak >= 3 ? 5 : 3,
                          ),
                        ),
                      ],
                    )
                  : tile,
            ),
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
    required this.charge,
    required this.answeredIndices,
    required this.verdicts,
    required this.phase,
    required this.isLast,
    required this.primaryEnabled,
    required this.onPrimary,
    required this.helper,
    required this.debrief,
  });

  final int total;
  final int index;
  final Animation<double> charge;
  final Set<int> answeredIndices;
  final Map<int, bool> verdicts;
  final _QuestionPhase phase;
  final bool isLast;
  final bool primaryEnabled;
  final VoidCallback onPrimary;
  final String helper;
  final Widget? debrief;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final resolved = phase == _QuestionPhase.resolved;
    final label = !resolved
        ? 'LOCK IN'
        : isLast
        ? 'SEE RESULTS'
        : 'NEXT';

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
                              'Question ${i + 1}, ${verdicts.containsKey(i)
                                  ? (verdicts[i]! ? 'correct' : 'wrong')
                                  : i == index
                                  ? 'current'
                                  : answeredIndices.contains(i)
                                  ? 'answered'
                                  : 'unanswered'}',
                          child: HudProgressSegment(
                            answered: answeredIndices.contains(i),
                            current: i == index,
                            verdict: verdicts[i],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) {
                    if (reduceMotion) return child;
                    return FadeTransition(
                      opacity: animation,
                      child: SizeTransition(
                        sizeFactor: animation,
                        child: child,
                      ),
                    );
                  },
                  child: debrief == null
                      ? const SizedBox(
                          key: ValueKey('quiz-no-debrief'),
                          width: double.infinity,
                        )
                      : Padding(
                          key: const ValueKey('quiz-debrief'),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: debrief,
                        ),
                ),
                if (resolved && !isLast && !reduceMotion)
                  // Charging cell: tops up over 3s, then deals the next
                  // question on its own. Tapping skips the wait.
                  AnimatedBuilder(
                    animation: charge,
                    builder: (context, _) => ChargingHudButton(
                      key: const ValueKey('quiz-advance'),
                      label: label,
                      icon: Icons.arrow_forward,
                      fill: charge.value,
                      onTap: onPrimary,
                    ),
                  )
                else
                  HudPagerButton(
                    key: ValueKey(
                      resolved ? 'quiz-advance' : 'quiz-lock-answer',
                    ),
                    label: label,
                    trailingIcon: !resolved
                        ? Icons.lock_outline
                        : isLast
                        ? Icons.fact_check_outlined
                        : Icons.arrow_forward,
                    focal: primaryEnabled,
                    enabled: primaryEnabled,
                    onTap: primaryEnabled ? onPrimary : null,
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
