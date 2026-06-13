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
import 'market_detail_screen.dart';
import 'widgets/pick_market_card.dart';
import 'widgets/pick_settlement_reveal.dart';
import 'widgets/pick_status_style.dart';
import 'widgets/pick_trade_sheet.dart';

class PicksHomeView extends StatefulWidget {
  const PicksHomeView({super.key});

  @override
  State<PicksHomeView> createState() => _PicksHomeViewState();
}

class _PicksHomeViewState extends State<PicksHomeView> {
  /// First-load entrance plays once; later rebuilds (filters, sorts) get a
  /// quick cross-fade instead of re-staggering.
  bool _introPlayed = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PicksCubit, PicksState>(
      builder: (context, state) {
        if (state.loading) return const _PicksSkeleton();
        final markets = state.filteredMarkets;
        final stagger = !_introPlayed;
        if (stagger) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _introPlayed = true;
          });
        }
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _LeagueSettingsRow(active: state.sportFilter),
                  const SizedBox(height: 9),
                  _TypeFilterBar(active: state.typeFilter),
                  if (state.positionList.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _MyPicksStrip(
                      state: state,
                      onClaimAll: () => _claimAll(context),
                    ),
                  ],
                ]),
              ),
            ),
            if (markets.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyMarkets(
                  hasMarkets: state.markets.isNotEmpty,
                  hasSubmittedPicks: state.positionList.isNotEmpty,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 28),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    for (var i = 0; i < markets.length; i++) ...[
                      _CardEntrance(
                        index: i,
                        animate: stagger,
                        child: PickMarketCard(
                          market: markets[i],
                          position: state.positionForMarket(markets[i].id),
                          onOpen: () => _openMarket(context, markets[i].id),
                          onBuy: (outcome) => showPickTradeSheet(
                            context: context,
                            market: markets[i],
                            outcome: outcome,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ]),
                ),
              ),
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

  Future<void> _claimAll(BuildContext context) async {
    playSound(SoundEffect.uiTap);
    final picks = context.read<PicksCubit>();
    final result = await picks.settleAllClaimable();
    if (!context.mounted || result.settledCount == 0) return;
    if (result.payoutOz > 0) {
      context.read<GameBloc>().add(CoinsAdded(result.payoutOz));
    }
    await showPickSettlementReveal(
      context,
      PickSettlementRevealData.batch(
        result: result,
        winStreak: picks.state.winStreak,
      ),
    );
  }
}

/// Staggered slide-up entrance for the first screenful of cards.
class _CardEntrance extends StatelessWidget {
  const _CardEntrance({
    required this.index,
    required this.animate,
    required this.child,
  });

  final int index;
  final bool animate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!animate || index > 7) return child;
    final delayFactor = index * 0.16;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: (300 * (1 + delayFactor)).round()),
      curve: Interval(
        delayFactor / (1 + delayFactor),
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Portfolio presence on the hub: net P&L, win streak, claimables, and a
/// horizontally scrolling rail of open positions.
class _MyPicksStrip extends StatelessWidget {
  const _MyPicksStrip({required this.state, required this.onClaimAll});

  final PicksState state;
  final VoidCallback onClaimAll;

  @override
  Widget build(BuildContext context) {
    final net = state.realizedProfitOz;
    final netColor = net > 0
        ? Cyber.lime
        : net < 0
        ? Cyber.red
        : Cyber.muted;
    final streak = state.winStreak;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const SectionLabel(label: 'MY PICKS'),
            const SizedBox(width: 10),
            Text(
              'NET ${net >= 0 ? '+' : '−'}${formatOzCompact(net.abs())} OZ',
              style: Cyber.label(
                8,
                color: netColor,
                letterSpacing: 0.8,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (streak >= 2) ...[
              const SizedBox(width: 10),
              const Icon(
                Icons.local_fire_department,
                color: Cyber.gold,
                size: 12,
              ),
              Text(
                '×$streak',
                style: Cyber.label(
                  8,
                  color: Cyber.gold,
                  letterSpacing: 0.4,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
            const Spacer(),
            if (state.hasClaimable)
              _ClaimAllButton(count: state.claimableCount, onTap: onClaimAll),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: state.positionList.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) =>
                _PositionChip(position: state.positionList[index]),
          ),
        ),
      ],
    );
  }
}

/// The one glowing element on the hub when present — claimable coins waiting.
class _ClaimAllButton extends StatelessWidget {
  const _ClaimAllButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Cyber.gold.withValues(alpha: 0.14),
          border: Border.all(color: Cyber.gold),
          boxShadow: Cyber.glow(Cyber.gold, alpha: 0.35, blur: 12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.redeem, color: Cyber.gold, size: 13),
            const SizedBox(width: 6),
            Text(
              'CLAIM $count',
              style: Cyber.label(
                9,
                color: Cyber.gold,
                letterSpacing: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PositionChip extends StatelessWidget {
  const _PositionChip({required this.position});

  final PickPosition position;

  @override
  Widget build(BuildContext context) {
    final color = pickPositionColor(position.status);
    final claimable = position.canSettle;
    return PressableScale(
      onTap: () {
        playSound(SoundEffect.uiTap);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MarketDetailScreen(marketId: position.marketId),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xff111b30),
          border: Border.all(
            color: claimable ? Cyber.gold : const Color(0xff243654),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 7),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96),
              child: Text(
                position.outcomeLabel.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Cyber.label(8, letterSpacing: 0.6),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              '${formatOzCompact(position.stakeOz)} OZ',
              style: Cyber.label(
                8,
                color: Cyber.muted,
                letterSpacing: 0.4,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
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
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xff111827),
          border: Border.all(color: Cyber.border),
        ),
        child: const Icon(Icons.settings, color: Cyber.muted, size: 17),
      ),
    );
  }
}

/// Market-type filter, styled like the leaderboard league chips: cut-corner
/// chips with an accent-tinted fill + border when active, in a horizontal
/// scroll so they never crowd.
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _TypeChip(
              label: items[i].label,
              active: items[i].value == active,
              onTap: () =>
                  context.read<PicksCubit>().setTypeFilter(items[i].value),
            ),
            if (i != items.length - 1) const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }
}

/// A leaderboard-style cut-corner chip (mirrors `_SportChip`).
class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? Cyber.cyan : Cyber.muted;
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: ShapeDecoration(
          color: active
              ? Cyber.cyan.withValues(alpha: 0.14)
              : Colors.transparent,
          shape: _CutChipBorder(
            cut: 8,
            side: BorderSide(
              color: active
                  ? Cyber.cyan.withValues(alpha: 0.72)
                  : Cyber.line.withValues(alpha: 0.28),
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontFamily: Cyber.displayFont,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

/// Symmetric four-corner cut-corner outline, matching the leaderboard chips.
class _CutChipBorder extends ShapeBorder {
  const _CutChipBorder({required this.cut, this.side = BorderSide.none});

  final double cut;
  final BorderSide side;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  ShapeBorder scale(double t) =>
      _CutChipBorder(cut: cut * t, side: side.scale(t));

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(side.width), textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final c = cut.clamp(0, rect.shortestSide / 2).toDouble();
    return Path()
      ..moveTo(rect.left + c, rect.top)
      ..lineTo(rect.right - c, rect.top)
      ..lineTo(rect.right, rect.top + c)
      ..lineTo(rect.right, rect.bottom - c)
      ..lineTo(rect.right - c, rect.bottom)
      ..lineTo(rect.left + c, rect.bottom)
      ..lineTo(rect.left, rect.bottom - c)
      ..lineTo(rect.left, rect.top + c)
      ..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    canvas.drawPath(
      getOuterPath(rect.deflate(side.width / 2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = side.width
        ..color = side.color,
    );
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) => this;

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) => this;
}

/// Sport filter label with a sliding cyan underline marking the active one.
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: Cyber.label(
              10,
              color: active ? Colors.white : Cyber.muted.withValues(alpha: 0.8),
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedScale(
            scale: active ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: Container(width: 18, height: 2, color: Cyber.cyan),
          ),
        ],
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
    final box = AnimatedContainer(
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
    );
    return PressableScale(
      onTap: onTap,
      child: active
          ? ClipPath(
              clipper: const HudChamferClipper(bigCut: 9, smallCut: 2),
              child: box,
            )
          : box,
    );
  }
}

class _EmptyMarkets extends StatelessWidget {
  const _EmptyMarkets({
    required this.hasMarkets,
    required this.hasSubmittedPicks,
  });

  final bool hasMarkets;
  final bool hasSubmittedPicks;

  @override
  Widget build(BuildContext context) {
    if (hasMarkets) {
      return CyberNoDataState(
        icon: Icons.manage_search,
        title: 'No picks found',
        message: 'Try another league, market type, or clear filters.',
        actionLabel: 'CLEAR FILTERS',
        actionIcon: Icons.filter_alt_off,
        onAction: () {
          playSound(SoundEffect.uiTap);
          context.read<PicksCubit>().resetFilters();
        },
      );
    }

    return CyberNoDataState(
      icon: hasSubmittedPicks ? Icons.hourglass_empty : Icons.ads_click,
      title: hasSubmittedPicks ? 'No live picks' : 'Be the 1st to pick',
      message: hasSubmittedPicks
          ? 'Fresh pick markets will appear here soon.'
          : 'No one has submitted a pick yet. Make the opening call.',
      accent: hasSubmittedPicks ? Cyber.cyan : Cyber.lime,
      spark: hasSubmittedPicks ? Icons.schedule : Icons.flash_on,
    );
  }
}

class _PicksSkeleton extends StatefulWidget {
  const _PicksSkeleton();

  @override
  State<_PicksSkeleton> createState() => _PicksSkeletonState();
}

class _PicksSkeletonState extends State<_PicksSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) =>
          Opacity(opacity: 0.55 + 0.45 * _pulse.value, child: child),
      child: ListView.separated(
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

/// Compact chip-based filter sheet: STATUS as a segmented row, SORT as a chip
/// grid. Sport selection lives on the main filter row, not here.
class _PickSettingsSheet extends StatelessWidget {
  const _PickSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return BlocBuilder<PicksCubit, PicksState>(
      builder: (context, state) {
        final cubit = context.read<PicksCubit>();
        return Padding(
          padding: EdgeInsets.fromLTRB(8, 0, 8, bottom + 8),
          child: ClipPath(
            clipper: const HudChamferClipper(bigCut: 16, smallCut: 3),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xff10192d),
                border: Border.all(color: Cyber.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const HudLine(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MARKET FILTERS',
                          style: Cyber.label(
                            12,
                            color: Cyber.cyan,
                            letterSpacing: 1.8,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'STATUS',
                          style: Cyber.label(
                            8,
                            color: Cyber.muted,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (final entry in const [
                              (label: 'ALL', value: PickMarketStatusFilter.all),
                              (
                                label: 'OPEN',
                                value: PickMarketStatusFilter.open,
                              ),
                              (
                                label: 'CLOSED',
                                value: PickMarketStatusFilter.closed,
                              ),
                            ]) ...[
                              Expanded(
                                child: _BoxFilter(
                                  label: entry.label,
                                  active: state.statusFilter == entry.value,
                                  onTap: () =>
                                      cubit.setStatusFilter(entry.value),
                                ),
                              ),
                              if (entry.value != PickMarketStatusFilter.closed)
                                const SizedBox(width: 7),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'SORT BY',
                          style: Cyber.label(
                            8,
                            color: Cyber.muted,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (final entry in const [
                              (label: 'NEW', value: PickSortOption.newest),
                              (
                                label: 'START TIME',
                                value: PickSortOption.startTime,
                              ),
                              (
                                label: 'CLOSING',
                                value: PickSortOption.closingSoon,
                              ),
                            ]) ...[
                              Expanded(
                                child: _BoxFilter(
                                  label: entry.label,
                                  active: state.sortOption == entry.value,
                                  onTap: () => cubit.setSortOption(entry.value),
                                ),
                              ),
                              if (entry.value != PickSortOption.closingSoon)
                                const SizedBox(width: 7),
                            ],
                          ],
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Expanded(
                              child: _BoxFilter(
                                label: 'VOLUME',
                                active:
                                    state.sortOption == PickSortOption.volume,
                                onTap: () =>
                                    cubit.setSortOption(PickSortOption.volume),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: _BoxFilter(
                                label: 'TRENDING',
                                active:
                                    state.sortOption == PickSortOption.trending,
                                onTap: () => cubit.setSortOption(
                                  PickSortOption.trending,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            const Expanded(child: SizedBox()),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
