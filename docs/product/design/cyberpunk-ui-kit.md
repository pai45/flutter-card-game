# StatOz Cyberpunk UI Kit

> **Status:** BUILT
> **Last verified:** 2026-10-03
> **Scope:** Reusable technical components, sport unlock sheets, Guess the Player and Guess the Driver lobbies

## Product Purpose

Make opening a new sport feel like gaining access to a playable game route.
The [Cyberpunk 2077 UI Art reference](https://www.behance.net/gallery/120401689/Cyberpunk-2077-UI-Art)
informs the fine frames, angular silhouettes and compact labels. StatOz supplies
the cyan actions, sport identity, gold rewards and Orbitron/Onest typography.
All artwork is composed from code and existing icons.

## Where It Lives

Every sport unlock bottom sheet adopts the kit. Import components through
`lib/widgets/cyber/cyber_widgets.dart`; implementation is in `cyber_kit.dart`.
`CyberKit` in `lib/config/theme.dart` owns shared dimensions and motion values.
Existing buttons and panels retain their default appearance.
The Guess the Player lobbies use the full-screen kit across Cricket, Football,
and Basketball: each uses
the framed case surface, sport emblem, status/reward badges, section rules, and
primary/secondary actions while keeping its existing game and archive flows.
Guess the Driver uses that same dossier layout with a Motorsport emblem, a
heart-budget badge in place of XP, race records, and its existing daily and
archive routes. `DailyCaseLobby` is the shared layout under `cyber_widgets.dart`.

## Player Flow

1. Select a locked sport and read what access opens.
2. Preview the featured first game and subsequent prerequisite route.
3. Review balance, 50 OZ cost and remaining balance.
4. Unlock, or visit quests if more OZ is needed.
5. Continue through the existing sport-unlocked celebration.

## Mechanics and Rules

| Component | Usage |
|---|---|
| `CyberKitSheet(body, footer, onClose)` | Framed sheet with close control; docks footer on roomy screens, otherwise scrolls everything. |
| `CyberKitSection(label, count)` | Section label with optional count and segmented rule. |
| `CyberSportEmblem(icon, accent)` | Flat sport identity plate; never glows. |
| `CyberStatusBadge(label, tone)` | Available, locked and reward labels, with meaning in text as well as color. |
| `CyberProgressionEntry(index, title, icon, detail, featured, last)` | Informational numbered route; never implies the game can launch before purchase. |
| `CyberActionButton(label, onPressed, variant, icon, loading, bare)` | Primary, secondary or icon control. `bare` removes the icon utility surface while retaining its 48 px target. Null callback or loading blocks activation. |

Use one enabled primary action per composition. Secondary actions have a dark
fill and cyan outline; compact icon controls require a descriptive label.
All actions have at least a 48 px touch target, keyboard Enter/Space activation,
focus indication, pointer feedback and semantic button labels. Text wraps and
grows controls. Loading displays a static hourglass and announces WORKING.

Top-left and bottom-right chamfers share `HudChamferClipper` and
`ChamferedActionSurface`, including the diagonal border segments. Colors stay
in `Cyber`/`AppTheme`. No noise, fake telemetry or persistent glitch effects.

```dart
CyberActionButton(
  label: 'VIEW QUESTS',
  variant: CyberActionVariant.secondary,
  icon: Icons.flag_outlined,
  onPressed: openQuests,
)
```

## Rewards and Progression

The kit changes presentation only. Sport access still costs 50 OZ, opens the
first configured game and queues the existing reveal. Game order, quest rewards
and persistence remain owned by the existing unlock system.

## Gratification and Feedback

Entrance fade/slide lasts 220 ms; a 90 ms press response accompanies the single
sound/haptic emitted by the action control. The purchase callback must not add
another tap cue. Reduced motion removes entrance and press animation. The
primary action has a steady, restrained halo instead of a repeating pulse.

## Visible States

- Affordable, including exactly 50 OZ: purchase enabled, remaining balance visible.
- Insufficient: purchase disabled, exact shortfall and primary VIEW QUESTS.
- Already owned: purchase disabled, SPORT ALREADY OPEN.
- Dismissing: local guard prevents repeat purchase dispatch.
- Components: default, hover, focus, pressed, disabled and loading.

## Persistence

No new persisted state or migrations. `GameBloc` and `UnlockProgress` remain
authoritative. Gallery controls and purchases use in-memory fixtures only.

## Planned Scope and Current Limitations

- **BUILT:** All sport unlock sheets, all three Guess the Player lobbies, the Guess the Driver lobby, and the focused reusable kit.
- **PROTOTYPE:** Isolated gallery at `tool/cyber_kit_preview.dart`; not in player navigation.
- Other sheets and mission ladders do not adopt this family in this rollout.

## Implementation References

- [Shared kit](../../../lib/widgets/cyber/cyber_kit.dart)
- [Sport unlock sheets](../../../lib/screens/predictions/widgets/unlock_sheets.dart)
- [Interactive gallery](../../../tool/cyber_kit_preview.dart)
- [Shared Guess the Player lobby](../../../lib/screens/guess_player/guess_player_lobby.dart)
- [Shared daily case layout](../../../lib/widgets/cyber/daily_case_lobby.dart)
- [Guess the Driver lobby](../../../lib/screens/guess_driver/guess_driver_home_screen.dart)

Run `flutter run -d chrome -t tool/cyber_kit_preview.dart`. The gallery includes
all sports, 0/49/50/80 OZ balances, 393 px normal and 320 px enlarged text, short
height, reduced motion, and a component page. Use Tab, pointer hover and press
to inspect interaction states. Reset restores the fixture.

## Tests

- `test/cyber_kit_test.dart`: route content/layout, purchase/dismissal/quest actions,
  accessible buttons, keyboard and reduced motion.
- `test/sport_unlock_bloc_test.dart`: actual spend, owned/broke guards and reveal queue.
- `test/quest_experience_test.dart`: existing quest and sheet regressions.
- `test/cricket_guess_player_lobby_test.dart`: lobby states, actions,
  narrow layout, and all three sport variants.
- `test/daily_mystery_ui_test.dart`: Guess the Driver fresh, resumed, completed,
  and visual snapshot states.
