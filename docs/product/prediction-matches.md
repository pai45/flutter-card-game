# Predict Tab

The **Predict** tab is the fixture-based prediction experience inside the StatOz sports hub. It replaces the older "Matches" naming in the product surface: users now enter the top-level **PREDICT / PICK / GAMES** hub and land on **PREDICT** by default.

Predict is separate from **Pick**. Predict asks users to answer a short quiz tied to a specific sports fixture and rewards accuracy with XP. Pick is the market-style outcome surface and uses Oz Coins.

## Product Purpose

Predict turns upcoming fixtures into a lightweight game loop:

1. Scan today's fixtures.
2. Open a fixture.
3. Answer a staged prediction quiz.
4. Bank a potential XP pot.
5. Return later for a cinematic settlement reveal.
6. Use the XP result to progress the player's level.

The feature supports football and cricket fixture formats today.

## Where It Lives

Predict is the first tab in the StatOz prediction hub:

- **PREDICT**: fixture quizzes and XP prediction rewards.
- **PICK**: market-style picks, stake/payout, and Oz Coin settlement.
- **GAMES**: game modes such as Pitch Duel, Shootout, and Quiz.

The Predict tab sits under the StatOz top bar and above the main app bottom navigation. The top bar shows the player context, including streak access and wallet context, but Predict itself does not spend or award coins.

## Predict Tab Layout

The Predict tab is built as a gamified fixture board:

- a HUD-styled StatOz top bar
- gliding top tabs for **PREDICT / PICK / GAMES**
- a match-day selector with previous/next controls and calendar access
- league sections such as FIFA, EPL, or IPL
- fixture cards grouped under league headers
- standings entry points from league headers
- animated card entrances when the tab first opens

Fixture cards use the shared cyber fixture-card language: notched status tag, team badges, score/result context, and a bottom strip that changes based on prediction state.

## Fixture States

Fixtures can appear in these product states:

- **Upcoming, not predicted**: quiz is open; card invites the user to predict for XP.
- **Upcoming, predicted**: answers are saved and editable until kickoff.
- **Live / locked**: prediction is read-only; live score/minute context can appear.
- **Finished, settleable**: results are known and the user has not revealed the outcome; card shows the gold "Results ready" strip.
- **Settled**: XP has been credited; card shows the earned XP result.

Football cards use compact score display. Cricket cards support innings-style score lines and result copy.

## Main User Flow

1. User opens the **Predict** tab.
2. User scans the selected match day and league-grouped fixture cards.
3. User taps an upcoming fixture without an existing prediction.
4. Match Prediction opens as a focused animated quiz flow.
5. User answers one question at a time.
6. The quiz builds a visible potential-XP pot as answers and boosters are placed.
7. User submits on the final question.
8. Submission plays a gamified confirmation moment and keeps the user in the prediction context.
9. If the user opens a predicted upcoming match, the screen opens in review/edit mode.
10. Before kickoff, the user can update answers and save changes.
11. Once the match is live, review becomes read-only and shows crowd vote context.
12. When the match is finished and settleable, the user taps **REVEAL RESULTS**.
13. The settlement cinematic reveals each answer, credits XP, and can trigger level-up celebration.

## Quiz Experience

First-time predictions use a staged, one-question-at-a-time quiz. The flow borrows the arcade timing of Pitch Duel without feeling like a form.

The reveal order is:

1. Current question number burst.
2. Question panel appears.
3. Question text reveals word by word.
4. Answer controls reveal sequentially.

Each quiz has:

- a fixture header with team badges and match context
- a countdown or lock line showing when predictions close
- one question per page
- progress segments for answered/current/pending questions
- previous and next navigation
- a final submit action
- a running potential-XP ticker
- optional multiplier boosters

Question types currently include:

- **Exact score**: user chooses home and away scores.
- **Multiple choice**: user chooses one listed answer.

Forward navigation is gated during reveal and until the current question is answered. A non-final **NEXT** action stays dimmed until an answer exists, then becomes the highlighted forward CTA. **PREVIOUS** remains available and does not replay the number burst.

## XP Pot And Boosters

Predict rewards XP only. Coins are never involved in Predict rewards.

Each quiz includes two optional boosters:

- one **2x** multiplier
- one **1.5x** multiplier

A booster can be placed on one answered question, with only one booster allowed per question. Boosters can be moved or removed until the prediction locks. Tapping an active booster removes it; tapping a booster that is already on another question moves it to the current answered question.

The potential-XP ticker updates as the user answers and places boosters. Boosted XP is awarded only if that question is correct after settlement. The 1.5x booster rounds up fractional XP.

## Submitted Prediction Review

Fixtures with an existing prediction open in review mode.

For upcoming editable matches, the review screen explains that answers can be updated until kickoff. Questions appear as a dense list of collapsed rows. Each row shows the question and the user's selected answer or score. Tapping a row expands it:

- multiple-choice questions show alternate options
- exact-score questions show the score picker
- multiplier chips show unused, active, or movable boosters
- changing an answer marks the draft dirty
- a sticky **SAVE UPDATES** action appears when there are unsaved changes

Saving updates replaces the stored prediction answers without replaying the first-time submission celebration.

For live matches, review mode is read-only. Rows show the user's answer plus vote counts and percentages for each option. Exact-score questions can show score distribution when mock vote data exists.

For finished matches, review mode stays read-only and adds result feedback. Correct answers are highlighted in green, incorrect selected answers are highlighted in red, and vote distribution remains visible.

The top-right action in Match Prediction opens a compact match leaderboard sheet so users can compare prediction performance in fixture context.

## Settlement Reveal

Finished, settleable predictions expose a focal **REVEAL RESULTS** action. Settlement is not a flat claim step; it is a cinematic payoff.

The reveal:

- shows "RESULTS ARE IN"
- recaps the fixture and final score
- flips each question verdict in quiz order
- marks correct answers green and wrong answers red
- ticks the XP total upward as correct answers resolve
- highlights booster-earned XP
- shows correct count and crowd comparison
- fills the level progress bar from the pre-settlement position
- triggers the level-up celebration if the settlement crosses a level

Tapping during the reveal can skip ahead to the summary. Rewards are credited once; watching or skipping the animation does not change the XP outcome.

## Prediction Lifecycle

**Open**

The user has submitted answers for an upcoming match. Answers remain editable before kickoff through review mode.

**Locked**

The match is live or no longer predictable. The user can review answers and crowd vote results, but cannot change them.

**Settleable**

The match is finished and results are known, but the user has not revealed the outcome. The fixture card shows a gold results-ready strip.

**Settled**

The app has compared stored answers against known results. Correct answers generated XP, the XP was credited to progression, and the review screen shows final correct/wrong highlighting.

## League And Standings Mapping

League headers in Predict give users a lightweight path from fixtures to standings. This reinforces that predictions happen inside league context, not as isolated cards.

Standings show team ranking context for the selected league. Team and league detail surfaces should continue to reinforce:

- who is playing
- where teams sit in the competition
- what match context matters before prediction

## Rewards

Predict rewards **XP only**.

- Correct answers grant their question XP value.
- Boosters multiply XP only when the boosted answer is correct.
- Wrong answers grant nothing.
- Predict never subtracts XP.
- Predict never awards Oz Coins.
- Predict never spends Oz Coins.

XP is credited into the same progression track used by Pitch Duel. If a settlement crosses a level threshold, the level-up celebration plays after the reveal.

## Relationship To Gamification

The shipped Predict flow already includes:

- staged quiz reveal
- animated submission moment
- potential-XP ticker
- boosters
- settleable result state
- settlement reveal cinematic
- XP crediting
- level progress and level-up moment
- match leaderboard sheet
- mock crowd vote context

The broader gamification layer is documented in [Prediction Gamification](prediction-gamification.md). Accuracy streaks, daily quests, and some badge-wall mechanics are still product-layer extensions around this core Predict flow.

## Current Product Notes

- Fixtures, leagues, standings, quizzes, vote breakdowns, and match leaderboard rows are currently mock-backed.
- Predict is the default landing tab in the prediction hub.
- The old user-facing "Matches" tab name has been replaced by **Predict**.
- One IPL fixture is seeded as already predicted to demonstrate the predicted-card state on a fresh install.
- One finished EPL fixture is seeded with an unsettled prediction so the settlement reveal can be demonstrated; its card shows the gold results-ready strip.
- One finished IPL fixture is seeded already settled to show the settled state.
- Demo predictions never overwrite stored predictions, so settling a demo fixture persists across relaunches.
- The one-time reward-settlement bottom sheet used for onboarding/UI feedback is a demo surface only. It can show Predict and Pick rows together, but it does not credit real Predict XP or Pick coins.
