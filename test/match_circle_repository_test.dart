import 'dart:convert';

import 'package:card_game/models/match_circle.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/services/match_circle_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const player = MatchCircleAuthor(
    id: 'player:TEST-USER',
    displayName: 'PLAYER ONE',
    avatarId: 'rodri',
    playerTag: 'TEST-USER',
  );
  const anotherPlayer = MatchCircleAuthor(
    id: 'player:OTHER',
    displayName: 'PLAYER TWO',
    avatarId: 'adams',
    playerTag: 'OTHER',
  );
  final now = DateTime.utc(2026, 7, 15, 12);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('lazily seeds once and isolates every match including F1', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalMatchCircleRepository(
      preferences: preferences,
      now: () => now,
    );
    final football = _match();
    final f1 = _match(
      id: 'british-gp',
      leagueId: 'f1',
      sport: Sport.motorsport,
      homeName: 'British Grand Prix',
      status: MatchStatus.upcoming,
    );

    final first = await repository.loadThread(football);
    final second = await repository.loadThread(football);
    final f1Thread = await repository.loadThread(f1);

    expect(first.visibleCount, 3);
    expect(
      second.posts.map((post) => post.id),
      first.posts.map((post) => post.id),
    );
    expect(second.seededAt, first.seededAt);
    expect(f1Thread.key, 'f1:f1:british-gp');
    expect(f1Thread.posts.first.text, contains('pole'));

    final recreated = LocalMatchCircleRepository(
      preferences: preferences,
      now: () => now.add(const Duration(days: 1)),
    );
    final afterRestart = await recreated.loadThread(football);
    expect(afterRestart.seededAt, first.seededAt);
    expect(afterRestart.posts, hasLength(3));

    final envelope =
        jsonDecode(
              preferences.getString(LocalMatchCircleRepository.storageKey)!,
            )
            as Map<String, dynamic>;
    expect(envelope['version'], LocalMatchCircleRepository.storageVersion);
    expect((envelope['threads'] as Map), hasLength(2));
  });

  test(
    'adds trimmed comments and one-level replies and persists them',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final repository = LocalMatchCircleRepository(
        preferences: preferences,
        now: () => now,
      );
      final match = _match();

      final withComment = await repository.addComment(
        match: match,
        author: player,
        text: '  My prediction  ',
      );
      final comment = withComment.topLevelPosts.first;
      expect(comment.text, 'My prediction');
      expect(withComment.visibleCount, 4);

      final withReply = await repository.addReply(
        match: match,
        parentId: comment.id,
        author: player,
        text: 'Reply',
      );
      final reply = withReply.repliesFor(comment.id).single;
      expect(withReply.visibleCount, 5);

      await expectLater(
        repository.addReply(
          match: match,
          parentId: reply.id,
          author: player,
          text: 'Nested reply',
        ),
        throwsA(isA<MatchCircleValidationException>()),
      );
      await expectLater(
        repository.addComment(match: match, author: player, text: '   '),
        throwsA(isA<MatchCircleValidationException>()),
      );
      await expectLater(
        repository.addComment(
          match: match,
          author: player,
          text: List.filled(501, 'x').join(),
        ),
        throwsA(isA<MatchCircleValidationException>()),
      );

      final reloaded = await LocalMatchCircleRepository(
        preferences: preferences,
      ).loadThread(match);
      expect(reloaded.visibleCount, 5);
      expect(reloaded.postById(reply.id)?.text, 'Reply');
    },
  );

  test('likes, edits and ownership checks survive recreation', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalMatchCircleRepository(
      preferences: preferences,
      now: () => now,
    );
    final match = _match();
    final added = await repository.addComment(
      match: match,
      author: player,
      text: 'Original',
    );
    final post = added.topLevelPosts.first;

    final liked = await repository.toggleLike(
      match: match,
      postId: post.id,
      authorId: player.id,
    );
    expect(liked.postById(post.id)?.likes, 1);
    expect(liked.postById(post.id)?.isLikedBy(player.id), isTrue);

    final edited = await repository.editPost(
      match: match,
      postId: post.id,
      authorId: player.id,
      text: ' Updated ',
    );
    expect(edited.postById(post.id)?.text, 'Updated');
    expect(edited.postById(post.id)?.isEdited, isTrue);

    final seedPost = edited.posts.firstWhere(
      (candidate) => candidate.author.id.startsWith('seed:'),
    );
    await expectLater(
      repository.editPost(
        match: match,
        postId: seedPost.id,
        authorId: player.id,
        text: 'Not mine',
      ),
      throwsA(isA<MatchCirclePermissionException>()),
    );

    final unliked = await repository.toggleLike(
      match: match,
      postId: post.id,
      authorId: player.id,
    );
    expect(unliked.postById(post.id)?.likes, 0);
    expect(unliked.postById(post.id)?.isLikedBy(player.id), isFalse);

    final reloaded = await LocalMatchCircleRepository(
      preferences: preferences,
    ).loadThread(match);
    expect(reloaded.postById(post.id)?.text, 'Updated');
    expect(reloaded.postById(post.id)?.likes, 0);
  });

  test(
    'deleting a parent tombstones it until its last reply is deleted',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final repository = LocalMatchCircleRepository(
        preferences: preferences,
        now: () => now,
      );
      final match = _match();
      final added = await repository.addComment(
        match: match,
        author: player,
        text: 'Parent',
      );
      final parent = added.topLevelPosts.first;
      final withReply = await repository.addReply(
        match: match,
        parentId: parent.id,
        author: anotherPlayer,
        text: 'Keep me',
      );
      final reply = withReply.repliesFor(parent.id).single;

      final tombstoned = await repository.deletePost(
        match: match,
        postId: parent.id,
        authorId: player.id,
      );
      expect(tombstoned.postById(parent.id)?.isDeleted, isTrue);
      expect(tombstoned.postById(parent.id)?.text, isEmpty);
      expect(
        tombstoned.topLevelPosts.map((post) => post.id),
        contains(parent.id),
      );
      expect(tombstoned.visibleCount, withReply.visibleCount - 1);

      final removed = await repository.deletePost(
        match: match,
        postId: reply.id,
        authorId: anotherPlayer.id,
      );
      expect(removed.postById(reply.id), isNull);
      expect(removed.postById(parent.id), isNull);
    },
  );

  test(
    'corrupt or unsupported persisted data produces a typed error',
    () async {
      SharedPreferences.setMockInitialValues({
        LocalMatchCircleRepository.storageKey: jsonEncode({
          'version': 99,
          'threads': {},
        }),
      });
      final repository = LocalMatchCircleRepository();

      await expectLater(
        repository.loadThread(_match()),
        throwsA(isA<MatchCirclePersistenceException>()),
      );
    },
  );
}

SportMatch _match({
  String id = 'match-1',
  String leagueId = 'epl',
  Sport sport = Sport.football,
  String homeName = 'Arsenal',
  MatchStatus status = MatchStatus.upcoming,
}) => SportMatch(
  id: id,
  leagueId: leagueId,
  sport: sport,
  home: SportTeam(
    id: 'home-$id',
    name: homeName,
    shortName: 'HOM',
    color: Colors.red,
  ),
  away: SportTeam(
    id: 'away-$id',
    name: sport == Sport.motorsport ? 'Formula 1' : 'Liverpool',
    shortName: 'AWY',
    color: Colors.blue,
  ),
  kickoff: DateTime(2026, 7, 20),
  status: status,
);
