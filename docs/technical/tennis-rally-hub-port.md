# Tennis Rally Hub — Implementation & Porting Reference

> **Status:** `TennisRallyHub` BUILT (routed) · `TennisRallyV2Hub` PROTOTYPE (built and tested, not routed) · **Written:** 2026-09-17 · **Audience:** Flutter engineers rebuilding the Tennis Rally front end in another project
>
> **Source of truth:**
> [`lib/screens/tennis/tennis_hub.dart`](../../lib/screens/tennis/tennis_hub.dart)
> (2,510 lines, one library). It holds two hubs and every private view they
> share:
> - **Shipped:** `TennisRallyHub`, `_PreviewScreen`, `_TennisLobbyEmblem`,
>   `_TennisLobbyCourtPainter` and `_ControlBrief`.
> - **Career board (shared):** `_openTennisMatchHistory`,
>   `_TennisCareerBoard`, `_CareerNumbers`, `_TrophyCabinet`, `_MasteryRow`
>   and `_AchievementRow`.
> - **Prototype:** `TennisRallyV2Hub` and its landing, selection, training,
>   tournament and settings views.
>
> Supporting files:
> - `lib/app.dart` (starter-pack gate, route push, app-level `TennisCubit`)
> - `lib/widgets/game_scaffold.dart` (`ReactHeaderBar`)
> - `lib/widgets/cyber/cyber_widgets.dart` (background, lobby status bar,
>   HUD stat, entrances)
> - `lib/widgets/matchmaking/game_match_gate.dart` and
>   `game_matchmaking_config.dart`
> - `lib/models/avatar_option.dart` and `avatar_frame_option.dart`
>
> **Companion to [Tennis Rally port](tennis-rally-port.md).**
> That doc ports the engine, renderer, cubit and play layer. Its §3 lists
> `tennis_hub.dart` as not ported, and its checklist step 2 says "build your
> own hub". This doc fills that gap. **Port that doc first:** this one
> reuses its A.3 (models), A.4 (athletes), A.5/A.6 (cubit), D.3 (starter
> pack), D.4 (storage), D.6 (cyber widgets) and D.7 (`HudCtaButton`)
> unchanged. It **replaces** D.1, D.2 and D.5 with supersets.
>
> **This document is self-contained on top of that one.** Appendix A is
> copied **verbatim** from the source by script. Appendix B holds stand-ins
> for host systems the hub only reads. Appendix C is the acceptance test.
> Written on top of the main doc's files, the app analyzes clean and all
> tests pass (§11). Sibling docs:
> - [Final Over hub](final-over-hub-port.md)
> - [Hoop Duel lobby](hoop-duel-lobby-port.md)
> - [Grand Prix lobby](grand-prix-lobby-port.md)

---

## 1. What ships, and what doesn't

`tennis_hub.dart` contains **two complete hubs**. Only one is wired into the
app:

| Hub | Reached from | What the player gets |
|---|---|---|
| **`TennisRallyHub`** (BUILT) | `app.dart` `_pushTennisRally` → `MaterialPageRoute(TennisRallyHub(onExit: navigator.pop))` | A **single match lobby** (`_PreviewScreen`): PLAY MATCH (a Quick Match against a random rival through matchmaking) or RESUME MATCH, plus Deck Builder, Match History and a controls brief. There is no mode, athlete or difficulty picker |
| **`TennisRallyV2Hub`** (PROTOTYPE) | Nothing in `lib/`. Only `test/tennis_widget_test.dart` mounts it ("hidden V2 hub") | A landing page with the Quick Match hero, a resume card and four mode cards, then player select, preview, the training lab, the tournament bracket and settings |

Both hubs share the lobby view, the career board, the engine and the cubit.
The engine and cubit fully support all five modes (port doc §1). Only the
shipped hub's UI is limited to Quick Match.

**Entry** (shipped):

- **Sports → Games → Tennis → Tennis Rally**, or the Trending hero tile
  ([arcade tiles doc](arcade-trending-hero-tiles.md)), calls
  `_openTennisRally()`.
- That runs `_enterTennisGameFlow`. On first entry
  (`tennisStarterPackClaimed == false`), it dispatches
  `TennisStarterPackOpened`. **`GameBloc` grants the starter athlete card**
  into the active deck slot, and the hub is pushed after the reveal.
- `TennisCubit(SecureGameStorage())..load()` is provided **app-wide** (in
  `lib/app.dart`), and an app-level `BlocListener` feeds its changes into
  achievement sync.

## 2. The shipped hub (`TennisRallyHub`)

### 2.1 Lifecycle

```
initState ─ post-frame ─▶ cubit.syncFromDeck(deck.deckTennisPlayers ids, deck.deckTennisStarter?.id)
build (BlocBuilder<TennisCubit, TennisState>, no buildWhen)
 ├ state.loading                                   → Scaffold(bg) + CircularProgressIndicator(cyan)   (no app bar)
 ├ !profile.starterPackClaimed || ownedPlayerIds.isEmpty
 │                                                 → the same spinner (waits for syncFromDeck; §9.2)
 └ otherwise: _preparePreviewOnce(state)           ← side effect in build
              → _PreviewScreen(state, onBack: widget.onExit,
                               onStart: state.canResume ? _resume : _launch)
```

- **`syncFromDeck`** (port doc A.6) mirrors the **card deck** into the
  tennis profile. The deck is the source of truth, and the profile is a
  cache. The sync:
  - keeps only ids that exist in `tennisPlayers` (= `tennisTop100`)
  - selects the deck starter, or else the first owned card
  - marks the starter pack claimed
  - rolls a random rival and persists
  - returns early (no emit) when nothing changed, **or when the deck has no
    valid tennis card**
- **`_preparePreviewOnce`** runs unless the state is still loading or
  unclaimed, the phase is already `preview` or `match`, or a prepare is
  already pending. It schedules `cubit.prepareQuickMatchPreview()` after the
  frame. That call:
  - makes sure the selected athlete is owned
  - **re-rolls the rival** and persists the profile
  - sets `selectedMode = quickMatch` and `phase = preview`
  - clears `config`, `summary` and `reward`

### 2.2 Actions

| Trigger | Code path | Result |
|---|---|---|
| PLAY MATCH (no snapshot) | `HapticFeedback.mediumImpact()` → `_launch()` | 1. `prepareQuickMatchPreview()` re-rolls the rival: "a random rival each queue entry", and there is no opponent picker. 2. `buildMatch(mode: quickMatch)` builds a `TennisMatchConfig` (new `matchId` and seed; the player's athlete, rival and difficulty) and sets phase → `match`. 3. `_pushMatchmakingThenMatch(config)` (below) |
| RESUME MATCH (snapshot saved) | `HapticFeedback.mediumImpact()` → `_resume()` | `resumeMatch()` returns the snapshot's config and sets phase → `match`. Then `_pushMatch(config)` plays `playMatch` and pushes the match screen **directly**, with no matchmaking. C.1 restores the rally from the snapshot when the `matchId` matches |
| Matchmaking | `_pushMatchmakingThenMatch` | Plays `playMatch`. Pushes `GameMatchGate(goLabel: 'PLAY!')` with `GameMatchmakingConfig(title: 'TENNIS RALLY', queueLabel: 'SCANNING GLOBAL TENNIS QUEUE')`. **Player:** athlete name, `avatarForName(name)` portrait, the equipped avatar frame, badge `LV <tennis level>`. **Opponent:** rival name and portrait, badge **the same** `LV <tennis level>` |
| Gate `onReady` | `pushReplacement` → `BlocProvider.value(cubit) → TennisMatchScreen(config, …)` | The gate route is replaced by the match. `onExit`, `onRestart` and `onContinueTournament` **all** pop and call `prepareQuickMatchPreview()` (§9.4) |
| Gate `onCancel` | `navigator.pop()` | Back to the lobby. The cubit stays in `match` with the built config (§9.5) |
| DECK BUILDER | `TennisDeckBuilderScreen(onBack: pop, onSaved: pop)` | Edit tennis cards and the starter. The lobby re-syncs only on its **next** mount (`syncFromDeck` runs once in `initState`) |
| MATCH HISTORY | `_openTennisMatchHistory(context, state)` | `showGameMatchHistory(gameLabel: 'Tennis Rally', history: matchHistory.where(isTennis), career: _TennisCareerBoard(profile))` (§4) |
| Back | `widget.onExit` | The host pops the route |

### 2.3 The lobby view (`_PreviewScreen`)

Layout facts:

- **Scaffold:** `ReactHeaderBar(title: 'Tennis Rally' (shown upper-cased),
  subtitle: '// MATCH LOBBY', onBack)`. There is **no right slot**: no level
  badge and no leaderboard.
- **Body:** `CyberBackground(animated: !settings.reducedMotion)` stacking
  `_TennisLobbyCourtPainter` (inside `IgnorePointer`) and the content.
- **Content column:** max width **380**, padding 24 / 22 / 24 / 32,
  vertically centered with `minHeight` = viewport.

Top to bottom:

| # | Element | Content | Entrance |
|---|---|---|---|
| 1 | Status bar | `CyberLobbyStatusBar(systemLabel: 'SYS://TENNIS_RALLY v1.0.0', lineColor: lime)`: a green glowing dot, `ONLINE`, a lime@.16 rule, and the system label (scale-down, so it never overflows) | rise-in 0 ms / 30 px |
| 2 | Hero row | `_TennisLobbyEmblem(92)`, 16 px gap. `TENNIS RALLY` (display 24, spacing 1.4, `FittedBox`), `FAST COURT SHOWDOWN` (display 9, muted, spacing 2.2), and a chip: `MATCH SAVED` (amber) when a snapshot exists, else `ATHLETE READY` (lime) | rise-in 80 ms / 24 px |
| 3 | Stat trio | Three `CyberHudStat` cells, 8 px apart, each a `CyberDealtCard` (start 180 + 75 × index ms, 540 ms, 130 px fly). **MASTERY:** `LV <masteryLevel(selected)>` (lime border). **SET WINS:** `setsWon`. **STREAK:** `currentWinStreak` (success border when > 0, else cyan) | dealt |
| 4 | Primary CTA | `HudCtaButton(sports_tennis, accent: lime)`. `RESUME MATCH` or `PLAY MATCH`; helper `<DIFFICULTY> // SEEDED FAIR PLAY` | rise-in 390 ms / 22 px |
| 5 | Secondary row | `CyberCtaButton(clip: false)`: `DECK BUILDER` and `MATCH HISTORY`, 12 px apart. Each is dealt (start 470 + 85 × index ms, 500 ms, 95 px fly) | dealt |
| 6 | Controls brief | `_ControlBrief` in a lime `CyberPanel`: a cyan move icon with `DRAG TO MOVE // QUICK FLICK TO SPRINT`, and a lime swipe icon with `TAP, HOLD OR SWIPE TO SHAPE THE SHOT` (display 8, muted) | rise-in 590 ms / 14 px |

Vertical gaps: 18 · 20 · 24 · 14 · 14.

**Stable keys:**

- `tennis-lobby-stat-mastery`, `-stat-wins`, `-stat-streak`
- `tennis-lobby-action-deck`, `-action-history`

**`_TennisLobbyEmblem`** is a 92 px square inside `CyberPulse(2600 ms,
reverse)`. It has no glow. Its layers:

- a `ChamferedActionSurface(HudChamferClipper(16, 5))` with a
  `lime@(.32 + .12·pulse)` border
- a `bg@.66` fill
- a tennis icon at 0.58 × size in lime
- a 5 px `cyan@.72` tick 13 px from the top-right corner
- `TR//01` (display 6.5, muted) 11 px from the bottom-left corner

**`_TennisLobbyCourtPainter`** draws a faint perspective court behind the
content:

- a trapezoid through (.25,.34), (.75,.34), (1.08,1) and (−.08,1), filled
  `lime@.025` and outlined in 1 px `lime@.09`
- a centre line at x = .5
- service lines at y = .53 (x .2 → .8) and y = .72 (x .11 → .89)

## 3. The prototype hub (`TennisRallyV2Hub`)

View state is a private `_TennisHubView` enum held in `setState`: `landing`,
`selection`, `preview`, `training`, `tournament` and `settings`. **Views are
not routes.** A loading state shows the bare spinner.

| View | Contents | Moves to |
|---|---|---|
| **landing** | `ReactHeaderBar('Tennis Rally', '// COURT ONLINE')`, with a lime `GameLeaderboardButton` on the right. `CyberBackground` (animated unless reduced motion), max width 760. **Row 1:** `_LandingSystemBar` (8 px lime dot, `COURT ONLINE // <ATHLETE>`, settings `tune` button with tooltip `Tennis settings`). **Row 2:** `_TennisHero`: 254 px chamfered card (22/8) over `_HeroCourtPainter`, `FEATURED // 2D ARCADE`, `TENNIS` / `RALLY` (display 34 white / 38 lime), `READ THE BOUNCE. OWN THE LINE.`, and a lime `QUICK MATCH` CTA (helper `FULL SET // PRO DEFAULT`). **Row 3:** `_ResumeCard` (amber `MATCH SUSPENDED`, `<MODE> // <RIVAL>`, `RESUME`), when a snapshot exists. **Row 4:** `PLAY MODES`, a two-column `Wrap` of `_ModeCard`s (below). **Row 5:** `_MatchHistoryStrip` (`<setsWon> WINS // <rate>% RATE // CAREER + RECENT SETS`). **Row 6:** `_MasteryStrip` (selected athlete, `LV n`, progress bar, next-cosmetic line) | QUICK MATCH / a mode card → `_openMode`. RESUME → `_resume`. Settings → `settings` |
| **selection** | `PLAYER SELECT // <MODE>`. A two-column `Wrap` of `_AthleteCard`s for **every** `tennisPlayers` entry: monogram, check or lock, name, archetype, then `OVR n` or an unlock label. Locked cards are at 54 % opacity and inert. Then `_AthleteDetail` (signature, `LV`, eight rating chips SPD/PWR/CTL/SRV/STA/VOL/SPN/RCH), a `DIFFICULTY` picker (cyan fill@.2 and border when selected), and a CTA: `FIND RIVAL` (`RANDOM QUEUE // <DIFF>`) for quick match and tournament, or `SESSION PREVIEW` (`<ATHLETE> // <DIFF>`) | CTA → `showPreview()` → `preview`. Back → `landing` |
| **preview** | The same `_PreviewScreen` as §2.3 | START → `_launch()`. Back → `selection` |
| **training** | `TRAINING LAB // 8 LESSONS`: athlete panel with `n/8 COMPLETE` and `CHANGE`, then eight `_LessonCard`s (number or check; `START` or `REPLAY`) | START → `_launch(mode: training, trainingLesson: n)`, pushed **without** matchmaking. CHANGE → `selection` (training) |
| **tournament** | `STAToz OPEN // 8 PLAYER BRACKET` (shown upper-cased as `STATOZ OPEN`). `_TournamentHeader`: a **glowing** gold panel, `THREE WINS TO THE TROPHY` or `TITLE SECURED`, `<ATHLETE> // <DIFF>`, `W/3`. `_Bracket`: QUARTERFINAL / SEMIFINAL / FINAL rows (result `W`/`L`, `NEXT`, `--`), plus a `FIELD OF 8` chip list. CTA: `PLAY <ROUND>` (gold, `<DIFF> // WIN TO ADVANCE`) or `CREATE NEW DRAW` | PLAY → `_launch(mode: tournament)`. NEW DRAW → `prepareTournament()` |
| **settings** | `TENNIS SETTINGS // CONTROLS & ACCESS`. Seven `SwitchListTile`s: left-handed, movement assist, reduced motion, strong flashes, haptics, music, sound. Two sliders: control size 0.8–1.25 and opacity 0.45–1. All in one `CyberPanel` | Every change → `cubit.updateSettings(...)` (persisted) |

**Mode cards:**

| Card | Accent | Subtitle |
|---|---|---|
| TOURNAMENT | gold | `8 PLAYERS / 3 ROUNDS` |
| TRAINING | cyan | `8 SKILL LESSONS` |
| ENDLESS RALLY | lime | `FIRST MISS ENDS IT` |
| TARGET PRACTICE | amber | `20 BALLS / 90 SEC` |

**`_openMode(mode)`**:

1. `playSound(uiTap)`.
2. `selectMode(mode)` (phase → `selection`).
3. Switch the view: training → `training`, tournament → `tournament`,
   otherwise `selection`.
4. For a tournament, also call `prepareTournament()`, which creates a draw
   only if none is active.

**`_launch({mode, trainingLesson})`** re-rolls the rival for Quick Match,
then calls `buildMatch`. Training is pushed directly; every other mode goes
through the same matchmaking gate as §2.2.

**V2 match callbacks:**

| Callback | Effect |
|---|---|
| exit | `returnToHub()` → `landing` |
| restart | Pop, then on the next frame `_launch` the **same mode and lesson** again |
| next round | `returnToHub()` → `tournament` |

The eight lessons (`_lessons`) are MOVEMENT, TIMING, DIRECTION, POWER SHOT,
LOB, SERVING, STAMINA and SCORING. The engine's goals for each are in the
port doc, §5.7.

## 4. Career board (shared, shown in Match History)

`_TennisCareerBoard(profile)` is passed as the `career` slot. Top to bottom:

1. `CAREER`, then `_CareerNumbers`: a cyan panel with **SETS**
   (`setsPlayed`), **WINS** (`setsWon`), **ACES** (`totalAces`) and
   **RALLY** (`longestRally`). Values are display 19 in cyan.
2. `_TrophyCabinet`: a gold panel with one trophy per difficulty (gold once
   won, border colour otherwise), the difficulty label and `x<count>` from
   `profile.trophies[difficulty.name]`.
3. `ATHLETE MASTERY`, then **one `_MasteryRow` per `tennisPlayers` entry**:
   monogram, name, a 5 px progress bar and `LV n`. This is **100 rows** with
   the current roster (§9.7).
4. `ACHIEVEMENTS`, then ten `_AchievementRow`s. Unlocked rows have a lime
   border and a `military_tech` icon; locked rows are at 55 % opacity with a
   lock icon:

   | Id | Name | Condition |
   |---|---|---|
   | clean-hold | CLEAN HOLD | Win a service game without losing a point |
   | break-through | BREAK THROUGH | Convert a break point |
   | unbreakable | UNBREAKABLE | Save three break points in one match |
   | ace-high | ACE HIGH | Hit five aces across completed sets |
   | rally-architect | RALLY ARCHITECT | Complete a 20-shot rally |
   | net-authority | NET AUTHORITY | Win ten net points with a serve-and-volley athlete |
   | comeback-set | COMEBACK SET | Win after trailing by three games |
   | tiebreak-nerve | TIEBREAK NERVE | Win after saving set point in a tiebreak |
   | all-styles | ALL STYLES | Win with every base archetype |
   | champion | CHAMPION | Win the eight-player tournament |

5. `RECENT MATCHES`. The history page lists the entries below this label.

**Mastery** (port doc A.3) uses `masteryXp[playerId]`. Level *n* costs
*n* × 100 XP to clear, and the level caps at 10. `masteryProgress` is the
fraction into the current level.

## 5. Gratification and feedback

| Moment | Feedback |
|---|---|
| Arrive (lobby) | Status bar and hero rise in. The stat trio is dealt from 180 ms. The CTA rises at 390 ms, the buttons are dealt from 470 ms, and the brief rises at 590 ms. The emblem border breathes (2.6 s). The CTA halo pulses. The cyber background drifts (unless reduced motion) |
| PLAY MATCH | Halo to full on press-down. Tap: **two** medium haptics and **two** `playMatch` cues (§9.1). Then the shared matchmaking cinematic: a queue search with the `SCANNING GLOBAL TENNIS QUEUE` telemetry, both portraits with `LV` badges, a lock-on, then the kickoff countdown ending on the `PLAY!` stamp. Then the match |
| RESUME MATCH | The same double haptic and double cue. Straight into the match, restored mid-rally |
| Back from a match | The lobby is re-prepared with a fresh rival. The stat trio shows the new mastery level, set wins and streak |
| Match History | The career board reads as a trophy room: numbers, the trophy cabinet, mastery bars and achievements |
| V2 extras | `uiTap` on mode cards. Selection haptic on athlete and difficulty picks. The glowing tournament header. Bracket rows turn lime or red as results come in |

The big payoffs belong to the match screen (port doc §8, C.1): stings, the
ACE and WINNER camera push, the tiebreak and end-change banners, and the
graded result with XP, coins and mastery.

## 6. Design rules carried by this code

- **Accent.** Tennis is **lime** (CTA, emblem, court lines, status rule,
  ATHLETE READY). Amber marks a suspended match, gold the trophies and
  tournament, and cyan the numbers and secondary chrome.
- **Glow.**
  - In the shipped lobby, only the status dot and the CTA halo glow. The
    emblem pulses its **border**, not a glow.
  - V2 breaks the rule once: `_TournamentHeader` is a `CyberPanel(glow:
    true)`.
- **Shape.** The emblem and V2 hero use the 16/5 and 22/8 chamfers.
  `CyberPanel` uses its own clipped outline, and `HudCtaButton` its plate.
  The stat cells, lesson badges and rating chips are square.
- **Type.** Everything uses `Cyber.display` / `Cyber.body` with tokens. The
  only raw hex is `_HeroCourtPainter`'s court colours (`#183341 → #07111D`
  gradient, `#12606A` court).
- **Reduced motion.** `settings.reducedMotion` switches off the
  `CyberBackground` drift in both hubs. The entrances and pulses still run.

## 7. Host touch-points (Appendix B)

| Source symbol | Stand-in | Replace with |
|---|---|---|
| `Cyber.blue` | B.1 (**replaces** port doc D.1 and adds the token) | Your palette |
| `AppSection` | B.2 (**replaces** port doc D.2: keeps `CardTier`, adds `AppSection`) | Your shell's destinations |
| `SoundEffect.uiTap` | B.3 (**replaces** port doc D.5) | Your UI tap cue |
| `ProgressTrack.tennis`, `PlayerProgression` | B.4 | Your XP tracks. The level goes on the matchmaking badges |
| `MatchHistoryEntry` | B.5 | Your history model (`isTennis` = `mode == 'tennis'`) |
| `Sport` | B.6 (verbatim enum) | Your sport enum |
| `GameBloc` / `GameState` / `PlayerCard` | B.7 / B.8: a `Cubit` holding `deckTennisPlayers`, `deckTennisStarter`, `progression`, `equippedAvatarFrameId` and `matchHistory` | Your progression and card store. It must grant the starter athlete **before** the hub is pushed |
| `AvatarOption`, `avatarForName` | B.9 (both verbatim; two stand-in portraits) | Your portrait catalogue |
| `AvatarFrameOption`, `avatarFrameOptionById` | B.10 (type and lookup) | Your cosmetic frames |
| `GameMatchGate` | B.11 (verbatim constructor; shows both fighters and hands over after 1.5 s) | Your matchmaking cinematic, or remove it and call `onReady` at once |
| `GameMatchmakingConfig`, `MatchmakingFighter` | A.4 (verbatim) | Keep |
| `GameLeaderboardButton`, `GameMode` | B.12 (verbatim constructor and enum) | Your leaderboard route (V2 only) |
| `showGameMatchHistory` | B.13 (verbatim signature) | Your history page, keeping the `career` slot |
| `TennisDeckBuilderScreen` | B.14 (verbatim constructor) | Your tennis deck editor |
| `TennisMatchScreen` | B.15 (same constructor; SETTLE / REMATCH / NEXT ROUND / EXIT buttons) | Port doc **C.1**, once its §9 touch-points are wired |

## 8. File map and port checklist

| Target path | Contents | Where |
|---|---|---|
| `lib/screens/tennis/tennis_hub.dart` | Both hubs and every view (verbatim, whole file) | A.1 |
| `lib/widgets/game_scaffold.dart` | `ReactHeaderBar` (verbatim subset) | A.2 |
| `lib/widgets/cyber/cyber_hub_widgets.dart` | `CyberBackground`, `CyberGridPainter`, `CyberTextureOverlay`, `HudLine`, `CyberCtaButton`, `CyberLobbyStatusBar`, `CyberHudStat`, `CyberSlideUpFadeIn`, `CyberPulse`, `CyberDealtCard` (verbatim declarations) | A.3 |
| `lib/widgets/matchmaking/game_matchmaking_config.dart` | Matchmaking identity types (verbatim, whole file) | A.4 |
| `lib/config/theme.dart` | **Stand-in**, replaces port doc D.1 | B.1 |
| `lib/config/enums.dart` | **Stand-in**, replaces port doc D.2 | B.2 |
| `lib/utils/sound_effects.dart` | **Stand-in**, replaces port doc D.5 | B.3 |
| `lib/models/progression.dart`, `match.dart`, `sport_match.dart` | **Stand-ins** | B.4–B.6 |
| `lib/blocs/game/game_bloc.dart`, `game_state.dart` | **Stand-ins** | B.7, B.8 |
| `lib/models/avatar_option.dart`, `avatar_frame_option.dart` | **Stand-ins** | B.9, B.10 |
| `lib/widgets/matchmaking/game_match_gate.dart` | **Stand-in** | B.11 |
| `lib/screens/leaderboard/widgets/game_leaderboard_button.dart` | **Stand-in** | B.12 |
| `lib/screens/match_history/match_history_pages.dart` | **Stand-in** | B.13 |
| `lib/screens/deck/tennis_deck_builder_screen.dart` | **Stand-in** | B.14 |
| `lib/screens/tennis/tennis_match_screen.dart` | **Stand-in**; overwrites the port doc's C.1 if you copied it | B.15 |
| `test/tennis_rally_hub_test.dart` | Widget tests for both hubs | C.1 |

Checklist:

1. Port [tennis-rally-port.md](tennis-rally-port.md) (A, B, D, E) and make
   its tests pass. Leave its Appendix C out for now.
2. Copy A.1–A.4, B.1–B.15 and C.1 to the listed paths. B.1, B.2 and B.3
   overwrite D.1, D.2 and D.5.
3. In the port doc's `lib/widgets/cyber/cyber_widgets.dart` (D.6), add this
   line right after its imports:
   ```dart
   export 'cyber_hub_widgets.dart';
   ```
   A.3 is a **superset** of the same-named file in the Final Over, Hoop Duel
   and Grand Prix docs. If you port several games, keep this one.
4. Provide `TennisCubit(SecureGameStorage())..load()` and your `GameBloc`
   above `MaterialApp`. Grant the starter athlete into the tennis deck, then
   push `TennisRallyHub(onExit: navigator.pop)`.
5. **Decide which hub to ship.** `TennisRallyHub` is the one in production.
   `TennisRallyV2Hub` is a drop-in replacement with the same constructor,
   and it unlocks the other four modes. Read §9.8–§9.11 first.
6. Replace B.11 and B.15 with your matchmaking and the port doc's C.1.
7. Consider the fixes in §9, then update C.1's expectations to match.
8. Run `flutter analyze` and `flutter test test/tennis_rally_hub_test.dart`.
9. On device, check at 320 px, a normal phone, and a tablet:
   - first entry (the starter grant) → lobby
   - PLAY MATCH → matchmaking → match → exit
   - pause, kill and relaunch → RESUME MATCH restores the rally
   - Deck Builder
   - Match History (scroll the career board)

## 9. Known issues and copy notes

Kept verbatim in Appendix A; fix them in your port if you like.

**Shipped hub**

1. **PLAY MATCH fires twice.** `HudCtaButton` already does a medium haptic
   and plays its default `tapSound` (`playMatch`). `_PreviewScreen`'s
   `onTap` adds another `mediumImpact()`, and `_pushMatchmakingThenMatch`
   (or `_pushMatch`) plays `playMatch` again. A haptic probe recorded **two**
   `mediumImpact` calls per tap. RESUME MATCH behaves the same.
2. **An endless spinner with no way back.**
   - Both loading branches return a bare `Scaffold` with no app bar.
   - If the active deck slot has no valid tennis card, `syncFromDeck` returns
     without emitting, so the hub spins **forever** (C.1 pins this).
   - Only a system back gesture leaves the screen. Give the spinner a
     back-enabled `ReactHeaderBar`, and route an empty deck to the Deck
     Builder.
3. **The hub re-prepares under the result screen.**
   - `_preparePreviewOnce` guards only against `preview` and `match`. After
     `settle()` the phase is `result`. The hub is still mounted beneath the
     match route and rebuilds on that emit, so it immediately calls
     `prepareQuickMatchPreview()`.
   - That clears `config`, `summary` and `reward`, **re-rolls and persists
     the rival**, and sets phase `preview`, all while the result panel is
     still on screen (C.1 pins this).
   - It is harmless today, because C.1 keeps its own summary and reward.
     But anything reading the cubit's result after settlement sees nothing.
   - Fix: also skip `result`, or only prepare when the hub route is current.
4. **REMATCH and NEXT ROUND act like EXIT.** In the shipped hub, all three
   match callbacks pop and re-prepare. The result panel's REMATCH goes back
   to the lobby instead of starting another match (C.1 pins this). The V2
   hub relaunches the same mode and lesson.
5. **Cancelling matchmaking leaves a stale phase.** The cubit stays in
   `match` with the unused config. The next PLAY MATCH rebuilds it, but in
   between the lobby is shown in phase `match`, so `_preparePreviewOnce`
   stays quiet.
6. **The rival's badge shows your level.** Both matchmaking badges read
   `LV <player tennis level>`.
7. **The career board has 100 mastery rows.** `ATHLETE MASTERY` lists every
   `tennisPlayers` entry: the whole top-100 roster, owned or not. The
   player's own RECENT MATCHES sit below all of them (C.1 has to scroll to
   reach them). Consider listing owned athletes only, or athletes with
   mastery XP.
8. **Leftovers from the old roster.** `_playerAccent` and `_unlockLabel` are
   keyed on the retired fictional roster (`jett-okafor`, `mira-chen`,
   `luca-vale`, `sora-malik`, `kaia-brooks`, `theo-laurent`, `riven-cole`).
   None of those ids exist in `tennisTop100`, so:
   - every monogram and mastery bar falls back to **cyan**
   - in V2, every locked athlete reads **`STARTER`** (C.1 counts 100)
9. **Minor:**
   - The lobby has no level badge or leaderboard; V2's landing has the
     leaderboard.
   - `_ControlBrief.mode` is unused, and the brief ignores the left-handed
     setting.
   - `SYS://TENNIS_RALLY v1.0.0` is hard-coded.
   - There is 54 px of dead scroll (`minHeight` ignores the padding).
   - `_resume` calls `resumeMatch()`, which throws if the snapshot vanished
     between build and tap.

**Prototype hub (read before routing it)**

10. **The settings view trips a framework assertion.** Each
    `SwitchListTile` sits inside a `CyberPanel`, whose `DecoratedBox` has a
    background colour. In debug builds, Flutter reports *"ListTile
    background color or ink splashes may be invisible."* on every build
    (C.1 pins this), and the switch ink is hidden. Wrap the tiles in a
    transparent `Material`.
11. **Other V2 issues:**
    - The views are `setState` values, not routes, so the system back
      gesture closes the whole hub from any view.
    - Player select renders a 100-card `Wrap` with no search or filter.
    - The QUICK MATCH hero helper says `PRO DEFAULT` even when another
      difficulty is selected.
    - The tournament header glows (§6).
    - `_MasteryStrip` promises cosmetics that nothing in `lib/` implements:
      alternate outfit (level 2), racket design (3), player frame (5),
      victory pose (7) and serve effect (10).

## 10. Acceptance test (Appendix C)

`test/tennis_rally_hub_test.dart` runs **16 widget tests**.

**Shipped hub (12):**

| Test | What it proves |
|---|---|
| spinner while loading | The spinner has no app bar |
| empty deck | The spinner is still up after 2 s, with no back arrow (§9.2) |
| adopts the deck | The profile is claimed, owns and selects `casper-ruud`, and the rival differs. Phase `preview`. The hero, ATHLETE READY, PLAY MATCH, the `PRO // SEEDED FAIR PLAY` helper, the stat labels, `LV 1` and the brief are shown. No PLAY MODES |
| PLAY MATCH → EXIT | A quick-match config for Casper at PRO, phase `match`. The gate shows the queue label and `LV 3` on **both** badges (§9.6). It hands over to the match. EXIT returns to `preview` with no config |
| cancel matchmaking | Back in the lobby, still in phase `match` with a config (§9.5) |
| settle | `setsWon` is 1, then phase `preview`, a cleared summary and a new rival while the match screen is still up (§9.3) |
| REMATCH | Lands back in the lobby in `preview`, with no gate (§9.4) |
| resume | A stored snapshot shows MATCH SAVED / RESUME MATCH, which opens the saved match with no gate |
| deck builder | Opens and closes |
| match history | Only `tennis` entries are listed. The career sections, **100** progress bars and CHAMPION are shown. The recent match is reached only after scrolling (§9.7) |
| 420 / 800 px | No layout exceptions |

**Prototype hub (4):**

| Test | What it proves |
|---|---|
| landing | Five mode labels. TRAINING opens the lab with `0/8 COMPLETE` and eight START buttons |
| tournament | An active draw, `STATOZ OPEN`, `PLAY QUARTERFINAL`, `THREE WINS TO THE TROPHY`, `0/3` |
| player select | PLAYER SELECT, SESSION PREVIEW, and **100** `STARTER` labels (§9.8) |
| settings | Left-handed persists, and every error captured is the ListTile assertion (§9.10) |

**Testing notes:**

- The tests step the clock in 50 ms frames and never call `pumpAndSettle`.
  One `runAsync` lets `syncFromDeck` and `settle` finish their storage
  writes.

## 11. Verification performed for this document

A script read **only this markdown file and the port doc**. It:

- wrote the port doc's A, B, D and E into an empty Flutter app
  (`card_game`, Flutter 3.44.4, the port doc's §4 dependencies plus
  `flutter_lints`)
- wrote this doc's A, B and C on top (B.1 over D.1, B.2 over D.2, B.3 over
  D.5)
- added the `export` line from §8 step 3

Results:

- **Verbatim check:** A.1 and A.4 are byte-identical to the source files.
  A.2 and A.3 are whole declarations cut from the source by name, under a
  new header comment. B.1 and B.2 keep D.1 and D.2 unchanged apart from the
  additions.
- **Analyze:** `flutter analyze` → **No issues found!**
- **Tests:** `flutter test` → **36 tests, all passed** (C.1's 16 plus the
  port doc's 20).
- **Probe (not shipped):** the source app's Orbitron and Onest were loaded,
  and the shipped lobby was rendered at 320–430 px with the longest roster
  name. There were no layout errors, and a platform-channel mock recorded
  two `mediumImpact` haptics per PLAY MATCH (§9.1).
- **Not checked:** the real `GameBloc` (starter grant, `TennisFinished`),
  the matchmaking cinematic, the leaderboard, the history page, the deck
  builder and the match screen (all stand-ins here), and a pixel comparison
  against the source app.

## 12. Product-doc corrections made alongside

[`games/tennis-rally.md`](../product/games/tennis-rally.md) described the
five-mode hub as the shipped entry. The page now says:

- The routed hub is the Quick Match lobby (resume, deck, history).
- The multi-mode hub is a PROTOTYPE.
- Athlete ownership comes from the card deck.
- The career board is in Match History.

---


## Appendix A — Hub files (verbatim)

Copy each block to the path in its heading.

### A.1 `lib/screens/tennis/tennis_hub.dart`

<sub>2510 lines</sub>

```dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/tennis/tennis_cubit.dart';
import '../../blocs/tennis/tennis_state.dart';
import '../../config/theme.dart';
import '../../models/avatar_frame_option.dart';
import '../../models/avatar_option.dart';
import '../../models/progression.dart';
import '../../models/sport_match.dart';
import '../../models/tennis.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import '../../widgets/matchmaking/game_match_gate.dart';
import '../../widgets/matchmaking/game_matchmaking_config.dart';
import '../deck/tennis_deck_builder_screen.dart';
import '../leaderboard/widgets/game_leaderboard_button.dart';
import '../match_history/match_history_pages.dart';
import 'tennis_match_screen.dart';

class TennisRallyHub extends StatefulWidget {
  const TennisRallyHub({required this.onExit, super.key});

  /// Returns to the Games tab that launched this standalone flow.
  final VoidCallback onExit;

  @override
  State<TennisRallyHub> createState() => _TennisRallyHubState();
}

class _TennisRallyHubState extends State<TennisRallyHub> {
  bool _preparingPreview = false;

  TennisCubit get _cubit => context.read<TennisCubit>();

  @override
  void initState() {
    super.initState();
    // The starter pack is granted by GameBloc before this hub is ever pushed
    // (see _enterTennisGameFlow in app.dart), so the deck is the source of
    // truth for which athletes the player owns.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final deck = context.read<GameBloc>().state;
      unawaited(
        _cubit.syncFromDeck(
          deck.deckTennisPlayers.map((card) => card.id).toList(),
          deck.deckTennisStarter?.id,
        ),
      );
    });
  }

  void _preparePreviewOnce(TennisState state) {
    if (_preparingPreview ||
        state.loading ||
        !state.profile.starterPackClaimed ||
        state.profile.ownedPlayerIds.isEmpty ||
        state.phase == TennisFlowPhase.preview ||
        state.phase == TennisFlowPhase.match) {
      return;
    }
    _preparingPreview = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cubit.prepareQuickMatchPreview();
      _preparingPreview = false;
    });
  }

  void _launch() {
    // Re-roll a random rival each queue entry (no opponent picker).
    _cubit.prepareQuickMatchPreview();
    final config = _cubit.buildMatch(mode: TennisMode.quickMatch);
    _pushMatchmakingThenMatch(config);
  }

  void _resume() {
    final config = _cubit.resumeMatch();
    _pushMatch(config);
  }

  void _pushMatchmakingThenMatch(TennisMatchConfig config) {
    playSound(SoundEffect.playMatch);
    final navigator = Navigator.of(context);
    final player = tennisPlayerById(config.playerId);
    final opponent = tennisPlayerById(config.opponentId);
    final game = context.read<GameBloc>().state;
    final level = game.progression.levelFor(ProgressTrack.tennis);
    final frame = avatarFrameOptionById(game.equippedAvatarFrameId);

    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => GameMatchGate(
          goLabel: 'PLAY!',
          config: GameMatchmakingConfig(
            title: 'TENNIS RALLY',
            queueLabel: 'SCANNING GLOBAL TENNIS QUEUE',
            player: MatchmakingFighter(
              name: player.name,
              avatarAsset: avatarForName(player.name).assetPath,
              frame: frame,
              badge: 'LV $level',
            ),
            opponent: MatchmakingFighter(
              name: opponent.name,
              avatarAsset: avatarForName(opponent.name).assetPath,
              badge: 'LV $level',
            ),
          ),
          onCancel: () => navigator.pop(),
          onReady: () {
            navigator.pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider.value(
                  value: _cubit,
                  child: TennisMatchScreen(
                    config: config,
                    onExit: () {
                      navigator.pop();
                      _cubit.prepareQuickMatchPreview();
                    },
                    onRestart: () {
                      navigator.pop();
                      _cubit.prepareQuickMatchPreview();
                    },
                    onContinueTournament: () {
                      navigator.pop();
                      _cubit.prepareQuickMatchPreview();
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _pushMatch(TennisMatchConfig config) {
    playSound(SoundEffect.playMatch);
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: _cubit,
          child: TennisMatchScreen(
            config: config,
            onExit: () {
              navigator.pop();
              _cubit.prepareQuickMatchPreview();
            },
            onRestart: () {
              navigator.pop();
              _cubit.prepareQuickMatchPreview();
            },
            onContinueTournament: () {
              navigator.pop();
              _cubit.prepareQuickMatchPreview();
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TennisCubit, TennisState>(
      builder: (context, state) {
        if (state.loading) {
          return const Scaffold(
            backgroundColor: Cyber.bg,
            body: Center(child: CircularProgressIndicator(color: Cyber.cyan)),
          );
        }
        if (!state.profile.starterPackClaimed ||
            state.profile.ownedPlayerIds.isEmpty) {
          // syncFromDeck lands on the frame after mount; hold the loader
          // rather than flashing an empty preview.
          return const Scaffold(
            backgroundColor: Cyber.bg,
            body: Center(child: CircularProgressIndicator(color: Cyber.cyan)),
          );
        }
        _preparePreviewOnce(state);
        return _PreviewScreen(
          state: state,
          onBack: widget.onExit,
          onStart: state.canResume ? _resume : _launch,
        );
      },
    );
  }
}

enum _TennisHubView {
  landing,
  selection,
  preview,
  training,
  tournament,
  settings,
}

class TennisRallyV2Hub extends StatefulWidget {
  const TennisRallyV2Hub({required this.onExit, super.key});

  /// Returns to the Games tab that launched this standalone flow.
  final VoidCallback onExit;

  @override
  State<TennisRallyV2Hub> createState() => _TennisRallyV2HubState();
}

class _TennisRallyV2HubState extends State<TennisRallyV2Hub> {
  _TennisHubView _view = _TennisHubView.landing;

  TennisCubit get _cubit => context.read<TennisCubit>();

  void _openMode(TennisMode mode) {
    playSound(SoundEffect.uiTap);
    _cubit.selectMode(mode);
    setState(() {
      _view = switch (mode) {
        TennisMode.training => _TennisHubView.training,
        TennisMode.tournament => _TennisHubView.tournament,
        _ => _TennisHubView.selection,
      };
    });
    if (mode == TennisMode.tournament) _cubit.prepareTournament();
  }

  void _showPreview() {
    _cubit.showPreview();
    setState(() => _view = _TennisHubView.preview);
  }

  void _launch({TennisMode? mode, int? trainingLesson}) {
    final selectedMode = mode ?? _cubit.state.selectedMode;
    if (selectedMode == TennisMode.quickMatch) {
      _cubit.prepareQuickMatchPreview();
    }
    final config = _cubit.buildMatch(
      mode: mode,
      trainingLesson: trainingLesson,
    );
    if (selectedMode == TennisMode.training) {
      _pushMatch(config);
    } else {
      _pushMatchmakingThenMatch(config);
    }
  }

  void _resume() {
    final config = _cubit.resumeMatch();
    _pushMatch(config);
  }

  void _pushMatchmakingThenMatch(TennisMatchConfig config) {
    playSound(SoundEffect.playMatch);
    final navigator = Navigator.of(context);
    final player = tennisPlayerById(config.playerId);
    final opponent = tennisPlayerById(config.opponentId);
    final game = context.read<GameBloc>().state;
    final level = game.progression.levelFor(ProgressTrack.tennis);
    final frame = avatarFrameOptionById(game.equippedAvatarFrameId);

    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => GameMatchGate(
          goLabel: 'PLAY!',
          config: GameMatchmakingConfig(
            title: 'TENNIS RALLY',
            queueLabel: 'SCANNING GLOBAL TENNIS QUEUE',
            player: MatchmakingFighter(
              name: player.name,
              avatarAsset: avatarForName(player.name).assetPath,
              frame: frame,
              badge: 'LV $level',
            ),
            opponent: MatchmakingFighter(
              name: opponent.name,
              avatarAsset: avatarForName(opponent.name).assetPath,
              badge: 'LV $level',
            ),
          ),
          onCancel: () => navigator.pop(),
          onReady: () {
            navigator.pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider.value(
                  value: _cubit,
                  child: TennisMatchScreen(
                    config: config,
                    onExit: () {
                      navigator.pop();
                      _cubit.returnToHub();
                      if (mounted) {
                        setState(() => _view = _TennisHubView.landing);
                      }
                    },
                    onRestart: () {
                      navigator.pop();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        _launch(
                          mode: config.mode,
                          trainingLesson: config.trainingLesson,
                        );
                      });
                    },
                    onContinueTournament: () {
                      navigator.pop();
                      _cubit.returnToHub();
                      if (mounted) {
                        setState(() => _view = _TennisHubView.tournament);
                      }
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _pushMatch(TennisMatchConfig config) {
    playSound(SoundEffect.playMatch);
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: _cubit,
          child: TennisMatchScreen(
            config: config,
            onExit: () {
              navigator.pop();
              _cubit.returnToHub();
              if (mounted) setState(() => _view = _TennisHubView.landing);
            },
            onRestart: () {
              navigator.pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _launch(
                  mode: config.mode,
                  trainingLesson: config.trainingLesson,
                );
              });
            },
            onContinueTournament: () {
              navigator.pop();
              _cubit.returnToHub();
              if (mounted) setState(() => _view = _TennisHubView.tournament);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TennisCubit, TennisState>(
      builder: (context, state) {
        if (state.loading) {
          return const Scaffold(
            backgroundColor: Cyber.bg,
            body: Center(child: CircularProgressIndicator(color: Cyber.cyan)),
          );
        }
        return switch (_view) {
          _TennisHubView.landing => _LandingScreen(
            state: state,
            onExit: widget.onExit,
            onOpenMode: _openMode,
            onResume: _resume,
            onSettings: () => setState(() => _view = _TennisHubView.settings),
          ),
          _TennisHubView.selection => _SelectionScreen(
            state: state,
            onBack: () => setState(() => _view = _TennisHubView.landing),
            onPreview: _showPreview,
          ),
          _TennisHubView.preview => _PreviewScreen(
            state: state,
            onBack: () => setState(() => _view = _TennisHubView.selection),
            onStart: () => _launch(),
          ),
          _TennisHubView.training => _TrainingScreen(
            state: state,
            onBack: () => setState(() => _view = _TennisHubView.landing),
            onSelectPlayer: () {
              _cubit.selectMode(TennisMode.training);
              setState(() => _view = _TennisHubView.selection);
            },
            onStart: (lesson) =>
                _launch(mode: TennisMode.training, trainingLesson: lesson),
          ),
          _TennisHubView.tournament => _TournamentScreen(
            state: state,
            onBack: () => setState(() => _view = _TennisHubView.landing),
            onStart: () => _launch(mode: TennisMode.tournament),
            onNewDraw: () => _cubit.prepareTournament(),
          ),
          _TennisHubView.settings => _HubSettingsScreen(
            settings: state.profile.settings,
            onBack: () => setState(() => _view = _TennisHubView.landing),
          ),
        };
      },
    );
  }
}

class _LandingScreen extends StatelessWidget {
  const _LandingScreen({
    required this.state,
    required this.onExit,
    required this.onOpenMode,
    required this.onResume,
    required this.onSettings,
  });

  final TennisState state;
  final VoidCallback onExit;
  final ValueChanged<TennisMode> onOpenMode;
  final VoidCallback onResume;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final profile = state.profile;
    return Scaffold(
      backgroundColor: Cyber.bg,
      appBar: ReactHeaderBar(
        title: 'Tennis Rally',
        subtitle: '// COURT ONLINE',
        onBack: onExit,
        rightSlot: const GameLeaderboardButton(
          sport: Sport.tennis,
          mode: GameMode.featured,
          accent: Cyber.lime,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: CyberBackground(
              animated: !profile.settings.reducedMotion,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _LandingSystemBar(
                          player: state.selectedPlayer,
                          onSettings: onSettings,
                        ),
                        const SizedBox(height: 13),
                        _TennisHero(
                          onPlay: () => onOpenMode(TennisMode.quickMatch),
                        ),
                        if (state.canResume) ...[
                          const SizedBox(height: 13),
                          _ResumeCard(
                            snapshot: state.resumeSnapshot!,
                            onResume: onResume,
                          ),
                        ],
                        const SizedBox(height: 18),
                        const SectionLabel(label: 'PLAY MODES'),
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final width = (constraints.maxWidth - 10) / 2;
                            return Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _ModeCard(
                                  width: width,
                                  mode: TennisMode.tournament,
                                  icon: Icons.emoji_events_outlined,
                                  subtitle: '8 PLAYERS / 3 ROUNDS',
                                  accent: Cyber.gold,
                                  onTap: () =>
                                      onOpenMode(TennisMode.tournament),
                                ),
                                _ModeCard(
                                  width: width,
                                  mode: TennisMode.training,
                                  icon: Icons.school_outlined,
                                  subtitle: '8 SKILL LESSONS',
                                  accent: Cyber.cyan,
                                  onTap: () => onOpenMode(TennisMode.training),
                                ),
                                _ModeCard(
                                  width: width,
                                  mode: TennisMode.endlessRally,
                                  icon: Icons.all_inclusive,
                                  subtitle: 'FIRST MISS ENDS IT',
                                  accent: Cyber.lime,
                                  onTap: () =>
                                      onOpenMode(TennisMode.endlessRally),
                                ),
                                _ModeCard(
                                  width: width,
                                  mode: TennisMode.targetPractice,
                                  icon: Icons.gps_fixed,
                                  subtitle: '20 BALLS / 90 SEC',
                                  accent: Cyber.amber,
                                  onTap: () =>
                                      onOpenMode(TennisMode.targetPractice),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        _MatchHistoryStrip(
                          profile: profile,
                          onTap: () => _openTennisMatchHistory(context, state),
                        ),
                        const SizedBox(height: 13),
                        _MasteryStrip(profile: profile),
                      ],
                    ),
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

class _LandingSystemBar extends StatelessWidget {
  const _LandingSystemBar({required this.player, required this.onSettings});

  final TennisPlayer player;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Cyber.lime,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'COURT ONLINE // ${player.name.toUpperCase()}',
            style: Cyber.display(9, color: Cyber.muted),
          ),
        ),
        IconButton(
          tooltip: 'Tennis settings',
          onPressed: onSettings,
          icon: const Icon(Icons.tune, color: Cyber.cyan, size: 21),
        ),
      ],
    );
  }
}

class _TennisHero extends StatelessWidget {
  const _TennisHero({required this.onPlay});

  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 254,
      child: ClipPath(
        clipper: const HudChamferClipper(bigCut: 22, smallCut: 8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: const _HeroCourtPainter()),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    color: Cyber.lime.withValues(alpha: 0.16),
                    child: Text(
                      'FEATURED // 2D ARCADE',
                      style: Cyber.display(8, color: Cyber.lime),
                    ),
                  ),
                  const SizedBox(height: 13),
                  Text(
                    'TENNIS',
                    style: Cyber.display(
                      34,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'RALLY',
                    style: Cyber.display(
                      38,
                      color: Cyber.lime,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'READ THE BOUNCE. OWN THE LINE.',
                    style: Cyber.body(
                      11,
                      color: Colors.white.withValues(alpha: 0.72),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: min(330, MediaQuery.sizeOf(context).width - 72),
                    child: HudCtaButton(
                      label: 'QUICK MATCH',
                      icon: Icons.sports_tennis,
                      accent: Cyber.lime,
                      helper: 'FULL SET // PRO DEFAULT',
                      onTap: onPlay,
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

class _HeroCourtPainter extends CustomPainter {
  const _HeroCourtPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff183341), Color(0xff07111d)],
        ).createShader(Offset.zero & size),
    );
    final court = Path()
      ..moveTo(size.width * 0.63, size.height * 0.14)
      ..lineTo(size.width * 0.94, size.height * 0.14)
      ..lineTo(size.width * 1.08, size.height * 0.98)
      ..lineTo(size.width * 0.47, size.height * 0.98)
      ..close();
    canvas.drawPath(court, Paint()..color = const Color(0xff12606a));
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(court, line);
    canvas.drawLine(
      Offset(size.width * 0.55, size.height * 0.59),
      Offset(size.width, size.height * 0.59),
      line,
    );
    canvas.drawLine(
      Offset(size.width * 0.705, size.height * 0.14),
      Offset(size.width * 0.64, size.height * 0.98),
      line,
    );
    canvas.drawLine(
      Offset(size.width * 0.855, size.height * 0.14),
      Offset(size.width * 0.91, size.height * 0.98),
      line,
    );
    canvas.drawCircle(
      Offset(size.width * 0.83, size.height * 0.42),
      9,
      Paint()..color = Cyber.lime,
    );
    canvas.drawCircle(
      Offset(size.width * 0.83, size.height * 0.42),
      18,
      Paint()
        ..color = Cyber.lime.withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.snapshot, required this.onResume});

  final TennisMatchSnapshot snapshot;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.amber,
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          const Icon(Icons.restore, color: Cyber.amber, size: 28),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MATCH SUSPENDED',
                  style: Cyber.display(11, color: Cyber.amber),
                ),
                const SizedBox(height: 4),
                Text(
                  '${snapshot.config.mode.label} // ${tennisPlayerById(snapshot.config.opponentId).name.toUpperCase()}',
                  style: Cyber.body(10, color: Cyber.muted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onResume,
            child: Text('RESUME', style: Cyber.display(10, color: Cyber.amber)),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.width,
    required this.mode,
    required this.icon,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final double width;
  final TennisMode mode;
  final IconData icon;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        child: CyberPanel(
          accent: accent,
          padding: const EdgeInsets.all(13),
          child: SizedBox(
            height: 92,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: accent, size: 23),
                const Spacer(),
                Text(
                  mode.label,
                  maxLines: 1,
                  style: Cyber.display(10, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  style: Cyber.display(7, color: Cyber.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _openTennisMatchHistory(BuildContext context, TennisState state) {
  final history = context
      .read<GameBloc>()
      .state
      .matchHistory
      .where((e) => e.isTennis)
      .toList(growable: false);
  showGameMatchHistory(
    context,
    gameLabel: 'Tennis Rally',
    history: history,
    career: _TennisCareerBoard(profile: state.profile),
  );
}

class _MatchHistoryStrip extends StatelessWidget {
  const _MatchHistoryStrip({required this.profile, required this.onTap});

  final TennisProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rate = profile.setsPlayed == 0
        ? 0
        : profile.setsWon / profile.setsPlayed;
    return InkWell(
      onTap: onTap,
      child: CyberPanel(
        accent: Cyber.cyan,
        child: Row(
          children: [
            const Icon(
              Icons.history,
              color: Cyber.cyan,
              size: 30,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MATCH HISTORY',
                    style: Cyber.display(12, color: Colors.white),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${profile.setsWon} WINS // ${(rate * 100).round()}% RATE // CAREER + RECENT SETS',
                    style: Cyber.display(8, color: Cyber.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Cyber.cyan),
          ],
        ),
      ),
    );
  }
}

class _MasteryStrip extends StatelessWidget {
  const _MasteryStrip({required this.profile});

  final TennisProfile profile;

  @override
  Widget build(BuildContext context) {
    final player = tennisPlayerById(profile.selectedPlayerId);
    final level = profile.masteryLevel(player.id);
    return CyberPanel(
      accent: Cyber.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${player.name.toUpperCase()} MASTERY',
                  style: Cyber.display(10),
                ),
              ),
              Text('LV $level', style: Cyber.display(11, color: Cyber.cyan)),
            ],
          ),
          const SizedBox(height: 9),
          CyberProgressBar(
            value: profile.masteryProgress(player.id),
            accent: Cyber.cyan,
            animate: false,
          ),
          const SizedBox(height: 7),
          Text(
            _nextCosmetic(level),
            style: Cyber.display(8, color: Cyber.muted),
          ),
        ],
      ),
    );
  }
}

String _nextCosmetic(int level) => switch (level) {
  < 2 => 'NEXT // ALTERNATE OUTFIT AT LEVEL 2',
  < 3 => 'NEXT // RACKET DESIGN AT LEVEL 3',
  < 5 => 'NEXT // PLAYER FRAME AT LEVEL 5',
  < 7 => 'NEXT // VICTORY POSE AT LEVEL 7',
  < 10 => 'NEXT // SERVE EFFECT AT LEVEL 10',
  _ => 'MASTERY PATH COMPLETE',
};

class _SelectionScreen extends StatelessWidget {
  const _SelectionScreen({
    required this.state,
    required this.onBack,
    required this.onPreview,
  });

  final TennisState state;
  final VoidCallback onBack;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final profile = state.profile;
    final selected = state.selectedPlayer;
    final competitive =
        state.selectedMode == TennisMode.quickMatch ||
        state.selectedMode == TennisMode.tournament;
    return Scaffold(
      backgroundColor: Cyber.bg,
      appBar: ReactHeaderBar(
        title: 'PLAYER SELECT',
        subtitle: '// ${state.selectedMode.label}',
        onBack: onBack,
      ),
      body: CyberBackground(
        animated: !profile.settings.reducedMotion,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionLabel(label: 'CHOOSE ATHLETE'),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = (constraints.maxWidth - 10) / 2;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final player in tennisPlayers)
                              SizedBox(
                                width: width,
                                child: _AthleteCard(
                                  player: player,
                                  selected: player.id == selected.id,
                                  unlocked: profile.isPlayerUnlocked(player.id),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _AthleteDetail(player: selected, profile: profile),
                    const SizedBox(height: 18),
                    const SectionLabel(label: 'DIFFICULTY'),
                    const SizedBox(height: 9),
                    _DifficultyPicker(selected: profile.difficulty),
                    const SizedBox(height: 20),
                    HudCtaButton(
                      label: competitive
                          ? 'FIND RIVAL'
                          : 'SESSION PREVIEW',
                      icon: competitive
                          ? Icons.radar
                          : Icons.sports_tennis,
                      accent: Cyber.lime,
                      helper: competitive
                          ? 'RANDOM QUEUE // ${profile.difficulty.label}'
                          : '${selected.name.toUpperCase()} // ${profile.difficulty.label}',
                      onTap: onPreview,
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

class _AthleteCard extends StatelessWidget {
  const _AthleteCard({
    required this.player,
    required this.selected,
    required this.unlocked,
  });

  final TennisPlayer player;
  final bool selected;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final accent = selected ? Cyber.lime : Cyber.cyan;
    return Opacity(
      opacity: unlocked ? 1 : 0.54,
      child: InkWell(
        onTap: unlocked
            ? () {
                HapticFeedback.selectionClick();
                context.read<TennisCubit>().selectPlayer(player.id);
              }
            : null,
        child: CyberPanel(
          accent: accent,
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 116,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _PlayerMonogram(player: player, size: 38),
                    const Spacer(),
                    if (selected)
                      const Icon(
                        Icons.check_circle,
                        color: Cyber.lime,
                        size: 19,
                      )
                    else if (!unlocked)
                      const Icon(
                        Icons.lock_outline,
                        color: Cyber.muted,
                        size: 18,
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  player.name.toUpperCase(),
                  maxLines: 1,
                  style: Cyber.display(10),
                ),
                const SizedBox(height: 4),
                Text(
                  player.archetype.label,
                  maxLines: 1,
                  style: Cyber.display(7, color: accent),
                ),
                const SizedBox(height: 4),
                Text(
                  unlocked
                      ? 'OVR ${player.ratings.overall}'
                      : _unlockLabel(player.id),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.display(7, color: Cyber.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _unlockLabel(String id) => switch (id) {
  'sora-malik' => 'COMPLETE ALL TRAINING',
  'kaia-brooks' => 'WIN ROOKIE TITLE',
  'theo-laurent' => 'WIN PRO TITLE',
  'riven-cole' => 'WIN ALL-STAR TITLE',
  _ => 'STARTER',
};

class _PlayerMonogram extends StatelessWidget {
  const _PlayerMonogram({required this.player, required this.size});

  final TennisPlayer player;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = player.name.split(' ').map((part) => part[0]).join();
    final color = _playerAccent(player.id);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(initials, style: Cyber.display(size * 0.28, color: color)),
    );
  }
}

Color _playerAccent(String id) => switch (id) {
  'jett-okafor' => Cyber.amber,
  'mira-chen' => Cyber.lime,
  'luca-vale' => Cyber.gold,
  'sora-malik' => Cyber.lime,
  'kaia-brooks' => Cyber.pink,
  'theo-laurent' => Cyber.blue,
  'riven-cole' => Cyber.violet,
  _ => Cyber.cyan,
};

class _AthleteDetail extends StatelessWidget {
  const _AthleteDetail({required this.player, required this.profile});

  final TennisPlayer player;
  final TennisProfile profile;

  @override
  Widget build(BuildContext context) {
    final ratings = player.ratings;
    return CyberPanel(
      accent: _playerAccent(player.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  player.signature,
                  style: Cyber.body(12, color: Cyber.muted),
                ),
              ),
              Text(
                'LV ${profile.masteryLevel(player.id)}',
                style: Cyber.display(11, color: Cyber.cyan),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _RatingChip('SPD', ratings.speed),
              _RatingChip('PWR', ratings.power),
              _RatingChip('CTL', ratings.control),
              _RatingChip('SRV', ratings.serve),
              _RatingChip('STA', ratings.stamina),
              _RatingChip('VOL', ratings.volley),
              _RatingChip('SPN', ratings.spin),
              _RatingChip('RCH', ratings.reach),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip(this.label, this.value);

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 67,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
      color: Cyber.bg.withValues(alpha: 0.62),
      child: Row(
        children: [
          Text(label, style: Cyber.display(7, color: Cyber.muted)),
          const Spacer(),
          Text('$value', style: Cyber.display(9, color: Cyber.cyan)),
        ],
      ),
    );
  }
}

class _DifficultyPicker extends StatelessWidget {
  const _DifficultyPicker({required this.selected});

  final TennisDifficulty selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final difficulty in TennisDifficulty.values)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: difficulty == TennisDifficulty.allStar ? 0 : 7,
              ),
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.read<TennisCubit>().selectDifficulty(difficulty);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 13,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: difficulty == selected
                        ? Cyber.cyan.withValues(alpha: 0.2)
                        : Cyber.panel,
                    border: Border.all(
                      color: difficulty == selected ? Cyber.cyan : Cyber.border,
                    ),
                  ),
                  child: Text(
                    difficulty.label,
                    textAlign: TextAlign.center,
                    style: Cyber.display(
                      8,
                      color: difficulty == selected ? Cyber.cyan : Cyber.muted,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PreviewScreen extends StatelessWidget {
  const _PreviewScreen({
    required this.state,
    required this.onBack,
    required this.onStart,
  });

  final TennisState state;
  final VoidCallback onBack;
  final VoidCallback onStart;

  void _openDeckBuilder(BuildContext context) {
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => TennisDeckBuilderScreen(
          onBack: navigator.pop,
          onSaved: navigator.pop,
        ),
      ),
    );
  }

  void _openMatchHistory(BuildContext context) {
    _openTennisMatchHistory(context, state);
  }

  @override
  Widget build(BuildContext context) {
    final player = state.selectedPlayer;
    final profile = state.profile;
    return Scaffold(
      backgroundColor: Cyber.bg,
      appBar: ReactHeaderBar(
        title: 'Tennis Rally',
        subtitle: '// MATCH LOBBY',
        onBack: onBack,
      ),
      body: CyberBackground(
        animated: !profile.settings.reducedMotion,
        child: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _TennisLobbyCourtPainter()),
              ),
            ),
            SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 380),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const CyberSlideUpFadeIn(
                                child: CyberLobbyStatusBar(
                                  systemLabel: 'SYS://TENNIS_RALLY v1.0.0',
                                  lineColor: Cyber.lime,
                                ),
                              ),
                              const SizedBox(height: 18),
                              CyberSlideUpFadeIn(
                                delay: const Duration(milliseconds: 80),
                                offset: 24,
                                child: Row(
                                  children: [
                                    const _TennisLobbyEmblem(size: 92),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'TENNIS RALLY',
                                              style: Cyber.display(
                                                24,
                                                letterSpacing: 1.4,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'FAST COURT SHOWDOWN',
                                            style: Cyber.display(
                                              9,
                                              color: Cyber.muted,
                                              letterSpacing: 2.2,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          CyberChip(
                                            label: state.canResume
                                                ? 'MATCH SAVED'
                                                : 'ATHLETE READY',
                                            color: state.canResume
                                                ? Cyber.amber
                                                : Cyber.lime,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: CyberDealtCard(
                                      key: const ValueKey(
                                        'tennis-lobby-stat-mastery',
                                      ),
                                      index: 0,
                                      initialDelay: const Duration(
                                        milliseconds: 180,
                                      ),
                                      flyDistance: 130,
                                      child: CyberHudStat(
                                        label: 'MASTERY',
                                        value:
                                            'LV ${profile.masteryLevel(player.id)}',
                                        accent: Cyber.lime,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: CyberDealtCard(
                                      key: const ValueKey(
                                        'tennis-lobby-stat-wins',
                                      ),
                                      index: 1,
                                      initialDelay: const Duration(
                                        milliseconds: 180,
                                      ),
                                      flyDistance: 130,
                                      child: CyberHudStat(
                                        label: 'SET WINS',
                                        value: '${profile.setsWon}',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: CyberDealtCard(
                                      key: const ValueKey(
                                        'tennis-lobby-stat-streak',
                                      ),
                                      index: 2,
                                      initialDelay: const Duration(
                                        milliseconds: 180,
                                      ),
                                      flyDistance: 130,
                                      child: CyberHudStat(
                                        label: 'STREAK',
                                        value: '${profile.currentWinStreak}',
                                        accent: profile.currentWinStreak > 0
                                            ? Cyber.success
                                            : Cyber.cyan,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              CyberSlideUpFadeIn(
                                delay: const Duration(milliseconds: 390),
                                offset: 22,
                                child: HudCtaButton(
                                  label: state.canResume
                                      ? 'RESUME MATCH'
                                      : 'PLAY MATCH',
                                  icon: Icons.sports_tennis,
                                  accent: Cyber.lime,
                                  helper:
                                      '${profile.difficulty.label} // SEEDED FAIR PLAY',
                                  onTap: () {
                                    HapticFeedback.mediumImpact();
                                    onStart();
                                  },
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: CyberDealtCard(
                                      key: const ValueKey(
                                        'tennis-lobby-action-deck',
                                      ),
                                      index: 0,
                                      initialDelay: const Duration(
                                        milliseconds: 470,
                                      ),
                                      staggerMs: 85,
                                      flyDistance: 95,
                                      duration: const Duration(
                                        milliseconds: 500,
                                      ),
                                      child: CyberCtaButton(
                                        label: 'Deck Builder',
                                        clip: false,
                                        onPressed: () =>
                                            _openDeckBuilder(context),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: CyberDealtCard(
                                      key: const ValueKey(
                                        'tennis-lobby-action-history',
                                      ),
                                      index: 1,
                                      initialDelay: const Duration(
                                        milliseconds: 470,
                                      ),
                                      staggerMs: 85,
                                      flyDistance: 95,
                                      duration: const Duration(
                                        milliseconds: 500,
                                      ),
                                      child: CyberCtaButton(
                                        label: 'Match History',
                                        clip: false,
                                        onPressed: () =>
                                            _openMatchHistory(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              CyberSlideUpFadeIn(
                                delay: const Duration(milliseconds: 590),
                                offset: 14,
                                child: _ControlBrief(mode: state.selectedMode),
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
          ],
        ),
      ),
    );
  }
}

class _TennisLobbyEmblem extends StatelessWidget {
  const _TennisLobbyEmblem({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CyberPulse(
      period: const Duration(milliseconds: 2600),
      builder: (context, pulse) {
        return SizedBox(
          width: size,
          height: size,
          child: ChamferedActionSurface(
            clipper: const HudChamferClipper(bigCut: 16, smallCut: 5),
            borderColor: Cyber.lime.withValues(alpha: 0.32 + pulse * 0.12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Cyber.bg.withValues(alpha: 0.66),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.sports_tennis,
                    size: size * 0.58,
                    color: Cyber.lime,
                  ),
                  Positioned(
                    top: 13,
                    right: 13,
                    child: Container(
                      width: 5,
                      height: 5,
                      color: Cyber.cyan.withValues(alpha: 0.72),
                    ),
                  ),
                  Positioned(
                    left: 11,
                    bottom: 11,
                    child: Text(
                      'TR//01',
                      style: Cyber.display(
                        6.5,
                        color: Cyber.muted,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TennisLobbyCourtPainter extends CustomPainter {
  const _TennisLobbyCourtPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final court = Path()
      ..moveTo(size.width * 0.25, size.height * 0.34)
      ..lineTo(size.width * 0.75, size.height * 0.34)
      ..lineTo(size.width * 1.08, size.height)
      ..lineTo(size.width * -0.08, size.height)
      ..close();
    canvas.drawPath(
      court,
      Paint()..color = Cyber.lime.withValues(alpha: 0.025),
    );

    final line = Paint()
      ..color = Cyber.lime.withValues(alpha: 0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(court, line);
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.34),
      Offset(size.width * 0.5, size.height),
      line,
    );
    canvas.drawLine(
      Offset(size.width * 0.11, size.height * 0.72),
      Offset(size.width * 0.89, size.height * 0.72),
      line,
    );
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.53),
      Offset(size.width * 0.8, size.height * 0.53),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ControlBrief extends StatelessWidget {
  const _ControlBrief({required this.mode});

  final TennisMode mode;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.lime,
      child: Row(
        children: [
          const Icon(Icons.open_with, color: Cyber.cyan),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'DRAG TO MOVE // QUICK FLICK TO SPRINT',
              style: Cyber.display(8, color: Cyber.muted),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.swipe, color: Cyber.lime),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'TAP, HOLD OR SWIPE TO SHAPE THE SHOT',
              style: Cyber.display(8, color: Cyber.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingScreen extends StatelessWidget {
  const _TrainingScreen({
    required this.state,
    required this.onBack,
    required this.onSelectPlayer,
    required this.onStart,
  });

  final TennisState state;
  final VoidCallback onBack;
  final VoidCallback onSelectPlayer;
  final ValueChanged<int> onStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      appBar: ReactHeaderBar(
        title: 'TRAINING LAB',
        subtitle: '// 8 LESSONS',
        onBack: onBack,
      ),
      body: CyberBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CyberPanel(
                        accent: Cyber.cyan,
                        child: Row(
                          children: [
                            _PlayerMonogram(
                              player: state.selectedPlayer,
                              size: 48,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    state.selectedPlayer.name.toUpperCase(),
                                    style: Cyber.display(11),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${state.profile.completedLessons.length}/8 COMPLETE',
                                    style: Cyber.display(8, color: Cyber.cyan),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: onSelectPlayer,
                              child: Text(
                                'CHANGE',
                                style: Cyber.display(9, color: Cyber.cyan),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      for (final lesson in _lessons) ...[
                        _LessonCard(
                          lesson: lesson,
                          complete: state.profile.completedLessons.contains(
                            lesson.number,
                          ),
                          onStart: () => onStart(lesson.number),
                        ),
                        const SizedBox(height: 9),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.lesson,
    required this.complete,
    required this.onStart,
  });

  final _LessonSpec lesson;
  final bool complete;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: complete ? Cyber.lime : Cyber.cyan,
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            color: (complete ? Cyber.lime : Cyber.cyan).withValues(alpha: 0.14),
            child: complete
                ? const Icon(Icons.check, color: Cyber.lime)
                : Text(
                    '${lesson.number}',
                    style: Cyber.display(16, color: Cyber.cyan),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lesson.name, style: Cyber.display(10)),
                const SizedBox(height: 4),
                Text(
                  lesson.objective,
                  style: Cyber.body(10, color: Cyber.muted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onStart,
            child: Text(
              complete ? 'REPLAY' : 'START',
              style: Cyber.display(
                9,
                color: complete ? Cyber.lime : Cyber.cyan,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _lessons = <_LessonSpec>[
  _LessonSpec(1, 'MOVEMENT', 'Reach the marker and return three normal shots.'),
  _LessonSpec(2, 'TIMING', 'Read early, good, perfect and late contact.'),
  _LessonSpec(3, 'DIRECTION', 'Aim one return left and one return right.'),
  _LessonSpec(4, 'POWER SHOT', 'Hold through a short ball and manage stamina.'),
  _LessonSpec(5, 'LOB', 'Lift a long upward gesture over the net player.'),
  _LessonSpec(6, 'SERVING', 'Complete a first serve and a safe second serve.'),
  _LessonSpec(7, 'STAMINA', 'Sprint, recover and return to centre position.'),
  _LessonSpec(8, 'SCORING', 'Play through Love, Deuce, Advantage and Game.'),
];

class _LessonSpec {
  const _LessonSpec(this.number, this.name, this.objective);

  final int number;
  final String name;
  final String objective;
}

class _TournamentScreen extends StatelessWidget {
  const _TournamentScreen({
    required this.state,
    required this.onBack,
    required this.onStart,
    required this.onNewDraw,
  });

  final TennisState state;
  final VoidCallback onBack;
  final VoidCallback onStart;
  final VoidCallback onNewDraw;

  @override
  Widget build(BuildContext context) {
    final tournament = state.profile.tournament;
    final active = tournament?.active ?? false;
    return Scaffold(
      backgroundColor: Cyber.bg,
      appBar: ReactHeaderBar(
        title: 'STAToz OPEN',
        subtitle: '// 8 PLAYER BRACKET',
        onBack: onBack,
      ),
      body: CyberBackground(
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TournamentHeader(
                      tournament: tournament,
                      profile: state.profile,
                    ),
                    const SizedBox(height: 14),
                    if (tournament != null) _Bracket(tournament: tournament),
                    const SizedBox(height: 16),
                    if (active)
                      HudCtaButton(
                        label: 'PLAY ${_roundName(tournament!.currentRound)}',
                        icon: Icons.sports_tennis,
                        accent: Cyber.gold,
                        helper:
                            '${tournament.difficulty.label} // WIN TO ADVANCE',
                        onTap: onStart,
                      )
                    else
                      HudCtaButton(
                        label: 'CREATE NEW DRAW',
                        icon: Icons.casino_outlined,
                        accent: Cyber.gold,
                        onTap: onNewDraw,
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

String _roundName(int round) => switch (round) {
  0 => 'QUARTERFINAL',
  1 => 'SEMIFINAL',
  _ => 'FINAL',
};

class _TournamentHeader extends StatelessWidget {
  const _TournamentHeader({required this.tournament, required this.profile});

  final TennisTournament? tournament;
  final TennisProfile profile;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.gold,
      glow: true,
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: Cyber.gold, size: 42),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tournament?.champion == true
                      ? 'TITLE SECURED'
                      : 'THREE WINS TO THE TROPHY',
                  style: Cyber.display(12, color: Cyber.gold),
                ),
                const SizedBox(height: 5),
                Text(
                  '${tennisPlayerById(tournament?.playerId ?? profile.selectedPlayerId).name.toUpperCase()} // '
                  '${tournament?.difficulty.label ?? profile.difficulty.label}',
                  style: Cyber.display(8, color: Cyber.muted),
                ),
              ],
            ),
          ),
          Text(
            '${tournament?.results.where((result) => result == 'W').length ?? 0}/3',
            style: Cyber.display(19, color: Cyber.gold),
          ),
        ],
      ),
    );
  }
}

class _Bracket extends StatelessWidget {
  const _Bracket({required this.tournament});

  final TennisTournament tournament;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('TOURNAMENT DRAW', style: Cyber.display(11, color: Cyber.cyan)),
          const SizedBox(height: 12),
          for (var i = 0; i < tournament.opponents.length; i++) ...[
            _BracketRound(
              round: i,
              opponent: tennisPlayerById(tournament.opponents[i]),
              result: i < tournament.results.length
                  ? tournament.results[i]
                  : null,
              current: tournament.active && i == tournament.currentRound,
            ),
            if (i < tournament.opponents.length - 1)
              Center(
                child: Container(width: 1, height: 13, color: Cyber.border),
              ),
          ],
          const SizedBox(height: 14),
          Text('FIELD OF 8', style: Cyber.display(8, color: Cyber.muted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final id in tournament.entrants)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  color: id == tournament.playerId
                      ? Cyber.cyan.withValues(alpha: 0.18)
                      : Cyber.bg.withValues(alpha: 0.62),
                  child: Text(
                    tennisPlayerById(id).name.toUpperCase(),
                    style: Cyber.display(
                      7,
                      color: id == tournament.playerId
                          ? Cyber.cyan
                          : Cyber.muted,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BracketRound extends StatelessWidget {
  const _BracketRound({
    required this.round,
    required this.opponent,
    required this.result,
    required this.current,
  });

  final int round;
  final TennisPlayer opponent;
  final String? result;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final color = result == 'W'
        ? Cyber.lime
        : (result == 'L'
              ? Cyber.danger
              : (current ? Cyber.gold : Cyber.border));
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: current
            ? Cyber.gold.withValues(alpha: 0.08)
            : Cyber.bg.withValues(alpha: 0.5),
        border: Border.all(color: color.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              _roundName(round),
              style: Cyber.display(8, color: color),
            ),
          ),
          _PlayerMonogram(player: opponent, size: 34),
          const SizedBox(width: 9),
          Expanded(
            child: Text(opponent.name.toUpperCase(), style: Cyber.display(9)),
          ),
          Text(
            result ?? (current ? 'NEXT' : '--'),
            style: Cyber.display(10, color: color),
          ),
        ],
      ),
    );
  }
}

/// Career board embedded in Tennis Match History (record + trophies + mastery).
class _TennisCareerBoard extends StatelessWidget {
  const _TennisCareerBoard({required this.profile});

  final TennisProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel(label: 'CAREER'),
        const SizedBox(height: 10),
        _CareerNumbers(profile: profile),
        const SizedBox(height: 14),
        _TrophyCabinet(profile: profile),
        const SizedBox(height: 14),
        const SectionLabel(label: 'ATHLETE MASTERY'),
        const SizedBox(height: 9),
        for (final player in tennisPlayers) ...[
          _MasteryRow(player: player, profile: profile),
          const SizedBox(height: 7),
        ],
        const SizedBox(height: 12),
        const SectionLabel(label: 'ACHIEVEMENTS'),
        const SizedBox(height: 9),
        for (final achievement in _tennisAchievements) ...[
          _AchievementRow(
            spec: achievement,
            unlocked: profile.achievements.contains(achievement.id),
          ),
          const SizedBox(height: 7),
        ],
        const SizedBox(height: 8),
        const SectionLabel(label: 'RECENT MATCHES'),
      ],
    );
  }
}

class _CareerNumbers extends StatelessWidget {
  const _CareerNumbers({required this.profile});

  final TennisProfile profile;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.cyan,
      child: Row(
        children: [
          _CareerNumber(label: 'SETS', value: '${profile.setsPlayed}'),
          _CareerNumber(label: 'WINS', value: '${profile.setsWon}'),
          _CareerNumber(label: 'ACES', value: '${profile.totalAces}'),
          _CareerNumber(label: 'RALLY', value: '${profile.longestRally}'),
        ],
      ),
    );
  }
}

class _CareerNumber extends StatelessWidget {
  const _CareerNumber({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: Cyber.display(19, color: Cyber.cyan)),
          const SizedBox(height: 4),
          Text(label, style: Cyber.display(7, color: Cyber.muted)),
        ],
      ),
    );
  }
}

class _TrophyCabinet extends StatelessWidget {
  const _TrophyCabinet({required this.profile});

  final TennisProfile profile;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TROPHY CABINET', style: Cyber.display(11, color: Cyber.gold)),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final difficulty in TennisDifficulty.values)
                Expanded(
                  child: Column(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        color: (profile.trophies[difficulty.name] ?? 0) > 0
                            ? Cyber.gold
                            : Cyber.border,
                        size: 31,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        difficulty.label,
                        style: Cyber.display(7, color: Cyber.muted),
                      ),
                      Text(
                        'x${profile.trophies[difficulty.name] ?? 0}',
                        style: Cyber.display(9, color: Cyber.gold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MasteryRow extends StatelessWidget {
  const _MasteryRow({required this.player, required this.profile});

  final TennisPlayer player;
  final TennisProfile profile;

  @override
  Widget build(BuildContext context) {
    final level = profile.masteryLevel(player.id);
    return Container(
      padding: const EdgeInsets.all(11),
      color: Cyber.panel,
      child: Row(
        children: [
          _PlayerMonogram(player: player, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.name.toUpperCase(), style: Cyber.display(9)),
                const SizedBox(height: 6),
                CyberProgressBar(
                  value: profile.masteryProgress(player.id),
                  accent: _playerAccent(player.id),
                  height: 5,
                  animate: false,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'LV $level',
            style: Cyber.display(10, color: _playerAccent(player.id)),
          ),
        ],
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({required this.spec, required this.unlocked});

  final _AchievementSpec spec;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: unlocked ? 1 : 0.55,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Cyber.panel,
          border: Border.all(color: unlocked ? Cyber.lime : Cyber.border),
        ),
        child: Row(
          children: [
            Icon(
              unlocked ? Icons.military_tech : Icons.lock_outline,
              color: unlocked ? Cyber.lime : Cyber.muted,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spec.name,
                    style: Cyber.display(
                      9,
                      color: unlocked ? Colors.white : Cyber.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    spec.condition,
                    style: Cyber.body(10, color: Cyber.muted),
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

const _tennisAchievements = <_AchievementSpec>[
  _AchievementSpec(
    'clean-hold',
    'CLEAN HOLD',
    'Win a service game without losing a point.',
  ),
  _AchievementSpec('break-through', 'BREAK THROUGH', 'Convert a break point.'),
  _AchievementSpec(
    'unbreakable',
    'UNBREAKABLE',
    'Save three break points in one match.',
  ),
  _AchievementSpec(
    'ace-high',
    'ACE HIGH',
    'Hit five aces across completed sets.',
  ),
  _AchievementSpec(
    'rally-architect',
    'RALLY ARCHITECT',
    'Complete a 20-shot rally.',
  ),
  _AchievementSpec(
    'net-authority',
    'NET AUTHORITY',
    'Win ten net points with a serve-and-volley athlete.',
  ),
  _AchievementSpec(
    'comeback-set',
    'COMEBACK SET',
    'Win after trailing by three games.',
  ),
  _AchievementSpec(
    'tiebreak-nerve',
    'TIEBREAK NERVE',
    'Win after saving set point in a tiebreak.',
  ),
  _AchievementSpec(
    'all-styles',
    'ALL STYLES',
    'Win with every base archetype.',
  ),
  _AchievementSpec('champion', 'CHAMPION', 'Win the eight-player tournament.'),
];

class _AchievementSpec {
  const _AchievementSpec(this.id, this.name, this.condition);

  final String id;
  final String name;
  final String condition;
}

class _HubSettingsScreen extends StatelessWidget {
  const _HubSettingsScreen({required this.settings, required this.onBack});

  final TennisSettings settings;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TennisCubit>();
    return Scaffold(
      backgroundColor: Cyber.bg,
      appBar: ReactHeaderBar(
        title: 'TENNIS SETTINGS',
        subtitle: '// CONTROLS & ACCESS',
        onBack: onBack,
      ),
      body: CyberBackground(
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: CyberPanel(
                  child: Column(
                    children: [
                      _HubSwitch(
                        label: 'LEFT-HANDED CONTROL LAYOUT',
                        value: settings.leftHanded,
                        onChanged: (value) => cubit.updateSettings(
                          settings.copyWith(leftHanded: value),
                        ),
                      ),
                      _HubSwitch(
                        label: 'MOVEMENT ASSIST',
                        value: settings.movementAssist,
                        onChanged: (value) => cubit.updateSettings(
                          settings.copyWith(movementAssist: value),
                        ),
                      ),
                      _HubSwitch(
                        label: 'REDUCED MOTION',
                        value: settings.reducedMotion,
                        onChanged: (value) => cubit.updateSettings(
                          settings.copyWith(reducedMotion: value),
                        ),
                      ),
                      _HubSwitch(
                        label: 'STRONG FLASHES',
                        value: settings.strongFlashes,
                        onChanged: (value) => cubit.updateSettings(
                          settings.copyWith(strongFlashes: value),
                        ),
                      ),
                      _HubSwitch(
                        label: 'HAPTICS',
                        value: settings.haptics,
                        onChanged: (value) => cubit.updateSettings(
                          settings.copyWith(haptics: value),
                        ),
                      ),
                      _HubSwitch(
                        label: 'MUSIC',
                        value: settings.music,
                        onChanged: (value) => cubit.updateSettings(
                          settings.copyWith(music: value),
                        ),
                      ),
                      _HubSwitch(
                        label: 'SOUND EFFECTS',
                        value: settings.sound,
                        onChanged: (value) => cubit.updateSettings(
                          settings.copyWith(sound: value),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _HubSlider(
                        label: 'CONTROL SIZE',
                        value: settings.controlScale,
                        min: 0.8,
                        max: 1.25,
                        onChanged: (value) => cubit.updateSettings(
                          settings.copyWith(controlScale: value),
                        ),
                      ),
                      _HubSlider(
                        label: 'CONTROL OPACITY',
                        value: settings.controlOpacity,
                        min: 0.45,
                        max: 1,
                        onChanged: (value) => cubit.updateSettings(
                          settings.copyWith(controlOpacity: value),
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

class _HubSwitch extends StatelessWidget {
  const _HubSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: Cyber.display(9)),
      value: value,
      activeThumbColor: Cyber.cyan,
      onChanged: onChanged,
    );
  }
}

class _HubSlider extends StatelessWidget {
  const _HubSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Cyber.display(9, color: Cyber.muted)),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: Cyber.cyan,
          inactiveColor: Cyber.border,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
```

### A.2 `lib/widgets/game_scaffold.dart`

<sub>132 lines</sub>

```dart
// SUBSET of the host app's lib/widgets/game_scaffold.dart: ReactHeaderBar,
// copied verbatim. Every hub view uses it as its app bar. GameScaffold (same
// source file) is left out; the hub builds its own CyberBackground bodies.
import 'package:flutter/material.dart';

import '../config/theme.dart';
import 'cyber/cyber_widgets.dart';

class ReactHeaderBar extends StatelessWidget implements PreferredSizeWidget {
  const ReactHeaderBar({
    required this.title,
    this.subtitle,
    this.onBack,
    this.leftSlot,
    this.rightSlot,
    this.titleUnderlay,
    this.compact = false,
    this.showShop = false,
    this.showTitle = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? leftSlot;
  final Widget? rightSlot;
  final Widget? titleUnderlay;
  final bool compact;
  final bool showShop;
  final bool showTitle;

  @override
  Size get preferredSize => Size.fromHeight(compact ? 56 : 66);

  @override
  Widget build(BuildContext context) {
    final barHeight = compact ? 54.0 : 64.0;
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: barHeight,
      titleSpacing: 0,
      // The gradient lives in flexibleSpace so it paints the whole AppBar —
      // status-bar inset included — instead of just the toolbar.
      flexibleSpace: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff0b1120), Color(0xff070b14)],
          ),
        ),
      ),
      title: Container(
        height: barHeight,
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: compact ? 6 : 8,
        ),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xff1e2538))),
        ),
        child: Row(
          children: [
            if (leftSlot != null)
              SizedBox(width: 42, height: 42, child: leftSlot)
            else if (onBack != null)
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                color: Cyber.cyan,
              ),
            if (leftSlot != null || onBack != null) const SizedBox(width: 8),
            Expanded(
              child: showTitle
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '/',
                              style: TextStyle(
                                color: Cyber.cyan,
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                title.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Orbitron',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (titleUnderlay != null) ...[
                          const SizedBox(height: 5),
                          titleUnderlay!,
                        ] else if (subtitle != null)
                          Text(
                            subtitle!,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Cyber.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            ?rightSlot,
          ],
        ),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(2),
        child: HudLine(),
      ),
    );
  }
}
```

### A.3 `lib/widgets/cyber/cyber_hub_widgets.dart`

<sub>566 lines</sub>

```dart
// SUPPLEMENT to the Tennis Rally port doc's
// lib/widgets/cyber/cyber_widgets.dart (Appendix D.6 there). These are the
// shared HUD primitives the hub needs on top of that subset, copied verbatim
// from the host app's cyber_widgets.dart.
// It is a superset of the same-named file in the Final Over hub, Hoop Duel
// lobby and Grand Prix lobby docs (it adds CyberBackground, CyberGridPainter,
// CyberLobbyStatusBar and CyberHudStat). Re-export this file from
// cyber_widgets.dart (see the hub doc, section 8) so
// `import 'cyber_widgets.dart'` keeps resolving everything, as in the source.
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/theme.dart';
import 'cyber_widgets.dart';

class CyberBackground extends StatefulWidget {
  const CyberBackground({
    required this.child,
    this.animated = false,
    super.key,
  });

  final Widget child;

  /// When true, the radial glow slowly drifts (used on the home screen).
  final bool animated;

  @override
  State<CyberBackground> createState() => _CyberBackgroundState();
}

class _CyberBackgroundState extends State<CyberBackground>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.animated) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 16),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Widget _glow(double t) {
    final dx = 0.2 + 0.3 * sin(t * 2 * pi);
    final dy = -0.75 + 0.18 * cos(t * 2 * pi);
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(dx, dy),
            radius: 1.1,
            colors: [
              Cyber.cyan.withValues(alpha: 0.12),
              Cyber.violet.withValues(alpha: 0.08),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: CyberGridPainter())),
        const Positioned.fill(child: CyberTextureOverlay()),
        if (_controller == null)
          _glow(0)
        else
          AnimatedBuilder(
            animation: _controller!,
            builder: (context, _) => _glow(_controller!.value),
          ),
        widget.child,
      ],
    );
  }
}

class CyberGridPainter extends CustomPainter {
  const CyberGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawRect(Offset.zero & size, Paint()..color = Cyber.bg);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Paints the shared HUD texture layers — CRT scanlines and an edge vignette —
/// over whatever is already on the canvas. Shared by the full
/// [CyberBackground] and the standalone [CyberTextureOverlay].
void _paintCyberTexture(Canvas canvas, Size size, {bool vignette = true}) {
  final rect = Offset.zero & size;

  // CRT scanlines — faint dark rows every 3px, crisp (no anti-alias).
  final scan = Paint()
    ..color = Colors.black.withValues(alpha: 0.14)
    ..strokeWidth = 1
    ..isAntiAlias = false;
  for (var y = 0.0; y < size.height; y += 3) {
    canvas.drawLine(Offset(0, y), Offset(size.width, y), scan);
  }

  // Vignette — darken the edges to pull focus to the centre.
  if (vignette) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 1.15,
          colors: [
            Colors.transparent,
            const Color(0xff04060c).withValues(alpha: 0.5),
          ],
          stops: const [0.55, 1.0],
        ).createShader(rect),
    );
  }
}

/// A transparent overlay of the shared HUD texture (scanlines + optional
/// vignette) for screens that draw their own background instead of
/// using [CyberBackground] (e.g. the home stadium, the shop). Drop it into a
/// Stack above the background and below the content:
/// `const Positioned.fill(child: CyberTextureOverlay())`.
class CyberTextureOverlay extends StatefulWidget {
  const CyberTextureOverlay({this.vignette = true, super.key});

  final bool vignette;

  @override
  State<CyberTextureOverlay> createState() => _CyberTextureOverlayState();
}

class _CyberTextureOverlayState extends State<CyberTextureOverlay> {
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _CyberOverlayPainter(vignette: widget.vignette),
        size: Size.infinite,
      ),
    );
  }
}

class _CyberOverlayPainter extends CustomPainter {
  const _CyberOverlayPainter({required this.vignette});

  final bool vignette;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _paintCyberTexture(canvas, size, vignette: vignette);
  }

  @override
  bool shouldRepaint(covariant _CyberOverlayPainter oldDelegate) =>
      oldDelegate.vignette != vignette;
}

class HudLine extends StatelessWidget {
  const HudLine({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Cyber.cyan.withValues(alpha: 0.9),
            Cyber.magenta.withValues(alpha: 0.75),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class CyberCtaButton extends StatelessWidget {
  const CyberCtaButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.clip = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final bg = primary
        ? const LinearGradient(colors: [Cyber.cyan, Color(0xff5cb4ff)])
        : LinearGradient(colors: [Cyber.panel2, Cyber.panel]);
    final inner = Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 56),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: bg,
        border: clip
            ? null
            : Border.all(color: primary ? Cyber.cyan : Cyber.line),
        boxShadow: [
          BoxShadow(
            color: (primary ? Cyber.cyan : Cyber.bg).withValues(alpha: 0.3),
            blurRadius: 18,
          ),
        ],
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: primary ? Cyber.bg : Cyber.cyan,
          fontFamily: 'Orbitron',
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: clip
            ? ChamferedActionSurface(
                clipper: CyberClipper(),
                borderColor: primary ? Cyber.cyan : Cyber.line,
                child: inner,
              )
            : inner,
      ),
    );
  }
}

/// Compact live-status telemetry shared by game lobbies.
///
/// The status dot is the only persistent element allowed to glow because it
/// communicates a live system state. The rest of the strip stays deliberately
/// quiet so it does not compete with the lobby CTA.
class CyberLobbyStatusBar extends StatelessWidget {
  const CyberLobbyStatusBar({
    required this.systemLabel,
    this.statusLabel = 'ONLINE',
    this.statusColor = Cyber.success,
    this.lineColor = Cyber.cyan,
    super.key,
  });

  final String systemLabel;
  final String statusLabel;
  final Color statusColor;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
            boxShadow: Cyber.glow(statusColor, alpha: 0.6, blur: 8, spread: 0),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          statusLabel.toUpperCase(),
          style: Cyber.display(9, color: statusColor, letterSpacing: 2),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(height: 1, color: lineColor.withValues(alpha: 0.16)),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              systemLabel.toUpperCase(),
              maxLines: 1,
              style: Cyber.display(8.5, color: Cyber.muted, letterSpacing: 1.2),
            ),
          ),
        ),
      ],
    );
  }
}

/// Calm telemetry cell for game-lobby progression and performance numbers.
class CyberHudStat extends StatelessWidget {
  const CyberHudStat({
    required this.label,
    required this.value,
    this.accent = Cyber.cyan,
    super.key,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Cyber.bg.withValues(alpha: 0.5),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: Cyber.display(
                16,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Cyber.display(7.5, color: Cyber.muted, letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }
}

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

/// A looping pulse driver for "live" HUD elements (alerts, active indicators,
/// ON FIRE states). Rebuilds [builder] with `t` sweeping 0 → 1 → 0 each
/// [period]. Keep it scarce — a pulse marks the one live thing on screen.
class CyberPulse extends StatefulWidget {
  const CyberPulse({
    required this.builder,
    this.period = const Duration(milliseconds: 900),
    super.key,
  });

  final Widget Function(BuildContext context, double t) builder;
  final Duration period;

  @override
  State<CyberPulse> createState() => _CyberPulseState();
}

class _CyberPulseState extends State<CyberPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => widget.builder(context, _controller.value),
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

### A.4 `lib/widgets/matchmaking/game_matchmaking_config.dart`

<sub>55 lines</sub>

```dart
import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/avatar_frame_option.dart';

/// One side of the matchmaking face-off (player or rival).
class MatchmakingFighter {
  const MatchmakingFighter({
    required this.name,
    required this.avatarAsset,
    this.badge,
    this.frame,
    this.accent,
  });

  final String name;
  final String avatarAsset;
  final String? badge;
  final AvatarFrameOption? frame;

  /// Banner accent; defaults to cyan (player) / gold (opponent) at the call site.
  final Color? accent;
}

/// Configurable identity + chrome for the shared matchmaking cinematic.
class GameMatchmakingConfig {
  const GameMatchmakingConfig({
    required this.title,
    required this.player,
    required this.opponent,
    this.subtitle = '// MATCHMAKING',
    this.queueLabel = 'SCANNING GLOBAL QUEUE',
    this.backgroundAsset,
    this.searchAccent = Cyber.cyan,
    this.lockedAccent = Cyber.gold,
  });

  /// Header title, e.g. `PITCH DUEL`.
  final String title;

  /// Header subtitle under the title.
  final String subtitle;

  /// Telemetry line under the search progress bar.
  final String queueLabel;

  /// Optional arena art (`assets/backgrounds/...`). Null = gradient bed only.
  final String? backgroundAsset;

  final MatchmakingFighter player;
  final MatchmakingFighter opponent;

  final Color searchAccent;
  final Color lockedAccent;
}
```


## Appendix B — Stand-ins for host-app dependencies

Each file says what the source does and what to replace it with (§7).

### B.1 `lib/config/theme.dart`

<sub>114 lines</sub>

```dart
// STAND-IN for the host app's lib/config/theme.dart.
// REPLACES Appendix D.1 of the Tennis Rally port doc: identical, plus
// `Cyber.blue`, which the hub's athlete accents read (source literal value).
// Every token the four ported games read, resolved to the source app's
// literal values. If the target project already has a design system, map
// these names onto it instead of shipping a second palette.
import 'package:flutter/material.dart';

class AppTheme {
  static const Color textContrast = Color.fromRGBO(255, 255, 255, 1);
}

class Cyber {
  // Surfaces
  static const Color bg = Color.fromRGBO(13, 17, 26, 1);
  static const Color bg2 = Color.fromRGBO(7, 12, 31, 1);
  static const Color card = Color.fromRGBO(15, 23, 43, 1);
  static const Color panel = Color.fromRGBO(29, 41, 61, 1);
  static const Color panel2 = Color.fromRGBO(15, 23, 43, 1);

  // Accents
  static const Color cyan = Color.fromRGBO(92, 223, 255, 1);
  static const Color magenta = Color.fromRGBO(194, 122, 255, 1);
  static const Color violet = Color.fromRGBO(194, 122, 255, 1);
  static const Color lime = Color.fromRGBO(81, 255, 148, 1);
  static const Color amber = Color.fromRGBO(255, 137, 4, 1);
  static const Color gold = Color.fromRGBO(253, 199, 0, 1);
  static const Color danger = Color.fromRGBO(255, 77, 77, 1);
  static const Color success = Color.fromRGBO(5, 223, 114, 1);
  static const Color pink = Color(0xFFFF94C1);
  static const Color blue = Color.fromRGBO(60, 149, 218, 1);

  // Lines & text
  static const Color border = Color.fromRGBO(49, 65, 88, 1);
  static const Color line = Color.fromRGBO(69, 85, 108, 1);
  static const Color muted = Color.fromRGBO(144, 161, 185, 1);
  static const Color textPrimary = Color.fromRGBO(92, 223, 255, 1);
  static const Color borderMuted = Color(0xFF243654);

  // Arena backdrop
  static const Color arenaSky = Color(0xFF020812);
  static const Color arenaHorizon = Color(0xFF071522);
  static const Color arenaVioletHorizon = Color(0xFF101024);
  static const Color arenaFloor = Color(0xFF02050B);

  // Fonts — Orbitron (display/labels) and Onest (body). Declare both in
  // pubspec.yaml or swap in the target project's families.
  static const String displayFont = 'Orbitron';
  static const String bodyFont = 'Onest';

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

### B.2 `lib/config/enums.dart`

<sub>22 lines</sub>

```dart
// STAND-IN for the host app's lib/config/enums.dart.
// REPLACES Appendix D.2 of the Tennis Rally port doc: its `CardTier` is kept,
// and `AppSection` (verbatim), which the leaderboard button stand-in takes, is
// added.
enum CardTier { bronze, silver, gold, platinum }

enum AppSection {
  // App-level destinations (bottom nav).
  predictions, // MATCHES - app home and sports-prediction hub
  leaderboard,
  shop,
  profile,
  // Card-game ("Pitch Duel") internal sections, reached under the GAMES tab.
  home,
  deck,
  howToPlay,
  match,
  shootout,
  game,
  allCards,
  guessPlayer,
}
```

### B.3 `lib/utils/sound_effects.dart`

<sub>9 lines</sub>

```dart
// STAND-IN for the host app's lib/utils/sound_effects.dart.
// REPLACES Appendix D.5 of the Tennis Rally port doc: same no-op stand-in,
// plus `uiTap`, which the V2 hub's mode cards and the leaderboard button play.
// Wire these to your own audio layer (audioplayers / flame_audio / etc).
enum SoundEffect { playMatch, cardSelect, riser, uiTap }

void playSound(SoundEffect effect) {
  // no-op stand-in
}
```

### B.4 `lib/models/progression.dart`

<sub>15 lines</sub>

```dart
// STAND-IN for the host app's lib/models/progression.dart: the XP-track shape
// the hub reads (the level stamped on both matchmaking badges). The source
// keeps per-track XP and derives levels from a shared curve.
enum ProgressTrack { tennis }

class PlayerProgression {
  const PlayerProgression({this.trackXp = const {}});

  final Map<ProgressTrack, int> trackXp;

  int xpFor(ProgressTrack track) => trackXp[track] ?? 0;

  /// Stand-in curve: a level every 100 XP. Use your own.
  int levelFor(ProgressTrack track) => xpFor(track) ~/ 100 + 1;
}
```

### B.5 `lib/models/match.dart`

<sub>21 lines</sub>

```dart
// STAND-IN for the host app's MatchHistoryEntry (lib/models/match.dart).
// The source entry also carries teams, scores, rounds and rewards. Tennis
// results are written with `mode: 'tennis'` by GameBloc's TennisFinished
// handler. The hub filters on `isTennis` (verbatim getter).
class MatchHistoryEntry {
  const MatchHistoryEntry({
    required this.id,
    required this.mode,
    required this.resultLabel,
    required this.summary,
  });

  final String id;
  final String mode;

  /// 'Victory', 'Defeat', 'Completed' or 'Lesson Complete'.
  final String resultLabel;
  final String summary;

  bool get isTennis => mode == 'tennis';
}
```

### B.6 `lib/models/sport_match.dart`

<sub>5 lines</sub>

```dart
// STAND-IN: the host app's `Sport` enum, verbatim. The rest of
// lib/models/sport_match.dart (fixtures, scores) is not needed.

/// Sport governs how sport-specific surfaces lay out scores and modules.
enum Sport { football, cricket, motorsport, basketball, tennis }
```

### B.7 `lib/blocs/game/game_bloc.dart`

<sub>12 lines</sub>

```dart
// STAND-IN for the host app's GameBloc, the global progression / card-economy
// bloc. The hub only reads it (context.read), so any
// StateStreamable<GameState> works. The source is a Bloc<GameEvent, GameState>:
// `TennisStarterPackOpened` grants the starter athlete card before the hub is
// pushed, and `TennisFinished` banks XP, coins and history (port doc §9).
import 'package:flutter_bloc/flutter_bloc.dart';

import 'game_state.dart';

class GameBloc extends Cubit<GameState> {
  GameBloc([super.initialState = const GameState()]);
}
```

### B.8 `lib/blocs/game/game_state.dart`

<sub>34 lines</sub>

```dart
// STAND-IN for the host app's GameState: only the members the hub reads.
// The hub never names this type; it reads these fields through
// `context.read<GameBloc>().state`.
import '../../models/match.dart';
import '../../models/progression.dart';

/// Stand-in for the source `PlayerCard` (lib/models/cards.dart). Tennis card
/// ids are `tennisTop100` ids (port doc A.4), so the cubit can resolve them.
class PlayerCard {
  const PlayerCard({required this.id, required this.name});

  final String id;
  final String name;
}

class GameState {
  const GameState({
    this.progression = const PlayerProgression(),
    this.matchHistory = const [],
    this.deckTennisPlayers = const [],
    this.deckTennisStarter,
    this.equippedAvatarFrameId,
  });

  final PlayerProgression progression;
  final List<MatchHistoryEntry> matchHistory;

  /// The active deck slot's tennis cards, and its starter.
  final List<PlayerCard> deckTennisPlayers;
  final PlayerCard? deckTennisStarter;

  /// Cosmetic ring shown on the player's matchmaking portrait.
  final String? equippedAvatarFrameId;
}
```

### B.9 `lib/models/avatar_option.dart`

<sub>39 lines</sub>

```dart
// STAND-IN for the host app's lib/models/avatar_option.dart. `AvatarOption`
// and `avatarForName` are verbatim. The source list holds a few dozen
// footballer portraits (`assets/avatar_options/*.webp`); two stand-in entries
// are enough to keep the hash deterministic.
class AvatarOption {
  const AvatarOption({
    required this.id,
    required this.label,
    required this.assetPath,
  });

  final String id;
  final String label;
  final String assetPath;
}

const avatarOptions = [
  AvatarOption(
    id: 'stand-in-a',
    label: 'Stand-in A',
    assetPath: 'assets/avatar_options/stand_in_a.webp',
  ),
  AvatarOption(
    id: 'stand-in-b',
    label: 'Stand-in B',
    assetPath: 'assets/avatar_options/stand_in_b.webp',
  ),
];

/// Deterministic avatar pick from a display [name] — the same name always maps
/// to the same face. Used for leaderboard rows, the rival dossier and the
/// friends roster so a rival looks identical everywhere they appear.
AvatarOption avatarForName(String name) {
  var hash = 0;
  for (final unit in name.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return avatarOptions[hash % avatarOptions.length];
}
```

### B.10 `lib/models/avatar_frame_option.dart`

<sub>28 lines</sub>

```dart
// STAND-IN for the host app's lib/models/avatar_frame_option.dart. The source
// maps each purchasable ring to a real team (league, sports, primary colour,
// coin price). The hub only passes the equipped option through to the
// matchmaking portrait, so this keeps the type and the lookup.
import 'package:flutter/material.dart';

class AvatarFrameOption {
  const AvatarFrameOption({
    required this.id,
    required this.label,
    required this.primary,
  });

  final String id;
  final String label;
  final Color primary;
}

const avatarFrameOptions = <AvatarFrameOption>[];

/// The frame with [id], or null for "none"/unknown (empty equipped slot).
AvatarFrameOption? avatarFrameOptionById(String? id) {
  if (id == null || id.isEmpty) return null;
  for (final option in avatarFrameOptions) {
    if (option.id == id) return option;
  }
  return null;
}
```

### B.11 `lib/widgets/matchmaking/game_match_gate.dart`

<sub>90 lines</sub>

```dart
// STAND-IN for the host app's GameMatchGate. The constructor is verbatim.
// The source runs the shared matchmaking cinematic (GameMatchmakingView: a
// queue search with the config's queue label under a progress bar, the two
// fighters, and a lock-on), then GameKickoffCountdown, which ends on the
// [goLabel] stamp. It calls [onReady] when the countdown lands, or [onCancel]
// once if the player backs out. This stand-in shows both names and hands over
// after a short fixed delay.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/theme.dart';
import 'game_matchmaking_config.dart';

class GameMatchGate extends StatefulWidget {
  const GameMatchGate({
    required this.config,
    required this.onReady,
    required this.onCancel,
    this.goLabel = 'GO!',
    super.key,
  });

  final GameMatchmakingConfig config;
  final VoidCallback onReady;
  final VoidCallback onCancel;

  /// Stamp after the countdown (Pitch Duel: `KICK OFF!`, Hoop: `TIP OFF!`).
  final String goLabel;

  @override
  State<GameMatchGate> createState() => _GameMatchGateState();
}

class _GameMatchGateState extends State<GameMatchGate> {
  /// Stand-in for the source search + countdown, which run several seconds.
  static const handOver = Duration(milliseconds: 1500);

  Timer? _timer;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(handOver, () {
      if (mounted && !_cancelled) widget.onReady();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _timer?.cancel();
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(config.title, style: Cyber.display(18)),
              const SizedBox(height: 8),
              Text(config.queueLabel, style: Cyber.label(9)),
              const SizedBox(height: 16),
              Text(
                '${config.player.name} (${config.player.badge}) VS '
                '${config.opponent.name} (${config.opponent.badge})',
                textAlign: TextAlign.center,
                style: Cyber.body(12),
              ),
              TextButton(onPressed: _cancel, child: const Text('CANCEL')),
            ],
          ),
        ),
      ),
    );
  }
}
```

### B.12 `lib/screens/leaderboard/widgets/game_leaderboard_button.dart`

<sub>56 lines</sub>

```dart
// STAND-IN for the host app's GameLeaderboardButton. The source is a flat
// 40×40 cut-corner plate (panel@0.55 fill, accent@0.5 border, leaderboard
// icon, no glow). A tap plays `uiTap` + a selection haptic and pushes the
// leaderboard already filtered to (sport, mode). Leaving the board for another
// app section pops it and forwards the section to [onNavigate]. A long press
// shows `RANK // <mode label>`. The constructor and `GameMode` are verbatim.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/enums.dart';
import '../../../config/theme.dart';
import '../../../models/sport_match.dart';
import '../../../utils/sound_effects.dart';

enum GameMode { featured, quiz, mystery, shootout, chess, bingo }

class GameLeaderboardButton extends StatelessWidget {
  const GameLeaderboardButton({
    required this.sport,
    required this.mode,
    this.accent = Cyber.cyan,
    this.onNavigate,
    super.key,
  });

  final Sport sport;
  final GameMode mode;
  final Color accent;
  final ValueChanged<AppSection>? onNavigate;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Leaderboard',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          playSound(SoundEffect.uiTap);
          HapticFeedback.selectionClick();
          // Port hook: push your leaderboard for (sport, mode) here.
        },
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
```

### B.13 `lib/screens/match_history/match_history_pages.dart`

<sub>58 lines</sub>

```dart
// STAND-IN for the host app's per-game match history page. The signature of
// showGameMatchHistory is verbatim. The source page is a full-screen fade route:
// a "MATCH HISTORY // <GAME>" header with a close button, the optional
// [career] board, a W/D/L + win% strip, then tappable result rows that open a
// detail page.
import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/match.dart';

void showGameMatchHistory(
  BuildContext context, {
  required String gameLabel,
  required List<MatchHistoryEntry> history,
  Widget? career,
}) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (ctx, a, b) => Scaffold(
        backgroundColor: Cyber.bg,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'MATCH HISTORY // ${gameLabel.toUpperCase()}',
                      style: Cyber.display(16),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: Cyber.cyan),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ?career,
              const SizedBox(height: 14),
              for (final entry in history)
                ListTile(
                  title: Text(entry.resultLabel, style: Cyber.label(12)),
                  subtitle: Text(
                    entry.summary,
                    style: Cyber.body(11, color: Cyber.muted),
                  ),
                ),
            ],
          ),
        ),
      ),
      transitionsBuilder: (ctx, animation, b, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}
```

### B.14 `lib/screens/deck/tennis_deck_builder_screen.dart`

<sub>31 lines</sub>

```dart
// STAND-IN for the host app's TennisDeckBuilderScreen. The source edits the
// active deck slot's tennis cards and starter, then dispatches the save to
// GameBloc. The shipped hub pushes it with `onBack` and `onSaved` both
// popping. Only those two parameters are used here.
import 'package:flutter/material.dart';

import '../../config/theme.dart';

class TennisDeckBuilderScreen extends StatelessWidget {
  const TennisDeckBuilderScreen({
    required this.onBack,
    this.onSaved,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback? onSaved;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: Center(
        child: TextButton(
          onPressed: onBack,
          child: Text('TENNIS DECK', style: Cyber.display(16)),
        ),
      ),
    );
  }
}
```

### B.15 `lib/screens/tennis/tennis_match_screen.dart`

<sub>75 lines</sub>

```dart
// STAND-IN for TennisMatchScreen. Replace this file with Appendix C.1 of the
// Tennis Rally port doc once its host touch-points (§9 there) are wired. The
// constructor is the same, so the hub does not change. The buttons mirror
// C.1: SETTLE records a 6–3 win through `cubit.settle`, like `_finish()`;
// REMATCH abandons, then calls onRestart, like `_restart()`; NEXT ROUND and
// EXIT call their callbacks.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/tennis/tennis_cubit.dart';
import '../../config/theme.dart';
import '../../models/tennis.dart';

class TennisMatchScreen extends StatelessWidget {
  const TennisMatchScreen({
    required this.config,
    required this.onExit,
    required this.onRestart,
    required this.onContinueTournament,
    super.key,
  });

  final TennisMatchConfig config;
  final VoidCallback onExit;
  final VoidCallback onRestart;
  final VoidCallback onContinueTournament;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TennisCubit>();
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${config.mode.label} // '
              '${tennisPlayerById(config.opponentId).name.toUpperCase()}',
              style: Cyber.display(14),
            ),
            TextButton(
              onPressed: () => cubit.settle(
                TennisMatchSummary(
                  matchId: config.matchId,
                  mode: config.mode,
                  playerId: config.playerId,
                  opponentId: config.opponentId,
                  difficulty: config.difficulty,
                  playerGames: 6,
                  opponentGames: 3,
                  won: true,
                  stats: const TennisMatchStats(),
                ),
              ),
              child: const Text('SETTLE'),
            ),
            TextButton(
              onPressed: () async {
                await cubit.abandonMatch();
                onRestart();
              },
              child: const Text('REMATCH'),
            ),
            TextButton(
              onPressed: onContinueTournament,
              child: const Text('NEXT ROUND'),
            ),
            TextButton(onPressed: onExit, child: const Text('EXIT')),
          ],
        ),
      ),
    );
  }
}
```


## Appendix C — Acceptance test

Rename `package:card_game/` to your package name.

### C.1 `test/tennis_rally_hub_test.dart`

<sub>375 lines</sub>

```dart
// Acceptance test for the Tennis Rally hub port. Rename `package:card_game/`
// to your package name.
import 'dart:math';

import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_state.dart';
import 'package:card_game/blocs/tennis/tennis_cubit.dart';
import 'package:card_game/blocs/tennis/tennis_state.dart';
import 'package:card_game/models/match.dart';
import 'package:card_game/models/progression.dart';
import 'package:card_game/models/tennis.dart';
import 'package:card_game/screens/tennis/tennis_hub.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/widgets/cyber/cyber_widgets.dart';
import 'package:card_game/widgets/matchmaking/game_match_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _casper = PlayerCard(id: 'casper-ruud', name: 'Casper Ruud');

GameState _deckState({
  List<MatchHistoryEntry> history = const [],
  int tennisXp = 0,
}) => GameState(
  deckTennisPlayers: const [_casper],
  deckTennisStarter: _casper,
  matchHistory: history,
  progression: PlayerProgression(trackXp: {ProgressTrack.tennis: tennisXp}),
);

void _setWidth(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Steps the clock frame by frame. The entrances start their tickers from
/// timers, so a single long pump would only render their first frame. The
/// emblem pulse, CTA halo and background drift loop forever, so never
/// pumpAndSettle.
Future<void> _advance(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<TennisCubit> _pumpHub(
  WidgetTester tester, {
  GameState gameState = const GameState(),
  bool load = true,
  double width = 800,
  bool v2 = false,
  VoidCallback? onExit,
}) async {
  _setWidth(tester, width);
  final cubit = TennisCubit(SecureGameStorage(), random: Random(7));
  if (load) await cubit.load();
  final gameBloc = GameBloc(gameState);
  addTearDown(cubit.close);
  addTearDown(gameBloc.close);
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider.value(value: cubit),
        BlocProvider.value(value: gameBloc),
      ],
      child: MaterialApp(
        home: v2
            ? TennisRallyV2Hub(onExit: onExit ?? () {})
            : TennisRallyHub(onExit: onExit ?? () {}),
      ),
    ),
  );
  // syncFromDeck runs on the first post-frame callback; let it save.
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await _advance(tester, 1400);
  return cubit;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  // Hub pages scroll when the viewport is short (and the test font is wide).
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _advance(tester, 800);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('TennisRallyHub (shipped)', () {
    testWidgets('spinner while loading, with no app bar', (tester) async {
      await _pumpHub(tester, gameState: _deckState(), load: false);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('an empty tennis deck leaves the spinner up for good', (
      tester,
    ) async {
      await _pumpHub(tester);
      await _advance(tester, 2000);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);
    });

    testWidgets('adopts the deck and lands on the match lobby', (tester) async {
      final cubit = await _pumpHub(tester, gameState: _deckState());
      final profile = cubit.state.profile;
      expect(profile.starterPackClaimed, isTrue);
      expect(profile.ownedPlayerIds, ['casper-ruud']);
      expect(profile.selectedPlayerId, 'casper-ruud');
      expect(profile.lastOpponentId, isNot('casper-ruud'));
      expect(cubit.state.phase, TennisFlowPhase.preview);

      expect(find.text('TENNIS RALLY'), findsWidgets);
      expect(find.text('FAST COURT SHOWDOWN'), findsOneWidget);
      expect(find.text('ATHLETE READY'), findsOneWidget);
      expect(find.text('PLAY MATCH'), findsOneWidget);
      expect(find.text('PRO // SEEDED FAIR PLAY'), findsOneWidget);
      for (final label in ['MASTERY', 'SET WINS', 'STREAK']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('LV 1'), findsOneWidget);
      expect(
        find.text('DRAG TO MOVE // QUICK FLICK TO SPRINT'),
        findsOneWidget,
      );
      // The shipped hub has no mode picker.
      expect(find.text('PLAY MODES'), findsNothing);
    });

    testWidgets('PLAY MATCH → matchmaking → match → EXIT', (tester) async {
      final cubit = await _pumpHub(
        tester,
        gameState: _deckState(tennisXp: 250),
      );

      await _tap(tester, find.text('PLAY MATCH'));
      final config = cubit.state.config!;
      final rival = tennisPlayerById(config.opponentId).name;
      expect(config.mode, TennisMode.quickMatch);
      expect(config.playerId, 'casper-ruud');
      expect(config.difficulty, TennisDifficulty.pro);
      expect(cubit.state.phase, TennisFlowPhase.match);
      expect(find.byType(GameMatchGate), findsOneWidget);
      expect(find.text('SCANNING GLOBAL TENNIS QUEUE'), findsOneWidget);
      // Both badges carry the player's own tennis level.
      expect(find.text('Casper Ruud (LV 3) VS $rival (LV 3)'), findsOneWidget);

      await _advance(tester, 1600);
      expect(find.byType(GameMatchGate), findsNothing);
      expect(
        find.text('QUICK MATCH // ${rival.toUpperCase()}'),
        findsOneWidget,
      );

      await _tap(tester, find.text('EXIT'));
      expect(find.text('PLAY MATCH'), findsOneWidget);
      expect(cubit.state.phase, TennisFlowPhase.preview);
      expect(cubit.state.config, isNull);
    });

    testWidgets('cancelling matchmaking returns to the lobby', (tester) async {
      final cubit = await _pumpHub(tester, gameState: _deckState());
      await _tap(tester, find.text('PLAY MATCH'));
      await _tap(tester, find.text('CANCEL'));
      expect(find.text('PLAY MATCH'), findsOneWidget);
      // The built config is left behind in `match` until the next launch.
      expect(cubit.state.phase, TennisFlowPhase.match);
      expect(cubit.state.config, isNotNull);
    });

    testWidgets('settling re-rolls the lobby underneath the result', (
      tester,
    ) async {
      final cubit = await _pumpHub(tester, gameState: _deckState());
      await _tap(tester, find.text('PLAY MATCH'));
      await _advance(tester, 1600);
      final rival = cubit.state.config!.opponentId;

      await tester.tap(find.text('SETTLE'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await _advance(tester, 200);
      expect(cubit.state.profile.setsWon, 1);
      // The hub is still mounted under the match route and re-prepares.
      expect(cubit.state.phase, TennisFlowPhase.preview);
      expect(cubit.state.summary, isNull);
      expect(cubit.state.profile.lastOpponentId, isNot(rival));
      expect(find.text('SETTLE'), findsOneWidget);
    });

    testWidgets('REMATCH returns to the lobby instead of relaunching', (
      tester,
    ) async {
      final cubit = await _pumpHub(tester, gameState: _deckState());
      await _tap(tester, find.text('PLAY MATCH'));
      await _advance(tester, 1600);
      await tester.tap(find.text('REMATCH'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await _advance(tester, 800);
      expect(find.text('PLAY MATCH'), findsOneWidget);
      expect(find.byType(GameMatchGate), findsNothing);
      expect(cubit.state.phase, TennisFlowPhase.preview);
    });

    testWidgets('a saved match offers RESUME and skips matchmaking', (
      tester,
    ) async {
      const saved = TennisMatchConfig(
        matchId: 'saved-1',
        mode: TennisMode.quickMatch,
        playerId: 'casper-ruud',
        opponentId: 'taylor-fritz',
        difficulty: TennisDifficulty.allStar,
        seed: 3,
      );
      await SecureGameStorage().saveTennisMatchSnapshot(
        const TennisMatchSnapshot(
          config: saved,
          engine: <String, dynamic>{},
          savedAtMillis: 0,
        ),
      );
      final cubit = await _pumpHub(tester, gameState: _deckState());
      expect(find.text('MATCH SAVED'), findsOneWidget);
      expect(find.text('RESUME MATCH'), findsOneWidget);

      await _tap(tester, find.text('RESUME MATCH'));
      expect(find.byType(GameMatchGate), findsNothing);
      expect(find.text('QUICK MATCH // TAYLOR FRITZ'), findsOneWidget);
      expect(cubit.state.config!.matchId, 'saved-1');
    });

    testWidgets('DECK BUILDER opens and closes', (tester) async {
      await _pumpHub(tester, gameState: _deckState());
      await _tap(tester, find.text('DECK BUILDER'));
      expect(find.text('TENNIS DECK'), findsOneWidget);
      await _tap(tester, find.text('TENNIS DECK'));
      expect(find.text('PLAY MATCH'), findsOneWidget);
    });

    testWidgets('match history: tennis only, with a 100-row mastery board', (
      tester,
    ) async {
      await _pumpHub(
        tester,
        gameState: _deckState(
          history: const [
            MatchHistoryEntry(
              id: 'tn-1',
              mode: 'tennis',
              resultLabel: 'Victory',
              summary: 'Beat Taylor Fritz 6-3',
            ),
            MatchHistoryEntry(
              id: 'gp-1',
              mode: 'grandprix',
              resultLabel: 'Defeat',
              summary: 'Grand Prix loss',
            ),
          ],
        ),
      );
      await _tap(tester, find.text('MATCH HISTORY'));
      expect(find.text('MATCH HISTORY // TENNIS RALLY'), findsOneWidget);
      for (final label in [
        'CAREER',
        'TROPHY CABINET',
        'ATHLETE MASTERY',
        'ACHIEVEMENTS',
        'RECENT MATCHES',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(
        find.byType(CyberProgressBar),
        findsNWidgets(tennisPlayers.length),
      );
      expect(tennisPlayers.length, 100);
      expect(find.text('CHAMPION'), findsOneWidget);
      // The recent matches sit below all 100 mastery rows.
      expect(find.text('Beat Taylor Fritz 6-3'), findsNothing);
      for (var i = 0; i < 20; i++) {
        if (find.text('Beat Taylor Fritz 6-3').evaluate().isNotEmpty) break;
        await tester.drag(find.byType(ListView).last, const Offset(0, -900));
        await tester.pump();
      }
      expect(find.text('Beat Taylor Fritz 6-3'), findsOneWidget);
      expect(find.text('Grand Prix loss'), findsNothing);
    });

    for (final width in [420.0, 800.0]) {
      testWidgets('lobby lays out without overflow at ${width.toInt()} px', (
        tester,
      ) async {
        await _pumpHub(tester, gameState: _deckState(), width: width);
        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(find.text('PLAY MATCH')).right,
          lessThanOrEqualTo(width),
        );
      });
    }
  });

  group('TennisRallyV2Hub (built, not routed)', () {
    testWidgets('landing lists five modes and opens the training lab', (
      tester,
    ) async {
      await _pumpHub(tester, v2: true);
      for (final label in [
        'QUICK MATCH',
        'TOURNAMENT',
        'TRAINING',
        'ENDLESS RALLY',
        'TARGET PRACTICE',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      await _tap(tester, find.text('TRAINING'));
      expect(find.text('TRAINING LAB'), findsOneWidget);
      expect(find.text('0/8 COMPLETE'), findsOneWidget);
      expect(find.text('START'), findsNWidgets(8));
    });

    testWidgets('tournament view drafts a bracket', (tester) async {
      final cubit = await _pumpHub(tester, v2: true);
      await _tap(tester, find.text('TOURNAMENT'));
      // ReactHeaderBar upper-cases the 'STAToz OPEN' title.
      expect(find.text('STATOZ OPEN'), findsOneWidget);
      expect(cubit.state.profile.tournament?.active, isTrue);
      expect(find.text('PLAY QUARTERFINAL'), findsOneWidget);
      expect(find.text('THREE WINS TO THE TROPHY'), findsOneWidget);
      expect(find.text('0/3'), findsOneWidget);
    });

    testWidgets('player select lists the whole 100-athlete roster', (
      tester,
    ) async {
      await _pumpHub(tester, v2: true);
      await _tap(tester, find.text('ENDLESS RALLY'));
      expect(find.text('PLAYER SELECT'), findsOneWidget);
      expect(find.text('SESSION PREVIEW'), findsOneWidget);
      // Every unowned athlete falls through to the old roster's fallback.
      expect(
        find.text('STARTER', skipOffstage: false),
        findsNWidgets(tennisPlayers.length),
      );
    });

    testWidgets('settings persist, but every switch trips a ListTile '
        'assertion', (tester) async {
      final cubit = await _pumpHub(tester, v2: true);
      final errors = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) =>
          errors.add(details.exceptionAsString().split('\n').first);
      addTearDown(() => FlutterError.onError = previous);

      await _tap(tester, find.byTooltip('Tennis settings'));
      expect(find.text('TENNIS SETTINGS'), findsOneWidget);
      await _tap(tester, find.text('LEFT-HANDED CONTROL LAYOUT'));
      FlutterError.onError = previous;

      expect(cubit.state.profile.settings.leftHanded, isTrue);
      expect(errors, isNotEmpty);
      expect(errors.toSet(), {
        'ListTile background color or ink splashes may be invisible.',
      });
    });
  });
}
```
