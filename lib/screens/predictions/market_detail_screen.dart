import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../shop/shop_screen.dart' show CoinIcon;
import 'widgets/pick_settlement_reveal.dart';
import 'widgets/pick_status_style.dart';
import 'widgets/pick_trade_sheet.dart';
import 'widgets/standings_table.dart' show DetailTopBar;

class MarketDetailScreen extends StatefulWidget {
  const MarketDetailScreen({required this.marketId, super.key});

  final String marketId;

  @override
  State<MarketDetailScreen> createState() => _MarketDetailScreenState();
}

class _MarketDetailScreenState extends State<MarketDetailScreen> {
  String? _selectedOutcomeId;
  _ChartRange _chartRange = _ChartRange.all;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: CyberPlainBackground(
        child: SafeArea(
          child: BlocBuilder<PicksCubit, PicksState>(
            builder: (context, state) {
              final market = state.marketFor(widget.marketId);
              if (market == null) {
                return const _MissingMarket();
              }
              final positions = state.positionsForMarket(market.id);
              final heldIds = positions.map((p) => p.outcomeId).toSet();
              final selectedId =
                  _selectedOutcomeId ??
                  positions.firstOrNull?.outcomeId ??
                  market.outcomes.first.id;
              final selected =
                  market.outcomeFor(selectedId) ?? market.outcomes.first;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DetailTopBar(title: 'MARKET'),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                      children: [
                        _MarketHeader(market: market),
                        const SizedBox(height: 14),
                        _OddsChart(
                          market: market,
                          range: _chartRange,
                          onRangeChanged: (range) {
                            setState(() => _chartRange = range);
                          },
                        ),
                        const SizedBox(height: 14),
                        _OutcomeList(
                          market: market,
                          selectedId: selected.id,
                          heldIds: heldIds,
                          onSelect: (outcome) {
                            setState(() => _selectedOutcomeId = outcome.id);
                          },
                          onBuy: (outcome) => showPickTradeSheet(
                            context: context,
                            market: market,
                            outcome: outcome,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (positions.isEmpty)
                          _NoPositionPanel(market: market)
                        else
                          for (var i = 0; i < positions.length; i++) ...[
                            if (i > 0) const SizedBox(height: 10),
                            _PositionPanel(
                              market: market,
                              position: positions[i],
                              onSettle: () => _settle(context, positions[i]),
                            ),
                          ],
                        const SizedBox(height: 14),
                        _RulesPanel(outcome: selected),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
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

class _MarketHeader extends StatelessWidget {
  const _MarketHeader({required this.market});

  final PickMarket market;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const HudChamferClipper(bigCut: 16, smallCut: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _TypePill(type: market.type),
                    const SizedBox(width: 8),
                    _StatusPill(status: market.status),
                    const Spacer(),
                    Text(
                      market.leagueLabel,
                      style: Cyber.label(10, color: Cyber.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  market.question,
                  style: Cyber.display(18, letterSpacing: 0.5),
                ),
                const SizedBox(height: 12),
                _LeadingProbability(market: market),
                const SizedBox(height: 12),
                if (market.homeLabel != null && market.awayLabel != null)
                  _ScoreContext(market: market)
                else
                  Text(
                    [
                      market.contextTitle,
                      market.contextSubtitle,
                    ].whereType<String>().join(' · '),
                    style: Cyber.body(
                      12,
                      color: Cyber.muted,
                      weight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _MiniMetric(
                      label: 'VOLUME',
                      value: '${market.volumeOz} Oz',
                    ),
                    const SizedBox(width: 10),
                    _MiniMetric(
                      label: 'CLOSES',
                      value: _timeLabel(market.closesAt),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The Polymarket signature: the leading outcome's probability as the hero
/// number, with its movement since the last price point.
class _LeadingProbability extends StatelessWidget {
  const _LeadingProbability({required this.market});

  final PickMarket market;

  @override
  Widget build(BuildContext context) {
    final leading = market.leadingOutcome;
    final delta = market.latestDeltaFor(leading.id);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '${leading.probabilityPercent}%',
          style: Cyber.display(
            34,
            color: leading.color,
            letterSpacing: 0,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                leading.label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Cyber.label(10, color: Colors.white, letterSpacing: 1),
              ),
              const SizedBox(height: 4),
              Text(
                'CHANCE',
                style: Cyber.label(
                  8,
                  color: Cyber.muted.withValues(alpha: 0.8),
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
        if (delta != null && delta != 0) _DeltaChip(delta: delta),
      ],
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.delta});

  final int delta;

  @override
  Widget build(BuildContext context) {
    final up = delta > 0;
    final color = up ? Cyber.lime : Cyber.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        '${up ? '▲' : '▼'}${delta.abs()} TODAY',
        style: Cyber.label(
          8,
          color: color,
          letterSpacing: 0.8,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _ScoreContext extends StatelessWidget {
  const _ScoreContext({required this.market});

  final PickMarket market;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Cyber.bg.withValues(alpha: 0.45),
        border: Border.all(color: Cyber.border),
      ),
      child: Column(
        children: [
          _ScoreRow(label: market.homeLabel!, score: market.homeScore),
          const SizedBox(height: 7),
          _ScoreRow(label: market.awayLabel!, score: market.awayScore),
          if (market.contextSubtitle != null) ...[
            const SizedBox(height: 9),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                market.contextSubtitle!,
                style: Cyber.body(
                  11,
                  color: Cyber.muted,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.label, required this.score});

  final String label;
  final String? score;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Cyber.body(13, weight: FontWeight.w700)),
        ),
        Text(
          score ?? '-',
          style: Cyber.label(
            12,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

enum _ChartRange { all, week, day }

class _OddsChart extends StatefulWidget {
  const _OddsChart({
    required this.market,
    required this.range,
    required this.onRangeChanged,
  });

  final PickMarket market;
  final _ChartRange range;
  final ValueChanged<_ChartRange> onRangeChanged;

  @override
  State<_OddsChart> createState() => _OddsChartState();
}

class _OddsChartState extends State<_OddsChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final history = _historyForRange(widget.market.priceHistory, widget.range);
    final series = _chartSeriesFor(widget.market, widget.range, limit: 3);
    final pointCount = _chartPointCount(series);
    final selectedIndex = _selectedChartIndex(_selectedIndex, pointCount);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xff10192d),
        border: Border.all(color: Cyber.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'MARKET ODDS',
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.label(10, color: Cyber.cyan),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Expand odds chart',
                onPressed: () => _openExpandedOdds(context),
                icon: const Icon(
                  Icons.open_in_full,
                  color: Cyber.cyan,
                  size: 16,
                ),
              ),
              Text(
                '${history.length} BETS',
                style: Cyber.label(9, color: Cyber.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ChartRangeTabs(
            active: widget.range,
            onChanged: (range) {
              setState(() => _selectedIndex = null);
              widget.onRangeChanged(range);
            },
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              void selectAt(Offset position) {
                final index = _indexForChartDx(
                  dx: position.dx,
                  width: constraints.maxWidth,
                  pointCount: pointCount,
                );
                if (index == _selectedIndex) return;
                HapticFeedback.selectionClick();
                setState(() => _selectedIndex = index);
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => selectAt(details.localPosition),
                onHorizontalDragUpdate: (details) =>
                    selectAt(details.localPosition),
                child: SizedBox(
                  key: const ValueKey('pick_odds_chart'),
                  height: 132,
                  child: CustomPaint(
                    painter: _OddsChartPainter(
                      series: series,
                      selectedIndex: selectedIndex,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _SelectedChartValues(series: series, selectedIndex: selectedIndex),
        ],
      ),
    );
  }

  void _openExpandedOdds(BuildContext context) {
    playSound(SoundEffect.uiTap);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ExpandedOddsChartScreen(
          market: widget.market,
          initialRange: widget.range,
        ),
      ),
    );
  }
}

class _ExpandedOddsChartScreen extends StatefulWidget {
  const _ExpandedOddsChartScreen({
    required this.market,
    required this.initialRange,
  });

  final PickMarket market;
  final _ChartRange initialRange;

  @override
  State<_ExpandedOddsChartScreen> createState() =>
      _ExpandedOddsChartScreenState();
}

class _ExpandedOddsChartScreenState extends State<_ExpandedOddsChartScreen> {
  late _ChartRange _range = widget.initialRange;
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final history = _historyForRange(widget.market.priceHistory, _range);
    final series = _chartSeriesFor(widget.market, _range);
    final pointCount = _chartPointCount(series);
    final selectedIndex = _selectedChartIndex(_selectedIndex, pointCount);

    return Scaffold(
      backgroundColor: Cyber.bg,
      body: CyberPlainBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                    Expanded(
                      child: Text(
                        'MARKET ODDS',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Cyber.display(16, letterSpacing: 1),
                      ),
                    ),
                    Text(
                      '${history.length} BETS',
                      style: Cyber.label(9, color: Cyber.muted),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ChartRangeTabs(
                  active: _range,
                  onChanged: (range) {
                    setState(() {
                      _range = range;
                      _selectedIndex = null;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      void selectAt(Offset position) {
                        final index = _indexForChartDx(
                          dx: position.dx,
                          width: constraints.maxWidth,
                          pointCount: pointCount,
                        );
                        if (index == _selectedIndex) return;
                        HapticFeedback.selectionClick();
                        setState(() => _selectedIndex = index);
                      }

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) => selectAt(details.localPosition),
                        onHorizontalDragUpdate: (details) =>
                            selectAt(details.localPosition),
                        child: CustomPaint(
                          painter: _OddsChartPainter(
                            series: series,
                            selectedIndex: selectedIndex,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                child: _SelectedChartValues(
                  series: series,
                  selectedIndex: selectedIndex,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartRangeTabs extends StatelessWidget {
  const _ChartRangeTabs({required this.active, required this.onChanged});

  final _ChartRange active;
  final ValueChanged<_ChartRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final range in _ChartRange.values) ...[
          Expanded(
            child: _ChartRangeButton(
              label: _chartRangeLabel(range),
              active: range == active,
              onTap: () => onChanged(range),
            ),
          ),
          if (range != _ChartRange.values.last) const SizedBox(width: 7),
        ],
      ],
    );
  }
}

class _ChartRangeButton extends StatelessWidget {
  const _ChartRangeButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? Cyber.cyan.withValues(alpha: 0.14)
              : Cyber.bg.withValues(alpha: 0.34),
          border: Border.all(
            color: active ? Cyber.cyan : Cyber.border.withValues(alpha: 0.75),
          ),
        ),
        child: Text(
          label,
          style: Cyber.label(9, color: active ? Cyber.cyan : Cyber.muted),
        ),
      ),
    );
  }
}

class _SelectedChartValues extends StatelessWidget {
  const _SelectedChartValues({
    required this.series,
    required this.selectedIndex,
  });

  final List<ChartSeries> series;
  final int? selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 7,
      children: [
        for (final item in series)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 14, height: 3, color: item.color),
              const SizedBox(width: 6),
              Text(
                '${item.label} ${_seriesValueAt(item, selectedIndex)}%',
                style: Cyber.body(
                  10,
                  color: item.color,
                  weight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _OutcomeList extends StatelessWidget {
  const _OutcomeList({
    required this.market,
    required this.selectedId,
    required this.heldIds,
    required this.onSelect,
    required this.onBuy,
  });

  final PickMarket market;
  final String selectedId;
  final Set<String> heldIds;
  final ValueChanged<PickOutcome> onSelect;
  final ValueChanged<PickOutcome> onBuy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeading(label: 'OUTCOMES'),
        const SizedBox(height: 10),
        for (final outcome in market.outcomes) ...[
          _OutcomeRow(
            outcome: outcome,
            selected: outcome.id == selectedId,
            held: heldIds.contains(outcome.id),
            canBuy: market.canBuy,
            onSelect: () => onSelect(outcome),
            onBuy: () => onBuy(outcome),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _OutcomeRow extends StatelessWidget {
  const _OutcomeRow({
    required this.outcome,
    required this.selected,
    required this.held,
    required this.canBuy,
    required this.onSelect,
    required this.onBuy,
  });

  final PickOutcome outcome;
  final bool selected;
  final bool held;
  final bool canBuy;
  final VoidCallback onSelect;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? outcome.color.withValues(alpha: 0.12)
              : const Color(0xff10192d),
          border: Border.all(color: selected ? outcome.color : Cyber.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          outcome.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Cyber.body(13, weight: FontWeight.w700),
                        ),
                      ),
                      if (held) ...[
                        const SizedBox(width: 7),
                        const Icon(
                          Icons.check_rounded,
                          color: Cyber.cyan,
                          size: 13,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'BACKED',
                          style: Cyber.label(
                            8,
                            color: Cyber.cyan,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  CyberProgressBar(
                    value: outcome.probabilityPercent / 100,
                    accent: outcome.color,
                    height: 6,
                    animate: false,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${outcome.probabilityPercent}%',
              style: Cyber.display(
                18,
                color: outcome.color,
                letterSpacing: 0,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 78,
              height: 38,
              child: FilledButton(
                onPressed: canBuy ? onBuy : null,
                style: FilledButton.styleFrom(
                  backgroundColor: canBuy ? outcome.color : Cyber.panel,
                  foregroundColor: outcome.color.computeLuminance() > 0.55
                      ? Cyber.bg
                      : Colors.white,
                  disabledBackgroundColor: Cyber.panel,
                  disabledForegroundColor: Cyber.muted,
                  padding: EdgeInsets.zero,
                  shape: const BeveledRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
                child: Text(
                  canBuy ? 'BUY' : 'LOCKED',
                  style: Cyber.label(
                    canBuy ? 10 : 8,
                    color: outcome.color.computeLuminance() > 0.55
                        ? Cyber.bg
                        : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the player holds no ticket on this market yet.
class _NoPositionPanel extends StatelessWidget {
  const _NoPositionPanel({required this.market});

  final PickMarket market;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xff10192d),
        border: Border.all(color: Cyber.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.confirmation_number_outlined, color: Cyber.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              market.canBuy
                  ? 'Pick an outcome to create your ticket.'
                  : 'Market is closed with no ticket held.',
              style: Cyber.body(12, color: Cyber.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionPanel extends StatelessWidget {
  const _PositionPanel({
    required this.market,
    required this.position,
    required this.onSettle,
  });

  final PickMarket market;
  final PickPosition position;
  final VoidCallback? onSettle;

  @override
  Widget build(BuildContext context) {
    final statusColor = pickPositionColor(position.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xff10192d),
        border: Border.all(color: statusColor.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('YOUR TICKET', style: Cyber.label(11, color: statusColor)),
              const Spacer(),
              Text(
                pickPositionLabel(position.status),
                style: Cyber.label(9, color: statusColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            position.outcomeLabel,
            style: Cyber.display(16, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _TicketMetric(label: 'STAKE', value: '${position.stakeOz} Oz'),
              const SizedBox(width: 8),
              _TicketMetric(label: 'SHARES', value: '${position.shareCount}'),
              const SizedBox(width: 8),
              _TicketMetric(
                label: 'MAX PAYOUT',
                value: '${position.maxPayoutOz} Oz',
              ),
            ],
          ),
          if (position.canSettle) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onSettle,
              icon: const CoinIcon(size: 16),
              label: Text(
                market.status == PickMarketStatus.voided
                    ? 'CLAIM REFUND'
                    : 'REVEAL RESULT',
              ),
            ),
          ] else if (position.isFinal) ...[
            const SizedBox(height: 10),
            Text(
              position.status == PickPositionStatus.won
                  ? '+${position.realizedProfit} Oz profit'
                  : position.status == PickPositionStatus.voided
                  ? 'Stake refunded'
                  : '${position.stakeOz} Oz spent',
              style: Cyber.body(
                12,
                color: statusColor,
                weight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RulesPanel extends StatelessWidget {
  const _RulesPanel({required this.outcome});

  final PickOutcome outcome;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Cyber.bg.withValues(alpha: 0.45),
        border: Border.all(color: Cyber.border),
      ),
      child: Text(
        'At ${outcome.probabilityPercent}%, every share costs '
        '${outcome.probabilityPercent} Oz and pays 100 Oz '
        '(${(100 / outcome.probabilityPercent).toStringAsFixed(1)}×) '
        'if correct.',
        style: Cyber.body(12, color: Cyber.muted, weight: FontWeight.w700),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 45,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: Cyber.bg.withValues(alpha: 0.42),
          border: Border.all(color: Cyber.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Cyber.label(8, color: Cyber.muted)),
            const SizedBox(height: 5),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.body(11, weight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketMetric extends StatelessWidget {
  const _TicketMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Cyber.label(8, color: Cyber.muted)),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Cyber.body(
              12,
              weight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SectionLabel(label: label),
        const SizedBox(width: 10),
        Expanded(
          child: Container(height: 1, color: Cyber.line.withValues(alpha: 0.3)),
        ),
      ],
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.type});

  final PickMarketType type;

  @override
  Widget build(BuildContext context) {
    final color = pickMarketTypeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        pickMarketTypeLabel(type),
        style: Cyber.label(8, color: color),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final PickMarketStatus status;

  @override
  Widget build(BuildContext context) {
    final color = pickMarketStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        pickMarketStatusLabel(status),
        style: Cyber.label(8, color: color),
      ),
    );
  }
}

class ChartSeries {
  const ChartSeries({
    required this.label,
    required this.color,
    required this.values,
  });

  final String label;
  final Color color;
  final List<int> values;
}

class _OddsChartPainter extends CustomPainter {
  const _OddsChartPainter({required this.series, required this.selectedIndex});

  final List<ChartSeries> series;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final grid = Paint()
      ..color = Cyber.border.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = size.height * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    if (series.isEmpty) return;
    final values = [for (final item in series) ...item.values];
    final minValue = math.max(0, values.reduce((a, b) => a < b ? a : b) - 8);
    final maxValue = math.min(100, values.reduce((a, b) => a > b ? a : b) + 8);
    final spread = math.max(1, maxValue - minValue);
    final pointCount = _chartPointCount(series);

    for (var s = 0; s < series.length; s++) {
      final item = series[s];
      final points = <Offset>[];
      for (var i = 0; i < item.values.length; i++) {
        final x = item.values.length == 1
            ? size.width
            : size.width * i / (item.values.length - 1);
        final normalized = (item.values[i] - minValue) / spread;
        final y = size.height - normalized * size.height;
        points.add(Offset(x, y));
      }
      if (points.isEmpty) continue;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        final previous = points[i - 1];
        final point = points[i];
        path.lineTo(point.dx, previous.dy);
        path.lineTo(point.dx, point.dy);
      }
      // Gradient fill under the leading series only — one focal series.
      if (s == 0 && points.length > 1) {
        final fill = Path.from(path)
          ..lineTo(points.last.dx, size.height)
          ..lineTo(points.first.dx, size.height)
          ..close();
        canvas.drawPath(
          fill,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                item.color.withValues(alpha: 0.18),
                item.color.withValues(alpha: 0.0),
              ],
            ).createShader(Offset.zero & size),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = item.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
    }

    final index = _selectedChartIndex(selectedIndex, pointCount);
    if (index == null) return;

    final selectedX = pointCount <= 1
        ? size.width
        : size.width * index / (pointCount - 1);
    _drawDashedLine(
      canvas,
      Offset(selectedX, 0),
      Offset(selectedX, size.height),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.square,
    );

    final markerSeries = series.isEmpty ? null : series.first;
    if (markerSeries == null || markerSeries.values.isEmpty) return;
    final markerValue = _seriesValueAt(markerSeries, index);
    final markerY =
        size.height - ((markerValue - minValue) / spread) * size.height;
    final center = Offset(selectedX, markerY);
    canvas.drawCircle(
      center,
      12,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawCircle(
      center,
      7,
      Paint()
        ..color = markerSeries.color.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      4,
      Paint()
        ..color = markerSeries.color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _OddsChartPainter old) =>
      old.series != series || old.selectedIndex != selectedIndex;
}

class _MissingMarket extends StatelessWidget {
  const _MissingMarket();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const DetailTopBar(title: 'MARKET'),
        Expanded(
          child: Center(
            child: Text(
              'Market unavailable.',
              style: Cyber.body(13, color: Cyber.muted),
            ),
          ),
        ),
      ],
    );
  }
}

List<PickPricePoint> _historyForRange(
  List<PickPricePoint> history,
  _ChartRange range,
) {
  if (history.isEmpty || range == _ChartRange.all) return history;
  final anchor = history.last.at;
  final cutoff = anchor.subtract(
    range == _ChartRange.week
        ? const Duration(days: 7)
        : const Duration(days: 1),
  );
  final filtered = [
    for (final point in history)
      if (!point.at.isBefore(cutoff)) point,
  ];
  if (filtered.length >= 2) return filtered;
  if (history.length <= 2) return history;
  return history.sublist(history.length - 2);
}

List<ChartSeries> _chartSeriesFor(
  PickMarket market,
  _ChartRange range, {
  int? limit,
}) {
  final outcomes = [...market.outcomes]
    ..sort((a, b) => b.probabilityPercent.compareTo(a.probabilityPercent));
  final selectedOutcomes = limit == null ? outcomes : outcomes.take(limit);
  final history = _historyForRange(market.priceHistory, range);
  return [
    for (final outcome in selectedOutcomes)
      ChartSeries(
        label: outcome.label,
        color: outcome.color,
        values: _historyValuesFor(history, outcome.id).isEmpty
            ? [outcome.probabilityPercent]
            : _historyValuesFor(history, outcome.id),
      ),
  ];
}

List<int> _historyValuesFor(List<PickPricePoint> history, String outcomeId) => [
  for (final point in history)
    if (point.percentFor(outcomeId) != null) point.percentFor(outcomeId)!,
];

String _chartRangeLabel(_ChartRange range) => switch (range) {
  _ChartRange.all => 'ALL',
  _ChartRange.week => 'WEEK',
  _ChartRange.day => 'DAY',
};

int _chartPointCount(List<ChartSeries> series) {
  var count = 0;
  for (final item in series) {
    if (item.values.length > count) count = item.values.length;
  }
  return count;
}

int? _selectedChartIndex(int? selectedIndex, int pointCount) {
  if (pointCount <= 0) return null;
  if (selectedIndex == null) return pointCount - 1;
  return selectedIndex.clamp(0, pointCount - 1);
}

int _indexForChartDx({
  required double dx,
  required double width,
  required int pointCount,
}) {
  if (pointCount <= 1 || width <= 0) return 0;
  final percent = (dx / width).clamp(0.0, 1.0);
  return (percent * (pointCount - 1)).round();
}

int _seriesValueAt(ChartSeries series, int? selectedIndex) {
  if (series.values.isEmpty) return 0;
  final index = selectedIndex ?? series.values.length - 1;
  return series.values[index.clamp(0, series.values.length - 1)];
}

void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
  const dash = 8.0;
  const gap = 6.0;
  final distance = (end - start).distance;
  if (distance <= 0) return;
  final direction = (end - start) / distance;
  var drawn = 0.0;
  while (drawn < distance) {
    final segmentEnd = math.min(drawn + dash, distance);
    canvas.drawLine(
      start + direction * drawn,
      start + direction * segmentEnd,
      paint,
    );
    drawn += dash + gap;
  }
}

String _timeLabel(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
