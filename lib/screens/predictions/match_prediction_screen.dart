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
import '../../widgets/team_logo.dart';
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

enum _QuizRevealPhase { numberIntro, questionReveal, optionsReveal, ready }

class _MatchPredictionScreenState extends State<MatchPredictionScreen>
    with TickerProviderStateMixin {
  PredictionQuiz? _quiz;
  bool _loading = true;
  bool _submitting = false;
  bool _savingUpdates = false;
  int _index = 0;
  final Map<String, int> _answers = {};
  Map<String, int> _savedAnswers = {};
  final Map<String, PredictionMultiplier> _multipliersByQuestion = {};
  Map<String, PredictionMultiplier> _savedMultipliersByQuestion = {};
  final Set<String> _expandedQuestions = {};
  Map<String, PredictionVoteBreakdown> _votesByQuestion = {};
  List<MatchPredictionLeaderboardEntry> _leaderboard = const [];
  Timer? _ticker;
  DateTime _now = DateTime.now();
  _QuizRevealPhase _revealPhase = _QuizRevealPhase.ready;
  int _revealRun = 0;

  late final AnimationController _numberIntro;
  late final AnimationController _questionReveal;
  late final AnimationController _optionsReveal;

  SportMatch get _match => widget.match;
  bool get _editable => _match.predictable;

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
    _numberIntro.dispose();
    _questionReveal.dispose();
    _optionsReveal.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cubit = context.read<PredictionCubit>();
    final quiz = await cubit.quizFor(_match.id);
    final existing = cubit.state.predictionFor(_match.id);
    if (existing != null) {
      _answers.addAll(existing.answers);
      _multipliersByQuestion.addAll(existing.multipliersByQuestion);
    }
    final votes = <String, PredictionVoteBreakdown>{};
    if (quiz != null) {
      for (final question in quiz.questions) {
        final vote = await cubit.votesFor(_match.id, question.id);
        if (vote != null) votes[question.id] = vote;
      }
    }
    final leaderboard = await cubit.matchLeaderboard(_match.id);
    if (!mounted) return;
    setState(() {
      _quiz = quiz;
      _loading = false;
      _votesByQuestion = votes;
      _leaderboard = leaderboard;
      _ensureScoreDefaults();
      _savedAnswers = Map<String, int>.from(_answers);
      _savedMultipliersByQuestion = Map<String, PredictionMultiplier>.from(
        _multipliersByQuestion,
      );
      if (existing != null && !_match.predictable && quiz != null) {
        _expandedQuestions
          ..clear()
          ..addAll(quiz.questions.map((q) => q.id));
      }
    });
    if (_questions.isNotEmpty && existing == null) {
      _runForwardReveal();
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
    setState(() => _submitting = true);
    await context.read<PredictionCubit>().submit(
      _match.id,
      Map.of(_answers),
      multipliersByQuestion: Map.of(_multipliersByQuestion),
    );
    // The overlay drives the celebration; it pops the screen when done.
  }

  Future<void> _saveUpdates() async {
    if (!_editable || _savingUpdates || !_hasDraftChanges || !_allAnswered) {
      return;
    }
    _ensureScoreDefaults();
    playSound(SoundEffect.uiTap);
    setState(() => _savingUpdates = true);
    await context.read<PredictionCubit>().submit(
      _match.id,
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
                potentialXp: _potentialXp,
                count: _questions.length,
                onDone: () {
                  if (mounted) Navigator.of(context).pop();
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
      ),
    );
  }

  Widget _content(UserPrediction? prediction) {
    if (_quiz == null || _questions.isEmpty) {
      return Column(
        children: [
          _QuizTopBar(
            onBack: () => Navigator.of(context).popUntil((r) => r.isFirst),
            onLeaderboard: _showMatchLeaderboard,
          ),
          const SizedBox(height: 20),
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

    if (prediction != null) {
      return _reviewContent(prediction);
    }

    final settled = prediction?.status == PredictionStatus.settled;
    final question = _questions[_index];
    final primary = _primaryButton(prediction, settled);

    return Column(
      children: [
        _QuizTopBar(
          onBack: () => Navigator.of(context).popUntil((r) => r.isFirst),
          onLeaderboard: _showMatchLeaderboard,
        ),
        const SizedBox(height: 20),
        _QuizHeader(match: _match),
        _LockLine(match: _match, untilLock: _untilLock),
        Expanded(
          child: AnimatedBuilder(
            animation: Listenable.merge([_questionReveal, _optionsReveal]),
            builder: (context, _) {
              final questionProgress = switch (_revealPhase) {
                _QuizRevealPhase.numberIntro => 0.0,
                _QuizRevealPhase.questionReveal => _questionReveal.value,
                _QuizRevealPhase.optionsReveal || _QuizRevealPhase.ready => 1.0,
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
                    ? const SizedBox.shrink(key: ValueKey('question-intro-gap'))
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
                        selectedMultiplier: _multipliersByQuestion[question.id],
                        multiplierOwners: _multiplierOwners,
                        multiplierEnabled:
                            _editable &&
                            !_revealing &&
                            _questionAnswered(question.id),
                        questionProgress: questionProgress,
                        controlProgress: optionsProgress,
                        onHomeChanged: (s) => _setScore(question.id, home: s),
                        onAwayChanged: (s) => _setScore(question.id, away: s),
                        onMultiplierTap: (multiplier) =>
                            _toggleMultiplier(question.id, multiplier),
                      )
                    : SingleChildScrollView(
                        key: ValueKey(question.id),
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
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
        _BottomDock(
          questions: _questions,
          answers: _answers,
          index: _index,
          canGoPrevious: _index > 0 && !_revealing,
          onPrevious: _previous,
          primary: primary,
          helper: _helperText(prediction, settled),
        ),
      ],
    );
  }

  Widget _reviewContent(UserPrediction prediction) {
    final editable = _editable;
    final readOnly = !editable;
    return Column(
      children: [
        _QuizTopBar(
          onBack: () => Navigator.of(context).popUntil((r) => r.isFirst),
          onLeaderboard: _showMatchLeaderboard,
        ),
        const SizedBox(height: 20),
        _QuizHeader(match: _match),
        _LockLine(match: _match, untilLock: _untilLock),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          child: _ReviewNotice(text: _reviewNotice(prediction)),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
            itemCount: _questions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final question = _questions[i];
              return _ReviewQuestionCard(
                index: i + 1,
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
              );
            },
          ),
        ),
        if (editable)
          _ReviewSaveDock(
            enabled: _hasDraftChanges && _allAnswered && !_savingUpdates,
            saving: _savingUpdates,
            onSave: _saveUpdates,
          ),
      ],
    );
  }

  String _reviewNotice(UserPrediction prediction) {
    if (_editable) {
      return 'You can update answers until match starts.';
    }
    if (_match.status == MatchStatus.finished ||
        prediction.status == PredictionStatus.settled) {
      return 'Final answers are in. Review results and crowd votes.';
    }
    return 'Predictions are locked. Review crowd votes as the match unfolds.';
  }

  void _showMatchLeaderboard() {
    playSound(SoundEffect.uiTap);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _MatchLeaderboardSheet(match: _match, entries: _leaderboard),
    );
  }

  /// The forward CTA's state for the current page. NEXT pages forward; the
  /// final page becomes SUBMIT (editable), SETTLE & CLAIM (finished demo) or
  /// DONE (locked review).
  _PrimaryAction _primaryButton(UserPrediction? prediction, bool settled) {
    final canSettle =
        _match.status == MatchStatus.finished &&
        (_quiz?.settleable ?? false) &&
        prediction != null &&
        !settled;
    if (_isLast && canSettle) {
      return _PrimaryAction(
        'SETTLE & CLAIM',
        enabled: !_revealing,
        onTap: _revealing ? null : _settle,
      );
    }
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
      return '$correct / ${_questions.length} correct  ·  +$reward COINS';
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

// ── Top bar (collapse chevron) ────────────────────────────────────────────────
class _QuizTopBar extends StatelessWidget {
  const _QuizTopBar({required this.onBack, required this.onLeaderboard});

  final VoidCallback onBack;
  final VoidCallback onLeaderboard;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
      decoration: BoxDecoration(
        color: const Color(0xff1a253a),
        border: const Border(bottom: BorderSide(color: Cyber.cyan, width: 1)),
      ),
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
          const SizedBox(width: 16),
          Semantics(
            button: true,
            label: 'Match leaderboard',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onLeaderboard,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                color: const Color(0xff11182a),
                child: const Icon(
                  Icons.emoji_events_outlined,
                  color: Colors.white,
                  size: 22,
                ),
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
  const _HeaderBadge({required this.team, required this.cutBottomRight});
  final SportTeam team;
  final bool cutBottomRight;

  @override
  Widget build(BuildContext context) {
    return TeamLogo(
      team: team,
      width: 44,
      height: 44,
      cutBottomRight: cutBottomRight,
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
      MatchStatus.finished => (Icons.flag_outlined, 'MATCH ENDED', Cyber.muted),
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
            style: Cyber.label(
              11,
              color: color,
              letterSpacing: 1.4,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}

// ── The single question panel ─────────────────────────────────────────────────
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
        style: Cyber.body(12.5, color: const Color(0xffbed7ee)),
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
                          question.text.toUpperCase(),
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
                  style: Cyber.label(8, color: Cyber.cyan, letterSpacing: 0.8),
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
    return Container(
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
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
          child: _QuizButton(
            label: saving ? 'SAVING...' : 'SAVE UPDATES',
            focal: enabled,
            enabled: enabled,
            onTap: onSave,
          ),
        ),
      ),
    );
  }
}

class _MatchLeaderboardSheet extends StatelessWidget {
  const _MatchLeaderboardSheet({required this.match, required this.entries});

  final SportMatch match;
  final List<MatchPredictionLeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: BoxDecoration(
          color: const Color(0xff11182a),
          border: Border.all(color: Cyber.cyan.withValues(alpha: 0.35)),
          boxShadow: Cyber.glow(Cyber.cyan, alpha: 0.18, blur: 16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events_outlined, color: Cyber.gold),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'MATCH LEADERBOARD',
                    style: Cyber.display(
                      15,
                      color: Colors.white,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Cyber.muted),
                ),
              ],
            ),
            Text(
              '${match.home.shortName} vs ${match.away.shortName}',
              style: Cyber.body(12, color: Cyber.muted),
            ),
            const SizedBox(height: 14),
            for (final entry in entries.take(6))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '#${entry.rank}',
                        style: Cyber.display(12, color: Cyber.cyan),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry.name,
                        style: Cyber.body(13.5, weight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${entry.correct} CORRECT',
                      style: Cyber.label(
                        9,
                        color: Cyber.muted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${entry.points}',
                      style: Cyber.display(13, color: Cyber.gold),
                    ),
                  ],
                ),
              ),
          ],
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
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 26),
          padding: const EdgeInsets.fromLTRB(18, 28, 18, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_panelTop, _panelBottom],
            ),
            border: Border.all(color: _panelBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _WordRevealText(
                      text: question.text.toUpperCase(),
                      progress: questionProgress,
                      style: Cyber.display(
                        16,
                        letterSpacing: 0.3,
                      ).copyWith(height: 1.25),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _BoostSelector(
                questionId: question.id,
                selected: selectedMultiplier,
                owners: multiplierOwners,
                enabled: multiplierEnabled,
                onTap: onMultiplierTap,
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
          child: _XpPill(
            reward:
                selectedMultiplier?.applyTo(question.reward) ?? question.reward,
            multiplier: selectedMultiplier,
          ),
        ),
        // The numbered tab, dipping over the panel's top-left edge.
        Positioned(
          left: 14,
          top: 14,
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
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 26),
            padding: const EdgeInsets.fromLTRB(18, 30, 18, 22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_panelTop, _panelBottom],
              ),
              border: Border.all(color: _panelBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _WordRevealText(
                        text: question.text.toUpperCase(),
                        progress: questionProgress,
                        style: Cyber.display(
                          16,
                          letterSpacing: 0.3,
                        ).copyWith(height: 1.25),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _BoostSelector(
                  questionId: question.id,
                  selected: selectedMultiplier,
                  owners: multiplierOwners,
                  enabled: multiplierEnabled,
                  onTap: onMultiplierTap,
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
            child: _XpPill(
              reward:
                  selectedMultiplier?.applyTo(question.reward) ??
                  question.reward,
              multiplier: selectedMultiplier,
            ),
          ),
          Positioned(
            left: 14,
            top: 14,
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
  });

  final String questionId;
  final PredictionMultiplier? selected;
  final Map<PredictionMultiplier, String> owners;
  final bool enabled;
  final ValueChanged<PredictionMultiplier> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
          color: active ? accent.withValues(alpha: 0.10) : _optionFill,
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
        boxShadow: current
            ? Cyber.glow(Cyber.amber, alpha: 0.35, blur: 8)
            : null,
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
                style: Cyber.body(
                  16,
                  color: content,
                  weight: FontWeight.w800,
                ).copyWith(letterSpacing: 0.8),
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
          ..color = enabled ? const Color(0xff1b2336) : const Color(0xff141a26),
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
        final scrim = (t < 0.85 ? 1.0 : (1 - (t - 0.85) / 0.15)).clamp(
          0.0,
          1.0,
        );
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
                      color: Cyber.cyan.withValues(alpha: 0.12),
                      border: Border.all(color: Cyber.cyan, width: 2.5),
                      boxShadow: Cyber.glow(Cyber.cyan, alpha: 0.7, blur: 26),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Cyber.cyan,
                      size: 58,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Opacity(
                  opacity: ((t - 0.25) / 0.25).clamp(0.0, 1.0),
                  child: Column(
                    children: [
                      Text(
                        'PREDICTION SUBMITTED',
                        style:
                            Cyber.display(
                              20,
                              color: Colors.white,
                              letterSpacing: 2,
                            ).copyWith(
                              shadows: [
                                Shadow(
                                  color: Cyber.cyan.withValues(alpha: 0.6),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${widget.count} FUTURES LOCKED · UP TO ${widget.potentialXp} XP',
                        style:
                            Cyber.label(
                              12,
                              color: Cyber.gold,
                              letterSpacing: 1.4,
                            ).copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
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
