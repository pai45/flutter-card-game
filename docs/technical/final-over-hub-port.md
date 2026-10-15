# Final Over Hub — Implementation & Porting Reference

> **Status:** BUILT · **Written:** 2026-09-17 · **Audience:** Flutter engineers rebuilding the Final Over lobby in another project
>
> **Source of truth:**
> [`lib/screens/final_over/final_over_hub.dart`](../../lib/screens/final_over/final_over_hub.dart)
> covers `FinalOverHub`, `_PitchStatusBar`, `_HeroRow`, `_TierPicker`,
> `_RecordPanel` and `_RecordStat`.
>
> Supporting files:
> - `lib/screens/final_over/widgets/final_over_arena_background.dart`
> - `lib/widgets/matchmaking/matchmaking_arena_background.dart`
> - `lib/widgets/game_scaffold.dart` (`ReactHeaderBar`)
> - `lib/widgets/cyber/cyber_widgets.dart` (entrances, pulse, texture, `CyberCtaButton`)
> - `lib/app.dart` (cubit provider and the route push)
>
> **Companion to [Final Over (cricket) port](final-over-cricket-port.md).**
> That doc ports the engine, renderer, cubit and play layer. Its §3 lists the
> hub as "not ported", and its checklist step 3 just says "build a hub". This
> doc fills that gap. **Port that doc first:** this one reuses its A.5
> (models), A.6 (kits), A.7 (rival names), A.8/A.9 (cubit), D.1 (theme),
> D.2 (storage), D.4 (cyber widgets) and D.5 (`HudCtaButton`) unchanged.
>
> **This document is self-contained on top of that one.** Appendix A is
> copied **verbatim** from the source by script. Appendix B holds stand-ins
> for host systems the hub only reads. Appendix C is the acceptance test.
> Written on top of the main doc's files, the app analyzes clean and all
> tests pass (§10).

---

## 1. What the hub is

The hub is the **Final Over lobby**. It is the one screen between "I want to
play cricket" and the chase. The player's path through it:

1. See their Final Over level.
2. Pick a difficulty tier.
3. Either **TAKE GUARD** (squad ready) or **BUILD SQUAD** (squad missing).
4. Optionally open the deck or the match history.

**Entry.** The hub is opened from **Sports → Games → Cricket → Final Over**
and from the Trending hero tile
([arcade tiles doc](arcade-trending-hero-tiles.md)):

- Both go through `_openFinalOver()` in `lib/app.dart`.
- That wraps the push in `_enterCricketGameFlow`. On first entry, it opens
  the free **cricket starter pack** and pushes the hub only after the reveal.
- The hub is a plain `MaterialPageRoute`:
  `FinalOverHub(onExit: navigator.pop)`.

Top to bottom (max width 440, centered, padding 20 / 16 / 20 / 24):

| # | Element | Content | Entrance |
|---|---|---|---|
| — | App bar | `ReactHeaderBar(showTitle: false)`: back arrow → `onExit`. Right slot: `PlayerLevelBadge(track: finalOver)`, 6 px gap, then `GameLeaderboardButton(sport: cricket, mode: featured)` | none |
| 1 | Status bar | 7 px cyan dot with `Cyber.glow(cyan, alpha .8, blur 8)` + `SYS://FINAL_OVER v1.0.0 — PITCH READY` (label 8.5, muted, 1 line, ellipsis) | rise-in, 0 ms |
| 2 | Hero row | 58 px round `Cyber.panel` badge. Its 1.6 px cyan border pulses between alpha .40 and .75 (`CyberPulse`, 2200 ms each way). Cricket icon (26). Beside it: `FINAL OVER` (display 24, white, spacing 2), `THREE OVERS. FIVE BATTERS. ONE CHASE.` (label 8.5, muted), and a `CyberChip` with the selected tier's **blurb** | rise-in, 80 ms |
| 3 | Section label | `CHASE TIER` | none |
| 4 | Tier picker | Three equal chamfered tiles (`HudChamferClipper(10, 3)`), 8 px apart. Each shows label (display 12) over target range (label 8, tabular) | rise-in, 240 ms |
| 5 | Primary CTA | `HudCtaButton`, cyan. **Ready:** `TAKE GUARD` / `<TIER> // TARGET <lo>–<hi>`. **Not ready:** `BUILD SQUAD` / `PICK 3 OWNED BATTERS TO CHASE` (see §8.1) | rise-in, 320 ms |
| 6 | Secondary row | Two `CyberCtaButton(clip: false)`, 12 px apart: `CRICKET DECK` and `MATCH HISTORY` (labels are upper-cased by the button) | dealt, index 0 / 1 |

Vertical gaps: 14 · 18 · 10 · 22 · 14.

**Tiers** come from `FinalOverTier` (port doc A.5). The hub reads only
`label`, `range` and `blurb`:

| Tier | Range | Blurb (hero chip) |
|---|---|---|
| ROOKIE | 32–40 | GET YOUR EYE IN |
| PRO | 44–56 | THE HONEST CHASE |
| ELITE | 58–66 | BOUNDARIES OR BUST |

The default tier is **ROOKIE** (`FinalOverStats()`).

## 2. Widget tree

```
BlocBuilder<GameBloc, GameState>          buildWhen: progression | matchHistory |
 │                                                   finalOverDeckReady | ownedFinalOverKitIds
 │  cubit.ensureEquippedKitOwned(ownedFinalOverKitIds)     ← side effect in build (§8.5)
 └ BlocBuilder<FinalOverCubit, FinalOverState>            (no buildWhen)
    ├ !loaded → Scaffold(bg: Cyber.bg) → CircularProgressIndicator(cyan)   (no app bar)
    └ Scaffold(bg: Cyber.bg)
       ├ appBar: ReactHeaderBar(title 'FINAL OVER', subtitle '// THREE-OVER CHASE',
       │                         showTitle: false, onBack: onExit, rightSlot: badge + board)
       └ body: FinalOverArenaBackground
          └ SafeArea(top: false) → LayoutBuilder
             └ SingleChildScrollView(padding 20/16/20/24)
                └ ConstrainedBox(minHeight: viewport height) → Center
                   └ ConstrainedBox(maxWidth: 440) → Column(center, stretch)
                      ├ CyberSlideUpFadeIn(_PitchStatusBar)
                      ├ CyberSlideUpFadeIn(80 ms, _HeroRow(tier))
                      ├ SectionLabel('CHASE TIER')
                      ├ CyberSlideUpFadeIn(240 ms, _TierPicker(selected))
                      ├ CyberSlideUpFadeIn(320 ms, HudCtaButton)
                      └ Row[ Expanded(CyberDealtCard(0, 'Cricket Deck')),
                             Expanded(CyberDealtCard(1, 'Match History')) ]
```

**Backdrop.** `FinalOverArenaBackground` is a one-line wrapper. It calls
`MatchmakingArenaBackground(asset: 'assets/backgrounds/final_over_arena.jpg')`,
which stacks:

1. a vertical `#02060F → #06121F → #01040A` gradient
2. the arena JPEG at **45 %** opacity, drifting on a **20 s** loop
   (±6 px x, ±4 px y, scale 1.05 ± 0.008)
3. a `bg@.28 → clear → bg@.6` scrim
4. `CyberTextureOverlay`: 1 px scanlines every 3 px at black@.14, plus a
   radial vignette
5. the content

A missing image falls back to `SizedBox.shrink()` through `errorBuilder`, so
the hub still looks right without the JPEG.

**Tier tile states** (`AnimatedContainer`, 160 ms):

| | Fill | Border | Label |
|---|---|---|---|
| Selected | `cyan@.16` | `cyan@.9`, 1.5 px | cyan |
| Idle | `panel@.8` | `Cyber.border`, 1 px | muted |

The range line is always muted.

## 3. State and data flow

The hub reads two state holders:

| Source | Scope in the source app | What the hub reads |
|---|---|---|
| `FinalOverCubit` (port doc A.9) | App-level: `BlocProvider(create: (_) => FinalOverCubit(SecureGameStorage())..load())` in `lib/app.dart` | `loaded`, `tier`, `stats`. It also calls `ensureEquippedKitOwned`, `selectTier`, `buildMatch` and `backToLobby` |
| `GameBloc` (host, stand-in B.2/B.3) | App-level | `progression` (level badge), `matchHistory` (history page), `finalOverDeckReady`, `deckFinalOverBatsmen`, `ownedFinalOverKitIds` |

**Readiness** is the source getter, verbatim in B.3:

```dart
bool get finalOverDeckReady =>
    deckFinalOverBatsmen.length == 5 &&
    deckFinalOverBatsmen.every((card) => ownedCardIds.contains(card.id));
```

### Actions

| Trigger | Code path | Result |
|---|---|---|
| Tier tile tap | `playSound(uiTap)` → `HapticFeedback.selectionClick()` → `cubit.selectTier(tier)` | No-op if unchanged. Otherwise emits and **persists** `FinalOverStats.tier` (`pd_final_over_stats_v1`). The chip blurb and CTA helper update on the same frame |
| CTA, ready | `_startMatch` | Collects the **5** squad ids. `cubit.buildMatch(batsmanIds:)` then builds a seeded config (target drawn from the tier ladder, equipped kit, rival name, `showHints` on the first chase) and moves the phase to `intro`. Pushes `BlocProvider.value(cubit) → FinalOverMatchScreen(config, onExit)` |
| Match `onExit` | `Navigator.pop` → `cubit.backToLobby()` | Phase → `idle`, summary cleared |
| CTA, not ready | `_openDeckBuilder` | Pushes `FinalOverDeckBuilderScreen(onBack: pop)`. When the squad is saved, `GameBloc` emits, `finalOverDeckReady` flips, and the outer builder swaps the CTA to TAKE GUARD |
| CRICKET DECK | `_openDeckBuilder` | Same screen. This is also where the **kit picker** lives |
| MATCH HISTORY | `showGameMatchHistory(gameLabel: 'Final Over', history: matchHistory.where(isFinalOver), career: _RecordPanel(stats))` | A full-screen fade route with the career board on top. `stats` is captured at tap time |
| Level badge tap | (inside the badge) | Expands 132 → 222 px to show NEXT XP and the track total |
| Leaderboard tap | (inside the button) | `uiTap` + selection haptic, then pushes the leaderboard filtered to Cricket / featured |
| Back | `onExit` | The host pops the route |

**Career board** (`_RecordPanel`) is a `CyberPanel(accent: cyan)` with a
`CAREER` label and five equal columns. Each column shows a value
(display 18, white, tabular) over a label (label 7.5, muted):

| Column | Source |
|---|---|
| BEST | `bestScore` |
| WON | `wins` |
| WIN RATE | `winRate` (`—` before the first chase, else a rounded `%`) |
| SIXES | `sixes` |
| BEST ★ | `bestStars` |

**The hub never owns a match.** Everything after `buildMatch` is the
match screen's contract (port doc §7): intro → `beginPlay`, `onMatchEnded`,
`abandonMatch` on dispose. The `BlocProvider.value` around the match route
is redundant when the cubit is app-level, as in the source. Keep it if your
cubit is scoped to the hub route.

### Wiring

```dart
// App root
MultiBlocProvider(
  providers: [
    BlocProvider(create: (_) => GameBloc(/* your progression + card state */)),
    BlocProvider(create: (_) => FinalOverCubit(SecureGameStorage())..load()),
  ],
  child: MaterialApp(/* … */),
);

// GAMES → Cricket → Final Over (gate on your starter pack first)
void openFinalOver(BuildContext context) {
  final navigator = Navigator.of(context);
  navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => FinalOverHub(onExit: navigator.pop),
    ),
  );
}
```

## 4. Gratification and feedback

The hub is short, so its job is **speed to the chase**, with enough motion
to feel alive:

| Moment | Feedback |
|---|---|
| Arrive | **Staggered rise-in** at 0 / 80 / 240 / 320 ms: 480 ms `easeOutCubic`, 30 px lift, fade from 0. **Dealt** secondary buttons: start at 220 + 75 × index ms, 540 ms long; fly up 260 px (`easeOutCubic`), alternate ±0.07 rad tilt that straightens, scale 0.92 → 1 (`easeOutBack`), fade over the first 45 % |
| Idle | Hero badge border pulse (2.2 s each way). `HudCtaButton` halo breathes 0.25 → 0.70 over 1.8 s. The arena drifts |
| Tier pick | `uiTap` + selection haptic. The tile cross-fades fill and border (160 ms). The hero chip and CTA helper re-read the new tier at once |
| CTA press | Halo goes to full on press-down. On tap: **medium** haptic + `SoundEffect.playMatch` (the button's default `tapSound`), then navigation |
| Squad saved | On return, the CTA reads TAKE GUARD with the tier's target range. That is the "you're ready" beat |

The big payoffs (bowler reveal, SIX stings, result cinematic, XP and
level-up) belong to the match screen (port doc §8 and C.2). The hub only
sets up the chase.

## 5. Design rules carried by this code

- **Glow is scarce.** Only two things glow: the live status dot and the
  primary CTA's halo. The selected tier uses fill and border, never a glow.
  The level badge and the leaderboard button are flat chrome. The secondary
  buttons carry a *dark* `bg@.3` shadow, not a glow.
- **Shape.** The tier tiles use the 10/3 diagonal chamfer, and
  `HudCtaButton` has its own clipped plate. The secondary row passes
  `clip: false`, so it is square-cornered with a 1 px `Cyber.line` border.
  Keep that for parity.
- **Colour and type.** Everything comes from `Cyber` tokens and the
  `display` / `label` styles. The only raw hex values are the arena gradient
  and the header-bar gradient (`#0B1120 → #070B14`, bottom rule `#1E2538`),
  exactly as in the source.
- **Numbers are tabular**: tier ranges and career values.
- **One primary action.** Only the CTA changes with state. Everything else is
  static, so the player's eye lands on it.

## 6. Host touch-points (Appendix B)

| Source symbol | Stand-in | Replace with |
|---|---|---|
| `GameBloc` / `GameState` | B.2 / B.3: a `Cubit` with the five fields the hub reads, plus `saveFinalOverDeck` | Your progression and card-economy store. It must expose the squad (5 ids), squad ownership, owned kit ids, XP and history |
| `MatchHistoryEntry` | B.4 | Your history model. The hub needs only `isFinalOver` (`mode == 'finalover'`) |
| `PlayerProgression`, `ProgressTrack` | B.5 | Your XP tracks |
| `Sport` | B.6 (verbatim enum) | Your sport enum |
| `PlayerLevelBadge` | B.7 (collapsed read-out only) | Your level chip. The source's expanding behaviour is described in B.7's header |
| `GameLeaderboardButton`, `GameMode` | B.8 (verbatim enum, `onOpen` hook) | Your leaderboard route |
| `showGameMatchHistory` | B.9 (verbatim signature) | Your history page. Keep the `career` slot above the results |
| `FinalOverDeckBuilderScreen` | B.10 (verbatim constructor; saves 5 placeholder ids) | Your squad editor plus the kit picker (source: 5 slots, owned batters sorted by rating) |
| `FinalOverMatchScreen` | B.11 (same constructor) | Port doc **C.1**, once its §9 touch-points are wired |
| `SoundEffect.uiTap` | B.1 (**replaces** port doc D.3 and adds `uiTap`) | Your UI tap cue |

## 7. File map and port checklist

| Target path | Contents | Where |
|---|---|---|
| `lib/screens/final_over/final_over_hub.dart` | The hub (verbatim, whole file) | A.1 |
| `lib/screens/final_over/widgets/final_over_arena_background.dart` | Arena wrapper (verbatim, whole file) | A.2 |
| `lib/widgets/matchmaking/matchmaking_arena_background.dart` | Drifting arena bed (verbatim, whole file) | A.3 |
| `lib/widgets/game_scaffold.dart` | `ReactHeaderBar` (verbatim subset) | A.4 |
| `lib/widgets/cyber/cyber_hub_widgets.dart` | `CyberTextureOverlay`, `HudLine`, `CyberCtaButton`, `CyberSlideUpFadeIn`, `CyberPulse`, `CyberDealtCard` (verbatim declarations) | A.5 |
| `lib/utils/sound_effects.dart` | **Stand-in**, replaces port doc D.3 | B.1 |
| `lib/blocs/game/game_bloc.dart`, `game_state.dart` | **Stand-ins** | B.2, B.3 |
| `lib/models/match.dart`, `progression.dart`, `sport_match.dart` | **Stand-ins** | B.4–B.6 |
| `lib/widgets/player_level_badge.dart` | **Stand-in** | B.7 |
| `lib/screens/leaderboard/widgets/game_leaderboard_button.dart` | **Stand-in** | B.8 |
| `lib/screens/match_history/match_history_pages.dart` | **Stand-in** | B.9 |
| `lib/screens/final_over/final_over_deck_builder_screen.dart` | **Stand-in** | B.10 |
| `lib/screens/final_over/final_over_match_screen.dart` | **Stand-in** until you port C.1 | B.11 |
| `test/final_over_hub_test.dart` | Widget tests | C.1 |

Checklist:

1. Port [final-over-cricket-port.md](final-over-cricket-port.md) (package,
   A, B, D) and make its tests pass.
2. Copy A.1–A.5, B.1–B.11 and C.1 to the listed paths. B.1 overwrites D.3.
   If your project already has any of the B systems, map them onto yours
   and keep the names the hub imports.
3. In the port doc's `lib/widgets/cyber/cyber_widgets.dart` (D.4), add this
   line right after its imports. The hub imports that one file for
   everything, as in the source:
   ```dart
   export 'cyber_hub_widgets.dart';
   ```
4. Optional: add `assets/backgrounds/final_over_arena.jpg` (a dark stadium
   plate; the source file is a 64 KB JPEG) and list it under
   `flutter: assets:`. Without it the backdrop is gradient + texture only.
5. Provide `FinalOverCubit(...)..load()` and your `GameBloc` above
   `MaterialApp`, and push the hub from your games list (§3 Wiring).
6. Replace B.11 with the port doc's C.1 once XP, audio and matchmaking are
   wired.
7. Fix the copy in §8.1, then update the string in C.1.
8. Run `flutter analyze` and `flutter test test/final_over_hub_test.dart`.
9. On device, check at 320 px, a normal phone, and a tablet:
   - the entrances play once
   - a tier tap clicks and the CTA helper follows
   - BUILD SQUAD → save → TAKE GUARD
   - TAKE GUARD → match → back lands in the lobby
   - history shows only Final Over results under CAREER

## 8. Known issues and copy notes

Kept verbatim in Appendix A; fix them in your port if you like.

1. **Squad size copy is stale.** The not-ready helper says
   `PICK 3 OWNED BATTERS TO CHASE`, but readiness needs **5** owned batters.
   The deck builder's subtitle is `// 5-BAT CHASE UNIT`, and the hero line
   says "FIVE BATTERS". Suggested copy: `PICK 5 OWNED BATTERS TO CHASE`. The
   port doc's §7/§11 also say "3 batsman ids". The source hub passes all
   five: the renderer takes `[0]` and `[1]` as striker and partner, and the
   rest walk in as wickets fall.
2. **The career record is not on the hub surface.** It appears only inside
   MATCH HISTORY.
3. **The kit picker is not on the hub.** It lives in the deck builder and
   the Shop. The hub only clamps an unowned equipped kit back to the free
   kit (`voltage`).
4. **The `blurb` doc comment is out of date.** In A.5 it says "the blurb under
   the tier tile", but the hub shows it as the hero chip.
5. **`ensureEquippedKitOwned` runs inside `build`.** This is safe with
   `flutter_bloc`, because a cubit's stream delivers asynchronously. If you
   port to a synchronous notifier (`ValueNotifier`, Riverpod), this would
   emit during build. Move it to a `BlocListener`, or to where
   `ownedFinalOverKitIds` changes.
6. **The loading scaffold has no app bar**, so there is no back button until
   stats load. Loading is one `SharedPreferences` read, so this is rarely
   visible.
7. **There is always ~40 px of scroll.** `minHeight` is the unpadded
   viewport height, but the scroll view adds 16 + 24 px of padding. On short
   screens, the secondary row sits below the fold (the test scrolls to it).
8. **The status line hard-codes `v1.0.0`.**
9. **`ReactHeaderBar` is given a title and subtitle but `showTitle: false`.**
   The hero row is the visible title.

## 9. Acceptance test (Appendix C)

`test/final_over_hub_test.dart` runs **9 widget tests**:

| Test | What it proves |
|---|---|
| spinner until load | The `!loaded` branch |
| BUILD SQUAD → deck → TAKE GUARD | Readiness drives the CTA. The helper copy (currently the stale "3") and the ROOKIE default |
| tier pick | `selectTier` persists `"elite"`. The helper and blurb follow. TAKE GUARD builds an `intro` config with an ELITE-ladder target, the 5 ids and first-chase hints. Exiting returns to `idle` and the lobby |
| kit fallback | A stored `ember` kit with only `voltage` owned is clamped to `voltage` |
| match history | Only `finalover` entries are listed. The CAREER board shows BEST 61 and WIN RATE 75 % |
| back | `onExit` fires |
| 320 / 390 / 600 px | No layout exceptions, and the tier row stays inside the view |

**Testing note.** The entrances start their tickers from `Timer`s, so a
single long `pump(d)` renders only their *first* frame. That leaves the
dealt buttons near their 260 px start, off-screen. The test steps the clock in 50 ms
frames (`_advance`). It never calls `pumpAndSettle`, because the pulse and
the arena drift repeat forever.

## 10. Verification performed for this document

A script read **only this markdown file and the port doc**. It:

- wrote the port doc's Appendix P into `final_over/` with its §4.1 manifest
- wrote the port doc's A, B, D and E into an empty Flutter app
  (`card_game`, Flutter 3.44.4, the §4.2 dependencies plus `flutter_lints`)
- wrote this doc's A, B and C on top (B.1 over D.3)
- added the `export` line from §7 step 3

Results:

- **Verbatim check:** A.1–A.3 are byte-identical to the source files. The
  one exception is A.2: the source has no trailing newline, and the
  extracted block ends with one. A.4 and A.5 are whole declarations cut
  from the source by name, under a new header comment.
- **Analyze:** `flutter analyze` → **No issues found!**
- **App tests:** `flutter test` → **13 tests, all passed** (C.1's 9 plus
  the port doc's 4 balance tests).
- **Package tests:** `flutter test` inside `final_over/` → **56 tests, all
  passed**.
- **Not checked:** the real `GameBloc`, `PlayerLevelBadge`, leaderboard,
  history page, deck builder and match screen (all stand-ins here), and a
  pixel comparison against the source app.

---


## Appendix A — Hub files (verbatim)

Copy each block to the path in its heading.

### A.1 `lib/screens/final_over/final_over_hub.dart`

<sub>399 lines</sub>

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/final_over/final_over_cubit.dart';
import '../../blocs/final_over/final_over_state.dart';
import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_state.dart';
import '../../config/theme.dart';
import '../../models/final_over.dart';
import '../../models/progression.dart';
import '../../models/sport_match.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import '../../widgets/player_level_badge.dart';
import '../leaderboard/widgets/game_leaderboard_button.dart';
import '../match_history/match_history_pages.dart';
import 'final_over_deck_builder_screen.dart';
import 'final_over_match_screen.dart';
import 'widgets/final_over_arena_background.dart';

/// The Final Over lobby. Tier selection, primary CTA, and secondary links.
class FinalOverHub extends StatelessWidget {
  const FinalOverHub({required this.onExit, super.key});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      buildWhen: (p, c) =>
          p.progression != c.progression ||
          p.matchHistory != c.matchHistory ||
          p.finalOverDeckReady != c.finalOverDeckReady ||
          p.ownedFinalOverKitIds != c.ownedFinalOverKitIds,
      builder: (context, gameState) {
        context.read<FinalOverCubit>().ensureEquippedKitOwned(
          gameState.ownedFinalOverKitIds,
        );
        return BlocBuilder<FinalOverCubit, FinalOverState>(
          builder: (context, state) {
            if (!state.loaded) {
              return const Scaffold(
                backgroundColor: Cyber.bg,
                body: Center(
                  child: CircularProgressIndicator(color: Cyber.cyan),
                ),
              );
            }
            final ready = gameState.finalOverDeckReady;
            return Scaffold(
              backgroundColor: Cyber.bg,
              appBar: ReactHeaderBar(
                title: 'FINAL OVER',
                subtitle: '// THREE-OVER CHASE',
                showTitle: false,
                onBack: onExit,
                rightSlot: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlayerLevelBadge(
                      progression: gameState.progression,
                      track: ProgressTrack.finalOver,
                    ),
                    const SizedBox(width: 6),
                    const GameLeaderboardButton(
                      sport: Sport.cricket,
                      mode: GameMode.featured,
                    ),
                  ],
                ),
              ),
              body: FinalOverArenaBackground(
                child: SafeArea(
                  top: false,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 440),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const CyberSlideUpFadeIn(child: _PitchStatusBar()),
                                  const SizedBox(height: 14),
                                  CyberSlideUpFadeIn(
                                    delay: const Duration(milliseconds: 80),
                                    child: _HeroRow(tier: state.tier),
                                  ),
                                  const SizedBox(height: 18),
                                  const SectionLabel(label: 'CHASE TIER'),
                                  const SizedBox(height: 10),
                                  CyberSlideUpFadeIn(
                                    delay: const Duration(milliseconds: 240),
                                    child: _TierPicker(selected: state.tier),
                                  ),
                                  const SizedBox(height: 22),
                                  CyberSlideUpFadeIn(
                                    delay: const Duration(milliseconds: 320),
                                    child: HudCtaButton(
                                      label: ready ? 'TAKE GUARD' : 'BUILD SQUAD',
                                      icon: Icons.sports_cricket_rounded,
                                      accent: Cyber.cyan,
                                      helper: ready
                                          ? '${state.tier.label} // TARGET ${state.tier.range}'
                                          : 'PICK 3 OWNED BATTERS TO CHASE',
                                      onTap: () => ready
                                          ? _startMatch(context, gameState)
                                          : _openDeckBuilder(context),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: CyberDealtCard(
                                          index: 0,
                                          child: CyberCtaButton(
                                            label: 'Cricket Deck',
                                            clip: false,
                                            onPressed: () =>
                                                _openDeckBuilder(context),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: CyberDealtCard(
                                          index: 1,
                                          child: CyberCtaButton(
                                            label: 'Match History',
                                            clip: false,
                                            onPressed: () =>
                                                showGameMatchHistory(
                                              context,
                                              gameLabel: 'Final Over',
                                              history: gameState.matchHistory
                                                  .where((e) => e.isFinalOver)
                                                  .toList(growable: false),
                                              career: _RecordPanel(
                                                stats: state.stats,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
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
              ),
            );
          },
        );
      },
    );
  }

  void _openDeckBuilder(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FinalOverDeckBuilderScreen(onBack: () => Navigator.of(context).pop()),
      ),
    );
  }

  void _startMatch(BuildContext context, GameState gameState) {
    final cubit = context.read<FinalOverCubit>();
    final batsmanIds =
        gameState.deckFinalOverBatsmen.map((card) => card.id).toList();
    final config = cubit.buildMatch(batsmanIds: batsmanIds);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: FinalOverMatchScreen(
            config: config,
            onExit: () {
              Navigator.of(context).pop();
              cubit.backToLobby();
            },
          ),
        ),
      ),
    );
  }
}

class _PitchStatusBar extends StatelessWidget {
  const _PitchStatusBar();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Cyber.cyan,
          boxShadow: Cyber.glow(Cyber.cyan, alpha: 0.8, blur: 8),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          'SYS://FINAL_OVER v1.0.0 — PITCH READY',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Cyber.label(8.5, color: Cyber.muted, letterSpacing: 1.4),
        ),
      ),
    ],
  );
}

class _HeroRow extends StatelessWidget {
  const _HeroRow({required this.tier});
  final FinalOverTier tier;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      CyberPulse(
        period: const Duration(milliseconds: 2200),
        builder: (context, t) => Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Cyber.panel,
            border: Border.all(
              color: Cyber.cyan.withValues(alpha: 0.4 + 0.35 * t),
              width: 1.6,
            ),
          ),
          child: const Icon(
            Icons.sports_cricket_rounded,
            color: Cyber.cyan,
            size: 26,
          ),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FINAL OVER',
              style: Cyber.display(24, color: Colors.white, letterSpacing: 2),
            ),
            const SizedBox(height: 4),
            Text(
              'THREE OVERS. FIVE BATTERS. ONE CHASE.',
              style: Cyber.label(8.5, color: Cyber.muted, letterSpacing: 1.4),
            ),
            const SizedBox(height: 8),
            CyberChip(label: tier.blurb, color: Cyber.cyan),
          ],
        ),
      ),
    ],
  );
}

class _RecordPanel extends StatelessWidget {
  const _RecordPanel({required this.stats});
  final FinalOverStats stats;

  @override
  Widget build(BuildContext context) => CyberPanel(
    accent: Cyber.cyan,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel(label: 'CAREER'),
        const SizedBox(height: 12),
        Row(
          children: [
            _RecordStat('BEST', '${stats.bestScore}'),
            _RecordStat('WON', '${stats.wins}'),
            _RecordStat('WIN RATE', stats.winRate),
            _RecordStat('SIXES', '${stats.sixes}'),
            _RecordStat('BEST ★', '${stats.bestStars}'),
          ],
        ),
      ],
    ),
  );
}

class _RecordStat extends StatelessWidget {
  const _RecordStat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Cyber.display(
            18,
            color: Colors.white,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Cyber.label(7.5, color: Cyber.muted, letterSpacing: 1),
        ),
      ],
    ),
  );
}

class _TierPicker extends StatelessWidget {
  const _TierPicker({required this.selected});
  final FinalOverTier selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final tier in FinalOverTier.values) ...[
          Expanded(
            child: GestureDetector(
              onTap: () {
                playSound(SoundEffect.uiTap);
                HapticFeedback.selectionClick();
                context.read<FinalOverCubit>().selectTier(tier);
              },
              child: ClipPath(
                clipper: const HudChamferClipper(bigCut: 10, smallCut: 3),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: tier == selected
                        ? Cyber.cyan.withValues(alpha: 0.16)
                        : Cyber.panel.withValues(alpha: 0.8),
                    border: Border.all(
                      color: tier == selected
                          ? Cyber.cyan.withValues(alpha: 0.9)
                          : Cyber.border,
                      width: tier == selected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        tier.label,
                        style: Cyber.display(
                          12,
                          color: tier == selected ? Cyber.cyan : Cyber.muted,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tier.range,
                        style: Cyber.label(
                          8,
                          color: Cyber.muted,
                          letterSpacing: 1,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (tier != FinalOverTier.values.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}
```

### A.2 `lib/screens/final_over/widgets/final_over_arena_background.dart`

<sub>17 lines</sub>

```dart
import 'package:flutter/material.dart';

import '../../../widgets/matchmaking/matchmaking_arena_background.dart';

/// Shared animated arena backdrop for the Final Over lobby.
class FinalOverArenaBackground extends StatelessWidget {
  const FinalOverArenaBackground({required this.child, super.key});

  final Widget child;

  static const assetPath = 'assets/backgrounds/final_over_arena.jpg';

  @override
  Widget build(BuildContext context) {
    return MatchmakingArenaBackground(asset: assetPath, child: child);
  }
}
```

### A.3 `lib/widgets/matchmaking/matchmaking_arena_background.dart`

<sub>107 lines</sub>

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../cyber/cyber_widgets.dart';

/// Shared animated arena backdrop for matchmaking (and sport lobbies that
/// want the same bed). Optional [asset] overlays a drifting sport plate;
/// missing art falls back to the gradient + texture stack.
class MatchmakingArenaBackground extends StatefulWidget {
  const MatchmakingArenaBackground({
    required this.child,
    this.asset,
    super.key,
  });

  final Widget child;

  /// Optional full-bleed arena image, e.g. `assets/backgrounds/penalty_arena.png`.
  final String? asset;

  @override
  State<MatchmakingArenaBackground> createState() =>
      _MatchmakingArenaBackgroundState();
}

class _MatchmakingArenaBackgroundState extends State<MatchmakingArenaBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff02060f), Color(0xff06121f), Color(0xff01040a)],
        ),
      ),
      child: Stack(
        children: [
          if (asset != null)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final phase = _controller.value * math.pi * 2;
                  return Transform.translate(
                    offset: Offset(math.sin(phase) * 6, math.cos(phase) * 4),
                    child: Transform.scale(
                      scale: 1.05 + 0.008 * math.sin(phase * 2),
                      child: child,
                    ),
                  );
                },
                child: Opacity(
                  opacity: 0.45,
                  child: Image.asset(
                    asset,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Cyber.bg.withValues(alpha: 0.28),
                    Colors.transparent,
                    Cyber.bg.withValues(alpha: 0.6),
                  ],
                  stops: const [0.0, 0.46, 1.0],
                ),
              ),
            ),
          ),
          const Positioned.fill(child: CyberTextureOverlay()),
          widget.child,
        ],
      ),
    );
  }
}
```

### A.4 `lib/widgets/game_scaffold.dart`

<sub>132 lines</sub>

```dart
// SUBSET of the host app's lib/widgets/game_scaffold.dart: ReactHeaderBar,
// copied verbatim. The hub uses it as its app bar. GameScaffold (same source
// file) is left out; it needs CyberBackground, which the hub does not use.
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

### A.5 `lib/widgets/cyber/cyber_hub_widgets.dart`

<sub>368 lines</sub>

```dart
// SUPPLEMENT to the Final Over port doc's lib/widgets/cyber/cyber_widgets.dart
// (Appendix D.4 there). These are the shared HUD primitives the hub needs on
// top of that subset, copied verbatim from the host app's cyber_widgets.dart.
// Re-export this file from cyber_widgets.dart (see the hub doc, section 8) so
// `import 'cyber_widgets.dart'` keeps resolving everything, as in the source.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/theme.dart';
import 'cyber_widgets.dart';

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


## Appendix B — Stand-ins for host-app dependencies

Each file says what the source does and what to replace it with (§6).

### B.1 `lib/utils/sound_effects.dart`

<sub>9 lines</sub>

```dart
// STAND-IN for the host app's lib/utils/sound_effects.dart.
// REPLACES Appendix D.3 of the Final Over port doc: same no-op stand-in, plus
// `uiTap`, which the hub's tier picker plays. Wire these to your own audio
// layer (audioplayers / flame_audio / etc).
enum SoundEffect { playMatch, cardSelect, riser, uiTap }

void playSound(SoundEffect effect) {
  // no-op stand-in
}
```

### B.2 `lib/blocs/game/game_bloc.dart`

<sub>20 lines</sub>

```dart
// STAND-IN for the host app's GameBloc, the global progression / card-economy
// bloc. The hub only reads it (BlocBuilder + context.read), so any
// StateStreamable<GameState> works. The source is a Bloc<GameEvent, GameState>
// with a FinalOverFinished event for XP and history (port doc §9).
import 'package:flutter_bloc/flutter_bloc.dart';

import 'game_state.dart';

class GameBloc extends Cubit<GameState> {
  GameBloc([super.initialState = const GameState()]);

  /// What the source deck builder does when the player saves a squad
  /// (`FinalOverDeckSaved` in the source).
  void saveFinalOverDeck(List<String> batsmanIds) => emit(
    state.copyWith(
      deckFinalOverBatsmen: [for (final id in batsmanIds) PlayerCard(id)],
      ownedCardIds: {...state.ownedCardIds, ...batsmanIds},
    ),
  );
}
```

### B.3 `lib/blocs/game/game_state.dart`

<sub>45 lines</sub>

```dart
// STAND-IN for the host app's GameState: only the five members the hub reads.
// `finalOverDeckReady` is the source getter, verbatim.
import '../../models/match.dart';
import '../../models/progression.dart';

/// Stand-in for the source `PlayerCard` (lib/models/cards.dart). The hub only
/// reads `id`.
class PlayerCard {
  const PlayerCard(this.id);
  final String id;
}

class GameState {
  const GameState({
    this.progression = const PlayerProgression(),
    this.matchHistory = const [],
    this.deckFinalOverBatsmen = const [],
    this.ownedCardIds = const {},
    this.ownedFinalOverKitIds = const ['voltage'],
  });

  final PlayerProgression progression;
  final List<MatchHistoryEntry> matchHistory;
  final List<PlayerCard> deckFinalOverBatsmen;
  final Set<String> ownedCardIds;
  final List<String> ownedFinalOverKitIds;

  bool get finalOverDeckReady =>
      deckFinalOverBatsmen.length == 5 &&
      deckFinalOverBatsmen.every((card) => ownedCardIds.contains(card.id));

  GameState copyWith({
    PlayerProgression? progression,
    List<MatchHistoryEntry>? matchHistory,
    List<PlayerCard>? deckFinalOverBatsmen,
    Set<String>? ownedCardIds,
    List<String>? ownedFinalOverKitIds,
  }) => GameState(
    progression: progression ?? this.progression,
    matchHistory: matchHistory ?? this.matchHistory,
    deckFinalOverBatsmen: deckFinalOverBatsmen ?? this.deckFinalOverBatsmen,
    ownedCardIds: ownedCardIds ?? this.ownedCardIds,
    ownedFinalOverKitIds: ownedFinalOverKitIds ?? this.ownedFinalOverKitIds,
  );
}
```

### B.4 `lib/models/match.dart`

<sub>21 lines</sub>

```dart
// STAND-IN for the host app's MatchHistoryEntry (lib/models/match.dart).
// The source entry also carries teams, scores, rounds and rewards. Final Over
// results are written with `mode: 'finalover'` by GameBloc's FinalOverFinished
// handler. The hub filters on `isFinalOver` (verbatim getter).
class MatchHistoryEntry {
  const MatchHistoryEntry({
    required this.id,
    required this.mode,
    required this.resultLabel,
    required this.summary,
  });

  final String id;
  final String mode;

  /// 'Victory', 'Draw' or 'Defeat'.
  final String resultLabel;
  final String summary;

  bool get isFinalOver => mode == 'finalover';
}
```

### B.5 `lib/models/progression.dart`

<sub>15 lines</sub>

```dart
// STAND-IN for the host app's lib/models/progression.dart. The source keeps
// per-track XP and derives levels from a shared curve; this keeps the shape the
// hub touches: a progression value and the `finalOver` track.
enum ProgressTrack { finalOver }

class PlayerProgression {
  const PlayerProgression({this.trackXp = const {}});

  final Map<ProgressTrack, int> trackXp;

  int xpFor(ProgressTrack track) => trackXp[track] ?? 0;

  /// Stand-in curve: a level every 100 XP. Use your own.
  int levelFor(ProgressTrack track) => xpFor(track) ~/ 100 + 1;
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

### B.7 `lib/widgets/player_level_badge.dart`

<sub>54 lines</sub>

```dart
// STAND-IN for the host app's PlayerLevelBadge (lib/widgets/player_level_badge.dart).
// The source is a 132 px flat plate: "LVL" over a gold level number, a hairline
// divider, a thin XP meter with `into/span`, and a chevron. A tap widens it to
// 222 px (easeOutBack, 360 ms) to reveal NEXT <n> XP and the track total. It
// never glows. This stand-in keeps the size and the collapsed read-out.
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/progression.dart';

class PlayerLevelBadge extends StatelessWidget {
  const PlayerLevelBadge({required this.progression, this.track, super.key});

  final PlayerProgression progression;
  final ProgressTrack? track;

  @override
  Widget build(BuildContext context) {
    final t = track ?? ProgressTrack.finalOver;
    return Semantics(
      label: 'Final Over level',
      child: Container(
        width: 132,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Cyber.panel,
          border: Border.all(
            color: Cyber.cyan.withValues(alpha: 0.5),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Text(
              'LVL',
              style: Cyber.label(8, color: Cyber.cyan, letterSpacing: 1.5),
            ),
            const SizedBox(width: 6),
            Text(
              '${progression.levelFor(t)}',
              style: Cyber.display(22, color: Cyber.gold),
            ),
            const Spacer(),
            Text(
              '${progression.xpFor(t) % 100}/100',
              style: Cyber.label(8, color: Cyber.muted, letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
```

### B.8 `lib/screens/leaderboard/widgets/game_leaderboard_button.dart`

<sub>56 lines</sub>

```dart
// STAND-IN for the host app's GameLeaderboardButton. The source is a flat
// 40×40 cut-corner plate (panel@0.55 fill, accent@0.5 border, leaderboard
// icon, no glow). A tap plays `uiTap` + a selection haptic and pushes the
// leaderboard already filtered to (sport, mode); a long press shows
// `RANK // <mode label>`. `GameMode` is the source enum, verbatim.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../models/sport_match.dart';
import '../../../utils/sound_effects.dart';

enum GameMode { featured, quiz, mystery, shootout, chess, bingo }

class GameLeaderboardButton extends StatelessWidget {
  const GameLeaderboardButton({
    required this.sport,
    required this.mode,
    this.accent = Cyber.cyan,
    this.onOpen,
    super.key,
  });

  final Sport sport;
  final GameMode mode;
  final Color accent;

  /// Port hook: open your leaderboard for (sport, mode).
  final VoidCallback? onOpen;

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
          onOpen?.call();
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

### B.9 `lib/screens/match_history/match_history_pages.dart`

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

### B.10 `lib/screens/final_over/final_over_deck_builder_screen.dart`

<sub>55 lines</sub>

```dart
// STAND-IN for the host app's FinalOverDeckBuilderScreen ("FINAL OVER SQUAD //
// 5-BAT CHASE UNIT"). The source is a 600-line editor: five batter slots
// (3 + 2), an owned-batter grid sorted by rating, the kit picker, and a save
// that dispatches the deck to GameBloc. The constructor is verbatim. This
// stand-in fills the squad with five placeholder ids so the hub flips from
// BUILD SQUAD to TAKE GUARD.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../config/theme.dart';
import '../../widgets/cyber/cyber_cta_button.dart';

class FinalOverDeckBuilderScreen extends StatelessWidget {
  const FinalOverDeckBuilderScreen({
    required this.onBack,
    this.onSaved,
    this.onBrowseShop,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback? onSaved;
  final VoidCallback? onBrowseShop;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: HudCtaButton(
              label: 'LOCK SQUAD',
              icon: Icons.sports_cricket_rounded,
              accent: Cyber.cyan,
              onTap: () {
                context.read<GameBloc>().saveFinalOverDeck(const [
                  'bat-1',
                  'bat-2',
                  'bat-3',
                  'bat-4',
                  'bat-5',
                ]);
                onSaved?.call();
                onBack();
              },
            ),
          ),
        ),
      ),
    );
  }
}
```

### B.11 `lib/screens/final_over/final_over_match_screen.dart`

<sub>34 lines</sub>

```dart
// STAND-IN for FinalOverMatchScreen. Replace this file with Appendix C.1 of
// the Final Over port doc once its host touch-points (§9 there) are wired.
// The constructor is the same, so the hub does not change.
import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/final_over.dart';

class FinalOverMatchScreen extends StatelessWidget {
  const FinalOverMatchScreen({
    required this.config,
    required this.onExit,
    super.key,
  });

  final FinalOverMatchConfig config;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: Center(
        child: TextButton(
          onPressed: onExit,
          child: Text(
            'CHASE ${config.target} // ${config.tier.label}',
            style: Cyber.display(18),
          ),
        ),
      ),
    );
  }
}
```


## Appendix C — Acceptance test

Rename `package:card_game/` to your package name.

### C.1 `test/final_over_hub_test.dart`

<sub>192 lines</sub>

```dart
// Acceptance test for the Final Over hub port. Rename `package:card_game/`
// to your package name.
import 'dart:convert';

import 'package:card_game/blocs/final_over/final_over_cubit.dart';
import 'package:card_game/blocs/final_over/final_over_state.dart';
import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_state.dart';
import 'package:card_game/models/final_over.dart';
import 'package:card_game/models/match.dart';
import 'package:card_game/screens/final_over/final_over_hub.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _squad = ['bat-1', 'bat-2', 'bat-3', 'bat-4', 'bat-5'];

GameState _readyState({List<MatchHistoryEntry> history = const []}) =>
    GameState(
      deckFinalOverBatsmen: [for (final id in _squad) PlayerCard(id)],
      ownedCardIds: _squad.toSet(),
      matchHistory: history,
    );

Future<(FinalOverCubit, GameBloc)> _pumpHub(
  WidgetTester tester, {
  GameState gameState = const GameState(),
  bool load = true,
  double width = 390,
  VoidCallback? onExit,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final cubit = FinalOverCubit(SecureGameStorage());
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
      child: MaterialApp(home: FinalOverHub(onExit: onExit ?? () {})),
    ),
  );
  await _advance(tester, 1000);
  return (cubit, gameBloc);
}

/// Steps the clock frame by frame. The entrances start their tickers from
/// timers, so a single long pump would only render their first frame. The
/// pulse and the arena drift repeat forever, so never pumpAndSettle.
Future<void> _advance(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tapCta(WidgetTester tester, String label) async {
  // The hub scrolls when the viewport is short (and the test font is tall).
  await tester.ensureVisible(find.text(label));
  await tester.pump();
  await tester.tap(find.text(label));
  await _advance(tester, 800);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows a spinner until career stats load', (tester) async {
    await _pumpHub(tester, load: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('FINAL OVER'), findsNothing);
  });

  testWidgets('no squad: BUILD SQUAD opens the deck builder, then flips to '
      'TAKE GUARD', (tester) async {
    await _pumpHub(tester);
    expect(find.text('BUILD SQUAD'), findsOneWidget);
    expect(find.text('PICK 3 OWNED BATTERS TO CHASE'), findsOneWidget);
    expect(find.text('ROOKIE'), findsOneWidget);
    expect(find.text('GET YOUR EYE IN'), findsOneWidget);

    await _tapCta(tester, 'BUILD SQUAD');
    expect(find.text('LOCK SQUAD'), findsOneWidget);

    await _tapCta(tester, 'LOCK SQUAD');
    expect(find.text('TAKE GUARD'), findsOneWidget);
    expect(find.text('ROOKIE // TARGET 32–40'), findsOneWidget);
  });

  testWidgets('tier pick persists and drives the chase config', (tester) async {
    final (cubit, _) = await _pumpHub(tester, gameState: _readyState());

    await tester.tap(find.text('ELITE'));
    await _advance(tester, 200);
    expect(cubit.state.tier, FinalOverTier.elite);
    expect(find.text('ELITE // TARGET 58–66'), findsOneWidget);
    expect(find.text('BOUNDARIES OR BUST'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pd_final_over_stats_v1'), contains('"elite"'));

    await _tapCta(tester, 'TAKE GUARD');
    final config = cubit.state.config!;
    expect(cubit.state.phase, FinalOverPhase.intro);
    expect(FinalOverTier.elite.targets, contains(config.target));
    expect(config.batsmanIds, _squad);
    expect(config.showHints, isTrue);
    expect(find.text('CHASE ${config.target} // ELITE'), findsOneWidget);

    // Exiting the match returns to the lobby and resets the session phase.
    await tester.tap(find.text('CHASE ${config.target} // ELITE'));
    await _advance(tester, 800);
    expect(cubit.state.phase, FinalOverPhase.idle);
    expect(find.text('TAKE GUARD'), findsOneWidget);
  });

  testWidgets('an equipped kit the player no longer owns falls back to the '
      'free kit', (tester) async {
    SharedPreferences.setMockInitialValues({
      'pd_final_over_stats_v1': jsonEncode(
        const FinalOverStats(kitId: 'ember').toJson(),
      ),
    });
    final (cubit, _) = await _pumpHub(tester, gameState: _readyState());
    expect(cubit.state.kitId, 'voltage');
  });

  testWidgets('match history lists only Final Over results under the career '
      'board', (tester) async {
    SharedPreferences.setMockInitialValues({
      'pd_final_over_stats_v1': jsonEncode(
        const FinalOverStats(chases: 4, wins: 3, bestScore: 61).toJson(),
      ),
    });
    await _pumpHub(
      tester,
      gameState: _readyState(
        history: const [
          MatchHistoryEntry(
            id: 'fo-1',
            mode: 'finalover',
            resultLabel: 'Victory',
            summary: 'Chased 48 with 2 balls to spare',
          ),
          MatchHistoryEntry(
            id: 'pd-1',
            mode: 'pitchduel',
            resultLabel: 'Defeat',
            summary: 'Pitch Duel loss',
          ),
        ],
      ),
    );

    await _tapCta(tester, 'MATCH HISTORY');
    expect(find.text('MATCH HISTORY // FINAL OVER'), findsOneWidget);
    expect(find.text('CAREER'), findsOneWidget);
    expect(find.text('61'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('Chased 48 with 2 balls to spare'), findsOneWidget);
    expect(find.text('Pitch Duel loss'), findsNothing);
  });

  testWidgets('back calls onExit', (tester) async {
    var exited = false;
    await _pumpHub(tester, onExit: () => exited = true);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    expect(exited, isTrue);
  });

  for (final width in [320.0, 390.0, 600.0]) {
    testWidgets('lays out without overflow at ${width.toInt()} px', (
      tester,
    ) async {
      await _pumpHub(tester, gameState: _readyState(), width: width);
      expect(tester.takeException(), isNull);
      final cta = tester.getSize(find.text('TAKE GUARD'));
      expect(cta.width, greaterThan(0));
      // The column caps at 440 px on wide screens.
      final tiers = tester.getRect(find.text('ELITE'));
      expect(tiers.right, lessThanOrEqualTo(width));
    });
  }
}
```
