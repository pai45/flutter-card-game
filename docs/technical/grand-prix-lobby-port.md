# Grand Prix Dash Lobby — Implementation & Porting Reference

> **Status:** BUILT · **Written:** 2026-09-17 · **Audience:** Flutter engineers rebuilding the Grand Prix Dash lobby in another project
>
> **Source of truth:**
> [`lib/screens/grand_prix/grand_prix_lobby_screen.dart`](../../lib/screens/grand_prix/grand_prix_lobby_screen.dart)
> covers `GrandPrixLobbyScreen`, `_PitLaneStatusBar`, `_HeroRow`,
> `_RaceEmblem`, `_RecordPanel`, `_RecordStat`, `_CircuitPicker`,
> `_LapPicker` and `_LapOption`.
>
> Supporting files:
> - [`lib/screens/grand_prix/grand_prix_hub.dart`](../../lib/screens/grand_prix/grand_prix_hub.dart) (`GrandPrixTabContent`, the shell that owns the cubit)
> - `lib/screens/grand_prix/widgets/grand_prix_arena_background.dart`
> - `lib/widgets/matchmaking/matchmaking_arena_background.dart`
> - `lib/widgets/game_scaffold.dart` (`ReactHeaderBar`)
> - `lib/widgets/cyber/cyber_widgets.dart` (entrances, texture, `CyberCtaButton`)
> - `lib/blocs/game/game_state.dart` (`racingDriverDeckReady`, `grandPrixPitDeckReady`)
> - `lib/config/theme.dart` (`Cyber.f1Red`)
> - `lib/app.dart` (the starter-pack gate and route push)
>
> **Companion to [Grand Prix Dash port](grand-prix-dash-port.md).**
> That doc ports the engine, renderer, cubit and controls. Its §3 lists "the
> lobby (circuit/livery/lap pickers)" as not ported, and its checklist step 2
> just says "build a lobby". This doc fills that gap. **Port that doc
> first:** this one reuses its A.4 (models), A.5 (circuits), A.7 (liveries),
> A.8/A.9 (cubit), D.3 (storage), D.5 (cyber widgets) and D.6
> (`HudCtaButton`) unchanged. It **replaces** D.1, D.2 and D.4 with
> supersets.
>
> **This document is self-contained on top of that one.** Appendix A is
> copied **verbatim** from the source by script. Appendix B holds stand-ins
> for host systems the lobby only reads. Appendix C is the acceptance test.
> Written on top of the main doc's files, the app analyzes clean and all
> tests pass (§10). Sibling docs: [Final Over hub](final-over-hub-port.md) ·
> [Hoop Duel lobby](hoop-duel-lobby-port.md).

---

## 1. What the lobby is

The lobby is the **Grand Prix Dash pit wall**. The player's path through it:

1. See their Grand Prix level and a season teaser.
2. Pick a circuit and a race distance.
3. Either **START RACE** (driver and livery ready) or **PIT DECK** (not
   ready).
4. Optionally open the Pit Deck or the Match History.

**Livery and driver are not picked here.** They live in the Pit Deck and the
Shop.

**Entry.** The lobby is opened from **Sports → Games → F1 → Grand Prix Dash**
and from the Trending hero tile
([arcade tiles doc](arcade-trending-hero-tiles.md)):

- Both go through `_openGrandPrix()` in `lib/app.dart`.
- That wraps the push in `_enterGrandPrixGameFlow`. On first entry
  (`grandPrixStarterPackClaimed == false`), it opens the **racing starter
  pack**, which signs the first F1 driver, and pushes only after the reveal.
- The pushed route is **`GrandPrixTabContent`** (A.2). It creates
  `GrandPrixCubit(SecureGameStorage())..load()` for this route and shows the
  lobby. The Pit Deck and races are pushed on top as their own routes, and
  they share the cubit through `BlocProvider.value`.
- `onNavigate` pops the route, then switches the app shell.
- `onBrowseShop` pops the route, then opens Shop tab 3 (the livery shop).
  The lobby forwards it to the Pit Deck.

Top to bottom (max width **420**, padding 20 / 16 / 20 / 24, vertically
centered; accent **`Cyber.f1Red` `#F42D29`**):

| # | Element | Content | Entrance (delay / lift) |
|---|---|---|---|
| — | App bar | `ReactHeaderBar(showTitle: false)`: back → `onNavigate(AppSection.predictions)`. Right slot: `PlayerLevelBadge(track: grandPrix)`, 6 px gap, then `GameLeaderboardButton(sport: motorsport, mode: featured, accent: f1Red, onNavigate:)` | none |
| 1 | Status bar | 7 px `Cyber.success` dot (glow α .6, blur 8), `PIT LANE OPEN` (Orbitron 9, w900, success, spacing 2), a flexible 1 px `f1Red@.16` rule, `SYS://GP_DASH v1.0.0` (Orbitron 8.5, w800, muted, spacing 1.2) | 0 ms / 30 px |
| 2 | Hero row | `_RaceEmblem` (84 px), 16 px gap. `GRAND PRIX DASH` (display 21, spacing 1.2, f1Red@.45 shadow, blur 14), `1·3·5 LAPS · 20 CARS · LIGHTS OUT` (Orbitron 9, w800, muted, spacing 2.2), then a season chip | 80 ms / 24 px |
| 3 | Label | `CIRCUIT` | none |
| 4 | Circuit strip | Horizontal `ListView` of 172 × 140 cards, 10 px apart (below) | 240 ms / 18 px |
| 5 | Label | `RACE DISTANCE` | none |
| 6 | Distance picker | Three equal tiles, 8 px apart (below) | 300 ms / 17 px |
| 7 | Primary CTA | `HudCtaButton(icon: sports_motorsports, accent: f1Red, tapSound: playMatch)`. **Ready:** `START RACE` → `_startRace`. **Not ready:** `PIT DECK` → `_openPitDeck` | 360 ms / 22 px |
| 8 | Secondary row | `CyberCtaButton(clip: false)`: `PIT DECK` and `MATCH HISTORY`, 12 px apart, each in a default `CyberDealtCard` | 420 ms / 18 px, plus the deal (§8.7) |

Vertical gaps: 16 · 20 · 10 · 20 · 10 · 22 · 14.

**Season chip** (`CyberChip`, first match wins):

| Stats | Label | Colour |
|---|---|---|
| `wins > 0` | `<wins> RACE WINS` | gold |
| `races > 0` | `<races> RACES IN` | f1Red |
| otherwise | `ROOKIE SEASON` | f1Red |

**Circuit cards.** There is one card per `grandPrixCircuits` entry (port doc
A.5), in data order:

| Circuit | Chip | Stars (of 4) |
|---|---|---|
| HARBOUR STREET | STREET | ★★★★ |
| DESERT MILE | SPEEDWAY | ★★☆☆ |
| EMERALD PARK (default) | BALANCED | ★★★☆ |
| MOUNTAIN PASS | TECHNICAL | ★★★★ |
| COASTAL SPRINT | FLOWING | ★★★☆ |

Card anatomy (12 px padding, square corners):

1. The name: display 11, one line, ellipsis.
2. The character chip.
3. Stars: amber@.9, 11 pt, spacing 2.
4. A spacer.
5. `BEST m:ss.mmm`: Orbitron 9, tabular. Cyan when set; otherwise muted
   `BEST --:--.---`.

The BEST value is `stats.bestLapMs(circuit, laps: selectedLaps)`. It is keyed
per circuit **and distance**: `emeraldPark` for 1 lap, and
`emeraldPark@3L` / `@5L` for longer races. Switching distance swaps every
card's BEST at once.

| Card state | Fill | Border | Name | Chip |
|---|---|---|---|---|
| Selected | `alphaBlend(f1Red@.10, panel)` | f1Red, 1.6 px | f1Red | f1Red |
| Idle | `panel` | `border@.6`, 1 px | white | muted |

**Distance tiles** (`_LapOption`, `AnimatedContainer` 180 ms, 10 px padding,
same fill and border rules as the cards):

| Tile | Big number | Title | XP chip (`grandPrixXpMultiplier`) |
|---|---|---|---|
| 1 LAP (default) | `1` | SPRINT | `XP ×1` (muted) |
| 3 LAPS | `3` | GRAND PRIX | `XP ×2` (gold) |
| 5 LAPS | `5` | ENDURANCE | `XP ×3` (gold) |

Each tile's contents:

- **Number:** display 22, tabular; f1Red when selected, white otherwise.
  It shares a baseline with ` LAP`/` LAPS` (display 9, muted).
- **Title:** Orbitron 7, w800; white when selected, muted otherwise.
- **XP chip:** reads the same function as the payout
  (`calculateGrandPrixXP`), so the chip and the reward never drift apart.

**CTA helper:**

| State | Helper |
|---|---|
| Ready | `<CIRCUIT NAME> · 1 LAP` or `· <n> LAPS` `· <LIVERY NAME>`, e.g. `EMERALD PARK · 1 LAP · GRID LINE` |
| Not ready | `EQUIP YOUR DRIVER AND LIVERY` |

## 2. Widget tree

```
GrandPrixTabContent (A.2)            BlocProvider(GrandPrixCubit(storage)..load())
 └ GrandPrixLobbyScreen(onNavigate, onBrowseShop)                    (StatefulWidget)
    └ BlocBuilder<GameBloc, GameState>   buildWhen: progression | deckRacingStarter |
       │                                 ownedGrandPrixLiveryIds          (§8.2)
       │  cubit.ensureEquippedLiveryOwned(ownedGrandPrixLiveryIds)   ← side effect in build (§8.8)
       └ BlocBuilder<GrandPrixCubit, GrandPrixState>                    (no buildWhen)
          │  ready = gameState.grandPrixPitDeckReady(state.livery)
          └ Scaffold(bg: Cyber.bg)
             ├ appBar: ReactHeaderBar(title 'GRAND PRIX DASH', subtitle '// LIGHTS OUT',
             │                         showTitle: false, onBack, rightSlot: badge + board)
             └ body: GrandPrixArenaBackground → SafeArea(top: false)
                ├ loading → Center(CircularProgressIndicator(f1Red))     (app bar stays)
                └ LayoutBuilder → SingleChildScrollView(20/16/20/24)
                   └ ConstrainedBox(minHeight: viewport) → Center → ConstrainedBox(maxWidth 420)
                      └ Column(center, stretch)
                         ├ SlideUp(_PitLaneStatusBar)
                         ├ SlideUp(80, _HeroRow(stats))
                         ├ SectionLabel('CIRCUIT')
                         ├ SlideUp(240, _CircuitPicker(selected, stats, laps))   (StatefulWidget)
                         ├ SectionLabel('RACE DISTANCE')
                         ├ SlideUp(300, _LapPicker(selected))
                         ├ SlideUp(360, HudCtaButton(ready ? START RACE : PIT DECK))
                         └ SlideUp(420, Row[ Dealt(0, 'Pit Deck'), Dealt(1, 'Match History') ])
```

**Backdrop.** `GrandPrixArenaBackground` is `MatchmakingArenaBackground(asset:
'assets/backgrounds/gp_arena.jpg')`. It is the same layered bed as the other
lobbies:

1. a vertical `#02060F → #06121F → #01040A` gradient
2. the JPEG at 45 % opacity, drifting on a 20 s loop
3. a scrim
4. scanlines + vignette

A missing image falls back to gradient + texture only.

**`_RaceEmblem`** (84 px) is driven by a 3600 ms controller that repeats
forward. With `phase = t·2π` and `pulse = 0.5 + 0.5·sin(2·phase)`, it
breathes **twice per loop**. Nothing actually rotates, despite the
controller's name `_spin`. The styling:

- A 0.9 × size circle: `bg@.5` fill, `f1Red@(.26 + .12·pulse)` border, and
  `Cyber.glow(f1Red, α .20 + .08·pulse, blur 18 + 4·pulse, spread −4)`.
- A `sports_motorsports` icon at 0.46 × size in f1Red, with an `f1Red@.62`
  shadow (blur 16 + 4·pulse).

**Circuit strip scroll.** `_CircuitPicker` opens with
`initialScrollOffset = index × 182 − 24`, clamped to
`[0, 182 × (count − 1)]`, so the remembered circuit starts in view. The
controller is created once, so later selections do not re-scroll. See §8.1
for the overshoot.

## 3. State and data flow

| Source | Scope in the source app | What the lobby reads |
|---|---|---|
| `GrandPrixCubit` (port doc A.9) | The Grand Prix route (`GrandPrixTabContent`) | `loading`, `stats`, and `circuitId` / `laps` / `livery`, which are all views over `stats.last*`, so every pick survives a restart. It also calls `ensureEquippedLiveryOwned`, `selectCircuit`, `selectLaps` and `buildRace` |
| `GameBloc` (host, stand-in B.2/B.3) | App-level | `progression` (badge, and the CPU level for `buildRace`), `deckRacingPlayers`, `deckRacingStarter`, `ownedCardIds`, `ownedGrandPrixLiveryIds`, and `matchHistory` (read at tap time) |

**Readiness** is two source getters, verbatim in B.3:

```dart
bool get racingDriverDeckReady =>
    deckRacingPlayers.isNotEmpty &&
    deckRacingStarter != null &&
    deckRacingPlayers.any((card) => card.id == deckRacingStarter!.id) &&
    ownedCardIds.contains(deckRacingStarter!.id);

bool grandPrixPitDeckReady(GrandPrixLivery equippedLivery) =>
    racingDriverDeckReady &&
    isGrandPrixLiveryOwned(equippedLivery.name, ownedGrandPrixLiveryIds);
```

So "ready" means the player has a signed, owned starter driver in their
racing deck **and** owns the equipped livery. GRID LINE is free and always
owned. The driver card is a gate only: neither `RaceSetup` nor the race
screen reads it.

### Actions

| Trigger | Code path | Result |
|---|---|---|
| Circuit card | `HapticFeedback.selectionClick()` → `playSound(uiTap)` → `cubit.selectCircuit(id)` | No-op if unchanged. Otherwise `stats.lastCircuit` is persisted (`pd_grand_prix_stats_v1`). The card, BEST and helper update |
| Distance tile | selection haptic → `uiTap` → `cubit.selectLaps(n)` | No-op if unchanged. Otherwise `lastLaps` is persisted, and every card's BEST switches to that distance |
| START RACE (ready) | `_startRace()` | `level = progression.levelFor(ProgressTrack.grandPrix)`, then `cubit.buildRace(level)`. That builds a `RaceSetup` from the circuit, livery, **level** (CPU strength via `cpuSmartness`), a random P8–P16 grid slot, a seed and the laps, and sets phase → `grid`. Then it pushes `BlocProvider.value(cubit) → GrandPrixRaceScreen(onExit: pop, onRaceAgain: …)` |
| PIT DECK (CTA when not ready, or the secondary button) | `_openPitDeck()` | Pushes `BlocProvider.value(cubit) → GrandPrixPitDeckScreen(onBack: pop, onBrowseShop:)`. On return, the new `deckRacingStarter` (or livery) rebuilds the lobby, and the CTA flips to START RACE |
| RACE AGAIN | `navigator.pop()`, then `_startRace()` | A new setup on a new route. It **re-reads the level**, so XP from the last race can toughen the next grid |
| Race `onExit` | `navigator.pop` | Back to the lobby. C.1 abandons a mid-race exit (port doc §7 step 6) |
| MATCH HISTORY | `showGameMatchHistory(gameLabel: 'Grand Prix', history: matchHistory.where(isGrandPrix), career: _RecordPanel(stats))` | Full-screen fade route with the career board |
| Back | `onNavigate(AppSection.predictions)` | Pop, then **MATCHES** (§8.9) |
| Leaderboard | (inside the button) | `uiTap` + selection haptic, then pushes the board filtered to Motorsport / featured, in f1Red |

**Career board** (`_RecordPanel`) is a `CyberPanel(accent: f1Red, padding:
14/12)` holding five columns. Each column shows a value (Orbitron 17, w900,
tabular, scale-down) over a label (Orbitron 7.5, muted, spacing 0.8):

| Column | Value | Colour |
|---|---|---|
| RACES | `races` | white |
| WINS | `wins` | gold |
| PODIUMS | `podiums` | white |
| BEST | `P<bestPosition>`, or `—` when 0 | cyan |
| STREAK | `currentStreak` | success when > 0, else muted |

### Wiring

```dart
// App root: your global progression + card store.
BlocProvider(create: (_) => GameBloc(/* … */), child: MaterialApp(/* … */));

// GAMES → F1 → Grand Prix Dash (gate on your racing starter pack first).
void openGrandPrix(BuildContext context) {
  final navigator = Navigator.of(context);
  navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => GrandPrixTabContent(
        onNavigate: (section) {
          navigator.pop();
          goToAppSection(section); // your shell switch
        },
        onBrowseShop: () {
          navigator.pop();
          openLiveryShop(); // your shop, on the livery tab
        },
      ),
    ),
  );
}
```

## 4. Gratification and feedback

| Moment | Feedback |
|---|---|
| Arrive | Cascade at 0 / 80 / 240 / 300 / 360 / 420 ms. Each block rises 17–30 px over 480 ms (`easeOutCubic`). The secondary buttons are also **dealt**: 260 px fly, ±0.07 rad tilt, `easeOutBack` settle |
| Idle | The f1Red emblem breathes twice every 3.6 s. `HudCtaButton` halo (0.25 → 0.70 over 1.8 s). Arena drift. Green **PIT LANE OPEN** dot |
| Circuit or distance pick | Selection haptic + `uiTap`. The distance tile cross-fades over 180 ms (the circuit card switches instantly). The BEST times and helper re-read at once. The gold `XP ×2` / `×3` chips advertise the grind reward |
| START RACE | Halo goes to full on press-down. On tap: **medium** haptic + `playMatch`, then the grid |
| PIT DECK (CTA) | The same medium haptic + `playMatch` (§8.3) |
| Driver signed | On return, the CTA turns into START RACE and the helper reads your whole setup. That is the "car's on the grid" beat |
| Season | The chip moves from ROOKIE SEASON → *n* RACES IN → *n* RACE WINS (gold). A cyan BEST on each card is your target to beat |

The five lights, launch grade, overtakes, lap flash and result cinematic
belong to the race screen (port doc §8, C.1–C.2).

## 5. Design rules carried by this code

- **Accent.** Grand Prix is **f1Red** throughout: selections, CTA, emblem,
  chips, leaderboard, spinner and career panel. Gold is kept for wins and
  XP multipliers, and cyan for times and BEST position.
- **Glow.** Four things glow:
  - the CTA halo
  - the emblem
  - the title shadow
  - the status dot

  Selections use fill and border only. The badge and leaderboard stay
  flat.
- **Shape.** Only `HudCtaButton` is clipped. The cards, tiles and secondary
  buttons are square with hairline borders.
- **Type.** The status line, tagline, BEST line, tile titles and record
  cells build `TextStyle(fontFamily: Cyber.displayFont, …)` inline. The
  stars use the default font. The only raw hex is in the shared arena and
  header gradients.
- **Numbers are tabular**: lap counts, BEST times and career values.
- **Content first.** Circuit identity comes from name, character and stars;
  there is no track art on the cards. The livery only shows up in the
  helper.

## 6. Host touch-points (Appendix B)

| Source symbol | Stand-in | Replace with |
|---|---|---|
| `Cyber.f1Red` | B.1 (**replaces** port doc D.1, adding the token) | Your racing accent |
| `AppSection` | B.2 (verbatim enum) | Your shell's destinations |
| `GameBloc` / `GameState` / `PlayerCard` | B.3 / B.4: a `Cubit` with the fields the lobby reads, both readiness getters verbatim, and `equipRacingDriver` | Your progression and card store |
| `SoundEffect.uiTap` | B.5 (**replaces** port doc D.4) | Your UI tap cue |
| `MatchHistoryEntry` | B.6 | Your history model (`isGrandPrix` = `mode == 'grandprix'`) |
| `PlayerProgression`, `ProgressTrack` | B.7 (**replaces** port doc D.2 and keeps its three functions) | Your XP tracks. `levelFor(grandPrix)` feeds CPU strength |
| `Sport` | B.8 (verbatim enum) | Your sport enum |
| `PlayerLevelBadge` | B.9 | Your level chip |
| `GameLeaderboardButton`, `GameMode` | B.10 (verbatim constructor and enum) | Your leaderboard route |
| `showGameMatchHistory` | B.11 (verbatim signature) | Your history page, keeping the `career` slot |
| `GrandPrixPitDeckScreen` | B.12 (verbatim constructor; signs a stand-in driver and equips GRID LINE through `selectLivery`) | Your driver signing, livery selector (`selectLivery(…, ownedLiveryIds:)`) and shop link |
| `GrandPrixRaceScreen` | B.13 (same constructor; reads `cubit.state.setup`) | Port doc **C.1**, once its §9 touch-points are wired |

## 7. File map and port checklist

| Target path | Contents | Where |
|---|---|---|
| `lib/screens/grand_prix/grand_prix_lobby_screen.dart` | The lobby (verbatim, whole file) | A.1 |
| `lib/screens/grand_prix/grand_prix_hub.dart` | `GrandPrixTabContent` shell (verbatim, whole file) | A.2 |
| `lib/screens/grand_prix/widgets/grand_prix_arena_background.dart` | Arena wrapper (verbatim, whole file) | A.3 |
| `lib/widgets/matchmaking/matchmaking_arena_background.dart` | Drifting arena bed (verbatim, whole file) | A.4 |
| `lib/widgets/game_scaffold.dart` | `ReactHeaderBar` (verbatim subset) | A.5 |
| `lib/widgets/cyber/cyber_hub_widgets.dart` | `CyberTextureOverlay`, `HudLine`, `CyberCtaButton`, `CyberSlideUpFadeIn`, `CyberPulse`, `CyberDealtCard` (verbatim declarations) | A.6 |
| `lib/config/theme.dart` | **Stand-in**, replaces port doc D.1 | B.1 |
| `lib/config/enums.dart` | **Stand-in** | B.2 |
| `lib/blocs/game/game_bloc.dart`, `game_state.dart` | **Stand-ins** | B.3, B.4 |
| `lib/utils/sound_effects.dart` | **Stand-in**, replaces port doc D.4 | B.5 |
| `lib/models/match.dart`, `progression.dart`, `sport_match.dart` | **Stand-ins** (`progression.dart` replaces port doc D.2) | B.6–B.8 |
| `lib/widgets/player_level_badge.dart` | **Stand-in** | B.9 |
| `lib/screens/leaderboard/widgets/game_leaderboard_button.dart` | **Stand-in** | B.10 |
| `lib/screens/match_history/match_history_pages.dart` | **Stand-in** | B.11 |
| `lib/screens/grand_prix/grand_prix_pit_deck_screen.dart` | **Stand-in** | B.12 |
| `lib/screens/grand_prix/grand_prix_race_screen.dart` | **Stand-in**; overwrites the port doc's C.1 if you copied it | B.13 |
| `test/grand_prix_lobby_test.dart` | Widget tests | C.1 |

Checklist:

1. Port [grand-prix-dash-port.md](grand-prix-dash-port.md) (A, B, D, E) and
   make its tests pass. Leave its Appendix C out for now; it does not compile
   without the host systems in its §9.
2. Copy A.1–A.6, B.1–B.13 and C.1 to the listed paths. B.1, B.5 and B.7
   overwrite D.1, D.4 and D.2. If your project already has any of the B
   systems, map them onto yours and keep the names the lobby imports.
3. In the port doc's `lib/widgets/cyber/cyber_widgets.dart` (D.5), add this
   line right after its imports:
   ```dart
   export 'cyber_hub_widgets.dart';
   ```
   A.5 and A.6 are the same code as in the Final Over hub and Hoop Duel
   lobby docs, apart from their header comments. Keep one copy if you port
   more than one game.
4. Optional: add `assets/backgrounds/gp_arena.jpg` (a dark circuit plate;
   the source file is a 50 KB JPEG) under `flutter: assets:`.
5. Gate entry on your racing starter pack (or grant a driver). Then push
   `GrandPrixTabContent` with `onNavigate` and `onBrowseShop` (§3 Wiring).
   Your `GameBloc` must sit above it.
6. Replace B.13 with the port doc's C.1 once XP, audio and the engine loop
   are wired.
7. Consider the fixes in §8, then update C.1's expectations to match.
8. Run `flutter analyze` and `flutter test test/grand_prix_lobby_test.dart`.
9. On device, check at 320 px, a normal phone, and a tablet:
   - the cascade plays
   - the remembered circuit opens in view
   - distance swaps the BEST times
   - no driver → PIT DECK → sign → START RACE
   - START RACE → RACE AGAIN → EXIT
   - history shows only Grand Prix results

## 8. Known issues and copy notes

Kept verbatim in Appendix A; fix them in your port if you like.

1. **The circuit strip overshoots, then springs back.** The initial offset
   is clamped to `182 × (count − 1)` rather than to the list's real
   `maxScrollExtent`. On a 390 px phone the maximum is 550 px. With COASTAL
   SPRINT remembered, the strip opens at **704 px** and visibly springs back
   to 550 px over ~600 ms. This was measured on both Android and iOS
   physics. MOUNTAIN PASS (522 px) fits on phones, but on the full
   420 px column the maximum is 480 px, so it overshoots too. Fix: jump to
   `min(target, position.maxScrollExtent)` in a post-frame callback.
2. **Readiness can go stale.** `grandPrixPitDeckReady` reads
   `deckRacingPlayers`, `deckRacingStarter`, `ownedCardIds` and
   `ownedGrandPrixLiveryIds`. The outer `buildWhen` watches only the starter
   and the liveries.
   - This was measured: emitting a state where only `deckRacingPlayers`
     changed (not ready → ready) left the CTA on PIT DECK.
   - In the source it is latent. Deck edits re-resolve cards from the shared
     catalog, and `PlayerCard` has no `==`, so the starter's identity
     changes only when the starter itself changes.
   - Fix: add `deckRacingPlayers` and `ownedCardIds` to `buildWhen`, or
     compare `c.grandPrixPitDeckReady(...)` directly.
3. **PIT DECK uses the race-start cue.** The not-ready CTA keeps
   `tapSound: playMatch` and the medium haptic, so opening a menu sounds like
   starting a race. When not ready, the CTA and the secondary button also
   both read "PIT DECK".
4. **The helper wraps.** The helper `Text` in `HudCtaButton` has no
   `maxLines`. With the real Onest and Orbitron fonts, `COASTAL SPRINT · 5
   LAPS · SILVER ARROW` wraps to **two lines** at ≤ 390 px (measured), and
   still fits the 64 px plate. With a fallback font it overflows by 13–24 px
   at ≤ 360 px.
5. **"BEST" is a race time, not a lap time.** For 3 and 5 laps, the stored
   value is the **total race time** (`GrandPrixResult.lapTimeMs`: "Total
   race time over all laps"). The card still says `BEST`, which reads as a
   best lap. The empty placeholder `--:--.---` also doesn't match the
   `m:ss.mmm` shape. Consider `BEST RACE` and `-:--.---`.
6. **The status row is tight.** It has two unshrinkable texts. It fits at
   320 px with Orbitron (no errors in the real-font render), but a larger
   system text scale can overflow it. Wrap `SYS://GP_DASH v1.0.0` in
   `Flexible`.
7. **The secondary row animates twice.** It sits inside a 420 ms
   `CyberSlideUpFadeIn` **and** each button is a default `CyberDealtCard`,
   which starts at 220 + 75 × index ms and runs 540 ms. Most of the deal
   plays while the parent is still invisible. Give the dealt cards
   `initialDelay: 470 ms` (as Hoop Duel does), or drop the wrapper.
8. **`ensureEquippedLiveryOwned` runs inside `build`.** When it clamps, it
   also persists. This is safe with `flutter_bloc`, but move it to a
   listener when porting to a synchronous notifier.
9. **Back always goes to MATCHES**, not to where the player came from.
10. **Cosmetic code notes:**
    - `_spin` never spins.
    - `SYS://GP_DASH v1.0.0` is hard-coded.
    - The page reserves ~40 px of dead scroll (`minHeight` ignores the
      padding, as in the Final Over hub).
    - The `Column` children in `build` are not `dart format`ted (mixed
      indentation).
    - The class doc says "circuit/distance pickers and START RACE", which is
      accurate. The product page's "livery swatches" are gone (§11).

## 9. Acceptance test (Appendix C)

`test/grand_prix_lobby_test.dart` runs **12 widget tests**:

| Test | What it proves |
|---|---|
| spinner while loading | The `loading` branch keeps the app bar, and back → `AppSection.predictions` |
| shell | `GrandPrixTabContent`: two PIT DECK labels, the not-ready helper and ROOKIE SEASON. PIT DECK → sign → START RACE with `EMERALD PARK · 1 LAP · GRID LINE` |
| circuit + distance | `XP ×1/×2/×3` chips. DESERT MILE + GRAND PRIX update the cubit and helper, and persist `lastCircuit` / `lastLaps` |
| BEST per distance | A 1-lap best shows `BEST 1:02.345`, and the others show `--:--.---`. ENDURANCE swaps in the `@5L` best `5:18.004` |
| START / RACE AGAIN / EXIT | A remembered MOUNTAIN PASS / 5 laps builds a `grid` setup with GRID LINE, **level 3** (from 250 XP) and a P8–P16 slot. RACE AGAIN replaces the setup. EXIT returns to the lobby |
| livery fallback | A stored SCARLET with only GRID LINE owned is clamped **and persisted** as GRID LINE, and START RACE is shown |
| owned livery | An owned PAPAYA stays equipped and appears in the helper |
| season chip | `4 RACES IN` |
| match history | `2 RACE WINS`. Only `grandprix` entries are listed. All five career labels and `P1` appear |
| remembered circuit | COASTAL SPRINT is inside a 420 px view after the entrance (after the §8.1 spring-back) |
| 500 / 800 px | No layout exceptions, and the distance row stays inside the view |

**Testing notes:**

- The entrances start their tickers from `Timer`s, so the test steps the
  clock in 50 ms frames (`_advance`). It never calls `pumpAndSettle`.
- The widths are 500 px and up because the test font is much wider than
  Orbitron. §8.1, §8.2 and §8.4 were measured with dedicated probes: the
  §8.4 probe loaded the real fonts, and the §8.1/§8.2 probes measured scroll
  offsets and rebuilds.

## 10. Verification performed for this document

A script read **only this markdown file and the port doc**. It:

- wrote the port doc's A, B, D and E into an empty Flutter app
  (`card_game`, Flutter 3.44.4, the port doc's §4 dependencies plus
  `flutter_lints`)
- wrote this doc's A, B and C on top (B.1 over D.1, B.5 over D.4, B.7 over
  D.2)
- added the `export` line from §7 step 3

Results:

- **Verbatim check:** A.1, A.2 and A.4 are byte-identical to the source
  files. The one exception is A.3: the source has no trailing newline, and
  the extracted block ends with one. A.5 and A.6 are whole declarations cut
  from the source by name, under a new header comment. B.1 and B.7 keep D.1
  and D.2 unchanged apart from the additions.
- **Analyze:** `flutter analyze` → **No issues found!**
- **Tests:** `flutter test` → **37 tests, all passed** (C.1's 12 plus the
  port doc's 25).
- **Probes (not shipped):**
  - circuit-strip scroll offsets for all five circuits on Android and iOS
    physics
  - a `buildWhen` staleness check
  - a real-font render (the source app's Orbitron and Onest) at
    320–430 px: no layout errors with the app's fonts
- **Not checked:** the real `GameBloc`, `PlayerLevelBadge`, leaderboard,
  history page, Pit Deck and race screen (all stand-ins here), and a pixel
  comparison against the source app.

## 11. Product-doc corrections made alongside

[`games/grand-prix-dash.md`](../product/games/grand-prix-dash.md) described
an older, deck-free, one-lap game whose lobby had livery swatches. Code is
authoritative. The page now reflects:

- the racing starter-pack gate
- the driver + livery readiness rule
- the 1 / 3 / 5-lap distances with XP multipliers
- livery selection in the Pit Deck
- personal bests keyed by circuit and distance
- the per-game Match History

---


## Appendix A — Lobby files (verbatim)

Copy each block to the path in its heading.

### A.1 `lib/screens/grand_prix/grand_prix_lobby_screen.dart`

<sub>790 lines</sub>

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_state.dart';
import '../../blocs/grand_prix/grand_prix_cubit.dart';
import '../../blocs/grand_prix/grand_prix_state.dart';
import '../../config/enums.dart';
import '../../config/theme.dart';
import '../../data/grand_prix_circuits.dart';
import '../../data/grand_prix_liveries.dart';
import '../../models/grand_prix.dart';
import '../../models/progression.dart'
    show ProgressTrack, grandPrixXpMultiplier;
import '../../models/sport_match.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import '../../widgets/player_level_badge.dart';
import '../leaderboard/widgets/game_leaderboard_button.dart';
import '../match_history/match_history_pages.dart';
import 'grand_prix_pit_deck_screen.dart';
import 'grand_prix_race_screen.dart';
import 'widgets/grand_prix_arena_background.dart';

/// Grand Prix Dash lobby: circuit/distance pickers and START RACE.
/// Career record lives in Match History. Livery and driver equip live in
/// Pit Deck / Shop.
class GrandPrixLobbyScreen extends StatefulWidget {
  const GrandPrixLobbyScreen({
    required this.onNavigate,
    this.onBrowseShop,
    super.key,
  });

  final ValueChanged<AppSection> onNavigate;
  final VoidCallback? onBrowseShop;

  @override
  State<GrandPrixLobbyScreen> createState() => _GrandPrixLobbyScreenState();
}

class _GrandPrixLobbyScreenState extends State<GrandPrixLobbyScreen> {
  void _openPitDeck() {
    final navigator = Navigator.of(context);
    final cubit = context.read<GrandPrixCubit>();
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: GrandPrixPitDeckScreen(
            onBack: navigator.pop,
            onBrowseShop: widget.onBrowseShop,
          ),
        ),
      ),
    );
  }

  void _startRace() {
    final cubit = context.read<GrandPrixCubit>();
    final level = context
        .read<GameBloc>()
        .state
        .progression
        .levelFor(ProgressTrack.grandPrix);
    cubit.buildRace(level);
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: GrandPrixRaceScreen(
            onExit: navigator.pop,
            onRaceAgain: () {
              navigator.pop();
              _startRace();
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      buildWhen: (p, c) =>
          p.progression != c.progression ||
          p.deckRacingStarter != c.deckRacingStarter ||
          p.ownedGrandPrixLiveryIds != c.ownedGrandPrixLiveryIds,
      builder: (context, gameState) {
        context.read<GrandPrixCubit>().ensureEquippedLiveryOwned(
          gameState.ownedGrandPrixLiveryIds,
        );
        return BlocBuilder<GrandPrixCubit, GrandPrixState>(
          builder: (context, state) {
            final ready = gameState.grandPrixPitDeckReady(state.livery);
            final liverySpec = grandPrixLiverySpec(state.livery);
            return Scaffold(
              backgroundColor: Cyber.bg,
              appBar: ReactHeaderBar(
                title: 'GRAND PRIX DASH',
                subtitle: '// LIGHTS OUT',
                onBack: () => widget.onNavigate(AppSection.predictions),
                showTitle: false,
                rightSlot: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlayerLevelBadge(
                      progression: gameState.progression,
                      track: ProgressTrack.grandPrix,
                    ),
                    const SizedBox(width: 6),
                    GameLeaderboardButton(
                      sport: Sport.motorsport,
                      mode: GameMode.featured,
                      accent: Cyber.f1Red,
                      onNavigate: widget.onNavigate,
                    ),
                  ],
                ),
              ),
              // Arena art stays full-bleed (same bed pattern as Hoop Duel).
              body: GrandPrixArenaBackground(
                child: SafeArea(
                  top: false,
                  child: state.loading
                      ? const Center(
                          child: CircularProgressIndicator(color: Cyber.f1Red),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 420,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const CyberSlideUpFadeIn(
                                          child: _PitLaneStatusBar(),
                                        ),
                                  const SizedBox(height: 16),
                                  CyberSlideUpFadeIn(
                                    delay: const Duration(milliseconds: 80),
                                    offset: 24,
                                    child: _HeroRow(stats: state.stats),
                                  ),
                                  const SizedBox(height: 20),
                                  const SectionLabel(label: 'CIRCUIT'),
                                  const SizedBox(height: 10),
                                  CyberSlideUpFadeIn(
                                    delay: const Duration(milliseconds: 240),
                                    offset: 18,
                                    child: _CircuitPicker(
                                      selected: state.circuitId,
                                      stats: state.stats,
                                      laps: state.laps,
                                      onSelect: (id) {
                                        HapticFeedback.selectionClick();
                                        playSound(SoundEffect.uiTap);
                                        context
                                            .read<GrandPrixCubit>()
                                            .selectCircuit(id);
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  const SectionLabel(label: 'RACE DISTANCE'),
                                  const SizedBox(height: 10),
                                  CyberSlideUpFadeIn(
                                    delay: const Duration(milliseconds: 300),
                                    offset: 17,
                                    child: _LapPicker(
                                      selected: state.laps,
                                      onSelect: (laps) {
                                        HapticFeedback.selectionClick();
                                        playSound(SoundEffect.uiTap);
                                        context
                                            .read<GrandPrixCubit>()
                                            .selectLaps(laps);
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 22),
                                  CyberSlideUpFadeIn(
                                    delay: const Duration(milliseconds: 360),
                                    offset: 22,
                                    child: HudCtaButton(
                                      label: ready ? 'START RACE' : 'PIT DECK',
                                      icon: Icons.sports_motorsports,
                                      accent: Cyber.f1Red,
                                      tapSound: SoundEffect.playMatch,
                                      helper: ready
                                          ? '${grandPrixCircuit(state.circuitId).name} · '
                                              '${state.laps == 1 ? '1 LAP' : '${state.laps} LAPS'} · '
                                              '${liverySpec.name}'
                                          : 'EQUIP YOUR DRIVER AND LIVERY',
                                      onTap: ready ? _startRace : _openPitDeck,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  CyberSlideUpFadeIn(
                                    delay: const Duration(milliseconds: 420),
                                    offset: 18,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: CyberDealtCard(
                                            index: 0,
                                            child: CyberCtaButton(
                                              label: 'Pit Deck',
                                              clip: false,
                                              onPressed: _openPitDeck,
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
                                                gameLabel: 'Grand Prix',
                                                history: context
                                                    .read<GameBloc>()
                                                    .state
                                                    .matchHistory
                                                    .where(
                                                      (e) => e.isGrandPrix,
                                                    )
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
}

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

class _PitLaneStatusBar extends StatelessWidget {
  const _PitLaneStatusBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: Cyber.success,
            shape: BoxShape.circle,
            boxShadow: Cyber.glow(Cyber.success, alpha: 0.6, blur: 8, spread: 0),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'PIT LANE OPEN',
          style: TextStyle(
            color: Cyber.success,
            fontFamily: Cyber.displayFont,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(height: 1, color: Cyber.f1Red.withValues(alpha: 0.16)),
        ),
        const SizedBox(width: 10),
        const Text(
          'SYS://GP_DASH v1.0.0',
          style: TextStyle(
            color: Cyber.muted,
            fontFamily: Cyber.displayFont,
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _HeroRow extends StatelessWidget {
  const _HeroRow({required this.stats});

  final GrandPrixStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _RaceEmblem(size: 84),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GRAND PRIX DASH',
                style: Cyber.display(21, letterSpacing: 1.2).copyWith(
                  shadows: [
                    Shadow(
                      color: Cyber.f1Red.withValues(alpha: 0.45),
                      blurRadius: 14,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '1·3·5 LAPS · 20 CARS · LIGHTS OUT',
                style: TextStyle(
                  color: Cyber.muted,
                  fontFamily: Cyber.displayFont,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: CyberChip(
                  label: stats.wins > 0
                      ? '${stats.wins} RACE WINS'
                      : stats.races > 0
                          ? '${stats.races} RACES IN'
                          : 'ROOKIE SEASON',
                  color: stats.wins > 0 ? Cyber.gold : Cyber.f1Red,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RaceEmblem extends StatefulWidget {
  const _RaceEmblem({this.size = 84});

  final double size;

  @override
  State<_RaceEmblem> createState() => _RaceEmblemState();
}

class _RaceEmblemState extends State<_RaceEmblem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _spin,
        builder: (context, _) {
          final phase = _spin.value * math.pi * 2;
          final pulse = 0.5 + 0.5 * math.sin(phase * 2);
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: size * 0.9,
                height: size * 0.9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Cyber.bg.withValues(alpha: 0.5),
                  border: Border.all(
                    color: Cyber.f1Red.withValues(alpha: 0.26 + pulse * 0.12),
                  ),
                  boxShadow: Cyber.glow(
                    Cyber.f1Red,
                    alpha: 0.2 + pulse * 0.08,
                    blur: 18 + pulse * 4,
                    spread: -4,
                  ),
                ),
              ),
              Icon(
                Icons.sports_motorsports,
                size: size * 0.46,
                color: Cyber.f1Red,
                shadows: [
                  Shadow(
                    color: Cyber.f1Red.withValues(alpha: 0.62),
                    blurRadius: 16 + pulse * 4,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RecordPanel extends StatelessWidget {
  const _RecordPanel({required this.stats});

  final GrandPrixStats stats;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.f1Red,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          _RecordStat(label: 'RACES', value: '${stats.races}'),
          _RecordStat(
            label: 'WINS',
            value: '${stats.wins}',
            accent: Cyber.gold,
          ),
          _RecordStat(label: 'PODIUMS', value: '${stats.podiums}'),
          _RecordStat(
            label: 'BEST',
            value: stats.bestPosition > 0 ? 'P${stats.bestPosition}' : '—',
            accent: Cyber.cyan,
          ),
          _RecordStat(
            label: 'STREAK',
            value: '${stats.currentStreak}',
            accent: stats.currentStreak > 0 ? Cyber.success : Cyber.muted,
          ),
        ],
      ),
    );
  }
}

class _RecordStat extends StatelessWidget {
  const _RecordStat({
    required this.label,
    required this.value,
    this.accent = Colors.white,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: accent,
                fontFamily: Cyber.displayFont,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              color: Cyber.muted,
              fontFamily: Cyber.displayFont,
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircuitPicker extends StatefulWidget {
  const _CircuitPicker({
    required this.selected,
    required this.stats,
    required this.laps,
    required this.onSelect,
  });

  final GrandPrixCircuitId selected;
  final GrandPrixStats stats;
  final int laps;
  final ValueChanged<GrandPrixCircuitId> onSelect;

  @override
  State<_CircuitPicker> createState() => _CircuitPickerState();
}

class _CircuitPickerState extends State<_CircuitPicker> {
  static const _cardExtent = 172.0 + 10.0; // card width + separator

  // Open with the remembered circuit in view, not always the list start.
  late final ScrollController _controller = ScrollController(
    initialScrollOffset:
        (grandPrixCircuits.indexWhere((c) => c.id == widget.selected) *
                _cardExtent -
            24)
            .clamp(0.0, _cardExtent * (grandPrixCircuits.length - 1)),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  GrandPrixCircuitId get selected => widget.selected;
  GrandPrixStats get stats => widget.stats;
  ValueChanged<GrandPrixCircuitId> get onSelect => widget.onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        itemCount: grandPrixCircuits.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final circuit = grandPrixCircuits[index];
          final isSelected = circuit.id == selected;
          final bestLap = stats.bestLapMs(circuit.id, laps: widget.laps);
          return GestureDetector(
            onTap: () => onSelect(circuit.id),
            child: Container(
              width: 172,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Color.alphaBlend(
                        Cyber.f1Red.withValues(alpha: 0.1),
                        Cyber.panel,
                      )
                    : Cyber.panel,
                border: Border.all(
                  color: isSelected
                      ? Cyber.f1Red
                      : Cyber.border.withValues(alpha: 0.6),
                  width: isSelected ? 1.6 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          circuit.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Cyber.display(
                            11,
                            color: isSelected ? Cyber.f1Red : Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      CyberChip(
                        label: circuit.character,
                        color: isSelected ? Cyber.f1Red : Cyber.muted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${'★' * circuit.difficultyStars}${'☆' * (4 - circuit.difficultyStars)}',
                    style: TextStyle(
                      color: Cyber.amber.withValues(alpha: 0.9),
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'BEST ${formatLapTime(bestLap)}',
                    style: TextStyle(
                      color: bestLap != null ? Cyber.cyan : Cyber.muted,
                      fontFamily: Cyber.displayFont,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Race-distance picker: 1 lap sprint, 3-lap grand prix, 5-lap endurance —
/// longer runs pay multiplied XP (chip reads [grandPrixXpMultiplier]).
class _LapPicker extends StatelessWidget {
  const _LapPicker({required this.selected, required this.onSelect});

  static const _options = [
    (laps: 1, title: 'SPRINT'),
    (laps: 3, title: 'GRAND PRIX'),
    (laps: 5, title: 'ENDURANCE'),
  ];

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final option in _options) ...[
          Expanded(
            child: _LapOption(
              laps: option.laps,
              title: option.title,
              isSelected: option.laps == selected,
              onTap: () => onSelect(option.laps),
            ),
          ),
          if (option != _options.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _LapOption extends StatelessWidget {
  const _LapOption({
    required this.laps,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final int laps;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final multiplier = grandPrixXpMultiplier(laps);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Color.alphaBlend(
                  Cyber.f1Red.withValues(alpha: 0.1),
                  Cyber.panel,
                )
              : Cyber.panel,
          border: Border.all(
            color: isSelected
                ? Cyber.f1Red
                : Cyber.border.withValues(alpha: 0.6),
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$laps',
                  style: Cyber.display(
                    22,
                    color: isSelected ? Cyber.f1Red : Colors.white,
                  ).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  laps == 1 ? ' LAP' : ' LAPS',
                  style: Cyber.display(
                    9,
                    color: Cyber.muted,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? Colors.white : Cyber.muted,
                fontFamily: Cyber.displayFont,
                fontSize: 7,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 7),
            CyberChip(
              label: 'XP ×$multiplier',
              color: multiplier > 1 ? Cyber.gold : Cyber.muted,
            ),
          ],
        ),
      ),
    );
  }
}
```

### A.2 `lib/screens/grand_prix/grand_prix_hub.dart`

<sub>34 lines</sub>

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/grand_prix/grand_prix_cubit.dart';
import '../../config/enums.dart';
import '../../services/secure_storage_service.dart';
import 'grand_prix_lobby_screen.dart';

/// Standalone Grand Prix Dash shell — the F1 tab's first game. Owns the mode's
/// cubit; the lobby is the only hub section (races are pushed routes), and
/// app-level navigation is delegated up via [onNavigate]. The player's signed
/// F1 driver comes from the shared starter pack (see `_enterGrandPrixGameFlow`
/// in app.dart).
class GrandPrixTabContent extends StatelessWidget {
  const GrandPrixTabContent({
    required this.onNavigate,
    this.onBrowseShop,
    super.key,
  });

  final ValueChanged<AppSection> onNavigate;
  final VoidCallback? onBrowseShop;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GrandPrixCubit(SecureGameStorage())..load(),
      child: GrandPrixLobbyScreen(
        onNavigate: onNavigate,
        onBrowseShop: onBrowseShop,
      ),
    );
  }
}
```

### A.3 `lib/screens/grand_prix/widgets/grand_prix_arena_background.dart`

<sub>17 lines</sub>

```dart
import 'package:flutter/material.dart';

import '../../../widgets/matchmaking/matchmaking_arena_background.dart';

/// Shared animated arena backdrop for the Grand Prix Dash lobby.
class GrandPrixArenaBackground extends StatelessWidget {
  const GrandPrixArenaBackground({required this.child, super.key});

  final Widget child;

  static const assetPath = 'assets/backgrounds/gp_arena.jpg';

  @override
  Widget build(BuildContext context) {
    return MatchmakingArenaBackground(asset: assetPath, child: child);
  }
}
```

### A.4 `lib/widgets/matchmaking/matchmaking_arena_background.dart`

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

### A.5 `lib/widgets/game_scaffold.dart`

<sub>132 lines</sub>

```dart
// SUBSET of the host app's lib/widgets/game_scaffold.dart: ReactHeaderBar,
// copied verbatim. The lobby uses it as its app bar. GameScaffold (same source
// file) is left out; it needs CyberBackground, which the lobby does not use.
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

### A.6 `lib/widgets/cyber/cyber_hub_widgets.dart`

<sub>369 lines</sub>

```dart
// SUPPLEMENT to the Grand Prix Dash port doc's
// lib/widgets/cyber/cyber_widgets.dart (Appendix D.5 there). These are the
// shared HUD primitives the lobby needs on top of that subset, copied verbatim
// from the host app's cyber_widgets.dart.
// Re-export this file from cyber_widgets.dart (see the lobby doc, section 7) so
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

### B.1 `lib/config/theme.dart`

<sub>116 lines</sub>

```dart
// STAND-IN for the host app's lib/config/theme.dart.
// REPLACES Appendix D.1 of the Grand Prix Dash port doc: identical, plus
// `Cyber.f1Red`, the lobby's brand accent (source literal value).
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

  /// Grand Prix Dash brand accent (racing red).
  static const Color f1Red = Color(0xFFF42D29);
  static const Color success = Color.fromRGBO(5, 223, 114, 1);
  static const Color pink = Color(0xFFFF94C1);

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

<sub>18 lines</sub>

```dart
// STAND-IN for the host app's lib/config/enums.dart: only `AppSection`, which
// the lobby takes as its navigation callback type (verbatim enum).
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

### B.3 `lib/blocs/game/game_bloc.dart`

<sub>20 lines</sub>

```dart
// STAND-IN for the host app's GameBloc, the global progression / card-economy
// bloc. The lobby only reads it (BlocBuilder + context.read), so any
// StateStreamable<GameState> works. The source is a Bloc<GameEvent, GameState>
// with a GrandPrixFinished event for XP and history (port doc §9).
import 'package:flutter_bloc/flutter_bloc.dart';

import 'game_state.dart';

class GameBloc extends Cubit<GameState> {
  GameBloc([super.initialState = const GameState()]);

  /// What the source Pit Deck does when the player signs a driver.
  void equipRacingDriver(PlayerCard driver) => emit(
    state.copyWith(
      deckRacingPlayers: [driver],
      deckRacingStarter: driver,
      ownedCardIds: {...state.ownedCardIds, driver.id},
    ),
  );
}
```

### B.4 `lib/blocs/game/game_state.dart`

<sub>61 lines</sub>

```dart
// STAND-IN for the host app's GameState: only the members the lobby reads.
// `racingDriverDeckReady` and `grandPrixPitDeckReady` are the source getters,
// verbatim.
import '../../data/grand_prix_liveries.dart';
import '../../models/grand_prix.dart';
import '../../models/match.dart';
import '../../models/progression.dart';

/// Stand-in for the source `PlayerCard` (lib/models/cards.dart). The lobby
/// only reads `id`.
class PlayerCard {
  const PlayerCard({required this.id, required this.name});

  final String id;
  final String name;
}

class GameState {
  const GameState({
    this.progression = const PlayerProgression(),
    this.matchHistory = const [],
    this.deckRacingPlayers = const [],
    this.deckRacingStarter,
    this.ownedCardIds = const {},
    this.ownedGrandPrixLiveryIds = const ['gridLine'],
  });

  final PlayerProgression progression;
  final List<MatchHistoryEntry> matchHistory;
  final List<PlayerCard> deckRacingPlayers;
  final PlayerCard? deckRacingStarter;
  final Set<String> ownedCardIds;
  final List<String> ownedGrandPrixLiveryIds;

  bool get racingDriverDeckReady =>
      deckRacingPlayers.isNotEmpty &&
      deckRacingStarter != null &&
      deckRacingPlayers.any((card) => card.id == deckRacingStarter!.id) &&
      ownedCardIds.contains(deckRacingStarter!.id);

  bool grandPrixPitDeckReady(GrandPrixLivery equippedLivery) =>
      racingDriverDeckReady &&
      isGrandPrixLiveryOwned(equippedLivery.name, ownedGrandPrixLiveryIds);

  GameState copyWith({
    PlayerProgression? progression,
    List<MatchHistoryEntry>? matchHistory,
    List<PlayerCard>? deckRacingPlayers,
    PlayerCard? deckRacingStarter,
    Set<String>? ownedCardIds,
    List<String>? ownedGrandPrixLiveryIds,
  }) => GameState(
    progression: progression ?? this.progression,
    matchHistory: matchHistory ?? this.matchHistory,
    deckRacingPlayers: deckRacingPlayers ?? this.deckRacingPlayers,
    deckRacingStarter: deckRacingStarter ?? this.deckRacingStarter,
    ownedCardIds: ownedCardIds ?? this.ownedCardIds,
    ownedGrandPrixLiveryIds:
        ownedGrandPrixLiveryIds ?? this.ownedGrandPrixLiveryIds,
  );
}
```

### B.5 `lib/utils/sound_effects.dart`

<sub>9 lines</sub>

```dart
// STAND-IN for the host app's lib/utils/sound_effects.dart.
// REPLACES Appendix D.4 of the Grand Prix Dash port doc: same no-op stand-in,
// plus `uiTap`, which the lobby's circuit and distance pickers play. Wire these
// to your own audio layer (audioplayers / flame_audio / etc).
enum SoundEffect { playMatch, cardSelect, riser, uiTap }

void playSound(SoundEffect effect) {
  // no-op stand-in
}
```

### B.6 `lib/models/match.dart`

<sub>22 lines</sub>

```dart
// STAND-IN for the host app's MatchHistoryEntry (lib/models/match.dart).
// The source entry also carries teams, scores, rounds and rewards. Grand Prix
// results are written with `mode: 'grandprix'` by GameBloc's
// GrandPrixFinished handler. The lobby filters on `isGrandPrix` (verbatim
// getter).
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

  bool get isGrandPrix => mode == 'grandprix';
}
```

### B.7 `lib/models/progression.dart`

<sub>47 lines</sub>

```dart
// STAND-IN for the host app's lib/models/progression.dart.
// REPLACES Appendix D.2 of the Grand Prix Dash port doc: its three functions
// are kept verbatim below, and the XP-track shape the lobby reads (level badge,
// buildRace level) is added on top. The source keeps per-track XP and derives
// levels from a shared curve.
import 'dart:math';

double cpuSmartness(int level) => min(1.0, level / 12);

// Longer Grand Prix race distances multiply the position payout — a 5-lap
// endurance run is worth the grind. Shown on the lobby's distance selector so
// keep the lobby chip and the payout reading from this one function.
int grandPrixXpMultiplier(int laps) => switch (laps) {
  >= 5 => 3,
  >= 3 => 2,
  _ => 1,
};

// XP for Grand Prix Dash — an arcade race, so it pays by finishing position:
// a one-lap win matches Football Chess's ceiling, a backmarker finish still
// earns a little, and longer distances multiply the position payout (see
// [grandPrixXpMultiplier]). A new personal best on the circuit+distance adds
// +3. XP only — racing never subtracts XP and never pays coins.
int calculateGrandPrixXP(int position, {bool personalBest = false, int laps = 1}) {
  final base = switch (position) {
    1 => 26,
    2 => 22,
    3 => 18,
    <= 6 => 12,
    <= 10 => 8,
    _ => 4,
  };
  return base * grandPrixXpMultiplier(laps) + (personalBest ? 3 : 0);
}

enum ProgressTrack { grandPrix }

class PlayerProgression {
  const PlayerProgression({this.trackXp = const {}});

  final Map<ProgressTrack, int> trackXp;

  int xpFor(ProgressTrack track) => trackXp[track] ?? 0;

  /// Stand-in curve: a level every 100 XP. Use your own.
  int levelFor(ProgressTrack track) => xpFor(track) ~/ 100 + 1;
}
```

### B.8 `lib/models/sport_match.dart`

<sub>5 lines</sub>

```dart
// STAND-IN: the host app's `Sport` enum, verbatim. The rest of
// lib/models/sport_match.dart (fixtures, scores) is not needed.

/// Sport governs how sport-specific surfaces lay out scores and modules.
enum Sport { football, cricket, motorsport, basketball, tennis }
```

### B.9 `lib/widgets/player_level_badge.dart`

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
    final t = track ?? ProgressTrack.grandPrix;
    return Semantics(
      label: 'Grand Prix level',
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

### B.10 `lib/screens/leaderboard/widgets/game_leaderboard_button.dart`

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

### B.11 `lib/screens/match_history/match_history_pages.dart`

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

### B.12 `lib/screens/grand_prix/grand_prix_pit_deck_screen.dart`

<sub>61 lines</sub>

```dart
// STAND-IN for the host app's GrandPrixPitDeckScreen. The source screen signs
// one owned F1 driver card as the starter and hosts the livery selector
// (`selectLivery(…, ownedLiveryIds:)`), with a link to the livery Shop. The
// constructor is verbatim. This stand-in signs a placeholder driver and
// equips the free livery, so the lobby's CTA flips to START RACE.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_state.dart';
import '../../blocs/grand_prix/grand_prix_cubit.dart';
import '../../config/theme.dart';
import '../../data/grand_prix_liveries.dart';
import '../../widgets/cyber/cyber_cta_button.dart';

const grandPrixStandInDriver = PlayerCard(
  id: 'f1-stand-in-driver',
  name: 'Stand-in Driver',
);

class GrandPrixPitDeckScreen extends StatelessWidget {
  const GrandPrixPitDeckScreen({
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
              label: 'SIGN DRIVER',
              icon: Icons.sports_motorsports,
              accent: Cyber.f1Red,
              onTap: () {
                final gameBloc = context.read<GameBloc>();
                gameBloc.equipRacingDriver(grandPrixStandInDriver);
                context.read<GrandPrixCubit>().selectLivery(
                  grandPrixFreeLivery,
                  ownedLiveryIds: gameBloc.state.ownedGrandPrixLiveryIds,
                );
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

### B.13 `lib/screens/grand_prix/grand_prix_race_screen.dart`

<sub>41 lines</sub>

```dart
// STAND-IN for GrandPrixRaceScreen. Replace this file with Appendix C.1 of the
// Grand Prix Dash port doc once its host touch-points (§9 there) are wired.
// The constructor is the same, so the lobby does not change. Like C.1, it
// reads the RaceSetup the lobby just built from the cubit.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/grand_prix/grand_prix_cubit.dart';
import '../../config/theme.dart';

class GrandPrixRaceScreen extends StatelessWidget {
  const GrandPrixRaceScreen({
    required this.onExit,
    required this.onRaceAgain,
    super.key,
  });

  final VoidCallback onExit;
  final VoidCallback onRaceAgain;

  @override
  Widget build(BuildContext context) {
    final setup = context.read<GrandPrixCubit>().state.setup!;
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'GRID // ${setup.circuit.name} // ${setup.laps}L',
              style: Cyber.display(16),
            ),
            TextButton(onPressed: onRaceAgain, child: const Text('RACE AGAIN')),
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

### C.1 `test/grand_prix_lobby_test.dart`

<sub>303 lines</sub>

```dart
// Acceptance test for the Grand Prix Dash lobby port. Rename
// `package:card_game/` to your package name.
import 'dart:convert';

import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_state.dart';
import 'package:card_game/blocs/grand_prix/grand_prix_cubit.dart';
import 'package:card_game/blocs/grand_prix/grand_prix_state.dart';
import 'package:card_game/config/enums.dart';
import 'package:card_game/models/grand_prix.dart';
import 'package:card_game/models/match.dart';
import 'package:card_game/models/progression.dart';
import 'package:card_game/screens/grand_prix/grand_prix_hub.dart';
import 'package:card_game/screens/grand_prix/grand_prix_lobby_screen.dart';
import 'package:card_game/screens/grand_prix/grand_prix_pit_deck_screen.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _statsKey = 'pd_grand_prix_stats_v1';

GameState _readyState({
  List<MatchHistoryEntry> history = const [],
  int grandPrixXp = 0,
}) => GameState(
  deckRacingPlayers: const [grandPrixStandInDriver],
  deckRacingStarter: grandPrixStandInDriver,
  ownedCardIds: {grandPrixStandInDriver.id},
  matchHistory: history,
  progression: PlayerProgression(
    trackXp: {ProgressTrack.grandPrix: grandPrixXp},
  ),
);

void _seedStats(GrandPrixStats stats) => SharedPreferences.setMockInitialValues(
  {_statsKey: jsonEncode(stats.toJson())},
);

Future<GrandPrixStats> _savedStats() async {
  final prefs = await SharedPreferences.getInstance();
  return GrandPrixStats.fromJson(
    jsonDecode(prefs.getString(_statsKey)!) as Map<String, dynamic>,
  );
}

void _setWidth(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Steps the clock frame by frame. The entrances start their tickers from
/// timers, so a single long pump would only render their first frame. The
/// emblem, CTA halo and arena drift loop forever, so never pumpAndSettle.
Future<void> _advance(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<(GrandPrixCubit, GameBloc)> _pumpLobby(
  WidgetTester tester, {
  GameState gameState = const GameState(),
  bool load = true,
  double width = 800,
  ValueChanged<AppSection>? onNavigate,
}) async {
  _setWidth(tester, width);
  final cubit = GrandPrixCubit(SecureGameStorage());
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
        home: GrandPrixLobbyScreen(onNavigate: onNavigate ?? (_) {}),
      ),
    ),
  );
  await _advance(tester, 1400);
  return (cubit, gameBloc);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  // The lobby scrolls when the viewport is short (and the test font is wide).
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _advance(tester, 800);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('spinner while loading keeps the app bar and back', (
    tester,
  ) async {
    AppSection? went;
    await _pumpLobby(tester, load: false, onNavigate: (s) => went = s);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('START RACE'), findsNothing);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    expect(went, AppSection.predictions);
  });

  testWidgets('shell: no driver → PIT DECK → sign → START RACE', (
    tester,
  ) async {
    _setWidth(tester, 800);
    final gameBloc = GameBloc();
    addTearDown(gameBloc.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: gameBloc,
        child: MaterialApp(home: GrandPrixTabContent(onNavigate: (_) {})),
      ),
    );
    await _advance(tester, 1400);
    // The CTA and the secondary button both read PIT DECK.
    expect(find.text('PIT DECK'), findsNWidgets(2));
    expect(find.text('EQUIP YOUR DRIVER AND LIVERY'), findsOneWidget);
    expect(find.text('ROOKIE SEASON'), findsOneWidget);

    await _tap(tester, find.text('PIT DECK').first);
    expect(find.text('SIGN DRIVER'), findsOneWidget);
    await _tap(tester, find.text('SIGN DRIVER'));

    expect(find.byType(GrandPrixLobbyScreen), findsOneWidget);
    expect(find.text('START RACE'), findsOneWidget);
    expect(find.text('EMERALD PARK · 1 LAP · GRID LINE'), findsOneWidget);
  });

  testWidgets('circuit and distance picks persist and feed the helper', (
    tester,
  ) async {
    final (cubit, _) = await _pumpLobby(tester, gameState: _readyState());
    for (final chip in ['XP ×1', 'XP ×2', 'XP ×3']) {
      expect(find.text(chip), findsOneWidget);
    }

    await _tap(tester, find.text('DESERT MILE'));
    await _tap(tester, find.text('GRAND PRIX'));
    expect(cubit.state.circuitId, GrandPrixCircuitId.desertMile);
    expect(cubit.state.laps, 3);
    expect(find.text('DESERT MILE · 3 LAPS · GRID LINE'), findsOneWidget);

    final saved = await _savedStats();
    expect(saved.lastCircuit, GrandPrixCircuitId.desertMile);
    expect(saved.lastLaps, 3);
  });

  testWidgets('BEST reads the personal best for the selected distance', (
    tester,
  ) async {
    _seedStats(
      const GrandPrixStats(
        bestLapMsByCircuit: {'emeraldPark': 62345, 'emeraldPark@5L': 318004},
      ),
    );
    final (cubit, _) = await _pumpLobby(tester, gameState: _readyState());
    expect(find.text('BEST 1:02.345'), findsOneWidget);
    expect(find.text('BEST --:--.---'), findsWidgets);

    await _tap(tester, find.text('ENDURANCE'));
    expect(cubit.state.laps, 5);
    expect(find.text('BEST 5:18.004'), findsOneWidget);
    expect(find.text('BEST 1:02.345'), findsNothing);
  });

  testWidgets('START RACE seeds the grid; RACE AGAIN reseeds; EXIT returns', (
    tester,
  ) async {
    _seedStats(
      const GrandPrixStats(
        lastCircuit: GrandPrixCircuitId.mountainPass,
        lastLaps: 5,
      ),
    );
    final (cubit, _) = await _pumpLobby(
      tester,
      gameState: _readyState(grandPrixXp: 250),
    );
    expect(find.text('MOUNTAIN PASS · 5 LAPS · GRID LINE'), findsOneWidget);

    await _tap(tester, find.text('START RACE'));
    final first = cubit.state.setup!;
    expect(cubit.state.phase, GrandPrixPhase.grid);
    expect(first.circuit.id, GrandPrixCircuitId.mountainPass);
    expect(first.laps, 5);
    expect(first.playerLivery, GrandPrixLivery.gridLine);
    expect(first.playerLevel, 3);
    expect(first.startPosition, inInclusiveRange(8, 16));
    expect(find.text('GRID // MOUNTAIN PASS // 5L'), findsOneWidget);

    await _tap(tester, find.text('RACE AGAIN'));
    expect(identical(cubit.state.setup, first), isFalse);
    expect(find.text('GRID // MOUNTAIN PASS // 5L'), findsOneWidget);

    await _tap(tester, find.text('EXIT'));
    expect(find.byType(GrandPrixLobbyScreen), findsOneWidget);
  });

  testWidgets('an unowned equipped livery falls back to GRID LINE', (
    tester,
  ) async {
    _seedStats(const GrandPrixStats(lastLivery: GrandPrixLivery.scarlet));
    final (cubit, _) = await _pumpLobby(tester, gameState: _readyState());
    expect(cubit.state.livery, GrandPrixLivery.gridLine);
    expect((await _savedStats()).lastLivery, GrandPrixLivery.gridLine);
    expect(find.text('START RACE'), findsOneWidget);
  });

  testWidgets('an owned non-free livery stays equipped', (tester) async {
    _seedStats(const GrandPrixStats(lastLivery: GrandPrixLivery.papaya));
    final (cubit, _) = await _pumpLobby(
      tester,
      gameState: _readyState().copyWith(
        ownedGrandPrixLiveryIds: const ['gridLine', 'papaya'],
      ),
    );
    expect(cubit.state.livery, GrandPrixLivery.papaya);
    expect(find.text('EMERALD PARK · 1 LAP · PAPAYA'), findsOneWidget);
  });

  testWidgets('hero chip counts races, then wins', (tester) async {
    _seedStats(const GrandPrixStats(races: 4));
    await _pumpLobby(tester);
    expect(find.text('4 RACES IN'), findsOneWidget);
  });

  testWidgets('match history lists only Grand Prix results under the career '
      'board', (tester) async {
    _seedStats(
      const GrandPrixStats(
        races: 6,
        wins: 2,
        podiums: 4,
        bestPosition: 1,
        currentStreak: 1,
      ),
    );
    await _pumpLobby(
      tester,
      gameState: _readyState(
        history: const [
          MatchHistoryEntry(
            id: 'gp-1',
            mode: 'grandprix',
            resultLabel: 'Victory',
            summary: 'P1 at Harbour Street',
          ),
          MatchHistoryEntry(
            id: 'bb-1',
            mode: 'basketball',
            resultLabel: 'Defeat',
            summary: 'Hoop Duel loss',
          ),
        ],
      ),
    );
    expect(find.text('2 RACE WINS'), findsOneWidget);

    await _tap(tester, find.text('MATCH HISTORY'));
    expect(find.text('MATCH HISTORY // GRAND PRIX'), findsOneWidget);
    for (final label in ['RACES', 'WINS', 'PODIUMS', 'BEST', 'STREAK']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('P1'), findsOneWidget);
    expect(find.text('P1 at Harbour Street'), findsOneWidget);
    expect(find.text('Hoop Duel loss'), findsNothing);
  });

  testWidgets('the remembered circuit opens in view', (tester) async {
    _seedStats(
      const GrandPrixStats(lastCircuit: GrandPrixCircuitId.coastalSprint),
    );
    await _pumpLobby(tester, gameState: _readyState(), width: 420);
    final card = tester.getRect(find.text('COASTAL SPRINT'));
    expect(card.left, greaterThanOrEqualTo(0));
    expect(card.right, lessThanOrEqualTo(420));
  });

  for (final width in [500.0, 800.0]) {
    testWidgets('lays out without overflow at ${width.toInt()} px', (
      tester,
    ) async {
      await _pumpLobby(tester, gameState: _readyState(), width: width);
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.text('ENDURANCE')).right,
        lessThanOrEqualTo(width),
      );
    });
  }
}
```
