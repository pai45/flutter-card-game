import 'package:card_game/models/match_circle.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const author = MatchCircleAuthor(
    id: 'player:ABCD-EFGH',
    displayName: 'PLAYER ONE',
    avatarId: 'rodri',
    playerTag: 'ABCD-EFGH',
  );

  test('author, post and thread JSON round-trip without losing fields', () {
    final createdAt = DateTime.utc(2026, 7, 15, 12);
    final editedAt = createdAt.add(const Duration(minutes: 5));
    final thread = MatchCircleThread(
      key: 'football:epl:match-1',
      sport: Sport.football,
      leagueId: 'epl',
      matchId: 'match-1',
      seededAt: createdAt.subtract(const Duration(hours: 1)),
      updatedAt: editedAt,
      posts: [
        MatchCirclePost(
          id: 'post-1',
          threadKey: 'football:epl:match-1',
          author: author,
          text: 'Edited prediction',
          createdAt: createdAt,
          editedAt: editedAt,
          likes: 4,
          likedByAuthorIds: const {'player:ABCD-EFGH'},
        ),
      ],
    );

    final decoded = MatchCircleThread.fromJson(thread.toJson());

    expect(decoded.toJson(), thread.toJson());
    expect(decoded.posts.single.isEdited, isTrue);
    expect(decoded.posts.single.isOwnedBy(author), isTrue);
    expect(decoded.posts.single.isLikedBy(author.id), isTrue);
  });

  test('collections are immutable defensive copies', () {
    final sourceLikes = <String>{author.id};
    final post = MatchCirclePost(
      id: 'post-1',
      threadKey: 'football:epl:match-1',
      author: author,
      text: 'Hello',
      createdAt: DateTime.utc(2026),
      likedByAuthorIds: sourceLikes,
    );
    final sourcePosts = <MatchCirclePost>[post];
    final thread = MatchCircleThread(
      key: post.threadKey,
      sport: Sport.football,
      leagueId: 'epl',
      matchId: 'match-1',
      posts: sourcePosts,
      seededAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    sourceLikes.clear();
    sourcePosts.clear();

    expect(post.likedByAuthorIds, {author.id});
    expect(thread.posts, hasLength(1));
    expect(() => post.likedByAuthorIds.add('other'), throwsUnsupportedError);
    expect(() => thread.posts.clear(), throwsUnsupportedError);
  });

  test('thread orders top-level newest and replies oldest', () {
    final base = DateTime.utc(2026, 7, 15, 12);
    MatchCirclePost post(
      String id,
      Duration age, {
      String? parentId,
      bool deleted = false,
    }) => MatchCirclePost(
      id: id,
      threadKey: 'football:epl:match-1',
      parentId: parentId,
      author: author,
      text: deleted ? '' : id,
      createdAt: base.subtract(age),
      isDeleted: deleted,
    );

    final thread = MatchCircleThread(
      key: 'football:epl:match-1',
      sport: Sport.football,
      leagueId: 'epl',
      matchId: 'match-1',
      seededAt: base,
      updatedAt: base,
      posts: [
        post('old-parent', const Duration(hours: 3)),
        post('reply-2', const Duration(hours: 1), parentId: 'old-parent'),
        post('new-parent', Duration.zero),
        post('reply-1', const Duration(hours: 2), parentId: 'old-parent'),
        post('tombstone', const Duration(hours: 4), deleted: true),
        post(
          'tombstone-reply',
          const Duration(minutes: 30),
          parentId: 'tombstone',
        ),
        post('orphan-tombstone', const Duration(hours: 5), deleted: true),
      ],
    );

    expect(thread.topLevelPosts.map((post) => post.id), [
      'new-parent',
      'old-parent',
      'tombstone',
    ]);
    expect(thread.repliesFor('old-parent').map((post) => post.id), [
      'reply-1',
      'reply-2',
    ]);
    expect(thread.visibleCount, 5);
  });

  test('canonical key and compact count formatting are stable', () {
    final match = _match();

    expect(matchCircleThreadKey(match), 'football:epl:match-1');
    expect(compactMatchCircleCount(999), '999');
    expect(compactMatchCircleCount(1200), '1.2K');
    expect(compactMatchCircleCount(15000), '15K');
    expect(compactMatchCircleCount(1250000), '1.3M');
  });
}

SportMatch _match() => SportMatch(
  id: 'match-1',
  leagueId: 'epl',
  sport: Sport.football,
  home: const SportTeam(
    id: 'ars',
    name: 'Arsenal',
    shortName: 'ARS',
    color: Colors.red,
  ),
  away: const SportTeam(
    id: 'liv',
    name: 'Liverpool',
    shortName: 'LIV',
    color: Colors.blue,
  ),
  kickoff: DateTime(2026, 7, 20),
  status: MatchStatus.upcoming,
);
