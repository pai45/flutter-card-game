# Streaks

> **Status:** BUILT
> **Last verified:** 2026-09-14
> **Scope:** Daily activity streaks, streak shields, daily quests, mode streaks, milestones, reward claims, and calendar surfaces

## Product Purpose

Streaks turn repeated play into a visible habit loop. They reward returning to
make a prediction, place a pick, or complete supported game activity without
making a missed day erase the player's broader progression. Streak shields give
committed players a safety net they earn through the daily quest loop.

## Where It Lives

The **streak hub** (`showStreakCalendar`) is reachable from every surface that
shows streak state:

- the flame tally in the `StatOzTopBar` on MATCH/GAMES, Shop and Leaderboard
  (previously only live on the Predict home);
- the **daily quest tile** leading both Trending feeds (MATCH and GAMES);
- the streak badge on each Profile telemetry band (PREDICTS / PICKS / GAMES).

All entries route through `AppShell._openStreakHub`, so quest buttons open the
same destinations everywhere. Screens built without the shell (tests, pushed
leaderboards) fall back to the hub without quest routing. Supported activity
types are prediction, pick, Pitch Duel, Penalty Shootout, and daily Guess the
Player; these roll up into overall and category streaks.

## Player Flow

1. Complete an eligible action.
2. The action records one idempotent activity for the current local day.
3. If banked shields cover every missed day since the last streak day, they are
   spent to bridge the gap first; the run continues instead of restarting.
4. The relevant activity/category streaks continue, restart, or remain unchanged.
5. A crossed milestone becomes claimable and a celebration is queued.
6. Claim the milestone reward; its claim state persists.

## Mechanics and Rules

### Streak hub — BUILT

The hub opens on a compact hero: flame core, animated run count with BEST, a
state tag (LIVE / PENDING / AT RISK / COLD) with a one-line prompt, a seven-day
chain ending today, and one next-milestone line with its meter. Banked shields
show in the header, not the hero. Tab content carries no section headings — the
tab names already label each view. Below it
the shared flat underline tab bar (`CyberUnderlineTabs`, the same bar as the
Leaderboard MATCHES / GAMES tabs) switches between four tabs; the sliding
underline takes each tab's identity colour:

- **TODAY** (gold) — daily quests: a one-row header (pips + reset clock), one
  objective card per quest (short requirement, reward top-right, meter with its
  status stamp), and the reward vault — a single row that only grows a CLAIM
  REWARDS CTA when coins are waiting. Eligibility rules appear on the game
  chooser sheet.
- **STREAKS** (amber) — one row per mode (Predict, Pick, Games, Pitch Duel,
  Penalty Shootout) with current/best; a seven-day chain appears only for live
  runs. A one-line shield panel follows.
- **CALENDAR** (cyan) — a month grid where consecutive chain days join with a
  gold fuse, active days carry a flame, shielded days a cyan shield, plus a day
  dossier (status tag and the day's predictions, picks, and matches).
- **MILESTONES** (violet) — the **road to 365**: a vertical rail that fills
  with the current run, with claimed, claimable (pulsing), next-target (days to
  go) and locked nodes.

### Streak shields — BUILT

| Rule | Behaviour |
|---|---|
| Earn | Completing the Daily Sweep forges one shield (once per local day) |
| Bank | Up to 2 shields (`streakShieldCap`); a full bank shows SHIELDS FULL and forges nothing |
| Spend | When the player returns (app load, resume, hub minute tick) or records activity, missed days since the last chain day are bridged if the bank covers the whole gap |
| Too wide | A gap larger than the bank breaks the run as before; shields are kept, never wasted |
| Count | Shielded days keep the overall chain alive but never add to the day count or milestones |
| Scope | Shields protect only the overall streak; mode streaks are unaffected |

A bridge queues a **STREAK SAVED** moment; a forge queues a **SHIELD FORGED**
moment.

### At-risk state — BUILT

From 18:00 local time (`streakRiskHour`), a live overall streak that today's
activity has not secured is **AT RISK**. The hero switches to danger red with a
pulsing tag and a countdown to midnight (noting whether a shield will cover a
miss); the top-bar flame and home tile turn red without pulsing.

### Streak reminders — BUILT

An in-app popup (no OS notifications) warns players before a live streak breaks.
It escalates at most twice per local day:

| Reminder | When | Content |
|---|---|---|
| Nudge (amber) | First app open/resume before 18:00 with a live, unsecured run | `KEEP THE FIRE BURNING` · "Play anything today to make it N." |
| AT RISK (danger) | Open/resume from 18:00 (`streakRiskHour`) with the run still unsecured | `STREAK AT RISK` · "Xh Ym left to save your N-day run." + `SHIELD ARMED` when shields are banked |

Each shows a pulsing streak flame, the run count, the compact week chain that is
about to break, one CTA into the hub (`KEEP IT ALIVE` / `SAVE MY STREAK`), one-tap
`PLAY` / `PREDICT` / `PICK` (routed through `AppShell._routeQuest`), and `NOT NOW`.
Nothing shows when today is already secured or there is no live run. A nudge
missed before 18:00 is skipped; only the AT RISK reminder fires in the evening.

Guards: the popup only opens on the bare app shell — never during loading,
onboarding, the welcome reward, a pack reveal, over a pushed game or the hub, or
while a streak/quest/achievement moment is queued. It re-checks when the game
finishes loading, when a queued moment clears, and on app resume. The shown day
is saved to `pd_streak_reminder_v1` (`StreakReminderLog`) before the popup opens,
so a killed app cannot repeat it; a failed read counts as an empty log.

### Daily quests — BUILT

TODAY combines daily quests and one quest-reward claim button; the milestone
track lives on its own MILESTONES tab. The hero distinguishes the secured streak
day from daily quest completion.

| Quest | Requirement | Oz Coins | Extra |
|---|---|---|---|
| Kick Off | Complete one eligible game | 10 | |
| Make Your Call | Submit one new prediction OR complete two games today | 10 | |
| Back Your Play | Confirm one pick OR complete three games today | 10 | |
| Daily Sweep | Complete all three quests | 20 | +1 streak shield |

Game totals are cumulative. Eligible completions are Pitch Duel, Penalty
Shootout, and daily Guess the Player across its supported sports. Winning is
optional; quitting does not count. Predictions count after a successful fresh
submission, not edits or results. Picks count after successful confirmation;
additional purchases in a position have distinct confirmation identities.
Quest buttons open a game chooser sheet (Pitch Duel, Penalty Shootout, daily
Guess the Player), MATCH for predictions, and an available market for picks
(falling back to MATCH Trending when none is open).

The fixed daily maximum is 50 Oz Coins, configured in `DailyQuestConfig`.
Activity still extends the existing streak independently of quests. Quest
completion and reward claims do not add extra streak days or change milestone
eligibility; the Daily Sweep's only streak effect is forging a shield. There is
no new quest XP.

Days follow device-local midnight. Loading the app, resuming it, and a
minute-boundary timer on the hub refresh the displayed day. Incomplete quests
expire; earned unclaimed rewards remain available indefinitely. Late events for
an expired day and future-dated events do not advance today's quests. Completed
day records and receipts prevent replaying payouts by revisiting a local date.

### Existing streak milestones — BUILT

Activity is date-keyed. Repeating the same activity in one day does not add a
second streak day. Consecutive dates increment the streak; a gap restarts the
active run unless shields bridge it. Milestones are 7 days (250 coins), 25 days
(750 coins), 50 days (gold card), 100 days (platinum card), 250 days (gold
pack), and 365 days (elite pack). Coin and card milestones use the gold reward
accent; the two pack milestones use the violet elite accent.

## Rewards and Progression

Streak milestones pay coins, cards, or packs through the shared economy. Daily
mystery settlement also records supported game activity and, when won, credits
its XP exactly once. Shields are a streak-only protection item, not a currency,
and never appear in the coin or XP ledgers.

## Gratification and Feedback

- **Quest READY stamp:** when a quest completes while visible, its status stamp
  slams in (overshoot scale) with a haptic and confirm cue; the card border
  turns success green.
- **Reward vault:** the CLAIM REWARDS CTA glows only while coins are waiting;
  the top-bar flame shows a gold beacon dot and the home tile's border pulses
  gold until they are claimed.
- **Quest payout reveal:** ring + ray burst behind a popping Oz Coin, count-up,
  and a CONTINUE CTA (auto-dismisses after 3 s).
- **Streak moments** share one chamfered moment panel with the burst icon:
  DAILY STREAK (flame, count-up, lit week chain, progress to next drop;
  auto-dismiss/tap), MILESTONE REACHED (tier accent, CLAIM REWARD CTA, heavy
  haptic), STREAK SAVED (cyan shield, chain showing the bridged day, remaining
  bank, KEEP IT ALIVE CTA), SHIELD FORGED (shield pips, auto-dismiss/tap).
- Glow follows the design system: the hero is the one glowing panel (only when
  LIVE or AT RISK); claimable milestone nodes and the claim CTA are the only
  other glowing elements. Persistent chrome (top bar, feed tile) changes
  colour but never pulses, except the tile's claim-ready border.

Sound preferences and reduced motion are respected: reduced motion snaps every
reveal to its final frame and disables pulses and the Lottie loop.

## Visible States

Cold, pending, live, at-risk, shielded, restarted, milestone-next,
milestone-claimable, claiming, claimed, shields-full, and persisted
calendar-history states are represented.

## Persistence

`StreakSnapshot` stores history, category day keys, claimed/announced
milestones, the celebration queue, `shields`, and `shieldedDays`. Snapshots
saved before shields existed load with an empty bank.

`DailyQuestSnapshot` is versioned and persisted separately from streak history.
It stores date-keyed progress, processed source identities, earned amounts and
claim receipts. Existing installs start with empty quest progress; seeded and
historical streak activity does not grant quests. Match resets preserve quests.

Quest claims write a pending journal containing absolute wallet, ledger and
claim-state targets, then replay these targets before clearing the journal.
GameBloc serializes updates across event types and blocks subsequent mutations
until any interrupted claim recovers. Each reward has a deterministic ledger
ID and the `dailyQuestReward` source. Failed claims offer retry feedback. Earned
amounts are saved so balancing changes cannot alter outstanding rewards.

The Daily Sweep shield is saved after the quest snapshot in the same handler; an
interruption between the two writes can lose that day's shield but never
duplicates one. Settlement event identity prevents duplicate daily-mystery XP or
streak credit.

## Planned Scope and Current Limitations

- **BUILT:** The activity/category model, milestone schedule, persistence,
  calendar, claims, celebration hosts, streak shields, at-risk state, and the
  fixed three-quest daily loop.
- **PLANNED:** Cross-device quest sync, server-controlled day boundaries,
  rotating quests, and coverage of additional game modes. Local clock changes
  are not protected by a server-authoritative clock.
- **PLANNED:** Any new game-specific streak must first define its recording and
  idempotency contract; undocumented game activity must not silently affect the
  overall streak.
- **Limitation:** The at-risk flame on persistent chrome updates when game state
  changes, not on a clock tick; the hub itself refreshes every minute.

## Implementation References

- [`lib/models/streak.dart`](../../../lib/models/streak.dart) — shields, bridging, at-risk
- [`lib/models/daily_quest.dart`](../../../lib/models/daily_quest.dart)
- [`lib/blocs/game/game_bloc.dart`](../../../lib/blocs/game/game_bloc.dart) — shield apply on load/refresh, sweep forge
- [`lib/widgets/streak_widgets.dart`](../../../lib/widgets/streak_widgets.dart) — flame, badge, shield pips, week chain
- [`lib/widgets/streak_celebration_host.dart`](../../../lib/widgets/streak_celebration_host.dart)
- [`lib/widgets/cyber/cyber_widgets.dart`](../../../lib/widgets/cyber/cyber_widgets.dart) — `CyberObjectiveCard`, `CyberObjectiveAction`
- [`lib/screens/predictions/streak_calendar_screen.dart`](../../../lib/screens/predictions/streak_calendar_screen.dart)
- [`lib/screens/predictions/widgets/daily_quest_panel.dart`](../../../lib/screens/predictions/widgets/daily_quest_panel.dart)
- [`lib/screens/predictions/widgets/daily_quest_home_tile.dart`](../../../lib/screens/predictions/widgets/daily_quest_home_tile.dart)
- [`lib/widgets/stat_oz_top_bar.dart`](../../../lib/widgets/stat_oz_top_bar.dart)
- [`lib/app.dart`](../../../lib/app.dart) — `_openStreakHub` / `_routeQuest` / `_maybeShowStreakReminder`
- [`lib/models/streak_reminder.dart`](../../../lib/models/streak_reminder.dart) — reminder rules + log
- [`lib/widgets/streak_reminder_popup.dart`](../../../lib/widgets/streak_reminder_popup.dart)

## Tests

- `test/daily_quest_model_test.dart`: cumulative alternatives, daily cap,
  serialization, duplicate events, rollover, preserved rewards and date replay.
- `test/daily_quest_bloc_test.dart`: initialization, claims, wallet ordering,
  restart recovery at every journal write boundary, match-reset persistence, and
  the Daily Sweep forging exactly one persisted shield.
- `test/daily_quest_widget_test.dart`: 320px enlarged-text/reduced-motion
  layout, game chooser destinations, READY/CLAIMED stamps, shield reward pill,
  quest claims and the coin reveal.
- `test/streak_model_test.dart`: seeds, idempotency, fan-out, resets, shield
  bridging, too-wide gaps, shield cap/serialization, and the at-risk window.
- `test/streak_widget_test.dart`: badge scaling, and the hub at 393px/1.4x text
  across TODAY / STREAKS / CALENDAR / MILESTONES with the one-glowing-panel rule.
- `test/streak_reminder_test.dart`: secured/cold → none, once-per-day nudge,
  evening AT RISK escalation, skipped nudge, next-day reset, log serialization.
- `test/streak_reminder_popup_test.dart`: both reminders at 320px/1.4x text, shield
  line only when armed, CTA / PLAY / PREDICT / PICK / NOT NOW results.
- [`test/streak_bloc_test.dart`](../../../test/streak_bloc_test.dart)
- [`test/daily_mystery_cubit_test.dart`](../../../test/daily_mystery_cubit_test.dart)
