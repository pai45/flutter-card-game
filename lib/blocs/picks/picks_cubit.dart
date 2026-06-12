import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/picks.dart';
import '../../services/pick_repository.dart';
import '../../services/secure_storage_service.dart';
import 'picks_state.dart';

class PicksCubit extends Cubit<PicksState> {
  PicksCubit(this._repository, this._storage) : super(const PicksState());

  final PickRepository _repository;
  final SecureGameStorage _storage;

  Future<void> load() async {
    final markets = await _repository.markets();
    final stored = await _storage.loadPickPositions();
    final positions = {for (final position in stored) position.id: position};
    if (positions.isEmpty) {
      _applyDemoPositions(positions, markets);
    }
    final synced = _syncStatuses(positions, markets);
    emit(
      state.copyWith(
        loading: false,
        markets: markets,
        positions: synced,
        clearMessage: true,
      ),
    );
    await _storage.savePickPositions(synced.values.toList());
  }

  void setSportFilter(PickSportFilter filter) {
    emit(state.copyWith(sportFilter: filter, clearMessage: true));
  }

  void setTypeFilter(PickMarketType? filter) {
    emit(state.copyWith(typeFilter: filter, clearMessage: true));
  }

  void setStatusFilter(PickMarketStatusFilter filter) {
    emit(state.copyWith(statusFilter: filter, clearMessage: true));
  }

  void setSortOption(PickSortOption option) {
    emit(state.copyWith(sortOption: option, clearMessage: true));
  }

  /// Restores the default browse view (used by the empty state's
  /// CLEAR FILTERS action).
  void resetFilters() {
    emit(
      state.copyWith(
        sportFilter: PickSportFilter.all,
        typeFilter: null,
        statusFilter: PickMarketStatusFilter.all,
        clearMessage: true,
      ),
    );
  }

  Future<PickPlacementResult> placePick({
    required String marketId,
    required String outcomeId,
    required int stakeOz,
    required int balanceOz,
  }) async {
    final market = state.marketFor(marketId);
    if (market == null) {
      return PickPlacementResult.failure('Market unavailable');
    }
    if (!market.canBuy) {
      return PickPlacementResult.failure('Market is closed');
    }
    final outcome = market.outcomeFor(outcomeId);
    if (outcome == null) {
      return PickPlacementResult.failure('Outcome unavailable');
    }
    if (balanceOz < stakeOz) {
      return PickPlacementResult.failure('Not enough Oz Coins');
    }
    if (!PickMath.isValidStake(
      stakeOz: stakeOz,
      probabilityPercent: outcome.probabilityPercent,
      balanceOz: balanceOz,
    )) {
      return PickPlacementResult.failure(
        'Stake must be a multiple of ${outcome.probabilityPercent} Oz',
      );
    }

    final shares = PickMath.sharesForStake(
      stakeOz: stakeOz,
      probabilityPercent: outcome.probabilityPercent,
    );
    final existing = state.positionForMarket(marketId);
    late final PickPosition position;
    if (existing != null) {
      if (existing.isFinal || existing.canSettle) {
        return PickPlacementResult.failure('This pick is no longer open');
      }
      if (existing.outcomeId != outcomeId) {
        return PickPlacementResult.failure(
          'You already hold ${existing.outcomeLabel}',
        );
      }
      position = existing.addBuy(
        stakeOz: stakeOz,
        shareCount: shares,
        probabilityPercent: outcome.probabilityPercent,
      );
    } else {
      position = PickPosition(
        id: _positionId(marketId, outcomeId, DateTime.now()),
        marketId: market.id,
        marketQuestion: market.question,
        marketType: market.type,
        leagueLabel: market.leagueLabel,
        outcomeId: outcome.id,
        outcomeLabel: outcome.label,
        stakeOz: stakeOz,
        shareCount: shares,
        averageProbabilityPercent: outcome.probabilityPercent.toDouble(),
        submittedAt: DateTime.now(),
        status: _openStatusFor(market),
      );
    }

    final next = Map<String, PickPosition>.from(state.positions)
      ..[position.id] = position;
    emit(state.copyWith(positions: next, message: 'Pick confirmed'));
    await _storage.savePickPositions(next.values.toList());
    return PickPlacementResult.success(
      position: position,
      stakeOz: stakeOz,
      shares: shares,
    );
  }

  Future<PickSettlementResult> settlePosition(String positionId) async {
    final position = state.positions[positionId];
    if (position == null) {
      return const PickSettlementResult(
        settled: false,
        message: 'Pick unavailable',
      );
    }
    if (position.isFinal) {
      return PickSettlementResult(
        settled: false,
        message: 'Pick already settled',
        position: position,
      );
    }
    final market = state.marketFor(position.marketId);
    if (market == null) {
      return PickSettlementResult(
        settled: false,
        message: 'Market unavailable',
        position: position,
      );
    }

    final syncedStatus = _statusForMarket(market, position);
    if (syncedStatus != PickPositionStatus.settleable) {
      final updated = position.copyWith(status: syncedStatus);
      final next = Map<String, PickPosition>.from(state.positions)
        ..[updated.id] = updated;
      emit(state.copyWith(positions: next));
      await _storage.savePickPositions(next.values.toList());
      return PickSettlementResult(
        settled: false,
        message: 'Result is not ready yet',
        position: updated,
      );
    }

    final settled = _settledPosition(position, market);
    final next = Map<String, PickPosition>.from(state.positions)
      ..[settled.id] = settled;
    emit(state.copyWith(positions: next, message: _settlementMessage(settled)));
    await _storage.savePickPositions(next.values.toList());
    return PickSettlementResult(
      settled: true,
      message: _settlementMessage(settled),
      position: settled,
      payoutOz: settled.payoutOz,
    );
  }

  /// Settles every claimable position in one pass and returns the aggregate
  /// so the caller can credit coins once and play a single reveal.
  Future<PickBatchSettlementResult> settleAllClaimable() async {
    final claimable = state.claimablePositions;
    var settledCount = 0;
    var wonCount = 0;
    var stakeOz = 0;
    var payoutOz = 0;
    final next = Map<String, PickPosition>.from(state.positions);
    for (final position in claimable) {
      final market = state.marketFor(position.marketId);
      if (market == null || !market.isResultKnown) continue;
      final settled = _settledPosition(position, market);
      next[settled.id] = settled;
      settledCount++;
      stakeOz += settled.stakeOz;
      payoutOz += settled.payoutOz;
      if (settled.status == PickPositionStatus.won) wonCount++;
    }
    if (settledCount > 0) {
      emit(state.copyWith(positions: next, clearMessage: true));
      await _storage.savePickPositions(next.values.toList());
    }
    return PickBatchSettlementResult(
      settledCount: settledCount,
      wonCount: wonCount,
      stakeOz: stakeOz,
      payoutOz: payoutOz,
    );
  }

  Map<String, PickPosition> _syncStatuses(
    Map<String, PickPosition> positions,
    List<PickMarket> markets,
  ) {
    final marketById = {for (final market in markets) market.id: market};
    final next = <String, PickPosition>{};
    for (final entry in positions.entries) {
      final market = marketById[entry.value.marketId];
      if (market == null || entry.value.isFinal) {
        next[entry.key] = entry.value;
      } else {
        next[entry.key] = entry.value.copyWith(
          status: _statusForMarket(market, entry.value),
        );
      }
    }
    return next;
  }

  PickPositionStatus _openStatusFor(PickMarket market) =>
      switch (market.status) {
        PickMarketStatus.live => PickPositionStatus.live,
        PickMarketStatus.unresolved => PickPositionStatus.unresolved,
        PickMarketStatus.settled ||
        PickMarketStatus.voided => PickPositionStatus.settleable,
        _ => PickPositionStatus.pending,
      };

  PickPositionStatus _statusForMarket(
    PickMarket market,
    PickPosition position,
  ) {
    if (position.isFinal) return position.status;
    return switch (market.status) {
      PickMarketStatus.live => PickPositionStatus.live,
      PickMarketStatus.unresolved => PickPositionStatus.unresolved,
      PickMarketStatus.settled ||
      PickMarketStatus.voided => PickPositionStatus.settleable,
      PickMarketStatus.upcoming ||
      PickMarketStatus.closed => PickPositionStatus.pending,
    };
  }

  PickPosition _settledPosition(PickPosition position, PickMarket market) {
    final now = DateTime.now();
    if (market.status == PickMarketStatus.voided) {
      return position.copyWith(
        status: PickPositionStatus.voided,
        resolvedAt: now,
        payoutOz: position.stakeOz,
        resultNote: market.voidReason ?? market.resultNote ?? 'Stake refunded',
      );
    }
    final won = market.resolvedOutcomeId == position.outcomeId;
    return position.copyWith(
      status: won ? PickPositionStatus.won : PickPositionStatus.lost,
      resolvedAt: now,
      payoutOz: won ? position.maxPayoutOz : 0,
      resultNote: market.resultNote,
    );
  }

  String _settlementMessage(PickPosition position) {
    return switch (position.status) {
      PickPositionStatus.won => 'Won ${position.payoutOz} Oz',
      PickPositionStatus.lost => 'Pick lost',
      PickPositionStatus.voided => 'Stake refunded',
      _ => 'Result pending',
    };
  }

  void _applyDemoPositions(
    Map<String, PickPosition> positions,
    List<PickMarket> markets,
  ) {
    final now = DateTime.now();
    void add({
      required String marketId,
      required String outcomeId,
      required int stake,
      required PickPositionStatus status,
      int payout = 0,
      String? note,
      Duration age = const Duration(hours: 4),
    }) {
      final market = markets.firstWhere((m) => m.id == marketId);
      final outcome = market.outcomeFor(outcomeId)!;
      final shares = PickMath.sharesForStake(
        stakeOz: stake,
        probabilityPercent: outcome.probabilityPercent,
      );
      final position = PickPosition(
        id: 'demo_${marketId}_$outcomeId',
        marketId: market.id,
        marketQuestion: market.question,
        marketType: market.type,
        leagueLabel: market.leagueLabel,
        outcomeId: outcome.id,
        outcomeLabel: outcome.label,
        stakeOz: stake,
        shareCount: shares,
        averageProbabilityPercent: outcome.probabilityPercent.toDouble(),
        submittedAt: now.subtract(age),
        status: status,
        resolvedAt:
            status == PickPositionStatus.won ||
                status == PickPositionStatus.lost ||
                status == PickPositionStatus.voided
            ? now.subtract(const Duration(hours: 1))
            : null,
        payoutOz: payout,
        resultNote: note,
      );
      positions.putIfAbsent(position.id, () => position);
    }

    add(
      marketId: 'epl_liv_mc_winner',
      outcomeId: 'liv',
      stake: 76,
      status: PickPositionStatus.pending,
      age: const Duration(hours: 2),
    );
    add(
      marketId: 'ipl_pjk_rcb_winner',
      outcomeId: 'rcb',
      stake: 68,
      status: PickPositionStatus.live,
      age: const Duration(minutes: 36),
    );
    add(
      marketId: 'ipl_opener_50',
      outcomeId: 'no',
      stake: 76,
      status: PickPositionStatus.unresolved,
      age: const Duration(days: 1, hours: 3),
    );
    add(
      marketId: 'epl_mu_over_1_5',
      outcomeId: 'yes',
      stake: 64,
      status: PickPositionStatus.won,
      payout: 100,
      note: 'Man Utd scored 2',
      age: const Duration(days: 3, hours: 2),
    );
    add(
      marketId: 'epl_avl_bha_double_chance',
      outcomeId: 'bha_draw',
      stake: 88,
      status: PickPositionStatus.lost,
      payout: 0,
      note: 'Villa won 2-0',
      age: const Duration(days: 2, hours: 5),
    );
    add(
      marketId: 'ipl_rain_delay',
      outcomeId: 'yes',
      stake: 44,
      status: PickPositionStatus.voided,
      payout: 44,
      note: 'Stake refunded',
      age: const Duration(days: 1, hours: 6),
    );
  }

  String _positionId(String marketId, String outcomeId, DateTime time) =>
      '${marketId}_${outcomeId}_${time.microsecondsSinceEpoch}';
}
