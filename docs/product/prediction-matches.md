# Prediction Matches

Prediction Matches is the fixture-based prediction experience. It is separate from the Pick marketplace: Matches asks users to answer a quiz tied to a specific sports fixture, while Pick is a market-style outcome selection surface.

## Product Purpose

Prediction Matches gives users a reason to engage with upcoming and live sports fixtures. The user studies a fixture, answers a short set of match questions, and later receives rewards when the prediction is settled.

The experience supports football and cricket fixture formats today.

## Where It Lives

Prediction Matches is the default landing tab inside the Predictions area.

The tab label is **MATCHES**. Fixture cards are grouped by league, such as EPL and IPL. League headers also act as entry points into league standings.

## Fixture States

Fixtures can appear in three product states:

- **Upcoming**: prediction is open if the match has not started.
- **Live**: prediction is locked, and the card can show live score/minute context.
- **Finished**: result context and earned reward messaging can be shown.

For football, cards use compact score display. For cricket, cards support innings-style score lines and result copy.

## Main User Flow

1. User opens the Matches tab.
2. User scans today's fixtures grouped by league.
3. User taps a predictable upcoming match without an existing prediction.
4. Match Prediction opens as a focused animated quiz flow.
5. User answers one question at a time and submits the quiz on the final question.
6. Submission shows a celebration overlay and returns the user to the match list.
7. If the user opens a match they already predicted, Match Prediction opens as a review screen instead of replaying the quiz.
8. Before kickoff, the review screen lets the user update answers until the match starts.
9. Once the match is live, the review screen becomes read-only and shows crowd vote results.
10. When the match is finished, the review screen shows vote results, correct answers, and settlement context.

## Prediction Quiz Experience

First-time predictions use a staged one-question flow. On entry, and after each forward **NEXT**, the screen plays a single large number burst for the current question number. The timing follows the Pitch Duel countdown style, but displays only the current question number instead of a 3, 2, 1 sequence.

The reveal order is:

1. Current question number burst.
2. Question panel appears.
3. Question text reveals word by word.
4. Answer controls reveal sequentially.

Each first-time match quiz has:

- a fixture header with team badges, match status, and visual team split
- a countdown or lock line showing when predictions close
- one question per page
- progress segments showing answered/current/pending questions
- previous and next navigation
- a final submit action

Question types currently include:

- **Exact score**: user chooses home and away scores.
- **Multiple choice**: user chooses one listed answer.

Multiple-choice option tiles reveal one by one. Exact-score controls reveal as one staged control after the question text.

Forward navigation is gated during reveal and until the current question is answered. A non-final **NEXT** action stays dimmed until an answer exists, then becomes the highlighted cyan CTA. **PREVIOUS** remains immediate and does not replay the number burst.

Each question can carry a reward value. The quiz shows the possible reward outside the question box while answering and shows correct count/reward after settlement.

## Quiz Multipliers

Each quiz includes two optional boosters: one **2x** multiplier and one **1.5x** multiplier. A user can place each booster on one answered question, with only one booster allowed per question.

Boosters can be moved or removed until predictions lock. Tapping an active booster removes it. Tapping a booster that is already on another question moves it to the current answered question.

The question XP display updates immediately when a booster is applied. Boosted XP is awarded only if that question is correct after settlement. The 1.5x booster rounds up fractional XP.

## Submitted Prediction Review

Matches with an existing prediction open in review mode.

For upcoming editable matches, the review screen shows helper copy that answers can be updated until the match starts. Questions appear as a dense scrollable list of collapsed rows. Each row shows the question and the user's selected answer or score. Tapping a row expands it:

- multiple-choice questions show alternate options
- exact-score questions show the score picker
- multiplier chips show which boosters are unused, active, or movable from another question
- changing an answer marks the draft dirty
- a sticky **SAVE UPDATES** action appears when there are unsaved changes

Saving updates replaces the stored prediction answers without showing the first-time submission celebration.

For live matches, review mode is read-only. Rows show the user's answer plus vote counts and percentages for each option. Exact-score questions can show a score distribution when mock vote data exists.

For finished matches, review mode stays read-only and adds result feedback. Correct answers are highlighted in green, incorrect selected answers are highlighted in red, and vote distribution remains visible.

The top-right action in Match Prediction opens a compact match leaderboard sheet. It shows rank rows for that match so users can compare prediction performance in context.

## Prediction Lifecycle

**Open**

The user has submitted answers for an upcoming match. Answers remain editable before kickoff through the submitted prediction review list.

**Locked**

The match is live or no longer predictable. The user can review answers and crowd vote results, but cannot change them.

**Settled**

The app compares stored answers against known results. Correct answers are highlighted in review, generate reward value, and the reward is credited to the user's coins.

## League And Standings Mapping

League headers in Matches give users a lightweight path from fixtures to standings. This supports the mental model that predictions happen inside league context, not as isolated cards.

Standings show team ranking context for the selected league. Team and league detail surfaces should continue to reinforce:

- who is playing
- where they sit in the competition
- what match context matters before prediction

## Rewards

Prediction settlement can credit coins. The match quiz also displays potential reward values per question and summary copy after results are known.

Current product behavior credits coins from settled predictions into the same wallet used by other app surfaces.

## Current Product Notes

- Fixtures, leagues, standings, and quizzes are currently mock-backed.
- Match-level vote breakdowns and leaderboard entries are mock-backed through the prediction repository, keyed by match and question so they can later be replaced by backend data.
- One IPL fixture is seeded as already predicted to demonstrate the predicted-card state on a fresh install.
- Some finished fixtures include settleable results so the claim flow can be demonstrated.
