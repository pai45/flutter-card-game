# Pitch Duel Web Design Patterns, Card UI, and Theme Reference

Last reviewed against the web source on 2026-05-17.

This document explains the design patterns used in the implemented Pitch Duel web app. It covers the visual language, CSS theme, layout system, reusable UI patterns, card designs, screen designs, animation patterns, and all implemented cards as they appear in the UI.

## 1. Design Direction

Pitch Duel follows a compact cyber-sports interface style. The app is designed to feel like a futuristic football match terminal rather than a traditional mobile game menu.

The main design traits are:

- Dark sci-fi base surfaces.
- Neon cyan as the primary brand/action color.
- Magenta, lime, amber, and red as semantic accents.
- Angular clipped corners instead of soft rounded cards.
- HUD-style score bars, chips, scanlines, grid overlays, and glowing dividers.
- Dense mobile-first layouts with fixed bottom action bars.
- Trading-card-inspired player cards with ratings, tiers, traits, and image panels.
- Small tactical action cards categorized by attack, defense, and special.
- Animated pack-opening and daily-card reveal moments.

The implementation is mostly custom CSS plus Tailwind utilities. The core design file is:

```txt
src/styles/scifi.css
```

Supporting style files:

```txt
src/styles/theme.css
src/styles/fonts.css
src/styles/tailwind.css
src/styles/index.css
```

## 2. Theme Foundation

### Fonts

Defined in `src/styles/fonts.css`:

```css
@import url("https://fonts.googleapis.com/css2?family=Onest:wght@400;500;600;700;800&family=Orbitron:wght@400;500;600;700;800;900&display=swap");
```

Font roles:

| CSS Variable/Class                 | Font                        | Usage                                          |
| ---------------------------------- | --------------------------- | ---------------------------------------------- |
| `--font-ui`                        | Onest                       | Body text, labels, compact metadata, chips     |
| `--font-display` / `.font-display` | Orbitron                    | Titles, scores, CTAs, card names, cyber labels |
| `.font-mono`                       | Onest with tabular numerals | Used as a pseudo-mono HUD style                |

Important note: `.font-mono` is not a true monospace face in this app. It uses Onest with heavier weight and tabular numbers to create a clean HUD readout.

### Base Color Tokens

Defined in `src/styles/scifi.css`:

| Token                  | Value                      | Role                                     |
| ---------------------- | -------------------------- | ---------------------------------------- |
| `--cyber-bg`           | `#05070d`                  | Deep page background                     |
| `--cyber-bg-2`         | `#0a0e1a`                  | Secondary dark background                |
| `--cyber-panel`        | `#0e1424`                  | Main panel surface                       |
| `--cyber-panel-2`      | `#131b2e`                  | Raised/secondary panel surface           |
| `--cyber-grid`         | `rgba(92, 223, 255, 0.06)` | Ambient background grid                  |
| `--cyber-cyan`         | `#5CDFFF`                  | Primary brand/action color               |
| `--cyber-cyan-soft`    | `rgba(92, 223, 255, 0.4)`  | Cyan glow/border                         |
| `--cyber-magenta`      | `#ff3df7`                  | Special/magenta accent                   |
| `--cyber-magenta-soft` | `rgba(255, 61, 247, 0.45)` | Magenta glow                             |
| `--cyber-lime`         | `#b6ff3d`                  | Success, player scoring, attack emphasis |
| `--cyber-amber`        | `#ffb13d`                  | Warning, penalties, packs                |
| `--cyber-red`          | `#ff2e63`                  | CPU, danger, defeat, red alerts          |
| `--cyber-violet`       | `#8a5cff`                  | Ambient/violet accent                    |
| `--cyber-line`         | `rgba(92, 223, 255, 0.25)` | Default cyber border                     |

The app also includes a generic shadcn-like token layer in `theme.css`, but the active game look mainly comes from `scifi.css` and component-level Tailwind classes.

### Global Background

The body uses:

- A fixed dark background.
- A cyan grid overlay via `body::before`.
- A vignette and ambient radial glow via `body::after`.
- App content is raised above these layers using `#root, .min-h-screen { position: relative; z-index: 1; }`.

Pattern:

```css
body::before {
  background-image:
    linear-gradient(var(--cyber-grid) 1px, transparent 1px),
    linear-gradient(90deg, var(--cyber-grid) 1px, transparent 1px);
  background-size: 40px 40px;
}
```

Design purpose:

- The app always feels like a live tactical interface.
- Screens do not need large decorative backgrounds; the global environment already carries the theme.

## 3. Shape Language

The design avoids rounded-card softness. Most major elements use clipped corners.

Clip utilities:

| Class             | Shape                                                  |
| ----------------- | ------------------------------------------------------ |
| `.clip-cyber`     | Large panel with angled top-left and bottom-right cuts |
| `.clip-cyber-sm`  | Small clipped panel/card                               |
| `.clip-cyber-btn` | Button-specific clipped shape                          |
| `.clip-notch`     | Larger notched block                                   |
| `.clip-tag-l`     | Left tag/ribbon shape                                  |
| `.clip-tag-r`     | Right tag/ribbon shape                                 |

Example:

```css
.clip-cyber {
  clip-path: polygon(
    10px 0,
    100% 0,
    100% calc(100% - 10px),
    calc(100% - 10px) 100%,
    0 100%,
    0 10px
  );
}
```

Design pattern:

- Use clipped panels for HUD surfaces, cards, dialogs, and CTAs.
- Use standard rectangular bars for high-information structural elements like score bars and headers.
- Use circles only for avatar/seal effects, not for main panels.

## 4. Surface and Panel Patterns

### Cyber Panel

Class: `.cyber-panel`

Used for:

- Scenario cards.
- Round logs.
- MVP panel.
- Modal/popup content.
- Compact HUD panels.

Visual properties:

- Dark gradient surface.
- Cyan border.
- Inner highlight.
- Outer cyan glow.

Variant:

```css
.cyber-panel-magenta
```

Used for special/magenta alert states, especially red-card notices.

### Chips

Class: `.chip`

Used for:

- Status text.
- Scenario stat bonuses.
- Deck status.
- Score update labels.
- Penalty labels.

Variants:

| Class           | Meaning                           |
| --------------- | --------------------------------- |
| `.chip`         | Default cyan                      |
| `.chip-magenta` | Special or red-card style         |
| `.chip-lime`    | Success, ready, goal/player score |
| `.chip-amber`   | Warning, draw, penalties          |
| `.chip-red`     | CPU score, danger, loss           |

Pattern:

- Chips are compact and uppercase.
- Chips should not contain long explanatory text.
- They work as HUD labels, not buttons.

## 5. Button Patterns

### Primary Cyber Button

Class:

```txt
cyber-btn clip-cyber-btn
```

Used for:

- Execute move.
- Select cards.
- Final result.
- Rematch.

Visual meaning:

- Primary action.
- Cyan gradient.
- Dark text.
- Strong glow.
- Heavy display font.

### Ghost Cyber Button

Class:

```txt
cyber-btn-ghost clip-cyber-btn
```

Used for:

- Secondary actions.
- Home/deck actions.
- Edit buttons.

Visual meaning:

- Still active, but less important.
- Dark panel surface with cyan text and subtle glow.

### Warning Cyber Button

Class:

```txt
cyber-btn-warn clip-cyber-btn
```

Used for:

- Penalty shootout button.

Visual meaning:

- High-stakes non-normal action.
- Amber/yellow gradient.

### Danger Cyber Button

Class:

```txt
cyber-btn-danger
```

Used for destructive/critical styling where needed.

### Home CTA Block

Classes:

```txt
cta-block cta-primary
cta-block cta-secondary
primary-text-cta
```

Used on Home:

- `Play Match` uses the primary block.
- `Deck Builder` uses the secondary block.
- `How to Play` uses a text CTA.

Pattern:

- Home CTAs are larger than match controls.
- Match controls are more compact and usually fixed at the bottom.

## 6. Animation and Motion Patterns

Animation classes:

| Class/Keyframes              | Use                                        |
| ---------------------------- | ------------------------------------------ |
| `.scanlines`                 | Adds CRT/HUD scanline overlay              |
| `.scan-sweep` / `scan-sweep` | Animated vertical cyan scan through panels |
| `.hud-line` / `pulse-line`   | Pulsing divider line                       |
| `.glitch-hover` / `glitch`   | Small hover jitter                         |
| `.flicker` / `flicker`       | Live/HUD flicker                           |
| `.live-dot`                  | Pulsing red CPU/live indicator             |
| `.card-hover`                | Slight lift and brightness on card hover   |
| `.selected-ring`             | Cyan selection outline and glow            |

Motion library:

- `motion/react` is used in match phases for result reveals, coin spin, icons, penalty kick dots, full-time result icons, and final archive reveal.

Pack opening animations:

- Daily card and shop pack reveals use custom CSS keyframes:
  - `pack-lift`
  - `pack-top-tear`
  - `pack-bottom-tear`
  - `pack-seal-pop`
  - `pack-shine`
  - `burst-pop`
  - `card-reveal`
  - `card-vertical-shimmer`

Design rule:

- Motion is used for important state transitions, not every small UI change.
- The highest-motion moments are coin toss, round result, full-time outcome, and card pack reveal.

## 7. Navigation and Global Header Pattern

File:

```txt
src/app/components/HeaderBar.tsx
```

The header is a shared top HUD bar.

Elements:

- Optional back button.
- Title with leading cyan slash.
- Optional subtitle.
- Optional `Shop` button.
- Optional right slot, used by Deck Builder for `New Deck`.
- Bottom `.hud-line` divider.

Design:

- Gradient from `#0b1120` to `#070b14`.
- Bottom border `#1e2538`.
- Compact 48px-ish height.
- Uppercase Orbitron title.
- Small Onest HUD subtitle.

Back button:

- Cyan.
- Clipped small hover target.
- Uses a left triangle glyph.

Shop:

- Available when `showLive` is true.
- Hidden in Deck Builder by passing `showLive={false}`.
- Opens a modal card shop.

## 8. Score Bar Pattern

File:

```txt
src/app/components/ScoreBar.tsx
```

Used in:

- Toss phase.
- Scenario phase.
- Play phase.
- Round result.
- Full time.

Structure:

- Left: `[P1] You` and player score in cyan.
- Center: round number or label, plus `VS`.
- Right: CPU score in red and `CPU [E1]`.

Design:

- Horizontal dark gradient.
- Bottom border.
- Tabular number display using Orbitron.
- Cyan for player identity.
- Red for CPU identity.

Pattern:

- The score bar is persistent match context.
- It should stay simple and readable; detailed logs are elsewhere.

## 9. Player Card UI Design

File:

```txt
src/app/components/PlayerCardComponent.tsx
```

Player cards are the strongest visual asset in the game. They look like futuristic football trading cards.

### Card Props

```ts
interface Props {
  card: PlayerCard;
  selected?: boolean;
  disabled?: boolean;
  redCarded?: boolean;
  used?: boolean;
  onClick?: () => void;
  size?: "sm" | "md";
}
```

### Card Sizes

| Size | Width  | Height | Use                                                   |
| ---- | ------ | ------ | ----------------------------------------------------- |
| `sm` | `w-24` | `h-36` | Match selection, deck builder pitch, compact displays |
| `md` | `w-32` | `h-48` | Daily card reveal, shop reveal                        |

### Anatomy

Each player card includes:

- Clipped card frame.
- Tier-colored border and glow.
- Image area from `card.image`.
- Fallback graphic if the image fails.
- Top-right rating badge.
- Top-left role tag (`ATK` or `DEF`).
- Trait strip above the name plate.
- Bottom name plate.
- Optional used badge.
- Optional red-card overlay.
- Optional selected ring.

### Tier Styles

Defined inside `PlayerCardComponent.tsx`.

| Tier   | Border    | Accent    | Background Gradient              | Glow Class    |
| ------ | --------- | --------- | -------------------------------- | ------------- |
| silver | `#8e9aab` | `#aeb8c8` | silver/steel gradient            | `glow-silver` |
| gold   | `#ffb13d` | `#ffb13d` | white/gold/orange gradient       | `glow-gold`   |
| purple | `#ba6eff` | `#ba6eff` | pale purple/deep violet gradient | `glow-purple` |

Design meaning:

- Silver: lower/common tier.
- Gold: high-value tier.
- Purple: premium/elite tier.

### Fallback Image Pattern

If the player image fails to load:

- `imageFailed` state becomes true.
- The image area renders a graphic gradient with the player's `GameIcon`.
- This keeps card layout intact even with missing assets.

### Interaction States

| State     | Visual                                         |
| --------- | ---------------------------------------------- |
| default   | Tier glow, clickable card                      |
| hover     | Lifts and brightens via `.card-hover`          |
| selected  | Cyan outline and glow via `.selected-ring`     |
| disabled  | Low opacity, grayscale, not clickable          |
| used      | Inactive if prop is passed; shows `USED` badge |
| redCarded | Red overlay with close icon                    |

Important implementation note:

- The component supports `used` and `redCarded`, but the match selection screen currently filters red cards and does not pass `used` for normal card reuse.

## 10. Action Card UI Design

File:

```txt
src/app/components/ActionCardComponent.tsx
```

Action cards are smaller tactical command cards.

### Card Props

```ts
interface Props {
  card: ActionCard;
  selected?: boolean;
  disabled?: boolean;
  used?: boolean;
  onClick?: () => void;
  size?: "sm" | "md";
}
```

### Card Sizes

| Size | Width  | Height | Use                       |
| ---- | ------ | ------ | ------------------------- |
| `sm` | `w-20` | `h-24` | Match/deck builder        |
| `md` | `w-24` | `h-32` | Larger displays if needed |

### Anatomy

Each action card includes:

- Clipped rectangular body.
- Category tag at top-left.
- Power badge at top-right.
- Icon.
- Uppercase title.
- Effect text.
- Risk warning icon if risky.
- Optional used badge.
- Optional selected ring.

### Category Styles

Defined inside `ActionCardComponent.tsx`.

| Category | Code  | Border    | Label Color | Background            | Meaning               |
| -------- | ----- | --------- | ----------- | --------------------- | --------------------- |
| attack   | `ATK` | `#b6ff3d` | lime        | green/dark gradient   | Offensive move        |
| defense  | `DEF` | `#5CDFFF` | cyan        | blue/dark gradient    | Defensive move        |
| special  | `SPC` | `#ff3df7` | magenta     | magenta/dark gradient | Flexible/utility move |

Risky action treatment:

- Risky cards get a magenta/red ring.
- A warning icon appears near the bottom-left.
- Risk is mechanical: risky attack can produce `foul`; risky defense can produce `red-card`.

## 11. Complete Player Card Catalog

Source:

```txt
src/app/data/cards.ts
```

### Attackers

| ID     | Name         | Role     | Rating | Tier   | Trait             | Icon      | Image                     |
| ------ | ------------ | -------- | -----: | ------ | ----------------- | --------- | ------------------------- |
| `atk1` | Marcus Blaze | attacker |     92 | gold   | Clinical Finisher | `bolt`    | `/player-images/atk1.png` |
| `atk2` | Leo Viper    | attacker |     95 | purple | Dribble King      | `target`  | `/player-images/atk2.png` |
| `atk3` | Kai Thunder  | attacker |     88 | silver | Speed Demon       | `run`     | `/player-images/atk3.png` |
| `atk4` | Dante Fury   | attacker |     90 | gold   | Aerial Threat     | `fire`    | `/player-images/atk4.png` |
| `atk5` | Riku Storm   | attacker |     86 | silver | Long Range        | `water`   | `/player-images/atk5.png` |
| `atk6` | Zane Phantom | attacker |     93 | purple | Ghost Run         | `phantom` | `/player-images/atk6.png` |

### Defenders

| ID     | Name        | Role     | Rating | Tier   | Trait        | Icon      | Image                     |
| ------ | ----------- | -------- | -----: | ------ | ------------ | --------- | ------------------------- |
| `def1` | Iron Wall   | defender |     91 | gold   | Unbreakable  | `shield`  | `/player-images/def1.png` |
| `def2` | Shadow Lock | defender |     89 | silver | Man Marker   | `lock`    | `/player-images/def2.png` |
| `def3` | Granite     | defender |     94 | purple | Brick Wall   | `terrain` | `/player-images/def3.png` |
| `def4` | Hawk Eye    | defender |     87 | gold   | Interceptor  | `eye`     | `/player-images/def4.png` |
| `def5` | Steel Trap  | defender |     85 | silver | Slide Master | `block`   | `/player-images/def5.png` |
| `def6` | Aegis       | defender |     93 | purple | Last Stand   | `temple`  | `/player-images/def6.png` |

## 12. Complete Action Card Catalog

Source:

```txt
src/app/data/cards.ts
```

| ID      | Title             | Category | UI Code | Power | Risky | Icon          | Effect Text              |
| ------- | ----------------- | -------- | ------- | ----: | ----- | ------------- | ------------------------ |
| `act1`  | Through Ball      | attack   | ATK     |    15 | no    | `arrow`       | +15 Attack Power         |
| `act2`  | Power Shot        | attack   | ATK     |    20 | no    | `score`       | +20 Attack, -5 Accuracy  |
| `act3`  | Skill Move        | attack   | ATK     |    12 | no    | `spark`       | +12 Attack, Bypass Trait |
| `act4`  | Cut Inside        | attack   | ATK     |    10 | no    | `return`      | +10 Attack, +5 Scenario  |
| `act5`  | Long Shot         | attack   | ATK     |    25 | yes   | `target`      | +25 Attack, High Risk    |
| `act6`  | Quick Break       | attack   | ATK     |    18 | no    | `bolt`        | +18 Counter Bonus        |
| `act7`  | Slide Tackle      | defense  | DEF     |    15 | no    | `shield`      | +15 Defense Power        |
| `act8`  | Press High        | defense  | DEF     |    12 | no    | `north`       | +12 Defense, Disrupt     |
| `act9`  | Block Lane        | defense  | DEF     |    10 | no    | `block`       | +10 Defense, +5 Position |
| `act10` | Tight Marking     | defense  | DEF     |    14 | no    | `person`      | +14 Defense Power        |
| `act11` | Intercept         | defense  | DEF     |    18 | no    | `hand`        | +18 Defense, Read Play   |
| `act12` | Last-Ditch Tackle | defense  | DEF     |    22 | yes   | `warning`     | +22 Defense, Foul Risk   |
| `act13` | All In            | special  | SPC     |    30 | yes   | `red-card`    | +30 Power, Red Card Risk |
| `act14` | Tactical Foul     | special  | SPC     |     8 | yes   | `yellow-card` | Stop Play, Yellow Risk   |
| `act15` | Mind Game         | special  | SPC     |    10 | no    | `mind`        | -10 Opponent Power       |
| `act16` | Fast Recovery     | special  | SPC     |     8 | no    | `wind`        | +8 All Stats             |

Design note:

- The UI displays the `effect` text, but the current resolver only uses `power`, `category`, and `risky`.
- Therefore, all cards visually imply flavor and tactics, while mechanics are intentionally simple.

## 13. Scenario UI Cards

Scenarios are displayed in `ScenarioPhase`.

Scenario panel pattern:

- Uses `.cyber-panel`, `.clip-cyber`, and `.scan-sweep`.
- Large icon.
- Uppercase cyan Orbitron title.
- Small gray Onest description.
- Two stat chips:
  - Lime attack bonus.
  - Cyan defense bonus.
- Role banner:
  - Lime for attacking.
  - Cyan for defending.

Scenario catalog:

| ID    | Title                | Icon     | Attack Bonus | Defense Bonus | UI Flavor                     |
| ----- | -------------------- | -------- | -----------: | ------------: | ----------------------------- |
| `sc1` | Counter Attack       | `bolt`   |            8 |             3 | Fast transition               |
| `sc2` | 1v1 Final Third      | `target` |            5 |             5 | Balanced duel                 |
| `sc3` | Set Piece Chance     | `brief`  |            6 |             6 | Balanced set play             |
| `sc4` | Last Minute Pressure | `timer`  |           10 |             2 | Attack-favored clutch         |
| `sc5` | Box Defense          | `wall`   |            2 |            10 | Defense-favored packed box    |
| `sc6` | Wide Break           | `run`    |            7 |             4 | Attack-favored flank          |
| `sc7` | Penalty Box Chaos    | `score`  |            8 |             8 | High-intensity balanced chaos |

## 14. Screen-Level Design Patterns

### Home Screen

File:

```txt
src/app/components/screens/HomeScreen.tsx
```

Design patterns:

- Centered vertical terminal menu.
- Large soccer icon as app marker.
- Deck status chip.
- Three main navigation actions.
- Compact loadout status panel.
- Fixed bottom Daily Drop CTA.
- Tutorial overlay support.

Visual hierarchy:

1. Brand/title in header.
2. Soccer icon and deck status.
3. Play Match primary CTA.
4. Deck Builder secondary CTA.
5. How to Play text CTA.
6. Loadout counts.
7. Daily Drop persistent bottom CTA.

### Deck Builder Screen

File:

```txt
src/app/components/screens/DeckBuilderScreen.tsx
```

Design patterns:

- Top header with `New Deck`.
- Horizontal deck pill selector.
- Large 5-a-side pitch card.
- Formation slots for two attackers, two defenders, and a decorative keeper core.
- Action card strip for six action cards.
- Edit mode reveals tabs and selection panel.
- Fixed bottom action bar with `Edit/Save` and `Play`.

Pitch design:

- Dark green/cyan tactical field.
- Pitch lines via CSS pseudo-elements.
- Attacker slots near top.
- Defender slots in middle.
- Keeper core near bottom.
- Formation cards use small player cards.

Deck pill pattern:

- Default pill is dark with cyan border.
- Active pill uses lime/cyan gradient and a glowing underline.

Selection panel:

- Flex-wrap card grid.
- Player and action cards reuse the real card components.
- Disabled cards are handled at the card component level.

### Match Flow Screens

Files:

```txt
src/app/components/screens/match/TossPhase.tsx
src/app/components/screens/match/ScenarioPhase.tsx
src/app/components/screens/match/PlayPhase.tsx
src/app/components/screens/match/RoundResultPhase.tsx
src/app/components/screens/match/MatchEndPhase.tsx
src/app/components/screens/match/PenaltyPhase.tsx
src/app/components/screens/match/FinalResultPhase.tsx
```

Shared match patterns:

- HeaderBar at top.
- ScoreBar below header when relevant.
- Dark full-screen layout.
- Phase-specific animated center content.
- Fixed or sticky bottom action button.
- Tutorial overlay per phase.
- Back button opens quit confirmation during active match.

### Toss Phase

Design:

- Centered coin icon.
- Heads/tails segmented choices.
- Cyan selected state.
- Coin spin animation on result.
- Player-won state uses cyan.
- Opponent-won state uses red.
- CPU choice appears as a clipped role chip.

### Scenario Phase

Design:

- Single large cyber panel.
- Scan sweep.
- Scenario icon and title.
- Attack/defense bonus chips.
- Role banner.
- Primary bottom-ish `SELECT CARDS` button.

### Play Phase

Design:

- Opponent strip at top with red CPU identity.
- Hidden CPU cards as question-mark placeholders.
- Status and power preview panel.
- Selected player/action preview shown before execution.
- Horizontal scroll for player roster.
- Grid for action cards.
- Sticky bottom execute button.

Color language:

- Player role and estimated power use cyan/lime.
- CPU strip uses red/magenta.
- Incomplete state uses gray.
- Ready state uses cyan.

### Round Result Phase

Design:

- Large animated outcome icon.
- Outcome label in semantic color.
- Optional score chip.
- Scenario and role metadata line.
- Attacker vs defender card layout.
- Red-card/foul alerts.
- Bottom `NEXT ROUND` or `FULL-TIME RESULT` button.

Outcome visual map:

| Outcome    | Label    | Color   | Icon          |
| ---------- | -------- | ------- | ------------- |
| `goal`     | GOAL     | lime    | `soccer`      |
| `saved`    | SAVED    | cyan    | `hand`        |
| `blocked`  | BLOCKED  | gray    | `block`       |
| `missed`   | MISSED   | amber   | `wind`        |
| `foul`     | FOUL     | amber   | `yellow-card` |
| `red-card` | RED CARD | magenta | `red-card`    |

### Match End Phase

Design:

- Full-time result screen.
- Radial background glow changes by result:
  - Draw: amber.
  - Player win: cyan.
  - Player loss: red.
- Large result icon:
  - Draw: balance.
  - Win: trophy.
  - Loss: close.
- Round log panel.
- Bottom action:
  - Penalty shootout if tied.
  - Final result if not tied.

### Penalty Phase

Design:

- Penalty score bar, separate from regular ScoreBar.
- Kick rows for player and CPU.
- Empty slots are small clipped boxes.
- Goals render soccer icons in lime.
- Miss/saved render close icons in red.
- Center state alternates between player kick button and CPU thinking text.
- Result state shows trophy or close icon.

### Final Result Phase

Design:

- Archive-style final screen.
- Large trophy/broken icon.
- Regular score panel.
- Optional penalty chip.
- Optional MVP panel.
- Round log.
- Three fixed bottom actions: Rematch, Home, Deck.

## 15. Shop and Pack Reveal Design

File:

```txt
src/app/components/HeaderBar.tsx
```

The shop is opened from `HeaderBar` when `showLive` is true.

Pack options:

| Pack          | CSS Class            | Coins | Visual Theme                        |
| ------------- | -------------------- | ----: | ----------------------------------- |
| Bronze Pack   | `shop-pack-bronze`   |    10 | bronze/copper gradient              |
| Silver Pack   | `shop-pack-silver`   |    50 | steel/silver gradient               |
| Gold Pack     | `shop-pack-gold`     |   250 | gold/yellow gradient                |
| Platinum Pack | `shop-pack-platinum` |  1000 | blue/silver/purple premium gradient |

Shop pattern:

- Full-screen overlay.
- Blurred dark backdrop.
- Clipped cyber panel.
- Two-column pack grid.
- Pack card with top-right icon and price.
- Opening state uses the same animated pack reveal system as Daily Drop.

Owned cards storage:

```txt
pd_owned_cards_v1
```

Design note:

- Shop reveal says `Added to your cards`.
- The current deck builder does not visibly consume this owned-card collection; card catalog access is still global.

## 16. Daily Drop Design

File:

```txt
src/app/components/screens/HomeScreen.tsx
```

Daily Drop CTA:

- Fixed bottom button.
- Amber/orange/magenta gradient.
- Strong shadow and shine sweep.
- Pack/cards icon block.

Daily reveal overlay:

- Full-screen dark/blurred backdrop.
- Animated pack tear.
- Radial burst rays.
- Revealed player card in medium size.
- Card generated label.
- Player name and role/trait metadata.

Design note:

- Despite the name Daily Drop, the current implementation allows repeated opens and does not persist a daily timer.

## 17. Modal and Confirmation Pattern

The app uses confirmation dialogs for:

- Quitting an active match.
- Discarding dirty deck changes.

Design behavior:

- Destructive actions are explicit.
- The user can cancel and return to the current flow.
- Match quit resets state and navigates home.
- Deck discard exits without saving.

Pattern:

- Use confirmation only when progress or edits would be lost.
- Do not interrupt normal navigation where no data is dirty.

## 18. Responsive and Layout Patterns

The app is mobile-first.

Common patterns:

- `min-h-screen flex flex-col` for full-screen screens.
- Header and score at top.
- Scrollable center content with `flex-1 overflow-y-auto`.
- Sticky/fixed bottom action areas.
- Max widths around `max-w-xs`, `max-w-sm`, or `max-w-md`.
- Horizontal scrolling for card rows where needed.
- Compact cards for mobile density.

Deck builder responsive detail:

```css
@media (max-width: 380px) {
  .five-side-pitch {
    height: 370px;
  }
  .formation-player {
    width: 88px;
    min-height: 132px;
  }
  .formation-empty-card {
    width: 88px;
    height: 132px;
  }
}
```

Design purpose:

- Preserve the pitch layout on narrow devices.
- Reduce card/slot footprint instead of letting overlap break the formation.

## 19. State-Driven Visual Design Patterns

The UI consistently maps game state to color and structure.

### Player vs CPU

| Entity            | Color |
| ----------------- | ----- |
| Player / You / P1 | cyan  |
| CPU / E1          | red   |

### Role

| Role      | Color |
| --------- | ----- |
| Attacking | lime  |
| Defending | cyan  |

### Results

| Result Type                        | Color   |
| ---------------------------------- | ------- |
| Goal / success                     | lime    |
| Saved / neutral player-facing info | cyan    |
| Miss / draw / penalty              | amber   |
| CPU danger / loss                  | red     |
| Red card / special danger          | magenta |

### Readiness

| State             | UI                            |
| ----------------- | ----------------------------- |
| Ready deck        | lime chip                     |
| Incomplete deck   | amber chip                    |
| Executable move   | cyan status and active button |
| Missing selection | gray/inactive button          |
| Selected card     | cyan ring                     |

## 20. Reusable Design Patterns in Code

### Composition Over Generic Abstractions

The app does not create a large formal design-system component API. Instead, it composes:

- Small shared components: `HeaderBar`, `ScoreBar`, `PlayerCardComponent`, `ActionCardComponent`, `GameIcon`, `Toast`, `TutorialTip`, `ConfirmDialog`.
- CSS utility classes from `scifi.css`.
- Tailwind classes directly in screen components.

This is a practical pattern for a small game UI:

- Fast to iterate.
- Visual style remains centralized through CSS classes.
- Screen-level layouts stay explicit.

### Reducer State Drives Screens

Design state is derived from game state:

- `phase` decides which screen is rendered.
- `playerAttacking` changes labels, colors, card filters, and icons.
- `selectedPlayerCard` and `selectedActionCard` drive preview panels.
- `roundResults` drive logs and final archive.
- `penaltyPhaseOver` changes the penalty screen from action mode to result mode.

### Shared Card Components

Player and action cards are reused everywhere:

- Deck builder.
- Match selection.
- Round result.
- Final MVP.
- Daily card.
- Shop reveal.

This gives the game a coherent collectible-card identity.

## 21. Design Caveats and Current Inconsistencies

These are useful if the design is extended later:

1. Some older generic theme tokens exist in `theme.css`, but the active game look uses `scifi.css`.
2. The UI supports `used` card states, but normal match selection does not currently show/disable used cards.
3. The shop persists owned card IDs, but deck builder still exposes the full card catalog.
4. Daily Drop is visually daily-themed but not time-limited.
5. The app includes strong desktop-compatible layouts, but the visual density and fixed bottom controls are clearly optimized for mobile.
6. Some button text and symbols include encoded glyph artifacts in file output; visually they are used as HUD arrows/markers.

## 22. Future Design Extension Guidelines

If new screens or cards are added, follow these patterns:

- Use dark backgrounds and cyber panels, not light cards.
- Use clipped corners for panels, cards, and buttons.
- Keep cyan as the primary action/identity color.
- Use lime for player attacking success and goals.
- Use red for CPU and loss states.
- Use amber for warnings, draws, and penalty moments.
- Use magenta for special cards and red-card intensity.
- Reuse `PlayerCardComponent` and `ActionCardComponent` wherever cards appear.
- Keep match screens focused on one decision at a time.
- Use fixed bottom actions for mobile ergonomics.
- Prefer compact chips and icon labels over long instructional text inside the active game UI.
- Keep animation reserved for state transitions and reward moments.

## 23. File Map for Design Work

| File                                               | Purpose                                        |
| -------------------------------------------------- | ---------------------------------------------- |
| `src/styles/scifi.css`                             | Main custom game theme, components, animations |
| `src/styles/theme.css`                             | Base Tailwind/theme tokens                     |
| `src/styles/fonts.css`                             | Google font imports                            |
| `src/styles/index.css`                             | Style import aggregator                        |
| `src/app/components/HeaderBar.tsx`                 | Header, shop, pack opening                     |
| `src/app/components/ScoreBar.tsx`                  | Match score HUD                                |
| `src/app/components/PlayerCardComponent.tsx`       | Player card design                             |
| `src/app/components/ActionCardComponent.tsx`       | Action card design                             |
| `src/app/components/GameIcon.tsx`                  | Icon abstraction used across UI                |
| `src/app/components/screens/HomeScreen.tsx`        | Home and Daily Drop                            |
| `src/app/components/screens/DeckBuilderScreen.tsx` | Pitch/deck composition                         |
| `src/app/components/screens/match/*.tsx`           | Match phase visuals                            |
| `src/app/data/cards.ts`                            | Card and scenario content driving UI           |
