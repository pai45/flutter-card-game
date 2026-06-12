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
import 'market_detail_screen.dart';

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
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HistoryHeader(onBack: () => Navigator.pop(context)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _PicksStatsRow(state: state),
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
                          ? _EmptyHistory(hasAnyPicks: positions.isNotEmpty)
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
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

enum _PicksFilter { all, won, lost, live, pending, unresolved, voided }

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          Expanded(
            child: Text(
              'MY PICKS HISTORY',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.display(19, color: Cyber.success, letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _PicksStatsRow extends StatelessWidget {
  const _PicksStatsRow({required this.state});

  final PicksState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _NotchedStatCard(
            label: 'PICKS',
            value: '${state.positions.length}',
            fill: const Color(0xff145d38),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _NotchedStatCard(
            label: 'EXPOSURE',
            value: '${state.openExposureOz}',
            fill: const Color(0xff124b41),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _NotchedStatCard(
            label: 'PROFIT',
            value: '${state.realizedProfitOz}',
            fill: const Color(0xff1f5d5d),
          ),
        ),
      ],
    );
  }
}

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
            _FilterChip(
              label: '${_label(filter)} (${counts[filter] ?? 0})',
              active: active == filter,
              onTap: () => onSelect(filter),
            ),
            if (filter != _PicksFilter.voided) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  String _label(_PicksFilter filter) => switch (filter) {
    _PicksFilter.all => 'ALL',
    _PicksFilter.won => 'WON',
    _PicksFilter.lost => 'LOST',
    _PicksFilter.live => 'LIVE',
    _PicksFilter.pending => 'PENDING',
    _PicksFilter.unresolved => 'REVIEW',
    _PicksFilter.voided => 'REFUND',
  };
}

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
    final palette = _pickPalette(position.status);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xff0f172d),
          border: Border.all(color: Cyber.border.withValues(alpha: 0.85)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.26),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          position.marketQuestion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Cyber.body(13, weight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _TypePill(type: position.marketType),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (market?.homeLabel != null && market?.awayLabel != null)
                    _MarketScorePreview(market: market!)
                  else
                    _FutureMarketBody(position: position, market: market),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pick: ${position.outcomeLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Cyber.body(
                            12,
                            color: Cyber.success,
                            weight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        position.leagueLabel,
                        style: Cyber.label(10, color: Cyber.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (position.status != PickPositionStatus.pending &&
                position.status != PickPositionStatus.live)
              _StatusStrip(label: palette.label, color: palette.color),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Metric(
                    label: 'AVG',
                    value:
                        '${position.averageProbabilityPercent.toStringAsFixed(0)}%',
                  ),
                  const SizedBox(width: 18),
                  Expanded(child: _StakeMetric(position: position)),
                  const SizedBox(width: 12),
                  _StatusMetric(position: position, palette: palette),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Text(
                    _formatPickTime(position.submittedAt),
                    style: Cyber.body(10, color: Cyber.muted),
                  ),
                  const Spacer(),
                  if (onSettle != null)
                    _ClaimButton(onTap: onSettle!)
                  else
                    Flexible(
                      child: Text(
                        position.resultNote ?? palette.valueLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: Cyber.body(10, color: Cyber.muted),
                      ),
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

class _MarketScorePreview extends StatelessWidget {
  const _MarketScorePreview({required this.market});

  final PickMarket market;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MarketSideRow(label: market.homeLabel!, score: market.homeScore),
        const SizedBox(height: 8),
        _MarketSideRow(label: market.awayLabel!, score: market.awayScore),
      ],
    );
  }
}

class _MarketSideRow extends StatelessWidget {
  const _MarketSideRow({required this.label, required this.score});

  final String label;
  final String? score;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Cyber.panel2,
            border: Border.all(color: Cyber.border),
          ),
          child: const Icon(
            Icons.horizontal_rule,
            color: Cyber.muted,
            size: 15,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            score == null ? label : '$label  $score',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Cyber.body(
              13,
              weight: FontWeight.w800,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
      ],
    );
  }
}

class _FutureMarketBody extends StatelessWidget {
  const _FutureMarketBody({required this.position, required this.market});

  final PickPosition position;
  final PickMarket? market;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Cyber.bg.withValues(alpha: 0.35),
        border: Border.all(color: Cyber.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.query_stats, color: Cyber.success, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              position.outcomeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.body(13, weight: FontWeight.w900),
            ),
          ),
          Text(
            market?.resultNote ?? _positionLabel(position.status),
            style: Cyber.body(11, color: Cyber.muted, weight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.type});

  final PickMarketType type;

  @override
  Widget build(BuildContext context) {
    final label = switch (type) {
      PickMarketType.match => 'MATCH',
      PickMarketType.event => 'EVENT',
      PickMarketType.future => 'FUTURE',
    };
    final color = switch (type) {
      PickMarketType.match => Cyber.cyan,
      PickMarketType.event => Cyber.gold,
      PickMarketType.future => Cyber.violet,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Text(
        label,
        style: Cyber.label(8, color: color, letterSpacing: 0.8),
      ),
    );
  }
}

class _StakeMetric extends StatelessWidget {
  const _StakeMetric({required this.position});

  final PickPosition position;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('STAKE VALUE', style: Cyber.label(8, color: Cyber.muted)),
        const SizedBox(height: 5),
        Row(
          children: [
            const CoinIcon(size: 12),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '${position.stakeOz} for ${position.shareCount} shares',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Cyber.body(
                  12,
                  weight: FontWeight.w800,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusMetric extends StatelessWidget {
  const _StatusMetric({required this.position, required this.palette});

  final PickPosition position;
  final _PickPalette palette;

  @override
  Widget build(BuildContext context) {
    final value = switch (position.status) {
      PickPositionStatus.won => '+${position.realizedProfit}',
      PickPositionStatus.lost => '-${position.stakeOz}',
      PickPositionStatus.voided => '0',
      PickPositionStatus.settleable => 'Claim',
      _ => palette.valueLabel,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('STATUS', style: Cyber.label(8, color: Cyber.muted)),
        const SizedBox(height: 5),
        Text(
          value,
          textAlign: TextAlign.right,
          style: Cyber.body(
            12,
            color: palette.color,
            weight: FontWeight.w900,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Cyber.label(8, color: Cyber.muted)),
        const SizedBox(height: 5),
        Text(
          value,
          style: Cyber.body(
            12,
            weight: FontWeight.w800,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ],
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      alignment: Alignment.center,
      color: color.withValues(alpha: 0.22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_statusIcon(label), color: color, size: 15),
          const SizedBox(width: 7),
          Text(label, style: Cyber.label(10, color: color, letterSpacing: 0.7)),
        ],
      ),
    );
  }
}

class _ClaimButton extends StatelessWidget {
  const _ClaimButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Cyber.gold.withValues(alpha: 0.12),
          border: Border.all(color: Cyber.gold.withValues(alpha: 0.75)),
        ),
        child: Text(
          'CLAIM',
          style: Cyber.label(9, color: Cyber.gold, letterSpacing: 0.8),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Cyber.success.withValues(alpha: 0.14) : Cyber.panel2,
          border: Border.all(color: active ? Cyber.success : Cyber.border),
        ),
        child: Text(
          label,
          style: Cyber.label(
            10,
            color: active ? Cyber.success : Cyber.muted,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

class _NotchedStatCard extends StatelessWidget {
  const _NotchedStatCard({
    required this.label,
    required this.value,
    required this.fill,
  });

  final String label;
  final String value;
  final Color fill;

  static const _notchW = 9.0;
  static const _notchH = 7.0;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _NotchedStatBorderPainter(fill: fill),
      child: ClipPath(
        clipper: const _NotchedStatClipper(notchW: _notchW, notchH: _notchH),
        child: Container(
          height: 78,
          alignment: Alignment.center,
          color: fill,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 13),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Cyber.body(
                  9,
                  color: Colors.white.withValues(alpha: 0.72),
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: Cyber.display(22, letterSpacing: 0).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotchedStatClipper extends CustomClipper<Path> {
  const _NotchedStatClipper({required this.notchW, required this.notchH});

  final double notchW;
  final double notchH;

  @override
  Path getClip(Size size) => _notchedRect(size, notchW, notchH);

  @override
  bool shouldReclip(covariant _NotchedStatClipper old) =>
      old.notchW != notchW || old.notchH != notchH;
}

class _NotchedStatBorderPainter extends CustomPainter {
  const _NotchedStatBorderPainter({required this.fill});

  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _notchedRect(
      size,
      _NotchedStatCard._notchW,
      _NotchedStatCard._notchH,
    );
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Cyber.border,
    );
  }

  @override
  bool shouldRepaint(covariant _NotchedStatBorderPainter old) =>
      old.fill != fill;
}

class _PickPalette {
  const _PickPalette({
    required this.label,
    required this.valueLabel,
    required this.color,
  });

  final String label;
  final String valueLabel;
  final Color color;
}

_PickPalette _pickPalette(PickPositionStatus status) {
  return switch (status) {
    PickPositionStatus.pending => const _PickPalette(
      label: 'PENDING',
      valueLabel: 'Pending',
      color: Cyber.gold,
    ),
    PickPositionStatus.live => const _PickPalette(
      label: 'LIVE',
      valueLabel: 'Live',
      color: Cyber.red,
    ),
    PickPositionStatus.unresolved => const _PickPalette(
      label: 'UNRESOLVED',
      valueLabel: 'Review',
      color: Cyber.amber,
    ),
    PickPositionStatus.settleable => const _PickPalette(
      label: 'RESULT READY',
      valueLabel: 'Claim',
      color: Cyber.gold,
    ),
    PickPositionStatus.won => const _PickPalette(
      label: 'WON',
      valueLabel: 'Won',
      color: Cyber.success,
    ),
    PickPositionStatus.lost => const _PickPalette(
      label: 'LOST',
      valueLabel: 'Lost',
      color: Cyber.red,
    ),
    PickPositionStatus.voided => const _PickPalette(
      label: 'REFUNDED',
      valueLabel: 'Refunded',
      color: Cyber.muted,
    ),
  };
}

Path _notchedRect(Size size, double notchW, double notchH) {
  final w = size.width;
  final h = size.height;
  final cx = w / 2;
  return Path()
    ..moveTo(0, 0)
    ..lineTo(cx - notchW, 0)
    ..lineTo(cx, notchH)
    ..lineTo(cx + notchW, 0)
    ..lineTo(w, 0)
    ..lineTo(w, h)
    ..lineTo(cx + notchW, h)
    ..lineTo(cx, h - notchH)
    ..lineTo(cx - notchW, h)
    ..lineTo(0, h)
    ..close();
}

IconData _statusIcon(String label) {
  return switch (label) {
    'WON' => Icons.trending_up,
    'LOST' => Icons.trending_down,
    'REFUNDED' => Icons.undo,
    'RESULT READY' => Icons.redeem,
    _ => Icons.help_outline,
  };
}

String _positionLabel(PickPositionStatus status) => switch (status) {
  PickPositionStatus.pending => 'Pending',
  PickPositionStatus.live => 'Live',
  PickPositionStatus.unresolved => 'Review',
  PickPositionStatus.settleable => 'Claim',
  PickPositionStatus.won => 'Won',
  PickPositionStatus.lost => 'Lost',
  PickPositionStatus.voided => 'Refunded',
};

String _formatPickTime(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  final month = switch (local.month) {
    1 => 'Jan',
    2 => 'Feb',
    3 => 'Mar',
    4 => 'Apr',
    5 => 'May',
    6 => 'Jun',
    7 => 'Jul',
    8 => 'Aug',
    9 => 'Sep',
    10 => 'Oct',
    11 => 'Nov',
    _ => 'Dec',
  };
  return '$hour:$minute, ${local.day} $month';
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.hasAnyPicks});

  final bool hasAnyPicks;

  @override
  Widget build(BuildContext context) {
    return CyberNoDataState(
      icon: hasAnyPicks ? Icons.filter_alt_off : Icons.ads_click,
      title: hasAnyPicks ? 'No picks in this filter' : 'Be the 1st to pick',
      message: hasAnyPicks
          ? 'Switch filters to review the picks already on your board.'
          : 'No one has submitted a pick here yet. Make the first call.',
      accent: hasAnyPicks ? Cyber.success : Cyber.lime,
      spark: hasAnyPicks ? Icons.tune : Icons.flash_on,
    );
  }
}
