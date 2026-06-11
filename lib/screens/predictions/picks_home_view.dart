import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/picks/picks_cubit.dart';
import '../../blocs/picks/picks_state.dart';
import '../../config/theme.dart';
import '../../models/picks.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import 'market_detail_screen.dart';
import 'widgets/pick_market_card.dart';
import 'widgets/pick_trade_sheet.dart';

class PicksHomeView extends StatelessWidget {
  const PicksHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PicksCubit, PicksState>(
      builder: (context, state) {
        if (state.loading) return const _PicksSkeleton();
        final markets = state.filteredMarkets;
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
          children: [
            _LeagueSettingsRow(active: state.sportFilter),
            const SizedBox(height: 9),
            _TypeFilterBar(active: state.typeFilter),
            const SizedBox(height: 16),
            if (markets.isEmpty)
              const _EmptyMarkets()
            else
              for (final market in markets) ...[
                PickMarketCard(
                  market: market,
                  position: state.positionForMarket(market.id),
                  onOpen: () => _openMarket(context, market.id),
                  onBuy: (outcome) => showPickTradeSheet(
                    context: context,
                    market: market,
                    outcome: outcome,
                  ),
                ),
                const SizedBox(height: 12),
              ],
          ],
        );
      },
    );
  }

  void _openMarket(BuildContext context, String marketId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MarketDetailScreen(marketId: marketId),
      ),
    );
  }
}

class _LeagueSettingsRow extends StatelessWidget {
  const _LeagueSettingsRow({required this.active});

  final PickSportFilter active;

  @override
  Widget build(BuildContext context) {
    const filters = PickSportFilter.values;
    return SizedBox(
      height: 32,
      child: Stack(
        children: [
          Positioned.fill(
            right: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 18),
              itemCount: filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 18),
              itemBuilder: (context, index) {
                final filter = filters[index];
                return _TextFilter(
                  label: _sportLabel(filter),
                  active: filter == active,
                  onTap: () =>
                      context.read<PicksCubit>().setSportFilter(filter),
                );
              },
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Cyber.bg.withValues(alpha: 0), Cyber.bg, Cyber.bg],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: _SettingsButton(onTap: () => _showPickSettings(context)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xff111827),
          border: Border.all(color: Cyber.border),
        ),
        child: const Icon(Icons.settings, color: Cyber.muted, size: 19),
      ),
    );
  }
}

class _TypeFilterBar extends StatelessWidget {
  const _TypeFilterBar({required this.active});

  final PickMarketType? active;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, PickMarketType? value})>[
      (label: 'ALL PICKS', value: null),
      (label: 'MATCHES', value: PickMarketType.match),
      (label: 'EVENT', value: PickMarketType.event),
      (label: 'FUTURES', value: PickMarketType.future),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(
            child: _BoxFilter(
              label: items[i].label,
              active: items[i].value == active,
              onTap: () =>
                  context.read<PicksCubit>().setTypeFilter(items[i].value),
            ),
          ),
          if (i != items.length - 1) const SizedBox(width: 7),
        ],
      ],
    );
  }
}

class _TextFilter extends StatelessWidget {
  const _TextFilter({
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
      child: Align(
        alignment: Alignment.center,
        child: Text(
          label,
          style: Cyber.label(
            10,
            color: active ? Colors.white : Cyber.muted.withValues(alpha: 0.8),
            letterSpacing: 0.9,
          ),
        ),
      ),
    );
  }
}

class _BoxFilter extends StatelessWidget {
  const _BoxFilter({
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
        height: 31,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? const Color(0xff12304a)
              : const Color(0xff111827).withValues(alpha: 0.86),
          border: Border.all(
            color: active
                ? Cyber.cyan.withValues(alpha: 0.7)
                : const Color(0xff273654),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: Cyber.label(
              9,
              color: active ? Cyber.cyan : Cyber.muted.withValues(alpha: 0.72),
              letterSpacing: 0.7,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyMarkets extends StatelessWidget {
  const _EmptyMarkets();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xff172234),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          const Icon(Icons.filter_alt_off, color: Cyber.muted, size: 26),
          const SizedBox(height: 10),
          Text(
            'No markets in this view.',
            textAlign: TextAlign.center,
            style: Cyber.body(13, color: Cyber.muted, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _PicksSkeleton extends StatelessWidget {
  const _PicksSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 28),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, index) => ClipPath(
        clipper: const HudChamferClipper(bigCut: 15, smallCut: 2),
        child: Container(
          height: index == 0 ? 76 : 138,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xff111827),
            border: Border.all(color: const Color(0xff243654)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 120,
                height: 10,
                color: Cyber.cyan.withValues(alpha: 0.18),
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                height: 32,
                color: Cyber.cyan.withValues(alpha: 0.1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _sportLabel(PickSportFilter filter) => switch (filter) {
  PickSportFilter.all => 'ALL',
  PickSportFilter.ipl => 'IPL',
  PickSportFilter.epl => 'EPL',
  PickSportFilter.fifa => 'FIFA',
  PickSportFilter.nba => 'NBA',
  PickSportFilter.laliga => 'LALIGA',
  PickSportFilter.seriea => 'SERIE A',
};

Future<void> _showPickSettings(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (_) => const _PickSettingsSheet(),
  );
}

class _PickSettingsSheet extends StatelessWidget {
  const _PickSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return BlocBuilder<PicksCubit, PicksState>(
      builder: (context, state) {
        return Padding(
          padding: EdgeInsets.fromLTRB(8, 0, 8, bottom + 8),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 620),
            decoration: BoxDecoration(
              color: const Color(0xff10192d),
              border: Border.all(color: Cyber.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const HudLine(),
                  const SizedBox(height: 14),
                  _SettingsSportRow(
                    label: 'ALL',
                    active: state.sportFilter == PickSportFilter.all,
                    onTap: () => context.read<PicksCubit>().setSportFilter(
                      PickSportFilter.all,
                    ),
                  ),
                  _SettingsSportRow(
                    label: 'CRICKET',
                    active: state.sportFilter == PickSportFilter.ipl,
                    onTap: () => context.read<PicksCubit>().setSportFilter(
                      PickSportFilter.ipl,
                    ),
                  ),
                  _SettingsSportRow(
                    label: 'FOOTBALL',
                    active: state.sportFilter == PickSportFilter.epl,
                    onTap: () => context.read<PicksCubit>().setSportFilter(
                      PickSportFilter.epl,
                    ),
                  ),
                  _SettingsSportRow(
                    label: 'BASKETBALL',
                    active: state.sportFilter == PickSportFilter.nba,
                    onTap: () => context.read<PicksCubit>().setSportFilter(
                      PickSportFilter.nba,
                    ),
                  ),
                  const _SettingsDivider(),
                  const _SettingsTitle('FILTER BY STATUS'),
                  _RadioSetting(
                    label: 'ALL MARKET',
                    selected: state.statusFilter == PickMarketStatusFilter.all,
                    onTap: () => context.read<PicksCubit>().setStatusFilter(
                      PickMarketStatusFilter.all,
                    ),
                  ),
                  _RadioSetting(
                    label: 'OPEN MARKET',
                    selected: state.statusFilter == PickMarketStatusFilter.open,
                    onTap: () => context.read<PicksCubit>().setStatusFilter(
                      PickMarketStatusFilter.open,
                    ),
                  ),
                  _RadioSetting(
                    label: 'CLOSED MARKET',
                    selected:
                        state.statusFilter == PickMarketStatusFilter.closed,
                    onTap: () => context.read<PicksCubit>().setStatusFilter(
                      PickMarketStatusFilter.closed,
                    ),
                  ),
                  const _SettingsDivider(),
                  const _SettingsTitle('SORT BY'),
                  _RadioSetting(
                    label: 'NEW',
                    selected: state.sortOption == PickSortOption.newest,
                    onTap: () => context.read<PicksCubit>().setSortOption(
                      PickSortOption.newest,
                    ),
                  ),
                  _RadioSetting(
                    label: 'START TIME',
                    selected: state.sortOption == PickSortOption.startTime,
                    onTap: () => context.read<PicksCubit>().setSortOption(
                      PickSortOption.startTime,
                    ),
                  ),
                  _RadioSetting(
                    label: 'CLOSING SOON',
                    selected: state.sortOption == PickSortOption.closingSoon,
                    onTap: () => context.read<PicksCubit>().setSortOption(
                      PickSortOption.closingSoon,
                    ),
                  ),
                  _RadioSetting(
                    label: 'VOLUME',
                    selected: state.sortOption == PickSortOption.volume,
                    onTap: () => context.read<PicksCubit>().setSortOption(
                      PickSortOption.volume,
                    ),
                  ),
                  _RadioSetting(
                    label: 'TRENDING',
                    selected: state.sortOption == PickSortOption.trending,
                    onTap: () => context.read<PicksCubit>().setSortOption(
                      PickSortOption.trending,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SettingsSportRow extends StatelessWidget {
  const _SettingsSportRow({
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
      child: Container(
        height: 49,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Cyber.body(
                  15,
                  color: active ? Cyber.cyan : Colors.white,
                  weight: FontWeight.w900,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: active ? Cyber.cyan : Colors.white,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: Cyber.border.withValues(alpha: 0.55),
      margin: const EdgeInsets.symmetric(vertical: 8),
    );
  }
}

class _SettingsTitle extends StatelessWidget {
  const _SettingsTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      child: Text(label, style: Cyber.body(15, weight: FontWeight.w900)),
    );
  }
}

class _RadioSetting extends StatelessWidget {
  const _RadioSetting({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? const Color(0xff5be1ff) : Colors.white,
                border: Border.all(
                  color: selected
                      ? const Color(0xff5be1ff)
                      : Colors.white.withValues(alpha: 0.72),
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, color: Cyber.bg, size: 17)
                  : null,
            ),
            const SizedBox(width: 26),
            Text(label, style: Cyber.body(14, weight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}
