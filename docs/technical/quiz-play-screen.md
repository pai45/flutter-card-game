# Quiz Play Screen — implementation and porting reference

> **Status:** BUILT
> **Last verified:** 2026-09-14
> **Scope:** [`lib/screens/quiz/quiz_play_screen.dart`](../../lib/screens/quiz/quiz_play_screen.dart)
> — the 10-question run — together with the two widget files it is built from:
> [`widgets/answer_verdict.dart`](../../lib/screens/quiz/widgets/answer_verdict.dart)
> (the **SIGNAL LOCK** per-question verdict cinematic and the charging NEXT button) and
> [`widgets/quiz_reveal.dart`](../../lib/screens/quiz/widgets/quiz_reveal.dart)
> (the end-of-run payoff overlay).

**The second half of a pair.** This is the screen that
[`quiz-lobby-and-set-ladder.md`](quiz-lobby-and-set-ladder.md) pushes once the player
has paid the entry fee — that doc gave it only as a placeholder. Port the two together:

- **Reuse from the lobby doc** its App. A (the quiz models and `QuizCubit`), App. B
  (`QuizBank`) and App. C (`CyberChip`, `CyberPlainBackground`, `CyberProgressBar`,
  `HudChamferClipper`, `HudCtaButton`, and the `_segTrack` constant).
- **Replace** the lobby doc's App. D stand-ins with **App. C of this doc**. It is a
  superset — it adds XP, audio scenes, the full sound palette and the rarity backdrop,
  and it drops the placeholder `QuizPlayScreen`.

**Written to be portable.** Every declaration in the three files is reproduced *exactly
as implemented* — all 14 in the screen, all 16 in `answer_verdict.dart` (10 widgets and
painters, 4 timing constants, 2 helpers) and all 11 in `quiz_reveal.dart` — plus the
four data helpers and three shared widgets they reach. The whole thing was compiled as
one library together with the lobby doc's port.

---

## 0. Port map

| # | Layer | Source | Here |
| --- | --- | --- | --- |
| 1 | Loop state | `_QuestionPhase` | §2, §3 — verbatim |
| 2 | The screen | `QuizPlayScreen` + `_QuizPlayScreenState` | §3 — verbatim |
| 3 | Verdict timeline | `kVerdictDuration`, `kVerdictScanEnd`, `kVerdictImpactEnd`, `kAutoAdvanceDelay`, `verdictBeat`, `verdictStreakAccent` | §4 — verbatim |
| 4 | Beat widgets | `VerdictScanline`, `SignalLockFx`, `GlitchTear` + painters | §4 — verbatim |
| 5 | The question | `_QuestionPanel`, `_OptionTile` | §5 — verbatim |
| 6 | HUD | `_TopBar`, `_QuizHeader`, `_XpEarnedMetric`, `_HudMetric`, `_MetricDivider`, `_CornerBracketsPainter` | §6 — verbatim |
| 7 | Dock | `_BottomDock`, `ChargingHudButton`, `VerdictDebriefStrip` | §7 — verbatim |
| 8 | Payoff | `QuizRevealOverlay` + 9 leaves | §8 — verbatim |
| 9 | Data | `buildQuizSet`, `SettlementQuestionResult`, `PredictionMultiplier`, `levelProgress` | App. A — verbatim |
| 10 | Shared widgets | `HudPagerButton`, `HudProgressSegment`, `PackBurst` | App. B — verbatim |
| 11 | Stand-ins | tokens, sound + audio scenes, storage, wallet + XP, chrome, rarity backdrop | App. C |
| — | Prerequisites | models, cubit, bank, 10 shared widgets | lobby doc App. A–C |

**Toolchain**

- **Dart 3.8+** — switch expressions and statements, records (via the lobby models), and
  a null-aware collection element in App. C's scaffold.
- **Flutter 3.27+** — `Color.withValues`; also comfortably covers
  `PopScope.onPopInvokedWithResult`.
- **`flutter_bloc`** — the only third-party package.
- **Imports for the combined library:** `dart:async`, `dart:convert`, `dart:math`
  (unprefixed — `levelFromXp`, `PackBurst`), `dart:math as math` and `dart:ui as ui`
  (both used by `answer_verdict.dart`), `package:flutter/material.dart`,
  `package:flutter/services.dart`, `package:flutter_bloc/flutter_bloc.dart`.

---

## 1. What it is

A single run through one set: ten questions, one at a time, each judged the moment
it's locked in — then a payoff screen.

```
QuizPlayScreen(sport, mode, setNumber)             pushed by the ladder after the fee
  ├─ no questions → _buildAwaitingQuestions         spinner, or SET NOT WRITTEN YET
  └─ PopScope(canPop: nothing picked || results shown)
       └─ Stack
            ├─ CyberPlainBackground
            ├─ Column
            │    ├─ _TopBar      ← exit · FOOTBALL QUIZ ·        [EASY · SET 12]
            │    ├─ _QuizHeader    QUESTION 3/10 │ STREAK ×2 │ XP EARNED 2 XP
            │    ├─ AnimatedSwitcher(question.id)   fade + 5% slide between questions
            │    │    └─ AnimatedBuilder(_verdict) → GlitchTear (wrong only)
            │    │         └─ _QuestionPanel   [03] prompt + 4 × _OptionTile
            │    │              ├─ VerdictScanline while scanning
            │    │              └─ SignalLockFx on the tile, when correct
            │    └─ _BottomDock
            │         ├─ 10 × HudProgressSegment     green ✓ · red ✗ · amber "you are here"
            │         ├─ VerdictDebriefStrip          SIGNAL LOCKED · ANSWER CONFIRMED · +1 XP
            │         ├─ LOCK IN  →  ChargingHudButton NEXT (3 s)  →  SEE RESULTS
            │         └─ helper line
            └─ [finished] QuizRevealOverlay
                   FLAWLESS SET · 10/10 CORRECT · ★★★ stamp in · +10 XP · SET 13 UNLOCKED
                   LEVEL bar · REVIEW RESULTS · CONTINUE TO SETS · REPLAY FOR 3 STARS
```

Each question runs the same four-beat loop: **pick → lock → verdict → advance**. The
verdict is a 700 ms cinematic that deliberately gives nothing away for its first 210 ms.
The next question is dealt automatically after a 3-second charge the player can skip —
except on the last question, which always waits. Because every answer has already been
judged in-play, the overlay at the end is a **payoff, not a settlement**: stars stamp
in, XP counts up, the level bar catches up.

---

## 2. The rules the screen enforces

### 2.1 Three phases per question

| `_QuestionPhase` | The player can… | Dock shows |
| --- | --- | --- |
| `picking` | pick an option, change it | `LOCK IN` (enabled once something is picked) |
| `resolving` | nothing — the scan beat is running | `LOCK IN`, disabled |
| `resolved` | tap NEXT / SEE RESULTS | charging `NEXT`, or `SEE RESULTS` on the last question |

`_select` refuses outside `picking`; `_lockAnswer` refuses outside `picking` or with no
pick; `_advance` refuses outside `resolved`. Those three guards are the whole state
machine.

### 2.2 Never leak the verdict before it lands

The scan beat is identical for right and wrong answers, and nothing else on screen is
allowed to give the answer away during it:

- **Streak and XP are updated in `_landVerdict`, not `_lockAnswer`.** The comment is
  explicit — updating them at lock time would leak the answer through the HUD.
- **`_verdictFor(index)` returns `null` for the current question until `resolved`**, so
  the dock's progress segment isn't graded early.
- The option tile only receives a verdict `when resolved && selected == i` — which also
  keeps the **semantics label** from announcing "correct"/"wrong" during the scan.
- The lock-in sound (`countdownTick`) and haptic are the same either way.

### 2.3 XP is earned per verdict, but banked only at the end

`_earnedXp` rises by `mode.reward` on every correct verdict — that's the **pot** the
header shows. It only reaches the player's actual XP total in two places:

- **`_finish`** — the full run, recorded as `EASY SET 12`;
- **a confirmed exit** — a partial run, recorded as `EASY SET 12 · PARTIAL RUN`.

`_xpBanked` makes banking one-shot. The test *the last question waits for a tap* pins
this: with every answer right but SEE RESULTS not yet tapped, total XP is still **0**.

### 2.4 The streak is feedback, never a multiplier

`verdictStreakAccent`'s doc comment says it outright — the streak *never multiplies XP*.
It only heats up the presentation: the verdict accent climbs green → amber (×3) → gold
(×5), the chevron sweep grows from 3 to 5 chevrons at ×3, the debrief reads
`OVERCLOCK ×n` from ×3, and `quizPerfect` fires from ×5. A hot run *looks* hotter; it
doesn't pay more.

### 2.5 The last question waits for the player

`_landVerdict` starts the auto-advance charge only `if (!_isLast)`. Walking into the
summary is the player's call, not a timer's.

### 2.6 Quitting forfeits the fee, not the XP

Once anything is picked, leaving goes through a confirmation that says exactly what's
lost — the set won't clear and the 25-coin fee isn't refunded — and exactly what's kept:
`Your +4 XP is banked`. A partial run pays for what was right but never records a result,
so the set stays locked and its attempt count doesn't move.

### 2.7 Replays are charged on the spot

`REPLAY FOR 3 STARS · 25 COINS` charges immediately, with no briefing sheet — the price
is on the button. It re-checks the live balance first and is hidden after a perfect run,
since there's nothing left to chase.

### 2.8 Sets are deterministic

`buildQuizSet` always deals the same ten questions in the same order (App. A). A replay
is the *same* test again, which is what makes chasing three stars fair.

---

## 3. The screen — `QuizPlayScreen`

The phase enum and the widget, verbatim:

```dart
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
```

The state, verbatim:

```dart
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
```

### 3.1 State

| Field | Job |
| --- | --- |
| `_questions` | the ten questions; re-dealt on replay |
| `_verdict` | 0→1 over 700 ms — every verdict effect reads its slice of this one controller |
| `_charge` | 0→1 over 3 s — the NEXT fill **and** the auto-advance timer |
| `_answers` | question index → picked option; a pick counts as soon as it's made |
| `_index`, `_phase` | where the run is |
| `_streak`, `_bestStreak` | presentation only (§2.4); best streak shows on the summary |
| `_earnedXp`, `_xpBanked` | the pot, and whether it has been paid out (§2.3) |
| `_verdictRun` | a token that cancels a stale `_lockAnswer` after a replay |
| `_submitting`, `_retrying` | re-entrancy locks for finishing and replaying |
| `_reveal*` | a snapshot handed to the overlay, so it never re-reads cubit state |

### 3.2 Setup and teardown

- **Questions are dealt synchronously in `initState`** so the first frame can lay out.
  The ladder preloads the bank before pushing, so this is normally a cache hit; if it
  misses (a deep link, a hot restart), `_loadQuestions` recovers instead of rendering an
  empty quiz.
- **`_charge` carries a status listener that calls `_advance`** when it completes — the
  charge *is* the timer; there is no separate one.
- **Scene music** — `enterScene(AudioScene.quiz)` in `initState`, `leaveScene(AudioScene.quiz)`
  in `dispose`. The scene argument matters: `leaveScene` ignores a scene that isn't
  current, so disposing this screen can't cut off music another screen has already
  started. The enter call isn't awaited; audio never blocks the first frame.

### 3.3 `_lockAnswer` — the timeline, in wall-clock time

```
t = 0 ms     lock      phase → resolving · countdownTick · selection haptic · _verdict.forward
             0–210     SCAN     scanline sweeps the options — identical for right and wrong
t = 210 ms   _landVerdict       phase → resolved · streak/XP update · verdict sound + haptic
             210–434   IMPACT   correct: chevrons + circuit trace · wrong: glitch tear + flicker
t = 434 ms   (wrong only)       uiConfirm — the real answer boots on, tagged // CORRECT
             434–700   BOOT
t = 700 ms   _verdict done      _charge already running (3 s) unless it's the last question
```

The two `Future.delayed` waits are computed from the same constants as the controller
(`700 × 0.30` and `700 × (0.62 − 0.30)`), so sound and picture stay in step.

**The `run` token.** `_verdictRun` is bumped on every lock and on every replay; after each
`await`, `run != _verdictRun` aborts. Replaying mid-cinematic can't land a stale verdict
on the new run.

**Reduced motion** skips the cinematic: the verdict controller jumps to 1 and the verdict
lands at once.

### 3.4 `_landVerdict` and `_advance`

Correct: streak up, pot up, `quizCorrect` + a medium haptic, `quizPerfect` from ×5.
Wrong: streak reset, `quizWrong` + a **heavy** haptic. Then the phase flips to `resolved`
and — unless this is the last question — the charge starts.

`_advance` stops the charge, finishes on the last question, and otherwise resets both
controllers and deals the next question. The question area's `AnimatedSwitcher` is keyed on
`question.id`, so that reset produces a clean fade-and-slide rather than the old verdict
effects bleeding into the new question.

> **Known issue 1 — with reduced motion on, the next question is dealt ~150 ms after
> the verdict.** *(Reproduced in a widget test against the app.)*
>
> The dock hides the charging button when `MediaQuery.disableAnimationsOf(context)` is
> true and shows a static NEXT instead — but `_landVerdict` still calls
> `_charge.forward(from: 0)` unconditionally. `_charge` is a default `AnimationController`,
> and Flutter scales a default controller's duration by **0.05** when the platform's
> disable-animations flag is on (`animation_controller.dart:651`, applied in
> `_InterpolationSimulation`). So the 3-second charge completes in **150 ms** and deals the
> next question almost immediately — to exactly the players who asked for less motion,
> who are often the ones who need *more* time to read.
>
> The app never overrides `MediaQuery.disableAnimations` itself, so on a device the
> `MediaQuery` flag and the platform flag always agree and this is what players get. The
> existing narrow reduced-motion test doesn't catch it because it sets only the
> `MediaQuery` flag, which doesn't touch the controller.
>
> **Fix** — match the dock, and make reduced motion a manual advance:
>
> ```dart
> if (!_isLast && !MediaQuery.disableAnimationsOf(context)) _charge.forward(from: 0);
> ```
>
> A regression test for it is in §12.

### 3.5 Leaving — `_requestExit` and `PopScope`

`canPop` is `_answers.isEmpty || _revealResults != null`, and `_requestExit` uses the same
condition, so the system back gesture and the top bar's exit button behave alike:

- **Nothing picked yet, or on the summary** → leave at once. Nothing to lose.
- **Otherwise** → stop the charge, then confirm. The copy changes with the pot:
  `Your +4 XP is banked, but SET 12 will not clear and the 25 coin entry fee will not be
  refunded.` Confirming banks the pot as a partial run and pops.

Note a pick counts as soon as it's made — tapping an option without locking it in is
enough to arm the confirmation. The test *play screen … protects paid progress* pins that.

> **Known issue 2 — a question can be dealt behind the exit dialog.**
> *(Reproduced.)* `_requestExit` stops the charge so the next question isn't dealt behind
> the dialog, as its comment says. But if the player backs out during the 210 ms scan
> beat, the charge isn't running yet: the pending `_lockAnswer` wakes up, lands the verdict,
> and **starts** the charge with the dialog open. Three seconds later the next question is
> dealt behind it.
>
> **Known issue 3 — KEEP PLAYING leaves auto-advance switched off.** *(Reproduced.)*
> The charge is stopped when the dialog opens and nothing restarts it when the player
> chooses KEEP PLAYING. The NEXT fill freezes part-way and the question never advances by
> itself for the rest of that question.
>
> **Fix for both** — hold a flag while the dialog is open, and resume afterwards:
>
> ```dart
> // In _requestExit, around the dialog:
> _exitPromptOpen = true;
> final confirmed = await showDialog<bool>(/* … */);
> _exitPromptOpen = false;
> // …and if the player stays:
> if (confirmed != true && mounted && _phase == _QuestionPhase.resolved && !_isLast) {
>   _charge.forward(); // resumes from where it stopped
> }
> // In _landVerdict:
> if (!_isLast && !_exitPromptOpen && !MediaQuery.disableAnimationsOf(context)) {
>   _charge.forward(from: 0);
> }
> ```

### 3.6 `_bankEarnedXp` and `_finish`

`_bankEarnedXp` pays the pot once, labelled full or partial. It skips an empty pot — and
so does the XP system itself, which ignores awards of zero or less.

`_finish` is ordered with care:

1. lock with `_submitting`, play `quizSubmit`;
2. build one `SettlementQuestionResult` per question — prompt, picked label, correct
   label, correct?, XP earned;
3. **read the "before" values first** — the set's best score and the player's total XP —
   so the overlay can show a NEW BEST chip and animate the level bar from the right place;
4. bank the pot;
5. `await recordResult`, which returns `newlyCleared`, `stars` and `starsGained` computed
   in one pass (lobby doc, App. A);
6. hand the overlay a complete snapshot in one `setState`.

Because the overlay gets values rather than re-reading state, nothing it shows can
disagree with what was saved.

### 3.7 `_retry`

Checks the live balance (and shows a snackbar if it's short), spends the fee with a
`SET 12 REPLAY` ledger line, plays `coinSpend` then — after a 120 ms beat — `playMatch`,
bumps `_verdictRun` to cancel anything in flight, and resets every field to a fresh run
with the same ten questions. `_retrying` stops a double-tap on the replay button from
charging twice.

### 3.8 The build, and the holding screen

With questions, the build is the tree in §1. Without them it shows
`_buildAwaitingQuestions` — a spinner while the bank loads, or `SET NOT WRITTEN YET`
once it has loaded and the set is past what's written. It keeps the quiz's top bar, so it
reads as part of the quiz rather than an error page.

`_helperText` shows `n of 10 left` plus the XP rate — or the streak, from ×2. `left` counts
**picks**, so it drops as soon as an option is tapped, before it's locked in.

---

## 4. The verdict cinematic — `answer_verdict.dart`

One 700 ms controller; every effect reads its own slice of it. The timeline constants and
the two helpers, verbatim:

```dart
/// "SIGNAL LOCK" — the per-question verdict cinematic for the Knowledge Arena.
///
/// One controller in the play screen runs 0→1 over [kVerdictDuration] and every
/// widget here reads its own slice of that timeline:
///
///   0.00 → 0.30  SCAN     a cyan scanline sweeps the option stack. Identical
///                         for right and wrong, so it gives nothing away.
///   0.30 → 0.62  IMPACT   correct → chevron sweep + circuit trace;
///                         wrong    → glitch tear + neon flicker.
///   0.62 → 1.00  BOOT     (wrong only) the real answer powers on.
///
/// The chevron is deliberately drawn at 45° — the same angle as the app's
/// signature corner chamfer — so the success beat is the shape language in
/// motion rather than generic confetti.
const Duration kVerdictDuration = Duration(milliseconds: 700);

const double kVerdictScanEnd = 0.30;
const double kVerdictImpactEnd = 0.62;

/// How long the player gets to read the verdict before the next question is
/// dealt automatically. The NEXT button charges across this window.
const Duration kAutoAdvanceDelay = Duration(seconds: 3);

/// Re-maps the master timeline onto a single beat, clamped to 0–1.
double verdictBeat(double t, double from, double to) =>
    ((t - from) / (to - from)).clamp(0.0, 1.0);

/// Streak escalation is pure feedback — it never multiplies XP. The accent
/// climbs success → amber → gold so a hot run visibly heats up.
Color verdictStreakAccent(int streak) {
  if (streak >= 5) return Cyber.gold;
  if (streak >= 3) return Cyber.amber;
  return Cyber.success;
}
```

`verdictBeat(t, from, to)` is the whole trick: it re-maps the master 0→1 onto one beat and
clamps, so each widget can say "I play from 0.30 to 0.62" without a controller of its own.

### 4.1 Beat 0 — `VerdictScanline`

```dart
/// Beat 0 — a 2px scanline with a soft tail sweeping down the option stack.
/// Verifying, not judging: the same sweep plays whatever the answer turns out
/// to be, which is what buys the reveal its tension.
class VerdictScanline extends StatelessWidget {
  const VerdictScanline({required this.progress, super.key});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final t = verdictBeat(progress, 0, kVerdictScanEnd);
    if (t <= 0 || t >= 1) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ScanlinePainter(t: t),
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  const _ScanlinePainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * t;
    const tail = 24.0;
    final fade = math.sin(t * math.pi).clamp(0.0, 1.0);

    canvas.drawRect(
      Rect.fromLTWH(0, y - tail, size.width, tail),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, y - tail),
          Offset(0, y),
          [
            Cyber.cyan.withValues(alpha: 0),
            Cyber.cyan.withValues(alpha: 0.16 * fade),
          ],
        ),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, y - 1, size.width, 2),
      Paint()..color = Cyber.cyan.withValues(alpha: 0.85 * fade),
    );
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter old) => old.t != t;
}
```

A 2px cyan line with a 24px soft tail sweeping down the options, fading in and out on a
sine. **Verifying, not judging** — it plays identically for every answer, which is what
gives the reveal its tension. It builds nothing outside its beat.

### 4.2 Beat 1, correct — `SignalLockFx`

```dart
/// Beat 1 (correct) — chevrons sweeping across the tile face at the chamfer
/// angle, plus a stroke that *draws* itself around the tile perimeter starting
/// from the letter badge. [chevrons] grows with the streak.
class SignalLockFx extends StatelessWidget {
  const SignalLockFx({
    required this.progress,
    required this.accent,
    this.chevrons = 3,
    super.key,
  });

  final double progress;
  final Color accent;
  final int chevrons;

  @override
  Widget build(BuildContext context) {
    final t = verdictBeat(progress, kVerdictScanEnd, 1);
    if (t <= 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _SignalLockPainter(t: t, accent: accent, chevrons: chevrons),
      ),
    );
  }
}

class _SignalLockPainter extends CustomPainter {
  const _SignalLockPainter({
    required this.t,
    required this.accent,
    required this.chevrons,
  });

  final double t;
  final Color accent;
  final int chevrons;

  @override
  void paint(Canvas canvas, Size size) {
    _paintTrace(canvas, size);
    _paintChevrons(canvas, size);
  }

  /// A stroke that runs the tile perimeter clockwise from the letter badge,
  /// then flashes the whole outline once it closes.
  void _paintTrace(Canvas canvas, Size size) {
    final draw = Curves.easeOutCubic.transform(
      verdictBeat(t, 0, 0.62).clamp(0.0, 1.0),
    );
    if (draw <= 0) return;

    final start = math.min(26.0, size.width * 0.2);
    final path = Path()
      ..moveTo(start, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, 0)
      ..lineTo(start, 0);

    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (sum, m) => sum + m.length);
    var remaining = total * draw;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square
      ..color = accent;

    for (final metric in metrics) {
      if (remaining <= 0) break;
      final take = math.min(remaining, metric.length);
      canvas.drawPath(metric.extractPath(0, take), paint);
      remaining -= take;
    }

    // Closing flash — the outline briefly blooms once the circuit completes.
    final flash = 1 - verdictBeat(t, 0.58, 0.9);
    if (draw >= 1 && flash > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 + 3 * flash
          ..color = accent.withValues(alpha: 0.5 * flash)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * flash),
      );
    }
  }

  void _paintChevrons(Canvas canvas, Size size) {
    const spacing = 17.0;
    const arm = 9.0;
    final travel = size.width + spacing * chevrons + arm * 2;
    final cy = size.height / 2;
    final head = Curves.easeOutCubic.transform(
      verdictBeat(t, 0, 0.75).clamp(0.0, 1.0),
    );

    for (var i = 0; i < chevrons; i++) {
      final x = -arm + head * travel - i * spacing;
      if (x < -arm * 2 || x > size.width + arm * 2) continue;
      // Leading chevron is brightest; the tail thins out behind it.
      final lead = 1 - i / chevrons;
      final edge = math.min(x, size.width - x) / 26;
      final alpha = (lead * (1 - head) * 1.5 * edge.clamp(0.0, 1.0)).clamp(
        0.0,
        1.0,
      );
      if (alpha <= 0.01) continue;

      canvas.drawPath(
        Path()
          ..moveTo(x - arm, cy - arm)
          ..lineTo(x, cy)
          ..lineTo(x - arm, cy + arm),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 - 2 * head
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.miter
          ..color = accent.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SignalLockPainter old) =>
      old.t != t || old.accent != accent || old.chevrons != chevrons;
}
```

Two layers on the chosen tile:

- **A circuit trace** — a 2px stroke that *draws itself* clockwise round the tile, starting
  from the letter badge, using `computeMetrics` and `extractPath`. When it closes, the
  outline blooms once with a blurred flash.
- **A chevron sweep** — 3 chevrons (5 on a streak of ×3 or more) crossing the tile, the
  leader brightest, fading at the tile edges.

The chevrons are drawn at **45°, the same angle as the app's corner chamfer**, so the
success beat is the design language in motion rather than generic confetti. Keep the angle.

### 4.3 Beat 1, wrong — `GlitchTear`

```dart
/// Beat 1 (wrong) — the panel tears. A decaying square-wave shake underneath,
/// displaced ghost bands and an RGB split painted over the top. Nothing is
/// rasterised, so the child keeps rendering live.
class GlitchTear extends StatelessWidget {
  const GlitchTear({
    required this.progress,
    required this.active,
    required this.child,
    super.key,
  });

  final double progress;
  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!active) return child;
    final t = verdictBeat(progress, kVerdictScanEnd, kVerdictImpactEnd);
    if (t <= 0 || t >= 1) return child;

    // Three hard cycles, decaying — reads as a mechanical fault, not a wobble.
    final decay = 1 - t;
    final shake = math.sin(t * math.pi * 6).sign * 4 * decay;

    return Transform.translate(
      offset: Offset(shake, 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _GlitchPainter(t: t)),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlitchPainter extends CustomPainter {
  const _GlitchPainter({required this.t});

  final double t;

  // Fixed band geometry (top fraction, height fraction, drift) so the tear is
  // deterministic — it must not re-scramble on every rebuild.
  static const List<List<double>> _bands = [
    [0.08, 0.05, 1.0],
    [0.27, 0.03, -0.6],
    [0.46, 0.07, 0.8],
    [0.68, 0.04, -1.0],
    [0.85, 0.05, 0.5],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final decay = 1 - t;
    final pulse = math.sin(t * math.pi * 6).sign;

    // RGB split across the whole panel.
    final splitPaint = Paint()..blendMode = BlendMode.plus;
    canvas.drawRect(
      Rect.fromLTWH(2 * pulse, 0, size.width, size.height),
      splitPaint..color = Cyber.danger.withValues(alpha: 0.14 * decay),
    );
    canvas.drawRect(
      Rect.fromLTWH(-2 * pulse, 0, size.width, size.height),
      splitPaint..color = Cyber.cyan.withValues(alpha: 0.08 * decay),
    );

    for (var i = 0; i < _bands.length; i++) {
      final band = _bands[i];
      final top = size.height * band[0];
      final height = math.max(2.0, size.height * band[1]);
      final dx = band[2] * (2 + 7 * decay) * pulse;

      // Displaced ghost slab — the "torn" slice.
      canvas.drawRect(
        Rect.fromLTWH(dx, top, size.width, height),
        Paint()
          ..blendMode = BlendMode.plus
          ..color = (i.isEven ? Cyber.danger : Cyber.cyan).withValues(
            alpha: 0.16 * decay,
          ),
      );
      // Hot edge on the tear.
      canvas.drawRect(
        Rect.fromLTWH(dx, top, size.width, 1),
        Paint()..color = Cyber.danger.withValues(alpha: 0.55 * decay),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlitchPainter old) => old.t != t;
}
```

The whole question panel **tears**: a decaying square-wave shake (three hard cycles,
±4px), an RGB split (danger and cyan layers offset ±2px, additively blended) and five
displaced "ghost" bands with hot red edges.

- **The bands are fixed geometry**, not random — the comment calls it out. A random tear
  would re-scramble on every rebuild and read as noise; a fixed one reads as a fault.
- **Nothing is rasterised.** The effect is painted over the live child, so the options
  keep rendering (and flickering) underneath.
- The square wave (`sin(...).sign`) rather than a smooth `sin` is what makes it feel
  mechanical instead of wobbly.

---

## 5. The question — `_QuestionPanel` and `_OptionTile`

```dart
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
```

### 5.1 The panel

- **The instruction line narrates the phase:** `SELECT ONE ANSWER` → `VERIFYING SIGNAL...`
  (in cyan, the scan colour) → `ANSWER LOCKED`.
- **A numbered badge** (`03`) overlaps the top-left edge.
- **The answer key only switches on after the tear** — `showKey = wrong && progress >= 0.62`
  — so a wrong answer lands, tears, *then* the right one lights up.
- **During the scan the other options dim to 55%**, pulling focus onto the pick.
- The whole panel is wrapped in `GlitchTear`, active only on a wrong verdict.

### 5.2 The option tile

One tile carries five looks, resolved by a single accent chain:

| State | Accent | Fill | Border | Glow | Right-hand mark |
| --- | --- | --- | --- | --- | --- |
| idle | — | `#0d1725` | `#304058`, 1px | — | empty circle |
| focused (keyboard) | mode accent | accent 7% | accent | — | empty circle |
| picked | mode accent | accent 15% | accent, 1.6px | `alpha .18, blur 12` | filled check |
| correct verdict | streak accent | accent 16% | accent, 1.6px | `alpha .28, blur 18` + `SignalLockFx` | verified |
| wrong verdict | `danger` | accent 16% | **flickering** accent | — | cancel |
| answer key (on a miss) | `success` | accent 10% | accent, 1.6px | — | `// CORRECT` |

- **The wrong-pick flicker** is a broken-neon strobe: the border alpha drops to 55% on
  alternate frame-buckets (`progress × 34`), decaying across the impact beat. It's skipped
  under reduced motion.
- **The letter badge becomes the verdict** — `A` turns into ✓ or ✕ once judged.
- **Press feedback** — scale to 0.985 over 100 ms; every state change animates over 160 ms;
  all of it drops to zero duration under reduced motion.
- **Semantics** — `Answer B: Wembley`, and once judged `…, correct` / `…, wrong`.

### 5.3 Glow audit

The tile's comment states the intent: *exactly one live element — the picked tile, then the
verdict tile.* Among the tiles that holds. **But across the whole screen it doesn't**: with an
option picked, four things glow at once — the picked tile, the **question-number badge**, the
current progress segment, and the focal LOCK IN button.

Three of those are defensible under the design system (the selected item, "you are here", the
primary CTA). **The badge isn't.** It glows on every question, all the time
(`Cyber.glow(mode.accent, alpha: 0.16, blur: 10)`), and the rule is explicit that *always-on
secondary elements never glow*. Dropping that one `boxShadow` is the obvious change in a port.

### 5.4 Two smaller notes

- **Keyboard users can focus an option but not choose it.** `FocusableActionDetector` is
  given no actions, so it only drives the focus highlight — Enter and Space do nothing. Screen
  readers are fine (the `GestureDetector` supplies a tap action), but on a web or desktop build
  a keyboard-only player can't answer. Add an `ActivateIntent` action if you ship there.
- **Untokenised colours.** This file uses raw hex where the design system wants tokens:
  `#1b2336 → #111a29` (panel gradient), `#304058` (idle border), `#0d1725` (idle fill),
  `#c8d3e2` (idle label), `#d9e5f6` (back arrow), and `#90A1B9` in the dock (which is
  `Cyber.muted` spelled out). Worth tokenising in a port.

---

## 6. The HUD — `_TopBar`, `_QuizHeader` and friends

```dart
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

```

- **`_TopBar`** — a 44×44 exit target labelled `Exit quiz` for screen readers, the sport
  title, and a `CyberChip` naming the category and set in the category's colour.
- **`_QuizHeader`** — three metrics between dividers, framed by **top-corner brackets** in the
  category colour (16px, 40%). The streak metric turns the streak accent from ×2.
- **`_XpEarnedMetric`** pops (scale to 1.16 over 160 ms, `easeOutBack`, back over 320 ms)
  whenever the pot grows — so a correct answer pays off on the tile *and* in the header.

> **Don't "fix" the `IntTween(begin: value, end: value)`.** It looks like a tween from a
> number to itself, but `TweenAnimationBuilder` only uses `begin` on the first build; after
> that, a new `end` animates *from the current value*. So the counter does tick up over
> 260 ms. Changing `begin` to `0` would make it count from zero on every correct answer.

---

## 7. The dock — `_BottomDock`, `ChargingHudButton`, `VerdictDebriefStrip`

```dart
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
```

Top to bottom:

1. **Ten progress segments.** Before a question is judged they read as a tracker (amber
   "you are here", green answered, slate to come); once judged, as a **scoreboard** — green
   correct, red wrong. Each announces its state to screen readers.
2. **The debrief strip**, animating in and out with fade + size (220 ms).
3. **The primary button**, in one of three forms:
   - `LOCK IN` — a `HudPagerButton`, focal (glowing) only once something is picked;
   - `NEXT` — the charging button, while the auto-advance is running;
   - the **plain focal button** — `SEE RESULTS` on the last question, and `NEXT` under reduced
     motion (see §3.4 for why that alone isn't enough).
4. **The helper line** (§3.8).

### 7.1 `ChargingHudButton`

```dart
/// The NEXT button as a charging cell: it starts calm and a bright focal fill
/// sweeps left→right over [kAutoAdvanceDelay], firing the next question when it
/// tops up. Tapping it any time skips the wait.
///
/// Rather than repaint the shared [HudPagerButton], this stacks two of them —
/// calm underneath, focal on top clipped to [fill] — so the label and icon each
/// pick up the right ink on their own side of the charge line.
class ChargingHudButton extends StatelessWidget {
  const ChargingHudButton({
    required this.label,
    required this.icon,
    required this.fill,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;

  /// 0–1. At 0 the button is fully charged-looking (focal) — pass 0 when there
  /// is no auto-advance running so it behaves like a normal focal CTA.
  final double fill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = fill.clamp(0.0, 1.0);
    return Stack(
      children: [
        HudPagerButton(
          label: label,
          trailingIcon: icon,
          focal: false,
          enabled: true,
          onTap: onTap,
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRect(
              clipper: _ChargeClipper(t),
              child: HudPagerButton(
                label: label,
                trailingIcon: icon,
                focal: true,
                enabled: true,
                onTap: null,
              ),
            ),
          ),
        ),
        if (t > 0 && t < 1)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _ChargeEdgePainter(t)),
            ),
          ),
      ],
    );
  }
}

class _ChargeClipper extends CustomClipper<Rect> {
  const _ChargeClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(covariant _ChargeClipper old) =>
      old.fraction != fraction;
}

/// The bright leading edge riding the charge front.
class _ChargeEdgePainter extends CustomPainter {
  const _ChargeEdgePainter(this.fraction);

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width * fraction;
    canvas.drawRect(
      Rect.fromLTWH(x - 1.5, 0, 3, size.height),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  @override
  bool shouldRepaint(covariant _ChargeEdgePainter old) =>
      old.fraction != fraction;
}
```

Rather than repainting the button, it **stacks two**: a calm one underneath, and a focal one on
top clipped to the charge fraction. The label and icon therefore pick up the right ink on each
side of the charge line automatically — dark on the bright filled part, cyan on the calm part —
without any per-glyph maths. A 3px blurred white edge rides the charge front. Tapping it at any
point skips the wait.

### 7.2 `VerdictDebriefStrip`

```dart
/// Beat 3 — the strip that lands under the options and stays until NEXT.
/// Flat fill + border, never a glow: the verdict tile above it is the one
/// focal element on screen.
class VerdictDebriefStrip extends StatelessWidget {
  const VerdictDebriefStrip({
    required this.correct,
    required this.xp,
    required this.streak,
    required this.correctLabel,
    super.key,
  });

  final bool correct;
  final int xp;
  final int streak;
  final String correctLabel;

  @override
  Widget build(BuildContext context) {
    final accent = correct ? verdictStreakAccent(streak) : Cyber.danger;
    final overclocked = correct && streak >= 3;

    return ClipPath(
      clipper: const HudChamferClipper(bigCut: 10, smallCut: 4),
      child: Container(
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: Color.alphaBlend(accent.withValues(alpha: 0.1), Cyber.panel),
          border: Border.all(color: accent.withValues(alpha: 0.55)),
        ),
        child: Row(
          children: [
            Icon(
              correct ? Icons.verified_outlined : Icons.report_gmailerrorred,
              color: accent,
              size: 18,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    overclocked
                        ? 'OVERCLOCK ×$streak'
                        : correct
                        ? 'SIGNAL LOCKED'
                        : 'SIGNAL LOST',
                    style: Cyber.label(11, color: accent, letterSpacing: 1.6),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    correct
                        ? 'ANSWER CONFIRMED · $correctLabel'
                        : 'ANSWER WAS · $correctLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.body(11.5, color: Cyber.muted),
                  ),
                ],
              ),
            ),
            if (correct) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Cyber.gold.withValues(alpha: 0.13),
                  border: Border.all(color: Cyber.gold.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '+$xp XP',
                  style: Cyber.display(11, color: Cyber.gold).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

The strip stays under the options until NEXT, and **names the right answer either way**:
`SIGNAL LOCKED · ANSWER CONFIRMED · Wembley` with a gold `+1 XP` chip, or
`SIGNAL LOST · ANSWER WAS · Wembley`. From ×3 it reads `OVERCLOCK ×3`. It's a flat chamfered
plate that **never glows** — the verdict tile above it is the focal point.

---

## 8. The payoff — `QuizRevealOverlay`

The overlay and its state, verbatim:

```dart
/// End-of-run summary for a Knowledge Arena set.
///
/// Every answer was already judged in-play by the SIGNAL LOCK cinematic, so
/// this is a payoff rather than a settlement: the mastery stars stamp in one at
/// a time, the XP total counts up, and the level bar catches up.
///
/// There is no fail state — finishing a set always clears it and always pays
/// XP for what you got right. Stars are the reason to come back.
class QuizRevealOverlay extends StatefulWidget {
  const QuizRevealOverlay({
    required this.mode,
    required this.setNumber,
    required this.results,
    required this.totalXp,
    required this.xpBefore,
    required this.newlyCleared,
    required this.stars,
    required this.starsGained,
    required this.bestBefore,
    required this.bestStreak,
    required this.onRetry,
    required this.onDone,
    super.key,
  });

  final QuizMode mode;
  final int setNumber;
  final List<SettlementQuestionResult> results;
  final int totalXp;
  final int xpBefore;

  /// True when this run completed the set for the first time.
  final bool newlyCleared;

  /// Mastery stars held for this set after the run (0–3).
  final int stars;

  /// Stars added by this run on top of the previous best.
  final int starsGained;

  /// Best correct-answer count before this run, for the NEW BEST chip.
  final int bestBefore;
  final int bestStreak;
  final VoidCallback onRetry;
  final VoidCallback onDone;

  @override
  State<QuizRevealOverlay> createState() => _QuizRevealOverlayState();
}

class _QuizRevealOverlayState extends State<QuizRevealOverlay> {
  int _starsShown = 0;
  int _run = 0;
  bool _started = false;

  Color get _accent => widget.mode.accent;
  int get _correctCount =>
      widget.results.where((result) => result.correct).length;
  bool get _perfect => widget.stars >= 3;
  bool get _newBest => _correctCount > widget.bestBefore;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _starsShown = widget.stars;
      playSound(_perfect ? SoundEffect.quizPerfect : SoundEffect.quizPass);
      return;
    }
    _play();
  }

  Future<void> _play() async {
    final run = ++_run;
    playSound(SoundEffect.whoosh);
    await Future<void>.delayed(const Duration(milliseconds: 420));
    for (var i = 0; i < widget.stars; i++) {
      if (!mounted || run != _run) return;
      playSound(
        i == 2 ? SoundEffect.quizPerfect : SoundEffect.quizCorrect,
      );
      setState(() => _starsShown = i + 1);
      await Future<void>.delayed(const Duration(milliseconds: 260));
    }
    if (!mounted || run != _run) return;
    if (!_perfect) playSound(SoundEffect.quizPass);
    if (widget.newlyCleared) playSound(SoundEffect.quizUnlock);
  }

  @override
  Widget build(BuildContext context) {
    final progressBefore = levelProgress(widget.xpBefore);
    final progressAfter = levelProgress(widget.xpBefore + widget.totalXp);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return ColoredBox(
      color: Cyber.bg.withValues(alpha: 0.98),
      child: SafeArea(
        child: Stack(
          key: const ValueKey('quiz-summary'),
          alignment: Alignment.center,
          children: [
            if (_perfect && !reduceMotion)
              const Positioned.fill(
                child: PackRevealBackground(
                  rarity: 'platinum',
                  pulseOpacity: 0.12,
                ),
              ),
            if (_perfect && !reduceMotion) const Center(child: PackBurst()),
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _RevealIn(
                          child: Text(
                            _perfect ? 'FLAWLESS SET' : 'SET CLEARED',
                            textAlign: TextAlign.center,
                            style:
                                Cyber.display(
                                  25,
                                  color: _perfect ? Cyber.gold : Cyber.success,
                                  letterSpacing: 2.2,
                                ).copyWith(
                                  shadows: reduceMotion
                                      ? null
                                      : [
                                          Shadow(
                                            color:
                                                (_perfect
                                                        ? Cyber.gold
                                                        : Cyber.success)
                                                    .withValues(alpha: 0.55),
                                            blurRadius: 20,
                                          ),
                                        ],
                                ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _RevealIn(
                          delayFactor: 0.2,
                          child: _ScoreLine(
                            correct: _correctCount,
                            total: widget.results.length,
                            bestStreak: widget.bestStreak,
                            newBest: _newBest,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _StarAward(
                          shown: _starsShown,
                          gained: widget.starsGained,
                        ),
                        const SizedBox(height: 24),
                        _RevealIn(
                          delayFactor: 0.35,
                          child: _XpTotal(xp: widget.totalXp),
                        ),
                        if (widget.newlyCleared) ...[
                          const SizedBox(height: 18),
                          _RevealIn(
                            delayFactor: 0.5,
                            child: _ClearBanner(
                              mode: widget.mode,
                              setNumber: widget.setNumber,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        _RevealIn(
                          delayFactor: 0.65,
                          child: _LevelLine(
                            before: progressBefore,
                            after: progressAfter,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _RevealIn(
                          delayFactor: 0.75,
                          child: _AnswerReview(
                            results: widget.results,
                            accent: _accent,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _RevealIn(
                          delayFactor: 0.85,
                          child: HudCtaButton(
                            label: 'CONTINUE TO SETS',
                            icon: Icons.arrow_forward,
                            accent: _accent,
                            onTap: widget.onDone,
                            tapSound: SoundEffect.uiTap,
                          ),
                        ),
                        if (!_perfect) ...[
                          const SizedBox(height: 10),
                          _RevealIn(
                            delayFactor: 0.95,
                            child: HudPagerButton(
                              key: const ValueKey('quiz-replay'),
                              label:
                                  'REPLAY FOR 3 STARS · $kQuizEntryCost COINS',
                              leadingIcon: Icons.replay,
                              focal: false,
                              enabled: true,
                              onTap: widget.onRetry,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

Its leaves, verbatim:

```dart
/// Score, best streak and a NEW BEST flag on one tabular line.
class _ScoreLine extends StatelessWidget {
  const _ScoreLine({
    required this.correct,
    required this.total,
    required this.bestStreak,
    required this.newBest,
  });

  final int correct;
  final int total;
  final int bestStreak;
  final bool newBest;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 6,
      children: [
        Text(
          '$correct / $total CORRECT',
          style: Cyber.label(12, color: Cyber.muted, letterSpacing: 1.6)
              .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        if (bestStreak >= 2)
          Text(
            'BEST STREAK ×$bestStreak',
            style:
                Cyber.label(
                  12,
                  color: bestStreak >= 5 ? Cyber.gold : Cyber.amber,
                  letterSpacing: 1.6,
                ).copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
        if (newBest)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Cyber.gold.withValues(alpha: 0.13),
              border: Border.all(color: Cyber.gold.withValues(alpha: 0.6)),
            ),
            child: Text(
              'NEW BEST',
              style: Cyber.label(9, color: Cyber.gold, letterSpacing: 1.3),
            ),
          ),
      ],
    );
  }
}

/// The mastery beat: three chamfered plates, each stamping down as it is
/// awarded. Only earned plates light, and only a full sweep glows.
class _StarAward extends StatelessWidget {
  const _StarAward({required this.shown, required this.gained});

  final int shown;
  final int gained;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              _StarPlate(earned: i < shown, complete: shown >= 3),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          gained > 0
              ? '+$gained ${gained == 1 ? 'STAR' : 'STARS'} EARNED'
              : shown == 0
              ? 'NO STARS YET · REPLAY TO EARN'
              : 'SET RECORD HELD',
          style: Cyber.label(
            9.5,
            color: gained > 0 ? Cyber.gold : Cyber.muted,
            letterSpacing: 1.6,
          ),
        ),
      ],
    );
  }
}

class _StarPlate extends StatelessWidget {
  const _StarPlate({required this.earned, required this.complete});

  final bool earned;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: earned ? 1 : 0),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Transform.scale(
        // Stamps down from oversized onto the plate.
        scale: earned && !reduceMotion ? 1 + 1.1 * (1 - t) : 1,
        child: child,
      ),
      child: ClipPath(
        clipper: const HudChamferClipper(bigCut: 9, smallCut: 3),
        child: Container(
          width: 62,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: earned
                ? Color.alphaBlend(
                    Cyber.gold.withValues(alpha: 0.14),
                    Cyber.panel,
                  )
                : Cyber.panel,
            border: Border.all(
              color: earned
                  ? Cyber.gold.withValues(alpha: 0.75)
                  : Cyber.borderMuted,
            ),
            boxShadow: earned && complete
                ? Cyber.glow(Cyber.gold, alpha: 0.3, blur: 16)
                : null,
          ),
          child: Icon(
            earned ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 30,
            color: earned ? Cyber.gold : Cyber.border,
          ),
        ),
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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduceMotion
          ? Duration.zero
          : Duration(milliseconds: (420 * (1 + delayFactor)).round()),
      curve: Interval(
        delayFactor / (1 + delayFactor),
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: reduceMotion ? Offset.zero : Offset(0, 14 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _AnswerReview extends StatelessWidget {
  const _AnswerReview({required this.results, required this.accent});

  final List<SettlementQuestionResult> results;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: accent.withValues(alpha: 0.08),
      ),
      child: Material(
        color: Cyber.panel2.withValues(alpha: 0.92),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: accent.withValues(alpha: 0.42)),
        ),
        child: ExpansionTile(
          key: const ValueKey('quiz-answer-review'),
          iconColor: accent,
          collapsedIconColor: accent,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          title: Text(
            'REVIEW RESULTS',
            style: Cyber.display(11, color: accent, letterSpacing: 1.1),
          ),
          subtitle: Text(
            'Selected and correct answers',
            style: Cyber.body(11, color: Cyber.muted),
          ),
          children: [
            for (var i = 0; i < results.length; i++)
              _AnswerReviewRow(index: i + 1, result: results[i]),
          ],
        ),
      ),
    );
  }
}

class _AnswerReviewRow extends StatelessWidget {
  const _AnswerReviewRow({required this.index, required this.result});

  final int index;
  final SettlementQuestionResult result;

  @override
  Widget build(BuildContext context) {
    final color = result.correct ? Cyber.success : Cyber.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Cyber.borderMuted)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            result.correct ? Icons.check_circle : Icons.cancel,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Q$index · ${result.text}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.body(11.5, weight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  result.correct
                      ? 'YOUR ANSWER · ${result.pickedLabel}'
                      : 'YOUR ANSWER · ${result.pickedLabel}  /  CORRECT · ${result.correctLabel}',
                  style: Cyber.body(10.5, color: color),
                ),
              ],
            ),
          ),
        ],
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
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 700),
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

/// Capstone naming the set this run just opened.
class _ClearBanner extends StatelessWidget {
  const _ClearBanner({required this.mode, required this.setNumber});

  final QuizMode mode;
  final int setNumber;

  @override
  Widget build(BuildContext context) {
    final accent = mode.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        border: Border.all(color: accent.withValues(alpha: 0.6)),
        boxShadow: Cyber.glow(accent, alpha: 0.28, blur: 14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            setNumber < kQuizSetCount
                ? Icons.lock_open
                : Icons.workspace_premium,
            color: accent,
            size: 16,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              setNumber < kQuizSetCount
                  ? 'SET ${setNumber + 1} UNLOCKED'
                  : '${mode.label} LADDER COMPLETE',
              style: Cyber.display(13, color: accent, letterSpacing: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Level readout + bar filling from the pre-run position to the post-run one.
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
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 700),
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

```

### 8.1 The sequence

| Order | Element | Beat |
| --- | --- | --- |
| 0 | `FLAWLESS SET` (gold) or `SET CLEARED` (green) | `whoosh` · 420 ms entrance |
| 1 | `8 / 10 CORRECT · BEST STREAK ×4 · NEW BEST` | +20% delay |
| 2 | three star plates | after 420 ms, one every 260 ms — each **stamps down** from 2.1× with `quizCorrect`, the third with `quizPerfect` |
| 3 | `+8 XP` | counts up over 700 ms |
| 4 | `SET 13 UNLOCKED` / `EASY LADDER COMPLETE` | only when newly cleared · `quizUnlock` |
| 5 | `LEVEL 4` bar | fills from before to after over 700 ms — **gold, from zero, on a level-up** |
| 6 | `REVIEW RESULTS` | collapsed; every answer, yours and the right one |
| 7 | `CONTINUE TO SETS` | primary CTA |
| 8 | `REPLAY FOR 3 STARS · 25 COINS` | only if not perfect |

A perfect run adds the pack-opening backdrop and a 12-ray amber burst behind everything.

### 8.2 Details worth keeping

- **There is no fail state here either.** A 0/10 still reads `SET CLEARED`, still unlocks the
  next set, and says `NO STARS YET · REPLAY TO EARN`. The copy under the stars is always
  forward-looking: `+2 STARS EARNED`, `SET RECORD HELD`, or the replay prompt.
- **`_RevealIn` staggers with one tween.** Duration `420 × (1 + delay)` with an
  `Interval(delay / (1 + delay), 1)` curve gives every element the same 420 ms entrance after its
  own delay — no timers, no controllers.
- **The star sequence starts in `didChangeDependencies`**, guarded to run once, because it needs
  `MediaQuery` (which `initState` can't read). A `_run` token stops it if the widget is torn down
  mid-sequence. Under reduced motion, all stars show at once with one sound.
- **Answers are always reviewable** — the test *a low score still clears the set* pins the review
  panel's presence on a bad run.
- **The glow here is intentional.** Headline, XP total, a full star sweep, the unlock banner, the
  CTA and the perfect-run burst all glow. The design system explicitly lets "moment" screens —
  pack reveals, level-ups, wins — glow. This is one.

---

## 9. Gratification map

Every action in the run pays the player back. This is the list a port must not strip:

| Moment | Sound | Haptic | Picture |
| --- | --- | --- | --- |
| Pick an option | `cardSelect` | selection | tile fills and glows |
| Lock in | `countdownTick` | selection | scanline sweep; other options dim |
| Correct | `quizCorrect` | medium | circuit trace + chevrons + closing flash; XP pops in the header; debrief `+1 XP` |
| Streak ×3 / ×5 | — / `quizPerfect` | — | accent heats amber → gold; 5 chevrons; `OVERCLOCK ×n` |
| Wrong | `quizWrong` | **heavy** | panel tears; neon flicker on the pick |
| Answer key | `uiConfirm` | — | the right option powers on with `// CORRECT` |
| Wait | — | — | NEXT charges left to right |
| Next question | `uiTap` | — | fade + slide |
| Finish | `quizSubmit` | medium | overlay |
| Summary | `whoosh`, per-star cues, `quizPass`, `quizUnlock` | — | stars stamp in; XP counts up; unlock banner; level bar; burst on a perfect run |
| Replay | `coinSpend`, then `playMatch` | — | fresh run |

---

## 10. Every value in one place

| Element | Value |
| --- | --- |
| Verdict cinematic | `700 ms` — scan `0–0.30` (210 ms), impact `0.30–0.62` (to 434 ms), boot `0.62–1.0` |
| Auto-advance | `3 s` charge; never on the last question |
| Wrong-answer boot cue | `uiConfirm` at 434 ms |
| Question transition | `240 ms`, fade + slide from 5% right |
| Streak accents | `success` ×1–2 · `amber` ×3–4 · `gold` ×5+ |
| Chevrons | 3, or 5 from ×3 — 17px apart, 9px arms, drawn at 45° |
| Circuit trace | 2px, then a closing flash up to 5px with blur 6 |
| Glitch | shake ±4px × 3 cycles decaying; RGB split ±2px; 5 fixed bands |
| Scanline | 2px line + 24px tail, cyan |
| Option tile | min height 58; 30×30 letter badge; press 0.985 / 100 ms; changes 160 ms; dim 55% / 140 ms |
| Tile glow | picked `alpha .18 blur 12` · correct `alpha .28 blur 18` |
| Flicker | 34 frame-buckets across the impact beat, border alpha 55–100% |
| Question panel | padding `18, 31, 18, 18`; prompt `display 18`, line height 1.32; 42×34 badge |
| Header | brackets 16px @ 40%, 1.5px; dividers 1×34 |
| XP pop | 1 → 1.16, `easeOutBack`, 160 ms out / 320 ms back; count 260 ms |
| Top bar | min height 64; 44×44 back target |
| Dock | padding `16, 14, 16, 18`; max width 430; debrief switch 220 ms |
| Progress segment | 8px tall, 5px apart, 220 ms |
| Pager button | 56px tall; chamfer 14 / 7; focal cyan glow blur 13 |
| Charge edge | 3px white, blur 3 |
| Summary | stars lead 420 ms, then 260 ms apart; plates 62×56, stamp 2.1× → 1 over 320 ms |
| Summary entrance | `_RevealIn` 420 ms × (1 + delay), rise 14px; delays 0 / .2 / .35 / .5 / .65 / .75 / .85 / .95 |
| Summary XP | `display 40` gold, counts up over 700 ms |
| Level bar | 8px, 700 ms; 50 XP × level × (level − 1) to reach each level |
| Perfect backdrop | platinum pack reveal at 12% pulse + 12 amber rays |

---

## 11. Design rules to keep

1. **Never leak the verdict early** — not in the HUD, the dock, sound, haptics or semantics.
2. **The scan is the same for everyone.** Tension comes from not knowing.
3. **Name the right answer every time**, right or wrong.
4. **The streak is feedback, not payout.**
5. **The last question waits for the player.**
6. **Quitting keeps what you earned** and costs only the fee; say both in the dialog.
7. **Pay out once.** Bank XP on finish or confirmed exit, never twice.
8. **Snapshot for the summary.** Read "before" values, then save, then show.
9. **Replays deal the same set.** Mastery means beating a fixed test.
10. **A fault, not a wobble** — fixed tear geometry and a square wave.
11. **Motion is optional.** Every effect has a reduced-motion path — and the auto-advance
    must honour it too (§3.4).
12. **Glow means live.** On the question: the pick, then the verdict, plus the primary button.
    Not the always-on badge (§5.3). The summary is a moment and may glow freely.

---

## 12. Tests

### 12.1 Existing — [`test/quiz_set_flow_test.dart`](../../test/quiz_set_flow_test.dart)

Seventeen tests exercise the play screen:

| Test | Pins |
| --- | --- |
| *play screen uses the active sport and protects paid progress* | `FOOTBALL QUIZ`, `XP EARNED`; picking an option then tapping `Exit quiz` opens `EXIT QUIZ?` with *will not be refunded* |
| *a sport with no authored ladder shows a holding screen* | empty pool → `TENNIS QUIZ`, `SET NOT WRITTEN YET`, no options |
| *cricket / basketball / motorsport / tennis render authored questions through the final set* (4) | GLOBAL set 50 → `<SPORT> QUIZ`, `GLOBAL · SET 50`, option 0 present |
| *a flawless tennis / motorsport / basketball set pays XP, stars and its unlock* (3) | EASY set 1 at 10/10 → 10 XP, set 2 unlocked, 3 stars |
| *locking an answer reveals the verdict before advancing* | nothing graded before LOCK IN; then `ANSWER LOCKED`, `SIGNAL LOCKED`, `ANSWER CONFIRMED · …`, `quiz-advance` present, `LOCK IN` gone |
| *the verdict auto-advances after the charge tops up* | still `1/10` 1.5 s after the verdict; `2/10` with the next prompt once the 3 s charge completes — no tap |
| *the last question waits for a tap instead of auto-advancing* | 5 s after the last verdict: `SEE RESULTS` still up, no summary, **0 XP** |
| *a wrong answer names the correct one immediately* | `SIGNAL LOST`, `ANSWER WAS · …`; `// CORRECT` after the tear |
| *a flawless set awards XP, three stars and the next set* | 10 XP, set 2 unlocked, 3 stars; `FLAWLESS SET`, `+3 STARS EARNED`, `SET 2 UNLOCKED`, `CONTINUE TO SETS` |
| *a low score still clears the set and pays for what was right* | 3/10 → 3 XP, set 2 unlocked, 1 star; `SET CLEARED`, review panel present; replay spends 25 coins |
| *quitting mid-run banks earned XP but does not clear the set* | MEDIUM, 2 right → `+4 XP is banked`; after EXIT QUIZ: 4 XP, set 2 locked, 0 attempts |
| *quiz surfaces fit a narrow reduced-motion layout* | 320×640, 1.3× text: no overflow; locking a wrong answer shows `SIGNAL LOST` |

**Keys:** `quiz-option-<i>` · `quiz-lock-answer` · `quiz-advance` · `quiz-debrief` /
`quiz-no-debrief` · `quiz-summary` · `quiz-answer-review` · `quiz-replay` · semantics label
`Exit quiz`.

The harness wraps the screen in `MultiBlocProvider` + `MaterialApp` with
`splashFactory: NoSplash.splashFactory` — the exit dialog's stock buttons use the ink-sparkle
shader, which the test runtime can't decode.

### 12.2 Recommended additions

None of the three known issues is caught today. The last narrow-layout test is the closest,
but it sets only `MediaQuery`'s flag, which doesn't change how the controller runs. This test
uses the **platform** flag, as a real device does; it fails against the current code and passes
once the §3.4 fix is in:

```dart
testWidgets('reduced motion never deals the next question on its own', (tester) async {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  // …pump QuizPlayScreen as the suite does, then pick the right option and tap LOCK IN.
  await tester.pump(const Duration(seconds: 5));
  expect(find.text('1/10'), findsOneWidget); // still on question 1 — the player advances
});
```

Worth adding alongside it: backing out during the 210 ms scan beat doesn't deal a question
behind the dialog, and choosing KEEP PLAYING resumes the charge.

---

## 13. Port checklist

1. **Port the lobby doc's App. A, B and C** — models, cubit, bank and shared widgets.
2. **Use this doc's App. C as your stand-ins**, in place of the lobby doc's App. D. Don't keep
   both; this one is the superset.
3. **Add App. A and App. B** from this doc. The six segment colours in App. B rely on
   `_segTrack` from the lobby doc's App. C.
4. **Paste §3–§8.** One library, or split into files and make the private names public.
5. **Wire it.** The ladder pushes `QuizPlayScreen(sport:, mode:, setNumber:)` after charging the
   fee. `GameBloc` and `QuizCubit` must be provided above it. Preload the bank; the screen
   recovers if you don't.
6. **Map the sound palette** — 13 cues — and give `AudioScene.quiz` its music.
7. **Decide the known issues:** the reduced-motion auto-advance (a one-line fix, §3.4); the
   dialog race and frozen charge (§3.5); the always-on badge glow (§5.3); keyboard activation
   (§5.4).
8. **Verify.** `flutter analyze` clean; then in the app: a pick glows, the scan gives nothing
   away, a correct answer sweeps and a wrong one tears, the right answer is always named, NEXT
   charges and deals the next question, the last question waits, a quit keeps its XP, and the
   summary stamps its stars and unlocks the next set. Then turn on the OS reduced-motion setting
   and check the verdict stays up until you tap.

---

## Implementation References

- [`lib/screens/quiz/quiz_play_screen.dart`](../../lib/screens/quiz/quiz_play_screen.dart) —
  `_QuestionPhase` (23), `QuizPlayScreen` (34), state (50), `_verdictFor` (88), `initState` (96),
  `_loadQuestions` (111), `dispose` (118), `_select` (125), `_lockAnswer` (134), `_landVerdict`
  (177), **unconditional charge start (193)**, `_advance` (196), `_requestExit` (212),
  `_bankEarnedXp` (260), `_finish` (275), `_retry` (327), `build` (384), `PopScope` (395), overlay
  mount (498), `_buildAwaitingQuestions` (524), `_helperText` (588), `_TopBar` (597), `_QuizHeader`
  (656), `_XpEarnedMetric` (719), `_HudMetric` (772), `_MetricDivider` (818), `_CornerBracketsPainter`
  (830), `_QuestionPanel` (853), **always-on badge glow (957)**, `_OptionTile` (974), `_BottomDock`
  (1183), charging-vs-plain button switch (1285).
- [`lib/screens/quiz/widgets/answer_verdict.dart`](../../lib/screens/quiz/widgets/answer_verdict.dart)
  — `kVerdictDuration` (23), beat ends (25–26), `kAutoAdvanceDelay` (30), `verdictBeat` (33),
  `verdictStreakAccent` (38), `VerdictScanline` (47), `SignalLockFx` (101), `GlitchTear` (235),
  `ChargingHudButton` (339), `VerdictDebriefStrip` (432).
- [`lib/screens/quiz/widgets/quiz_reveal.dart`](../../lib/screens/quiz/widgets/quiz_reveal.dart)
  — `QuizRevealOverlay` (23), state (65), `_play` (89), `_ScoreLine` (247), `_StarAward` (304),
  `_StarPlate` (341), `_RevealIn` (395), `_AnswerReview` (426), `_XpTotal` (518), `_ClearBanner`
  (550), `_LevelLine` (592).
- Data: [`quiz_trivia_bank.dart`](../../lib/services/quiz_trivia_bank.dart) `buildQuizSet` (25);
  [`settlement_reveal.dart`](../../lib/screens/predictions/widgets/settlement_reveal.dart)
  `SettlementQuestionResult` (18); [`prediction.dart`](../../lib/models/prediction.dart)
  `PredictionMultiplier` (42); [`progression.dart`](../../lib/models/progression.dart) `xpToReach`
  (8), `levelFromXp` (10), `LevelProgress` (19), `levelProgress` (35).
- Shared widgets: [`cyber_widgets.dart`](../../lib/widgets/cyber/cyber_widgets.dart) `PackBurst`
  (194), `HudPagerButton` (3570), `_HudPagerButtonPainter` (3634), segment colours (3693–3699),
  `HudProgressSegment` (3708); [`card_unpack_animation.dart`](../../lib/widgets/card_unpack_animation.dart)
  `PackRevealBackground` (226).
- XP: [`game_bloc.dart`](../../lib/blocs/game/game_bloc.dart) `_onPredictionXpAdded` (652).
- Audio: [`sound_effects.dart`](../../lib/utils/sound_effects.dart) `AudioScene` (9),
  `AudioController` (613), `enterScene` (685), `leaveScene` (701).
- Framework: Flutter 3.44.4, `packages/flutter/lib/src/animation/animation_controller.dart` —
  the 0.05 reduced-motion scale (651) and `_InterpolationSimulation`, which applies it.
- Tests: [`test/quiz_set_flow_test.dart`](../../test/quiz_set_flow_test.dart) (254–782, 832–868).
- Pair: [`quiz-lobby-and-set-ladder.md`](quiz-lobby-and-set-ladder.md).
- Product: [`docs/product/games/football-quiz.md`](../product/games/football-quiz.md) and its four
  sport siblings.

---

## Appendix A — data the screen reads, verbatim

### A.1 `buildQuizSet` — `lib/services/quiz_trivia_bank.dart`

Callers must `await QuizBank.ensureLoaded(sport, mode)` first; this is a synchronous read of the
cache so the screen can lay out on its first frame.

```dart
/// The 10 questions behind [setNumber] (1…[kQuizSetCount]).
///
/// Deterministic — the same set always deals the same questions in the same
/// order, which is what makes chasing a 3-star run worthwhile. Returns an empty
/// list when the pool isn't loaded, or when the set is past the authored range.
List<TriviaQuestion> buildQuizSet(Sport sport, QuizMode mode, int setNumber) {
  final pool = QuizBank.pool(sport, mode);
  final clampedSet = setNumber.clamp(1, kQuizSetCount);
  final start = (clampedSet - 1) * kQuizQuestionsPerSet;
  if (start + kQuizQuestionsPerSet > pool.length) return const [];
  return List<TriviaQuestion>.unmodifiable(
    pool.sublist(start, start + kQuizQuestionsPerSet),
  );
}
```

### A.2 `SettlementQuestionResult` — `lib/screens/predictions/widgets/settlement_reveal.dart`

Shared with the prediction settlement flow, which is why it carries a `multiplier` the quiz never
sets.

```dart
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
```

### A.3 `PredictionMultiplier` — `lib/models/prediction.dart`

Needed only because A.2 names it. Small and self-contained, so it's included as-is.

```dart
enum PredictionMultiplier {
  x2('x2', '2x', 2.0),
  x15('x15', '1.5x', 1.5);

  const PredictionMultiplier(this.jsonKey, this.label, this.factor);

  final String jsonKey;
  final String label;
  final double factor;

  static PredictionMultiplier? fromJsonKey(String? key) {
    for (final multiplier in values) {
      if (multiplier.jsonKey == key) return multiplier;
    }
    return null;
  }

  int applyTo(int reward) => (reward * factor).ceil();
}
```

### A.4 Level maths — `lib/models/progression.dart`

The curve behind the summary's level bar: level *L* takes `50 × L × (L − 1)` total XP to reach —
0, 100, 300, 600 …

```dart
// Cumulative XP required to reach level L. L1 = 0, L2 = 100, L3 = 300.
const int _kLevelXp = 50;

int xpToReach(int level) => _kLevelXp * level * (level - 1);

int levelFromXp(int totalXp) {
  final xp = max(0, totalXp);
  final level =
      ((_kLevelXp + sqrt(_kLevelXp * _kLevelXp + 4 * _kLevelXp * xp)) /
              (2 * _kLevelXp))
          .floor();
  return max(1, level);
}

class LevelProgress {
  const LevelProgress({
    required this.level,
    required this.intoLevel,
    required this.levelSpan,
    required this.toNextLevel,
    required this.pct,
  });

  final int level;
  final int intoLevel;
  final int levelSpan;
  final int toNextLevel;
  final double pct;
}

LevelProgress levelProgress(int totalXp) {
  final xp = max(0, totalXp);
  final level = levelFromXp(xp);
  final start = xpToReach(level);
  final next = xpToReach(level + 1);
  final span = next - start;
  final into = xp - start;
  return LevelProgress(
    level: level,
    intoLevel: into,
    levelSpan: span,
    toNextLevel: next - xp,
    pct: span == 0 ? 0 : (into / span).clamp(0.0, 1.0),
  );
}
```

---

## Appendix B — shared widgets, verbatim

From `lib/widgets/cyber/cyber_widgets.dart`.

### B.1 `HudPagerButton`

The dock's LOCK IN / NEXT / SEE RESULTS button and the summary's replay button. `focal` is the
bright glowing forward action; otherwise it's a calm dark plate.

```dart
/// An angular HUD pager button on the [HudChamferClipper] silhouette.
/// [focal] = the bright glowing forward CTA (NEXT/SUBMIT); otherwise a calm dark
/// plate (PREVIOUS). Disabled state dims content and calms the plate.
class HudPagerButton extends StatelessWidget {
  const HudPagerButton({
    required this.label,
    required this.focal,
    required this.enabled,
    required this.onTap,
    this.leadingIcon,
    this.trailingIcon,
    super.key,
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
          painter: _HudPagerButtonPainter(focal: focal, enabled: enabled),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
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
        ),
      ),
    );
  }
}

class _HudPagerButtonPainter extends CustomPainter {
  const _HudPagerButtonPainter({required this.focal, required this.enabled});
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
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Colors.white.withValues(alpha: enabled ? 0.72 : 0.32),
      );
    } else {
      // Calm dark plate (PREVIOUS, or a disabled forward action).
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
  bool shouldRepaint(covariant _HudPagerButtonPainter old) =>
      old.focal != focal || old.enabled != enabled;
}
```

### B.2 `HudProgressSegment`

**The six colour constants below are the file's `_seg*` set minus `_segTrack`**, which the lobby
doc's App. C already defines (with `CyberStarRating`). Porting both docs into one library with a
second copy would be a duplicate-declaration error.

```dart
const _segGreenA = Color(0xFF00C850);
const _segGreenB = Color(0xFF009865);
const _segAmberA = Color(0xFFFFB13D);
const _segAmberB = Color(0xFFFF7A1A);
const _segRedA = Color(0xFFFF6B6B);
const _segRedB = Color(0xFFC81E30);

/// One bar in a paginated progress row: amber "you are here" for [current],
/// green for already-[answered]/passed, slate otherwise. Only the current
/// segment glows.
///
/// Pass [verdict] on quiz-style rows where an answer has already been marked
/// right or wrong — the segment then reads as a scoreboard (green = correct,
/// red = wrong) instead of a plain answered/unanswered tracker.
class HudProgressSegment extends StatelessWidget {
  const HudProgressSegment({
    required this.answered,
    required this.current,
    this.verdict,
    super.key,
  });

  final bool answered;
  final bool current;

  /// null = not graded (default, the original behaviour).
  final bool? verdict;

  @override
  Widget build(BuildContext context) {
    final graded = verdict != null;
    final Gradient? gradient = graded
        ? LinearGradient(
            colors: verdict!
                ? const [_segGreenA, _segGreenB]
                : const [_segRedA, _segRedB],
          )
        : current
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
        boxShadow: current && !graded
            ? Cyber.glow(Cyber.amber, alpha: 0.35, blur: 8)
            : null,
      ),
    );
  }
}
```

### B.3 `PackBurst`

The 12-ray amber starburst behind a perfect summary. Uses `pi` from an unprefixed `dart:math`.

```dart
class PackBurst extends StatelessWidget {
  const PackBurst({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 310,
      height: 310,
      child: Stack(
        children: [
          for (var i = 0; i < 12; i++)
            Positioned.fill(
              child: Transform.rotate(
                angle: i * pi / 6,
                child: Align(
                  alignment: const Alignment(0, -0.38),
                  child: Container(
                    width: 3,
                    height: 126,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Cyber.amber.withValues(alpha: 0.95),
                          Colors.transparent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Cyber.amber.withValues(alpha: 0.5),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

---

## Appendix C — stand-ins

**This appendix replaces App. D of [`quiz-lobby-and-set-ladder.md`](quiz-lobby-and-set-ladder.md)**
for anyone porting both screens. It keeps every name the lobby code uses and adds what the play
screen needs: `Cyber.borderMuted`; the full 13-cue sound palette; `AudioScene` and
`AudioController`; XP on the wallet (`PredictionXpAdded`, `XpTransactionSource`, and
`state.progression.totalXP`); and a stand-in for the perfect-run backdrop. It drops the lobby
doc's placeholder play screen — the real one is §3.

The whole port — both docs — is one library with these imports:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
```

```dart
// ─── Appendix C stand-ins (supersede App. D of quiz-lobby-and-set-ladder.md) ─
// One file that serves BOTH quiz screens. Every declaration keeps the exact
// name and call shape the verbatim code uses, so the lobby's §3–§11, this
// doc's §3–§9 and both docs' appendices compile on top of it unedited.

/// The five sports. Several switches over this are exhaustive — adding a sport
/// is a compile error until every one handles it, which is the point.
enum Sport { football, cricket, motorsport, basketball, tennis }

/// C.1 — Design tokens. Every alias resolved to the source app's literal.
abstract final class Cyber {
  // Surfaces
  static const bg = Color(0xFF0D111A);
  static const panel = Color(0xFF1D293D);
  static const panel2 = Color(0xFF0F172B);

  // Lines and muted text
  static const border = Color(0xFF314158);
  static const borderMuted = Color(0xFF243654); // play-screen hairlines
  static const line = Color(0xFF45556C);
  static const muted = Color(0xFF90A1B9);

  // Accents
  static const cyan = Color(0xFF5CDFFF); // primary; the scan beat
  static const lime = Color(0xFF51FF94); // EASY
  static const amber = Color(0xFFFF8904); // MEDIUM; streak ×3; current segment
  static const danger = Color(0xFFFF4D4D); // HARD; wrong verdict
  static const violet = Color(0xFFC27AFF); // GLOBAL
  static const gold = Color(0xFFFDC700); // XP, stars, streak ×5 — rewards only
  static const success = Color(0xFF05DF72); // correct verdict; answer key

  static const displayFont = 'Orbitron';
  static const bodyFont = 'Onest';

  static List<BoxShadow> glow(
    Color color, {
    double alpha = 0.3,
    double blur = 16,
    double spread = -2,
  }) => [
    BoxShadow(
      color: color.withValues(alpha: alpha),
      blurRadius: blur,
      spreadRadius: spread,
    ),
  ];

  static TextStyle display(
    double size, {
    Color color = Colors.white,
    double letterSpacing = 1.5,
    FontWeight weight = FontWeight.w900,
  }) => TextStyle(
    color: color,
    fontFamily: displayFont,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    height: 1,
    decoration: TextDecoration.none,
  );

  static TextStyle body(
    double size, {
    Color color = Colors.white,
    FontWeight weight = FontWeight.w500,
    double letterSpacing = 0,
    double height = 1.35,
    List<FontFeature>? fontFeatures,
  }) => TextStyle(
    color: color,
    fontFamily: bodyFont,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    height: height,
    fontFeatures: fontFeatures,
    decoration: TextDecoration.none,
  );

  static TextStyle label(
    double size, {
    Color color = Colors.white,
    FontWeight weight = FontWeight.w800,
    double letterSpacing = 0.9,
    double height = 1,
    List<FontFeature>? fontFeatures,
  }) => TextStyle(
    color: color,
    fontFamily: displayFont,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    height: height,
    fontFeatures: fontFeatures,
    decoration: TextDecoration.none,
  );
}

/// The `AppTheme` members the verbatim code still names — two spinners and
/// `CyberPlainBackground`. A shim means none of them needs editing.
abstract final class AppTheme {
  static const textPrimary = Cyber.cyan;
  static LinearGradient get backgroundGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF010916), Color(0xFF0E2646)],
  );
}

/// C.2 — Sound. Every cue either quiz screen plays. Wire to your audio layer.
enum SoundEffect {
  uiTap,
  uiConfirm,
  cardSelect,
  countdownTick,
  playMatch,
  coinSpend,
  whoosh,
  quizCorrect,
  quizWrong,
  quizPerfect,
  quizPass,
  quizSubmit,
  quizUnlock,
}

void playSound(SoundEffect effect) {}

/// Scene music. The play screen enters [AudioScene.quiz] in `initState` and
/// leaves it in `dispose`. Keep the guard in [leaveScene]: leaving a scene that
/// is no longer current must not stop whatever another screen started.
enum AudioScene { quiz }

class AudioController {
  AudioController._();

  static final AudioController instance = AudioController._();

  AudioScene? _scene;

  Future<void> enterScene(AudioScene scene, {bool musicEnabled = true}) async {
    _scene = scene;
  }

  Future<void> leaveScene([AudioScene? scene]) async {
    if (scene != null && scene != _scene) return;
    _scene = null;
  }
}

/// C.3 — Persistence. Same contract as the source app's secure storage (JSON
/// per sport, corrupt data → fresh progress), kept in memory.
class SecureGameStorage {
  final Map<Sport, String> _store = {};

  Future<QuizProgress> loadQuizProgress(Sport sport) async {
    try {
      final raw = _store[sport];
      if (raw == null || raw.isEmpty) return QuizProgress.initial();
      return QuizProgress.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return QuizProgress.initial();
    }
  }

  Future<void> saveQuizProgress(Sport sport, QuizProgress progress) async {
    _store[sport] = jsonEncode(progress.toJson());
  }
}

/// C.4 — Wallet and XP. Stands in for the app's `GameBloc`, keeping coins and
/// total XP only.
///
/// **Keep both refusals.** A spend that would go below zero, and an XP award of
/// zero or less, emit nothing — exactly as the source bloc does. The screens'
/// own guards are written against that behaviour.
enum OzCoinTransactionSource { quizEntry, manual }

enum XpTransactionSource { prediction, quiz }

abstract class GameEvent {}

class CoinsAdded extends GameEvent {
  CoinsAdded(this.amount);
  final int amount;
}

class CoinsSpent extends GameEvent {
  CoinsSpent(
    this.amount, {
    this.source = OzCoinTransactionSource.manual,
    this.title,
    this.subtitle,
  });

  final int amount;
  final OzCoinTransactionSource source;
  final String? title;
  final String? subtitle;
}

class PredictionXpAdded extends GameEvent {
  PredictionXpAdded(
    this.amount, {
    this.details,
    this.source = XpTransactionSource.prediction,
    this.title = 'PREDICTION REWARD',
  });

  final int amount;
  final String? details;
  final XpTransactionSource source;
  final String title;
}

class Progression {
  const Progression({this.totalXP = 0});
  final int totalXP;
}

class GameState {
  const GameState({this.coins = 0, this.progression = const Progression()});

  final int coins;
  final Progression progression;

  GameState copyWith({int? coins, Progression? progression}) => GameState(
    coins: coins ?? this.coins,
    progression: progression ?? this.progression,
  );
}

class GameBloc extends Bloc<GameEvent, GameState> {
  GameBloc({int coins = 0}) : super(GameState(coins: coins)) {
    on<CoinsAdded>(
      (event, emit) => emit(state.copyWith(coins: state.coins + event.amount)),
    );
    on<CoinsSpent>((event, emit) {
      final next = state.coins - event.amount;
      if (next < 0) return; // silent refusal
      emit(state.copyWith(coins: next));
    });
    on<PredictionXpAdded>((event, emit) {
      if (event.amount <= 0) return; // silent refusal
      emit(
        state.copyWith(
          progression: Progression(
            totalXP: state.progression.totalXP + event.amount,
          ),
        ),
      );
    });
  }
}

/// C.5 — Page chrome for the lobby screens. The play screen draws its own.
class GameScaffold extends StatelessWidget {
  const GameScaffold({
    required this.title,
    required this.child,
    this.subtitle,
    this.leading,
    this.rightSlot,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? rightSlot;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(66),
        child: SafeArea(
          bottom: false,
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xff0b1120), Color(0xff070b14)],
              ),
              border: Border(bottom: BorderSide(color: Cyber.cyan, width: 2)),
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  SizedBox(width: 42, height: 42, child: leading),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '/ ${title.toUpperCase()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Cyber.display(18, letterSpacing: 1.3),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          overflow: TextOverflow.ellipsis,
                          style: Cyber.label(11, color: Cyber.muted),
                        ),
                    ],
                  ),
                ),
                ?rightSlot,
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(top: false, child: child),
    );
  }
}

/// C.6 — Leaderboard entry point for the lobby. Flat plate, never glows.
enum GameMode { quiz }

class GameLeaderboardButton extends StatelessWidget {
  const GameLeaderboardButton({
    required this.sport,
    required this.mode,
    this.accent = Cyber.cyan,
    super.key,
  });

  final Sport sport;
  final GameMode mode;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Leaderboard',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => playSound(SoundEffect.uiTap), // push your board here
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Cyber.panel.withValues(alpha: 0.55),
            border: Border.all(color: accent.withValues(alpha: 0.5)),
          ),
          child: Icon(Icons.leaderboard_rounded, color: accent, size: 19),
        ),
      ),
    );
  }
}

/// C.7 — The perfect-run backdrop. The source version reuses the pack-opening
/// reveal (rarity glow, scanline sweep, vignette and rotating god-rays, built
/// from a ~250-line painter chain in `card_unpack_animation.dart`). This keeps
/// its constructor and its two readable traits — a pulsing rarity glow and a
/// slow 16 s ray rotation — in a fraction of the code.
class PackRevealBackground extends StatefulWidget {
  const PackRevealBackground({
    this.rarity = 'platinum',
    this.pulseOpacity = 0.1,
    this.showRays = true,
    super.key,
  });

  final String rarity;
  final double pulseOpacity;
  final bool showRays;

  @override
  State<PackRevealBackground> createState() => _PackRevealBackgroundState();
}

class _PackRevealBackgroundState extends State<PackRevealBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beam = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
  )..repeat();

  @override
  void dispose() {
    _beam.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glow = widget.rarity == 'platinum'
        ? const Color(0xFFE5F4FF)
        : Cyber.gold;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _beam,
        builder: (context, _) {
          final t = _beam.value;
          final pulse = 0.6 + 0.4 * sin(t * 2 * pi * 8);
          return Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Cyber.bg),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 0.9,
                    colors: [
                      glow.withValues(alpha: widget.pulseOpacity * pulse),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              if (widget.showRays)
                CustomPaint(painter: _RevealRaysPainter(glow, t)),
            ],
          );
        },
      ),
    );
  }
}

class _RevealRaysPainter extends CustomPainter {
  const _RevealRaysPainter(this.color, this.rotation);

  final Color color;
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final reach = size.longestSide;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 12; i++) {
      final a = rotation * 2 * pi + i * pi / 6;
      canvas.drawPath(
        Path()
          ..moveTo(centre.dx, centre.dy)
          ..lineTo(
            centre.dx + reach * cos(a - 0.06),
            centre.dy + reach * sin(a - 0.06),
          )
          ..lineTo(
            centre.dx + reach * cos(a + 0.06),
            centre.dy + reach * sin(a + 0.06),
          )
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RevealRaysPainter old) =>
      old.rotation != rotation || old.color != color;
}
```

Notes:

- **C.4 wallet.** Both refusals are deliberate — a spend below zero and an XP award of zero or
  less emit nothing, as in the source app. `_bankEarnedXp` and `_retry` are written against that
  behaviour. The real bloc also persists both values and writes a ledger entry for each
  transaction, which is what the `title`, `subtitle` and `details` fields are for.
- **C.2 audio.** `AudioController.instance` here is a field rather than the source's lazy getter;
  call sites are identical. Keep `leaveScene`'s scene check.
- **C.7 backdrop.** The source reuses the pack-opening reveal — rarity glow, scanline sweep,
  vignette and rotating god-rays, about 160 lines of widgets and painters plus rarity helpers in
  `card_unpack_animation.dart`. The stand-in keeps the constructor and its two readable traits (a
  pulsing glow and a slow 16 s ray rotation). It only ever shows behind a perfect run.
