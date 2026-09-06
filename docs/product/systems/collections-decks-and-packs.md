# Collections, Decks, Cards, Packs, Starter Packs, and Daily Drops

> **Status:** BUILT
> **Last verified:** 2026-09-05
> **Scope:** Card ownership, sport decks, pack opening, starter entitlement, duplicate handling, and daily drops

## Product Purpose

The collection system gives play a durable metagame: acquire cards, reveal
rarities, build eligible sport squads/decks, and bring owned content into game
modes such as Pitch Duel, Football Chess, Grand Prix Dash, Final Over,
Basketball, and Tennis.

## Where It Lives

Collections are exposed through All Cards, the Deck Locker (All Decks),
mode-specific deck builders, home starter-pack onboarding, daily drops, shop
packs, and pack reveal flows.

The Deck Locker (Profile → **ALL DECKS**) is sport-tabbed, matching the GAMES
tab's sport strip (Football, Cricket, Basketball, Tennis, Motorsport — one
tab per sport, sliding accent-coloured underline). Each tab shows that sport's
real equipped squad as cards (attack/defence/keeper/action-deck groups for
Football, batting order for Cricket, rotation for Basketball, a hero athlete
card for Tennis/Motorsport), a fill meter, and a docked **EDIT LOADOUT** /
**BUILD LOADOUT** CTA into that sport's deck builder — the tab's one glowing
element. A tab whose starter pack is still unclaimed shows a locked state
(lock icon, sport-accent messaging) with a **PLAY \<SPORT\>** action that
routes to that sport's GAMES tab, where launching the game claims the starter
pack (see the starter-pack gates below) and returns the player to a filled
loadout. The locker no longer exposes multi-squad slot switching or squad
creation — that management (the `SQUAD CHANNEL` pill row and **New squad**)
now lives only inside the football deck builder
([`lib/screens/deck/deck_builder_screen.dart`](../../../lib/screens/deck/deck_builder_screen.dart)),
reachable from Pitch Duel's DECK section; the underlying multi-squad model
(`StoredDeckSlot`, `DeckCreated`/`DeckApplied`) is unchanged.

## Player Flow

1. Receive or buy a pack, starter pack, direct card, or daily drop.
2. Open the reveal sequence and collect cards, XP, and duplicate compensation.
3. Inspect the updated collection.
4. Build a mode-eligible deck/roster and save it.
5. Enter a game that validates the deck requirements.

## Mechanics and Rules

Cards carry sport/type/rarity and gameplay attributes. Deck validation is
mode-specific. Starter packs are granted once per eligible mode/account state.
Pack assembly controls slots and rarity rolls; the application step owns card
unlocking, XP, ledgers, and duplicate handling.

### Cricket card portraits

Cricket player cards resolve their portrait from the player-card display name,
using the canonical `assets/cricketer_images/<lowercase_name>.webp` path. The
collection currently includes supplied portraits for Devdutt Padikkal, Romario
Shepherd, Shardul Thakur, Jamie Overton, Washington Sundar, Ayush Badoni, Tom
Banton, Finn Allen, Marco Jansen, Nitish Rana, Krunal Pandya, Mitchell Santner,
Rahul Tripathi, Glenn Phillips, Jason Holder, Matthew Short, Azmatullah Omarzai,
Shashank Singh, Ben Duckett, Dhruv Jurel, Vaibhav Sooryavanshi, Kamindu Mendis,
Rovman Powell, Jitesh Sharma, Josh Inglis, Jonny Bairstow, Sanju Samson,
Yashasvi Jaiswal, MS Dhoni, Travis Head, and 35 newly supplied IPL roster
portraits. The archive labels match each player-card ID exactly and contain no
duplicates; the canonical display-name resolver loads the art onto its matching
card. Other cricket cards retain their existing resolved portrait or icon
fallback.

### Basketball player portraits

Hoop Duel player cards use explicit current-roster ID mappings. The collection
now includes 180 supplied player portraits, including three newly added labelled
WebP portraits; cards outside the mapped set retain the existing icon fallback.
The supplied basketball labels were unique, so the first-occurrence policy did
not need conflict resolution.

### Tennis player portraits

Tennis player cards use explicit roster-ID mappings. Fifty-three supplied tennis
portraits are available from the current archives. Diana Shnaider had two labelled
files; the first archive entry (`diana-shnaider-2.webp`) is used for her one
canonical card, as required. Other tennis cards retain the existing icon
fallback when no portrait is mapped.

### Motorsport driver portraits

Motorsport player cards use their stable roster ID as the portrait label. The
collection ships 105 exact roster matches: the existing 22 F1 PNG portraits and
83 supplied F2, NASCAR, and IndyCar WebP portraits. The archive's labels were
unique, so its first-occurrence rule requires no conflict resolution.

### Football player portraits

Football player cards resolve portraits from their short labels. The supplied
portraits for Ederson Moraes, Aurélien Tchouaméni, Bart Verbruggen, and Vinícius
Júnior are mapped to their exact current card IDs. Their archive labels are
unique; the first-occurrence policy therefore required no conflict resolution.

## Rewards and Progression

Revealed cards grant Cards/Meta XP based on card type and rating/power. Packs
and daily drops can also affect the collection and wallet through explicit
settlement sources. Rewards are applied before or independently of skippable
presentation so animation cannot duplicate them.

## Gratification and Feedback

Card-by-card unpacking, rarity stings, pack summaries, collection deltas, level
progress, and starter-pack onboarding provide the system's main reveal moments.

## Visible States

Unowned/owned/duplicate cards, locked/eligible deck slots, invalid/valid saved
decks, unopened/revealing/complete packs, starter-pack eligibility, and
available/claimed daily drops are represented. The Deck Locker additionally
renders, per sport tab: locked (starter pack unclaimed, routes to GAMES),
unlocked-but-incomplete (`BUILD LOADOUT`, empty card slots for unfilled
roles), and unlocked-ready (`READY` chip, `EDIT LOADOUT`, a just-saved
confirmation seal).

## Persistence

Owned cards, saved decks, pack/daily-drop claims, starter entitlements, XP, and
ledger records persist through `SecureGameStorage` and shared game state.

## Planned Scope and Current Limitations

- **BUILT:** Shared football collections plus mode-specific deck/roster and
  starter-pack paths already present in code.
- **PLANNED:** New sports must define card schema, deck eligibility, duplicate
  behavior, settlement source, and migration before joining the shared catalog.

## Implementation References

- [`lib/models/packs.dart`](../../../lib/models/packs.dart)
- [`lib/models/starter_pack.dart`](../../../lib/models/starter_pack.dart)
- [`lib/models/deck.dart`](../../../lib/models/deck.dart)
- [`lib/screens/deck/all_cards_screen.dart`](../../../lib/screens/deck/all_cards_screen.dart)
- [`lib/screens/deck/all_decks_screen.dart`](../../../lib/screens/deck/all_decks_screen.dart)
- [`lib/widgets/card_unpack_animation.dart`](../../../lib/widgets/card_unpack_animation.dart)
- [`lib/screens/home/widgets/daily_drop.dart`](../../../lib/screens/home/widgets/daily_drop.dart)

## Tests

- [`test/starter_pack_test.dart`](../../../test/starter_pack_test.dart)
- [`test/game_daily_drop_reveal_test.dart`](../../../test/game_daily_drop_reveal_test.dart)
- [`test/shared_deck_locker_test.dart`](../../../test/shared_deck_locker_test.dart)
- [`test/deck_locker_widget_test.dart`](../../../test/deck_locker_widget_test.dart)
- [`test/basketball_portraits_test.dart`](../../../test/basketball_portraits_test.dart)
- [`test/football_portraits_test.dart`](../../../test/football_portraits_test.dart)
- [`test/cricket_portraits_test.dart`](../../../test/cricket_portraits_test.dart)
- [`test/racing_portraits_test.dart`](../../../test/racing_portraits_test.dart)
