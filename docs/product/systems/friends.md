# Friends

> **Status:** BUILT
> **Last verified:** 2026-08-09
> **Scope:** Friends Arena, friend relationships, activity summaries, and social entry points

## Product Purpose

Friends adds social motivation around play: seeing familiar rivals, comparing
activity, and reaching referrals from a dedicated social arena.

## Where It Lives

The Friends Arena is opened from the app's social/navigation surfaces. Its
state is managed separately from referrals even though the arena links to the
referral screen.

## Player Flow

1. Open Friends Arena; a new player begins with an empty friends list.
2. Search the seeded rival catalog by tag or username.
3. Add/remove the resolved rival as a local friend bookmark.
4. Open the rival dossier or challenge a friend with the existing CPU-themed
   match route when the deck gate is satisfied.
5. Return later with the membership restored from secure storage.

## Mechanics and Rules

`FriendsCubit` owns an on-device set of rival display names. Search resolves
against the seeded rival roster; membership is idempotent and supports add,
remove, and toggle. Challenge launches local CPU play themed as the selected
rival. This is not a production account search or real-time presence service.

## Rewards and Progression

Friends itself does not mint XP or coins. Referral rewards are documented and
settled separately in [Referrals](referrals.md).

## Gratification and Feedback

Avatar identity, online/activity signals, rivalry copy, and animated arena
cards provide game-like social energy without presenting an enterprise contact
list.

## Visible States

Loading, empty list, valid result, unknown tag, own tag, friend/non-friend,
deck-gated challenge, populated ranking, and referral navigation are represented.

## Persistence

Friend names persist through `SecureGameStorage` and round-trip across cubit/app
reload. There is no remote social graph or cross-device relationship sync.

## Planned Scope and Current Limitations

- **BUILT:** Local searchable rival bookmarks, secure persistence, dossier,
  add/remove feedback, and CPU-themed challenge route.
- **PROTOTYPE:** Search identities and ranks use the seeded rival catalog.
- **PLANNED:** Production identity lookup, requests, blocks, presence, privacy,
  remote persistence, and multiplayer invitations require backend scope.

## Implementation References

- [`lib/blocs/friends/friends_cubit.dart`](../../../lib/blocs/friends/friends_cubit.dart)
- [`lib/screens/friends/friends_arena_screen.dart`](../../../lib/screens/friends/friends_arena_screen.dart)

## Tests

- [`test/friends_cubit_test.dart`](../../../test/friends_cubit_test.dart)
