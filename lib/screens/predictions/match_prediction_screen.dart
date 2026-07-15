import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/achievement/achievement_celebration_controller.dart';
import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/picks/picks_cubit.dart';
import '../../blocs/prediction/prediction_cubit.dart';
import '../../blocs/prediction/prediction_state.dart';
import '../../config/theme.dart';
import '../../models/picks.dart';
import '../../models/prediction.dart';
import '../../models/sport_match.dart';
import '../../models/streak.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/staggered_card_entrance.dart';
import '../../widgets/team_logo.dart';
import 'market_detail_screen.dart';
import 'widgets/score_prediction_picker.dart';
import 'widgets/settlement_reveal.dart';
import '../../utils/prediction_helpers.dart';

/// The prediction quiz for one fixture, built as a gamified single-question
/// flow that mirrors the design reference:
///   • a HUD header (corner brackets, kickoff time, team badges + split bar);
///   • a "QUIZ LOCKS IN hh:mm:ss" countdown to kickoff;
///   • ONE question at a time — a numbered panel, an XP pill and A/B/C options;
///   • a progress-dot row + a chamfered NEXT button (SUBMIT on the last one);
///   • a full-screen SUBMITTED celebration when the quiz is sent.
///
/// Editable until kickoff; once live/finished the same paginated UI becomes a
/// read-only review (settled answers show correct/wrong). Finished settleable
/// matches dock a REVEAL RESULTS action that plays the settlement reveal
/// cinematic ([SettlementRevealOverlay]) and credits the earned XP.
class MatchPredictionScreen extends StatefulWidget {
  const MatchPredictionScreen({
    required this.match,
    this.quizId,
    this.embedded = false,
    this.showTopBar = true,
    this.showMatchHeader = true,
    this.onOpenPicks,
    super.key,
  });

  final SportMatch match;
  final String? quizId;
  final bool embedded;
  final bool showTopBar;
  final bool showMatchHeader;
  final VoidCallback? onOpenPicks;

  @override
  State<MatchPredictionScreen> createState() => _MatchPredictionScreenState();
}

enum _QuizRevealPhase { numberIntro, questionReveal, optionsReveal, ready }

class _MatchPredictionScreenState extends State<MatchPredictionScreen>
    with TickerProviderStateMixin {
  List<PredictionQuiz> _quizzes = const [];
  PredictionQuiz? _quiz;
  bool _loading = true;
  bool _submitting = false;
  bool _savingUpdates = false;
  bool _showQuizHub = true;
  // True for the session right after a fresh submit: we stay on the review list
  // (the "quiz submitted" screen) instead of popping, the cards cascade in, and
  // the dock shows an OPEN PICKS CTA until the user edits an answer.
  bool _justSubmitted = false;
  // Held while the post-submit cinematic plays so a freshly-unlocked achievement
  // (e.g. Analyst on the 10th quiz) reveals *after* it, not on top of it.
  AchievementCelebrationController? _heldCelebrations;
  int _index = 0;
  final Map<String, int> _answers = {};
  final Set<String> _interactedScoreQuestions = {};
  Map<String, int> _savedAnswers = {};
  final Map<String, PredictionMultiplier> _multipliersByQuestion = {};
  Map<String, PredictionMultiplier> _savedMultipliersByQuestion = {};
  final Set<String> _expandedQuestions = {};
  Map<String, PredictionVoteBreakdown> _votesByQuestion = {};
  List<MatchPredictionLeaderboardEntry> _leaderboard = const [];
  List<SettlementQuestionResult>? _settlementResults;
  int _settlementXp = 0;
  int _settlementXpBefore = 0;
  double? _settlementBeatenShare;
  Timer? _ticker;
  DateTime _now = DateTime.now();
  _QuizRevealPhase _revealPhase = _QuizRevealPhase.ready;
  int _revealRun = 0;

  late final AnimationController _numberIntro;
  late final AnimationController _questionReveal;
  late final AnimationController _optionsReveal;

  SportMatch get _match => widget.match;
  bool get _editable => _match.predictable;
  String? get _quizId => _quiz?.id;

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
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
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

  Future<void> _load() async {
    final cubit = context.read<PredictionCubit>();
    final quizzes = await cubit.quizzesFor(_match.id);
    final initialQuiz = _initialQuiz(quizzes);
    if (initialQuiz == null) {
      if (!mounted) return;
      setState(() {
        _quizzes = quizzes;
        _quiz = null;
        _loading = false;
        _showQuizHub = widget.embedded && quizzes.isNotEmpty;
      });
      return;
    }
    await _loadQuiz(initialQuiz, quizzes: quizzes);
  }

  PredictionQuiz? _initialQuiz(List<PredictionQuiz> quizzes) {
    if (quizzes.isEmpty) return null;
    final targetId = widget.quizId;
    if (targetId != null) {
      for (final quiz in quizzes) {
        if (quiz.id == targetId) return quiz;
      }
    }
    if (widget.embedded && quizzes.length > 1) return null;
    return quizzes.first;
  }

  Future<void> _loadQuiz(
    PredictionQuiz quiz, {
    List<PredictionQuiz>? quizzes,
  }) async {
    final cubit = context.read<PredictionCubit>();
    final existing = cubit.state.predictionFor(_match.id, quiz.id);
    final nextAnswers = <String, int>{};
    final nextMultipliers = <String, PredictionMultiplier>{};
    final interactedScoreQuestions = <String>{};
    if (existing != null) {
      nextAnswers.addAll(existing.answers);
      nextMultipliers.addAll(existing.multipliersByQuestion);
      interactedScoreQuestions.addAll(
        quiz.questions
            .where(
              (q) => q.isScorePrediction && existing.answers.containsKey(q.id),
            )
            .map((q) => q.id),
      );
    }
    final votes = <String, PredictionVoteBreakdown>{};
    for (final question in quiz.questions) {
      final vote = await cubit.votesFor(_match.id, quiz.id, question.id);
      if (vote != null) votes[question.id] = vote;
    }
    final leaderboard = await cubit.matchLeaderboard(_match.id, quiz.id);
    if (!mounted) return;
    setState(() {
      _quizzes = quizzes ?? _quizzes;
      _quiz = quiz;
      _loading = false;
      _showQuizHub = false;
      _answers
        ..clear()
        ..addAll(nextAnswers);
      _interactedScoreQuestions
        ..clear()
        ..addAll(interactedScoreQuestions);
      _multipliersByQuestion
        ..clear()
        ..addAll(nextMultipliers);
      _expandedQuestions.clear();
      _settlementResults = null;
      _justSubmitted = false;
      _submitting = false;
      _savingUpdates = false;
      _index = 0;
      _revealPhase = _QuizRevealPhase.ready;
      _votesByQuestion = votes;
      _leaderboard = leaderboard;
      _ensureScoreDefaults();
      _savedAnswers = Map<String, int>.from(_answers);
      _savedMultipliersByQuestion = Map<String, PredictionMultiplier>.from(
        _multipliersByQuestion,
      );
      if (existing != null && !_match.predictable) {
        _expandedQuestions
          ..clear()
          ..addAll(quiz.questions.map((q) => q.id));
      }
    });
    if (_questions.isNotEmpty && existing == null) {
      _runForwardReveal();
    } else if (existing != null && _canSettle(existing)) {
      _startSettlementReveal(existing);
    }
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
  bool get _revealing => _revealPhase != _QuizRevealPhase.ready;
  bool get _currentAnswered {
    if (_questions.isEmpty) return false;
    final q = _questions[_index];
    return q.isScorePrediction || _answers.containsKey(q.id);
  }

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

  bool get _hasDraftChanges =>
      !_sameAnswers(_answers, _savedAnswers) ||
      !_sameMultipliers(_multipliersByQuestion, _savedMultipliersByQuestion);

  Map<PredictionMultiplier, String> get _multiplierOwners => {
    for (final entry in _multipliersByQuestion.entries) entry.value: entry.key,
  };

  int get _potentialXp =>
      _questions.fold(0, (sum, question) => sum + _boostedRewardFor(question));

  /// XP "in the pot" so far: boosted rewards of the questions the user has
  /// actually answered. Score questions only count once touched, so the 0-0
  /// default doesn't pre-fill the pot.
  int get _bankedXp => _questions.fold(
    0,
    (sum, question) =>
        sum + (_questionBanked(question) ? _boostedRewardFor(question) : 0),
  );

  bool _questionBanked(QuizQuestion question) => question.isScorePrediction
      ? _interactedScoreQuestions.contains(question.id)
      : _answers.containsKey(question.id);

  int _boostedRewardFor(QuizQuestion question) =>
      _multipliersByQuestion[question.id]?.applyTo(question.reward) ??
      question.reward;

  String get _remainingBoostText {
    final remaining = PredictionMultiplier.values
        .where(
          (multiplier) => !_multipliersByQuestion.containsValue(multiplier),
        )
        .map((multiplier) => multiplier.label)
        .join(', ');
    return remaining.isEmpty ? 'Boosts armed' : 'Boosts left: $remaining';
  }

  Duration get _untilLock {
    final d = _match.kickoff.difference(_now);
    return d.isNegative ? Duration.zero : d;
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
    final quizId = _quizId;
    if (quizId == null || !_allAnswered || _submitting) return;
    final isFresh =
        context.read<PredictionCubit>().state.predictionFor(
          _match.id,
          quizId,
        ) ==
        null;
    _ensureScoreDefaults();
    playSound(SoundEffect.matchWin);
    // Hold the global achievement reveal so the post-submit cinematic plays
    // first; the cinematic releases it on completion (see the overlay onDone).
    _heldCelebrations = context.read<AchievementCelebrationController>()
      ..hold();
    setState(() => _submitting = true);
    await context.read<PredictionCubit>().submit(
      _match.id,
      quizId,
      Map.of(_answers),
      multipliersByQuestion: Map.of(_multipliersByQuestion),
    );
    if (!mounted) return;
    if (isFresh) {
      context.read<GameBloc?>()?.add(
        StreakActivityRecorded(StreakActivity.predict),
      );
    }
    // Snapshot what we just submitted as the saved baseline so the post-submit
    // review list opens with no pending draft — that's what surfaces the
    // OPEN PICKS dock. Editing an answer afterwards flips _hasDraftChanges
    // back on and swaps the dock to SAVE UPDATES.
    _savedAnswers = Map<String, int>.from(_answers);
    _savedMultipliersByQuestion = Map<String, PredictionMultiplier>.from(
      _multipliersByQuestion,
    );
    // The overlay drives the celebration; on completion its onDone lands us on
    // the review list (no longer pops the screen).
  }

  Future<void> _saveUpdates() async {
    final quizId = _quizId;
    if (quizId == null ||
        !_editable ||
        _savingUpdates ||
        !_hasDraftChanges ||
        !_allAnswered) {
      return;
    }
    _ensureScoreDefaults();
    playSound(SoundEffect.uiTap);
    setState(() => _savingUpdates = true);
    await context.read<PredictionCubit>().submit(
      _match.id,
      quizId,
      Map.of(_answers),
      multipliersByQuestion: Map.of(_multipliersByQuestion),
    );
    if (!mounted) return;
    setState(() {
      _savedAnswers = Map<String, int>.from(_answers);
      _savedMultipliersByQuestion = Map<String, PredictionMultiplier>.from(
        _multipliersByQuestion,
      );
      _savingUpdates = false;
    });
  }

  /// The best pick market for this fixture. Fresh quiz submit should hand the
  /// player into the same match's Picks surface, not a different quiz.
  PickMarket? _sameMatchPickMarket() {
    final picks = context.read<PicksCubit?>();
    if (picks == null) return null;
    final linked = picks.state.markets
        .where((market) => market.matchId == _match.id)
        .toList();
    if (linked.isEmpty) return null;
    linked.sort(_compareSameMatchMarkets);
    return linked.first;
  }

  /// Scores the stored answers locally (presentation), persists the
  /// settlement, credits the XP to progression, then plays the reveal
  /// cinematic. Rewards are credited up front so skipping changes nothing.
  Future<void> _startSettlementReveal(UserPrediction prediction) async {
    if (_settlementResults != null) return;
    final quiz = _quiz;
    if (quiz == null) return;
    final results = <SettlementQuestionResult>[];
    var correctCount = 0;
    var totalXp = 0;
    for (final question in quiz.questions) {
      final picked = prediction.answers[question.id];
      final correctAnswer = _correctAnswer(question);
      final correct =
          picked != null && correctAnswer != null && picked == correctAnswer;
      final multiplier = prediction.multipliersByQuestion[question.id];
      final earned = correct
          ? (multiplier?.applyTo(question.reward) ?? question.reward)
          : 0;
      if (correct) correctCount++;
      totalXp += earned;
      results.add(
        SettlementQuestionResult(
          text: question.text,
          pickedLabel: _answerLabel(question, picked),
          correctLabel: _answerLabel(question, correctAnswer),
          correct: correct,
          earnedXp: earned,
          multiplier: multiplier,
        ),
      );
    }
    final xpBefore = context.read<GameBloc>().state.progression.totalXP;
    final beatenShare = _leaderboard.isEmpty
        ? null
        : _leaderboard.where((e) => correctCount >= e.correct).length /
              _leaderboard.length;
    final earnedXp = await context.read<PredictionCubit>().settle(
      _match.id,
      prediction.quizId,
    );
    if (!mounted) return;
    if (earnedXp > 0) {
      context.read<GameBloc>().add(
        PredictionXpAdded(
          earnedXp,
          details:
              '${_match.home.shortName} vs ${_match.away.shortName} ${prediction.quizId}',
        ),
      );
    }
    setState(() {
      _settlementResults = results;
      _settlementXp = totalXp;
      _settlementXpBefore = xpBefore;
      _settlementBeatenShare = beatenShare;
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      children: [
        if (!widget.embedded)
          const Positioned.fill(
            child: CyberPlainBackground(child: SizedBox.expand()),
          ),
        Positioned.fill(
          child: widget.embedded
              ? _buildPredictionBody()
              : SafeArea(child: _buildPredictionBody()),
        ),
        if (_settlementResults != null)
          Positioned.fill(
            child: SettlementRevealOverlay(
              match: _match,
              results: _settlementResults!,
              totalXp: _settlementXp,
              xpBefore: _settlementXpBefore,
              beatenShare: _settlementBeatenShare,
              onDone: () {
                if (mounted) setState(() => _settlementResults = null);
              },
            ),
          ),
        if (_submitting)
          Positioned.fill(
            child: _SubmittedOverlay(
              potentialXp: _potentialXp,
              count: _questions.length,
              onDone: () {
                if (!mounted) return;
                // Release the hold so any queued achievement reveal plays over
                // the quiz-submitted list we land on (no longer pop home).
                _heldCelebrations?.release();
                _heldCelebrations = null;
                // The prediction now exists in state, so the rebuild routes
                // to _reviewContent — the all-questions list. _justSubmitted
                // makes the cards cascade in and shows the OPEN PICKS dock.
                setState(() {
                  _submitting = false;
                  _justSubmitted = true;
                });
              },
            ),
          ),
        if (!_loading && _questions.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _numberIntro,
                builder: (context, _) => _QuizNumberBurst(
                  number: _index + 1,
                  progress: _revealPhase == _QuizRevealPhase.numberIntro
                      ? _numberIntro.value
                      : 0,
                ),
              ),
            ),
          ),
      ],
    );

    if (widget.embedded) return content;

    return Scaffold(backgroundColor: Cyber.bg, body: content);
  }

  Widget _buildPredictionBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Cyber.cyan));
    }
    return BlocBuilder<PredictionCubit, PredictionState>(
      builder: (context, state) => _content(
        _quizId == null ? null : state.predictionFor(_match.id, _quizId!),
      ),
    );
  }

  Widget _content(UserPrediction? prediction) {
    if (_quiz == null) {
      if (widget.embedded && _quizzes.isNotEmpty) {
        return _quizSetHubContent();
      }
      return Column(
        children: [
          if (widget.showTopBar)
            _QuizTopBar(
              onBack: () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
          if (widget.showMatchHeader) ...[
            const SizedBox(height: 20),
            _QuizHeader(match: _match),
          ],
          Expanded(
            child: CyberNoDataState(
              icon: Icons.quiz_outlined,
              title: 'Quiz not live yet',
              message:
                  'Prediction questions will appear here when this match opens.',
              accent: Cyber.violet,
              spark: Icons.schedule,
            ),
          ),
        ],
      );
    }

    if (_questions.isEmpty) {
      return Column(
        children: [
          if (widget.showTopBar)
            _QuizTopBar(
              onBack: () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
          Expanded(
            child: CyberNoDataState(
              icon: Icons.quiz_outlined,
              title: 'Quiz not live yet',
              message:
                  'Prediction questions will appear here when this set opens.',
              accent: Cyber.violet,
              spark: Icons.schedule,
            ),
          ),
        ],
      );
    }

    if (prediction != null) {
      return _reviewContent(prediction);
    }

    if (widget.embedded && _quizzes.length > 1 && _showQuizHub) {
      return _quizSetHubContent();
    }

    final settled = prediction?.status == PredictionStatus.settled;
    final question = _questions[_index];
    final primary = _primaryButton(prediction, settled);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (question.backgroundAsset != null &&
            _revealPhase != _QuizRevealPhase.numberIntro)
          Positioned.fill(
            child: Opacity(
              opacity: _QuizQuestionPanelFrame.backgroundOpacity,
              child: Image.asset(
                question.backgroundAsset!,
                key: ValueKey(question.backgroundAsset),
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        Column(
          children: [
            _QuizChromeShell(
              edge: _QuizChromeEdge.top,
              child: Column(
                children: [
                  if (widget.showTopBar)
                    _QuizTopBar(
                      onBack: () =>
                          Navigator.of(context).popUntil((r) => r.isFirst),
                    ),
                  if (widget.showMatchHeader) ...[
                    const SizedBox(height: 20),
                    _QuizHeader(match: _match),
                  ],
                  if (widget.embedded && _quizzes.length > 1)
                    _AllQuizzesButton(onTap: _returnToQuizHub),
                  _LockLine(
                    match: _match,
                    untilLock: _untilLock,
                    trailing: _editable
                        ? _XpPotTicker(value: _bankedXp, max: _potentialXp)
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
                        ? _ScoreQuestionPanel(
                            key: ValueKey(question.id),
                            index: _index + 1,
                            question: question,
                            match: _match,
                            homeScore: _scoreFor(question.id).$1,
                            awayScore: _scoreFor(question.id).$2,
                            settled: settled,
                            editable: _editable && !_revealing,
                            selectedMultiplier:
                                _multipliersByQuestion[question.id],
                            multiplierOwners: _multiplierOwners,
                            multiplierEnabled:
                                _editable &&
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
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            child: _QuestionPanel(
                              index: _index + 1,
                              question: question,
                              selected: _answers[question.id],
                              settled: settled,
                              enabled: !_revealing,
                              selectedMultiplier:
                                  _multipliersByQuestion[question.id],
                              multiplierOwners: _multiplierOwners,
                              multiplierEnabled:
                                  _editable &&
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
            _QuizChromeShell(
              edge: _QuizChromeEdge.bottom,
              child: _BottomDock(
                questions: _questions,
                answers: _answers,
                index: _index,
                canGoPrevious: _index > 0 && !_revealing,
                onPrevious: _previous,
                primary: primary,
                helper: _helperText(prediction, settled),
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool _canSettle(UserPrediction prediction) =>
      _match.status == MatchStatus.finished &&
      (_quiz?.settleable ?? false) &&
      prediction.status != PredictionStatus.settled;

  Widget _quizSetHubContent() {
    return Column(
      children: [
        _QuizChromeShell(
          edge: _QuizChromeEdge.top,
          child: Column(
            children: [
              if (widget.showTopBar)
                _QuizTopBar(
                  onBack: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                ),
              if (widget.showMatchHeader) ...[
                const SizedBox(height: 20),
                _QuizHeader(match: _match),
              ],
              _LockLine(match: _match, untilLock: _untilLock),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
            children: [
              for (var i = 0; i < _quizzes.length; i++)
                Padding(
	                  padding: EdgeInsets.only(
	                    bottom: i == _quizzes.length - 1 ? 0 : 26,
	                  ),
                  child: _QuizSetHubCard(
                    match: _match,
                    quiz: _quizzes[i],
                    index: i + 1,
                    prediction: context
                        .read<PredictionCubit>()
                        .state
                        .predictionFor(_match.id, _quizzes[i].id),
                    onTap: () => _openQuizSet(_quizzes[i]),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _openQuizSet(PredictionQuiz quiz) {
    playSound(SoundEffect.uiTap);
    if (widget.embedded) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MatchPredictionScreen(match: _match, quizId: quiz.id),
        ),
      );
      return;
    }
    unawaited(_loadQuiz(quiz));
  }

  void _returnToQuizHub() {
    playSound(SoundEffect.uiTap);
    setState(() {
      _quiz = null;
      _showQuizHub = true;
      _answers.clear();
      _multipliersByQuestion.clear();
      _interactedScoreQuestions.clear();
      _savedAnswers = {};
      _savedMultipliersByQuestion = {};
      _expandedQuestions.clear();
      _settlementResults = null;
      _justSubmitted = false;
      _index = 0;
    });
  }

  Widget _reviewContent(UserPrediction prediction) {
    final editable = _editable;
    final readOnly = !editable;
    return Column(
      children: [
        if (widget.showTopBar)
          _QuizTopBar(
            onBack: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 18),
            itemCount: _questions.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Column(
                  children: [
                    if (widget.showMatchHeader) ...[
                      const SizedBox(height: 20),
                      _QuizHeader(match: _match),
                    ],
                    if (widget.embedded && _quizzes.length > 1)
                      _AllQuizzesButton(onTap: _returnToQuizHub),
                    _LockLine(match: _match, untilLock: _untilLock),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: _ReviewNotice(text: _reviewNotice(prediction)),
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              }

              final questionIndex = i - 1;
              final question = _questions[questionIndex];
              return StaggeredCardEntrance(
                index: questionIndex,
                // Cascade the cards in only right after a fresh submit; plain
                // revisits render instantly.
                animate: _justSubmitted,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    0,
                    20,
                    questionIndex == _questions.length - 1 ? 0 : 10,
                  ),
                  child: _ReviewQuestionCard(
                    index: questionIndex + 1,
                    question: question,
                    match: _match,
                    selected: _answers[question.id],
                    multiplier: _multipliersByQuestion[question.id],
                    multiplierOwners: _multiplierOwners,
                    votes: _votesByQuestion[question.id],
                    expanded: _expandedQuestions.contains(question.id),
                    editable: editable,
                    readOnly: readOnly,
                    finished: _match.status == MatchStatus.finished,
                    onToggle: () {
                      playSound(SoundEffect.uiTap);
                      setState(() {
                        if (!_expandedQuestions.add(question.id)) {
                          _expandedQuestions.remove(question.id);
                        }
                      });
                    },
                    onSelect: (answer) {
                      if (!editable) return;
                      playSound(SoundEffect.cardSelect);
                      setState(() => _answers[question.id] = answer);
                    },
                    onScoreChanged: (home, away) {
                      if (!editable) return;
                      playSound(SoundEffect.uiTap);
                      setState(() {
                        _answers[question.id] = ScoreAnswer.encode(home, away);
                      });
                    },
                    onMultiplierTap: (multiplier) =>
                        _toggleMultiplier(question.id, multiplier),
                  ),
                ),
              );
            },
          ),
        ),
        if (editable && _justSubmitted && !_hasDraftChanges)
          // Fresh submit, no edits yet: hand the player into the same match's
          // picks market when one exists.
          _OpenPicksDock(
            market: _sameMatchPickMarket(),
            onOpenPicks: widget.onOpenPicks,
          )
        else if (editable)
          _ReviewSaveDock(
            enabled: _hasDraftChanges && _allAnswered && !_savingUpdates,
            saving: _savingUpdates,
            onSave: _saveUpdates,
          )
        else if (_canSettle(prediction))
          _SettleDock(
            onSettle: () {
              playSound(SoundEffect.uiTap);
              _startSettlementReveal(prediction);
            },
          ),
      ],
    );
  }

  String _reviewNotice(UserPrediction prediction) {
    if (_editable) {
      return 'You can update answers until match starts.';
    }
    if (_canSettle(prediction)) {
      return 'Results are in. Reveal your verdicts to claim XP.';
    }
    if (_match.status == MatchStatus.finished ||
        prediction.status == PredictionStatus.settled) {
      return 'Final answers are in. Review results and crowd votes.';
    }
    return 'Predictions are locked. Review crowd votes as the match unfolds.';
  }

  /// The forward CTA's state for the current page. NEXT pages forward; the
  /// final page becomes SUBMIT (editable) or DONE (locked review). Settlement
  /// lives on the review screen's REVEAL RESULTS dock, not here.
  _PrimaryAction _primaryButton(UserPrediction? prediction, bool settled) {
    if (!_editable) {
      if (_isLast) {
        return _PrimaryAction(
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
      return _PrimaryAction(
        'NEXT',
        enabled: !_revealing,
        isNext: true,
        onTap: _revealing ? null : _next,
      );
    }
    if (_isLast) {
      return _PrimaryAction(
        'SUBMIT QUIZ',
        enabled: _allAnswered && !_revealing,
        onTap: _allAnswered && !_revealing ? _submit : null,
      );
    }
    final canAdvance = _currentAnswered && !_revealing;
    return _PrimaryAction(
      'NEXT',
      enabled: canAdvance,
      isNext: true,
      onTap: canAdvance ? _next : null,
    );
  }

  String _helperText(UserPrediction? prediction, bool settled) {
    if (settled) {
      final correct = prediction?.correctCount ?? 0;
      final reward = prediction?.rewardEarned ?? 0;
      return '$correct / ${_questions.length} correct  ·  +$reward XP';
    }
    if (!_editable) {
      return 'Predictions are locked — match in progress';
    }
    if (_allAnswered) {
      return 'All ${_questions.length} futures locked in - $_remainingBoostText';
    }
    return 'Complete all ${_questions.length} futures - $_remainingBoostText';
  }
}

// ── Top / bottom chrome that fades into the question backdrop ─────────────────
enum _QuizChromeEdge { top, bottom }

class _QuizChromeShell extends StatelessWidget {
  const _QuizChromeShell({required this.edge, required this.child});

  final _QuizChromeEdge edge;
  final Widget child;

  static const _opacity = 0.92;
  static const _fadeHeight = 40.0;

  @override
  Widget build(BuildContext context) {
    final solid = Cyber.bg.withValues(alpha: _opacity);
    final clear = Cyber.bg.withValues(alpha: 0);
    final gradient = edge == _QuizChromeEdge.top
        ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [solid, solid, solid.withValues(alpha: 0.35), clear],
            stops: const [0, 0.58, 0.82, 1],
          )
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [clear, solid.withValues(alpha: 0.35), solid, solid],
            stops: const [0, 0.18, 0.42, 1],
          );

    final fadePad = edge == _QuizChromeEdge.top
        ? const EdgeInsets.only(bottom: _fadeHeight)
        : const EdgeInsets.only(top: _fadeHeight);

    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: Padding(padding: fadePad, child: child),
    );
  }
}

// ── Top bar (collapse chevron) ────────────────────────────────────────────────
class _QuizTopBar extends StatelessWidget {
  const _QuizTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              playSound(SoundEffect.uiTap);
              onBack();
            },
            child: const SizedBox(
              width: 36,
              height: 56,
              child: Icon(Icons.arrow_back, color: Color(0xffd9e5f6), size: 24),
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Text(
              'Back to Matches',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontFamily: Cyber.bodyFont,
                fontWeight: FontWeight.w600,
                fontSize: 18,
                height: 1,
              ),
            ),
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
                style: Cyber.display(
                  15,
                  color: _statusColor,
                  letterSpacing: 1.5,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _HeaderBadge(team: match.home, cutBottomRight: true, sport: match.sport),
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
                  _HeaderBadge(team: match.away, cutBottomRight: false, sport: match.sport),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(height: 4, color: match.home.color),
                  ),
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
  const _HeaderBadge({required this.team, required this.cutBottomRight, this.sport});
  final SportTeam team;
  final bool cutBottomRight;
  final Sport? sport;

  @override
  Widget build(BuildContext context) {
    return TeamLogo(
      team: team,
      width: 44,
      height: 44,
      cutBottomRight: cutBottomRight,
      sport: sport,
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
  const _LockLine({
    required this.match,
    required this.untilLock,
    this.trailing,
  });
  final SportMatch match;
  final Duration untilLock;

  /// Optional second line (the potential-XP ticker while answering),
  /// stacked under the lock countdown.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final (icon, text, color) = switch (match.status) {
      MatchStatus.upcoming when untilLock > Duration.zero => (
        Icons.lock_clock,
        'QUIZ LOCKS IN ${_formatCountdown(untilLock)}',
        Cyber.gold,
      ),
      MatchStatus.finished => (Icons.flag_outlined, 'MATCH ENDED', Cyber.muted),
      _ => (Icons.lock_outline, 'PREDICTIONS LOCKED', Cyber.danger),
    };

    final lockLine = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: Cyber.label(
            11,
            color: color,
            letterSpacing: 1.4,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
      child: trailing == null
          ? Center(child: lockLine)
          : Column(children: [lockLine, const SizedBox(height: 7), trailing!]),
    );
  }
}

// ── Potential-XP pot ticker ───────────────────────────────────────────────────
/// The running "pot" in the quiz header: counts up as answers lock and
/// boosters land, toward the quiz's boosted max. Gold = reward, tabular
/// figures, a brief pulse on gains — no persistent glow.
class _XpPotTicker extends StatefulWidget {
  const _XpPotTicker({required this.value, required this.max});

  final int value;
  final int max;

  @override
  State<_XpPotTicker> createState() => _XpPotTickerState();
}

class _XpPotTickerState extends State<_XpPotTicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      reverseDuration: const Duration(milliseconds: 320),
    );
  }

  @override
  void didUpdateWidget(covariant _XpPotTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value > oldWidget.value) {
      _pulse.forward(from: 0).then((_) {
        if (mounted) _pulse.reverse();
      });
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.value.toDouble()),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      builder: (context, shown, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'POTENTIAL',
            style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.4),
          ),
          const SizedBox(width: 5),
          const Icon(Icons.bolt, size: 13, color: Cyber.gold),
          const SizedBox(width: 2),
          ScaleTransition(
            scale: Tween(
              begin: 1.0,
              end: 1.2,
            ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut)),
            child: Text(
              '${shown.round()}',
              style: Cyber.display(
                12,
                color: Cyber.gold,
                letterSpacing: 0.6,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
          Text(
            '/${widget.max} XP',
            style: Cyber.label(
              10,
              color: Cyber.muted,
              letterSpacing: 1.2,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}

// ── The single question panel ─────────────────────────────────────────────────
class _AllQuizzesButton extends StatelessWidget {
  const _AllQuizzesButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_back, color: Cyber.cyan, size: 16),
              const SizedBox(width: 6),
              Text(
                'ALL QUIZZES',
                style: Cyber.label(10, color: Cyber.cyan, letterSpacing: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizChamferPanelPainter extends CustomPainter {
  const _QuizChamferPanelPainter({
    required this.bigCut,
    required this.smallCut,
    required this.borderColor,
  });

  final double bigCut;
  final double smallCut;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final path = HudChamferClipper(
      bigCut: bigCut,
      smallCut: smallCut,
    ).buildPath(size);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = borderColor,
    );
  }

  @override
  bool shouldRepaint(covariant _QuizChamferPanelPainter old) =>
      old.bigCut != bigCut ||
      old.smallCut != smallCut ||
      old.borderColor != borderColor;
}

/// Resolved per-state look for a quiz-set hub card. Keeps the visual language
/// gamified: every state reads as an "objective" with a status tag, a reward
/// stake, a completion/accuracy meter and a call-to-action.
class _QuizHubVisual {
  const _QuizHubVisual({
    required this.accent,
    required this.tag,
    required this.progress,
    required this.progressAccent,
    required this.ctaIcon,
    required this.ctaText,
    required this.rewardText,
    required this.rewardColor,
    this.glow = false,
    this.pulse = false,
    this.showChevron = true,
    this.outcomes,
  });

  final Color accent;
  final String tag;
  final double progress;
  final Color progressAccent;
  final IconData ctaIcon;
  final String ctaText;
  final String rewardText;
  final Color rewardColor;

  /// Full-card glow — reserved for the reward-reveal "moment" only (glow rule).
  final bool glow;

  /// Beckon pulse (drives the reveal moment's breathing glow).
  final bool pulse;
  final bool showChevron;
  final List<QuestionOutcome>? outcomes;
}

_QuizHubVisual _resolveQuizHubVisual(
  SportMatch match,
  PredictionQuiz quiz,
  UserPrediction? prediction,
) {
  final total = quiz.questions.length;
  final answered = prediction?.answers.length ?? 0;
  final potentialXp = quiz.maxReward;
  final settled = prediction?.status == PredictionStatus.settled;
  final locked = prediction?.status == PredictionStatus.locked;

  // Finished + settled → verdict card (calm; the moment already happened).
  if (match.status == MatchStatus.finished && settled) {
    final correct = prediction!.correctCount ?? 0;
    final won = correct > 0;
    final earned = prediction.rewardEarned;
    return _QuizHubVisual(
      accent: won ? Cyber.gold : Cyber.muted,
      tag: 'SETTLED',
      progress: total == 0 ? 0 : correct / total,
      progressAccent: won ? Cyber.success : Cyber.muted,
      ctaIcon: won ? Icons.military_tech : Icons.done_all,
      ctaText: '$correct / $total CORRECT',
      rewardText: earned > 0 ? '+$earned XP' : 'NO XP',
      rewardColor: earned > 0 ? Cyber.success : Cyber.muted,
      showChevron: false,
      outcomes: questionOutcomes(quiz, prediction),
    );
  }

  // Finished + rewards waiting → the ONE glowing focal moment on the screen.
  if (match.status == MatchStatus.finished &&
      (prediction != null || quiz.settleable)) {
    return const _QuizHubVisual(
      accent: Cyber.gold,
      tag: 'REWARD READY',
      progress: 1,
      progressAccent: Cyber.gold,
      ctaIcon: Icons.redeem,
      ctaText: 'TAP TO REVEAL RESULTS',
      rewardText: 'REVEAL',
      rewardColor: Cyber.gold,
      glow: true,
      pulse: true,
    );
  }

  // Finished, no entry → closed/expired.
  if (match.status == MatchStatus.finished) {
    return const _QuizHubVisual(
      accent: Cyber.muted,
      tag: 'CLOSED',
      progress: 0,
      progressAccent: Cyber.muted,
      ctaIcon: Icons.flag_outlined,
      ctaText: 'RESULT RECORDED · NO ENTRY',
      rewardText: 'MISSED',
      rewardColor: Cyber.muted,
      showChevron: false,
    );
  }

  // Live / locked → predictions closed while the match runs.
  if (match.status == MatchStatus.live || locked) {
    return _QuizHubVisual(
      accent: Cyber.danger,
      tag: match.status == MatchStatus.live ? 'LIVE' : 'LOCKED',
      progress: total == 0 ? 0 : answered / total,
      progressAccent: Cyber.danger,
      ctaIcon: Icons.lock_outline,
      ctaText: 'LOCKED · MATCH IN PROGRESS',
      rewardText: prediction != null ? 'IN PLAY' : 'CLOSED',
      rewardColor: Cyber.danger,
      showChevron: false,
    );
  }

  // Upcoming + already predicted → locked-in / resume.
  if (prediction != null) {
    final complete = answered >= total;
    return _QuizHubVisual(
      accent: Cyber.lime,
      tag: complete ? 'LOCKED IN' : 'IN PROGRESS',
      progress: total == 0 ? 0 : answered / total,
      progressAccent: Cyber.lime,
      ctaIcon: complete ? Icons.verified : Icons.edit,
      ctaText: complete
          ? 'PREDICTION SET · TAP TO EDIT'
          : 'RESUME · $answered/$total ANSWERED',
      rewardText: '+$potentialXp XP',
      rewardColor: Cyber.gold,
    );
  }

  // Upcoming, fresh objective → the actionable entry point.
  return _QuizHubVisual(
    accent: Cyber.cyan,
    tag: 'OBJECTIVE',
    progress: 0,
    progressAccent: Cyber.cyan,
    ctaIcon: Icons.bolt,
    ctaText: 'TAP TO PREDICT · $total QUESTIONS',
    rewardText: '+$potentialXp XP',
    rewardColor: Cyber.gold,
  );
}

/// Hard (un-blurred) offset copy of the hub-card silhouette, drawn behind the
/// card and shifted straight down so its bottom peeks out as a solid thick
/// edge — the "embossed" elevation used by the home fixture cards.
class _QuizHubHardShadowPainter extends CustomPainter {
  const _QuizHubHardShadowPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final path = const HudChamferClipper(bigCut: 12, smallCut: 3)
        .buildPath(size)
        .shift(const Offset(0, 5));
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _QuizHubHardShadowPainter old) =>
      old.color != color;
}

class _QuizSetHubCard extends StatefulWidget {
  const _QuizSetHubCard({
    required this.match,
    required this.quiz,
    required this.index,
    required this.prediction,
    required this.onTap,
  });

  final SportMatch match;
  final PredictionQuiz quiz;
  final int index;
  final UserPrediction? prediction;
  final VoidCallback onTap;

  @override
  State<_QuizSetHubCard> createState() => _QuizSetHubCardState();
}

class _QuizSetHubCardState extends State<_QuizSetHubCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _resolveQuizHubVisual(widget.match, widget.quiz, widget.prediction);

    // Only the reward-reveal moment breathes; everything else is still.
    if (v.pulse && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!v.pulse && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }

    return Semantics(
      button: true,
      label: 'Open ${widget.quiz.title}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(_pulse.value);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Hard, un-blurred offset edge behind the card — a solid thick
                // bottom border that reads as elevation (matches the home
                // fixture cards), tinted to the card's state accent.
                Positioned.fill(
                  child: CustomPaint(
                    painter: _QuizHubHardShadowPainter(
                      v.accent.withValues(alpha: 0.30),
                    ),
                  ),
                ),
                // The reveal moment adds a soft pulsing accent glow on top.
                if (v.glow)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: Cyber.glow(
                        v.accent,
                        alpha: 0.18 + 0.22 * t,
                        blur: 18 + 8 * t,
                        spread: -3,
                      ),
                    ),
                    child: child,
                  )
                else
                  child!,
              ],
            );
          },
          child: CustomPaint(
            painter: _QuizChamferPanelPainter(
              bigCut: 12,
              smallCut: 3,
              borderColor: v.accent.withValues(alpha: v.glow ? 0.6 : 0.4),
            ),
            child: ClipPath(
              clipper: const HudChamferClipper(bigCut: 12, smallCut: 3),
              child: Container(
                decoration: BoxDecoration(
                  // Team-vs-team wash: each corner carries its team's colour at
                  // 16% composited over the #06152B base, so the card reads as
                  // "this fixture" while text stays legible.
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.alphaBlend(
                        widget.match.home.color.withValues(alpha: 0.16),
                        _hubCardBase,
                      ),
                      Color.alphaBlend(
                        widget.match.away.color.withValues(alpha: 0.16),
                        _hubCardBase,
                      ),
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 84),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _IndexPlate(index: widget.index, accent: v.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        v.tag,
                                        style: Cyber.label(
                                          8.5,
                                          color: v.accent,
                                          letterSpacing: 1.6,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.quiz.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Cyber.display(
                                          14.5,
                                          color: Colors.white,
                                          letterSpacing: 0.2,
                                        ).copyWith(height: 1.2),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _RewardPill(
                                  text: v.rewardText,
                                  color: v.rewardColor,
                                ),
                              ],
                            ),
                            if (widget.quiz.subtitle != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                widget.quiz.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Cyber.body(11.5, color: Cyber.muted),
                              ),
                            ],
                            const SizedBox(height: 11),
                            CyberProgressBar(
                              value: v.progress.clamp(0.0, 1.0),
                              accent: v.progressAccent,
                              height: 6,
                              trackColor: Colors.black.withValues(alpha: 0.35),
                              trackBorderColor:
                                  v.accent.withValues(alpha: 0.22),
                            ),
                            const SizedBox(height: 10),
                            _HubDivider(accent: v.accent),
                            const SizedBox(height: 9),
                            Row(
                              children: [
                                Icon(v.ctaIcon, color: v.accent, size: 14),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    v.ctaText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Cyber.label(
                                      9,
                                      color: v.accent,
                                      letterSpacing: 1,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ).copyWith(
                                      shadows: v.pulse
                                          ? [
                                              Shadow(
                                                color: v.accent.withValues(
                                                  alpha: 0.5,
                                                ),
                                                blurRadius: 10,
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (v.outcomes != null)
                                  _HubOutcomeDots(
                                    outcomes: v.outcomes!,
                                    compact: true,
                                  )
                                else if (v.showChevron)
                                  _ChevronChip(accent: v.accent),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Chamfered "mission number" plate on the left edge of a quiz-set hub card.
class _IndexPlate extends StatelessWidget {
  const _IndexPlate({required this.index, required this.accent});

  final int index;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: CustomPaint(
        painter: _QuizChamferPanelPainter(
          bigCut: 8,
          smallCut: 2,
          borderColor: accent.withValues(alpha: 0.6),
        ),
        child: ClipPath(
          clipper: const HudChamferClipper(bigCut: 8, smallCut: 2),
          child: Container(
            alignment: Alignment.center,
            color: accent.withValues(alpha: 0.16),
            child: Text(
              index.toString().padLeft(2, '0'),
              style: Cyber.display(
                15,
                color: accent,
                letterSpacing: 0,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
        ),
      ),
    );
  }
}

/// The XP / status stake shown top-right of a quiz-set hub card.
class _RewardPill extends StatelessWidget {
  const _RewardPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: Cyber.label(
          9,
          color: color,
          letterSpacing: 0.6,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Calm state-tinted hairline separating the meter from the CTA line. Fades in
/// from the edges so it reads as HUD chrome, not a hard rule (and never glows).
class _HubDivider extends StatelessWidget {
  const _HubDivider({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            accent.withValues(alpha: 0.35),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

/// Chamfered "go" affordance for actionable quiz-set hub cards.
class _ChevronChip extends StatelessWidget {
  const _ChevronChip({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 26,
      child: CustomPaint(
        painter: _QuizChamferPanelPainter(
          bigCut: 6,
          smallCut: 2,
          borderColor: accent.withValues(alpha: 0.55),
        ),
        child: ClipPath(
          clipper: const HudChamferClipper(bigCut: 6, smallCut: 2),
          child: Container(
            color: accent.withValues(alpha: 0.14),
            alignment: Alignment.center,
            child: Icon(Icons.arrow_forward, size: 15, color: accent),
          ),
        ),
      ),
    );
  }
}

class _ReviewNotice extends StatelessWidget {
  const _ReviewNotice({required this.text});

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

class _ReviewQuestionCard extends StatelessWidget {
  const _ReviewQuestionCard({
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
    final selectedLabel = _answerLabel(question, selected);
    final correct = _correctAnswer(question);
    final selectedCorrect = selected != null && selected == correct;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_panelTop, _panelBottom],
        ),
        border: Border.all(color: _panelBorder),
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
                        _MultiplierBadge(multiplier: multiplier!),
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
                      'CORRECT ANSWER: ${_answerLabel(question, correct)}',
                      style: Cyber.label(
                        10,
                        color: Cyber.success,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _EarnedXpLine(
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
    final boostSelector = _BoostSelector(
      questionId: question.id,
      selected: multiplier,
      owners: multiplierOwners,
      enabled: selected != null,
      onTap: onMultiplierTap,
    );
    if (question.isScorePrediction) {
      final score = selected == null ? (home: 0, away: 0) : _decode(selected!);
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
    final answers = _pollAnswers(question, votes, selected);
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
            child: _MultiplierBadge(multiplier: multiplier!),
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
              label: _answerLabel(question, answer),
              votes: votes?.votesFor(answer) ?? 0,
              share: votes?.shareFor(answer) ?? 0,
              selected: selected == answer,
              correct: finished && _correctAnswer(question) == answer,
            ),
          ),
      ],
    );
  }
}

class _MultiplierBadge extends StatelessWidget {
  const _MultiplierBadge({required this.multiplier});

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

class _EarnedXpLine extends StatelessWidget {
  const _EarnedXpLine({required this.earned, required this.boosted});

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

class _ReviewSaveDock extends StatelessWidget {
  const _ReviewSaveDock({
    required this.enabled,
    required this.saving,
    required this.onSave,
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

/// Focal dock shown right after a fresh submit: moves the player straight into
/// the same match's pick market. If no market is linked yet, it drops them back
/// to the matches list.
class _OpenPicksDock extends StatelessWidget {
  const _OpenPicksDock({required this.market, this.onOpenPicks});

  final PickMarket? market;
  final VoidCallback? onOpenPicks;

  @override
  Widget build(BuildContext context) {
    final market = this.market;
    final label = market == null ? 'BACK TO MATCHES' : 'OPEN PICKS';
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 22),
        child: HudPagerButton(
          label: label,
          focal: true,
          enabled: true,
          trailingIcon: Icons.keyboard_double_arrow_right,
          onTap: () {
            playSound(SoundEffect.playMatch);
            if (onOpenPicks != null) {
              onOpenPicks!();
              return;
            }
            if (market == null) {
              Navigator.of(context).popUntil((r) => r.isFirst);
            } else {
              PredictionCubit? prediction;
              try {
                prediction = context.read<PredictionCubit>();
              } on ProviderNotFoundException {
                prediction = null;
              }
              // Replace so quiz→picks→quiz does not grow the back stack.
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) {
                    final screen = MarketDetailScreen(marketId: market.id);
                    if (prediction == null) return screen;
                    return BlocProvider<PredictionCubit>.value(
                      value: prediction,
                      child: screen,
                    );
                  },
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

/// Focal dock on a finished, settleable review: launches the settlement
/// reveal cinematic.
class _SettleDock extends StatelessWidget {
  const _SettleDock({required this.onSettle});

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

class _QuizNumberBurst extends StatelessWidget {
  const _QuizNumberBurst({required this.number, required this.progress});

  final int number;
  final double progress;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0) return const SizedBox.shrink();

    final p = progress.clamp(0.0, 1.0);
    final double scale;
    final double opacity;
    if (p < 0.25) {
      scale = 2.0 - Curves.easeOutBack.transform(p / 0.25);
      opacity = 1.0;
    } else if (p < 0.82) {
      scale = 1.0;
      opacity = 1.0;
    } else {
      final t = (p - 0.82) / 0.18;
      scale = 1.0 + 0.18 * t;
      opacity = 1.0 - t;
    }
    final glow = (1 - (p / 0.45).clamp(0.0, 1.0)) * 0.85 + 0.15;

    return ColoredBox(
      color: Cyber.bg.withValues(alpha: (0.86 * opacity).clamp(0.0, 0.86)),
      child: Center(
        child: Transform.scale(
          scale: scale.clamp(0.4, 2.5),
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Text(
              '$number',
              style: TextStyle(
                color: Cyber.lime,
                fontFamily: 'Orbitron',
                fontSize: 128,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: Cyber.lime.withValues(alpha: glow),
                    blurRadius: 52,
                  ),
                  Shadow(
                    color: Cyber.cyan.withValues(alpha: glow * 0.55),
                    blurRadius: 80,
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

  static const backgroundOpacity = 0.5;

  @override
  Widget build(BuildContext context) {
    final hasBackground = backgroundAsset != null;

    return Container(
      width: double.infinity,
      margin: margin,
      decoration: BoxDecoration(
        color: hasBackground
            ? _panelBottom.withValues(alpha: _quizSurfaceOpacity)
            : null,
        gradient: hasBackground
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_panelTop, _panelBottom],
              ),
        border: Border.all(color: _panelBorder),
      ),
      clipBehavior: Clip.hardEdge,
      child: Padding(padding: padding, child: child),
    );
  }
}

class _QuestionPanel extends StatelessWidget {
  const _QuestionPanel({
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
          margin: const EdgeInsets.only(top: 30),
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
              _BoostSelector(
                questionId: question.id,
                selected: selectedMultiplier,
                owners: multiplierOwners,
                enabled: multiplierEnabled,
                onTap: onMultiplierTap,
                showLabel: false,
              ),
              const SizedBox(width: 4),
              _XpPill(
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
          top: 18,
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _QuizQuestionPanelFrame(
            backgroundAsset: question.backgroundAsset,
            margin: const EdgeInsets.only(top: 30),
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
                _BoostSelector(
                  questionId: question.id,
                  selected: selectedMultiplier,
                  owners: multiplierOwners,
                  enabled: multiplierEnabled,
                  onTap: onMultiplierTap,
                  showLabel: false,
                ),
                const SizedBox(width: 4),
                _XpPill(
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
            top: 18,
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

class _BoostSelector extends StatelessWidget {
  const _BoostSelector({
    required this.questionId,
    required this.selected,
    required this.owners,
    required this.enabled,
    required this.onTap,
    this.showLabel = true,
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

class _XpPill extends StatelessWidget {
  const _XpPill({required this.reward, this.multiplier});
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

enum _OptionVisual { idle, selected, correct, wrong }

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
    final fill = active
        ? Color.alphaBlend(accent.withValues(alpha: 0.10), _optionFill)
        : _optionFill;
    return GestureDetector(
      key: tileKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
        decoration: BoxDecoration(
          color: fill.withValues(alpha: _quizSurfaceOpacity),
          border: Border.all(
            color: active ? accent : _optionBorder,
            width: active ? 1.5 : 1,
          ),
          boxShadow: state == _OptionVisual.selected
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
                color: active ? accent.withValues(alpha: 0.20) : _letterFill,
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
  bool _slammed = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );
    playSound(SoundEffect.whoosh);
    // Ticker-driven (no timers) so this stays test-friendly: the seal slams
    // into place ~225ms in, the instant it lands.
    _c.addListener(() {
      if (_slammed || _c.value < 0.05) return;
      _slammed = true;
      playSound(SoundEffect.cardSlam);
      HapticFeedback.heavyImpact();
    });
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
    _c.forward();
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
        // The seal slams in (elastic overshoot), a confirm pulse breathes out
        // once, a radar arc sweeps the ring and the checkmark draws itself in —
        // then the headline resolves and the XP charges up. One focal seal,
        // sequenced beats — no radial rays, no confetti.
        final pop = Curves.elasticOut.transform((t / 0.18).clamp(0.0, 1.0));
        final flash = (1 - t / 0.10).clamp(0.0, 1.0); // soft cyan lock flash
        final pulse = ((t - 0.06) / 0.24).clamp(
          0.0,
          1.0,
        ); // single confirm ring
        final sweep = Curves.easeOutCubic.transform(
          ((t - 0.08) / 0.34).clamp(0.0, 1.0),
        );
        final check = Curves.easeOutCubic.transform(
          ((t - 0.18) / 0.18).clamp(0.0, 1.0),
        );
        // The headline reveals one letter at a time across this window.
        final headlineT = ((t - 0.14) / 0.26).clamp(0.0, 1.0);
        final textIn = ((t - 0.18) / 0.12).clamp(0.0, 1.0);
        final xpT = Curves.easeOut.transform(
          ((t - 0.24) / 0.30).clamp(0.0, 1.0),
        );
        final xpValue = (widget.potentialXp * xpT).round();
        // A long satisfying hold on the locked seal before the scrim fades.
        final scrim = (t < 0.86 ? 1.0 : (1 - (t - 0.86) / 0.14)).clamp(
          0.0,
          1.0,
        );
        return Opacity(
          opacity: scrim,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: Cyber.bg.withValues(alpha: 0.92)),
              // CRT scanlines + vignette so the dark scrim reads as filmed HUD,
              // not a flat fill.
              const Positioned.fill(
                child: IgnorePointer(child: CyberTextureOverlay()),
              ),
              // ── Seal cluster, riding a touch above centre ──────────────────
              Align(
                alignment: const Alignment(0, -0.22),
                child: Transform.scale(
                  scale: pop,
                  child: SizedBox(
                    width: 240,
                    height: 240,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        // Soft cyan lock flash at the instant it lands.
                        Opacity(
                          opacity: flash * 0.65,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Cyber.cyan.withValues(alpha: 0.7),
                                  Cyber.cyan.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Single confirm pulse ring (expands once, fades).
                        if (pulse > 0 && pulse < 1)
                          Opacity(
                            opacity: (1 - pulse) * 0.7,
                            child: Transform.scale(
                              scale: 0.45 + pulse * 1.25,
                              child: Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Cyber.cyan.withValues(alpha: 0.6),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // The HUD seal: chamfered plate, corner brackets, a
                        // radar sweep ring and the checkmark drawing itself in.
                        CustomPaint(
                          size: const Size(240, 240),
                          painter: _SubmitSealPainter(
                            sweep: sweep,
                            check: check,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // ── Headline + XP charge, below the seal ───────────────────────
              Align(
                alignment: const Alignment(0, 0.18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _SubmittedHeadline(
                        text: 'PREDICTION SUBMITTED',
                        progress: headlineT,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Opacity(
                      opacity: textIn,
                      child: Text(
                        '${widget.count} ANSWERS LOCKED IN',
                        style: Cyber.label(
                          11,
                          color: Cyber.muted,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Opacity(
                      opacity: textIn,
                      child: SizedBox(
                        width: 188,
                        child: CyberProgressBar(
                          value: xpT,
                          accent: Cyber.gold,
                          height: 6,
                          animate: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Opacity(
                      opacity: textIn,
                      child: Text(
                        'UP TO $xpValue XP',
                        style:
                            Cyber.label(
                              13,
                              color: Cyber.gold,
                              letterSpacing: 1.6,
                            ).copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The submit seal: a chamfered HUD plate ringed by corner brackets, a radar
/// [sweep] arc that completes into a glowing ring, and a checkmark that draws
/// itself in over [check]. This is the one focal "moment" element, so it earns
/// the glow (per THE GLOW RULE).
class _SubmitSealPainter extends CustomPainter {
  const _SubmitSealPainter({required this.sweep, required this.check});

  final double sweep; // 0..1 radar sweep around the ring
  final double check; // 0..1 checkmark stroke draw-on

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const half = 44.0; // plate is 88×88
    const cut = 13.0; // diagonal corner chamfer (signature shape)

    // Chamfered HUD plate — top-right and bottom-left cut for an off-axis,
    // hand-built feel rather than a symmetric box.
    final plate = Path()
      ..moveTo(center.dx - half, center.dy - half)
      ..lineTo(center.dx + half - cut, center.dy - half)
      ..lineTo(center.dx + half, center.dy - half + cut)
      ..lineTo(center.dx + half, center.dy + half)
      ..lineTo(center.dx - half + cut, center.dy + half)
      ..lineTo(center.dx - half, center.dy + half - cut)
      ..close();

    // Focal glow under the plate.
    canvas.drawPath(
      plate,
      Paint()
        ..color = Cyber.cyan.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    // Fill with a vertical gradient for depth (not a flat tint).
    canvas.drawPath(
      plate,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Cyber.cyan.withValues(alpha: 0.20),
            Cyber.cyan.withValues(alpha: 0.05),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: half)),
    );
    canvas.drawPath(
      plate,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Cyber.cyan.withValues(alpha: 0.85),
    );

    // Corner brackets just outside the plate.
    const bo = half + 12; // bracket offset from centre
    const bl = 14.0; // bracket arm length
    final bp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = Cyber.cyan.withValues(alpha: 0.55);
    void bracket(double sx, double sy) {
      final c = center + Offset(sx * bo, sy * bo);
      canvas.drawLine(c, c + Offset(-sx * bl, 0), bp);
      canvas.drawLine(c, c + Offset(0, -sy * bl), bp);
    }

    bracket(-1, -1);
    bracket(1, -1);
    bracket(1, 1);
    bracket(-1, 1);

    // Radar ring: a faint full track + a glowing arc that sweeps around, with a
    // bright head dot while it travels.
    const ringR = half + 28;
    final ringRect = Rect.fromCircle(center: center, radius: ringR);
    canvas.drawCircle(
      center,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Cyber.cyan.withValues(alpha: 0.12),
    );
    const start = -pi / 2;
    if (sweep > 0) {
      canvas.drawArc(
        ringRect,
        start,
        sweep * 2 * pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..color = Cyber.cyan.withValues(alpha: 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      if (sweep < 1) {
        final a = start + sweep * 2 * pi;
        final tip = center + Offset(cos(a) * ringR, sin(a) * ringR);
        canvas.drawCircle(
          tip,
          6,
          Paint()
            ..color = Cyber.cyan.withValues(alpha: 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        canvas.drawCircle(tip, 3, Paint()..color = Colors.white);
      }
    }

    // Checkmark, drawn on with a path-metric reveal.
    if (check > 0) {
      final tick = Path()
        ..moveTo(center.dx - 20, center.dy + 1)
        ..lineTo(center.dx - 6, center.dy + 16)
        ..lineTo(center.dx + 22, center.dy - 18);
      final drawn = Path();
      for (final m in tick.computeMetrics()) {
        drawn.addPath(m.extractPath(0, m.length * check), Offset.zero);
      }
      // Glow pass then the bright stroke.
      canvas.drawPath(
        drawn,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Cyber.cyan.withValues(alpha: 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawPath(
        drawn,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SubmitSealPainter old) =>
      old.sweep != sweep || old.check != check;
}

/// The submit headline revealed one letter at a time — a clean staggered fade +
/// rise as [progress] goes 0 → 1. No chromatic ghosts (so nothing overlaps), and
/// kept to a single line via [FittedBox] so it never wraps on narrow screens.
class _SubmittedHeadline extends StatelessWidget {
  const _SubmittedHeadline({required this.text, required this.progress});

  final String text;
  final double progress; // 0..1 overall reveal

  @override
  Widget build(BuildContext context) {
    final chars = text.split('');
    final n = chars.length;
    final style = Cyber.display(22, color: Colors.white, letterSpacing: 1.5)
        .copyWith(
          shadows: [
            Shadow(color: Cyber.cyan.withValues(alpha: 0.55), blurRadius: 14),
          ],
        );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < n; i++)
            if (chars[i] == ' ')
              const SizedBox(width: 10)
            else
              _Letter(
                char: chars[i],
                style: style,
                // Each letter starts a touch after the previous; all land by 1.
                local: Curves.easeOutCubic.transform(
                  ((progress - (i / n) * 0.55) / 0.45).clamp(0.0, 1.0),
                ),
              ),
        ],
      ),
    );
  }
}

class _Letter extends StatelessWidget {
  const _Letter({required this.char, required this.style, required this.local});

  final String char;
  final TextStyle style;
  final double local; // 0..1 this letter's reveal

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: local,
      child: Transform.translate(
        offset: Offset(0, (1 - local) * 12),
        child: Text(char, style: style),
      ),
    );
  }
}

// ── Helpers + palette ─────────────────────────────────────────────────────────
({int home, int away}) _decode(int encoded) {
  final (home, away) = ScoreAnswer.decode(encoded);
  return (home: home, away: away);
}

String _answerLabel(QuizQuestion question, int? answer) {
  if (answer == null) return 'Not answered';
  if (question.isScorePrediction) {
    final (home, away) = ScoreAnswer.decode(answer);
    return '$home - $away';
  }
  if (answer < 0 || answer >= question.options.length) return 'Unknown';
  return question.options[answer];
}

int? _correctAnswer(QuizQuestion question) => question.isScorePrediction
    ? question.settledScoreEncoded
    : question.settledOptionIndex;

List<int> _pollAnswers(
  QuizQuestion question,
  PredictionVoteBreakdown? votes,
  int? selected,
) {
  if (!question.isScorePrediction) {
    return [for (var i = 0; i < question.options.length; i++) i];
  }
  final answers = <int>{...votes?.totals.keys ?? const <int>[]};
  if (selected != null) answers.add(selected);
  final correct = question.settledScoreEncoded;
  if (correct != null) answers.add(correct);
  final sorted = answers.toList()
    ..sort(
      (a, b) => (votes?.votesFor(b) ?? 0).compareTo(votes?.votesFor(a) ?? 0),
    );
  return sorted.take(5).toList();
}

bool _sameAnswers(Map<String, int> a, Map<String, int> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

bool _sameMultipliers(
  Map<String, PredictionMultiplier> a,
  Map<String, PredictionMultiplier> b,
) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

int _compareSameMatchMarkets(PickMarket a, PickMarket b) {
  final typeRank = _sameMatchMarketTypeRank(
    a,
  ).compareTo(_sameMatchMarketTypeRank(b));
  if (typeRank != 0) return typeRank;
  final openRank = (a.canBuy ? 0 : 1).compareTo(b.canBuy ? 0 : 1);
  if (openRank != 0) return openRank;
  return a.closesAt.compareTo(b.closesAt);
}

int _sameMatchMarketTypeRank(PickMarket market) =>
    market.type == PickMarketType.match ? 0 : 1;

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
// Solid base the team-colour wash sits over on quiz-set hub cards.
const _hubCardBase = Color(0xff06152b);
const _panelBorder = Color(0xff2a3550);
const _quizSurfaceOpacity = 0.90;
const _optionFill = Color(0xff0f1826);
const _optionBorder = Color(0xff283448);
const _letterFill = Color(0xff1a2434);

class _HubOutcomeDots extends StatelessWidget {
  const _HubOutcomeDots({required this.outcomes, this.compact = false});

  final List<QuestionOutcome> outcomes;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final gap = compact ? 4.0 : 5.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < outcomes.length; i++) ...[
          _HubOutcomeDot(outcome: outcomes[i], compact: compact),
          if (i != outcomes.length - 1) SizedBox(width: gap),
        ],
      ],
    );
  }
}

class _HubOutcomeDot extends StatelessWidget {
  const _HubOutcomeDot({required this.outcome, required this.compact});

  final QuestionOutcome outcome;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = switch (outcome) {
      QuestionOutcome.correct => Cyber.success,
      QuestionOutcome.wrong => Cyber.red,
      QuestionOutcome.pending => Cyber.muted,
    };
    final icon = switch (outcome) {
      QuestionOutcome.correct => Icons.check,
      QuestionOutcome.wrong => Icons.close,
      QuestionOutcome.pending => Icons.more_horiz,
    };
    final box = compact ? 13.0 : 17.0;
    final iconSize = compact ? 9.0 : 11.0;
    return Container(
      width: box,
      height: box,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}
