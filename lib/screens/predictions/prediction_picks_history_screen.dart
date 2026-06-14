import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/picks/picks_cubit.dart';
import '../../blocs/picks/picks_state.dart';
import '../../config/theme.dart';
import '../../models/oz_coin_ledger.dart';
import '../../models/picks.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/cyber/fixture_card.dart';
import '../shop/shop_screen.dart' show CoinIcon;
import 'market_detail_screen.dart';
import 'widgets/history_hud.dart';
import 'widgets/pick_settlement_reveal.dart';
import 'widgets/pick_status_style.dart';

void showPredictionPicksHistory(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const PredictionPicksHistoryScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class PredictionPicksHistoryScreen extends StatefulWidget {
  const PredictionPicksHistoryScreen({super.key});

  @override
  State<PredictionPicksHistoryScreen> createState() =>
      _PredictionPicksHistoryScreenState();
}

class _PredictionPicksHistoryScreenState
    extends State<PredictionPicksHistoryScreen> {
  _PicksFilter _filter = _PicksFilter.all;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: Stack(
        children: [
          const Positioned.fill(
            child: CyberPlainBackground(child: SizedBox.expand()),
          ),
          SafeArea(
            child: BlocBuilder<PicksCubit, PicksState>(
              builder: (context, state) {
                final positions = state.positionList;
                final counts = {
                  for (final filter in _PicksFilter.values)
                    filter: positions.where((p) => _matches(p, filter)).length,
                };
                final filtered = positions
                    .where((position) => _matches(position, _filter))
                    .toList();
                final net = state.realizedProfitOz;
                final profitColor = net > 0
                    ? Cyber.lime
                    : net < 0
                    ? Cyber.red
                    : Colors.white;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HistoryHeaderBar(
                      title: 'MY PICKS HISTORY',
                      accent: Cyber.success,
                      onBack: () => Navigator.pop(context),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: HistoryStatCell(
                              label: 'PICKS',
                              value: '${positions.length}',
                              accent: Cyber.success,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: HistoryStatCell(
                              label: 'EXPOSURE',
                              value: formatOzCompact(state.openExposureOz),
                              accent: Cyber.success,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: HistoryStatCell(
                              label: 'PROFIT',
                              value:
                                  '${net >= 0 ? '+' : '−'}'
                                  '${formatOzCompact(net.abs())}',
                              accent: Cyber.success,
                              valueColor: profitColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _PicksFilterBar(
                      active: _filter,
                      counts: counts,
                      onSelect: (filter) => setState(() => _filter = filter),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? _EmptyHistory(
                              hasAnyPicks: positions.isNotEmpty,
                              filterLabel: _filterLabel(_filter),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final position = filtered[index];
                                return _OzPickCard(
                                  position: position,
                                  market: state.marketFor(position.marketId),
                                  onTap: () =>
                                      _openMarket(context, position.marketId),
                                  onSettle: position.canSettle
                                      ? () => _settle(context, position)
                                      : null,
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _matches(PickPosition position, _PicksFilter filter) {
    return switch (filter) {
      _PicksFilter.all => true,
      _PicksFilter.won => position.status == PickPositionStatus.won,
      _PicksFilter.lost => position.status == PickPositionStatus.lost,
      _PicksFilter.live => position.status == PickPositionStatus.live,
      _PicksFilter.pending => position.status == PickPositionStatus.pending,
      _PicksFilter.unresolved =>
        position.status == PickPositionStatus.unresolved ||
            position.status == PickPositionStatus.settleable,
      _PicksFilter.voided => position.status == PickPositionStatus.voided,
    };
  }

  void _openMarket(BuildContext context, String marketId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MarketDetailScreen(marketId: marketId),
      ),
    );
  }

  Future<void> _settle(BuildContext context, PickPosition position) async {
    playSound(SoundEffect.uiTap);
    final picks = context.read<PicksCubit>();
    final result = await picks.settlePosition(position.id);
    if (!context.mounted) return;
    final settled = result.position;
    if (!result.settled || settled == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xff121b30),
          content: Text(result.message, style: Cyber.body(12)),
        ),
      );
      return;
    }
    if (result.payoutOz > 0) {
      context.read<GameBloc>().add(
        CoinsAdded(
          result.payoutOz,
          source: OzCoinTransactionSource.pickPayout,
          title: 'PICK PAYOUT',
          subtitle: settled.marketQuestion,
        ),
      );
    }
    await showPickSettlementReveal(
      context,
      PickSettlementRevealData.single(
        position: settled,
        winStreak: picks.state.winStreak,
      ),
    );
  }
}

enum _PicksFilter { all, won, lost, live, pending, unresolved, voided }

String _filterLabel(_PicksFilter filter) => switch (filter) {
  _PicksFilter.all => 'ALL',
  _PicksFilter.won => 'WON',
  _PicksFilter.lost => 'LOST',
  _PicksFilter.live => 'LIVE',
  _PicksFilter.pending => 'PENDING',
  _PicksFilter.unresolved => 'REVIEW',
  _PicksFilter.voided => 'REFUND',
};

class _PicksFilterBar extends StatelessWidget {
  const _PicksFilterBar({
    required this.active,
    required this.counts,
    required this.onSelect,
  });

  final _PicksFilter active;
  final Map<_PicksFilter, int> counts;
  final ValueChanged<_PicksFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final filter in _PicksFilter.values) ...[
            HistoryFilterChip(
              label: _filterLabel(filter),
              count: counts[filter] ?? 0,
              active: active == filter,
              accent: Cyber.success,
              onTap: () => onSelect(filter),
            ),
            if (filter != _PicksFilter.voided) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// Pick position card on the shared fixture silhouette: status tag in the
/// notch, league/type kicker + question, the held outcome + "to win" row, and a
/// state-specific bottom strip (focal CLAIM strip carries the settlement tap).
class _OzPickCard extends StatelessWidget {
  const _OzPickCard({
    required this.position,
    required this.market,
    required this.onTap,
    required this.onSettle,
  });

  final PickPosition position;
  final PickMarket? market;
  final VoidCallback onTap;
  final VoidCallback? onSettle;

  @override
  Widget build(BuildContext context) {
    return FixtureCardFrame(
      onTap: onTap,
      tag: _PickTag(position: position, market: market),
      body: _PickCardBody(position: position, market: market),
      bottomStrip: _PickHistoryStrip(
        position: position,
        market: market,
        onSettle: onSettle,
      ),
    );
  }
}

class _PickTag extends StatelessWidget {
  const _PickTag({required this.position, required this.market});

  final PickPosition position;
  final PickMarket? market;

  @override
  Widget build(BuildContext context) {
    switch (position.status) {
      case PickPositionStatus.pending:
        final m = market;
        if (m != null) {
          return FixtureTagText(
            text: 'CLOSES ${pickClosesLabel(m.closesAt)}',
            color: kFixtureTimeGold,
          );
        }
        return const FixtureTagText(text: 'PENDING', color: Cyber.gold);
      case PickPositionStatus.live:
        final live = market?.liveLabel;
        return FixtureLiveTag(
          label: live == null || live == 'LIVE' ? 'LIVE' : 'LIVE $live',
        );
      case PickPositionStatus.settleable:
        return const FixtureTagText(text: 'CLAIM', color: Cyber.gold);
      case PickPositionStatus.won:
      case PickPositionStatus.lost:
      case PickPositionStatus.voided:
      case PickPositionStatus.unresolved:
        return FixtureTagText(
          text: pickPositionLabel(position.status),
          color: pickPositionColor(position.status),
        );
    }
  }
}

class _PickCardBody extends StatelessWidget {
  const _PickCardBody({required this.position, required this.market});

  final PickPosition position;
  final PickMarket? market;

  @override
  Widget build(BuildContext context) {
    final context0 = _contextLine();
    final outcomeColor =
        market?.outcomeFor(position.outcomeId)?.color ??
        pickPositionColor(position.status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${position.leagueLabel} · ${pickMarketTypeLabel(position.marketType)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Cyber.label(
            8,
            color: Cyber.muted.withValues(alpha: 0.85),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          position.marketQuestion,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Cyber.body(15, weight: FontWeight.w700, height: 1.15),
        ),
        if (context0 != null) ...[
          const SizedBox(height: 4),
          Text(
            context0,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Cyber.body(
              11,
              color: const Color(0xff9fb0c2),
              weight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _HeldBadge(label: position.outcomeLabel, color: outcomeColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'YOUR PICK',
                    style: Cyber.label(
                      7,
                      color: Cyber.muted,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    position.outcomeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.body(12.5, weight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TO WIN',
                  style: Cyber.label(7, color: Cyber.muted, letterSpacing: 1.2),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CoinIcon(size: 12),
                    const SizedBox(width: 4),
                    Text(
                      '${position.stakeOz} → ${position.maxPayoutOz}',
                      style: Cyber.body(
                        12.5,
                        weight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// A muted scoreline shown only when the position is live and the market
  /// carries a score (logic mirrors the pick market card's context line).
  String? _contextLine() {
    if (position.status != PickPositionStatus.live) return null;
    final m = market;
    if (m == null) return null;
    if (m.homeLabel == null || m.awayLabel == null) return null;
    if (m.homeScore == null && m.awayScore == null) return null;
    return '${m.homeLabel} ${m.homeScore ?? '-'}'
        '  —  '
        '${m.awayScore ?? '-'} ${m.awayLabel}';
  }
}

/// The non-interactive held-outcome badge: an octagon fill carrying the short
/// outcome code, tinted to the outcome color.
class _HeldBadge extends StatelessWidget {
  const _HeldBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ink = color.computeLuminance() > 0.48 ? Colors.black : Colors.white;
    return SizedBox(
      width: 44,
      height: 36,
      child: CustomPaint(
        painter: FixtureBadgePainter(color: color),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 5),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                pickOutcomeCode(label),
                style: Cyber.label(11, color: ink, letterSpacing: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickHistoryStrip extends StatelessWidget {
  const _PickHistoryStrip({
    required this.position,
    required this.market,
    required this.onSettle,
  });

  final PickPosition position;
  final PickMarket? market;
  final VoidCallback? onSettle;

  @override
  Widget build(BuildContext context) {
    switch (position.status) {
      case PickPositionStatus.settleable:
        // Inner detector wins the gesture arena over the frame's outer tap.
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onSettle,
          child: FixtureCardStrip(
            fill: kFixtureStripGold,
            topBorder: Cyber.gold.withValues(alpha: 0.35),
            child: Row(
              children: [
                const Icon(Icons.redeem, color: Cyber.gold, size: 14),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'RESULT READY — TAP TO CLAIM',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.label(9, color: Cyber.gold, letterSpacing: 1)
                        .copyWith(
                          shadows: [
                            Shadow(
                              color: Cyber.gold.withValues(alpha: 0.45),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '+${position.maxPayoutOz} OZ',
                  style: Cyber.label(
                    9,
                    color: Cyber.gold,
                    letterSpacing: 0.8,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        );
      case PickPositionStatus.won:
        return FixtureCardStrip(
          topBorder: Cyber.success.withValues(alpha: 0.25),
          child: Row(
            children: [
              const Icon(Icons.trending_up, color: Cyber.success, size: 13),
              const SizedBox(width: 6),
              Text(
                '+${position.realizedProfit} OZ PROFIT',
                style: Cyber.body(
                  12,
                  color: Cyber.success,
                  weight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );
      case PickPositionStatus.lost:
        return FixtureCardStrip(
          topBorder: Cyber.red.withValues(alpha: 0.18),
          child: Text(
            '−${position.stakeOz} OZ',
            style: Cyber.body(
              12,
              color: Cyber.red.withValues(alpha: 0.9),
              weight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );
      case PickPositionStatus.voided:
        return FixtureCardStrip(
          child: Text(
            'REFUNDED ${position.stakeOz} OZ',
            style: Cyber.label(
              9,
              color: Cyber.muted,
              letterSpacing: 0.8,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );
      case PickPositionStatus.pending:
      case PickPositionStatus.live:
      case PickPositionStatus.unresolved:
        final m = market;
        return FixtureCardStrip(
          child: Row(
            children: [
              const Spacer(),
              Text(
                m == null ? 'OPEN' : 'VOL ${formatOzCompact(m.volumeOz)} OZ',
                style: Cyber.label(
                  8,
                  color: Cyber.muted.withValues(alpha: 0.7),
                  letterSpacing: 0.8,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.hasAnyPicks, required this.filterLabel});

  final bool hasAnyPicks;
  final String filterLabel;

  @override
  Widget build(BuildContext context) {
    return CyberNoDataState(
      icon: hasAnyPicks ? Icons.filter_alt_off : Icons.ads_click,
      title: hasAnyPicks ? 'No $filterLabel entries' : 'Be the 1st to pick',
      message: hasAnyPicks
          ? 'Switch filters to review the picks already on your board.'
          : 'No one has submitted a pick here yet. Make the first call.',
      accent: hasAnyPicks ? Cyber.success : Cyber.lime,
      spark: hasAnyPicks ? Icons.tune : Icons.flash_on,
    );
  }
}
