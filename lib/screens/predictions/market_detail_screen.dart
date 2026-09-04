import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/picks/picks_cubit.dart';
import '../../blocs/picks/picks_state.dart';
import '../../blocs/prediction/prediction_cubit.dart';
import '../../blocs/prediction/prediction_state.dart';
import '../../config/theme.dart';
import '../../models/oz_coin_ledger.dart';
import '../../models/picks.dart';
import '../../models/sport_match.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_chart.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../shop/shop_screen.dart' show CoinIcon;
import 'match_detail_screen.dart';
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
  String _chartRange = _marketRanges.first;

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
                        _MarketOddsChart(
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
                        _LinkedPredictionQuizCta(market: market),
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
                    CyberStatPill(
                      label: pickMarketTypeLabel(market.type),
                      color: pickMarketTypeColor(market.type),
                    ),
                    const SizedBox(width: 8),
                    CyberStatPill(
                      label: pickMarketStatusLabel(market.status),
                      color: pickMarketStatusColor(market.status),
                    ),
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
                    CyberMiniMetric(
                      label: 'VOLUME',
                      value: '${market.volumeOz} Oz',
                    ),
                    const SizedBox(width: 10),
                    CyberMiniMetric(
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

class _LinkedPredictionQuizCta extends StatelessWidget {
  const _LinkedPredictionQuizCta({required this.market});

  final PickMarket market;

  @override
  Widget build(BuildContext context) {
    final matchId = market.matchId;
    if (matchId == null) {
      return const SizedBox.shrink();
    }
    final PredictionCubit prediction;
    try {
      prediction = context.read<PredictionCubit>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }

    return BlocBuilder<PredictionCubit, PredictionState>(
      bloc: prediction,
      builder: (context, state) {
        final match =
            _matchById(state.fixtures, matchId) ?? _matchFromMarket(market);
        if (match == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: CyberCtaButton(
            key: const ValueKey('same_match_prediction_quiz_cta'),
            label: 'PREDICTION QUIZ',
            primary: true,
            onPressed: () {
              playSound(SoundEffect.playMatch);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => MatchDetailScreen(match: match),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

SportMatch? _matchById(List<SportMatch> fixtures, String matchId) {
  for (final match in fixtures) {
    if (match.id == matchId) return match;
  }
  return null;
}

SportMatch? _matchFromMarket(PickMarket market) {
  final matchId = market.matchId;
  final homeLabel = market.homeLabel;
  final awayLabel = market.awayLabel;
  if (matchId == null || homeLabel == null || awayLabel == null) return null;
  final homeOutcome = market.outcomes
      .where((outcome) => outcome.label == homeLabel)
      .firstOrNull;
  final awayOutcome = market.outcomes
      .where((outcome) => outcome.label == awayLabel)
      .firstOrNull;
  return SportMatch(
    id: matchId,
    leagueId: market.leagueId,
    sport: market.sport,
    home: SportTeam(
      id: homeOutcome?.id ?? 'home',
      name: homeLabel,
      shortName: _teamShortName(homeLabel),
      color: homeOutcome?.color ?? Cyber.cyan,
    ),
    away: SportTeam(
      id: awayOutcome?.id ?? 'away',
      name: awayLabel,
      shortName: _teamShortName(awayLabel),
      color: awayOutcome?.color ?? Cyber.amber,
    ),
    kickoff: market.closesAt,
    status: switch (market.status) {
      PickMarketStatus.live => MatchStatus.live,
      PickMarketStatus.settled ||
      PickMarketStatus.voided => MatchStatus.finished,
      _ => MatchStatus.upcoming,
    },
    homeScore: market.homeScore,
    awayScore: market.awayScore,
  );
}

String _teamShortName(String label) {
  final letters = label
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0])
      .join()
      .toUpperCase();
  if (letters.length >= 2) {
    return letters.substring(0, math.min(letters.length, 4));
  }
  if (label.isEmpty) return 'TBD';
  return label.substring(0, math.min(label.length, 3)).toUpperCase();
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
        if (delta != null && delta != 0)
          CyberDeltaChip(delta: delta.toDouble(), suffix: 'TODAY'),
      ],
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

const List<String> _marketRanges = ['ALL', 'WEEK', 'DAY'];

/// Market odds on the shared chart system. Prices are stepped: an outcome holds
/// its price until the next trade lands.
class _MarketOddsChart extends StatelessWidget {
  const _MarketOddsChart({
    required this.market,
    required this.range,
    required this.onRangeChanged,
  });

  final PickMarket market;
  final String range;
  final ValueChanged<String> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    final history = _historyForRange(market.priceHistory, range);
    return CyberChartPanel(
      chartKey: const ValueKey('pick_odds_chart'),
      title: 'MARKET ODDS',
      caption: '${history.length} BETS',
      height: 132,
      stepped: true,
      percentScale: true,
      series: _chartSeriesFor(market, range, limit: 3),
      ranges: _marketRanges,
      activeRange: range,
      onRangeChanged: onRangeChanged,
      markerSound: false,
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
        const CyberSectionHeading(label: 'OUTCOMES'),
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
              : Cyber.chartSurface,
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
        color: Cyber.chartSurface,
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
        color: Cyber.chartSurface,
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
          Text(label, style: Cyber.label(9, color: Cyber.muted)),
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
  String range,
) {
  if (history.isEmpty || range == 'ALL') return history;
  final anchor = history.last.at;
  final cutoff = anchor.subtract(
    range == 'WEEK' ? const Duration(days: 7) : const Duration(days: 1),
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
  String range, {
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
        fill: outcome.id == outcomes.first.id,
        readout: (value, _) => '${value.round()}%',
        values: _historyValuesFor(history, outcome.id).isEmpty
            ? [outcome.probabilityPercent.toDouble()]
            : _historyValuesFor(history, outcome.id),
      ),
  ];
}

List<double> _historyValuesFor(
  List<PickPricePoint> history,
  String outcomeId,
) => [
  for (final point in history)
    if (point.percentFor(outcomeId) != null)
      point.percentFor(outcomeId)!.toDouble(),
];

String _timeLabel(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
