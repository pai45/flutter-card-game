import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/secure_storage_service.dart';

/// The player's local friends list — rivals they've added from a leaderboard
/// dossier, kept by display name. There is no backend, so this is a personal
/// bookmark set persisted on-device via [SecureGameStorage].
class FriendsState {
  const FriendsState({this.loading = true, this.friends = const []});

  final bool loading;
  final List<String> friends;

  bool contains(String name) => friends.contains(name);

  FriendsState copyWith({bool? loading, List<String>? friends}) => FriendsState(
    loading: loading ?? this.loading,
    friends: friends ?? this.friends,
  );
}

class FriendsCubit extends Cubit<FriendsState> {
  FriendsCubit(this._storage) : super(const FriendsState());

  final SecureGameStorage _storage;

  Future<void> load() async {
    final friends = await _storage.loadFriends();
    emit(FriendsState(loading: false, friends: friends));
  }

  bool isFriend(String name) => state.friends.contains(name);

  Future<void> addFriend(String name) async {
    if (state.friends.contains(name)) return;
    final updated = [...state.friends, name];
    emit(state.copyWith(friends: updated));
    await _storage.saveFriends(updated);
  }

  Future<void> removeFriend(String name) async {
    if (!state.friends.contains(name)) return;
    final updated = state.friends.where((n) => n != name).toList();
    emit(state.copyWith(friends: updated));
    await _storage.saveFriends(updated);
  }

  /// Adds the friend if absent, removes if present. Returns the new membership
  /// so the caller can play the right "added/removed" beat.
  Future<bool> toggleFriend(String name) async {
    final nowFriend = !state.friends.contains(name);
    if (nowFriend) {
      await addFriend(name);
    } else {
      await removeFriend(name);
    }
    return nowFriend;
  }
}
