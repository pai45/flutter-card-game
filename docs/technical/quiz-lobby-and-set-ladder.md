# Quiz Lobby and Set Ladder — implementation and porting reference

> **Status:** BUILT
> **Last verified:** 2026-09-14
> **Scope:** [`lib/screens/quiz/quiz_lobby_screen.dart`](../../lib/screens/quiz/quiz_lobby_screen.dart)
> — the two screens between the GAMES tab and a quiz run: **`QuizLobbyScreen`**
> (the Knowledge Arena — pick a category) and **`QuizSetScreen`** (the Knowledge
> Ladder — pick a set, confirm the entry fee, play) — plus the progression model,
> question bank and coin transaction underneath them.

**Written to be portable.** All 16 declarations in the file are reproduced
*exactly as implemented*, in the section that explains them. The appendices carry
the models, cubit and question bank verbatim, every shared widget verbatim, and a
set of stand-ins for the five subsystems that cannot travel — built so the verbatim
screen code compiles on top of them **without a single edit**.

**Out of scope:** `QuizPlayScreen` (the 10-question run, answer verdicts, XP payout
and result reveal) is the destination these screens push. It is given here by
contract only (App. D.7), and documented in full in
[`quiz-play-screen.md`](quiz-play-screen.md) — whose App. C stand-ins supersede App. D
below when you port both screens. The product rules live in
[`docs/product/games/football-quiz.md`](../product/games/football-quiz.md) and its
four sport siblings.

---

## 0. Port map

| # | Layer | Source | Here |
| --- | --- | --- | --- |
| 1 | Rules | `QuizSetVisualState`, `kQuizBandNames` | §2, §3 — verbatim |
| 2 | Screen 1 | `QuizLobbyScreen` | §3 — verbatim |
| 3 | Hero | `_KnowledgeArenaHero`, `_ArenaProgressTrack`, `_sportIcon` | §4 — verbatim |
| 4 | Category tile | `_ModeTile` | §5 — verbatim |
| 5 | Screen 2 | `QuizSetScreen` + state | §6 — verbatim |
| 6 | Headline card | `_NextChallengeCard` | §7 — verbatim |
| 7 | Difficulty tabs | `_ChapterSelector`, `_ChapterTab` | §8 — verbatim |
| 8 | Set tile | `_SetTile` | §9 — verbatim |
| 9 | Chrome | `_BackButton`, `_CoinBalance`, `_LadderRule` | §10 — verbatim |
| 10 | Entry sheet | `_EntryBriefing`, `_BriefingStat` | §11 — verbatim |
| 11 | Progression | `QuizMode`, `QuizSetProgress`, `QuizModeProgress`, `QuizProgress`, `QuizState`, `QuizCubit` | App. A — verbatim |
| 12 | Question bank | `QuizBank` + the asset format | App. B — verbatim |
| 13 | Shared widgets | 10 from `cyber_widgets.dart`, `HudCtaButton` | App. C — verbatim |
| 14 | Stand-ins | `Cyber`, sound, storage, wallet, scaffold, leaderboard, play screen | App. D |

**Toolchain**

- **Dart 3.8+.** The file itself needs Dart 3 (switch expressions with `||`
  patterns in `_SetTile`, records in `QuizProgress.record`, `abstract final class`
  on `QuizBank`). The App. D scaffold uses a **null-aware collection element**
  (`?rightSlot`), which is 3.8 — replace it with `if (rightSlot != null) rightSlot!`
  on older SDKs.
- **Flutter 3.27+** — `Color.withValues(alpha:)` throughout.
- **`flutter_bloc`** — `BlocBuilder`, `context.read`, `context.select`. The only
  third-party package the screens need.
- **Fonts** — Orbitron (display/labels) and Onest (body).
- **`dart:async`** (the entrance animations use `Timer`), **`dart:convert`** (the
  bank and storage decode JSON).

---

## 1. What it is

A two-screen **progression ladder**. Four categories, each a ladder of 50 sets of
10 questions, split into five difficulty chapters. Every set costs 25 coins to
enter, pays XP per correct answer, and grades your best run with up to three
stars. Finishing a set — at any score — unlocks the next one.

```
GAMES tab → QuizTabContent → QuizLobbyScreen(sport)          "KNOWLEDGE ARENA"
  ├─ GameScaffold  / FOOTBALL QUIZ   [back]  [leaderboard]
  └─ BlocBuilder<QuizCubit>  (spinner while state.loading)
       ├─ CyberSlideUpFadeIn → _KnowledgeArenaHero
       │     telemetry strip · sport plate · KNOWLEDGE ARENA · 37 / 200 SETS CLEARED
       │     TOTAL MASTERY 18%  [▓▓▓░|░░░|░░░|░░░]  · MISSION BRIEF · 10 Q / RUN
       ├─ CHOOSE A CATEGORY
       └─ 2×2 grid, each CyberDealtCard(index) → _ModeTile
             EASY / MEDIUM / HARD / GLOBAL — +N XP, NEXT SET n, meter, ★ stars, n/50
                 │ tap
                 ▼
QuizSetScreen(sport, mode)                                      "KNOWLEDGE LADDER"
  ├─ GameScaffold  / EASY SETS   [back]  [🪙 coins]
  └─ (spinner while the question bank loads)
       ├─ _NextChallengeCard      NEXT CHALLENGE · EASY · SET 12   (or 2 other states)
       ├─ SET CHAPTERS   12/50 CLEARED  ★ 31/150
       ├─ _ChapterSelector   FOUNDATION | PROSPECT | CONTENDER | SPECIALIST | LEGEND
       ├─ 10-tile grid (5 cols, 4 under 350px) → _SetTile × 10
       │     PERFECT ★★★ · REPLAY ★★ · PLAY · FINISH 11 · SOON
       └─ _LadderRule
                 │ tap an open tile
                 ▼
       showModalBottomSheet → _EntryBriefing
             ENTRY BRIEFING · QUESTIONS 10 · 3-STAR 10/10 · +1 XP · ENTRY 25
             BALANCE · 50 COINS   [ ≫ | START SET ]
                 │ confirm → re-check coins → CoinsSpent(25) → 120ms
                 ▼
       QuizPlayScreen(sport, mode, setNumber)  → records result → pops
                 │
                 ▼
       back on the ladder, chapter view jumps to the new next challenge
```

---

## 2. The rules the UI projects

Both screens are thin projections of a small progression model (App. A). Get these
right and the UI follows; everything visual is derived from them.

### 2.1 Sets clear on completion, not on score

There is **no fail state.** `QuizSetProgress.merge` sets `completed: true` for every
full run regardless of `correct`. The score only grades stars:

| Best correct | Stars | Tile |
| --- | --- | --- |
| 10 / 10 | ★★★ | `mastered` — gold, `PERFECT` |
| 7 – 9 | ★★ | `cleared` — green, `REPLAY` |
| 1 – 6 | ★ | `cleared` — green, `REPLAY` |
| 0 | — | `cleared` — green, `REPLAY` |

`kQuizTwoStarScore = 7` is the only threshold; three stars requires a flawless run.
This is a deliberate game-design choice — nobody gets walled — and stars are what
turn a cleared set into a reason to replay. Only a full sweep glows
(`CyberStarRating`), so a wall of tiles stays calm and a perfect one pops.

`merge` keeps the **best** `correct` and increments `attempts`, so a bad replay can
never cost a star.

### 2.2 Unlocks are strictly sequential, per category

```dart
bool isSetUnlocked(int setNumber) {
  if (setNumber < 1 || setNumber > kQuizSetCount) return false;
  if (setNumber == 1) return true;
  return setProgress(setNumber - 1).completed;
}
```

Set *n* opens when set *n−1* is completed. All four categories are open from the
start (`QuizProgress.isUnlocked` returns `true`) — `unlockedBy` survives only as a
legacy field. Progress is per sport, per category, per set.

### 2.3 Chapters are difficulty bands

`kQuizBandNames` — FOUNDATION, PROSPECT, CONTENDER, SPECIALIST, LEGEND. Band *k*
covers sets `10(k−1)+1 … 10k`, so the chapter selector doubles as the difficulty
ladder. In the bank, band *k* is 100 authored questions; flattening bands 1→5
produces the 500-question pool the sets index into. Category sets breadth, band sets
depth: band 5 of EASY is still easier than band 1 of MEDIUM.

### 2.4 Authored vs. theoretical sets

The ladder is always 50 sets, but the question database may not reach all of them.
`QuizBank.authoredSetCount` = `pool.length ~/ 10` — **partial sets don't count**, and
`_parse` stops at the first missing or short band, so a half-written band can never
shift the questions behind an already-published set. Sets past the authored count
render as `SOON` rather than falling back to filler questions.

### 2.5 The five visual states, and why their order matters

```dart
QuizSetVisualState _visualState(QuizModeProgress progress, int setNumber) {
  final set = progress.setProgress(setNumber);
  if (set.mastered) return QuizSetVisualState.mastered;
  if (set.completed) return QuizSetVisualState.cleared;
  if (!_isPlayable(setNumber)) return QuizSetVisualState.upcoming;
  if (!progress.isSetUnlocked(setNumber)) return QuizSetVisualState.locked;
  return QuizSetVisualState.available;
}
```

The `if` chain is ordered, and two orderings are load-bearing:

- **Earned state beats content state.** `mastered`/`cleared` are checked before
  `upcoming`, so a set the player completed stays graded even if a later bank
  release shrinks the authored count. Never hide a reward the player already won.
- **`upcoming` beats `locked`.** An unwritten set reads `SOON`, not `FINISH 11` —
  telling the player to finish set 11 to unlock a set that has no questions would
  be a lie.

### 2.6 The entry fee

`kQuizEntryCost = 25` coins per attempt, charged **only after** the player confirms
the briefing, and only if the balance still covers it at that moment (§6.4). XP is
paid per correct answer by the play screen (`mode.reward`: 1 / 2 / 4 / 5). The
quiz never pays coins.

---

## 3. Screen 1 — `QuizLobbyScreen`

The file opens with the two top-level declarations the whole ladder keys off,
verbatim:

```dart
/// A set is [mastered] at a flawless 10/10, [cleared] once finished at any
/// score, [available] when open but unplayed, [locked] until the previous set
/// is finished, and [upcoming] when the question database doesn't reach it yet.
/// There is no fail state — the score only decides mastery stars.
enum QuizSetVisualState { mastered, cleared, available, locked, upcoming }

/// The five difficulty rungs of every mode. Band `k` owns sets `10(k-1)+1…10k`,
/// so the chapter selector doubles as the difficulty ladder.
const List<String> kQuizBandNames = [
  'FOUNDATION',
  'PROSPECT',
  'CONTENDER',
  'SPECIALIST',
  'LEGEND',
];
```

Then the lobby, verbatim:

```dart
class QuizLobbyScreen extends StatelessWidget {
  const QuizLobbyScreen({required this.sport, required this.onBack, super.key});

  final Sport sport;
  final VoidCallback onBack;

  void _openSets(BuildContext context, QuizMode mode) {
    playSound(SoundEffect.uiTap);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuizSetScreen(sport: sport, mode: mode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: '${sport.name.toUpperCase()} QUIZ',
      subtitle: 'KNOWLEDGE ARENA',
      leading: _BackButton(onTap: onBack),
      rightSlot: GameLeaderboardButton(
        sport: sport,
        mode: GameMode.quiz,
        accent: Cyber.violet,
      ),
      child: BlocBuilder<QuizCubit, QuizState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(
              child: CircularProgressIndicator(color: Cyber.cyan),
            );
          }
          final progress = state.progressForSport(sport);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CyberSlideUpFadeIn(
                        child: _KnowledgeArenaHero(
                          sport: sport,
                          progress: progress,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const SectionLabel(label: 'CHOOSE A CATEGORY'),
                      const SizedBox(height: 10),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: QuizMode.values.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.92,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                        itemBuilder: (context, index) {
                          final mode = QuizMode.values[index];
                          return CyberDealtCard(
                            key: ValueKey('quiz-mode-${mode.name}'),
                            index: mode.index,
                            initialDelay: const Duration(milliseconds: 120),
                            child: _ModeTile(
                              sport: sport,
                              mode: mode,
                              progress: progress.forMode(mode),
                              onTap: () => _openSets(context, mode),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

- **A `StatelessWidget` driven entirely by `QuizCubit`.** It shows a cyan spinner
  while `state.loading` and then derives everything from
  `state.progressForSport(sport)`. `QuizCubit` is provided app-wide and loaded once
  at startup (`app.dart:97`: `QuizCubit(SecureGameStorage())..load()`), so the
  spinner is only ever visible on a cold start.
- **`onBack` is a callback, not a pop.** The lobby is hosted as tab content
  (`QuizTabContent`), not pushed, so "back" means *return to the predictions
  shell*. Everything *after* the lobby is a pushed route.
- **The leaderboard button is violet**, matching the GLOBAL category — the
  leaderboard is the competitive capstone, same as that category.
- **Two entrance animations, staggered.** The hero rises with
  `CyberSlideUpFadeIn` (480 ms, 30px). The four category tiles are *dealt* with
  `CyberDealtCard` — fly up 260px, alternating ±0.07 rad tilt, `easeOutBack`
  settle from 0.92 — starting at 120 ms and stepping 75 ms per tile
  (`index: mode.index`). The lobby builds in like a hand of cards.
- **`maxWidth: 430`** constrains the column on tablets and web; the grid is
  `shrinkWrap` + `NeverScrollableScrollPhysics` inside the outer `ListView`.

---

## 4. The hero — `_KnowledgeArenaHero`

Verbatim:

```dart
class _KnowledgeArenaHero extends StatelessWidget {
  const _KnowledgeArenaHero({required this.sport, required this.progress});

  final Sport sport;
  final QuizProgress progress;

  @override
  Widget build(BuildContext context) {
    final passed = QuizMode.values.fold<int>(
      0,
      (sum, mode) => sum + progress.forMode(mode).completedCount,
    );
    final total = QuizMode.values.length * kQuizSetCount;
    final progressValue = total == 0 ? 0.0 : passed / total;
    final progressPercent = (progressValue * 100).round();

    return Semantics(
      container: true,
      label:
          'Knowledge Arena. ${sport.name} trivia with four categories. '
          '$passed of $total sets cleared. Every attempt contains 10 questions.',
      child: CyberPanel(
        accent: Cyber.cyan,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 16, 0),
              child: Row(
                children: [
                  Container(width: 5, height: 5, color: Cyber.cyan),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'QUIZ GRID // ${sport.name.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.label(
                        7.5,
                        color: Cyber.cyan,
                        letterSpacing: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 18,
                    height: 1,
                    color: Cyber.cyan.withValues(alpha: 0.16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '04 TRACKS',
                    style: Cyber.label(
                      7.5,
                      color: Cyber.muted,
                      letterSpacing: 1.1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 62,
                    height: 72,
                    child: ChamferedActionSurface(
                      clipper: const HudChamferClipper(bigCut: 12, smallCut: 4),
                      borderColor: Cyber.cyan.withValues(alpha: 0.58),
                      child: ColoredBox(
                        color: Color.lerp(Cyber.panel2, Cyber.cyan, 0.08)!,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              _sportIcon(sport),
                              color: Cyber.cyan,
                              size: 30,
                            ),
                            Positioned(
                              top: 9,
                              right: 9,
                              child: Container(
                                width: 5,
                                height: 5,
                                color: Cyber.cyan,
                              ),
                            ),
                            Positioned(
                              left: 9,
                              bottom: 8,
                              child: Text(
                                'TRIVIA',
                                style: Cyber.label(
                                  6.5,
                                  color: Cyber.muted,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'KNOWLEDGE',
                            style: Cyber.display(15.5, letterSpacing: 1.35),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'ARENA',
                          style: Cyber.display(
                            22,
                            color: Cyber.cyan,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'CLEAR SETS // CLIMB THE LADDER',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Cyber.label(
                            7,
                            color: Cyber.muted,
                            letterSpacing: 0.65,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(width: 1, height: 54, color: Cyber.border),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 52,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$passed',
                          style:
                              Cyber.display(
                                27,
                                color: Cyber.cyan,
                                letterSpacing: 0.3,
                              ).copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '/ $total',
                          style: Cyber.label(
                            9,
                            color: Cyber.muted,
                            letterSpacing: 0.4,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'SETS CLEARED',
                          textAlign: TextAlign.right,
                          style: Cyber.label(
                            6,
                            color: Cyber.muted,
                            letterSpacing: 0.65,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        'TOTAL MASTERY',
                        style: Cyber.label(
                          7.5,
                          color: Cyber.muted,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$progressPercent%',
                        style: Cyber.label(
                          8.5,
                          color: Cyber.cyan,
                          letterSpacing: 0.5,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  _ArenaProgressTrack(value: progressValue),
                ],
              ),
            ),
            Container(
              color: Cyber.panel2.withValues(alpha: 0.72),
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 12),
              child: Row(
                children: [
                  const Icon(Icons.route_outlined, color: Cyber.cyan, size: 17),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MISSION BRIEF',
                          style: Cyber.label(
                            7,
                            color: Cyber.cyan,
                            letterSpacing: 1.15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Clear sets to advance each category ladder.',
                          style: Cyber.body(10.5, color: Cyber.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ChamferedActionSurface(
                    clipper: const HudChamferClipper(bigCut: 8, smallCut: 3),
                    borderColor: Cyber.cyan.withValues(alpha: 0.42),
                    child: Container(
                      width: 58,
                      height: 38,
                      color: Cyber.bg.withValues(alpha: 0.6),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '10',
                            style:
                                Cyber.display(
                                  14,
                                  color: Cyber.cyan,
                                  letterSpacing: 0.3,
                                ).copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Q / RUN',
                            style: Cyber.label(
                              5.8,
                              color: Cyber.muted,
                              letterSpacing: 0.65,
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _ArenaProgressTrack extends StatelessWidget {
  const _ArenaProgressTrack({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: 8,
          child: Stack(
            children: [
              Positioned.fill(
                child: CyberProgressBar(
                  value: value,
                  accent: Cyber.cyan,
                  height: 8,
                ),
              ),
              for (final checkpoint in const [0.25, 0.5, 0.75])
                Positioned(
                  left: constraints.maxWidth * checkpoint - 0.5,
                  top: 1,
                  bottom: 1,
                  child: Container(
                    width: 1,
                    color: Cyber.bg.withValues(alpha: 0.82),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

IconData _sportIcon(Sport sport) => switch (sport) {
  Sport.football => Icons.sports_soccer,
  Sport.cricket => Icons.sports_cricket,
  Sport.motorsport => Icons.sports_motorsports,
  Sport.basketball => Icons.sports_basketball,
  Sport.tennis => Icons.sports_tennis,
};
```

The hero is **telemetry, not a banner** — the one place the player sees their
whole-sport progress:

- `passed` sums `completedCount` across all four categories; `total` is
  `4 × 50 = 200`. The big cyan number is sets cleared, `/ 200` beneath it.
- **`_ArenaProgressTrack`** is `CyberProgressBar` with three 1px `Cyber.bg`
  notches cut into it at 25 / 50 / 75%. The notches turn a plain meter into a
  milestone track — you can see how close you are to the next quarter. It is the
  **only** animated meter on the lobby (700 ms fill); the category tiles pass
  `animate: false` because the dealt-card entrance is already moving them.
- **HUD greeble** does real structural work here: `QUIZ GRID // FOOTBALL`,
  `04 TRACKS`, `CLEAR SETS // CLIMB THE LADDER`, and the `10 Q / RUN` plate tell the
  player the shape of the game before they tap anything.
- **The sport plate** is a `62 × 72` `ChamferedActionSurface` on a
  `HudChamferClipper(12, 4)` — the app's signature diagonal cut — with the sport
  glyph, a 5px corner tick and a `TRIVIA` stamp.
- **`KNOWLEDGE` sits in a `FittedBox(scaleDown)`** so a narrow screen shrinks it
  rather than overflowing; `ARENA` is the larger, cyan word.
- **No glow.** `CyberPanel` glow is off by default, and nothing on the lobby lights
  up. The lobby is a menu; the moments come later.
- A single `Semantics(container: true)` label reads the whole hero as one sentence.

`_sportIcon` is an exhaustive switch over `Sport` — add a sport and this stops
compiling until you give it a glyph.

---

## 5. The category tile — `_ModeTile`

Verbatim:

```dart
class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.sport,
    required this.mode,
    required this.progress,
    required this.onTap,
  });

  final Sport sport;
  final QuizMode mode;
  final QuizModeProgress progress;
  final VoidCallback onTap;

  int get _nextSet {
    for (var set = 1; set <= kQuizSetCount; set++) {
      if (progress.isSetUnlocked(set) && !progress.setProgress(set).completed) {
        return set;
      }
    }
    return kQuizSetCount;
  }

  @override
  Widget build(BuildContext context) {
    final accent = mode.accent;
    final complete = progress.completedCount == kQuizSetCount;
    return Semantics(
      button: true,
      label:
          '${mode.label} category, ${progress.completedCount} of $kQuizSetCount sets cleared, ${progress.starCount} stars, ${complete ? 'complete' : 'next set $_nextSet'}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: CyberPanel(
          accent: accent,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      border: Border.all(color: accent.withValues(alpha: 0.42)),
                    ),
                    child: Icon(mode.iconFor(sport), color: accent, size: 22),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '+${mode.reward} XP / CORRECT',
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.label(
                        7,
                        color: Cyber.gold,
                        letterSpacing: 0.4,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                mode.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Cyber.display(15, letterSpacing: 1.2),
              ),
              const SizedBox(height: 4),
              Text(
                mode.blurbFor(sport),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Cyber.label(
                  7.5,
                  color: Cyber.muted,
                  letterSpacing: 0.65,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                complete ? 'LADDER COMPLETE' : 'NEXT SET $_nextSet',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Cyber.label(
                  7.5,
                  color: complete
                      ? Cyber.success
                      : accent.withValues(alpha: 0.9),
                  letterSpacing: 0.7,
                ),
              ),
              const Spacer(),
              CyberProgressBar(
                value: progress.completedCount / kQuizSetCount,
                accent: accent,
                height: 6,
                animate: false,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Cyber.gold, size: 11),
                  const SizedBox(width: 3),
                  Text(
                    '${progress.starCount}',
                    style: Cyber.label(8.5, color: Cyber.gold).copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${progress.completedCount}/$kQuizSetCount',
                    style: Cyber.display(11, color: accent).copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
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
```

Each tile is a complete progress card for one category:

| Row | Content |
| --- | --- |
| Top | 44px accent-tinted icon plate · `+N XP / CORRECT` in gold |
| Middle | `EASY` (display 15) · sport-specific blurb (`FOOTBALL BASICS`, `SLAMS & TOURS`) |
| Status | `NEXT SET n` in the accent, or `LADDER COMPLETE` in `Cyber.success` |
| Bottom | 6px meter at `completedCount / 50` · ★ star count in gold · `n/50` |

The accent **climbs the skill ladder**: EASY `lime` → MEDIUM `amber` → HARD
`danger` → GLOBAL `violet`. The colour tells the difficulty before the label does.
Gold is reserved for XP and stars — rewards only, never an accent.

`Spacer()` pushes the meter to the bottom of the tile so all four tiles align their
meters regardless of blurb length; the grid's `childAspectRatio: 0.92` gives them the
height to do it.

> **Known gap — `_nextSet` ignores the authored count.** `_ModeTile._nextSet`
> walks all 50 sets and returns the first unlocked-and-incomplete one. It never
> consults `QuizBank` — the lobby does not load the bank at all. The set screen's
> `_nextChallenge` (§6.2) *does* stop at the authored count. So with a partially
> written ladder, the lobby tile can say `NEXT SET 11` while the set screen shows
> set 11 as `SOON`. It is latent today because every sport ships a complete 50-set
> ladder (pinned by `quiz_cubit_test.dart` — *every sport authors a full 50-set
> ladder*). **A port that ships content incrementally should fix this**: load the
> bank in the lobby, or clamp `_nextSet` to the authored count.

---

## 6. Screen 2 — `QuizSetScreen`

Verbatim:

```dart
class QuizSetScreen extends StatefulWidget {
  const QuizSetScreen({required this.sport, required this.mode, super.key});

  final Sport sport;
  final QuizMode mode;

  @override
  State<QuizSetScreen> createState() => _QuizSetScreenState();
}

class _QuizSetScreenState extends State<QuizSetScreen> {
  int? _selectedChapter;
  int? _launchingSet;
  bool _loadingBank = true;

  /// How many of the 50 sets the question database actually reaches. Anything
  /// past this renders as [QuizSetVisualState.upcoming] rather than falling back
  /// to filler questions.
  int _authoredSets = 0;

  @override
  void initState() {
    super.initState();
    _loadBank();
  }

  Future<void> _loadBank() async {
    await QuizBank.ensureLoaded(widget.sport, widget.mode);
    if (!mounted) return;
    setState(() {
      _authoredSets = QuizBank.authoredSetCount(widget.sport, widget.mode);
      _loadingBank = false;
    });
  }

  bool _isPlayable(int setNumber) => setNumber <= _authoredSets;

  int _nextChallenge(QuizModeProgress progress) {
    for (var set = 1; set <= kQuizSetCount; set++) {
      if (!_isPlayable(set)) break;
      if (progress.isSetUnlocked(set) && !progress.setProgress(set).completed) {
        return set;
      }
    }
    return _authoredSets < 1 ? 1 : _authoredSets;
  }

  QuizSetVisualState _visualState(QuizModeProgress progress, int setNumber) {
    final set = progress.setProgress(setNumber);
    if (set.mastered) return QuizSetVisualState.mastered;
    if (set.completed) return QuizSetVisualState.cleared;
    if (!_isPlayable(setNumber)) return QuizSetVisualState.upcoming;
    if (!progress.isSetUnlocked(setNumber)) return QuizSetVisualState.locked;
    return QuizSetVisualState.available;
  }

  Future<void> _startSet(int setNumber) async {
    if (_launchingSet != null) return;
    if (!_isPlayable(setNumber)) return;
    final quiz = context.read<QuizCubit>();
    if (!quiz.isSetUnlocked(widget.sport, widget.mode, setNumber)) return;

    setState(() => _launchingSet = setNumber);
    final game = context.read<GameBloc>();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EntryBriefing(
        sport: widget.sport,
        mode: widget.mode,
        setNumber: setNumber,
        coins: game.state.coins,
      ),
    );

    if (!mounted) return;
    if (confirmed != true) {
      setState(() => _launchingSet = null);
      return;
    }
    if (game.state.coins < kQuizEntryCost) {
      setState(() => _launchingSet = null);
      _showMessage('Need $kQuizEntryCost coins to play this quiz set.');
      return;
    }

    playSound(SoundEffect.coinSpend);
    playSound(SoundEffect.playMatch);
    game.add(
      CoinsSpent(
        kQuizEntryCost,
        source: OzCoinTransactionSource.quizEntry,
        title: '${widget.sport.name.toUpperCase()} QUIZ ENTRY',
        subtitle: '${widget.mode.label} SET $setNumber',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuizPlayScreen(
          sport: widget.sport,
          mode: widget.mode,
          setNumber: setNumber,
        ),
      ),
    );
    if (!mounted) return;
    final updated = quiz.progressFor(widget.sport, widget.mode);
    setState(() {
      _launchingSet = null;
      _selectedChapter = (_nextChallenge(updated) - 1) ~/ 10;
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
    final mode = widget.mode;
    return GameScaffold(
      title: '${mode.label} SETS',
      subtitle: 'KNOWLEDGE LADDER',
      leading: _BackButton(onTap: () => Navigator.of(context).maybePop()),
      rightSlot: const _CoinBalance(),
      child: BlocBuilder<QuizCubit, QuizState>(
        builder: (context, state) {
          if (_loadingBank) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.textPrimary),
            );
          }

          final progress = state.progressFor(widget.sport, mode);
          final nextChallenge = _nextChallenge(progress);
          final selectedChapter = _selectedChapter ?? (nextChallenge - 1) ~/ 10;
          final firstSet = selectedChapter * 10 + 1;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _NextChallengeCard(
                        sport: widget.sport,
                        mode: mode,
                        setNumber: nextChallenge,
                        progress: progress.setProgress(nextChallenge),
                        ladderComplete:
                            _authoredSets > 0 &&
                            progress.completedCount >= _authoredSets,
                        awaitingContent: _authoredSets == 0,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(
                            child: SectionLabel(label: 'SET CHAPTERS'),
                          ),
                          Text(
                            '${progress.completedCount}/$kQuizSetCount CLEARED',
                            style: Cyber.label(
                              9,
                              color: mode.accent,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(width: 9),
                          const Icon(
                            Icons.star_rounded,
                            color: Cyber.gold,
                            size: 12,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${progress.starCount}/${progress.maxStars}',
                            style:
                                Cyber.label(
                                  9,
                                  color: Cyber.gold,
                                  letterSpacing: 0.4,
                                ).copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _ChapterSelector(
                        selected: selectedChapter,
                        accent: mode.accent,
                        authoredSets: _authoredSets,
                        onSelected: (chapter) {
                          playSound(SoundEffect.uiTap);
                          setState(() => _selectedChapter = chapter);
                        },
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth < 350 ? 4 : 5;
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  childAspectRatio: 0.8,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                            itemCount: 10,
                            itemBuilder: (context, index) {
                              final setNumber = firstSet + index;
                              final visualState = _visualState(
                                progress,
                                setNumber,
                              );
                              return _SetTile(
                                key: ValueKey('quiz-set-$setNumber'),
                                mode: mode,
                                setNumber: setNumber,
                                progress: progress.setProgress(setNumber),
                                visualState: visualState,
                                launching: _launchingSet == setNumber,
                                onTap: () => _startSet(setNumber),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      _LadderRule(mode: mode),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

Four pieces of state, each with one job:

| Field | Job |
| --- | --- |
| `_loadingBank` | spinner until the question bank for this sport+mode is decoded |
| `_authoredSets` | how many of the 50 sets have questions — the `SOON` boundary |
| `_selectedChapter` | which band is showing; `null` means *follow the next challenge* |
| `_launchingSet` | the set being opened — a re-entrancy lock **and** the tile's glow |

### 6.1 Loading the bank

`initState` calls `QuizBank.ensureLoaded`, which is idempotent and de-duplicates
concurrent calls (App. B). The `mounted` check after the `await` guards a player
who backs out before the JSON finishes decoding. A missing or malformed asset
caches an **empty pool** rather than throwing, which makes `_authoredSets` 0 and
routes the whole screen into its `IN DEVELOPMENT` state instead of crashing.

> **Sharp edge — the screen only waits for the bank, not the cubit.** The
> `BlocBuilder` shows a spinner on `_loadingBank` but never checks
> `state.loading`. Reached through the lobby this cannot matter: the lobby itself
> waits for `state.loading`. But a port that **deep-links** straight to a set
> screen on a cold start would render with empty progress — every set locked but
> set 1 — until the cubit loads, and then snap. Add `|| state.loading` to the
> spinner condition if you deep-link.

### 6.2 `_nextChallenge` — where the player is

Walks the sets in order, **stopping at the first unwritten set**, and returns the
first one that is unlocked but not completed. If there is none, it falls back to the
last authored set (or set 1 when nothing is authored). That single number drives
three things:

- the `_NextChallengeCard` headline,
- the default chapter — `(nextChallenge − 1) ~/ 10`, so the ladder always opens on
  the band the player is actually in, and
- the chapter jump after a run (§6.5).

### 6.3 `ladderComplete` and `awaitingContent`

Computed at the call site rather than inside the card:

```dart
ladderComplete: _authoredSets > 0 && progress.completedCount >= _authoredSets,
awaitingContent: _authoredSets == 0,
```

`ladderComplete` compares against **authored** sets, not 50 — so a player who has
cleared everything written so far sees `LADDER COMPLETE`, not a nudge toward a
set that does not exist.

### 6.4 `_startSet` — the paid entry transaction

This is the most carefully guarded method in the file. In order:

1. **Three silent guards.** Already launching → return. Not authored → return.
   Not unlocked → return. `_SetTile` already disables those taps; these are
   belt-and-braces for anything that calls `_startSet` directly.
2. **Lock** — `_launchingSet = setNumber`. The tile starts glowing and reads
   `OPENING`, and any second tap hits guard 1.
3. **Brief** — a transparent, scroll-controlled bottom sheet showing the cost and
   the balance. The sheet gets `game.state.coins` as a **snapshot** at the moment it
   opens.
4. **Cancelled?** — `confirmed != true` covers both the close button (`false`) and
   a swipe-down or barrier tap (`null`). Unlock and return. **No coins move.**
5. **Re-check the balance** against the *live* `game.state.coins`.
6. **Spend** — stingers, then `CoinsSpent` with a ledger title
   (`FOOTBALL QUIZ ENTRY`) and subtitle (`EASY SET 12`) so the transaction reads
   properly in the coin history.
7. **120 ms beat**, then push the play screen and **await** its return.
8. **Return** — re-read progress, unlock, and move the chapter view (§6.5).

**Why step 5 is load-bearing.** It looks redundant — the briefing's CTA is already
disabled when the snapshot can't afford it. But the snapshot can go stale while the
sheet is open, and the wallet **refuses underfunded spends silently**: in the
source app `_nextCoinSnapshot` returns `null` when the balance would go negative,
and `_applyCoinDelta` then returns without emitting or reporting anything. So if
`_startSet` skipped step 5 and dispatched `CoinsSpent` into an empty wallet, the
spend would quietly not happen and the play screen would open anyway — **a free
run**. The re-check is the only thing between a stale snapshot and that. The App. D
wallet preserves the silent refusal on purpose so this stays true in a port.

**The spend is not awaited.** `game.add` is fire-and-forget; the 120 ms delay is the
only gap before the route push. It is enough in practice, and it doubles as a beat
that lets the `coinSpend` + `playMatch` stingers land before the transition
covers them. A port with a synchronous wallet can shorten it, but should keep a beat.

**Every exit path clears `_launchingSet`** — cancel, can't afford, and return from
play. Miss one and a tile stays glowing with every other tile unresponsive.

> **Minor — `playMatch` plays twice.** The briefing's `HudCtaButton` plays its
> default `tapSound` (`SoundEffect.playMatch`) plus a medium haptic when START SET
> is tapped. The sheet then pops, `_startSet` resumes, and plays
> `coinSpend` **and `playMatch` again**. The two are a few frames apart, so it
> reads as one thick stinger rather than an echo — but if you tune audio in a port,
> pass `tapSound: SoundEffect.uiTap` on the briefing CTA or drop the second call.

### 6.5 The return beat

```dart
final updated = quiz.progressFor(widget.sport, widget.mode);
setState(() {
  _launchingSet = null;
  _selectedChapter = (_nextChallenge(updated) - 1) ~/ 10;
});
```

When the play screen pops, the ladder **moves itself to wherever the player now
is.** Clear set 10 and the view flips from FOUNDATION to PROSPECT with set 11 lit
as `PLAY`. It is a small beat, but it is the payoff for finishing a chapter — the
next rung is already on screen, one tap away.

It reads through `quiz.progressFor` — the cubit captured *before* the await. On a
completed run the play screen `await`s `recordResult` before it shows the reveal,
and the reveal is what pops, so the new progress is already in state here. A mid-run
quit pops without recording anything; the beat then recomputes the same next
challenge and nothing moves.

### 6.6 The header row

`SET CHAPTERS` on the left; on the right, `12/50 CLEARED` in the category accent and
`★ 31/150` in gold with tabular figures. Completion and mastery are **two separate
counters** — a player can clear every set with one star each, and that should read
as unfinished business, not done.

### 6.7 The grid

`LayoutBuilder` picks **5 columns, or 4 under 350px** of available width, at
`childAspectRatio: 0.8` with 8px gaps. Always exactly 10 tiles —
`firstSet + index` for the selected chapter.

---

## 7. The headline — `_NextChallengeCard`

Verbatim:

```dart
class _NextChallengeCard extends StatelessWidget {
  const _NextChallengeCard({
    required this.sport,
    required this.mode,
    required this.setNumber,
    required this.progress,
    required this.ladderComplete,
    required this.awaitingContent,
  });

  final Sport sport;
  final QuizMode mode;
  final int setNumber;
  final QuizSetProgress progress;
  final bool ladderComplete;

  /// No sets are authored for this mode yet — say so plainly instead of
  /// pointing the player at a set they cannot open.
  final bool awaitingContent;

  @override
  Widget build(BuildContext context) {
    final accent = awaitingContent
        ? Cyber.muted
        : ladderComplete
        ? Cyber.success
        : mode.accent;
    final replay = progress.hasRun && !progress.mastered;
    return CyberPanel(
      accent: accent,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                awaitingContent
                    ? Icons.hourglass_empty
                    : ladderComplete
                    ? Icons.workspace_premium
                    : mode.iconFor(sport),
                color: accent,
                size: 22,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  awaitingContent
                      ? 'IN DEVELOPMENT'
                      : ladderComplete
                      ? 'LADDER COMPLETE'
                      : 'NEXT CHALLENGE',
                  style: Cyber.label(10, color: accent, letterSpacing: 1.6),
                ),
              ),
              CyberChip(
                label: awaitingContent
                    ? 'SOON'
                    : ladderComplete
                    ? 'CLEARED'
                    : 'SET $setNumber',
                color: accent,
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            awaitingContent
                ? '${mode.label} LADDER LOADING'
                : ladderComplete
                ? '${mode.label} KNOWLEDGE MASTERED'
                : '${mode.label} · SET $setNumber',
            style: Cyber.display(20, letterSpacing: 1.1),
          ),
          const SizedBox(height: 7),
          Text(
            awaitingContent
                ? 'This ladder is still being written. Try another mode or sport.'
                : ladderComplete
                ? 'Replay any set to chase a flawless 3-star run.'
                : replay
                ? 'Best ${progress.bestCorrect}/$kQuizQuestionsPerSet · ${progress.stars}/3 stars · replay for a perfect run.'
                : '10 questions · instant verdict after every answer.',
            style: Cyber.body(12, color: Cyber.muted),
          ),
        ],
      ),
    );
  }
}
```

One card, three states, resolved by the same nested ternary in every slot:

| State | Accent | Icon | Label | Chip | Title | Body |
| --- | --- | --- | --- | --- | --- | --- |
| `awaitingContent` | `muted` | hourglass | `IN DEVELOPMENT` | `SOON` | `EASY LADDER LOADING` | *This ladder is still being written…* |
| `ladderComplete` | `success` | premium badge | `LADDER COMPLETE` | `CLEARED` | `EASY KNOWLEDGE MASTERED` | *Replay any set to chase a flawless 3-star run.* |
| otherwise | mode accent | mode icon | `NEXT CHALLENGE` | `SET 12` | `EASY · SET 12` | see below |

The default body has its own split, on `replay = hasRun && !mastered`:

- **Played but not perfect** — `Best 8/10 · 2/3 stars · replay for a perfect run.`
  This is the replay hook: it names the gap between the player's best and a
  flawless run.
- **Unplayed** — `10 questions · instant verdict after every answer.`

`awaitingContent` is checked first everywhere, so an empty bank never shows a
misleading `LADDER COMPLETE` (0 cleared ≥ 0 authored would otherwise be true — which
is also why the call site guards `ladderComplete` with `_authoredSets > 0`).

---

## 8. The difficulty tabs — `_ChapterSelector` and `_ChapterTab`

Verbatim:

```dart
/// The five difficulty bands of a mode, one tab each. Band `k` covers sets
/// `10(k-1)+1…10k` and gets harder as you climb, so the rung name carries the
/// real information and the set range is the fine print.
class _ChapterSelector extends StatelessWidget {
  const _ChapterSelector({
    required this.selected,
    required this.accent,
    required this.authoredSets,
    required this.onSelected,
  });

  final int selected;
  final Color accent;
  final int authoredSets;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    // No `stretch` here: this Row sits inside a vertical ListView, so stretching
    // asks for infinite height and blanks the grid. The fixed-height tabs
    // define the row.
    return Row(
      children: [
        for (var chapter = 0; chapter < kQuizBandNames.length; chapter++) ...[
          if (chapter > 0) const SizedBox(width: 6),
          Expanded(
            child: _ChapterTab(
              chapter: chapter,
              selected: selected == chapter,
              // A band nobody can reach yet stays legible but reads as inert.
              authored: chapter * 10 < authoredSets,
              accent: accent,
              onTap: () => onSelected(chapter),
            ),
          ),
        ],
      ],
    );
  }
}

class _ChapterTab extends StatelessWidget {
  const _ChapterTab({
    required this.chapter,
    required this.selected,
    required this.authored,
    required this.accent,
    required this.onTap,
  });

  final int chapter;
  final bool selected;
  final bool authored;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final firstSet = chapter * 10 + 1;
    final ink = selected
        ? accent
        : authored
        ? Cyber.muted
        : Cyber.muted.withValues(alpha: 0.55);

    return Semantics(
      button: true,
      selected: selected,
      label:
          '${kQuizBandNames[chapter]}, sets $firstSet through ${firstSet + 9}',
      child: GestureDetector(
        key: ValueKey('quiz-chapter-$chapter'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.16) : Cyber.panel2,
            border: Border.all(color: selected ? accent : Cyber.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Difficulty rung — the reason to care which chapter you're on.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  kQuizBandNames[chapter],
                  maxLines: 1,
                  style: Cyber.label(7.5, color: ink, letterSpacing: 0.3),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${firstSet.toString().padLeft(2, '0')}–${firstSet + 9}',
                style: Cyber.label(
                  8.5,
                  color: selected
                      ? accent
                      : ink.withValues(alpha: authored ? 0.75 : 0.45),
                  letterSpacing: 0.4,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- **The band name is the headline; the set range is the fine print.**
  `FOUNDATION` in `label(7.5)` over `01–10` in tabular `label(8.5)`. The rung name
  is the reason to care which chapter you're on.
- **Three ink levels:** selected → the category accent with a 16% tint and a solid
  accent border; authored → `muted`; unauthored → `muted` at 55%, with the range
  dimmer still. An unwritten band stays legible but reads as inert. It stays
  **tappable** — you can look at a SOON chapter, you just can't play it.
- **The comment about `stretch` is a real bug avoided.** The `Row` sits in a
  vertical `ListView`, which gives unbounded height; `CrossAxisAlignment.stretch`
  would ask for infinite height and blank the grid below. The fixed 46px tabs
  define the row height instead. Keep the comment in a port.
- `FittedBox(scaleDown)` on the band name — `SPECIALIST` in a fifth of a 320px
  screen is tight.
- `ValueKey('quiz-chapter-$chapter')` is the test hook.

---

## 9. The set tile — `_SetTile`

Verbatim:

```dart
class _SetTile extends StatelessWidget {
  const _SetTile({
    super.key,
    required this.mode,
    required this.setNumber,
    required this.progress,
    required this.visualState,
    required this.launching,
    required this.onTap,
  });

  final QuizMode mode;
  final int setNumber;
  final QuizSetProgress progress;
  final QuizSetVisualState visualState;
  final bool launching;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled =
        visualState != QuizSetVisualState.locked &&
        visualState != QuizSetVisualState.upcoming &&
        !launching;
    final graded =
        visualState == QuizSetVisualState.mastered ||
        visualState == QuizSetVisualState.cleared;
    final color = switch (visualState) {
      QuizSetVisualState.mastered => Cyber.gold,
      QuizSetVisualState.cleared => Cyber.success,
      QuizSetVisualState.available => mode.accent,
      QuizSetVisualState.locked || QuizSetVisualState.upcoming => Cyber.muted,
    };
    final icon = switch (visualState) {
      QuizSetVisualState.mastered => Icons.workspace_premium,
      QuizSetVisualState.cleared => Icons.replay_circle_filled,
      QuizSetVisualState.available => Icons.play_circle_fill,
      QuizSetVisualState.locked => Icons.lock,
      QuizSetVisualState.upcoming => Icons.hourglass_empty,
    };
    final status = switch (visualState) {
      QuizSetVisualState.mastered => 'PERFECT',
      QuizSetVisualState.cleared => 'REPLAY',
      QuizSetVisualState.available => 'PLAY',
      QuizSetVisualState.locked => 'FINISH ${setNumber - 1}',
      QuizSetVisualState.upcoming => 'SOON',
    };

    return Semantics(
      button: enabled,
      enabled: enabled,
      label:
          'Set $setNumber, ${visualState.name}${progress.hasRun ? ', best ${progress.bestCorrect} of $kQuizQuestionsPerSet, ${progress.stars} of 3 stars' : ''}',
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: Color.lerp(Cyber.panel2, color, 0.07),
              border: Border.all(color: color.withValues(alpha: 0.62)),
              // Glow rule: only the tile being opened is "live".
              boxShadow: launching
                  ? Cyber.glow(color, alpha: 0.22, blur: 12)
                  : null,
            ),
            // Four stacked rows in a 5-column grid cell is tight; scaleDown
            // keeps the stars + best-score line legible at large text scales
            // instead of overflowing.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(height: 5),
                  Text(
                    setNumber.toString().padLeft(2, '0'),
                    style: Cyber.display(15, color: color),
                  ),
                  const SizedBox(height: 4),
                  if (graded)
                    CyberStarRating(earned: progress.stars, size: 11)
                  else
                    Text(
                      launching ? 'OPENING' : status,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: Cyber.label(
                        6.5,
                        color: color,
                        letterSpacing: 0.35,
                      ),
                    ),
                  if (graded ||
                      visualState == QuizSetVisualState.available) ...[
                    const SizedBox(height: 4),
                    Text(
                      graded
                          ? (launching
                                ? 'OPENING'
                                : '$status · ${progress.bestCorrect}/$kQuizQuestionsPerSet')
                          : '+${mode.reward} XP EACH',
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: Cyber.label(
                        5.8,
                        color: graded
                            ? Cyber.muted
                            : color.withValues(alpha: 0.8),
                        letterSpacing: 0.3,
                      ),
                    ),
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
```

Three exhaustive switches map the visual state to colour, icon and status. The
tile's second and third rows then change shape depending on whether the set is
**graded**:

| State | Colour | Icon | Row 3 | Row 4 | Tappable |
| --- | --- | --- | --- | --- | --- |
| `mastered` | `gold` | premium badge | ★★★ (glowing) | `PERFECT · 10/10` | ✓ |
| `cleared` | `success` | replay | ★★ / ★ / — | `REPLAY · 8/10` | ✓ |
| `available` | mode accent | play | `PLAY` | `+1 XP EACH` | ✓ |
| `locked` | `muted` | lock | `FINISH 11` | — | ✗ 50% |
| `upcoming` | `muted` | hourglass | `SOON` | — | ✗ 50% |

- **`locked` names the action.** `FINISH 11`, not `LOCKED` — the tile tells you how
  to open it.
- **`launching` overrides the text** with `OPENING` and adds the only glow on the
  screen: `Cyber.glow(color, alpha: 0.22, blur: 12)`. The comment says it — *only
  the tile being opened is live*. It also disables the tile, so the lock from §6.4 is
  visible as well as enforced.
- **Stars only glow on a full sweep** (`CyberStarRating`), so a grid of cleared
  sets is calm and a mastered one catches the eye.
- **`Opacity(0.5)` plus `onTap: null`** for disabled tiles — and `Semantics` gets
  `button: enabled, enabled: enabled`, so screen readers announce them correctly.
  The semantics label includes the best score and stars when there has been a run.
- **`FittedBox(scaleDown)` around the whole column.** Four stacked rows in a
  fifth-width cell overflow at large text scales; scaling down keeps them legible.
  The widget test pins this at 320px wide and 1.3× text.
- The fill is `Color.lerp(panel2, color, 0.07)` — a 7% wash of the state colour —
  with the border at 62%. Flat, never a gradient.

---

## 10. Chrome — `_BackButton`, `_CoinBalance`, `_LadderRule`

Verbatim:

```dart
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          playSound(SoundEffect.uiTap);
          onTap();
        },
        child: const Center(
          child: Icon(Icons.arrow_back_ios_new, size: 18, color: Cyber.cyan),
        ),
      ),
    );
  }
}

class _CoinBalance extends StatelessWidget {
  const _CoinBalance();

  @override
  Widget build(BuildContext context) {
    final coins = context.select<GameBloc, int>((bloc) => bloc.state.coins);
    return Semantics(
      label: '$coins coins available',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: Cyber.gold.withValues(alpha: 0.08),
          border: Border.all(color: Cyber.gold.withValues(alpha: 0.38)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.toll, color: Cyber.gold, size: 16),
            const SizedBox(width: 5),
            Text('$coins', style: Cyber.display(11, color: Cyber.gold)),
          ],
        ),
      ),
    );
  }
}

class _LadderRule extends StatelessWidget {
  const _LadderRule({required this.mode});

  final QuizMode mode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Cyber.panel2.withValues(alpha: 0.88),
        border: Border.all(color: Cyber.border),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: mode.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Finish all $kQuizQuestionsPerSet questions to unlock the next set — any score clears it. '
              'Score $kQuizQuestionsPerSet/$kQuizQuestionsPerSet for 3 stars.',
              style: Cyber.body(11.5, color: Cyber.muted),
            ),
          ),
        ],
      ),
    );
  }
}
```

- **`_CoinBalance` uses `context.select`**, not a `BlocBuilder` — it rebuilds only
  when `coins` changes, not on every `GameBloc` emission. So the balance ticks down
  live the moment the entry fee lands, which is exactly when the player looks at it.
  Gold tint and border, never a glow: persistent chrome.
- **`_BackButton` plays `uiTap` before calling back.** It is used on both screens —
  as `onBack` on the lobby, `maybePop` on the set screen.
- **`_LadderRule` states the no-fail rule in plain words** at the foot of the grid:
  *any score clears it; score 10/10 for 3 stars.* A game with an unusual rule should
  say it where the player is deciding.

---

## 11. The entry sheet — `_EntryBriefing` and `_BriefingStat`

Verbatim:

```dart
class _EntryBriefing extends StatelessWidget {
  const _EntryBriefing({
    required this.sport,
    required this.mode,
    required this.setNumber,
    required this.coins,
  });

  final Sport sport;
  final QuizMode mode;
  final int setNumber;
  final int coins;

  @override
  Widget build(BuildContext context) {
    final canAfford = coins >= kQuizEntryCost;
    final missing = (kQuizEntryCost - coins).clamp(0, kQuizEntryCost);
    return Container(
      decoration: BoxDecoration(
        color: Cyber.bg,
        border: Border(top: BorderSide(color: mode.accent, width: 2)),
      ),
      child: CyberPlainBackground(
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'ENTRY BRIEFING',
                            style: Cyber.display(17, letterSpacing: 1.6),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close entry briefing',
                          onPressed: () => Navigator.of(context).pop(false),
                          icon: const Icon(Icons.close, color: Cyber.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    CyberPanel(
                      accent: mode.accent,
                      glow: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                mode.iconFor(sport),
                                color: mode.accent,
                                size: 26,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${mode.label} · SET $setNumber',
                                      style: Cyber.display(18),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '${sport.name.toUpperCase()} · ${mode.blurbFor(sport)}',
                                      style: Cyber.label(
                                        8.5,
                                        color: Cyber.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _BriefingStat(
                            icon: Icons.help_outline,
                            label: 'QUESTIONS',
                            value: '$kQuizQuestionsPerSet',
                            accent: mode.accent,
                          ),
                          const SizedBox(height: 9),
                          _BriefingStat(
                            icon: Icons.star_rounded,
                            label: '3-STAR SCORE',
                            value:
                                '$kQuizQuestionsPerSet / $kQuizQuestionsPerSet',
                            accent: Cyber.gold,
                          ),
                          const SizedBox(height: 9),
                          _BriefingStat(
                            icon: Icons.bolt,
                            label: 'REWARD',
                            value: '+${mode.reward} XP / CORRECT',
                            accent: Cyber.gold,
                          ),
                          const SizedBox(height: 9),
                          _BriefingStat(
                            icon: Icons.toll,
                            label: 'ENTRY',
                            value: '$kQuizEntryCost COINS',
                            accent: Cyber.amber,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: canAfford
                            ? Cyber.panel2
                            : Cyber.danger.withValues(alpha: 0.08),
                        border: Border.all(
                          color: canAfford ? Cyber.border : Cyber.danger,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            canAfford
                                ? Icons.account_balance_wallet
                                : Icons.error_outline,
                            color: canAfford ? Cyber.gold : Cyber.danger,
                            size: 19,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              canAfford
                                  ? 'BALANCE · $coins COINS'
                                  : 'NEED $missing MORE COINS',
                              style: Cyber.label(
                                10,
                                color: canAfford ? Colors.white : Cyber.danger,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    HudCtaButton(
                      key: const ValueKey('quiz-confirm-entry'),
                      label: 'START SET',
                      helper: canAfford
                          ? '$kQuizEntryCost COINS WILL BE SPENT'
                          : 'NEED $missing MORE COINS',
                      accent: mode.accent,
                      enabled: canAfford,
                      onTap: canAfford
                          ? () => Navigator.of(context).pop(true)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BriefingStat extends StatelessWidget {
  const _BriefingStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: accent, size: 18),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1),
          ),
        ),
        Text(value, style: Cyber.label(10, color: accent)),
      ],
    );
  }
}
```

The briefing is a **pre-match card**, not a confirm dialog. It frames the set as a
mission — what you'll face, what you can win, what it costs — before asking for
coins:

| Row | Value | Colour |
| --- | --- | --- |
| QUESTIONS | `10` | mode accent |
| 3-STAR SCORE | `10 / 10` | gold |
| REWARD | `+1 XP / CORRECT` | gold |
| ENTRY | `25 COINS` | amber |

Then a wallet strip that flips on `canAfford`:

- **Affordable** — `panel2` fill, gold wallet icon, `BALANCE · 50 COINS` in white.
- **Short** — `danger` at 8%, danger border, error icon, `NEED 12 MORE COINS`.
  `missing` is clamped to `0..25`, so it never prints a negative.

And the CTA: `HudCtaButton` in the category accent, `START SET`, with a helper line
that repeats the consequence — `25 COINS WILL BE SPENT` — or the shortfall. When it
can't afford, the CTA is `enabled: false` **and** `onTap: null`, and it goes flat
(58% opacity, no halo). The shortfall is said twice, in the strip and on the button,
because it is the only reason the player can't proceed.

**Glow audit.** The sheet has **two** glowing elements: the briefing `CyberPanel`
(`glow: true`) and the CTA's pulsing halo (`HudCtaButton` glows by default). The
design system's rule is one focal element per screen. It is defensible here — the
sheet is a pre-match "moment", and panel-plus-CTA read as one unit — but it is a
deliberate exception, so decide it consciously in a port rather than copying it by
accident. Setting `glow: false` on the panel would leave the CTA as the single focal
point.

A 2px mode-accent rule across the top edge marks the sheet as belonging to the
category that opened it. `SafeArea(top: false)` plus `useSafeArea: true` on the
sheet keep it clear of the home indicator without double-insetting the top.

---

## 12. Gratification map

The lobby and ladder are menus, but every step pays the player back with a moment.
This is the list a port must not strip in the name of simplicity:

| Moment | What happens | Where |
| --- | --- | --- |
| Arrive | hero rises (480 ms); four category tiles are **dealt** in with tilt and an `easeOutBack` settle, 75 ms apart | §3 |
| See your standing | milestone-notched mastery meter fills over 700 ms; sets-cleared counter in display type | §4 |
| Choose a category | colour climbs the skill ladder lime → amber → danger → violet; gold `+N XP` promise on every tile | §5 |
| Land on the ladder | view opens on your current chapter; `NEXT CHALLENGE` names the exact set | §6.2, §7 |
| The replay hook | `Best 8/10 · 2/3 stars · replay for a perfect run.` | §7 |
| Mastery | a flawless set turns gold, reads `PERFECT`, and its three stars **glow** — the only calm-breaking tile on the grid | §9 |
| Commit | tap → tile **glows** and reads `OPENING` → the pre-match briefing slides up | §6.4, §9 |
| Pay in | medium haptic + `playMatch`, then `coinSpend` + `playMatch`; the header balance ticks down live | §6.4, §10 |
| Come back | the ladder jumps to the chapter you're now in, next set lit as `PLAY` | §6.5 |

---

## 13. Every value in one place

| Element | Value |
| --- | --- |
| Sets per category | `50` (`kQuizSetCount`), 5 chapters × 10 |
| Questions per set | `10` (`kQuizQuestionsPerSet`); 100 per band, 500 per category |
| Entry cost | `25` coins (`kQuizEntryCost`), per attempt, replays included |
| Stars | 10 → 3 · 7–9 → 2 (`kQuizTwoStarScore = 7`) · 1–6 → 1 · 0 → 0 |
| XP per correct | EASY `1` · MEDIUM `2` · HARD `4` · GLOBAL `5` |
| Category accents | EASY `lime` · MEDIUM `amber` · HARD `danger` · GLOBAL `violet` |
| Column width cap | `430` on both screens and the sheet |
| List padding | `EdgeInsets.fromLTRB(16, 16, 16, 28)` |
| Hero entrance | `CyberSlideUpFadeIn` — `480 ms`, `30px`, `easeOutCubic` |
| Tile entrance | `CyberDealtCard` — start `120 ms`, `+75 ms` per tile, `540 ms`, fly `260px`, tilt `±0.07 rad`, settle `0.92 → 1` `easeOutBack` |
| Mode grid | 2 columns, `childAspectRatio 0.92`, gap `12` |
| Hero meter | `CyberProgressBar` `8px`, animated `700 ms`, notches at 25/50/75% |
| Tile meter | `CyberProgressBar` `6px`, `animate: false` |
| Hero sport plate | `62 × 72`, `HudChamferClipper(12, 4)` |
| Chapter tab | height `46`, gap `6`, `AnimatedContainer 180 ms`, selected tint `16%` |
| Set grid | 5 columns (4 under `350px`), `childAspectRatio 0.8`, gap `8`, 10 tiles |
| Set tile | fill `lerp(panel2, colour, 0.07)`, border `62%`, disabled `Opacity 0.5`, `AnimatedContainer 180 ms` |
| Launching glow | `Cyber.glow(colour, alpha: 0.22, blur: 12)` |
| Star row on tile | `CyberStarRating(size: 11)` |
| Entry sheet | `showModalBottomSheet`, `isScrollControlled`, `useSafeArea`, transparent; 2px accent top rule |
| Briefing panel | `CyberPanel(glow: true)` |
| Launch beat | `120 ms` between `CoinsSpent` and the route push |
| CTA | `HudCtaButton` `64px`, disabled `0.58` opacity, no halo |

---

## 14. Design rules to keep

1. **No fail state.** Any complete run clears the set. Score decides stars only.
2. **A better replay can only help.** Keep best `correct`, never the latest.
3. **Earned beats unwritten.** A completed set stays graded even if content shrinks;
   an unwritten set reads `SOON`, never `FINISH n`.
4. **Never serve filler.** Unauthored sets are unplayable and say so. A short band
   stops the pool; it never shifts published questions.
5. **Charge only after confirmation, and re-check at the moment of charging.** The
   wallet refuses silently — the screen is the only guard against a free run.
6. **Clear the launch lock on every exit path.**
7. **Glow means live.** On these screens: the tile being opened, a full star sweep,
   and the entry sheet. Nothing on the lobby glows; persistent chrome never does.
8. **Colour carries meaning.** Accent = difficulty; gold = rewards (XP, stars,
   coins, mastery); success = cleared; muted = unavailable; danger = can't afford.
9. **Tell the player what to do.** `FINISH 11`, not `LOCKED`. `NEED 12 MORE COINS`,
   not `INSUFFICIENT FUNDS`.
10. **Numbers are tabular** — counters, ranges, balances, scores.
11. **Survive small screens and large text.** `FittedBox(scaleDown)` on dense
    cells, 4 columns under 350px, `maxWidth: 430`.
12. **Everything is labelled for screen readers** — tiles announce state, best
    score and stars; disabled tiles announce as disabled.

---

## 15. Tests

### Widget flow — [`test/quiz_set_flow_test.dart`](../../test/quiz_set_flow_test.dart)

The five tests that exercise these two screens:

| Test | Pins |
| --- | --- |
| *knowledge arena shows all categories and completion telemetry* | `KNOWLEDGE ARENA`; one `quiz-mode-<name>` tile per mode; each shows `+N XP / CORRECT` |
| *set entry briefing blocks play without enough coins* | at 0 coins: `ENTRY BRIEFING`, `NEED 25 MORE COINS`, no play screen, balance still 0 |
| *set entry is charged only after briefing confirmation* | at 50 coins: balance **still 50** while the briefing is open, `BALANCE · 50 COINS`; confirm → balance 25 and the play screen opens |
| *set ladder uses chapters and explicit progress states* | runs of 8 and 3 → `REPLAY · 8/10` and `REPLAY · 3/10` (both clear); set 3 `PLAY`; set 4 `FINISH 3`; tapping chapter 1 shows `quiz-set-11` and hides `quiz-set-1` |
| *the star grid fits a narrow, large-text set screen* | 320×640, 1.3× text, reduced motion; scores `[10, 8, 3, 10, 6, 9]` → `PERFECT · 10/10` ×2, both `REPLAY`s, `CyberStarRating` present |

The last test also **pins a known 7.0px bottom overflow** in the source app's
`GameScaffold` header at 1.3× text on a 320pt screen. It is shared page chrome — an
empty `GameScaffold` reproduces it — and the test asserts the exact magnitude so the
set tiles can't quietly add overflow of their own. The App. D scaffold doesn't carry
this overflow; if you port the real header, expect it.

The test harness wraps screens in `MultiBlocProvider` + `MaterialApp` with
`splashFactory: NoSplash.splashFactory` — the ink-sparkle shader can't be decoded by
the test runtime — and preloads every bank with `QuizBank.ensureLoaded` in `setUp`.

### Model and bank — [`test/quiz_cubit_test.dart`](../../test/quiz_cubit_test.dart)

| Group | Covers |
| --- | --- |
| set unlock rules | all modes open but only set 1; finishing unlocks exactly the next; a low score still clears; a scoreless run clears with no stars |
| `QuizSetProgress` | star grading; best run kept and attempts counted; legacy `passed` saves load; completion and stars tracked separately |
| `QuizCubit` | records a result and persists across a reload |
| question bank | constants match the economy; every sport authors a full ladder; sets deal in band order; every question well-formed; **an unauthored pool yields no playable sets**; **a half-authored pool stops rather than serving filler** |

### Keys

`quiz-mode-<mode>` · `quiz-set-<n>` · `quiz-chapter-<k>` · `quiz-confirm-entry`

### Not covered today — worth adding in a port

- the `upcoming` / `SOON` tile and the `IN DEVELOPMENT` and `LADDER COMPLETE` card
  states on the set screen (the empty-pool seam is only exercised against the play screen);
- the re-entrancy lock — a double tap opening one sheet, not two;
- the post-confirm re-check — the balance dropping while the sheet is open;
- the return beat jumping the chapter view after a run;
- the lobby tile's `NEXT SET n` against a partially authored ladder (§5).

---

## 16. Port checklist

1. **Dependencies.** Add `flutter_bloc`. Declare Orbitron and Onest, or retarget
   `Cyber.displayFont` / `bodyFont`.
2. **Stand-ins.** Paste App. D into one file. Keep the names — the screens call
   `GameBloc`, `CoinsSpent`, `GameScaffold`, `SecureGameStorage`, `playSound` and
   `QuizPlayScreen` exactly. Then replace each with your own system:
   - **wallet** — keep the silent refusal of underfunded spends, or keep `_startSet`'s
     re-check and make your wallet throw instead; don't lose both;
   - **storage** — anything durable; one JSON string per sport;
   - **play screen** — must call `QuizCubit.recordResult` before popping.
3. **Models.** Paste App. A. If you drop a sport or a category, the exhaustive
   switches in `QuizModeX` and `_sportIcon` will tell you every place to update.
4. **Bank.** Paste App. B, declare `assets/quiz/` in `pubspec.yaml`, and ship one
   `<sport>_<mode>.json` per pool. It's fine to ship a few bands first.
5. **Shared widgets.** Paste App. C.
6. **Provide the cubit once, at the app root,** and call `load()` — the lobby
   expects it already loading.
7. **Screens.** Paste §3–§11 verbatim. Host `QuizLobbyScreen` wherever your game
   list lives and give it an `onBack`.
8. **Decide the known issues:** clamp the lobby's `NEXT SET` to authored sets if you
   ship content incrementally (§5); add `|| state.loading` to the set screen's
   spinner if you deep-link (§6.1); pick one `playMatch` (§6.4); keep or drop the
   second glow on the briefing (§11).
9. **Verify.** `flutter analyze` clean, then in the app: tiles deal in on the lobby;
   the ladder opens on your chapter; an underfunded briefing blocks START SET;
   confirming spends exactly 25 once; the tile glows only while opening; finishing a
   chapter's last set flips the view to the next chapter; a 320px screen at large
   text still fits the grid.

---

## Implementation References

- [`lib/screens/quiz/quiz_lobby_screen.dart`](../../lib/screens/quiz/quiz_lobby_screen.dart)
  — `QuizSetVisualState` (24), `kQuizBandNames` (28), `QuizLobbyScreen` (36),
  `QuizSetScreen` (126), `_loadBank` (152), `_nextChallenge` (163),
  `_visualState` (173), `_startSet` (182), the post-confirm re-check (208), the return
  beat (236), `_BackButton` (389), `_KnowledgeArenaHero` (413),
  `_ArenaProgressTrack` (714), `_ModeTile` (752), `_ModeTile._nextSet` (765),
  `_CoinBalance` (887), `_NextChallengeCard` (914), `_ChapterSelector` (1009),
  `_ChapterTab` (1047), `_SetTile` (1120), `_LadderRule` (1247),
  `_EntryBriefing` (1277), `_BriefingStat` (1452), `_sportIcon` (1483).
- [`lib/models/quiz_trivia.dart`](../../lib/models/quiz_trivia.dart) — `QuizMode` (12),
  constants (14–22), `QuizModeX` (24), `QuizSetProgress` (130), `stars` (156),
  `QuizModeProgress` (182), `isSetUnlocked` (222), `QuizProgress` (264),
  `record` (298).
- [`lib/blocs/quiz/quiz_state.dart`](../../lib/blocs/quiz/quiz_state.dart),
  [`lib/blocs/quiz/quiz_cubit.dart`](../../lib/blocs/quiz/quiz_cubit.dart) —
  `recordResult` (33).
- [`lib/services/quiz_bank.dart`](../../lib/services/quiz_bank.dart) — `QuizBank` (20),
  `authoredSetCount` (49), `ensureLoaded` (56), `_parse` (80).
- [`lib/blocs/game/game_bloc.dart`](../../lib/blocs/game/game_bloc.dart) —
  `_onCoinsSpent` (714), `_applyCoinDelta` (1308), the silent refusal in
  `_nextCoinSnapshot` (1338).
- [`lib/widgets/cyber/cyber_widgets.dart`](../../lib/widgets/cyber/cyber_widgets.dart)
  — `CyberPlainBackground` (544), `SectionLabel` (651), `CyberProgressBar` (1123),
  `CyberPanel` (1430), `CyberClipper` (1895), `HudChamferClipper` (1920),
  `ChamferedActionSurface` (1954), `CyberChip` (3184), `CyberSlideUpFadeIn` (3318),
  `CyberDealtCard` (3425), `CyberStarRating` (3755).
- [`lib/widgets/cyber/cyber_cta_button.dart`](../../lib/widgets/cyber/cyber_cta_button.dart)
  — `HudCtaButton` (109).
- Hosting: [`lib/screens/quiz/quiz_hub.dart`](../../lib/screens/quiz/quiz_hub.dart)
  (`QuizTabContent`, 13); cubit provided at [`lib/app.dart`](../../lib/app.dart) (97).
- Destination: [`lib/screens/quiz/quiz_play_screen.dart`](../../lib/screens/quiz/quiz_play_screen.dart)
  — `QuizPlayScreen` (34), `recordResult` call (307).
- Content check: [`tool/verify_quiz_bank.dart`](../../tool/verify_quiz_bank.dart).
- Tests: [`test/quiz_set_flow_test.dart`](../../test/quiz_set_flow_test.dart),
  [`test/quiz_cubit_test.dart`](../../test/quiz_cubit_test.dart).
- Product: [`docs/product/games/football-quiz.md`](../product/games/football-quiz.md)
  (and the cricket, basketball, motorsport and tennis quiz pages).

---

## Appendix A — progression model, verbatim

### A.1 `lib/models/quiz_trivia.dart`

(imports omitted — it needs `package:flutter/material.dart`, `Cyber` and `Sport`)

```dart
/// The four Knowledge Arena quiz modes. Three are skill tiers
/// (easy → medium → hard) and [global] is the world-sport capstone. Each mode
/// is a self-contained pool of answer-keyed trivia (see `quiz_trivia_bank.dart`).
///
/// Modes are progression-gated: [easy] is always open; every other mode unlocks
/// once its [unlockedBy] predecessor is *cleared* (see [QuizProgress.isUnlocked]).
enum QuizMode { easy, medium, hard, global }

const int kQuizSetCount = 50;
const int kQuizQuestionsPerSet = 10;
const int kQuizQuestionPoolPerMode = kQuizSetCount * kQuizQuestionsPerSet;
const int kQuizEntryCost = 25;

/// Best-score thresholds for the mastery stars shown on the set grid. There is
/// no pass/fail gate — finishing a set always clears it — so stars are the
/// reason to replay.
const int kQuizTwoStarScore = 7;

extension QuizModeX on QuizMode {
  /// HUD label.
  String get label => switch (this) {
    QuizMode.easy => 'EASY',
    QuizMode.medium => 'MEDIUM',
    QuizMode.hard => 'HARD',
    QuizMode.global => 'GLOBAL',
  };

  /// One-line pitch shown on the mode tile — sport-specific copy so cricket /
  /// tennis / basketball / motorsport never inherit football wording.
  String blurbFor(Sport sport) => switch (this) {
    QuizMode.easy => switch (sport) {
      Sport.football => 'FOOTBALL BASICS',
      Sport.cricket => 'CRICKET BASICS',
      Sport.tennis => 'TENNIS BASICS',
      Sport.basketball => 'BASKETBALL BASICS',
      Sport.motorsport => 'MOTORSPORT BASICS',
    },
    QuizMode.medium => switch (sport) {
      Sport.football => 'CLUBS & CUPS',
      Sport.cricket => 'TEAMS & TOURNAMENTS',
      Sport.tennis => 'SLAMS & TOURS',
      Sport.basketball => 'TEAMS & TITLES',
      Sport.motorsport => 'TEAMS & SERIES',
    },
    QuizMode.hard => 'DEEP-CUT TRIVIA',
    QuizMode.global => switch (sport) {
      Sport.football => 'WORLD FOOTBALL',
      Sport.cricket => 'WORLD CRICKET',
      Sport.tennis => 'WORLD TENNIS',
      Sport.basketball => 'WORLD BASKETBALL',
      Sport.motorsport => 'WORLD MOTORSPORT',
    },
  };

  /// XP paid per correct answer. Every correct answer pays, whatever the final
  /// score — there is no pass gate.
  int get reward => switch (this) {
    QuizMode.easy => 1,
    QuizMode.medium => 2,
    QuizMode.hard => 4,
    QuizMode.global => 5,
  };

  /// Accent colour — follows the glow/colour discipline: success→amber→danger
  /// climb the skill ladder, violet marks the global capstone.
  Color get accent => switch (this) {
    QuizMode.easy => Cyber.lime,
    QuizMode.medium => Cyber.amber,
    QuizMode.hard => Cyber.danger,
    QuizMode.global => Cyber.violet,
  };

  /// Easy uses the sport glyph; medium/hard/global keep the ladder icons.
  IconData iconFor(Sport sport) => switch (this) {
    QuizMode.easy => switch (sport) {
      Sport.football => Icons.sports_soccer,
      Sport.cricket => Icons.sports_cricket,
      Sport.tennis => Icons.sports_tennis,
      Sport.basketball => Icons.sports_basketball,
      Sport.motorsport => Icons.sports_motorsports,
    },
    QuizMode.medium => Icons.emoji_events_outlined,
    QuizMode.hard => Icons.local_fire_department_outlined,
    QuizMode.global => Icons.public,
  };

  /// Legacy mode-ladder dependency. Quiz categories are all open;
  /// set progression is gated inside each mode.
  QuizMode? get unlockedBy => switch (this) {
    QuizMode.easy => null,
    QuizMode.medium => QuizMode.easy,
    QuizMode.hard => QuizMode.medium,
    QuizMode.global => QuizMode.hard,
  };
}

/// One answer-keyed trivia question. Unlike the prediction bank's fixture-bound
/// markets, the correct answer is known up front ([correctIndex]).
class TriviaQuestion {
  const TriviaQuestion({
    required this.id,
    required this.mode,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.backgroundAsset,
  });

  final String id;
  final QuizMode mode;
  final String prompt;
  final List<String> options;
  final int correctIndex;

  /// Optional full-bleed backdrop; null falls back to the panel gradient.
  final String? backgroundAsset;

  String get correctLabel => options[correctIndex];
  String labelFor(int? index) =>
      index == null || index < 0 || index >= options.length
      ? '—'
      : options[index];
}

class QuizSetProgress {
  const QuizSetProgress({
    this.completed = false,
    this.bestCorrect = 0,
    this.attempts = 0,
  });

  /// The persisted key stays `passed` (and still falls back to the older
  /// `cleared`) so saves written before the pass gate was removed keep loading.
  factory QuizSetProgress.fromJson(Map<String, dynamic> json) =>
      QuizSetProgress(
        completed: json['passed'] as bool? ?? json['cleared'] as bool? ?? false,
        bestCorrect: json['bestCorrect'] as int? ?? 0,
        attempts: json['attempts'] as int? ?? json['played'] as int? ?? 0,
      );

  /// True once the player has answered every question in the set once. Any
  /// score completes it — the score only decides [stars].
  final bool completed;
  final int bestCorrect;
  final int attempts;

  bool get hasRun => attempts > 0;
  double get bestPct => bestCorrect / kQuizQuestionsPerSet;

  /// Mastery grade, 0–3. A flawless run is the only way to three stars.
  int get stars {
    if (bestCorrect >= kQuizQuestionsPerSet) return 3;
    if (bestCorrect >= kQuizTwoStarScore) return 2;
    if (bestCorrect > 0) return 1;
    return 0;
  }

  bool get mastered => stars >= 3;

  QuizSetProgress merge({required int correct}) {
    return QuizSetProgress(
      completed: true,
      bestCorrect: correct > bestCorrect ? correct : bestCorrect,
      attempts: attempts + 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'passed': completed,
    'bestCorrect': bestCorrect,
    'attempts': attempts,
  };
}

/// Persisted progress for a single mode: 50 sequential sets, where set 1 starts
/// unlocked and each next set opens after the previous set is passed.
class QuizModeProgress {
  const QuizModeProgress({this.sets = const {}});

  factory QuizModeProgress.fromJson(Map<String, dynamic> json) {
    final rawSets = json['sets'];
    if (rawSets is Map) {
      return QuizModeProgress(
        sets: {
          for (final entry in rawSets.entries)
            int.parse(entry.key.toString()): QuizSetProgress.fromJson(
              Map<String, dynamic>.from(entry.value as Map),
            ),
        },
      );
    }

    // Backwards compatibility for the old single-run-per-mode shape: if a mode
    // had been cleared, treat set 1 as passed so returning players keep access.
    final legacyCleared = json['cleared'] as bool? ?? false;
    final legacyBest = json['bestCorrect'] as int? ?? 0;
    final legacyPlayed = json['played'] as int? ?? 0;
    if (!legacyCleared && legacyBest == 0 && legacyPlayed == 0) {
      return const QuizModeProgress();
    }
    return QuizModeProgress(
      sets: {
        1: QuizSetProgress(
          completed: legacyCleared,
          bestCorrect: legacyBest.clamp(0, kQuizQuestionsPerSet),
          attempts: legacyPlayed,
        ),
      },
    );
  }

  final Map<int, QuizSetProgress> sets;

  QuizSetProgress setProgress(int setNumber) =>
      sets[setNumber] ?? const QuizSetProgress();

  bool isSetUnlocked(int setNumber) {
    if (setNumber < 1 || setNumber > kQuizSetCount) return false;
    if (setNumber == 1) return true;
    return setProgress(setNumber - 1).completed;
  }

  int get completedCount =>
      sets.entries.where((entry) => entry.value.completed).length;

  /// Total mastery stars banked across the mode's 50 sets (max 150).
  int get starCount => sets.values.fold(0, (sum, set) => sum + set.stars);

  int get maxStars => kQuizSetCount * 3;

  bool get cleared => completedCount >= kQuizSetCount;
  bool get hasRun => sets.values.any((set) => set.hasRun);
  int get played => sets.values.fold(0, (sum, set) => sum + set.attempts);
  int get bestCorrect => sets.values.fold(
    0,
    (best, set) => set.bestCorrect > best ? set.bestCorrect : best,
  );
  int get bestTotal => kQuizQuestionsPerSet;
  double get bestPct => bestCorrect / kQuizQuestionsPerSet;

  QuizModeProgress recordSet(int setNumber, {required int correct}) {
    final before = setProgress(setNumber);
    return QuizModeProgress(
      sets: {
        ...sets,
        setNumber: before.merge(correct: correct),
      },
    );
  }

  Map<String, dynamic> toJson() => {
    'sets': {
      for (final entry in sets.entries) '${entry.key}': entry.value.toJson(),
    },
  };
}

/// The full per-mode progress map, with set unlock rules baked in.
class QuizProgress {
  const QuizProgress(this.byMode);

  factory QuizProgress.initial() => const QuizProgress({});

  factory QuizProgress.fromJson(Map<String, dynamic> json) => QuizProgress({
    for (final mode in QuizMode.values)
      if (json[mode.name] != null)
        mode: QuizModeProgress.fromJson(
          Map<String, dynamic>.from(json[mode.name] as Map),
        ),
  });

  final Map<QuizMode, QuizModeProgress> byMode;

  QuizModeProgress forMode(QuizMode mode) =>
      byMode[mode] ?? const QuizModeProgress();

  /// All four categories are open; numbered sets are gated inside each mode.
  bool isUnlocked(QuizMode mode) => true;

  bool isSetUnlocked(QuizMode mode, int setNumber) =>
      forMode(mode).isSetUnlocked(setNumber);

  int get clearedCount =>
      QuizMode.values.where((m) => forMode(m).cleared).length;

  /// Returns an updated copy with [mode]'s result folded in.
  ///
  /// [newlyCleared] is true when this run completed the set for the first time
  /// (so the reveal can play a "SET N+1 UNLOCKED" beat), [stars] is the set's
  /// mastery grade afterwards and [starsGained] is how many this run added on
  /// top of the previous best. The reveal reads all three from here rather than
  /// re-reading cubit state after an await, so they can never disagree.
  ({QuizProgress progress, bool newlyCleared, int stars, int starsGained})
  record(
    QuizMode mode, {
    required int correct,
    required int total,
    int setNumber = 1,
  }) {
    final before = forMode(mode);
    final beforeSet = before.setProgress(setNumber);
    final after = before.recordSet(setNumber, correct: correct);
    final afterSet = after.setProgress(setNumber);
    return (
      progress: QuizProgress({...byMode, mode: after}),
      newlyCleared: !beforeSet.completed && afterSet.completed,
      stars: afterSet.stars,
      starsGained: afterSet.stars - beforeSet.stars,
    );
  }

  Map<String, dynamic> toJson() => {
    for (final entry in byMode.entries) entry.key.name: entry.value.toJson(),
  };
}
```

Two persistence details worth keeping:

- **Backwards-compatible keys.** `QuizSetProgress.toJson` still writes `passed`, and
  `fromJson` falls back through `passed` → `cleared`, and `attempts` → `played`, so
  saves from before the pass gate was removed keep loading. `QuizModeProgress.fromJson`
  also accepts the old one-run-per-mode shape and maps it onto set 1. A fresh port
  with no legacy saves can drop both fallbacks.
- **`record` returns a record** — `newlyCleared`, `stars`, `starsGained` — computed
  from the *before* and *after* in one pass, so the play screen's reveal reads them
  from the return value instead of re-reading cubit state after an `await` where they
  could disagree.

### A.2 `lib/blocs/quiz/quiz_state.dart`

```dart
/// Holds the player's persisted Quiz progress (per-mode cleared flags
/// and best runs) keyed by Sport. [loading] is true until the first read from storage lands.
class QuizState {
  const QuizState({
    this.loading = true,
    this.progressBySport = const {},
  });

  final bool loading;
  final Map<Sport, QuizProgress> progressBySport;

  QuizProgress progressForSport(Sport sport) =>
      progressBySport[sport] ?? const QuizProgress({});

  bool isUnlocked(Sport sport, QuizMode mode) =>
      progressForSport(sport).isUnlocked(mode);
  QuizModeProgress progressFor(Sport sport, QuizMode mode) =>
      progressForSport(sport).forMode(mode);

  QuizState copyWith({bool? loading, Map<Sport, QuizProgress>? progressBySport}) => QuizState(
    loading: loading ?? this.loading,
    progressBySport: progressBySport ?? this.progressBySport,
  );
}

```

### A.3 `lib/blocs/quiz/quiz_cubit.dart`

```dart

/// Owns the Quiz progression: which modes are unlocked and the best
/// run per mode across all sports. There is no backend — progress is personal and persisted
/// on-device via [SecureGameStorage], mirroring `FriendsCubit`.
class QuizCubit extends Cubit<QuizState> {
  QuizCubit(this._storage) : super(const QuizState());

  final SecureGameStorage _storage;

  Future<void> load() async {
    final Map<Sport, QuizProgress> progressBySport = {};
    for (final sport in Sport.values) {
      progressBySport[sport] = await _storage.loadQuizProgress(sport);
    }
    emit(QuizState(loading: false, progressBySport: progressBySport));
  }

  bool isUnlocked(Sport sport, QuizMode mode) => state.isUnlocked(sport, mode);
  bool isSetUnlocked(Sport sport, QuizMode mode, int setNumber) =>
      state.progressForSport(sport).isSetUnlocked(mode, setNumber);
  QuizModeProgress progressFor(Sport sport, QuizMode mode) => state.progressFor(sport, mode);
  QuizSetProgress setProgressFor(Sport sport, QuizMode mode, int setNumber) =>
      state.progressFor(sport, mode).setProgress(setNumber);

  /// Folds a finished session into the persisted progress. Returns the outcome
  /// so the reveal can play its "SET N+1 UNLOCKED" and mastery-star beats.
  Future<({bool newlyCleared, int stars, int starsGained})> recordResult(
    Sport sport,
    QuizMode mode, {
    int setNumber = 1,
    required int correct,
    required int total,
  }) async {
    final result = state.progressForSport(sport).record(
      mode,
      setNumber: setNumber,
      correct: correct,
      total: total,
    );
    final nextProgressBySport = Map<Sport, QuizProgress>.from(state.progressBySport);
    nextProgressBySport[sport] = result.progress;

    emit(state.copyWith(progressBySport: nextProgressBySport));
    await _storage.saveQuizProgress(sport, result.progress);
    return (
      newlyCleared: result.newlyCleared,
      stars: result.stars,
      starsGained: result.starsGained,
    );
  }
}

```

`recordResult` **emits before it persists**, so the UI updates immediately and the
write happens behind it. The ladder's return beat (§6.5) depends on that: after a
completed run, the new progress is already in state when the play screen pops.

---

## Appendix B — the question bank, verbatim

### B.1 `lib/services/quiz_bank.dart`

```dart

/// Loads the authored trivia database off the asset bundle and caches it.
///
/// One JSON file per sport+mode lives at `assets/quiz/<sport>_<mode>.json`.
/// Each file carries five **bands** of [kQuizBandSize] questions; band `k` owns
/// sets `10(k-1)+1 … 10k`, so flattening bands 1→5 reproduces the 500-question
/// pool the ladder indexes into. Bands exist so difficulty can ramp across the
/// 50 sets — band 1 is the gentlest rung of a mode, band 5 the hardest.
///
/// A file may ship with later bands empty (the database is authored one batch at
/// a time). A short pool is not an error: [authoredSetCount] reports how many of
/// the 50 sets actually exist so the lobby can render the rest as "SOON" rather
/// than fall back to filler questions.
abstract final class QuizBank {
  /// Questions per difficulty band — 10 sets × 10 questions.
  static const int kQuizBandSize = kQuizQuestionsPerSet * kSetsPerBand;

  /// Sets covered by one band. Five bands span the 50-set ladder.
  static const int kSetsPerBand = 10;

  /// Number of difficulty bands in every mode.
  static const int kBandCount = kQuizSetCount ~/ kSetsPerBand;

  static final Map<String, List<TriviaQuestion>> _pools = {};
  static final Map<String, Future<void>> _inFlight = {};

  static String _key(Sport sport, QuizMode mode) => '${sport.name}_${mode.name}';

  static String assetPath(Sport sport, QuizMode mode) =>
      'assets/quiz/${_key(sport, mode)}.json';

  /// True once [ensureLoaded] has resolved for this pool.
  static bool isLoaded(Sport sport, QuizMode mode) =>
      _pools.containsKey(_key(sport, mode));

  /// The flattened question pool, or an empty list when not yet loaded.
  static List<TriviaQuestion> pool(Sport sport, QuizMode mode) =>
      _pools[_key(sport, mode)] ?? const <TriviaQuestion>[];

  /// How many of the 50 sets have authored questions behind them. Partial sets
  /// don't count — a set needs all [kQuizQuestionsPerSet] questions to be
  /// playable.
  static int authoredSetCount(Sport sport, QuizMode mode) =>
      pool(sport, mode).length ~/ kQuizQuestionsPerSet;

  /// Parses `assets/quiz/<sport>_<mode>.json` into the cache. Idempotent, and
  /// concurrent calls share one decode. A missing or malformed file caches an
  /// empty pool rather than throwing — the ladder then shows every set as
  /// upcoming instead of crashing the screen.
  static Future<void> ensureLoaded(Sport sport, QuizMode mode) {
    final key = _key(sport, mode);
    if (_pools.containsKey(key)) return Future<void>.value();
    return _inFlight[key] ??= _load(sport, mode, key).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  static Future<void> _load(Sport sport, QuizMode mode, String key) async {
    try {
      final raw = await rootBundle.loadString(assetPath(sport, mode));
      _pools[key] = _parse(
        jsonDecode(raw) as Map<String, dynamic>,
        sport,
        mode,
      );
    } catch (_) {
      _pools[key] = const <TriviaQuestion>[];
    }
  }

  /// Flattens `bands` 1→5 into a single ordered pool. Stops at the first band
  /// that is missing or short, so a half-authored band can never shift the
  /// questions behind an already-published set.
  static List<TriviaQuestion> _parse(
    Map<String, dynamic> json,
    Sport sport,
    QuizMode mode,
  ) {
    final bands = json['bands'];
    if (bands is! Map) return const <TriviaQuestion>[];

    final questions = <TriviaQuestion>[];
    for (var band = 1; band <= kBandCount; band++) {
      final entries = bands['$band'];
      if (entries is! List || entries.length < kQuizBandSize) break;
      for (var index = 0; index < kQuizBandSize; index++) {
        final parsed = _question(
          entries[index],
          sport,
          mode,
          questions.length + 1,
        );
        if (parsed == null) return questions;
        questions.add(parsed);
      }
    }
    return List<TriviaQuestion>.unmodifiable(questions);
  }

  /// `{"p": prompt, "o": [4 options], "a": correctIndex}` → [TriviaQuestion].
  /// The id is positional so it stays stable regardless of file formatting, and
  /// keeps the `<mode>_q<NNN>` shape the rest of the app matches on.
  static TriviaQuestion? _question(
    Object? entry,
    Sport sport,
    QuizMode mode,
    int number,
  ) {
    if (entry is! Map) return null;
    final prompt = entry['p'];
    final rawOptions = entry['o'];
    final answer = entry['a'];
    if (prompt is! String || prompt.isEmpty) return null;
    if (rawOptions is! List || rawOptions.length < 2) return null;
    if (answer is! int || answer < 0 || answer >= rawOptions.length) return null;

    return TriviaQuestion(
      id: '${sport.name}_${mode.name}_q${number.toString().padLeft(3, '0')}',
      mode: mode,
      prompt: prompt,
      options: List<String>.unmodifiable(rawOptions.map((o) => '$o')),
      correctIndex: answer,
    );
  }

  /// Test seam — forces a pool without touching the asset bundle, so the
  /// unauthored-ladder path stays under test now that every sport ships one.
  static void debugSetPool(
    Sport sport,
    QuizMode mode,
    List<TriviaQuestion> questions,
  ) => _pools[_key(sport, mode)] = List<TriviaQuestion>.unmodifiable(questions);

  /// Test seam — drops every cached pool.
  static void debugReset() {
    _pools.clear();
    _inFlight.clear();
  }
}

```

### B.2 The asset format

One file per sport and category, at `assets/quiz/<sport>_<mode>.json`:

```json
{
  "sport": "football",
  "mode": "easy",
  "version": 1,
  "bands": {
    "1": [
      { "p": "How many players from each team start a football match on the pitch?",
        "o": ["9", "10", "11", "12"],
        "a": 2 }
    ],
    "2": [],
    "3": [],
    "4": [],
    "5": []
  }
}
```

- `p` prompt, `o` options (at least 2; the app authors 4), `a` zero-based correct
  index.
- Each band needs **exactly 100 well-formed entries to count.** A short band ends the
  pool there, and a malformed entry ends it at that entry — nothing after it is used.
  Ship bands in order.
- Question IDs are **positional** (`football_easy_q001`), not stored, so reformatting
  the file never changes them.
- Declare the folder in `pubspec.yaml` under `flutter: assets: - assets/quiz/`.
- The source app validates content with `dart run tool/verify_quiz_bank.dart` —
  counts, option lengths, duplicate prompts and answer-position balance.

---

## Appendix C — shared widgets, verbatim

From `lib/widgets/cyber/cyber_widgets.dart` unless noted. All need only `Cyber`,
`AppTheme` (App. D), `dart:async` and `package:flutter/material.dart`.

### C.1 `SectionLabel`

```dart
class SectionLabel extends StatelessWidget {
  const SectionLabel({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: Cyber.cyan.withValues(alpha: 0.7),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
```

### C.2 `CyberPanel`, `CyberClipper` and its border painter

The standard clipped surface: a flat `Cyber.panel` fill with a bottom-corner
chamfer, the accent entering only as a 50% border. Glow is opt-in.

```dart
class CyberPanel extends StatelessWidget {
  const CyberPanel({
    required this.child,
    this.accent = Cyber.cyan,
    this.padding = const EdgeInsets.all(16),
    this.glow = false,
    super.key,
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;

  /// Whether this is a focal / active surface that should glow. Off by default:
  /// most panels are plain surfaces and rely on the fill + border for depth.
  /// Reserve [glow] for the panel the user should look at first on a screen.
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final borderColor = accent.withValues(alpha: 0.5);
    return CustomPaint(
      foregroundPainter: _CyberPanelBorderPainter(color: borderColor),
      child: ClipPath(
        clipper: CyberClipper(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Cyber.panel,
            boxShadow: glow
                ? Cyber.glow(accent, alpha: 0.18, blur: 18, spread: 1)
                : null,
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class _CyberPanelBorderPainter extends CustomPainter {
  const _CyberPanelBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      CyberClipper.buildPath(size),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_CyberPanelBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

class CyberClipper extends CustomClipper<Path> {
  static const double cut = 12;

  static Path buildPath(Size size, {double cut = cut}) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(cut, size.height)
      ..lineTo(0, size.height - cut)
      ..close();
  }

  @override
  Path getClip(Size size) => buildPath(size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
```

### C.3 `HudChamferClipper`, `ChamferedActionSurface`, `ChamferedActionBorderPainter`

The four-corner diagonal cut used by the hero's sport plate and `10 Q / RUN` plate.
`ChamferedActionSurface` strokes the path in the foreground because a rectangular
`BoxDecoration` border would be clipped away along with the child.

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

/// Clips an interactive surface and strokes that exact path in the foreground.
///
/// A rectangular [BoxDecoration.border] is clipped along with its child and
/// therefore cannot paint the diagonal chamfer segments. CTA implementations
/// use this shell so every straight and cut edge receives the same border.
class ChamferedActionSurface extends StatelessWidget {
  const ChamferedActionSurface({
    required this.clipper,
    required this.borderColor,
    required this.child,
    this.borderWidth = 1,
    this.glowColor,
    this.glow = 0,
    super.key,
  });

  final CustomClipper<Path> clipper;
  final Color borderColor;
  final double borderWidth;
  final Color? glowColor;
  final double glow;
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: ChamferedActionBorderPainter(
      clipper: clipper,
      color: borderColor,
      width: borderWidth,
      glowColor: glowColor,
      glow: glow,
    ),
    child: ClipPath(clipper: clipper, child: child),
  );
}

/// Border painter shared by app CTAs that use a clipped action silhouette.
class ChamferedActionBorderPainter extends CustomPainter {
  const ChamferedActionBorderPainter({
    required this.clipper,
    required this.color,
    required this.width,
    this.glowColor,
    this.glow = 0,
  });

  final CustomClipper<Path> clipper;
  final Color color;
  final double width;
  final Color? glowColor;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final path = clipper.getClip(size);
    if (glow > 0 && glowColor != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = glowColor!.withValues(alpha: 0.22 * glow.clamp(0, 1))
          ..style = PaintingStyle.stroke
          ..strokeWidth = width + 1.5
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7 * glow),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(covariant ChamferedActionBorderPainter oldDelegate) =>
      oldDelegate.clipper != clipper ||
      oldDelegate.color != color ||
      oldDelegate.width != width ||
      oldDelegate.glowColor != glowColor ||
      oldDelegate.glow != glow;
}
```

### C.4 `CyberProgressBar`

The one meter used for every progress bar in the app. Note it carries its own
subtle accent shadow — by design, so every meter reads the same.

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

### C.5 `CyberStarRating`

```dart
const _segTrack = Color(0xFF314158);

/// Mastery grade for a quiz set — up to [max] chamfered star plates, [earned]
/// of them lit. Shared by the set grid and the end-of-run summary.
///
/// Follows the glow rule: only a full sweep (every star earned) glows, so a
/// wall of set tiles stays calm and a mastered one pops.
class CyberStarRating extends StatelessWidget {
  const CyberStarRating({
    required this.earned,
    this.max = 3,
    this.size = 12,
    this.spacing = 2,
    this.dimColor = _segTrack,
    super.key,
  });

  final int earned;
  final int max;
  final double size;
  final double spacing;
  final Color dimColor;

  @override
  Widget build(BuildContext context) {
    final complete = earned >= max;
    return Semantics(
      label: '$earned of $max stars',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < max; i++) ...[
            if (i > 0) SizedBox(width: spacing),
            Icon(
              i < earned ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: i < earned ? Cyber.gold : dimColor,
              shadows: i < earned && complete
                  ? [
                      Shadow(
                        color: Cyber.gold.withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}
```

### C.6 `CyberChip`

Note it builds a raw `TextStyle` with `fontFamily: 'Onest'` rather than going
through `Cyber.body` — it predates the helper. Harmless, but if you retarget the
body font, change it here too.

```dart
class CyberChip extends StatelessWidget {
  const CyberChip({required this.label, required this.color, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontFamily: 'Onest',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
```

### C.7 `CyberSlideUpFadeIn` and `CyberDealtCard`

Both are one-shot `Timer`-started entrances that dispose the timer and controller
safely if the widget leaves before the delay fires. Neither checks
`MediaQuery.disableAnimations`; the narrow-layout test runs with it on and the tiles
still land.

```dart
/// A one-shot "slide up + fade in" entrance. Wrap any element to have it rise
/// into place on first build; stagger siblings by passing increasing [delay]s.
/// Used for the lobby entrance reveals (home + shootout landing pages).
class CyberSlideUpFadeIn extends StatefulWidget {
  const CyberSlideUpFadeIn({
    required this.child,
    this.delay = Duration.zero,
    this.offset = 30,
    super.key,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<CyberSlideUpFadeIn> createState() => _CyberSlideUpFadeInState();
}

class _CyberSlideUpFadeInState extends State<CyberSlideUpFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;
  Timer? _kickoff;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _kickoff = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _kickoff?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (_, child) => Opacity(
        opacity: _progress.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - _progress.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// A one-shot "dealt card" entrance: the child flies up from below with a slight
/// alternating tilt and an easeOutBack settle, fading in along the way. Use for
/// rows of stat cells / action buttons; stagger via [index] + [staggerMs].
class CyberDealtCard extends StatefulWidget {
  const CyberDealtCard({
    required this.index,
    required this.child,
    this.initialDelay = const Duration(milliseconds: 220),
    this.staggerMs = 75,
    this.flyDistance = 260,
    this.duration = const Duration(milliseconds: 540),
    super.key,
  });

  final int index;
  final Widget child;
  final Duration initialDelay;
  final int staggerMs;
  final double flyDistance;
  final Duration duration;

  @override
  State<CyberDealtCard> createState() => _CyberDealtCardState();
}

class _CyberDealtCardState extends State<CyberDealtCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slide;
  late final Animation<double> _settle;
  late final Animation<double> _opacity;
  late final Animation<double> _tilt;
  Timer? _kickoff;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _slide = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _settle = Tween<double>(
      begin: 0.92,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
    );
    _tilt = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

    final delay =
        widget.initialDelay +
        Duration(milliseconds: widget.index * widget.staggerMs);
    _kickoff = Timer(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _kickoff?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        const tiltAmount = 0.07;
        final tiltAngle =
            (widget.index.isEven ? -tiltAmount : tiltAmount) *
            (1 - _tilt.value);
        return Opacity(
          opacity: _opacity.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, widget.flyDistance * (1 - _slide.value)),
            child: Transform.rotate(
              angle: tiltAngle,
              child: Transform.scale(
                scale: _settle.value.clamp(0.5, 1.2),
                child: child,
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
```

### C.8 `CyberPlainBackground`

Used behind the entry briefing. Reads `AppTheme.backgroundGradient`, which the
App. D shim provides.

```dart
class CyberPlainBackground extends StatelessWidget {
  const CyberPlainBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
          ),
        ),
        child,
      ],
    );
  }
}
```

### C.9 `HudCtaButton` — from `lib/widgets/cyber/cyber_cta_button.dart`

The primary CTA — angular silhouette, gradient fill, a pulsing halo that intensifies
on press. Needs `package:flutter/services.dart` for its haptic and `playSound` from
App. D. The file's `HudHoldCtaButton` wrapper is not used here and is omitted.

```dart
/// Accent blue used alongside [Cyber.cyan] for this button's gradient glow,
/// matching the primary CTA gradient elsewhere in the app.
const Color _accentBlue = Color(0xff5cb4ff);

/// Bright blue fill gradient (top-lit) for the inverted CTA treatment.
const Color _fillTop = Color(0xFF6FC4FF);
const Color _fillBottom = Color(0xFF2E90F5);

/// Dark ink used for the icon, divider and label sitting on the bright fill.
const Color _ink = Color(0xFF0C1422);

/// Angular HUD silhouette: a strong chamfer on the top-left and bottom-right
/// corners, with smaller angular accents on the top-right and bottom-left.
class _HudButtonClipper extends CustomClipper<Path> {
  final double bigCut;
  final double smallCut;
  const _HudButtonClipper({required this.bigCut, required this.smallCut});

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
  bool shouldReclip(covariant _HudButtonClipper old) =>
      old.bigCut != bigCut || old.smallCut != smallCut;
}

/// Paints the glowing cyan/blue border by stroking the same HUD path twice:
/// a soft blurred glow stroke under a crisp gradient stroke.
class _HudBorderPainter extends CustomPainter {
  final double glow; // 0..1 intensity
  final double bigCut;
  final double smallCut;
  final Color glowColor;
  final Color borderColor;
  const _HudBorderPainter({
    required this.glow,
    required this.bigCut,
    required this.smallCut,
    required this.glowColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _HudButtonClipper(
      bigCut: bigCut,
      smallCut: smallCut,
    ).buildPath(size);

    // Soft halo only when intensity > 0 — glow:false CTAs stay crisp/flat.
    if (glow > 0) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = glowColor.withValues(alpha: 0.30 + 0.40 * glow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + 6 * glow);
      canvas.drawPath(path, glowPaint);
    }

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.80 + 0.15 * glow),
          borderColor.withValues(alpha: 0.90),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _HudBorderPainter old) =>
      old.glow != glow ||
      old.bigCut != bigCut ||
      old.smallCut != smallCut ||
      old.glowColor != glowColor ||
      old.borderColor != borderColor;
}

/// Reusable gamified sci-fi HUD call-to-action button.
///
/// Angular clipped silhouette, glowing cyan border, bright gradient fill with
/// a chevron compartment and a glowing label. Pulses
/// gently while idle and intensifies on tap. Reuse it for any primary CTA via
/// [label] and the optional [icon].
class HudCtaButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final double height;
  final bool enabled;
  final VoidCallback? onPressStart;
  final VoidCallback? onPressEnd;
  final VoidCallback? onPressCancel;

  /// Primary accent for the glow, border and fill. Defaults to the Play Match
  /// cyan; pass e.g. [Cyber.violet] to recolour the button for another role.
  final Color accent;

  /// Cue played on tap. Defaults to the Play Match whoosh.
  final SoundEffect tapSound;

  /// Optional small sub-line rendered under [label] (e.g. an odds readout).
  final String? helper;

  /// Optional copy used while the pointer is held down. Hold-to-charge actions
  /// use this to tell the player exactly what releasing will do.
  final String? pressedLabel;
  final String? pressedHelper;

  /// When true (default) the button carries the pulsing neon halo. Set false
  /// for a calmer flat treatment (crisp border, no neon glow, no drop shadow)
  /// — e.g. on the hold-to-lock dock or profile-setup flow.
  final bool glow;

  /// Calm secondary action with a flat panel fill and accent-colored content.
  final bool outlined;
  final TextStyle? labelStyle;

  const HudCtaButton({
    super.key,
    this.label = 'PLAY MATCH',
    this.icon = Icons.keyboard_double_arrow_right,
    this.onTap,
    this.height = 64,
    this.accent = Cyber.cyan,
    this.tapSound = SoundEffect.playMatch,
    this.helper,
    this.pressedLabel,
    this.pressedHelper,
    this.glow = true,
    this.outlined = false,
    this.labelStyle,
    this.enabled = true,
    this.onPressStart,
    this.onPressEnd,
    this.onPressCancel,
  });

  @override
  State<HudCtaButton> createState() => _HudCtaButtonState();
}

class _HudCtaButtonState extends State<HudCtaButton>
    with SingleTickerProviderStateMixin {
  static const double _bigCut = 18;
  static const double _smallCut = 8;

  late final AnimationController _pulse;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HudCtaButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled && _pressed) {
      _pressed = false;
      widget.onPressCancel?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    // The default cyan keeps the exact original Play Match palette; any other
    // accent derives a lighter companion tone and a bright fill from it.
    final bool isCyan = accent == Cyber.cyan;
    final Color secondary = isCyan
        ? _accentBlue
        : Color.lerp(accent, Colors.white, 0.30)!;
    final Color fillTop = widget.enabled
        ? (isCyan ? _fillTop : Color.lerp(accent, Colors.white, 0.34)!)
        : Cyber.panel2;
    final Color fillBottom = widget.enabled
        ? (isCyan ? _fillBottom : accent)
        : Cyber.panel;
    final contentColor = widget.enabled
        ? (widget.outlined ? accent : _ink)
        : Cyber.muted;
    final displayLabel = _pressed
        ? widget.pressedLabel ?? widget.label
        : widget.label;
    final displayHelper = _pressed
        ? widget.pressedHelper ?? widget.helper
        : widget.helper;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: displayLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled
            ? (_) {
                setState(() => _pressed = true);
                widget.onPressStart?.call();
              }
            : null,
        onTapUp: widget.enabled
            ? (_) {
                setState(() => _pressed = false);
                widget.onPressEnd?.call();
              }
            : null,
        onTapCancel: widget.enabled
            ? () {
                setState(() => _pressed = false);
                widget.onPressCancel?.call();
              }
            : null,
        onTap: widget.enabled && widget.onTap != null
            ? () {
                HapticFeedback.mediumImpact();
                playSound(widget.tapSound);
                widget.onTap!.call();
              }
            : null,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            // Idle pulse (0..1); fully lit while pressed for clear feedback.
            // With glow off the halo is dropped (a faint press tick only) and
            // the border stays crisp.
            final glow = widget.enabled && widget.glow
                ? (_pressed ? 1.0 : 0.25 + 0.45 * _pulse.value)
                : (_pressed ? 0.3 : 0.0);
            return Opacity(
              opacity: widget.enabled ? 1 : 0.58,
              child: Container(
                height: widget.height,
                width: double.infinity,
                decoration: BoxDecoration(
                  // Glow rule: halo only when [glow] is on. Flat otherwise —
                  // crisp border only, no drop shadow.
                  boxShadow: widget.enabled && widget.glow
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.18 + 0.22 * glow),
                            blurRadius: 24 + 16 * glow,
                            spreadRadius: 1,
                          ),
                          BoxShadow(
                            color: secondary.withValues(
                              alpha: 0.12 + 0.18 * glow,
                            ),
                            blurRadius: 40 + 22 * glow,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: CustomPaint(
                  foregroundPainter: _HudBorderPainter(
                    glow: glow,
                    bigCut: _bigCut,
                    smallCut: _smallCut,
                    glowColor: widget.enabled ? accent : Cyber.line,
                    borderColor: widget.enabled ? secondary : Cyber.line,
                  ),
                  child: ClipPath(
                    clipper: const _HudButtonClipper(
                      bigCut: _bigCut,
                      smallCut: _smallCut,
                    ),
                    child: Stack(
                      children: [
                        // Bright interior with a subtle top-lit fade.
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: widget.outlined ? Cyber.panel : null,
                              gradient: widget.outlined
                                  ? null
                                  : LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [fillTop, fillBottom],
                                    ),
                            ),
                          ),
                        ),
                        // Chevron compartment | divider | label.
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Row(
                            children: [
                              Icon(
                                widget.icon,
                                color: contentColor,
                                size: 26,
                                shadows: [
                                  Shadow(
                                    color: Colors.white.withValues(alpha: 0.30),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Container(
                                width: 1.4,
                                height: widget.height * 0.42,
                                color: contentColor.withValues(alpha: 0.30),
                              ),
                              Expanded(
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          displayLabel,
                                          maxLines: 1,
                                          textAlign: TextAlign.center,
                                          style:
                                              (widget.labelStyle ??
                                                      DefaultTextStyle.of(
                                                        context,
                                                      ).style)
                                                  .copyWith(
                                                    color: contentColor,
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 3,
                                                    shadows: [
                                                      Shadow(
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.30,
                                                            ),
                                                        blurRadius: 4,
                                                      ),
                                                    ],
                                                  ),
                                        ),
                                      ),
                                      if (displayHelper != null) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          displayHelper,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: contentColor.withValues(
                                              alpha: 0.72,
                                            ),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              // Balances the left chevron compartment so the
                              // label reads optically centred.
                              const SizedBox(width: 40),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
```

---

## Appendix D — stand-ins

> **Porting the play screen too?** Use App. C of
> [`quiz-play-screen.md`](quiz-play-screen.md) instead of this appendix. It is a superset
> — the same names plus XP, audio scenes and the full sound palette — without the
> placeholder play screen below. Don't keep both.

The five subsystems the screens touch that don't travel — the design tokens, sound,
secure storage, the coin economy, page chrome, the leaderboard, and the play screen —
replaced by the smallest code that keeps every verbatim call site in §3–§11 and
App. A–C compiling **unedited**.

The whole port — this appendix, App. A, B and C, and §3–§11 — is one library with
these imports:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
```

```dart
// ─── Appendix D stand-ins ─────────────────────────────────────────────────
// Everything below replaces a subsystem of the source app. Each keeps the
// exact name and call shape the verbatim screen code uses, so §3–§11 compile
// unedited on top of it.

/// The five sports. `_sportIcon`, `QuizModeX.blurbFor` and `QuizModeX.iconFor`
/// switch exhaustively over this — adding a sport is a compile error until
/// every one of them handles it, which is the point.
enum Sport { football, cricket, motorsport, basketball, tennis }

/// D.1 — Design tokens. Every alias resolved to the source app's literal.
abstract final class Cyber {
  // Surfaces
  static const bg = Color(0xFF0D111A);
  static const panel = Color(0xFF1D293D);
  static const panel2 = Color(0xFF0F172B);

  // Lines and muted text
  static const border = Color(0xFF314158);
  static const line = Color(0xFF45556C);
  static const muted = Color(0xFF90A1B9);

  // Accents
  static const cyan = Color(0xFF5CDFFF); // primary
  static const lime = Color(0xFF51FF94); // EASY
  static const amber = Color(0xFFFF8904); // MEDIUM, entry cost
  static const danger = Color(0xFFFF4D4D); // HARD, can't afford
  static const violet = Color(0xFFC27AFF); // GLOBAL, leaderboard
  static const gold = Color(0xFFFDC700); // stars, XP, coins — rewards only
  static const success = Color(0xFF05DF72); // cleared, ladder complete

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

/// The two `AppTheme` members the verbatim code still names — the set screen's
/// spinner and `CyberPlainBackground`. A shim means neither needs editing.
abstract final class AppTheme {
  static const textPrimary = Cyber.cyan;
  static LinearGradient get backgroundGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF010916), Color(0xFF0E2646)],
  );
}

/// D.2 — Sound. Wire to your audio layer; the no-op keeps every call site.
enum SoundEffect { uiTap, coinSpend, playMatch }

void playSound(SoundEffect effect) {}

/// D.3 — Persistence. The source app uses flutter_secure_storage; this keeps
/// its exact contract (JSON per sport, corrupt data → fresh progress) in memory.
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

/// D.4 — The wallet. Stands in for the app's `GameBloc`, keeping only coins.
///
/// **Keep the silent refusal.** A spend that would take the balance below zero
/// emits nothing and reports nothing — exactly like the source
/// `_nextCoinSnapshot` returning null. `_startSet`'s second affordability check
/// exists *because* of this; without it an underfunded confirm would still
/// push the play screen.
enum OzCoinTransactionSource { quizEntry, manual }

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

class GameState {
  const GameState({this.coins = 0});
  final int coins;
}

class GameBloc extends Bloc<GameEvent, GameState> {
  GameBloc({int coins = 0}) : super(GameState(coins: coins)) {
    on<CoinsAdded>(
      (event, emit) => emit(GameState(coins: state.coins + event.amount)),
    );
    on<CoinsSpent>((event, emit) {
      final next = state.coins - event.amount;
      if (next < 0) return; // silent refusal — see the class comment
      emit(GameState(coins: next));
    });
  }
}

/// D.5 — Page chrome. Same slots as the app's `GameScaffold`: a `/`-prefixed
/// uppercase title over a muted subtitle, a 42px leading slot, a right slot.
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

/// D.6 — Leaderboard entry point. The real button pushes the leaderboard
/// filtered to this game's board. Persistent chrome: flat plate, never glows.
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

/// D.7 — The play screen, by contract only. The real one runs 10 questions,
/// reveals verdicts and pays XP; the ladder needs just two things from it:
/// it must call [QuizCubit.recordResult] before popping, and it must pop.
/// This placeholder does both so the ladder loop is testable end to end.
class QuizPlayScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GameScaffold(
      title: '${sport.name.toUpperCase()} QUIZ',
      subtitle: '${mode.label} SET $setNumber',
      child: Center(
        child: TextButton(
          onPressed: () async {
            await context.read<QuizCubit>().recordResult(
              sport,
              mode,
              setNumber: setNumber,
              correct: kQuizQuestionsPerSet,
              total: kQuizQuestionsPerSet,
            );
            if (context.mounted) Navigator.of(context).maybePop();
          },
          child: Text('RECORD A 10/10 RUN', style: Cyber.label(12)),
        ),
      ),
    );
  }
}
```

Notes per stand-in:

- **D.1 `Cyber` / `AppTheme`.** Only the tokens this port uses, with every alias
  resolved to the source literal. `Cyber.display` deliberately takes no
  `fontFeatures` — which is why the screens apply tabular figures with
  `.copyWith(...)` on display text. Keep the signature.
- **D.3 storage.** In-memory, so progress resets on restart. Swap the map for
  `flutter_secure_storage` or `shared_preferences`; keep the `try`/`catch` that turns
  corrupt JSON into fresh progress rather than a crash.
- **D.4 wallet.** The source `GameBloc` also persists the balance and writes a coin
  ledger entry per transaction — that's what `title` and `subtitle` on `CoinsSpent`
  are for. The stand-in keeps the fields so the call site is unchanged.
- **D.5 scaffold.** Visual approximation of the app's header — gradient bar,
  `/`-prefixed title, 2px bottom rule. The real one sits over a textured grid
  background (`CyberBackground`), omitted here as it's large and purely atmospheric.
- **D.7 play screen.** A placeholder that records a flawless run and pops, so the
  full loop — entry, charge, record, return beat — runs end to end before you've
  built the real one.
