import 'dart:collection';

import '../../models/match_circle.dart';
import '../../models/sport_match.dart';

class MatchCircleState {
  MatchCircleState({
    Map<String, MatchCircleThread> threads = const {},
    Set<String> loadingThreadKeys = const {},
    Set<String> mutatingThreadKeys = const {},
    Map<String, String> errorsByThreadKey = const {},
    this.currentAuthor,
  }) : threads = UnmodifiableMapView(
         Map<String, MatchCircleThread>.from(threads),
       ),
       loadingThreadKeys = UnmodifiableSetView(
         Set<String>.from(loadingThreadKeys),
       ),
       mutatingThreadKeys = UnmodifiableSetView(
         Set<String>.from(mutatingThreadKeys),
       ),
       errorsByThreadKey = UnmodifiableMapView(
         Map<String, String>.from(errorsByThreadKey),
       );

  final Map<String, MatchCircleThread> threads;
  final Set<String> loadingThreadKeys;
  final Set<String> mutatingThreadKeys;
  final Map<String, String> errorsByThreadKey;
  final MatchCircleAuthor? currentAuthor;

  MatchCircleThread? threadFor(SportMatch match) =>
      threads[matchCircleThreadKey(match)];

  bool loading(SportMatch match) =>
      loadingThreadKeys.contains(matchCircleThreadKey(match));

  bool isLoading(SportMatch match) => loading(match);

  bool mutating(SportMatch match) =>
      mutatingThreadKeys.contains(matchCircleThreadKey(match));

  bool isMutating(SportMatch match) => mutating(match);

  String? error(SportMatch match) =>
      errorsByThreadKey[matchCircleThreadKey(match)];

  String? errorFor(SportMatch match) => error(match);

  int countFor(SportMatch match) => threadFor(match)?.visibleCount ?? 0;

  MatchCircleState copyWith({
    Map<String, MatchCircleThread>? threads,
    Set<String>? loadingThreadKeys,
    Set<String>? mutatingThreadKeys,
    Map<String, String>? errorsByThreadKey,
    Object? currentAuthor = _sentinel,
  }) => MatchCircleState(
    threads: threads ?? this.threads,
    loadingThreadKeys: loadingThreadKeys ?? this.loadingThreadKeys,
    mutatingThreadKeys: mutatingThreadKeys ?? this.mutatingThreadKeys,
    errorsByThreadKey: errorsByThreadKey ?? this.errorsByThreadKey,
    currentAuthor: identical(currentAuthor, _sentinel)
        ? this.currentAuthor
        : currentAuthor as MatchCircleAuthor?,
  );
}

const Object _sentinel = Object();
