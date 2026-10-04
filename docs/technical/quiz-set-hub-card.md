# Quiz Set Hub Card — implementation and porting reference

> **Status:** BUILT
> **Last verified:** 2026-09-11
> **Scope:** `_QuizSetHubCard` in
> [`lib/screens/predictions/match_prediction_screen.dart`](../../lib/screens/predictions/match_prediction_screen.dart)
> — the per-quiz "objective" card on a match's PREDICT tab — with every state it
> can show and every widget it is built from.

**Written to be portable.** Every widget, painter, model and helper the card
touches is reproduced *exactly as implemented*, in the section that explains it.
The appendices add a flattened drop-in copy of the design tokens and stand-ins
for the three things that cannot travel (team palettes, the coin balance, UI
sound).

---

## 0. Port map

| # | Layer | Source | Here |
| --- | --- | --- | --- |
| 1 | State → look mapping | `_QuizHubVisual`, `_ContestMeta`, `_resolveQuizHubVisual` | §3 — verbatim |
| 2 | The card | `_QuizSetHubCard` + state | §4 — verbatim |
| 3 | Silhouette + elevation | `HudChamferClipper`, `_QuizChamferPanelPainter`, `_QuizHubHardShadowPainter` | §5 — verbatim |
| 4 | Leaves | `_IndexPlate`, `_RewardPill`, `_HubDivider`, `_ChevronChip`, `_HubOutcomeDots`, `_HubOutcomeDot` | §6 — verbatim |
| 5 | Contest ribbon | `_ContestStrip`, `_ContestChip`, `CoinIcon` | §7 — verbatim |
| 6 | Meter | `CyberProgressBar` | §8 — verbatim |
| 7 | Host + tap routing | the `ListView` loop, `_openQuizSet` | §9 — verbatim |
| 8 | Models + helpers | `PredictionQuiz`, `QuizQuestion`, `UserPrediction`, `PredictionStatus`, `questionOutcomes` | App. A — verbatim |
| 9 | Tokens + stand-ins | `Cyber`, `paletteForTeam`, coins, `playSound` | App. B |

**Toolchain:** Dart 3 (`switch` expressions in `_HubOutcomeDot`), Flutter 3.27+
(`Color.withValues`), fonts Orbitron + Onest. Third-party: `flutter_bloc` (only
for the coin read — see App. B) and `flutter_svg` (only for `CoinIcon`).

---

## 1. What it is

A match can carry one or more prediction quizzes ("sets"). The PREDICT tab lists
one `_QuizSetHubCard` per set; tapping a card opens that set. The card's job is
to answer, at a glance, **"what can I do with this quiz right now, and what is
it worth?"** — so every state is phrased as a game objective with a status tag,
a stake, a meter and a call to action.

```
_QuizSetHubCard(match, quiz, index, prediction, onTap)
  └─ Semantics(button) → GestureDetector      tap → onTap, or a snackbar if blocked
       └─ AnimatedBuilder(_pulse)             only runs in REWARD READY
            └─ Stack
                 ├─ _QuizHubHardShadowPainter  solid edge 5px below   (elevation)
                 └─ [glow?] CustomPaint(_QuizChamferPanelPainter)      (border)
                      └─ ClipPath(HudChamferClipper 12/3)
                           └─ team-vs-team gradient over #06152B
                                └─ Row
                                     ├─ _IndexPlate            "01"
                                     └─ Column
                                          ├─ tag / title       + _RewardPill
                                          ├─ subtitle
                                          ├─ _ContestStrip     (paid contests only)
                                          ├─ CyberProgressBar  6px meter
                                          ├─ _HubDivider
                                          └─ ctaIcon  ctaText  _HubOutcomeDots | _ChevronChip
```

The screenshot state — `FINAL RESULTS` / `VIEW` / `VIEW COMMUNITY RESULTS` with
an empty meter and a chevron — is branch 3 below.

---

## 2. The inputs

| Input | Type | Drives |
| --- | --- | --- |
| `match` | `SportMatch` | `status` (upcoming / live / finished), `kickoff`, and both teams' colours for the background wash |
| `quiz` | `PredictionQuiz` | `title`, `subtitle`, `questions.length`, `maxReward` (sum of question XP), `isContest` (`entryFee > 0`), `entryFee`, `settleable` (every question settled) |
| `index` | `int` | the `01` plate — 1-based position in the list |
| `prediction` | `UserPrediction?` | `null` = never entered. Otherwise `status` (`open` / `locked` / `settled`), `answers`, `correctCount`, `rewardEarned`, `contestRank`, `contestPrizeOz` |
| coin balance | `int?` | read inside the card, **only for contests**, to decide ENTRY LOCKED |
| `onTap` | `VoidCallback` | the host's open action; bypassed when the state is `blocked` |

---

## 3. Every state — `_resolveQuizHubVisual`

The whole visual vocabulary of the card is computed by one pure function that
returns a `_QuizHubVisual`. **It is an ordered `if` chain: the first matching
branch wins**, so order is part of the contract.

### 3.1 The state table

`total` = `quiz.questions.length`; `answered` = `prediction.answers.length`;
`XP` = `quiz.maxReward`.

| # | Condition (in order) | Tag | Accent | Meter | CTA icon · text | Pill | Trailing | Tap | Glow |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | finished **and** settled | `PRIZE WON` if contest coins won, else `SETTLED` | gold if any correct or coins won, else muted | `correct/total` (success, or muted if none) | `military_tech` or `done_all` · `'<c> / <t> CORRECT'` | `+<earned> XP` (success) or `NO XP` (muted) | **outcome dots** | open | — |
| 2 | finished **and** entered, not yet settled | `REWARD READY` | gold | full, gold | `redeem` · `TAP TO REVEAL RESULTS` (contest: `… RESULT · PRIZE`) | `REVEAL` gold | chevron | open | **yes — pulsing** |
| 3 | finished, never entered | `FINAL RESULTS` if `settleable`, else `RESULT VERIFYING` | cyan / amber | empty | `query_stats` · `VIEW COMMUNITY RESULTS` / `VIEW CROWD SIGNAL` | `VIEW` | chevron | open | — |
| 4 | live | `LIVE` | danger | `answered/total` | `lock_outline` · `LOCKED PICKS · MATCH IN PROGRESS` | `IN PLAY` if entered, else `CLOSED` | none | **blocked** if never entered | — |
| 5 | kickoff passed (feed still says upcoming) **and** never entered | `CLOSED` | muted | empty | `lock_clock_outlined` · `KICKOFF PASSED · NO ENTRY` | `MISSED` | none | **blocked** | — |
| 6 | prediction locked | `LOCKED IN` | success | `answered/total` | `how_to_vote_outlined` · `VIEW CROWD VOTES` | `+<XP> XP` gold | chevron | open | — |
| 7 | entered (open draft) | `DRAFT ACTIVE` if all answered, else `IN PROGRESS` | cyan | `answered/total` | `edit` · `REVIEW & LOCK` / `'RESUME · <a>/<t> ANSWERED'` | `+<XP> XP` gold | chevron | open | — |
| 8 | contest **and** can't afford the fee | `ENTRY LOCKED` | muted | empty | `lock_outline` · `'NEED <fee> OZ TO ENTER'` | `+<XP> XP` muted | none | **blocked** | — |
| 9 | everything else | `OBJECTIVE` | cyan | empty | `bolt` · `'TAP TO PREDICT · <t> QUESTIONS'` | `+<XP> XP` gold | chevron | open | — |

That is 9 branches and 12 distinct tags. Every branch also carries the contest
metadata (`contestFor(...)`) except branch 3, which has none.

### 3.2 Why the order is what it is

- **Settled beats reward-ready (1 before 2).** Once the reveal has been watched
  and the prediction settles, the card calms down to a verdict; the moment
  already happened.
- **Reward-ready requires an actual entry (2).** The quiz is looked up by match
  id whether or not the player ever played it, so `quiz.settleable` alone would
  light up a reward card for someone who never entered. The comment in source
  says exactly this.
- **Live before closed (4 before 5).** A live match is its own state even for a
  player who missed it — they see LIVE, blocked, not a generic CLOSED.
- **Branch 5 exists because score feeds lag.** A just-started fixture can still
  report `upcoming`; the local kickoff clock closes *fresh* entry. Players with an
  existing draft fall through to 6/7, so the deadline-lock path can still seal
  their last saved answers.
- **Affordability is checked last (8).** A player who already paid (`prediction
  != null`) has left the chain at 6 or 7 and is never re-gated by their balance.

### 3.3 The look object and contest metadata

`_QuizHubVisual` is a plain value object — nothing in it is computed. Two fields
are the card's behaviour switches rather than looks:

- **`glow` / `pulse`** — only branch 2 sets them. The card is the one glowing,
  breathing focal element on the screen in that state and nowhere else.
- **`blocked` / `blockedMessage`** — branches 4 (unentered), 5 and 8. The card
  swallows the tap and shows the message instead of calling `onTap`.

`_ContestMeta` carries the paid-contest context (fee, paid, affordable, and the
post-settle rank and prize) to the ribbon in §7. It is `null` for free quizzes.

> Note: in source the doc comment `/// Resolved per-state look for a quiz-set
> hub card…` sits above `_ContestMeta`, but it describes `_QuizHubVisual`; the
> comment was left behind when `_ContestMeta` was inserted between them. It is
> reproduced as-is below.

**Full source:**

```dart
/// Resolved per-state look for a quiz-set hub card. Keeps the visual language
/// gamified: every state reads as an "objective" with a status tag, a reward
/// stake, a completion/accuracy meter and a call-to-action.
/// State of a paid-contest quiz, drives the [_ContestStrip] on its hub card.
class _ContestMeta {
  const _ContestMeta({
    required this.fee,
    this.paid = false,
    this.affordable = true,
    this.rank = 0,
    this.prizeOz = 0,
    this.settled = false,
  });

  final int fee;
  final bool paid;
  final bool affordable;
  final int rank; // finish position once settled (0 = not settled)
  final int prizeOz; // coins won (0 = none / off podium)
  final bool settled;
}

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
    this.blocked = false,
    this.blockedMessage,
    this.contest,
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

  /// Entry is barred (can't afford the fee) — tap is intercepted, card muted.
  final bool blocked;
  final String? blockedMessage;

  /// Paid-contest metadata (null for free/XP-only quizzes).
  final _ContestMeta? contest;
  final List<QuestionOutcome>? outcomes;
}
```

```dart
_QuizHubVisual _resolveQuizHubVisual(
  SportMatch match,
  PredictionQuiz quiz,
  UserPrediction? prediction, {
  int? coins,
}) {
  final total = quiz.questions.length;
  final answered = prediction?.answers.length ?? 0;
  final potentialXp = quiz.maxReward;
  final settled = prediction?.status == PredictionStatus.settled;
  final locked = prediction?.status == PredictionStatus.locked;

  // Paid-contest context (Scoreline Quiz). `paid` once a prediction exists.
  final isContest = quiz.isContest;
  final entered = prediction != null;
  final affordable = coins == null || coins >= quiz.entryFee;
  _ContestMeta? contestFor({
    bool settled = false,
    int rank = 0,
    int prizeOz = 0,
  }) => isContest
      ? _ContestMeta(
          fee: quiz.entryFee,
          paid: entered,
          affordable: affordable,
          rank: rank,
          prizeOz: prizeOz,
          settled: settled,
        )
      : null;

  // Finished + settled → verdict card (calm; the moment already happened).
  if (match.status == MatchStatus.finished && settled) {
    final correct = prediction!.correctCount ?? 0;
    final won = correct > 0;
    final earned = prediction.rewardEarned;
    final prizeOz = prediction.contestPrizeOz;
    final wonCoins = prizeOz > 0;
    return _QuizHubVisual(
      accent: (won || wonCoins) ? Cyber.gold : Cyber.muted,
      tag: wonCoins ? 'PRIZE WON' : 'SETTLED',
      progress: total == 0 ? 0 : correct / total,
      progressAccent: won ? Cyber.success : Cyber.muted,
      ctaIcon: (won || wonCoins) ? Icons.military_tech : Icons.done_all,
      ctaText: '$correct / $total CORRECT',
      rewardText: earned > 0 ? '+$earned XP' : 'NO XP',
      rewardColor: earned > 0 ? Cyber.success : Cyber.muted,
      showChevron: false,
      contest: contestFor(
        settled: true,
        rank: prediction.contestRank ?? 0,
        prizeOz: prizeOz,
      ),
      outcomes: questionOutcomes(quiz, prediction),
    );
  }

  // Finished + rewards waiting → the ONE glowing focal moment on the screen.
  // Gated on actual engagement (prediction != null), not just a settleable
  // quiz — the quiz is looked up by matchId regardless of whether the user
  // ever played it, so `quiz.settleable` alone isn't a sufficient signal.
  if (match.status == MatchStatus.finished && prediction != null) {
    return _QuizHubVisual(
      accent: Cyber.gold,
      tag: 'REWARD READY',
      progress: 1,
      progressAccent: Cyber.gold,
      ctaIcon: Icons.redeem,
      ctaText: isContest
          ? 'TAP TO REVEAL RESULT · PRIZE'
          : 'TAP TO REVEAL RESULTS',
      rewardText: 'REVEAL',
      rewardColor: Cyber.gold,
      glow: true,
      pulse: true,
      contest: contestFor(),
    );
  }

  // Finished, no entry → closed/expired.
  if (match.status == MatchStatus.finished) {
    return _QuizHubVisual(
      accent: quiz.settleable ? Cyber.cyan : Cyber.amber,
      tag: quiz.settleable ? 'FINAL RESULTS' : 'RESULT VERIFYING',
      progress: 0,
      progressAccent: quiz.settleable ? Cyber.cyan : Cyber.amber,
      ctaIcon: Icons.query_stats,
      ctaText: quiz.settleable ? 'VIEW COMMUNITY RESULTS' : 'VIEW CROWD SIGNAL',
      rewardText: 'VIEW',
      rewardColor: quiz.settleable ? Cyber.cyan : Cyber.amber,
    );
  }

  // Live → all saved entries are frozen while the match runs.
  if (match.status == MatchStatus.live) {
    return _QuizHubVisual(
      accent: Cyber.danger,
      tag: 'LIVE',
      progress: total == 0 ? 0 : answered / total,
      progressAccent: Cyber.danger,
      ctaIcon: Icons.lock_outline,
      ctaText: 'LOCKED PICKS · MATCH IN PROGRESS',
      rewardText: prediction != null ? 'IN PLAY' : 'CLOSED',
      rewardColor: Cyber.danger,
      showChevron: false,
      blocked: prediction == null,
      blockedMessage: prediction == null
          ? 'Kickoff has passed. New predictions are closed.'
          : null,
      contest: contestFor(),
    );
  }

  // Score providers can briefly leave a just-started fixture marked upcoming.
  // The local kickoff clock closes only fresh entry; existing drafts still
  // open so the deadline-lock path can seal their last saved answers.
  if (!match.kickoff.isAfter(DateTime.now()) && prediction == null) {
    return _QuizHubVisual(
      accent: Cyber.muted,
      tag: 'CLOSED',
      progress: 0,
      progressAccent: Cyber.muted,
      ctaIcon: Icons.lock_clock_outlined,
      ctaText: 'KICKOFF PASSED · NO ENTRY',
      rewardText: 'MISSED',
      rewardColor: Cyber.muted,
      showChevron: false,
      blocked: true,
      blockedMessage: 'Kickoff has passed. New predictions are closed.',
      contest: contestFor(),
    );
  }

  // Manually locked before kickoff → crowd signal is already unlocked.
  if (locked) {
    return _QuizHubVisual(
      accent: Cyber.success,
      tag: 'LOCKED IN',
      progress: total == 0 ? 0 : answered / total,
      progressAccent: Cyber.success,
      ctaIcon: Icons.how_to_vote_outlined,
      ctaText: 'VIEW CROWD VOTES',
      rewardText: '+$potentialXp XP',
      rewardColor: Cyber.gold,
      contest: contestFor(),
    );
  }

  // Upcoming + submitted → editable, auto-saved draft.
  if (prediction != null) {
    final complete = answered >= total;
    return _QuizHubVisual(
      accent: Cyber.cyan,
      tag: complete ? 'DRAFT ACTIVE' : 'IN PROGRESS',
      progress: total == 0 ? 0 : answered / total,
      progressAccent: Cyber.cyan,
      ctaIcon: Icons.edit,
      ctaText: complete
          ? 'REVIEW & LOCK'
          : 'RESUME · $answered/$total ANSWERED',
      rewardText: '+$potentialXp XP',
      rewardColor: Cyber.gold,
      contest: contestFor(),
    );
  }

  // Upcoming, contest entry unaffordable → barred until they top up.
  if (isContest && !affordable) {
    return _QuizHubVisual(
      accent: Cyber.muted,
      tag: 'ENTRY LOCKED',
      progress: 0,
      progressAccent: Cyber.muted,
      ctaIcon: Icons.lock_outline,
      ctaText: 'NEED ${quiz.entryFee} OZ TO ENTER',
      rewardText: '+$potentialXp XP',
      rewardColor: Cyber.muted,
      showChevron: false,
      blocked: true,
      blockedMessage: 'Need ${quiz.entryFee} Oz to enter this contest.',
      contest: contestFor(),
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
    contest: contestFor(),
  );
}
```

---

## 4. The card — `_QuizSetHubCard`

### 4.1 Behaviour

- **Coins are read reactively, and only for contests.**
  `context.select<GameBloc?, int?>((b) => b?.state.coins)` rebuilds the card the
  moment the wallet changes, so ENTRY LOCKED flips to OBJECTIVE without a
  refresh. The nullable read means a tree without a `GameBloc` (the widget tests)
  treats entry as affordable.
- **The pulse controller idles unless it's needed.** A 1,400 ms
  `AnimationController` is created once; `build` starts it with
  `repeat(reverse: true)` when `v.pulse` is true and stops it (resetting to 0)
  when it isn't. Only REWARD READY ever animates.
- **Glow maths.** While pulsing, `t = easeInOut(_pulse.value)` drives
  `Cyber.glow(accent, alpha: 0.18 + 0.22·t, blur: 18 + 8·t, spread: -3)` — a
  breath between 18%/18 px and 40%/26 px. The chamfer border also brightens from
  40% to 60% alpha in that state.
- **Blocked taps still answer.** A blocked card plays the UI tap sound and shows
  a floating `SnackBar` with `blockedMessage`, so it never feels dead.
- **Accessibility.** The whole card is one `Semantics(button: true)` labelled
  `'Open <quiz title>'`.

### 4.2 Layout

| Element | Value |
| --- | --- |
| silhouette | `HudChamferClipper(bigCut: 12, smallCut: 3)` |
| fill | `LinearGradient` top-left → bottom-right: home colour @16% and away colour @16%, each `alphaBlend`ed over `_hubCardBase` (`#06152B`) — the card reads as *this fixture* |
| padding / min height | `fromLTRB(12, 12, 12, 13)` / 84 |
| tag | `Cyber.label(8.5, accent, letterSpacing 1.6)` |
| title | `Cyber.display(14.5, white, letterSpacing 0.2)`, height 1.2, max 2 lines |
| subtitle | `Cyber.body(11.5, muted)`, 1 line, only when non-null |
| meter | `CyberProgressBar` height 6, black @35% track, accent @22% track border |
| CTA line | `Cyber.label(9, accent, letterSpacing 1)`, tabular; gets a 10 px accent text-shadow while pulsing |

The team colours come from `paletteForTeam(...).secondaryTextColor` — see App. B
for a stand-in.

**Full source — the card and its state:**

```dart
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
    // Reactive coin balance so the entry gate flips the moment the wallet does.
    // Nullable read: contest gating only matters where a GameBloc exists (the
    // real app); tests without one treat entry as affordable.
    final coins = widget.quiz.isContest
        ? context.select<GameBloc?, int?>((b) => b?.state.coins)
        : null;
    final v = _resolveQuizHubVisual(
      widget.match,
      widget.quiz,
      widget.prediction,
      coins: coins,
    );
    final homeColor = paletteForTeam(
      widget.match.home,
      sport: widget.match.sport,
      competition: widget.match.leagueId,
    ).secondaryTextColor;
    final awayColor = paletteForTeam(
      widget.match.away,
      sport: widget.match.sport,
      competition: widget.match.leagueId,
    ).secondaryTextColor;

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
        onTap: v.blocked
            ? () {
                playSound(SoundEffect.uiTap);
                final messenger = ScaffoldMessenger.maybeOf(context);
                messenger?.showSnackBar(
                  SnackBar(
                    content: Text(
                      v.blockedMessage ??
                          'This quiz is not available right now.',
                      style: Cyber.body(13),
                    ),
                    backgroundColor: Cyber.panel,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            : widget.onTap,
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
                        homeColor.withValues(alpha: 0.16),
                        _hubCardBase,
                      ),
                      Color.alphaBlend(
                        awayColor.withValues(alpha: 0.16),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                            if (v.contest != null) ...[
                              const SizedBox(height: 9),
                              _ContestStrip(meta: v.contest!),
                            ],
                            const SizedBox(height: 11),
                            CyberProgressBar(
                              value: v.progress.clamp(0.0, 1.0),
                              accent: v.progressAccent,
                              height: 6,
                              trackColor: Colors.black.withValues(alpha: 0.35),
                              trackBorderColor: v.accent.withValues(
                                alpha: 0.22,
                              ),
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
                                    style:
                                        Cyber.label(
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
```

The base colour, a top-level constant further down the file:

```dart
const _hubCardBase = Color(0xff06152b);
```

---

## 5. Silhouette and elevation

Three pieces make the card's shape:

1. **`HudChamferClipper`** (shared, `cyber_widgets.dart`) — the app's "HUD
   hardware" silhouette: a big chamfer top-left and bottom-right, small accent
   cuts top-right and bottom-left. The card uses 12/3, the index plate 8/2, the
   chevron chip 6/2 — the same shape at three scales.
2. **`_QuizChamferPanelPainter`** — strokes that exact path at 1.2 px. A
   `BoxDecoration.border` can't do this: it would be clipped along with the child
   and could never draw the diagonal segments.
3. **`_QuizHubHardShadowPainter`** — fills the same 12/3 path **shifted 5 px
   down**, at the state accent @30%, behind the card. No blur. Only the bottom
   sliver shows, and it reads as a solid thick edge — the embossed elevation the
   home fixture cards use.

**Full source:**

```dart
/// Angular HUD silhouette shared by the primary CTA ([HudCtaButton]) and player
/// cards: a strong chamfer on the top-left and bottom-right corners with smaller
/// accent cuts on the top-right and bottom-left. Keeping one silhouette across
/// buttons and cards makes them read as the same "HUD hardware" family.
class HudChamferClipper extends CustomClipper<Path> {
  const HudChamferClipper({required this.bigCut, required this.smallCut});

  final double bigCut;
  final double smallCut;

  Path buildPath(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(bigCut, 0) // after the top-left chamfer
      ..lineTo(w - smallCut, 0) // top edge
      ..lineTo(w, smallCut) // top-right accent
      ..lineTo(w, h - bigCut) // right edge
      ..lineTo(w - bigCut, h) // bottom-right chamfer
      ..lineTo(smallCut, h) // bottom edge
      ..lineTo(0, h - smallCut) // bottom-left accent
      ..lineTo(0, bigCut) // left edge
      ..close();
  }

  @override
  Path getClip(Size size) => buildPath(size);

  @override
  bool shouldReclip(covariant HudChamferClipper old) =>
      old.bigCut != bigCut || old.smallCut != smallCut;
}
```

```dart
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

/// Hard (un-blurred) offset copy of the hub-card silhouette, drawn behind the
/// card and shifted straight down so its bottom peeks out as a solid thick
/// edge — the "embossed" elevation used by the home fixture cards.
class _QuizHubHardShadowPainter extends CustomPainter {
  const _QuizHubHardShadowPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final path = const HudChamferClipper(
      bigCut: 12,
      smallCut: 3,
    ).buildPath(size).shift(const Offset(0, 5));
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _QuizHubHardShadowPainter old) =>
      old.color != color;
}
```

---

## 6. Leaves

| Widget | What it is |
| --- | --- |
| `_IndexPlate` | 38×38 chamfered (8/2) plate, accent @16% fill, zero-padded index in `Cyber.display(15)` tabular |
| `_RewardPill` | the top-right stake: `+120 XP`, `REVEAL`, `VIEW`, `MISSED`… Tinted fill @12%, border @50% |
| `_HubDivider` | 1 px line fading transparent → accent @35% → transparent; never glows |
| `_ChevronChip` | 26×26 chamfered (6/2) "go" affordance with `Icons.arrow_forward`; shown only when `showChevron` |
| `_HubOutcomeDots` / `_HubOutcomeDot` | settled state only: one 13 px square per question — ✓ success, ✕ red, ⋯ muted for pending |

In the trailing slot, **outcome dots win over the chevron**: a settled card shows
its per-question verdict instead of an arrow.

**Full source:**

```dart
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
```

```dart
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
```

---

## 7. The contest ribbon — `_ContestStrip`

Rendered only when `v.contest != null`, i.e. for paid quizzes
(`quiz.entryFee > 0`). Two phases:

| Phase | Left chip | Right chip |
| --- | --- | --- |
| entry, already paid | ✓ `ENTRY PAID` (lime) | 🏆 `2000 · 1000 · 500` (gold) |
| entry, affordable | coin `-<fee> OZ ENTRY` (cyan) | 🏆 prize pool |
| entry, can't afford | 🔒 `NEED <fee> OZ` (muted) | 🏆 prize pool |
| settled | 📊 `FINISHED #<rank>` (gold if won, else muted) | coin `+<prize>` filled gold, or `NO PRIZE` |

The prize pool is `kScorelineContestPrizes` (`[2000, 1000, 500]`, from
`prediction.dart`) joined with `·`. The coin win is a **chip, not a glow** — the
reveal cinematic owns the moment and the hub stays calm.

**Full source:**

```dart
/// Paid-contest ribbon on the Scoreline Quiz hub card: entry state on the left,
/// prize pool on the right (pre-settle) — or finish + coins won (post-settle).
/// Flat tinted chips only; the gold coin win is a chip, not a glow (glow rule:
/// the reveal cinematic owns the "moment", the hub stays calm).
class _ContestStrip extends StatelessWidget {
  const _ContestStrip({required this.meta});

  final _ContestMeta meta;

  @override
  Widget build(BuildContext context) {
    if (meta.settled) {
      final won = meta.prizeOz > 0;
      return Row(
        children: [
          _ContestChip(
            icon: Icons.leaderboard,
            label: meta.rank > 0 ? 'FINISHED #${meta.rank}' : 'FINISHED',
            color: won ? Cyber.gold : Cyber.muted,
          ),
          const Spacer(),
          if (won)
            _ContestChip(
              coin: true,
              label: '+${meta.prizeOz}',
              color: Cyber.gold,
              filled: true,
            )
          else
            _ContestChip(label: 'NO PRIZE', color: Cyber.muted),
        ],
      );
    }

    // Entry phase — left chip reflects paid / affordable / barred.
    final Widget entry;
    if (meta.paid) {
      entry = _ContestChip(
        icon: Icons.check_circle,
        label: 'ENTRY PAID',
        color: Cyber.lime,
      );
    } else if (meta.affordable) {
      entry = _ContestChip(
        coin: true,
        label: '-${meta.fee} OZ ENTRY',
        color: Cyber.cyan,
      );
    } else {
      entry = _ContestChip(
        icon: Icons.lock_outline,
        label: 'NEED ${meta.fee} OZ',
        color: Cyber.muted,
      );
    }

    return Row(
      children: [
        entry,
        const Spacer(),
        _ContestChip(
          icon: Icons.emoji_events,
          label: kScorelineContestPrizes.join(' · '),
          color: Cyber.gold,
        ),
      ],
    );
  }
}

/// One compact chip in the [_ContestStrip]. Either an [icon] or a [coin] glyph
/// leads the label. `filled` tints the fill up for the coins-won highlight.
class _ContestChip extends StatelessWidget {
  const _ContestChip({
    this.icon,
    this.coin = false,
    required this.label,
    required this.color,
    this.filled = false,
  });

  final IconData? icon;
  final bool coin;
  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: filled ? 0.18 : 0.10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (coin)
            const CoinIcon(size: 12)
          else if (icon != null)
            Icon(icon, size: 12, color: color),
          if (coin || icon != null) const SizedBox(width: 4),
          Text(
            label,
            style: Cyber.label(
              8.5,
              color: color,
              letterSpacing: 0.8,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
```

`CoinIcon`, from `lib/screens/shop/widgets/shop_card.dart`:

```dart
/// The Oz-coin glyph. Lives here (next to the shop's price widgets) and is
/// re-exported from `shop_screen.dart` so existing importers keep working.
class CoinIcon extends StatelessWidget {
  const CoinIcon({this.size = 24, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        'assets/icons/oz_coins.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}
```

---

## 8. The meter — `CyberProgressBar`

The app's single meter, shared with every XP, rank and power bar: a gradient
that reaches full colour by ~70% of its width, a bright leading edge, a tight
glow and a glossy sheen. On this card it shows completion (`answered/total`) or,
once settled, accuracy (`correct/total`). It is self-contained — it needs only
`Cyber.bg` and `Cyber.cyan`.

**Full source:**

```dart
/// A polished progress / meter bar shared by every XP, rank and power meter so
/// the "gradient flow" reads identically across the app. The fill ramps from a
/// soft translucent accent to full colour over ~70% of its width and finishes
/// on a bright leading edge, paired with a tight, subtle glow and a glossy top
/// sheen for a clean finish.
class CyberProgressBar extends StatelessWidget {
  const CyberProgressBar({
    required this.value,
    this.accent = Cyber.cyan,
    this.height = 7,
    this.radius = 2,
    this.animate = true,
    this.trackColor,
    this.trackBorderColor,
    super.key,
  });

  /// Fill fraction, 0..1.
  final double value;
  final Color accent;
  final double height;
  final double radius;

  /// When true the fill grows from 0 to [value] on first build. Leave false
  /// when the caller already animates [value] itself.
  final bool animate;
  final Color? trackColor;
  final Color? trackBorderColor;

  Widget _bar(double v) {
    final r = BorderRadius.circular(radius);
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: trackColor ?? Cyber.bg.withValues(alpha: 0.7),
                borderRadius: r,
                border: trackBorderColor == null
                    ? null
                    : Border.all(color: trackBorderColor!),
              ),
            ),
          ),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: v,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: r,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.3),
                    blurRadius: 6,
                    spreadRadius: -1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: r,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // The flow: soft fade-in, full colour by ~70%, bright tip.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            accent.withValues(alpha: 0.45),
                            accent.withValues(alpha: 0.95),
                            accent,
                          ],
                          stops: const [0.0, 0.7, 1.0],
                        ),
                      ),
                    ),
                    // Glossy top sheen.
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: height * 0.5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.22),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final target = value.clamp(0.0, 1.0).toDouble();
    if (!animate) return _bar(target);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => _bar(v),
    );
  }
}
```

---

## 9. The host — building the list and opening a set

The PREDICT tab builds one card per quiz, 26 px apart, reading each card's
prediction straight from the cubit:

```dart
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
  )
```

`_openQuizSet` is the second gate. Even if a card reaches `onTap`, an unentered
quiz is refused once the deadline has passed — **unless** the match is finished,
which is the community-results path (branch 3). Embedded hosts push a dedicated
`MatchPredictionScreen` for that quiz id.

```dart
  void _openQuizSet(PredictionQuiz quiz) {
    final existing = _predictionCubit.state.predictionFor(_match.id, quiz.id);
    final communityResults =
        existing == null && _match.status == MatchStatus.finished;
    if (existing == null && !_beforeDeadline && !communityResults) {
      _notify('Kickoff has passed. New predictions are closed.');
      return;
    }
    playSound(SoundEffect.uiTap);
    if (widget.embedded) {
      final openPicks = widget.onOpenPicks;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MatchPredictionScreen(
            match: _match,
            quizId: quiz.id,
            onOpenPicks: openPicks == null
                ? null
                : () {
                    Navigator.of(context).pop();
                    openPicks();
                  },
          ),
        ),
      );
      return;
    }
    unawaited(_loadQuiz(quiz));
  }
```

---

## 10. Design rules to keep

- **One glow, one state.** Only REWARD READY glows, and it breathes. Every other
  state is flat fill + chamfer border + hard edge. This is the glow rule: glow
  means "this is the thing to do now".
- **Accent is state, colour is fixture.** The accent (border, tag, meter, CTA,
  plate) encodes the state — cyan actionable, gold reward, success locked,
  danger live, amber verifying, muted closed. The background wash encodes the
  two teams. They never compete.
- **Every state has a next action.** Even a blocked card answers a tap with a
  reason. Even a missed quiz offers `VIEW COMMUNITY RESULTS`.
- **Same silhouette at three scales.** Card 12/3, plate 8/2, chevron 6/2 — one
  `HudChamferClipper`, so the parts read as one piece of hardware.
- **Numbers are tabular** — index, pill, CTA text, contest chips.

---

## 11. Tests

| Test | What it proves |
| --- | --- |
| [`match_prediction_screen_test.dart:227`](../../test/match_prediction_screen_test.dart#L227) *a finished unentered quiz shows community final results* | branch 3 copy |
| [`:243`](../../test/match_prediction_screen_test.dart#L243) *embedded single quiz shows quiz-set hub card* | branch 9 — `TAP TO PREDICT · 2 QUESTIONS` |
| [`:271`](../../test/match_prediction_screen_test.dart#L271) *finished multi-quiz hub opens the community results route* | branch 3 on two cards + the `_openQuizSet` community path |
| [`match_detail_screen_test.dart:442`](../../test/match_detail_screen_test.dart#L442) *predict tab shows quiz-set hub for regular matches* | the hub renders inside match detail |
| [`:457`](../../test/match_detail_screen_test.dart#L457) *predict tab shows quiz-set hub for a single quiz* | branch 9 — `TAP TO PREDICT · 1 QUESTIONS` |

**Not covered by a widget test:** branches 1, 2 and 4–8 (SETTLED/PRIZE WON,
REWARD READY and its pulse, LIVE, CLOSED, LOCKED IN, DRAFT ACTIVE/IN PROGRESS,
ENTRY LOCKED) and the contest ribbon. Because `_resolveQuizHubVisual` is a pure
function of `(match, quiz, prediction, coins)`, a table-driven unit test over it
is the cheapest way to pin all nine branches — worth adding in a port.

---

## Implementation References

- [`lib/screens/predictions/match_prediction_screen.dart`](../../lib/screens/predictions/match_prediction_screen.dart) — the card, its states, leaves and host
- [`lib/widgets/cyber/cyber_widgets.dart`](../../lib/widgets/cyber/cyber_widgets.dart) — `HudChamferClipper`, `CyberProgressBar`
- [`lib/utils/prediction_helpers.dart`](../../lib/utils/prediction_helpers.dart) — `questionOutcomes`
- [`lib/models/prediction.dart`](../../lib/models/prediction.dart) — quiz and prediction models
- [`lib/screens/shop/widgets/shop_card.dart`](../../lib/screens/shop/widgets/shop_card.dart) — `CoinIcon`
- [`lib/services/quiz_archetypes.dart`](../../lib/services/quiz_archetypes.dart) — where a generated quiz's title and subtitle come from
- [`lib/config/theme.dart`](../../lib/config/theme.dart)

---

## Appendix A — models and helpers, verbatim

### A.1 `prediction.dart`

```dart
/// Where a user's prediction sits in its lifecycle.
/// open    → submitted draft, auto-saved and still editable.
/// locked  → manually sealed or auto-locked at kickoff; answers are immutable.
/// settled → result known, [correctCount]/[rewardEarned] populated.
enum PredictionStatus { open, locked, settled }

const kDefaultPredictionQuizId = 'main';

/// Oz-coin prize pool for a Scoreline Quiz contest, indexed by finish rank
/// (rank 1 → 2000, rank 2 → 1000, rank 3 → 500; everyone else wins nothing).
const List<int> kScorelineContestPrizes = [2000, 1000, 500];
```

```dart
/// A single quiz question attached to a fixture.
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.text,
    this.options = const [],
    this.reward = 0,
    this.type = QuizQuestionType.multipleChoice,
    this.backgroundAsset,
    this.settledOptionIndex,
    this.settledHomeScore,
    this.settledAwayScore,
    this.forcedVoid = false,
    this.archetypeKey,
    this.settlementRule = const {},
  });

  final String id;
  final String text;
  final List<String> options;
  final QuizQuestionType type;

  /// Optional full-bleed panel backdrop (shown at 50% opacity in the quiz UI).
  final String? backgroundAsset;

  /// XP credited if this question is answered correctly.
  final int reward;

  /// The correct option once the match is settled (multiple-choice only).
  final int? settledOptionIndex;

  /// The correct full-time score once settled (exact-score only).
  final int? settledHomeScore;
  final int? settledAwayScore;

  /// Set by the auto-settlement engine when a finished match's real data can't
  /// support this question (e.g. a cricket scorecard with no six-count
  /// breakdown). A voided question counts as settled — so the quiz as a whole
  /// can still be revealed — but is excluded from scoring: no XP either way.
  /// This is the per-question escape hatch that guarantees a fixture is never
  /// left permanently unsettleable just because one archetype didn't resolve.
  final bool forcedVoid;

  /// Stable semantic identifier used by live intelligence and settlement.
  ///
  /// Legacy authored quizzes can omit this; [QuizArchetypes] maps their
  /// existing ids without changing persisted answer keys.
  final String? archetypeKey;

  /// Immutable primitive parameters captured with a generated quiz snapshot,
  /// such as an over/under threshold.
  final Map<String, Object?> settlementRule;

  bool get isScorePrediction => type == QuizQuestionType.exactScore;

  int? get settledScoreEncoded {
    if (settledHomeScore == null || settledAwayScore == null) return null;
    return ScoreAnswer.encode(settledHomeScore!, settledAwayScore!);
  }

  bool get isSettled =>
      forcedVoid ||
      (isScorePrediction
          ? settledScoreEncoded != null
          : settledOptionIndex != null);

  QuizQuestion copyWith({
    int? settledOptionIndex,
    int? settledHomeScore,
    int? settledAwayScore,
    bool? forcedVoid,
  }) => QuizQuestion(
    id: id,
    text: text,
    options: options,
    reward: reward,
    type: type,
    backgroundAsset: backgroundAsset,
    settledOptionIndex: settledOptionIndex ?? this.settledOptionIndex,
    settledHomeScore: settledHomeScore ?? this.settledHomeScore,
    settledAwayScore: settledAwayScore ?? this.settledAwayScore,
    forcedVoid: forcedVoid ?? this.forcedVoid,
    archetypeKey: archetypeKey,
    settlementRule: settlementRule,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'text': text,
    'options': options,
    'reward': reward,
    'type': type.name,
    'backgroundAsset': backgroundAsset,
    'settledOptionIndex': settledOptionIndex,
    'settledHomeScore': settledHomeScore,
    'settledAwayScore': settledAwayScore,
    'forcedVoid': forcedVoid,
    'archetypeKey': archetypeKey,
    'settlementRule': settlementRule,
  };

  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
    id: json['id'] as String,
    text: json['text'] as String,
    options: (json['options'] as List? ?? const [])
        .map((option) => option.toString())
        .toList(growable: false),
    reward: json['reward'] as int? ?? 0,
    type: QuizQuestionType.values.byName(
      json['type'] as String? ?? QuizQuestionType.multipleChoice.name,
    ),
    backgroundAsset: json['backgroundAsset'] as String?,
    settledOptionIndex: json['settledOptionIndex'] as int?,
    settledHomeScore: json['settledHomeScore'] as int?,
    settledAwayScore: json['settledAwayScore'] as int?,
    forcedVoid: json['forcedVoid'] as bool? ?? false,
    archetypeKey: json['archetypeKey'] as String?,
    settlementRule: Map<String, Object?>.from(
      json['settlementRule'] as Map? ?? const {},
    ),
  );
}
```

```dart
/// The full quiz for one fixture.
class PredictionQuiz {
  const PredictionQuiz({
    required this.matchId,
    required this.questions,
    this.id = kDefaultPredictionQuizId,
    this.title = 'Prediction Quiz',
    this.subtitle,
    this.prizeLabel,
    this.entryFee = 0,
    this.schemaVersion = 1,
    this.generated = false,
  });

  final String id;
  final String matchId;
  final String title;
  final String? subtitle;
  final String? prizeLabel;
  final List<QuizQuestion> questions;

  /// Oz-coin cost to enter this quiz as a paid contest. 0 = free/XP-only.
  final int entryFee;
  final int schemaVersion;
  final bool generated;

  int get maxReward => questions.fold(0, (sum, q) => sum + q.reward);
  bool get settleable => questions.every((q) => q.isSettled);

  /// A paid coin contest (top-3 finishers win [kScorelineContestPrizes]).
  bool get isContest => entryFee > 0;

  PredictionQuiz copyWith({List<QuizQuestion>? questions}) => PredictionQuiz(
    id: id,
    matchId: matchId,
    title: title,
    subtitle: subtitle,
    prizeLabel: prizeLabel,
    entryFee: entryFee,
    schemaVersion: schemaVersion,
    generated: generated,
    questions: questions ?? this.questions,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'matchId': matchId,
    'title': title,
    'subtitle': subtitle,
    'prizeLabel': prizeLabel,
    'entryFee': entryFee,
    'schemaVersion': schemaVersion,
    'generated': generated,
    'questions': questions.map((question) => question.toJson()).toList(),
  };

  factory PredictionQuiz.fromJson(Map<String, dynamic> json) => PredictionQuiz(
    id: json['id'] as String? ?? kDefaultPredictionQuizId,
    matchId: json['matchId'] as String,
    title: json['title'] as String? ?? 'Prediction Quiz',
    subtitle: json['subtitle'] as String?,
    prizeLabel: json['prizeLabel'] as String?,
    entryFee: json['entryFee'] as int? ?? 0,
    schemaVersion: json['schemaVersion'] as int? ?? 1,
    generated: json['generated'] as bool? ?? false,
    questions: (json['questions'] as List? ?? const [])
        .map(
          (question) =>
              QuizQuestion.fromJson(Map<String, dynamic>.from(question as Map)),
        )
        .toList(growable: false),
  );
}
```

```dart
/// A user's submitted answers for a fixture. Persisted locally for now.
class UserPrediction {
  const UserPrediction({
    required this.matchId,
    required this.answers,
    required this.submittedAt,
    this.quizId = kDefaultPredictionQuizId,
    this.multipliersByQuestion = const {},
    this.status = PredictionStatus.open,
    this.correctCount,
    this.rewardEarned = 0,
    this.contestRank,
    this.contestPrizeOz = 0,
  });

  /// questionId → selected option index.
  final Map<String, int> answers;
  final Map<String, PredictionMultiplier> multipliersByQuestion;
  final String matchId;
  final String quizId;
  final DateTime submittedAt;
  final PredictionStatus status;
  final int? correctCount;
  final int rewardEarned;

  /// Finish position in the paid-contest field once settled (1-based). Null for
  /// free quizzes or before settlement.
  final int? contestRank;

  /// Oz coins won from the contest prize pool (0 off the podium / free quizzes).
  final int contestPrizeOz;

  String get key => predictionStorageKey(matchId, quizId);

  UserPrediction copyWith({
    Map<String, int>? answers,
    Map<String, PredictionMultiplier>? multipliersByQuestion,
    String? quizId,
    PredictionStatus? status,
    int? correctCount,
    int? rewardEarned,
    int? contestRank,
    int? contestPrizeOz,
  }) => UserPrediction(
    matchId: matchId,
    quizId: quizId ?? this.quizId,
    answers: answers ?? this.answers,
    multipliersByQuestion: multipliersByQuestion ?? this.multipliersByQuestion,
    submittedAt: submittedAt,
    status: status ?? this.status,
    correctCount: correctCount ?? this.correctCount,
    rewardEarned: rewardEarned ?? this.rewardEarned,
    contestRank: contestRank ?? this.contestRank,
    contestPrizeOz: contestPrizeOz ?? this.contestPrizeOz,
  );

  Map<String, dynamic> toJson() => {
    'matchId': matchId,
    'quizId': quizId,
    'answers': answers,
    'multipliersByQuestion': multipliersByQuestion.map(
      (questionId, multiplier) => MapEntry(questionId, multiplier.jsonKey),
    ),
    'submittedAt': submittedAt.millisecondsSinceEpoch,
    'status': status.name,
    'correctCount': correctCount,
    'rewardEarned': rewardEarned,
    'contestRank': contestRank,
    'contestPrizeOz': contestPrizeOz,
  };

  factory UserPrediction.fromJson(Map<String, dynamic> json) => UserPrediction(
    matchId: json['matchId'] as String,
    quizId: json['quizId'] as String? ?? kDefaultPredictionQuizId,
    answers: (json['answers'] as Map).map(
      (key, value) => MapEntry(key as String, value as int),
    ),
    multipliersByQuestion: _predictionMultipliersFromJson(
      json['multipliersByQuestion'],
    ),
    submittedAt: DateTime.fromMillisecondsSinceEpoch(
      json['submittedAt'] as int,
    ),
    status: PredictionStatus.values.byName(json['status'] as String? ?? 'open'),
    correctCount: json['correctCount'] as int?,
    rewardEarned: json['rewardEarned'] as int? ?? 0,
    contestRank: json['contestRank'] as int?,
    contestPrizeOz: json['contestPrizeOz'] as int? ?? 0,
  );
}
```

### A.2 `prediction_helpers.dart` — per-question outcomes

A question counts only once the prediction is settled **and** the question has
a settled answer; anything else is `pending`. Score questions compare the
encoded scoreline, option questions the option index.

```dart
/// Per-question result glyph on the history screen.
enum QuestionOutcome { correct, wrong, pending }
```

```dart
QuestionOutcome questionOutcome(QuizQuestion question, UserPrediction prediction) {
  if (prediction.status == PredictionStatus.settled && question.isSettled) {
    final picked = prediction.answers[question.id];
    if (picked == null) return QuestionOutcome.pending;
    final correct = question.isScorePrediction
        ? question.settledScoreEncoded
        : question.settledOptionIndex;
    if (correct == null) return QuestionOutcome.pending;
    return picked == correct ? QuestionOutcome.correct : QuestionOutcome.wrong;
  }
  return QuestionOutcome.pending;
}

List<QuestionOutcome> questionOutcomes(
  PredictionQuiz quiz,
  UserPrediction prediction,
) => [for (final q in quiz.questions) questionOutcome(q, prediction)];
```

---

## Appendix B — tokens and stand-ins

### B.1 Design tokens — flattened, drop-in

```dart
import 'package:flutter/material.dart';

/// Flattened copy of the tokens the hub card uses. In the source project
/// every value is an alias onto `AppTheme` in lib/config/theme.dart.
class Cyber {
  // Surfaces
  static const Color bg = Color.fromRGBO(13, 17, 26, 1);
  static const Color card = Color.fromRGBO(15, 23, 43, 1);
  static const Color panel = Color.fromRGBO(29, 41, 61, 1);

  // State accents
  static const Color cyan = Color.fromRGBO(92, 223, 255, 1);
  static const Color gold = Color.fromRGBO(253, 199, 0, 1);
  static const Color success = Color.fromRGBO(5, 223, 114, 1);
  static const Color danger = Color.fromRGBO(255, 77, 77, 1);
  static const Color red = Color.fromRGBO(227, 31, 38, 1);
  static const Color amber = Color.fromRGBO(255, 137, 4, 1);
  static const Color lime = Color.fromRGBO(81, 255, 148, 1);

  // Lines and text
  static const Color border = Color.fromRGBO(49, 65, 88, 1);
  static const Color line = Color.fromRGBO(69, 85, 108, 1);
  static const Color muted = Color.fromRGBO(144, 161, 185, 1);

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
```

### B.2 Stand-ins

**Team colours** (background wash). The real `paletteForTeam` is a 4,699-line
generated lookup; the card reads only `.secondaryTextColor`:

```dart
class TeamPalette {
  const TeamPalette(this.secondaryTextColor);
  final Color secondaryTextColor;
}

TeamPalette paletteForTeam(SportTeam team, {Sport? sport, String? competition}) =>
    TeamPalette(team.color);
```

**Coin balance** (contests only). Replace the `GameBloc` read with your wallet —
keep it reactive so ENTRY LOCKED flips when the balance changes:

```dart
final coins = widget.quiz.isContest
    ? context.select<WalletCubit?, int?>((w) => w?.state.coins) // your source
    : null;
```

If you have no paid contests, delete it and pass `coins: null`; branch 8 and the
contest ribbon then never appear.

**UI sound:**

```dart
enum SoundEffect { uiTap }
void playSound(SoundEffect effect) {}
```

**Coin glyph.** `CoinIcon` loads `assets/icons/oz_coins.svg` through
`flutter_svg`. Without the asset, swap in
`Icon(Icons.monetization_on, size: size, color: Cyber.gold)`.

### B.3 Checklist

- [ ] Tokens (B.1) and fonts compile
- [ ] Models + `questionOutcomes` (App. A), or your own with the same field names
- [ ] `HudChamferClipper` + both painters (§5)
- [ ] Leaves (§6), contest ribbon (§7) if you have paid quizzes, `CyberProgressBar` (§8)
- [ ] `_QuizHubVisual` + `_resolveQuizHubVisual` (§3) — keep the branch order
- [ ] `_QuizSetHubCard` (§4) with your coin source and palette
- [ ] Host loop + an open action with its own deadline gate (§9)
- [ ] A table-driven test over `_resolveQuizHubVisual` (§11)
