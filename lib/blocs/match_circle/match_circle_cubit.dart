import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/avatar_option.dart';
import '../../models/match_circle.dart';
import '../../models/sport_match.dart';
import '../../services/match_circle_repository.dart';
import '../../services/secure_storage_service.dart';
import 'match_circle_state.dart';

class MatchCircleCubit extends Cubit<MatchCircleState> {
  MatchCircleCubit(this._repository, this._storage) : super(MatchCircleState());

  final MatchCircleRepository _repository;
  final SecureGameStorage _storage;
  final Map<String, Future<MatchCircleThread?>> _threadLoads = {};
  Future<MatchCircleAuthor>? _authorLoad;

  MatchCircleAuthor? get currentAuthor => state.currentAuthor;

  MatchCircleThread? threadFor(SportMatch match) => state.threadFor(match);

  bool loading(SportMatch match) => state.loading(match);

  bool mutating(SportMatch match) => state.mutating(match);

  String? error(SportMatch match) => state.error(match);

  int countFor(SportMatch match) => state.countFor(match);

  /// Loads a match thread once. Failed loads can be retried by calling this
  /// again; concurrent requests for the same match share one future.
  Future<MatchCircleThread?> ensureThread(SportMatch match) {
    final key = matchCircleThreadKey(match);
    final inFlight = _threadLoads[key];
    if (inFlight != null) return inFlight;

    final load = _ensureThread(match);
    _threadLoads[key] = load;
    load.whenComplete(() {
      if (identical(_threadLoads[key], load)) _threadLoads.remove(key);
    });
    return load;
  }

  Future<MatchCircleThread?> _ensureThread(SportMatch match) async {
    final key = matchCircleThreadKey(match);
    final existing = state.threads[key];
    if (existing != null) {
      await _ensureCurrentAuthor(refresh: true);
      return existing;
    }

    emit(
      state.copyWith(
        loadingThreadKeys: {...state.loadingThreadKeys, key},
        errorsByThreadKey: _withoutError(key),
      ),
    );
    try {
      await _ensureCurrentAuthor();
      final thread = existing ?? await _repository.loadThread(match);
      emit(
        state.copyWith(
          threads: {...state.threads, key: thread},
          loadingThreadKeys: {...state.loadingThreadKeys}..remove(key),
          errorsByThreadKey: _withoutError(key),
        ),
      );
      return thread;
    } catch (exception) {
      emit(
        state.copyWith(
          loadingThreadKeys: {...state.loadingThreadKeys}..remove(key),
          errorsByThreadKey: {
            ...state.errorsByThreadKey,
            key: _messageFor(exception),
          },
        ),
      );
      return null;
    }
  }

  Future<bool> addComment(SportMatch match, String text) => _mutate(
    match,
    (author) =>
        _repository.addComment(match: match, author: author, text: text),
  );

  Future<bool> addReply(
    SportMatch match, {
    required String parentId,
    required String text,
  }) => _mutate(
    match,
    (author) => _repository.addReply(
      match: match,
      parentId: parentId,
      author: author,
      text: text,
    ),
  );

  Future<bool> toggleLike(SportMatch match, String postId) => _mutate(
    match,
    (author) => _repository.toggleLike(
      match: match,
      postId: postId,
      authorId: author.id,
    ),
  );

  Future<bool> editPost(
    SportMatch match, {
    required String postId,
    required String text,
  }) => _mutate(
    match,
    (author) => _repository.editPost(
      match: match,
      postId: postId,
      authorId: author.id,
      text: text,
    ),
  );

  Future<bool> deletePost(SportMatch match, String postId) => _mutate(
    match,
    (author) => _repository.deletePost(
      match: match,
      postId: postId,
      authorId: author.id,
    ),
  );

  void clearError(SportMatch match) {
    final key = matchCircleThreadKey(match);
    if (!state.errorsByThreadKey.containsKey(key)) return;
    emit(state.copyWith(errorsByThreadKey: _withoutError(key)));
  }

  Future<bool> _mutate(
    SportMatch match,
    Future<MatchCircleThread> Function(MatchCircleAuthor author) operation,
  ) async {
    final key = matchCircleThreadKey(match);
    if (state.mutatingThreadKeys.contains(key)) return false;
    if (await ensureThread(match) == null) return false;
    final author = state.currentAuthor;
    if (author == null) return false;

    emit(
      state.copyWith(
        mutatingThreadKeys: {...state.mutatingThreadKeys, key},
        errorsByThreadKey: _withoutError(key),
      ),
    );
    try {
      final thread = await operation(author);
      emit(
        state.copyWith(
          threads: {...state.threads, key: thread},
          mutatingThreadKeys: {...state.mutatingThreadKeys}..remove(key),
          errorsByThreadKey: _withoutError(key),
        ),
      );
      return true;
    } catch (exception) {
      // The previous thread remains in the map, which also lets a composer keep
      // its draft while the UI surfaces the operation error.
      emit(
        state.copyWith(
          mutatingThreadKeys: {...state.mutatingThreadKeys}..remove(key),
          errorsByThreadKey: {
            ...state.errorsByThreadKey,
            key: _messageFor(exception),
          },
        ),
      );
      return false;
    }
  }

  Future<MatchCircleAuthor> _ensureCurrentAuthor({bool refresh = false}) async {
    final existing = state.currentAuthor;
    if (existing != null && !refresh) return existing;
    final load = _authorLoad ??= _loadCurrentAuthor();
    try {
      final author = await load;
      if (state.currentAuthor != author) {
        emit(state.copyWith(currentAuthor: author));
      }
      return author;
    } finally {
      if (identical(_authorLoad, load)) _authorLoad = null;
    }
  }

  Future<MatchCircleAuthor> _loadCurrentAuthor() async {
    final playerTag = await _storage.loadOrCreatePlayerTag();
    final selectedAvatarId = await _storage.loadSelectedAvatarId();
    return MatchCircleAuthor(
      id: 'player:$playerTag',
      displayName: 'PLAYER ONE',
      avatarId: avatarOptionById(selectedAvatarId).id,
      playerTag: playerTag,
    );
  }

  Map<String, String> _withoutError(String key) => {
    for (final entry in state.errorsByThreadKey.entries)
      if (entry.key != key) entry.key: entry.value,
  };

  String _messageFor(Object exception) => switch (exception) {
    MatchCircleException error => error.message,
    _ => 'Could not update Match Circle. Try again.',
  };
}
