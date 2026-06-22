import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/picks/picks_cubit.dart';
import '../../blocs/picks/picks_state.dart';
import '../../config/theme.dart';
import '../../models/picks.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/staggered_card_entrance.dart';
import 'market_detail_screen.dart';
import 'widgets/pick_market_card.dart';
import 'widgets/pick_trade_sheet.dart';

class PicksHomeView extends StatefulWidget {
  const PicksHomeView({
    this.animateIntro = true,
    this.onIntroPlayed,
    super.key,
  });

  final bool animateIntro;
  final VoidCallback? onIntroPlayed;

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
        final stagger =
            widget.animateIntro && !_introPlayed && markets.isNotEmpty;
        if (stagger) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _introPlayed = true;
            widget.onIntroPlayed?.call();
          });
        }
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _PickFiltersHeader(),
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
                      StaggeredCardEntrance(
                        index: i,
                        animate: stagger,
                        child: PickMarketCard(
                          market: markets[i],
                          positions: state.positionsForMarket(markets[i].id),
                          onOpen: () => _openMarket(context, markets[i].id),
                          onBuy: (outcome) => showPickTradeSheet(
                            context: context,
                            market: markets[i],
                            outcome: outcome,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
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
}

/// Market-type filters with settings (league + status/sort live in the sheet).
class _PickFiltersHeader extends StatelessWidget {
  const _PickFiltersHeader();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PicksCubit, PicksState>(
      builder: (context, state) {
        return SizedBox(
          height: 32,
          child: Row(
            children: [
              Expanded(child: _TypeFilterBar(active: state.typeFilter)),
              const SizedBox(width: 8),
              _SettingsButton(onTap: () => _showPickSettings(context)),
            ],
          ),
        );
      },
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

/// Market-type filter with leaderboard-style cut-corner CTA chips.
class _TypeFilterBar extends StatelessWidget {
  const _TypeFilterBar({required this.active});

  final PickMarketType? active;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, PickMarketType? value})>[
      (label: 'ALL', value: null),
      (label: 'MATCHES', value: PickMarketType.match),
      (label: 'EVENT', value: PickMarketType.event),
      (label: 'FUTURES', value: PickMarketType.future),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _TabCtaChip(
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

/// Leaderboard-style cut-corner CTA chip used by both pick filter rows.
class _TabCtaChip extends StatelessWidget {
  const _TabCtaChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
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

/// Top-left / bottom-right cut outline, matching the leaderboard chips.
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
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.bottom - c)
      ..lineTo(rect.right - c, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
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
        separatorBuilder: (_, _) => const SizedBox(height: 16),
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
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (_) => const _PickSettingsSheet(),
  );
}

/// Compact chip-based filter sheet: LEAGUE, STATUS, and SORT.
class _PickSettingsSheet extends StatelessWidget {
  const _PickSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return BlocBuilder<PicksCubit, PicksState>(
      builder: (context, state) {
        final cubit = context.read<PicksCubit>();
        return Padding(
          padding: EdgeInsets.fromLTRB(0, 0, 0, bottom + 12),
          child: ClipPath(
            clipper: const HudChamferClipper(bigCut: 18, smallCut: 4),
            child: CustomPaint(
              foregroundPainter: const HudSheetFramePainter(),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xff152139), Color(0xff0b101c)],
                  ),
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
                            'LEAGUE',
                            style: Cyber.label(
                              8,
                              color: Cyber.muted,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              for (final filter in PickSportFilter.values)
                                _TabCtaChip(
                                  label: _sportLabel(filter),
                                  active: state.sportFilter == filter,
                                  onTap: () => cubit.setSportFilter(filter),
                                ),
                            ],
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
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              for (final entry in const [
                                (
                                  label: 'ALL',
                                  value: PickMarketStatusFilter.all,
                                ),
                                (
                                  label: 'OPEN',
                                  value: PickMarketStatusFilter.open,
                                ),
                                (
                                  label: 'CLOSED',
                                  value: PickMarketStatusFilter.closed,
                                ),
                              ])
                                _TabCtaChip(
                                  label: entry.label,
                                  active: state.statusFilter == entry.value,
                                  onTap: () =>
                                      cubit.setStatusFilter(entry.value),
                                ),
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
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
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
                                (
                                  label: 'VOLUME',
                                  value: PickSortOption.volume,
                                ),
                                (
                                  label: 'TRENDING',
                                  value: PickSortOption.trending,
                                ),
                              ])
                                _TabCtaChip(
                                  label: entry.label,
                                  active: state.sortOption == entry.value,
                                  onTap: () =>
                                      cubit.setSortOption(entry.value),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
