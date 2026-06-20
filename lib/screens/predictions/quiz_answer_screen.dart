import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/achievement/achievement_celebration_controller.dart';
import '../../blocs/prediction/prediction_cubit.dart';
import '../../config/theme.dart';
import '../../models/prediction.dart';
import '../../models/sport_match.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import 'widgets/quiz_chrome.dart';
import 'widgets/quiz_question_widgets.dart';
import 'widgets/quiz_submitted_overlay.dart';

enum _QuizRevealPhase { numberIntro, questionReveal, optionsReveal, ready }

/// Paginated answer flow for a single fixture's prediction quiz. Mounted by
/// [MatchPredictionScreen] while no [UserPrediction] exists for the match.
/// Owns the reveal cinematic, the draft answers/boosts, and the post-submit
/// celebration overlay. When the celebration finishes it pings the router
/// (via [onSubmissionFinished]), which then swaps to the review screen.
class QuizAnswerScreen extends StatefulWidget {
  const QuizAnswerScreen({
    required this.match,
    required this.quiz,
    required this.onLeaderboard,
    required this.onSubmissionStarted,
    required this.onSubmissionFinished,
    super.key,
  });

  final SportMatch match;
  final PredictionQuiz quiz;
  final VoidCallback onLeaderboard;

  /// Fired the instant the cubit submit kicks off — lets the router pin
  /// itself on this screen until the cinematic finishes (otherwise its
  /// BlocBuilder would race ahead to the review screen the moment the new
  /// [UserPrediction] lands in state).
  final VoidCallback onSubmissionStarted;

  /// Fired when the celebration cinematic finishes. The router releases its
  /// lock and pivots to the review screen with the cascade animation.
  final VoidCallback onSubmissionFinished;

  @override
  State<QuizAnswerScreen> createState() => _QuizAnswerScreenState();
}

class _QuizAnswerScreenState extends State<QuizAnswerScreen>
    with TickerProviderStateMixin {
  bool _submitting = false;
  AchievementCelebrationController? _heldCelebrations;

  int _index = 0;
  final Map<String, int> _answers = {};
  final Set<String> _interactedScoreQuestions = {};
  final Map<String, PredictionMultiplier> _multipliersByQuestion = {};

  _QuizRevealPhase _revealPhase = _QuizRevealPhase.ready;
  int _revealRun = 0;

  late final AnimationController _numberIntro;
  late final AnimationController _questionReveal;
  late final AnimationController _optionsReveal;

  Timer? _ticker;
  DateTime _now = DateTime.now();

  SportMatch get _match => widget.match;
  PredictionQuiz get _quiz => widget.quiz;
  List<QuizQuestion> get _questions => _quiz.questions;
  bool get _editable => _match.predictable;
  bool get _revealing => _revealPhase != _QuizRevealPhase.ready;
  bool get _isLast => _index >= _questions.length - 1;

  bool get _allAnswered => _questions.every(
    (q) => q.isScorePrediction || _answers.containsKey(q.id),
  );

  bool get _currentAnswered {
    if (_questions.isEmpty) return false;
    final q = _questions[_index];
    return q.isScorePrediction || _answers.containsKey(q.id);
  }

  Duration get _untilLock {
    final d = _match.kickoff.difference(_now);
    return d.isNegative ? Duration.zero : d;
  }

  Map<PredictionMultiplier, String> get _multiplierOwners => {
    for (final entry in _multipliersByQuestion.entries) entry.value: entry.key,
  };

  int get _potentialXp =>
      _questions.fold(0, (sum, q) => sum + _boostedRewardFor(q));

  /// XP "in the pot" so far: boosted rewards of the questions the user has
  /// actually answered. Score questions only count once touched, so the 0-0
  /// default doesn't pre-fill the pot.
  int get _bankedXp => _questions.fold(
    0,
    (sum, q) => sum + (_questionBanked(q) ? _boostedRewardFor(q) : 0),
  );

  bool _questionBanked(QuizQuestion question) => question.isScorePrediction
      ? _interactedScoreQuestions.contains(question.id)
      : _answers.containsKey(question.id);

  int _boostedRewardFor(QuizQuestion question) =>
      _multipliersByQuestion[question.id]?.applyTo(question.reward) ??
      question.reward;

  bool _questionAnswered(String questionId) {
    QuizQuestion? question;
    for (final candidate in _questions) {
      if (candidate.id == questionId) {
        question = candidate;
        break;
      }
    }
    if (question == null) return false;
    return question.isScorePrediction || _answers.containsKey(questionId);
  }

  String get _remainingBoostText {
    final remaining = PredictionMultiplier.values
        .where(
          (multiplier) => !_multipliersByQuestion.containsValue(multiplier),
        )
        .map((multiplier) => multiplier.label)
        .join(', ');
    return remaining.isEmpty ? 'Boosts armed' : 'Boosts left: $remaining';
  }

  @override
  void initState() {
    super.initState();
    _numberIntro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _questionReveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _optionsReveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _ensureScoreDefaults();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    if (_questions.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runForwardReveal();
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    // Never leak a hold if the screen is torn down mid-cinematic.
    _heldCelebrations?.release();
    _numberIntro.dispose();
    _questionReveal.dispose();
    _optionsReveal.dispose();
    super.dispose();
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

  void _select(String questionId, int optionIndex) {
    if (!_editable || _revealing) return;
    playSound(SoundEffect.cardSelect);
    setState(() => _answers[questionId] = optionIndex);
  }

  void _setScore(String questionId, {int? home, int? away}) {
    if (!_editable || _revealing) return;
    final (currentHome, currentAway) = _scoreFor(questionId);
    playSound(SoundEffect.uiTap);
    setState(() {
      _interactedScoreQuestions.add(questionId);
      _answers[questionId] = ScoreAnswer.encode(
        home ?? currentHome,
        away ?? currentAway,
      );
    });
  }

  void _toggleMultiplier(String questionId, PredictionMultiplier multiplier) {
    if (!_editable || _revealing || !_questionAnswered(questionId)) return;
    final active = _multipliersByQuestion[questionId] == multiplier;
    playSound(
      active
          ? SoundEffect.uiTap
          : multiplier == PredictionMultiplier.x2
          ? SoundEffect.rarityGold
          : SoundEffect.raritySilver,
    );
    setState(() {
      if (active) {
        _multipliersByQuestion.remove(questionId);
        return;
      }
      _multipliersByQuestion.removeWhere(
        (key, value) => key == questionId || value == multiplier,
      );
      _multipliersByQuestion[questionId] = multiplier;
    });
  }

  void _previous() {
    if (_index <= 0) return;
    playSound(SoundEffect.uiTap);
    _revealRun++;
    _numberIntro.value = 1;
    _questionReveal.value = 1;
    _optionsReveal.value = 1;
    setState(() {
      _index--;
      _revealPhase = _QuizRevealPhase.ready;
    });
  }

  void _next() {
    if (_isLast || _revealing || (_editable && !_currentAnswered)) return;
    playSound(SoundEffect.uiTap);
    setState(() => _index++);
    _runForwardReveal();
  }

  Future<void> _runForwardReveal() async {
    final run = ++_revealRun;
    _numberIntro
      ..stop()
      ..reset();
    _questionReveal
      ..stop()
      ..reset();
    _optionsReveal
      ..stop()
      ..reset();
    if (!mounted) return;
    setState(() => _revealPhase = _QuizRevealPhase.numberIntro);
    playSound(SoundEffect.countdownTick);
    unawaited(_numberIntro.forward());
    await Future<void>.delayed(_numberIntro.duration!);
    if (!mounted || run != _revealRun) return;
    setState(() => _revealPhase = _QuizRevealPhase.questionReveal);
    unawaited(_questionReveal.forward());
    await Future<void>.delayed(_questionReveal.duration!);
    if (!mounted || run != _revealRun) return;
    setState(() => _revealPhase = _QuizRevealPhase.optionsReveal);
    unawaited(_optionsReveal.forward());
    await Future<void>.delayed(_optionsReveal.duration!);
    if (!mounted || run != _revealRun) return;
    setState(() => _revealPhase = _QuizRevealPhase.ready);
  }

  Future<void> _submit() async {
    if (!_allAnswered || _submitting) return;
    _ensureScoreDefaults();
    playSound(SoundEffect.matchWin);
    widget.onSubmissionStarted();
    // Hold the global achievement reveal so the post-submit cinematic plays
    // first; the cinematic releases it on completion (see onDone).
    _heldCelebrations = context.read<AchievementCelebrationController>()..hold();
    setState(() => _submitting = true);
    await context.read<PredictionCubit>().submit(
      _match.id,
      Map.of(_answers),
      multipliersByQuestion: Map.of(_multipliersByQuestion),
    );
    // The overlay drives the celebration; on completion its onDone releases the
    // hold and pings the router so it swaps to the review screen.
  }

  @override
  Widget build(BuildContext context) {
    final question = _questions.isEmpty ? null : _questions[_index];

    return Scaffold(
      backgroundColor: Cyber.bg,
      body: Stack(
        children: [
          const Positioned.fill(
            child: CyberPlainBackground(child: SizedBox.expand()),
          ),
          if (question?.backgroundAsset != null &&
              _revealPhase != _QuizRevealPhase.numberIntro)
            Positioned.fill(
              child: Opacity(
                opacity: quizPanelBackgroundOpacity,
                child: Image.asset(
                  question!.backgroundAsset!,
                  key: ValueKey(question.backgroundAsset),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          SafeArea(child: _content()),
          if (_submitting)
            Positioned.fill(
              child: SubmittedOverlay(
                potentialXp: _potentialXp,
                count: _questions.length,
                onDone: () {
                  if (!mounted) return;
                  // Release the hold so any queued achievement reveal plays
                  // over the review screen that the router is about to mount.
                  _heldCelebrations?.release();
                  _heldCelebrations = null;
                  setState(() => _submitting = false);
                  widget.onSubmissionFinished();
                },
              ),
            ),
          if (_questions.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _numberIntro,
                  builder: (context, _) => QuizNumberBurst(
                    number: _index + 1,
                    progress: _revealPhase == _QuizRevealPhase.numberIntro
                        ? _numberIntro.value
                        : 0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _content() {
    final question = _questions[_index];
    final primary = _primaryButton();

    return Column(
      children: [
        QuizChromeShell(
          edge: QuizChromeEdge.top,
          child: Column(
            children: [
              QuizTopBar(
                onBack: () => Navigator.of(context).popUntil((r) => r.isFirst),
                onLeaderboard: widget.onLeaderboard,
              ),
              const SizedBox(height: 20),
              QuizHeader(match: _match),
              LockLine(
                match: _match,
                untilLock: _untilLock,
                trailing: _editable
                    ? XpPotTicker(value: _bankedXp, max: _potentialXp)
                    : null,
              ),
            ],
          ),
        ),
        Expanded(
          child: AnimatedBuilder(
            animation: Listenable.merge([_questionReveal, _optionsReveal]),
            builder: (context, _) {
              final questionProgress = switch (_revealPhase) {
                _QuizRevealPhase.numberIntro => 0.0,
                _QuizRevealPhase.questionReveal => _questionReveal.value,
                _QuizRevealPhase.optionsReveal ||
                _QuizRevealPhase.ready => 1.0,
              };
              final optionsProgress = switch (_revealPhase) {
                _QuizRevealPhase.optionsReveal => _optionsReveal.value,
                _QuizRevealPhase.ready => 1.0,
                _ => 0.0,
              };
              return AnimatedSwitcher(
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
                child: _revealPhase == _QuizRevealPhase.numberIntro
                    ? const SizedBox.shrink(
                        key: ValueKey('question-intro-gap'),
                      )
                    : question.isScorePrediction
                    ? ScoreQuestionPanel(
                        key: ValueKey(question.id),
                        index: _index + 1,
                        question: question,
                        match: _match,
                        homeScore: _scoreFor(question.id).$1,
                        awayScore: _scoreFor(question.id).$2,
                        settled: false,
                        editable: _editable && !_revealing,
                        selectedMultiplier:
                            _multipliersByQuestion[question.id],
                        multiplierOwners: _multiplierOwners,
                        multiplierEnabled: _editable &&
                            !_revealing &&
                            _questionAnswered(question.id),
                        questionProgress: questionProgress,
                        controlProgress: optionsProgress,
                        onHomeChanged: (s) =>
                            _setScore(question.id, home: s),
                        onAwayChanged: (s) =>
                            _setScore(question.id, away: s),
                        onMultiplierTap: (multiplier) =>
                            _toggleMultiplier(question.id, multiplier),
                      )
                    : SingleChildScrollView(
                        key: ValueKey(question.id),
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                        child: QuestionPanel(
                          index: _index + 1,
                          question: question,
                          selected: _answers[question.id],
                          settled: false,
                          enabled: !_revealing,
                          selectedMultiplier:
                              _multipliersByQuestion[question.id],
                          multiplierOwners: _multiplierOwners,
                          multiplierEnabled: _editable &&
                              !_revealing &&
                              _questionAnswered(question.id),
                          questionProgress: questionProgress,
                          optionsProgress: optionsProgress,
                          onSelect: (opt) => _select(question.id, opt),
                          onMultiplierTap: (multiplier) =>
                              _toggleMultiplier(question.id, multiplier),
                        ),
                      ),
              );
            },
          ),
        ),
        QuizChromeShell(
          edge: QuizChromeEdge.bottom,
          child: BottomDock(
            questions: _questions,
            answers: _answers,
            index: _index,
            canGoPrevious: _index > 0 && !_revealing,
            onPrevious: _previous,
            primary: primary,
            helper: _helperText(),
          ),
        ),
      ],
    );
  }

  /// The forward CTA's state for the current page. NEXT pages forward; the
  /// final page becomes SUBMIT (editable) or DONE (locked review).
  PrimaryAction _primaryButton() {
    if (!_editable) {
      if (_isLast) {
        return PrimaryAction(
          'DONE',
          enabled: !_revealing,
          onTap: _revealing
              ? null
              : () {
                  playSound(SoundEffect.uiTap);
                  Navigator.of(context).maybePop();
                },
        );
      }
      return PrimaryAction(
        'NEXT',
        enabled: !_revealing,
        isNext: true,
        onTap: _revealing ? null : _next,
      );
    }
    if (_isLast) {
      return PrimaryAction(
        'SUBMIT QUIZ',
        enabled: _allAnswered && !_revealing,
        onTap: _allAnswered && !_revealing ? _submit : null,
      );
    }
    final canAdvance = _currentAnswered && !_revealing;
    return PrimaryAction(
      'NEXT',
      enabled: canAdvance,
      isNext: true,
      onTap: canAdvance ? _next : null,
    );
  }

  String _helperText() {
    if (!_editable) {
      return 'Predictions are locked — match in progress';
    }
    if (_allAnswered) {
      return 'All ${_questions.length} futures locked in - $_remainingBoostText';
    }
    return 'Complete all ${_questions.length} futures - $_remainingBoostText';
  }
}
