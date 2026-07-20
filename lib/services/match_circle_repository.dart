import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/match_circle.dart';
import '../models/sport_match.dart';

class MatchCircleException implements Exception {
  const MatchCircleException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MatchCircleValidationException extends MatchCircleException {
  const MatchCircleValidationException(super.message);
}

class MatchCircleNotFoundException extends MatchCircleException {
  const MatchCircleNotFoundException(super.message);
}

class MatchCirclePermissionException extends MatchCircleException {
  const MatchCirclePermissionException(super.message);
}

class MatchCirclePersistenceException extends MatchCircleException {
  const MatchCirclePersistenceException(super.message);
}

/// Trims and validates text before it enters the repository.
String normalizeMatchCirclePostText(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw const MatchCircleValidationException('Write something first.');
  }
  if (trimmed.length > matchCirclePostMaxLength) {
    throw const MatchCircleValidationException(
      'Comments can be up to 500 characters.',
    );
  }
  return trimmed;
}

abstract class MatchCircleRepository {
  Future<MatchCircleThread> loadThread(SportMatch match);

  Future<int> getVisibleCount(SportMatch match);

  Future<MatchCircleThread> addComment({
    required SportMatch match,
    required MatchCircleAuthor author,
    required String text,
  });

  Future<MatchCircleThread> addReply({
    required SportMatch match,
    required String parentId,
    required MatchCircleAuthor author,
    required String text,
  });

  Future<MatchCircleThread> toggleLike({
    required SportMatch match,
    required String postId,
    required String authorId,
  });

  Future<MatchCircleThread> editPost({
    required SportMatch match,
    required String postId,
    required String authorId,
    required String text,
  });

  Future<MatchCircleThread> deletePost({
    required SportMatch match,
    required String postId,
    required String authorId,
  });
}

/// Device-local Match Circle storage.
///
/// All discussions live in one versioned JSON envelope. Operations are
/// serialized so mutations to different matches cannot overwrite one another.
class LocalMatchCircleRepository implements MatchCircleRepository {
  LocalMatchCircleRepository({
    SharedPreferences? preferences,
    Future<SharedPreferences> Function()? preferencesLoader,
    DateTime Function()? now,
    String Function()? idGenerator,
  }) : assert(preferences == null || preferencesLoader == null),
       _preferences = preferences != null
           ? Future.value(preferences)
           : (preferencesLoader ?? SharedPreferences.getInstance)(),
       _now = now ?? DateTime.now,
       _idGenerator = idGenerator;

  static const int storageVersion = 1;
  static const String storageKey = 'pd_match_circle_threads_v1';

  final Future<SharedPreferences> _preferences;
  final DateTime Function() _now;
  final String Function()? _idGenerator;
  Future<void> _operationTail = Future.value();
  int _idSequence = 0;

  @override
  Future<MatchCircleThread> loadThread(SportMatch match) =>
      _synchronized(() async {
        final threads = await _readThreads();
        final key = matchCircleThreadKey(match);
        final existing = threads[key];
        if (existing != null) return existing;

        final seeded = _seedThread(match);
        threads[key] = seeded;
        await _writeThreads(threads);
        return seeded;
      });

  @override
  Future<int> getVisibleCount(SportMatch match) async =>
      (await loadThread(match)).visibleCount;

  @override
  Future<MatchCircleThread> addComment({
    required SportMatch match,
    required MatchCircleAuthor author,
    required String text,
  }) => _mutate(match, (thread) {
    final createdAt = _now();
    final post = MatchCirclePost(
      id: _nextUniquePostId(thread),
      threadKey: thread.key,
      author: author,
      text: normalizeMatchCirclePostText(text),
      createdAt: createdAt,
    );
    return thread.copyWith(
      posts: [...thread.posts, post],
      updatedAt: createdAt,
    );
  });

  @override
  Future<MatchCircleThread> addReply({
    required SportMatch match,
    required String parentId,
    required MatchCircleAuthor author,
    required String text,
  }) => _mutate(match, (thread) {
    final parent = thread.postById(parentId);
    if (parent == null || parent.isDeleted) {
      throw const MatchCircleNotFoundException(
        'That comment is no longer available.',
      );
    }
    if (parent.isReply) {
      throw const MatchCircleValidationException(
        'Replies can only be added to a main comment.',
      );
    }

    final createdAt = _now();
    final reply = MatchCirclePost(
      id: _nextUniquePostId(thread),
      threadKey: thread.key,
      parentId: parent.id,
      author: author,
      text: normalizeMatchCirclePostText(text),
      createdAt: createdAt,
    );
    return thread.copyWith(
      posts: [...thread.posts, reply],
      updatedAt: createdAt,
    );
  });

  @override
  Future<MatchCircleThread> toggleLike({
    required SportMatch match,
    required String postId,
    required String authorId,
  }) => _mutate(match, (thread) {
    final index = _livePostIndex(thread, postId);
    final post = thread.posts[index];
    final likedBy = Set<String>.from(post.likedByAuthorIds);
    final wasLiked = likedBy.remove(authorId);
    if (!wasLiked) likedBy.add(authorId);
    final nextLikes = wasLiked
        ? (post.likes > 0 ? post.likes - 1 : 0)
        : post.likes + 1;
    final posts = List<MatchCirclePost>.from(thread.posts);
    posts[index] = post.copyWith(likes: nextLikes, likedByAuthorIds: likedBy);
    return thread.copyWith(posts: posts, updatedAt: _now());
  });

  @override
  Future<MatchCircleThread> editPost({
    required SportMatch match,
    required String postId,
    required String authorId,
    required String text,
  }) => _mutate(match, (thread) {
    final index = _livePostIndex(thread, postId);
    final post = thread.posts[index];
    _requireOwnership(post, authorId);
    final editedAt = _now();
    final posts = List<MatchCirclePost>.from(thread.posts);
    posts[index] = post.copyWith(
      text: normalizeMatchCirclePostText(text),
      editedAt: editedAt,
    );
    return thread.copyWith(posts: posts, updatedAt: editedAt);
  });

  @override
  Future<MatchCircleThread> deletePost({
    required SportMatch match,
    required String postId,
    required String authorId,
  }) => _mutate(match, (thread) {
    final index = _livePostIndex(thread, postId);
    final post = thread.posts[index];
    _requireOwnership(post, authorId);
    final posts = List<MatchCirclePost>.from(thread.posts);

    if (post.isReply) {
      final parentId = post.parentId!;
      posts.removeAt(index);
      final hasLiveReplies = posts.any(
        (candidate) => candidate.parentId == parentId && !candidate.isDeleted,
      );
      if (!hasLiveReplies) {
        posts.removeWhere(
          (candidate) => candidate.id == parentId && candidate.isDeleted,
        );
      }
    } else {
      final hasLiveReplies = posts.any(
        (candidate) => candidate.parentId == post.id && !candidate.isDeleted,
      );
      if (hasLiveReplies) {
        posts[index] = post.copyWith(
          text: '',
          editedAt: null,
          likes: 0,
          likedByAuthorIds: const {},
          isDeleted: true,
        );
      } else {
        posts.removeAt(index);
      }
    }

    return thread.copyWith(posts: posts, updatedAt: _now());
  });

  Future<MatchCircleThread> _mutate(
    SportMatch match,
    MatchCircleThread Function(MatchCircleThread thread) update,
  ) => _synchronized(() async {
    final threads = await _readThreads();
    final key = matchCircleThreadKey(match);
    final current = threads[key] ?? _seedThread(match);
    final updated = update(current);
    threads[key] = updated;
    await _writeThreads(threads);
    return updated;
  });

  int _livePostIndex(MatchCircleThread thread, String postId) {
    final index = thread.posts.indexWhere((post) => post.id == postId);
    if (index < 0 || thread.posts[index].isDeleted) {
      throw const MatchCircleNotFoundException(
        'That comment is no longer available.',
      );
    }
    return index;
  }

  void _requireOwnership(MatchCirclePost post, String authorId) {
    if (post.author.id != authorId) {
      throw const MatchCirclePermissionException(
        'You can only change your own comments.',
      );
    }
  }

  String _nextUniquePostId(MatchCircleThread thread) {
    for (var attempt = 0; attempt < 1000; attempt++) {
      final generated = _idGenerator?.call();
      final id =
          generated ?? 'mc_${_now().microsecondsSinceEpoch}_${_idSequence++}';
      if (thread.postById(id) == null) return id;
      if (generated != null) {
        throw const MatchCirclePersistenceException(
          'Could not create a unique comment.',
        );
      }
    }
    throw const MatchCirclePersistenceException(
      'Could not create a unique comment.',
    );
  }

  MatchCircleThread _seedThread(SportMatch match) {
    final key = matchCircleThreadKey(match);
    final seededAt = _now();
    final primaryId = '$key:seed:1';
    final copy = _seedCopy(match);
    final posts = <MatchCirclePost>[
      MatchCirclePost(
        id: primaryId,
        threadKey: key,
        author: _priyanshu,
        text: copy.primary,
        createdAt: seededAt.subtract(const Duration(hours: 7)),
        likes: 3,
      ),
      MatchCirclePost(
        id: '$key:seed:2',
        threadKey: key,
        parentId: primaryId,
        author: _jasper,
        text: copy.reply,
        createdAt: seededAt.subtract(const Duration(hours: 6)),
        likes: 1,
      ),
      MatchCirclePost(
        id: '$key:seed:3',
        threadKey: key,
        author: _maya,
        text: copy.secondary,
        createdAt: seededAt.subtract(const Duration(hours: 4)),
        likes: 2,
      ),
    ];
    return MatchCircleThread(
      key: key,
      sport: match.sport,
      leagueId: match.leagueId,
      matchId: match.id,
      posts: posts,
      seededAt: seededAt,
      updatedAt: seededAt,
    );
  }

  ({String primary, String reply, String secondary}) _seedCopy(
    SportMatch match,
  ) {
    final contest = '${match.home.name} vs ${match.away.name}';
    return switch ((match.sport, match.status)) {
      (Sport.football, MatchStatus.upcoming) => (
        primary: 'Score predictions for $contest?',
        reply: 'I think one goal decides it.',
        secondary: 'Which midfield wins the first 20 minutes?',
      ),
      (Sport.football, MatchStatus.live) => (
        primary: 'This match is wide open right now.',
        reply: 'The next goal changes everything.',
        secondary: 'Who has impressed you most so far?',
      ),
      (Sport.football, MatchStatus.finished) => (
        primary: 'That $contest result will be talked about.',
        reply: 'The turning point was clear to me.',
        secondary: 'Who was your player of the match?',
      ),
      (Sport.cricket, MatchStatus.upcoming) => (
        primary: 'What is a winning total for $contest?',
        reply: 'The powerplay matchup will be huge.',
        secondary: 'Who takes the first wicket?',
      ),
      (Sport.cricket, MatchStatus.live) => (
        primary: 'This spell could decide the match.',
        reply: 'One big over swings the pressure.',
        secondary: 'How would you play the next five overs?',
      ),
      (Sport.cricket, MatchStatus.finished) => (
        primary: 'What was the key moment in $contest?',
        reply: 'The middle overs made the difference.',
        secondary: 'Who gets your player of the match vote?',
      ),
      (Sport.basketball, MatchStatus.upcoming) => (
        primary: 'Who sets the pace in $contest?',
        reply: 'The bench minutes could decide it.',
        secondary: 'Drop your final score prediction.',
      ),
      (Sport.basketball, MatchStatus.live) => (
        primary: 'This run has changed the energy.',
        reply: 'The next timeout is important.',
        secondary: 'Who should take the next big shot?',
      ),
      (Sport.basketball, MatchStatus.finished) => (
        primary: 'What decided $contest tonight?',
        reply: 'The fourth-quarter execution stood out.',
        secondary: 'Who was your MVP?',
      ),
      (Sport.tennis, MatchStatus.upcoming) => (
        primary: 'How many sets for ${match.home.name} vs ${match.away.name}?',
        reply: 'The first-serve numbers will tell the story.',
        secondary: 'Which matchup is the biggest factor?',
      ),
      (Sport.tennis, MatchStatus.live) => (
        primary: 'Momentum is moving quickly in this set.',
        reply: 'The next service game feels massive.',
        secondary: 'What adjustment would you make now?',
      ),
      (Sport.tennis, MatchStatus.finished) => (
        primary: 'What was the turning point in this match?',
        reply: 'The return game made the difference.',
        secondary: 'Best rally of the match?',
      ),
      (Sport.motorsport, MatchStatus.upcoming) => (
        primary: 'Who takes pole at ${match.home.name}?',
        reply: 'Race pace could look very different from qualifying.',
        secondary: 'Give us your podium prediction.',
      ),
      (Sport.motorsport, MatchStatus.live) => (
        primary: 'Race strategy is getting interesting now.',
        reply: 'The next pit window could decide it.',
        secondary: 'Who makes the next move through the field?',
      ),
      (Sport.motorsport, MatchStatus.finished) => (
        primary: 'How do you rate the ${match.home.name} weekend?',
        reply: 'Strategy made all the difference.',
        secondary: 'Who is your driver of the day?',
      ),
    };
  }

  Future<Map<String, MatchCircleThread>> _readThreads() async {
    try {
      final preferences = await _preferences;
      final raw = preferences.getString(storageKey);
      if (raw == null || raw.isEmpty) return {};
      final envelope = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final version = envelope['version'] as int?;
      if (version != storageVersion) {
        throw const MatchCirclePersistenceException(
          'Stored Match Circle data uses an unsupported version.',
        );
      }
      final rawThreads = Map<String, dynamic>.from(
        envelope['threads'] as Map? ?? const {},
      );
      return {
        for (final entry in rawThreads.entries)
          entry.key: MatchCircleThread.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          ),
      };
    } on MatchCircleException {
      rethrow;
    } catch (_) {
      throw const MatchCirclePersistenceException(
        'Could not read Match Circle discussions.',
      );
    }
  }

  Future<void> _writeThreads(Map<String, MatchCircleThread> threads) async {
    try {
      final preferences = await _preferences;
      final stored = await preferences.setString(
        storageKey,
        jsonEncode({
          'version': storageVersion,
          'threads': {
            for (final entry in threads.entries)
              entry.key: entry.value.toJson(),
          },
        }),
      );
      if (!stored) {
        throw const MatchCirclePersistenceException(
          'Could not save Match Circle discussions.',
        );
      }
    } on MatchCircleException {
      rethrow;
    } catch (_) {
      throw const MatchCirclePersistenceException(
        'Could not save Match Circle discussions.',
      );
    }
  }

  Future<T> _synchronized<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _operationTail = _operationTail.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}

const MatchCircleAuthor _priyanshu = MatchCircleAuthor(
  id: 'seed:priyanshu',
  displayName: 'Priyanshu',
  avatarId: 'raphinha',
);

const MatchCircleAuthor _jasper = MatchCircleAuthor(
  id: 'seed:jasper',
  displayName: 'Jasper',
  avatarId: 'rodri',
);

const MatchCircleAuthor _maya = MatchCircleAuthor(
  id: 'seed:maya',
  displayName: 'Maya',
  avatarId: 'camavinga',
);
