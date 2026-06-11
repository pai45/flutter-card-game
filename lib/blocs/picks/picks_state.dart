import '../../models/picks.dart';
import '../../models/sport_match.dart';

enum PickSportFilter { all, ipl, epl, fifa, nba, laliga, seriea }

enum PickMarketStatusFilter { all, open, closed }

enum PickSortOption { newest, startTime, closingSoon, volume, trending }

class PicksState {
  const PicksState({
    this.loading = true,
    this.markets = const [],
    this.positions = const {},
    this.sportFilter = PickSportFilter.all,
    this.typeFilter,
    this.statusFilter = PickMarketStatusFilter.open,
    this.sortOption = PickSortOption.startTime,
    this.message,
  });

  final bool loading;
  final List<PickMarket> markets;
  final Map<String, PickPosition> positions;
  final PickSportFilter sportFilter;
  final PickMarketType? typeFilter;
  final PickMarketStatusFilter statusFilter;
  final PickSortOption sortOption;
  final String? message;

  List<PickMarket> get filteredMarkets {
    final items = markets.where(_matchesFilters).toList();
    items.sort(_compareMarkets);
    return items;
  }

  List<PickPosition> get positionList {
    final items = positions.values.toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return items;
  }

  int get activePositionCount =>
      positions.values.where((position) => !position.isFinal).length;

  int get claimableCount =>
      positions.values.where((position) => position.canSettle).length;

  int get openExposureOz => positions.values
      .where((position) => !position.isFinal)
      .fold(0, (sum, position) => sum + position.stakeOz);

  int get realizedProfitOz => positions.values
      .where((position) => position.isFinal)
      .fold(0, (sum, position) => sum + position.realizedProfit);

  PickMarket? marketFor(String marketId) {
    for (final market in markets) {
      if (market.id == marketId) return market;
    }
    return null;
  }

  PickPosition? positionForMarket(String marketId) {
    for (final position in positions.values) {
      if (position.marketId == marketId) return position;
    }
    return null;
  }

  bool _matchesFilters(PickMarket market) {
    if (typeFilter != null && market.type != typeFilter) return false;
    if (!_matchesSport(market)) return false;
    return switch (statusFilter) {
      PickMarketStatusFilter.all => true,
      PickMarketStatusFilter.open => market.canBuy,
      PickMarketStatusFilter.closed =>
        market.status == PickMarketStatus.closed ||
            market.status == PickMarketStatus.settled ||
            market.status == PickMarketStatus.unresolved ||
            market.status == PickMarketStatus.voided,
    };
  }

  bool _matchesSport(PickMarket market) {
    return switch (sportFilter) {
      PickSportFilter.all => true,
      PickSportFilter.ipl => market.leagueLabel == 'IPL',
      PickSportFilter.epl => market.leagueLabel == 'EPL',
      PickSportFilter.fifa => market.leagueLabel == 'FIFA',
      PickSportFilter.nba => false,
      PickSportFilter.laliga =>
        market.sport == Sport.football && market.leagueLabel == 'LALIGA',
      PickSportFilter.seriea =>
        market.sport == Sport.football && market.leagueLabel == 'SERIE A',
    };
  }

  int _compareMarkets(PickMarket a, PickMarket b) {
    return switch (sortOption) {
      PickSortOption.newest => b.closesAt.compareTo(a.closesAt),
      PickSortOption.startTime => a.closesAt.compareTo(b.closesAt),
      PickSortOption.closingSoon => _closingSoonRank(a, b),
      PickSortOption.volume => b.volumeOz.compareTo(a.volumeOz),
      PickSortOption.trending => _trendScore(b).compareTo(_trendScore(a)),
    };
  }

  int _closingSoonRank(PickMarket a, PickMarket b) {
    final aOpen = a.canBuy ? 0 : 1;
    final bOpen = b.canBuy ? 0 : 1;
    if (aOpen != bOpen) return aOpen.compareTo(bOpen);
    return a.closesAt.compareTo(b.closesAt);
  }

  int _trendScore(PickMarket market) {
    if (market.priceHistory.length < 2) return 0;
    final first = market.priceHistory.first.percentsByOutcome;
    final last = market.priceHistory.last.percentsByOutcome;
    var score = 0;
    for (final outcome in market.outcomes) {
      final start = first[outcome.id];
      final end = last[outcome.id];
      if (start != null && end != null) score += (end - start).abs();
    }
    return score;
  }

  PicksState copyWith({
    bool? loading,
    List<PickMarket>? markets,
    Map<String, PickPosition>? positions,
    PickSportFilter? sportFilter,
    Object? typeFilter = _sentinel,
    PickMarketStatusFilter? statusFilter,
    PickSortOption? sortOption,
    String? message,
    bool clearMessage = false,
  }) => PicksState(
    loading: loading ?? this.loading,
    markets: markets ?? this.markets,
    positions: positions ?? this.positions,
    sportFilter: sportFilter ?? this.sportFilter,
    typeFilter: identical(typeFilter, _sentinel)
        ? this.typeFilter
        : typeFilter as PickMarketType?,
    statusFilter: statusFilter ?? this.statusFilter,
    sortOption: sortOption ?? this.sortOption,
    message: clearMessage ? null : message ?? this.message,
  );
}

const Object _sentinel = Object();

class PickPlacementResult {
  const PickPlacementResult._({
    required this.success,
    required this.message,
    this.position,
    this.stakeOz = 0,
    this.shares = 0,
  });

  factory PickPlacementResult.success({
    required PickPosition position,
    required int stakeOz,
    required int shares,
  }) => PickPlacementResult._(
    success: true,
    message: 'Pick confirmed',
    position: position,
    stakeOz: stakeOz,
    shares: shares,
  );

  factory PickPlacementResult.failure(String message) =>
      PickPlacementResult._(success: false, message: message);

  final bool success;
  final String message;
  final PickPosition? position;
  final int stakeOz;
  final int shares;
}

class PickSettlementResult {
  const PickSettlementResult({
    required this.settled,
    required this.message,
    this.position,
    this.payoutOz = 0,
  });

  final bool settled;
  final String message;
  final PickPosition? position;
  final int payoutOz;
}
