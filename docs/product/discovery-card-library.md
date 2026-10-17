# Editorial discovery card library

> **Status:** BUILT
> **Last verified:** 2026-10-15
> **Scope:** Reusable presentation for recent match, Events, Picks, Futures, XP and reveal cards across Flutter, web and Designer.

## Product Purpose

Give players a recognizable, readable route from live sport to predictions and quizzes while preserving StatOz's cyber hierarchy.

## Where It Lives

Match Trending, the dedicated Picks/Futures and reveal lists, and Designer's Brand Components and Assets Design kit. Existing authentication, sport unlocks and trading permissions continue to apply.

## Player Flow

1. Swipe or keyboard through the five available featured winner Picks.
2. Browse sport cycles: two wide fixtures, up to three independent Events, a paired quiz/compact fixture/XP grid, then one available Future.
3. Open the existing match, quiz, market or trade flow and return with feed/slide position preserved.

## Mechanics and Rules

Football keeps logos above edge-aligned two-line names and unboxed scores. Cricket/basketball retain stacked scoreboards; motorsport shows available classification or schedule. VS is supporting display text rather than score-size text.

Lifecycle tabs sit flush at the top-right with internal padding and reserved content space. LIVE includes available context in the same tag. Never fabricate timing or repeat lifecycle-only timing. Names clamp visually at two lines while accessible identities stay complete.

Events questions use medium body weight and quieter answers; percentages have no underline. Outcome percentage controls fill the row height at the right edge using the outcome color. XP cards show logos/VS, genuine progress and reward without a repeated Match Prediction title or action rail. Gold reveal cards remain thin and fixture-name-only in dedicated lists.

## Rewards and Progression

Feature adapters supply actual progress, potential XP, positions and claim state. This library does not calculate rewards, write balances or settle predictions. Existing scoring and settlement rules remain in their owners.

## Gratification and Feedback

Preserve the existing one-time card entrance, focus/press feedback and selection haptic. Respect reduced motion, route/page visibility and offscreen behavior. Keep motion silent and navigation immediate. Match tint stays subtle from the top-right: live red, followed cyan, scheduled neutral, finished supported winner color.

## Visible States

Preserve LIVE, OPEN, CLOSED, UNRESOLVED, FINISHED, SETTLED and VOID from authoritative feature data. Missing timing is omitted. Empty/partial cycles remain valid, loading remains a feature concern, and disabled outcomes retain their guard. Never fabricate records to fill a grid.

## Persistence

Selection freezes IDs while content values remain subscribed. Web restores session cache/slide position; Flutter uses existing state and PageStorage. The component library creates no new player persistence or economy schema.

## Planned Scope and Current Limitations

- **BUILT:** Focused compatibility library, shared presentation tokens, local React primitive copies, Designer catalog and downloadable source kit.
- **PROTOTYPE:** Existing demo championship markets remain explicitly labeled; they are not new production feeds.
- Performance changes reduce repeated priority calculations, lookups and web observers; no device benchmark or physical haptic measurement is claimed.

## Implementation References

- [Flutter public library](../../lib/widgets/cyber/match_discovery.dart) and its focused parts: plate/motion, status, presentation, primitives, outcome, fixture, Events, market, mission, layout and reveal.
- [Trending feed](../../lib/screens/predictions/widgets/trending_match_bento.dart) and editorial_cycle_selection.dart keep feature selection separate from visuals.
- [Canonical numerical contract](../../design/match-discovery.json). Generate local adapters with tool/match-discovery.mjs --web-root <web> --designer-root <designer>.
- React primitives: src/design-system/components/data-display/discovery-card. Sport/data/navigation/access adapters remain in features/matches; editorial-discovery.tsx preserves old imports.
- From web, scripts/sync-discovery-library.mjs --designer-root <designer> copies the fixed primitive allowlist with hashes. Both React apps run discovery:check and match-discovery:check locally; normal builds have no other-checkout dependency.

## Tests

Use match_editorial_test.dart, match_editorial_motion_test.dart, trending_hub_test.dart and match_discovery_contract_test.dart for affected presentation and selection. Existing Picks tests cover their model/widget/cubit responsibilities. Run targeted analysis, generated-output checks and matching real web/Flutter captures at narrow and increased text sizes. Web selection and shared-observer lifecycle tests exercise the optimization; Designer tests verify lifecycle formatting, library hashes and downloadable source contents.

## Superseded code cleanup (2026-10-15)

The Match feed uses the editorial cycle selector, not the retired hard-coded Match Trending catalog. Games keeps its own typed catalog with unchanged IDs, spans and sport locks. Removed unreferenced web Trending tiles, their private footer/meta helpers and the unused team lockup. The web feed imports the single design-system token stylesheet; generators no longer emit a duplicate feature copy. Team-name typography and clamping belong to the shared primitive. Removed obsolete Trending fixture chrome and unreachable race/cricket branches from the Tennis fallback. Active compatibility exports and Tennis presentation remain supported.

## Personal cards on Match Trending (2026-10-16)

After the featured carousel, show saved reveal entries as the existing thin paired gold cards without a visible Ready to reveal heading. Follow them with Your predictions: existing compact prediction cards for saved drafts, live/locked entries, unresolved results and settled history. Use actual quiz IDs, progress and earned XP; include paid quizzes and all supported sports. A finished entry becomes gold only when its quiz has resolvable results. Settlement remains inside the existing quiz route. Recompute personal entries from saved state independently of frozen discovery slots and omit their duplicate XP mission tile from the cycle. Flutter resolves repository-backed saved fixtures outside the rolling feed without injecting them into cycle selection. Missing records are omitted. Keep sport locks, navigation, reduced-motion behavior and settlement guards.

Personal card carousels (2026-10-16): Reveal results is the heading above the thin gold cards. Both it and Your predictions use independent manual horizontal rails with 2.2 cards visible at ordinary phone/desktop sizes. Use the same generated visible-count tokens; 16px gutters, natural equal card height, keyboard left/right/Home/End, swipe and stored return offsets. Below 360px or at 1.4× text use 1.1 wider cards for readable names and lifecycle tags. No automatic playback or arrow controls. Gold names clamp to two visible lines with full accessible identity.
