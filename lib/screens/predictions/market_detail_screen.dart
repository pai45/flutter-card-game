import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/picks/picks_cubit.dart';
import '../../blocs/picks/picks_state.dart';
import '../../config/theme.dart';
import '../../models/picks.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../shop/shop_screen.dart' show CoinIcon;
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
              final position = state.positionForMarket(market.id);
              final selectedId =
                  _selectedOutcomeId ??
                  position?.outcomeId ??
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
                        _PositionPanel(
                          market: market,
                          position: position,
                          onSettle: position == null
                              ? null
                              : () => _settle(context, position),
                        ),
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
    final result = await context.read<PicksCubit>().settlePosition(position.id);
    if (!context.mounted) return;
    if (result.payoutOz > 0) {
      context.read<GameBloc>().add(CoinsAdded(result.payoutOz));
      playSound(SoundEffect.coins);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xff121b30),
        content: Text(result.message, style: Cyber.body(12)),
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
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xff10192d),
          border: Border.all(color: Cyber.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const HudLine(),
            Padding(
              padding: const EdgeInsets.all(14),
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
                  const SizedBox(height: 10),
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
          child: Text(label, style: Cyber.body(13, weight: FontWeight.w900)),
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
    final outcomes = [...widget.market.outcomes]
      ..sort((a, b) => b.probabilityPercent.compareTo(a.probabilityPercent));
    final topOutcomes = outcomes.take(3).toList();
    final history = _historyForRange(widget.market.priceHistory, widget.range);
    final series = [
      for (final outcome in topOutcomes)
        ChartSeries(
          label: outcome.label,
          color: outcome.color,
          values: _historyValuesFor(history, outcome.id).isEmpty
              ? [outcome.probabilityPercent]
              : _historyValuesFor(history, outcome.id),
        ),
    ];
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
                setState(() {
                  _selectedIndex = _indexForChartDx(
                    dx: position.dx,
                    width: constraints.maxWidth,
                    pointCount: pointCount,
                  );
                });
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
                  weight: FontWeight.w900,
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
    required this.onSelect,
    required this.onBuy,
  });

  final PickMarket market;
  final String selectedId;
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
    required this.canBuy,
    required this.onSelect,
    required this.onBuy,
  });

  final PickOutcome outcome;
  final bool selected;
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
                  Text(
                    outcome.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.body(13, weight: FontWeight.w900),
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

class _PositionPanel extends StatelessWidget {
  const _PositionPanel({
    required this.market,
    required this.position,
    required this.onSettle,
  });

  final PickMarket market;
  final PickPosition? position;
  final VoidCallback? onSettle;

  @override
  Widget build(BuildContext context) {
    if (position == null) {
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
    final statusColor = _positionColor(position!.status);
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
                _positionLabel(position!.status),
                style: Cyber.label(9, color: statusColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            position!.outcomeLabel,
            style: Cyber.display(16, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _TicketMetric(label: 'STAKE', value: '${position!.stakeOz} Oz'),
              const SizedBox(width: 8),
              _TicketMetric(label: 'SHARES', value: '${position!.shareCount}'),
              const SizedBox(width: 8),
              _TicketMetric(
                label: 'MAX PAYOUT',
                value: '${position!.maxPayoutOz} Oz',
              ),
            ],
          ),
          if (position!.canSettle) ...[
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
          ] else if (position!.isFinal) ...[
            const SizedBox(height: 10),
            Text(
              position!.status == PickPositionStatus.won
                  ? '+${position!.realizedProfit} Oz profit'
                  : position!.status == PickPositionStatus.voided
                  ? 'Stake refunded'
                  : '${position!.stakeOz} Oz spent',
              style: Cyber.body(
                12,
                color: statusColor,
                weight: FontWeight.w900,
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
        '${outcome.probabilityPercent} Oz and pays 100 Oz if correct.',
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
            Text(label, style: Cyber.label(7, color: Cyber.muted)),
            const SizedBox(height: 5),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.body(11, weight: FontWeight.w900),
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
          Text(label, style: Cyber.label(7, color: Cyber.muted)),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Cyber.body(
              12,
              weight: FontWeight.w900,
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
    final color = switch (type) {
      PickMarketType.match => Cyber.cyan,
      PickMarketType.event => Cyber.gold,
      PickMarketType.future => Cyber.violet,
    };
    final label = switch (type) {
      PickMarketType.match => 'MATCH',
      PickMarketType.event => 'EVENT',
      PickMarketType.future => 'FUTURE',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(label, style: Cyber.label(8, color: color)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final PickMarketStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _marketStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        _marketStatusLabel(status),
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

    for (final item in series) {
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
    if (selectedX + 42 < size.width) {
      canvas.drawLine(
        center + const Offset(13, 0),
        center + const Offset(42, 0),
        Paint()
          ..color = markerSeries.color
          ..strokeWidth = 3,
      );
    }
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

String _marketStatusLabel(PickMarketStatus status) => switch (status) {
  PickMarketStatus.upcoming => 'OPEN',
  PickMarketStatus.live => 'LIVE',
  PickMarketStatus.closed => 'CLOSED',
  PickMarketStatus.unresolved => 'UNRESOLVED',
  PickMarketStatus.settled => 'SETTLED',
  PickMarketStatus.voided => 'VOID',
};

Color _marketStatusColor(PickMarketStatus status) => switch (status) {
  PickMarketStatus.upcoming => Cyber.gold,
  PickMarketStatus.live => Cyber.red,
  PickMarketStatus.closed => Cyber.muted,
  PickMarketStatus.unresolved => Cyber.amber,
  PickMarketStatus.settled => Cyber.success,
  PickMarketStatus.voided => Cyber.muted,
};

String _positionLabel(PickPositionStatus status) => switch (status) {
  PickPositionStatus.pending => 'PENDING',
  PickPositionStatus.live => 'LIVE',
  PickPositionStatus.unresolved => 'UNRESOLVED',
  PickPositionStatus.settleable => 'CLAIM',
  PickPositionStatus.won => 'WON',
  PickPositionStatus.lost => 'LOST',
  PickPositionStatus.voided => 'REFUNDED',
};

Color _positionColor(PickPositionStatus status) => switch (status) {
  PickPositionStatus.pending => Cyber.cyan,
  PickPositionStatus.live => Cyber.red,
  PickPositionStatus.unresolved => Cyber.amber,
  PickPositionStatus.settleable => Cyber.gold,
  PickPositionStatus.won => Cyber.success,
  PickPositionStatus.lost => Cyber.red,
  PickPositionStatus.voided => Cyber.muted,
};
