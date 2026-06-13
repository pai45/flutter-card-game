# Prediction Gamification

Prediction Gamification is the retention layer on top of [Prediction Matches](prediction-matches.md). It turns the existing predict-and-claim loop into a compounding game: consecutive correct answers build a streak, settlements play out as a cinematic reveal, accuracy unlocks achievements, and daily quests give users a reason to open the Matches tab every day.

The settlement reveal and prediction XP are **built**; streaks, achievements, and daily quests remain designed-only. Predictions reward **XP only — coins are never involved anywhere in this system**. See Current Product Notes at the end for build status and dependencies.

## Product Purpose

Before this layer, the prediction loop ended at submission. The user answered an animated quiz, saw a celebration, and later claimed a flat reward in one step. The moment the user learns they were _right_ — the emotional payoff of the whole feature — was the least gamified part of the flow, and nothing carries from one prediction to the next.

This design fixes both problems:

- **Carry-over**: an accuracy streak and achievement progress make every prediction raise the stakes of the next one.
- **Payoff**: settlement becomes the highlight of the loop — a staged reveal with rising rewards, streak tension, and crowd comparison.
- **Daily pull**: quests and visible streak state give the user a concrete reason to return before each match day.

## Where It Lives

All surfaces live inside the existing Predictions area:

- **Matches tab header**: daily quest chips and the user's current streak flame.
- **Match prediction quiz**: streak flame in the quiz header, crowd-vote feedback after answering, reactive reward pills.
- **Settlement reveal**: replaces the current settle-and-claim step on finished, settleable matches.
- **Streak Calendar screen**: extended to show accuracy-streak history and the badge wall entry point.
- **Badge wall**: a new section reachable from the Streak Calendar (and later from Profile).

## Accuracy Streak

The accuracy streak is the core retention mechanic.

**Definition**

- The streak counts **consecutive correct answers across settled quiz questions**. It carries across matches and across days.
- A wrong settled answer resets the streak to 0.
- Matches the user did not predict do not affect the streak. Skipping a day never breaks it — only being wrong does.
- Within a single settlement, questions resolve in quiz order, so a quiz with a wrong answer in the middle banks the streak built before it, then resets.

**Tiers**

| Tier    | Streak | Settlement multiplier | Flame         |
| ------- | ------ | --------------------- | ------------- |
| Warm    | 3+     | 1.1x                  | cyan          |
| Hot     | 5+     | 1.25x                 | gold          |
| Blazing | 10+    | 1.5x                  | red           |
| Inferno | 20+    | 2x                    | red, animated |

- The multiplier applies to the XP of each correct answer at the streak level it lands on (see Reward Stacking Rules).
- The flame badge with the current streak count appears on the Matches tab header, the quiz header while answering, and on fixture cards the user has predicted.

**Tension**

- During the settlement reveal, the copy before each unrevealed answer reflects the live stakes: a user on a 9-streak sees "1 away from BLAZING" and, when a wrong answer is next, the streak-broken beat plays before the reset.
- A streak reset is framed as a restart, not a failure: "Streak ended at 12 — your best yet. Start a new run."
- The Streak Calendar screen records the user's best streak and marks the days streak answers settled, reusing the existing big-number animation for the current streak.

## Settlement Reveal Experience (built)

Settling a finished match is a staged cinematic instead of a single claim action. A finished, settleable prediction docks a focal **REVEAL RESULTS** button on its review screen; tapping it credits the earned XP and plays the reveal. It uses the same reveal language as the quiz itself (staged entrances) and the multi-beat result pattern from the Pitch Duel round result screen.

The beats, in order:

1. **Header beat** — "RESULTS ARE IN", fixture recap with final score, and a running XP ticker.
2. **Verdict flips** — each question row stamps in one at a time as correct (green) or wrong (red), showing the user's pick and, when wrong, the right answer. Correct stamps tick the XP counter upward; a correct answer carrying a booster shows its boosted amount in gold and plays the gold rarity sting instead of the standard reveal cue.
3. **Summary beat** — total XP count-up, correct count, "You beat N% of predictors" computed from the match leaderboard, and a level progress bar filling from the pre-settlement position. A perfect quiz swaps the title for **PERFECT QUIZ** in gold with a ray burst and the platinum sting.
4. **Level-up moment** — when the credited XP crosses a level, the standard level-up celebration plays after CONTINUE.

Tapping during the flips skips straight to the summary. Rewards are identical whether or not the user watches the full sequence — XP is credited before the cinematic starts.

Planned additions (with the streak and achievement systems): a **streak beat** where the flame increments live with each correct flip, tier crossings trigger a flame burst, and a wrong flip plays the streak-broken beat with the restart framing above; achievement unlocks surfacing in the summary beat; and a CTA to the next predictable fixture so the loop re-enters immediately.

## Achievements

Achievements are permanent badges earned through prediction play. They live on a badge wall reached from the Streak Calendar screen.

**States**

- **Locked**: visible as a silhouette with its unlock condition, so users can see what to chase.
- **Unlocked**: earned; if it carries an XP bounty, an **UNCLAIMED** chip shows until collected.
- **Claimed**: bounty collected; the badge stays on the wall permanently.

Unlocks that happen during a settlement appear in the summary beat; unlocks elsewhere (for example Early Bird at submission time) show a toast using the level-up celebration pattern.

**Launch set**

| Badge          | Trigger                                                  | Tier     |
| -------------- | -------------------------------------------------------- | -------- |
| First Blood    | First settled correct answer                             | Bronze   |
| Early Bird     | Predict 5 matches more than 24h before kickoff           | Silver   |
| Contrarian     | Correct on a question where the crowd majority was wrong | Silver   |
| League Scholar | Settle predictions in 3 different leagues                | Silver   |
| Perfect Quiz   | All questions correct in one match                       | Gold     |
| Boost Master   | Both boosters land on correct answers in one quiz        | Gold     |
| Hot Hand       | Reach a 10-answer streak                                 | Gold     |
| Inferno        | Reach a 20-answer streak                                 | Platinum |

Tier colors map to the existing card-rarity palette so badges read consistently with the rest of the app.

## Prediction XP (built)

Prediction settlements grant XP into the same progression track used by Pitch Duel matches and packs (see [Pitch Duel Leveling System](pitch-duel-leveling.md)). Predictions never touch the coin wallet.

- Each correct answer grants its reward value as XP to progression.
- Boosters (and, once built, streak multipliers) apply to that XP.
- Wrong answers grant nothing — unlike Pitch Duel match losses, predictions never subtract XP.
- A level-up caused by a prediction settlement triggers the existing level-up celebration at the end of the settlement reveal.

## Daily Quests

Two to three rotating quests appear as progress chips on the Matches tab header, visible before the user opens any fixture.

- Quests reset on a 24-hour cycle, like the existing daily drop.
- Each quest has an XP bounty claimed from the chip when complete.
- Quest progress updates live as the user acts (submitting, placing boosters, settling).

Launch quest pool, rotated daily:

- Predict 2 matches today.
- Place both boosters in one quiz.
- Get 3 correct answers settled.
- Update a prediction before kickoff.
- Predict a match in a league you haven't predicted today.

Quests are individually completable in a single session by an engaged user; they create a checklist for the day, not a grind.

## Answer Feedback Enhancements

The quiz keeps its tap-to-answer flow. Feedback while answering gets amplified:

- **Potential-XP ticker (built)**: a running pot in the quiz header, next to the lock countdown. It counts up (gold, with a pulse) as answers lock and boosters land, toward the quiz's boosted maximum — so the five questions read as a pot being built and SUBMIT as banking it. The exact-score question only joins the pot once the user touches the score picker, not from its 0-0 default.
- **Crowd bars on lock**: after the user selects an answer, vote-percentage bars animate in for that question ("64% picked this"), using the same vote data already shown in live review mode. The user learns the crowd's lean only _after_ committing, which preserves the prediction and sets up the Contrarian achievement.
- **Haptics**: light haptic on option selection, medium on booster placement, success haptic on submit.
- **Reactive reward pill**: placing or moving a booster makes the reward pill count up or down to the new value with a pulse, instead of swapping the number statically.
- **Streak flame in header**: the current streak and tier are visible while answering, so the stakes of this quiz are explicit.

## Reward Stacking Rules

One formula governs every correct answer at settlement:

```
earned = ceil(base reward × booster factor) × streak tier multiplier, rounded up
```

- **Base reward**: the question's XP value, shown while answering.
- **Booster factor**: 2x or 1.5x if that booster sits on this question, otherwise 1x. The 1.5x booster rounds up, matching current behavior.
- **Streak tier multiplier**: the tier the streak is at _when this answer resolves_ during the reveal, so a tier crossed mid-settlement boosts the remaining answers in that quiz. (1x until the streak system is built.)
- The final amount is credited as XP only — never coins.
- Wrong answers earn nothing and reset the streak; boosters on wrong answers are simply lost, as today.

Worked example: a 30-XP question with the 2x booster, resolved while the user is on a 5-streak (Hot, 1.25x), pays `ceil(30 × 2) × 1.25 = 75` XP.

## Lifecycle Additions

The prediction lifecycle (Open → Locked → Settled, defined in [Prediction Matches](prediction-matches.md)) gains one distinction at the end:

- **Settleable** (built): the match is finished and results are known, but the user has not run the settlement reveal. The fixture card shows a gold "Results ready — tap to reveal" strip to pull the user in; once settled, the card strip shows the XP the user actually earned.
- **Settled**: the reveal has played (or been skipped) and rewards are credited. The review screen shows the final correct/wrong highlighting as today, plus the streak and XP context from that settlement.

Streak state, achievement progress, and quest progress persist locally alongside predictions, in the same storage used for prediction data.

## Current Product Notes

- **Built**: the settlement reveal cinematic (REVEAL RESULTS dock on finished settleable reviews, verdict flips, XP ticker, crowd comparison, level progress, perfect-quiz treatment, level-up moment), prediction XP crediting into progression, and the Settleable card state ("Results ready" strip). Predictions reward XP only; the coin wallet is untouched. A finished demo fixture (Man Utd vs West Ham) ships settleable so the reveal is reachable with mock data.
- **Built**: the potential-XP ticker in the quiz header (see Answer Feedback Enhancements).
- **Designed, not yet built**: accuracy streaks, achievements/badge wall, daily quests, and the remaining answer-feedback enhancements (crowd bars on lock, haptics, reactive reward pill, streak flame). The current shipped quiz behavior is documented in [Prediction Matches](prediction-matches.md).
- The design intentionally reuses shipped systems: the progression/XP track, level-up celebration, sound effects, streak calendar screen, crowd vote data, and the match leaderboard sheet. No new backend concepts are required beyond what the mock prediction repository already models.
- Crowd comparison and the Contrarian achievement depend on per-question vote data, which is currently mock-backed.
- Phase 2 candidates, deliberately not designed here: timed-answer bonuses and double-or-nothing wagers (risk mechanics), a streak-saver purchase that protects a streak from one wrong answer, a weekly quest track, and social streak comparison on the leaderboard.
