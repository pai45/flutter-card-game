import 'dart:collection';

import 'sport_match.dart';

/// The maximum number of characters accepted by a Match Circle post.
const int matchCirclePostMaxLength = 500;

/// Stable storage/state key for a match discussion.
String matchCircleThreadKey(SportMatch match) =>
    '${match.sport.name}:${match.leagueId}:${match.id}';

/// Compact count used by the Match Circle call-to-action.
String compactMatchCircleCount(int count) {
  if (count < 1000) return '$count';
  if (count < 1000000) {
    final value = count / 1000;
    return '${_compactNumber(value)}K';
  }
  final value = count / 1000000;
  return '${_compactNumber(value)}M';
}

String _compactNumber(double value) {
  final rounded = value.roundToDouble();
  return value == rounded
      ? rounded.toInt().toString()
      : value.toStringAsFixed(1);
}

class MatchCircleAuthor {
  const MatchCircleAuthor({
    required this.id,
    required this.displayName,
    required this.avatarId,
    this.playerTag,
  });

  factory MatchCircleAuthor.fromJson(Map<String, dynamic> json) =>
      MatchCircleAuthor(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        avatarId: json['avatarId'] as String,
        playerTag: json['playerTag'] as String?,
      );

  final String id;
  final String displayName;
  final String avatarId;
  final String? playerTag;

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'avatarId': avatarId,
    if (playerTag != null) 'playerTag': playerTag,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatchCircleAuthor &&
          id == other.id &&
          displayName == other.displayName &&
          avatarId == other.avatarId &&
          playerTag == other.playerTag;

  @override
  int get hashCode => Object.hash(id, displayName, avatarId, playerTag);
}

class MatchCirclePost {
  MatchCirclePost({
    required this.id,
    required this.threadKey,
    required this.author,
    required this.text,
    required this.createdAt,
    this.parentId,
    this.editedAt,
    this.likes = 0,
    Set<String> likedByAuthorIds = const {},
    this.isDeleted = false,
  }) : likedByAuthorIds = UnmodifiableSetView(
         Set<String>.from(likedByAuthorIds),
       );

  factory MatchCirclePost.fromJson(Map<String, dynamic> json) =>
      MatchCirclePost(
        id: json['id'] as String,
        threadKey: json['threadKey'] as String,
        parentId: json['parentId'] as String?,
        author: MatchCircleAuthor.fromJson(
          Map<String, dynamic>.from(json['author'] as Map),
        ),
        text: json['text'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        editedAt: json['editedAt'] == null
            ? null
            : DateTime.parse(json['editedAt'] as String),
        likes: json['likes'] as int? ?? 0,
        likedByAuthorIds: Set<String>.from(
          json['likedByAuthorIds'] as List? ?? const [],
        ),
        isDeleted: json['isDeleted'] as bool? ?? false,
      );

  final String id;
  final String threadKey;
  final String? parentId;
  final MatchCircleAuthor author;
  final String text;
  final DateTime createdAt;
  final DateTime? editedAt;
  final int likes;
  final Set<String> likedByAuthorIds;
  final bool isDeleted;

  bool get isReply => parentId != null;
  bool get isEdited => editedAt != null;

  bool isOwnedBy(MatchCircleAuthor candidate) => author.id == candidate.id;

  bool isLikedBy(String authorId) => likedByAuthorIds.contains(authorId);

  MatchCirclePost copyWith({
    String? text,
    Object? editedAt = _sentinel,
    int? likes,
    Set<String>? likedByAuthorIds,
    bool? isDeleted,
  }) => MatchCirclePost(
    id: id,
    threadKey: threadKey,
    parentId: parentId,
    author: author,
    text: text ?? this.text,
    createdAt: createdAt,
    editedAt: identical(editedAt, _sentinel)
        ? this.editedAt
        : editedAt as DateTime?,
    likes: likes ?? this.likes,
    likedByAuthorIds: likedByAuthorIds ?? this.likedByAuthorIds,
    isDeleted: isDeleted ?? this.isDeleted,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'threadKey': threadKey,
    if (parentId != null) 'parentId': parentId,
    'author': author.toJson(),
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    if (editedAt != null) 'editedAt': editedAt!.toIso8601String(),
    'likes': likes,
    'likedByAuthorIds': likedByAuthorIds.toList(growable: false)..sort(),
    'isDeleted': isDeleted,
  };
}

class MatchCircleThread {
  MatchCircleThread({
    required this.key,
    required this.sport,
    required this.leagueId,
    required this.matchId,
    required List<MatchCirclePost> posts,
    required this.seededAt,
    required this.updatedAt,
  }) : posts = UnmodifiableListView(List<MatchCirclePost>.from(posts));

  factory MatchCircleThread.fromJson(
    Map<String, dynamic> json,
  ) => MatchCircleThread(
    key: json['key'] as String,
    sport: Sport.values.byName(json['sport'] as String),
    leagueId: json['leagueId'] as String,
    matchId: json['matchId'] as String,
    posts: (json['posts'] as List? ?? const [])
        .map(
          (post) =>
              MatchCirclePost.fromJson(Map<String, dynamic>.from(post as Map)),
        )
        .toList(growable: false),
    seededAt: DateTime.parse(json['seededAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  final String key;
  final Sport sport;
  final String leagueId;
  final String matchId;
  final List<MatchCirclePost> posts;
  final DateTime seededAt;
  final DateTime updatedAt;

  /// Visible top-level comments, newest first. A deleted parent remains as a
  /// tombstone only while it has at least one visible reply.
  List<MatchCirclePost> get topLevelPosts {
    final liveReplyParents = {
      for (final post in posts)
        if (post.parentId != null && !post.isDeleted) post.parentId!,
    };
    final result =
        [
          for (final post in posts)
            if (!post.isReply &&
                (!post.isDeleted || liveReplyParents.contains(post.id)))
              post,
        ]..sort((a, b) {
          final byTime = b.createdAt.compareTo(a.createdAt);
          return byTime != 0 ? byTime : b.id.compareTo(a.id);
        });
    return List.unmodifiable(result);
  }

  /// Visible one-level replies for [parentId], oldest first.
  List<MatchCirclePost> repliesFor(String parentId) {
    final result =
        [
          for (final post in posts)
            if (post.parentId == parentId && !post.isDeleted) post,
        ]..sort((a, b) {
          final byTime = a.createdAt.compareTo(b.createdAt);
          return byTime != 0 ? byTime : a.id.compareTo(b.id);
        });
    return List.unmodifiable(result);
  }

  int get visibleCount => posts.where((post) => !post.isDeleted).length;
  int get commentCount => visibleCount;

  MatchCirclePost? postById(String postId) {
    for (final post in posts) {
      if (post.id == postId) return post;
    }
    return null;
  }

  MatchCircleThread copyWith({
    List<MatchCirclePost>? posts,
    DateTime? updatedAt,
  }) => MatchCircleThread(
    key: key,
    sport: sport,
    leagueId: leagueId,
    matchId: matchId,
    posts: posts ?? this.posts,
    seededAt: seededAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'key': key,
    'sport': sport.name,
    'leagueId': leagueId,
    'matchId': matchId,
    'posts': posts.map((post) => post.toJson()).toList(growable: false),
    'seededAt': seededAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

const Object _sentinel = Object();
