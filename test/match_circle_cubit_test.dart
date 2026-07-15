import 'package:card_game/blocs/match_circle/match_circle_cubit.dart';
import 'package:card_game/models/match_circle.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/services/match_circle_repository.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime.utc(2026, 7, 15, 12);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'pd_player_tag_v1': 'TEST-USER',
      'pd_selected_avatar_v1': 'rodri',
    });
  });

  test(
    'ensureThread loads a stable PLAYER ONE author and seeded thread',
    () async {
      final cubit = MatchCircleCubit(
        LocalMatchCircleRepository(now: () => now),
        SecureGameStorage(),
      );
      final match = _match();

      final thread = await cubit.ensureThread(match);

      expect(thread?.visibleCount, 3);
      expect(cubit.loading(match), isFalse);
      expect(cubit.error(match), isNull);
      expect(cubit.threadFor(match), same(thread));
      expect(cubit.currentAuthor?.id, 'player:TEST-USER');
      expect(cubit.currentAuthor?.displayName, 'PLAYER ONE');
      expect(cubit.currentAuthor?.playerTag, 'TEST-USER');
      expect(cubit.currentAuthor?.avatarId, 'rodri');
      await cubit.close();
    },
  );

  test('mutations update the thread and its visible count', () async {
    final cubit = MatchCircleCubit(
      LocalMatchCircleRepository(now: () => now),
      SecureGameStorage(),
    );
    final match = _match();
    await cubit.ensureThread(match);
    final initialCount = cubit.countFor(match);

    expect(await cubit.addComment(match, '  New thought  '), isTrue);
    final author = cubit.currentAuthor!;
    final parent = cubit
        .threadFor(match)!
        .topLevelPosts
        .firstWhere((post) => post.isOwnedBy(author));
    expect(parent.text, 'New thought');
    expect(cubit.countFor(match), initialCount + 1);

    expect(
      await cubit.addReply(match, parentId: parent.id, text: 'A reply'),
      isTrue,
    );
    final reply = cubit.threadFor(match)!.repliesFor(parent.id).single;
    expect(cubit.countFor(match), initialCount + 2);

    expect(await cubit.toggleLike(match, parent.id), isTrue);
    expect(cubit.threadFor(match)!.postById(parent.id)?.likes, 1);
    expect(
      cubit.threadFor(match)!.postById(parent.id)?.isLikedBy(author.id),
      isTrue,
    );

    expect(
      await cubit.editPost(match, postId: parent.id, text: 'Edited'),
      isTrue,
    );
    expect(cubit.threadFor(match)!.postById(parent.id)?.text, 'Edited');

    expect(await cubit.deletePost(match, parent.id), isTrue);
    expect(cubit.threadFor(match)!.postById(parent.id)?.isDeleted, isTrue);
    expect(await cubit.deletePost(match, reply.id), isTrue);
    expect(cubit.threadFor(match)!.postById(parent.id), isNull);
    expect(cubit.countFor(match), initialCount);
    await cubit.close();
  });

  test('failed mutation keeps the prior thread and exposes an error', () async {
    final repository = _FailingRepository();
    final cubit = MatchCircleCubit(repository, SecureGameStorage());
    final match = _match();
    await cubit.ensureThread(match);
    final before = cubit.threadFor(match);

    final saved = await cubit.addComment(match, 'Draft stays in the UI');

    expect(saved, isFalse);
    expect(cubit.threadFor(match), same(before));
    expect(cubit.countFor(match), before!.visibleCount);
    expect(cubit.mutating(match), isFalse);
    expect(cubit.error(match), 'Disk unavailable.');

    cubit.clearError(match);
    expect(cubit.error(match), isNull);
    await cubit.close();
  });

  test('failed load clears loading and can be retried', () async {
    final repository = _FailingRepository(loadFailures: 1);
    final cubit = MatchCircleCubit(repository, SecureGameStorage());
    final match = _match();

    expect(await cubit.ensureThread(match), isNull);
    expect(cubit.loading(match), isFalse);
    expect(cubit.error(match), 'Disk unavailable.');

    final retried = await cubit.ensureThread(match);
    expect(retried, isNotNull);
    expect(cubit.error(match), isNull);
    await cubit.close();
  });
}

class _FailingRepository implements MatchCircleRepository {
  _FailingRepository({this.loadFailures = 0}) : thread = _thread();

  int loadFailures;
  final MatchCircleThread thread;

  @override
  Future<MatchCircleThread> loadThread(SportMatch match) async {
    if (loadFailures > 0) {
      loadFailures--;
      throw const MatchCirclePersistenceException('Disk unavailable.');
    }
    return thread;
  }

  @override
  Future<int> getVisibleCount(SportMatch match) async => thread.visibleCount;

  @override
  Future<MatchCircleThread> addComment({
    required SportMatch match,
    required MatchCircleAuthor author,
    required String text,
  }) async => throw const MatchCirclePersistenceException('Disk unavailable.');

  @override
  Future<MatchCircleThread> addReply({
    required SportMatch match,
    required String parentId,
    required MatchCircleAuthor author,
    required String text,
  }) async => throw const MatchCirclePersistenceException('Disk unavailable.');

  @override
  Future<MatchCircleThread> toggleLike({
    required SportMatch match,
    required String postId,
    required String authorId,
  }) async => throw const MatchCirclePersistenceException('Disk unavailable.');

  @override
  Future<MatchCircleThread> editPost({
    required SportMatch match,
    required String postId,
    required String authorId,
    required String text,
  }) async => throw const MatchCirclePersistenceException('Disk unavailable.');

  @override
  Future<MatchCircleThread> deletePost({
    required SportMatch match,
    required String postId,
    required String authorId,
  }) async => throw const MatchCirclePersistenceException('Disk unavailable.');
}

MatchCircleThread _thread() {
  final now = DateTime.utc(2026, 7, 15, 12);
  const author = MatchCircleAuthor(
    id: 'seed:jasper',
    displayName: 'Jasper',
    avatarId: 'adams',
  );
  return MatchCircleThread(
    key: 'football:epl:match-1',
    sport: Sport.football,
    leagueId: 'epl',
    matchId: 'match-1',
    posts: [
      MatchCirclePost(
        id: 'seed-1',
        threadKey: 'football:epl:match-1',
        author: author,
        text: 'Seed',
        createdAt: now,
      ),
    ],
    seededAt: now,
    updatedAt: now,
  );
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
