# Product Document Template

> **Status:** BUILT | PROTOTYPE | PLANNED | DEPRECATED
> **Last verified:** YYYY-MM-DD
> **Scope:** One sentence defining what this page owns

Use this template for every new game, product system, or design rule. Remove
instructional text when creating the real page. If built and planned behavior
coexist, keep the page's primary status above and label planned subsections
`[PLANNED]`.

## Product Purpose

Explain the player problem, fantasy, or return motivation. Frame the audience as
gamers, not administrators.

## Where It Lives

Describe the navigation path, entry requirements, and related surfaces.

## Player Flow

Use a numbered end-to-end flow from entry through the result or return loop.

## Mechanics and Rules

State the rules, limits, formulas, timing, difficulty, and relevant edge cases.
Do not copy implementation details that do not affect product behavior.

## Rewards and Progression

Document XP track, Oz Coin effects, streak activity, achievements, collection
changes, and exactly when settlement becomes final.

## Gratification and Feedback

Document motion, sound, haptics, reveals, result beats, score ticks, milestone
moments, and the next-action CTA. Reuse existing moment patterns before
proposing a new one.

## Visible States

Cover loading, ready, active, paused/locked, error, empty, result, claimed, and
review states that apply.

## Persistence

Describe what survives relaunch, what is intentionally session-only, and the
source that owns the data.

## Planned Scope and Current Limitations

- **BUILT:** Confirm shipped behavior that could otherwise be ambiguous.
- **PROTOTYPE:** Identify local, mock, seeded, or non-production integrations.
- **PLANNED:** Record approved future scope only.
- **DEPRECATED:** Link historical behavior only when migration context matters.

## Implementation References

Link the smallest useful set of screens, models, blocs/cubits, services, and
shared widgets. Relative links must resolve after the page is moved.

## Tests

List the tests that prove the rules or lifecycle claims in this page. Do not
claim verification from a test that covers only presentation.
