# Sport and Game Unlocks (Beginner's Quest)

> **Status:** BUILT
> **Last verified:** 2026-10-04
> **Scope:** The home sport chosen at onboarding, locked sports and games, the per-sport Beginner's Quest ladder that opens games by playing, and the 50 Oz sport unlock.

## Product Purpose

A first-time player used to land on 5 sports and 18 games at once. Unlocks
pace that: a new player starts in **one home sport**, chooses any first game,
and opens the rest one mission at a time. Every completed mission pays back
with a celebration and the choice of the next game. Other sports stay visible as locked
teasers, so the player knows there is more to earn.

## Where It Lives

- **Onboarding.** Step 3 of profile setup is **PICK YOUR HOME SPORT**
  (single-select). Its clubs page follows. See
  [Profile, Onboarding, and Settings](profile-onboarding-and-settings.md).
- **Sports hub sport strip (MATCH and GAMES).** Unlocked sports come first,
  home sport leading. Locked sports trail as dimmed icons with a gold padlock
  seal, and tapping one opens the **UNLOCK SPORT** sheet. TRENDING is hidden
  while only one sport is open; once it returns, its match and games feeds
  show only tiles from unlocked sports. A stored tab that points at a locked sport, or
  at a hidden TRENDING, falls back to the home sport.
- **GAMES tab, slot #1.** The **BEGINNER'S QUEST** card, shown while that
  sport's quest is running. Its mission plate leads with the current game's
  icon, name, and finish condition. A compact header inside that same card shows
  the chapter, an `00/06` overall route count and a thin progress meter; it
  replaces the former separate title, prose progress line, and repeated chapter
  counter. The live mission is the focal plate, with a restrained pitch diagram
  for football.
  With no active mission, the card says **CHOOSE YOUR FIRST GAME** or
  **CHOOSE YOUR NEXT GAME** and opens the game picker with **CHOOSE GAME**.
  The picker lists every unfinished game with its icon, name, finish condition
  and one `+40 XP PER CLEAR` reward cue above the choices. Tapping highlights an option; **CHOOSE & PLAY** saves the choice
  before opening its lobby. Dismissal does not select anything. A failed save
  keeps the picker open with retry feedback. The active Games card remains
  informational, with launch controls in the catalogue and quest hub.
  The reward rail shows `+40 XP`; active missions also show **CHOOSE NEXT GAME
  ON CLEAR** or the final completion bonus. It wraps on small screens.
- **MATCH / TRENDING quest slot.** The home-sport Beginner's Quest takes the
  daily-quest tile's place for the whole rookie phase, then the daily tile
  returns permanently. Buying another sport early does not change the focus.
- **Streak / quest hub.** Before home-sport graduation it becomes a tabless
  **ROOKIE PATH** command center. When a game has not been chosen, one quest
  card leads to the picker; the six locked game tickets are hidden. A compact
  chapter map shows the two meaningful payoffs: Daily Quests after three home
  missions, then 50 Oz when Football Explorer is complete. Three-game sports
  show Daily Quests and 50 Oz together at the third clear. With an active
  mission, the **GAME BOARD** shows the live ticket with its PLAY action,
  finish condition and +40 XP, then quiet locked options and cleared replays.
  Football adds a faint pitch diagram. Completed tickets follow the player's
  chosen order; route nodes use state icons rather than numbers because games
  can be selected out of catalogue order. After graduation, one-sport managed
  careers get QUESTS with Daily Quests followed by active sport quests.
- **ALL SPORTS.** Locked sports show a lock, `LOCKED // N GAMES + MATCHES` and
  `50 OZ`, and open the unlock sheet. Fixtures are never fetched for them.
- **Match search.** Results cover unlocked sports only.
- **Launch guard.** Every game launch goes through one guarded entry in the
  app shell. A locked game opens its lock sheet while a mission is active,
  or the picker with that game highlighted while awaiting selection. A locked
  sport opens its purchase sheet. Quest shortcuts also open the picker when
  no home-sport mission is selected.

## Player Flow

1. Onboarding: pick a home sport (e.g. Cricket), then its club, then FINISH
   SETUP. Both hub strips land on the home sport.
2. GAMES offers **CHOOSE YOUR FIRST GAME**, `00/03` progress and `+40 XP`.
   The player can choose Final Over, Cricket Quiz or Guess the Player.
3. The selected game becomes the active mission and opens its lobby. Other
   unfinished games stay locked until that mission clears. Completed games
   remain available for replay.
4. Completion gives `+40 XP`, a result receipt and the queued **MISSION
   COMPLETE** celebration with **CHOOSE NEXT GAME**. The receipt presents the
   XP reward, route meter and next unlock before the player continues. Any remaining game may
   be selected. A selected quiz has free beginner attempts until cleared.
5. After three distinct home-sport missions, Daily Quests unlock. Clearing
   all games in a sport pays `+50 OZ`; Football continues through three
   Explorer choices after graduation and pays the bonus after six missions.
6. The player taps a padlocked sport on the strip. The UNLOCK sheet previews
   that sport's game catalogue and the balance before and after. They tap
   **UNLOCK · 50 OZ**, **SPORT UNLOCKED** plays, and **ENTER \<SPORT\>** lands
   them on that sport's GAMES tab, where its own Beginner's Quest starts.

## Mechanics and Rules

**Game catalogue** (`sportGameLadder` supplies display order, not mission order):

| Sport | Game | Game | Game | Game | Game | Game |
|---|---|---|---|---|---|---|
| Football | Pitch Duel | Penalty Shootout | Football Quiz | Guess the Player | Football Bingo | 5v5 Football Chess |
| Cricket | Final Over | Cricket Quiz | Guess the Player | | | |
| Basketball | Hoop Duel | Basketball Quiz | Guess the Player | | | |
| Motorsport | Grand Prix Dash | Motorsport Quiz | Guess the Driver | | | |
| Tennis | Tennis Rally | Tennis Quiz | Guess the Winner | | | |

**Unlocking games:**
- Before the first mission and after each clear, choose any unfinished game
  in that sport. Selection opens one game and locks the mission until cleared.
  Finishing that mission enables another choice; winning is not required.
- Replaying an earlier game never advances the ladder, and neither does a
  repeated settlement id.
- Games unlock by playing only. There is no coin skip.

**What counts as "finished":**
- **Match games:** the game's normal settle event. Pitch Duel match end,
  Shootout, Grand Prix, Hoop Duel, Final Over and Tennis Rally settles.
- **Quiz:** a quiz set answered in full. A partial run does not count.
- **Football Chess:** a finished match.
- **Football Bingo:** a completed grid.
- **Guess the Player / Driver / Winner:** a fresh daily result, won or lost.

**Unlocking a sport:**
- All five sport purchase sheets use the shared Cyberpunk UI kit: sport identity
  header, game catalogue with finish conditions, and balance/cost footer.
  Every game is a possible starter; there is no fixed prerequisite route.
- Only the enabled primary action glows. The footer stays docked at normal text
  sizes when at least 620 px is available; short screens and text above 1.2x use
  one scrollable sheet. Close, barrier dismissal and back never purchase.
- The kit uses a 220 ms entrance, short press feedback, and one sound/haptic per
  action. Reduced motion removes the entrance/press movement. Existing app-root
  sport unlock celebrations remain the purchase payoff.
- Another sport costs **50 Oz** (`sportUnlockCostOz`).
- An unaffordable purchase shows the shortfall and a pointer to the quest
  reward, and never charges.
- Buying a sport you already own is a no-op.
- An unlocked sport opens its matches and picks, and offers its own first-game
  picker. Sport mission selections and completion are independent.

**Daily quests:**
- The home quest is the one-time graduation gate. Daily activity records
  invisibly before graduation, then becomes visible without being reset.
- The top bar shows a flag plus `cleared/total`; Daily reward indicators and
  at-risk reminders stay suppressed during the Rookie Path.
- Buying another sport early is allowed, but the home quest keeps focus. After
  graduation, later sport quests never replace or hide Daily Quests.
- Every finished GAMES-tab mode now counts as a daily-quest game, so a
  non-football player can clear Kick Off and friends.
- Quest game CTAs route to the named football mode when it is open. Otherwise
  they go to the home sport's current quest game.

**Grandfathering:**
- A profile that finished onboarding before unlocks shipped keeps every sport
  and game open and never sees the quest.
- Re-onboarding after a logout keeps anything already earned.

## Rewards and Progression

- Each quest step pays **+40 XP** on the Cards/Meta track, source
  `beginnerQuest`.
- Clearing a sport's whole quest pays **+50 Oz** once, source
  `beginnerQuestReward`. That is exactly one sport unlock, so each finished
  quest can fund the next sport; the loop ends after 5 sports.
- A sport unlock is a ledger spend with source `sportUnlock`.
- The predictions XP-only rule is untouched: quest Oz is a GAMES reward, not a
  prediction reward.

## Gratification and Feedback

- `CyberUnlockReveal` is the shared app-root moment: vignette, then a padlock
  rattle, shackle spring and shard burst (`quizUnlock` + heavy haptic), then
  the item plate slam, then title, reward chip and CTA. It is a moment screen,
  so the glow is intentional.
- Reveals queue and play one at a time.
- A reveal plays only while the home hub is the top route, so it never covers
  gameplay, a result screen or a level-up. It also waits for achievement,
  streak and quest-reward moments, pack reveals and the welcome reward.
- The streak reminder waits while unlock reveals are pending.
- Locked tiles are desaturated and flat with no glow, with **CHOOSE AS YOUR
  MISSION** or **FINISH CURRENT MISSION** chips. The GAMES quest card uses a
  focal mission plate and reward rail, plus a picker action while awaiting choice.
  Only the enabled primary picker action glows; the highlighted option gets an
  accent border and check. The picker puts the +40 XP payoff once above the
  choices instead of repeating it in every game row. In the ROOKIE PATH board, only the active
  ticket glows. Ticket taps have sound and haptic feedback, while advancement
  briefly transitions the ticket state unless reduced motion is requested.
  The existing unlock reveal remains the completion payoff.

## Visible States

- **Unmanaged:** a fresh install before onboarding finishes. Everything open.
- **Awaiting selection:** home/unlocked sport quest active, no assigned mission;
  the card offers a first/next choice.
- **Active mission:** selected game and completed games open; other unfinished
  games require finishing the active mission.
- **Quest complete:** the card disappears and all of that sport's games are
  open. Completing the home quest also graduates the career to Daily Quests.
- **Multi-sport:** TRENDING returns once a second sport is open.
- **Quest List:** after home graduation, QUESTS combines Daily
  Quests with remaining active sport ladders.
- **Grandfathered:** no locks, no quest.

## Persistence

The v1 RETURNING PLAYER preset is a fully graduated career: Football is its
home sport, all five sports are unlocked, every one of the 18 ladder positions
is reached and recorded as played, every sport quest is complete, and the
pending reveal queue is empty. Opening that career therefore shows the complete
game board immediately and never replays unlock or quest-completion reveals.

`UnlockProgress` (v2 JSON, existing key `pd_unlock_progress_v1`) stores:
- the home sport and unlocked sports
- ordered completed game identities and optional active game per sport
- completed quests
- processed settlement ids
- rookie tickets used
- the pending reveal queue (so a reveal survives a relaunch)

GameBloc owns it and writes it after every change. A missing key plus a
finished onboarding migrates to `grandfathered`.
V1 saves with zero cleared missions become first-game choices. Progressed v1
saves preserve their completed prefix and assigned active mission; the next
clear enables choice. Completed quests, grandfathered access, processed IDs,
rookie ticket markers and queued reveals survive migration. Selection and
unlock mutations share a queue; failed selection saves never unlock or launch.

## Planned Scope and Current Limitations

- **BUILT:** everything above.
- The GAMES tab keeps its hand-built art layout. The quest hub shows completed
  games in chosen order; catalogue tiles identify the active mission and locks.
- The leaderboard, shop and collection sport strips still list every sport;
  they are not gated.
- Profile's Following editor still offers every sport as the primary sport.
  Changing it there does not unlock anything.
- **[PLANNED]** Offer the new sport's club picker right after a sport unlock.

## Implementation References

- [game_ladder.dart](../../../lib/config/game_ladder.dart): `ArcadeGame`,
  `sportGameLadder` and the cost/reward constants.
- [unlock_progress.dart](../../../lib/models/unlock_progress.dart)
- [game_bloc.dart](../../../lib/blocs/game/game_bloc.dart): `HomeSportChosen`,
  `SportUnlockPurchased`, `QuestGameSelected`, `ArcadeGamePlayed`, `RookieTicketUsed`,
  `UnlockRevealConsumed`, and the `_recordArcadePlay` hook.
- [app.dart](../../../lib/app.dart): `_openArcadeGame` guard, `_openQuestGame`
  and the `UnlockRevealGate` wiring.
- [prediction_home_screen.dart](../../../lib/screens/predictions/prediction_home_screen.dart):
  gated strip, lock veils, quest slots.
- [beginner_quest_card.dart](../../../lib/screens/predictions/widgets/beginner_quest_card.dart)
- [unlock_sheets.dart](../../../lib/screens/predictions/widgets/unlock_sheets.dart)
- [cyber_unlock_reveal.dart](../../../lib/widgets/cyber/cyber_unlock_reveal.dart)
- [unlock_celebration_host.dart](../../../lib/widgets/unlock_celebration_host.dart)
- [sport_underline_tabs.dart](../../../lib/widgets/cyber/sport_underline_tabs.dart)

## Tests

- `test/unlock_progress_test.dart`: ladder rules, idempotency, quest
  completion, sport unlock, rookie ticket, grandfathering and JSON versioning.
- `test/quest_game_picker_test.dart`: every sport's picker, dismissal, save-before-
  launch, duplicate taps, failed-save retry, and launching after a Rookie Path
  rebuild at 320 px with enlarged text and reduced motion.
- `test/sport_unlock_bloc_test.dart`: grandfather migration, step XP, a
  cricket game counting toward daily quests, the one-time +50 Oz, 50 Oz
  purchases (broke, owned) and rookie ticket spend.
- `test/profile_setup_screen_test.dart`: single-select home sport.
- `test/returning_profile_preset_test.dart`: all five sports, 18 games,
  completed quests, played markers, and empty reveal queue.
