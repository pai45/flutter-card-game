# Sport and Game Unlocks (Beginner's Quest)

> **Status:** BUILT
> **Last verified:** 2026-09-19
> **Scope:** The home sport chosen at onboarding, locked sports and games, the per-sport Beginner's Quest ladder that opens games by playing, and the 50 Oz sport unlock.

## Product Purpose

A first-time player used to land on 5 sports and 18 games at once. Unlocks
pace that: a new player starts in **one home sport** with **one open game**, and
opens the rest by playing. Every game they finish pays back with an unlock
moment and points them at the next one. Other sports stay visible as locked
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
  sport's quest is running. Its compact two-row layout shows only the current
  game, `+40 XP`, the next unlock/completion bonus, and **PLAY NOW**; the header
  already carries total ladder progress, so the card does not repeat a step
  stamp, paragraph, or second progress meter.
- **MATCH / TRENDING quest slot.** The home-sport Beginner's Quest takes the
  daily-quest tile's place for the whole rookie phase, then the daily tile
  returns permanently. Buying another sport early does not change the focus.
- **Streak / quest hub.** Before home-sport graduation it becomes a tabless
  **ROOKIE PATH** command center: ladder progress, current game CTA, rewards,
  game states, and a locked Daily Quest preview. After graduation, one-sport
  careers get TODAY; managed careers with 2+ sports get QUESTS (Daily Quests
  followed by active sport quests).
- **ALL SPORTS.** Locked sports show a lock, `LOCKED // N GAMES + MATCHES` and
  `50 OZ`, and open the unlock sheet. Fixtures are never fetched for them.
- **Match search.** Results cover unlocked sports only.
- **Launch guard.** Every game launch goes through one guarded entry in the
  app shell. A locked game opens its lock sheet instead, so trending tiles,
  quest routes and reveal CTAs cannot bypass a lock.

## Player Flow

1. Onboarding: pick a home sport (e.g. Cricket), then its club, then FINISH
   SETUP. Both hub strips land on the home sport.
2. GAMES shows the Beginner's Quest card: `PLAY FINAL OVER`, step 1 of 3,
   `+40 XP`, `UNLOCKS CRICKET QUIZ`. Only Final Over is open. The next game
   wears an amber **NEXT UNLOCK** padlock chip; later games show
   **QUEST STEP n**.
3. The player finishes one Final Over (win or lose) and returns to the hub.
   **NEW GAME UNLOCKED** plays: the padlock rattles, the shackle springs open,
   and the Cricket Quiz plate slams in with `+40 XP` and **PLAY NOW**.
4. The quiz step comes with a **ROOKIE TICKET**: the first quiz entry during
   the quest is free.
5. Finishing the last home-sport game plays **ROOKIE PATH COMPLETE**:
   `DAILY QUESTS UNLOCKED` and `+50 OZ`, with VIEW TODAY or VIEW QUESTS.
6. The player taps a padlocked sport on the strip. The UNLOCK sheet previews
   that sport's full game ladder and the balance before and after. They tap
   **UNLOCK · 50 OZ**, **SPORT UNLOCKED** plays, and **ENTER \<SPORT\>** lands
   them on that sport's GAMES tab, where its own Beginner's Quest starts.

## Mechanics and Rules

**Ladder order** (source of truth: `sportGameLadder`):

| Sport | 1 (open) | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| Football | Pitch Duel | Penalty Shootout | Football Quiz | Guess the Player | Football Bingo | 5v5 Football Chess |
| Cricket | Final Over | Cricket Quiz | Guess the Player | | | |
| Basketball | Hoop Duel | Basketball Quiz | Guess the Player | | | |
| Motorsport | Grand Prix Dash | Motorsport Quiz | Guess the Driver | | | |
| Tennis | Tennis Rally | Tennis Quiz | Guess the Winner | | | |

**Unlocking games:**
- Game N+1 unlocks when the quest's **current step** (game N) is finished once.
  Winning is not required.
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
- Another sport costs **50 Oz** (`sportUnlockCostOz`).
- An unaffordable purchase shows the shortfall and a pointer to the quest
  reward, and never charges.
- Buying a sport you already own is a no-op.
- An unlocked sport opens its matches, picks and first game, and starts its
  own Beginner's Quest.

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
- Locked tiles are desaturated and flat with no glow. The next unlock gets a
  calm amber chip. The GAMES quest card is a compact mission plate with one
  reward chip and a calm **PLAY NOW** action; the detailed objective card and
  segmented ladder remain in the dedicated ROOKIE PATH command center.

## Visible States

- **Unmanaged:** a fresh install before onboarding finishes. Everything open.
- **Gated:** home sport only, quest active.
- **Mid-quest:** some games open, NEXT UNLOCK and QUEST STEP chips on the rest.
- **Quest complete:** the card disappears and all of that sport's games are
  open. Completing the home quest also graduates the career to Daily Quests.
- **Multi-sport:** TRENDING returns once a second sport is open.
- **Quest List:** after home graduation with 2+ sports, QUESTS combines Daily
  Quests with remaining active sport ladders.
- **Grandfathered:** no locks, no quest.

## Persistence

`UnlockProgress` (versioned JSON, key `pd_unlock_progress_v1`) stores:
- the home sport and unlocked sports
- ladder position per sport
- completed quests
- processed settlement ids
- rookie tickets used
- the pending reveal queue (so a reveal survives a relaunch)

GameBloc owns it and writes it after every change. A missing key plus a
finished onboarding migrates to `grandfathered`.

## Planned Scope and Current Limitations

- **BUILT:** everything above.
- The GAMES tab keeps its hand-built art layout, so the tiles are not reordered
  to match the ladder. The lock chips communicate the order.
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
  `SportUnlockPurchased`, `ArcadeGamePlayed`, `RookieTicketUsed`,
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
- `test/sport_unlock_bloc_test.dart`: grandfather migration, step XP, a
  cricket game counting toward daily quests, the one-time +50 Oz, 50 Oz
  purchases (broke, owned) and rookie ticket spend.
- `test/profile_setup_screen_test.dart`: single-select home sport.
