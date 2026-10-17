part of 'trending_match_bento.dart';

class _EditorialCycle {
  const _EditorialCycle(
    this.sport,
    this.matches,
    this.compact,
    this.missions,
    this.events,
    this.future,
  );
  final Sport sport;
  final List<String> matches, missions, events;
  final String? compact, future;
}

extension _EditorialSelection on _TrendingMatchesViewState {
  _EditorialCycle _select(
    Sport sport,
    PredictionState state,
    PicksState picks,
    Set<String> excluded,
  ) {
    final openMatches = state.predictions.values
        .where((p) => p.status == PredictionStatus.open)
        .map((p) => p.matchId)
        .toSet();
    final followedLeagues = state.followedLeagueIds.toSet();
    final freeQuizMatches = state.quizzes.values
        .where((q) => q.entryFee == 0)
        .map((q) => q.matchId)
        .toSet();
    final priorities = <String, int>{};
    for (final fixture in state.fixtures.where((m) => m.sport == sport)) {
      priorities.putIfAbsent(
        fixture.id,
        () =>
            (state.isFavoriteMatch(fixture) ? 4 : 0) +
            (followedLeagues.contains(fixture.leagueId) ? 2 : 0) +
            (openMatches.contains(fixture.id) ? 1 : 0),
      );
    }
    final championship = RegExp(
      MatchDiscoveryTokens.futurePriorityPattern,
      caseSensitive: false,
    );
    final seen = <String>{};
    final fixtures =
        state.fixtures.where((m) => m.sport == sport && seen.add(m.id)).toList()
          ..sort((a, b) {
            final p = priorities[b.id]!.compareTo(priorities[a.id]!);
            if (p != 0) return p;
            final live = (b.status == MatchStatus.live ? 1 : 0).compareTo(
              a.status == MatchStatus.live ? 1 : 0,
            );
            if (live != 0) return live;
            final time = a.kickoff.compareTo(b.kickoff);
            return time != 0 ? time : a.id.compareTo(b.id);
          });
    final matches = fixtures
        .take(MatchDiscoveryTokens.cycleCounts['matches']!)
        .map((m) => m.id)
        .toList();
    final compact = fixtures
        .skip(MatchDiscoveryTokens.cycleCounts['matches']!)
        .firstOrNull
        ?.id;
    final missions = fixtures
        .where(
          (m) =>
              m.status == MatchStatus.upcoming &&
              freeQuizMatches.contains(m.id),
        )
        .take(MatchDiscoveryTokens.cycleCounts['missions']!)
        .map((m) => m.id)
        .toList();
    final events = picks.markets
        .where(
          (m) =>
              m.sport == sport &&
              m.type == PickMarketType.event &&
              m.outcomes.isNotEmpty,
        )
        .take(MatchDiscoveryTokens.cycleCounts['events']!)
        .map((m) => m.id)
        .toList();
    final futures =
        picks.markets
            .where(
              (market) =>
                  market.sport == sport &&
                  market.type == PickMarketType.future &&
                  market.outcomes.isNotEmpty &&
                  !excluded.contains(market.id),
            )
            .toList()
          ..sort((a, b) {
            int rank(PickMarket market) =>
                (market.canBuy ? 4 : 0) +
                (championship.hasMatch(market.question) ? 2 : 0);
            final order = rank(b).compareTo(rank(a));
            return order != 0 ? order : a.id.compareTo(b.id);
          });
    return _EditorialCycle(
      sport,
      matches,
      compact,
      missions,
      events,
      futures.firstOrNull?.id,
    );
  }
}
