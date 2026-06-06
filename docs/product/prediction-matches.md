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
3. User taps a predictable upcoming match or a match with an existing prediction.
4. Match Prediction opens as a focused quiz flow.
5. User answers one question at a time.
6. User submits the quiz on the final question.
7. Submission shows a celebration overlay and returns the user to the match list.
8. When the match is no longer editable, the same screen becomes a read-only review.
9. If the match is finished and answers can be settled, the user can claim rewards.

## Prediction Quiz Experience

Each match quiz has:

- a fixture header with team badges, match status, and visual team split
- a countdown or lock line showing when predictions close
- one question per page
- progress segments showing answered/current/pending questions
- previous and next navigation
- a final submit action

Question types currently include:

- **Exact score**: user chooses home and away scores.
- **Multiple choice**: user chooses one listed answer.

Each question can carry a reward value. The quiz shows the possible reward while answering and shows correct count/reward after settlement.

## Prediction Lifecycle

**Open**

The user has submitted answers for an upcoming match. Answers are still treated as editable before kickoff.

**Locked**

The match is live or no longer predictable. The user can review answers, but cannot change them.

**Settled**

The app compares stored answers against known results. Correct answers generate reward value, and the reward is credited to the user's coins.

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
- One IPL fixture is seeded as already predicted to demonstrate the predicted-card state on a fresh install.
- Some finished fixtures include settleable results so the claim flow can be demonstrated.
