import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_state.dart';
import '../../config/theme.dart';
import '../../models/oz_coin_ledger.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../predictions/widgets/history_hud.dart';
import '../predictions/widgets/pick_status_style.dart'
    show formatOzCompact, formatOzGrouped;

void showOzCoinHistory(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const OzCoinHistoryScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class OzCoinHistoryScreen extends StatefulWidget {
  const OzCoinHistoryScreen({super.key});

  @override
  State<OzCoinHistoryScreen> createState() => _OzCoinHistoryScreenState();
}

class _OzCoinHistoryScreenState extends State<OzCoinHistoryScreen> {
  _CoinHistoryFilter _filter = _CoinHistoryFilter.all;

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
            child: BlocBuilder<GameBloc, GameState>(
              builder: (context, state) {
                final ledger = [...state.coinLedger]
                  ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
                final counts = {
                  for (final filter in _CoinHistoryFilter.values)
                    filter: ledger
                        .where((entry) => _matches(entry, filter))
                        .length,
                };
                final filtered = ledger
                    .where((entry) => _matches(entry, _filter))
                    .toList();
                final earned = _earned(ledger);
                final spent = _spent(ledger);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HistoryHeaderBar(
                      title: 'OZ COIN HISTORY',
                      accent: Cyber.gold,
                      onBack: () => Navigator.pop(context),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: HistoryStatCell(
                              label: 'BALANCE',
                              value: formatOzCompact(state.coins),
                              accent: Cyber.gold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: HistoryStatCell(
                              label: 'EARNED',
                              value: formatOzCompact(earned),
                              accent: Cyber.gold,
                              valueColor: earned > 0 ? Cyber.success : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: HistoryStatCell(
                              label: 'SPENT',
                              value: formatOzCompact(spent),
                              accent: Cyber.gold,
                              valueColor: spent > 0 ? Cyber.red : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _CoinHistoryFilterBar(
                      active: _filter,
                      counts: counts,
                      onSelect: (filter) => setState(() => _filter = filter),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? _EmptyCoinHistory(hasAny: ledger.isNotEmpty)
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) =>
                                  _CoinHistoryTile(entry: filtered[index]),
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

  bool _matches(OzCoinLedgerEntry entry, _CoinHistoryFilter filter) {
    return switch (filter) {
      _CoinHistoryFilter.all => true,
      _CoinHistoryFilter.earned => entry.delta > 0,
      _CoinHistoryFilter.spent => entry.delta < 0,
      _CoinHistoryFilter.picks =>
        entry.source == OzCoinTransactionSource.pickStake ||
            entry.source == OzCoinTransactionSource.pickPayout,
      _CoinHistoryFilter.shop =>
        entry.source == OzCoinTransactionSource.packPurchase ||
            entry.source == OzCoinTransactionSource.directCardPurchase ||
            entry.source == OzCoinTransactionSource.duplicateRefund ||
            entry.source == OzCoinTransactionSource.shopTopUp,
      _CoinHistoryFilter.games =>
        entry.source == OzCoinTransactionSource.matchReward ||
            entry.source == OzCoinTransactionSource.shootoutReward ||
            entry.source == OzCoinTransactionSource.quizEntry ||
            entry.source == OzCoinTransactionSource.quizContestPayout ||
            entry.source == OzCoinTransactionSource.footballBingoLifeline ||
            entry.source == OzCoinTransactionSource.guessPlayerHint ||
            entry.source == OzCoinTransactionSource.guessPlayerExtraAttempt,
    };
  }
}

enum _CoinHistoryFilter { all, earned, spent, picks, shop, games }

String _filterLabel(_CoinHistoryFilter filter) => switch (filter) {
  _CoinHistoryFilter.all => 'ALL',
  _CoinHistoryFilter.earned => 'EARNED',
  _CoinHistoryFilter.spent => 'SPENT',
  _CoinHistoryFilter.picks => 'PICKS',
  _CoinHistoryFilter.shop => 'SHOP',
  _CoinHistoryFilter.games => 'GAMES',
};

class _CoinHistoryFilterBar extends StatelessWidget {
  const _CoinHistoryFilterBar({
    required this.active,
    required this.counts,
    required this.onSelect,
  });

  final _CoinHistoryFilter active;
  final Map<_CoinHistoryFilter, int> counts;
  final ValueChanged<_CoinHistoryFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final filter in _CoinHistoryFilter.values) ...[
            HistoryFilterChip(
              label: _filterLabel(filter),
              count: counts[filter] ?? 0,
              active: active == filter,
              accent: Cyber.gold,
              onTap: () => onSelect(filter),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _CoinHistoryTile extends StatelessWidget {
  const _CoinHistoryTile({required this.entry});

  final OzCoinLedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final positive = entry.delta >= 0;
    final color = positive ? Cyber.success : Cyber.red;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Cyber.card,
        border: Border.all(color: Cyber.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color.withValues(alpha: 0.55)),
            ),
            child: Icon(_sourceIcon(entry.source), color: color, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.display(
                    13,
                    color: Colors.white,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  [
                    if (entry.subtitle != null) entry.subtitle!,
                    _timestampLabel(entry.timestamp),
                  ].join(' - '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.body(11, color: Cyber.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${positive ? '+' : '-'}${formatOzGrouped(entry.delta.abs())}',
                style: Cyber.display(
                  16,
                  color: color,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              const SizedBox(height: 4),
              Text(
                '${formatOzCompact(entry.balanceAfter)} BAL',
                style: Cyber.label(9, color: Cyber.muted, letterSpacing: 0.8),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyCoinHistory extends StatelessWidget {
  const _EmptyCoinHistory({required this.hasAny});

  final bool hasAny;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          hasAny ? 'No coin moves match this filter.' : 'No coin history yet.',
          textAlign: TextAlign.center,
          style: Cyber.body(13, color: Cyber.muted),
        ),
      ),
    );
  }
}

int _earned(List<OzCoinLedgerEntry> ledger) => ledger
    .where((entry) => entry.delta > 0)
    .where((entry) => entry.type != OzCoinTransactionType.openingBalance)
    .fold(0, (sum, entry) => sum + entry.delta);

int _spent(List<OzCoinLedgerEntry> ledger) => ledger
    .where((entry) => entry.delta < 0)
    .fold(0, (sum, entry) => sum + entry.delta.abs());

IconData _sourceIcon(OzCoinTransactionSource source) {
  return switch (source) {
    OzCoinTransactionSource.matchReward ||
    OzCoinTransactionSource.shootoutReward => Icons.sports_soccer,
    OzCoinTransactionSource.tennisReward => Icons.sports_tennis,
    OzCoinTransactionSource.quizEntry => Icons.quiz_rounded,
    OzCoinTransactionSource.quizContestPayout => Icons.emoji_events_rounded,
    OzCoinTransactionSource.footballBingoLifeline => Icons.grid_view,
    OzCoinTransactionSource.guessPlayerHint ||
    OzCoinTransactionSource.guessPlayerExtraAttempt =>
      Icons.manage_search_rounded,
    OzCoinTransactionSource.streakReward => Icons.local_fire_department,
    OzCoinTransactionSource.referralReward => Icons.card_giftcard_rounded,
    OzCoinTransactionSource.pickStake ||
    OzCoinTransactionSource.pickPayout => Icons.keyboard_double_arrow_up,
    OzCoinTransactionSource.packPurchase ||
    OzCoinTransactionSource.directCardPurchase ||
    OzCoinTransactionSource.duplicateRefund ||
    OzCoinTransactionSource.shopTopUp => Icons.storefront,
    OzCoinTransactionSource.openingBalance => Icons.account_balance_wallet,
    OzCoinTransactionSource.manual => Icons.toll,
  };
}

String _timestampLabel(DateTime timestamp) {
  final local = timestamp.toLocal();
  final month = _month(local.month);
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day $month $hour:$minute';
}

String _month(int month) => const [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
][month - 1];
