import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_state.dart';
import '../../config/theme.dart';
import '../../models/progression.dart';
import '../../models/xp_ledger.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../predictions/widgets/history_hud.dart';
import 'widgets/profile_card.dart';

void showXpHistory(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const XpHistoryScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class XpHistoryScreen extends StatefulWidget {
  const XpHistoryScreen({super.key});

  @override
  State<XpHistoryScreen> createState() => _XpHistoryScreenState();
}

class _XpHistoryScreenState extends State<XpHistoryScreen> {
  XpChartRange _range = XpChartRange.all;
  _XpHistoryFilter _filter = _XpHistoryFilter.all;

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
                final ledger = [...state.xpLedger]
                  ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
                final filtered = ledger
                    .where((entry) => _matches(entry, _filter))
                    .toList();
                final earned = ledger
                    .where(
                      (entry) =>
                          entry.delta > 0 &&
                          entry.type != XpTransactionType.openingBalance,
                    )
                    .fold<int>(0, (sum, entry) => sum + entry.delta);
                final lost = ledger
                    .where((entry) => entry.delta < 0)
                    .fold<int>(0, (sum, entry) => sum + entry.delta.abs());
                final counts = {
                  for (final filter in _XpHistoryFilter.values)
                    filter: ledger
                        .where((entry) => _matches(entry, filter))
                        .length,
                };
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HistoryHeaderBar(
                      title: 'XP PROGRESS',
                      accent: Cyber.cyan,
                      onBack: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                        children: [
                          _LevelSummary(progression: state.progression),
                          const SizedBox(height: 12),
                          _XpGraphCard(
                            totalXp: state.progression.totalXP,
                            ledger: ledger,
                            range: _range,
                            onRangeChanged: (range) =>
                                setState(() => _range = range),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: HistoryStatCell(
                                  label: 'EARNED',
                                  value: _grouped(earned),
                                  accent: Cyber.cyan,
                                  valueColor: earned > 0 ? Cyber.success : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: HistoryStatCell(
                                  label: 'LOST',
                                  value: _grouped(lost),
                                  accent: Cyber.cyan,
                                  valueColor: lost > 0 ? Cyber.red : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: HistoryStatCell(
                                  label: 'NET',
                                  value: _signed(earned - lost),
                                  accent: Cyber.cyan,
                                  valueColor: earned - lost >= 0
                                      ? Cyber.success
                                      : Cyber.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _XpFilterBar(
                            active: _filter,
                            counts: counts,
                            onSelect: (filter) =>
                                setState(() => _filter = filter),
                          ),
                          const SizedBox(height: 12),
                          if (filtered.isEmpty)
                            _EmptyXpHistory(hasAny: ledger.isNotEmpty)
                          else
                            for (var i = 0; i < filtered.length; i++) ...[
                              _XpHistoryTile(entry: filtered[i]),
                              if (i != filtered.length - 1)
                                const SizedBox(height: 10),
                            ],
                        ],
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
}

class _LevelSummary extends StatelessWidget {
  const _LevelSummary({required this.progression});

  final PlayerProgression progression;

  @override
  Widget build(BuildContext context) {
    final progress = levelProgress(progression.totalXP);
    return ProfileCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CURRENT LEVEL',
                    style: Cyber.label(
                      9,
                      color: Cyber.muted,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${progress.level}',
                    style: Cyber.display(36, color: Cyber.cyan),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_grouped(progression.totalXP)} TOTAL XP',
                    style: Cyber.label(
                      10,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${_grouped(progress.toNextLevel)} XP TO LEVEL ${progress.level + 1}',
                    key: const ValueKey('xp-to-next-level'),
                    style: Cyber.display(
                      13,
                      color: progress.toNextLevel == 0
                          ? Cyber.success
                          : Cyber.cyan,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          CyberProgressBar(
            value: progress.pct,
            accent: Cyber.cyan,
            trackColor: Cyber.bg,
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Text(
                '${_grouped(progress.intoLevel)} XP',
                style: Cyber.label(9, color: Cyber.muted),
              ),
              const Spacer(),
              Text(
                '${_grouped(progress.levelSpan)} XP',
                style: Cyber.label(9, color: Cyber.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _XpGraphCard extends StatelessWidget {
  const _XpGraphCard({
    required this.totalXp,
    required this.ledger,
    required this.range,
    required this.onRangeChanged,
  });

  final int totalXp;
  final List<XpLedgerEntry> ledger;
  final XpChartRange range;
  final ValueChanged<XpChartRange> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    return ProfileCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, color: Cyber.cyan, size: 20),
              const SizedBox(width: 8),
              Text(
                'XP HISTORY',
                style: Cyber.display(14, color: Cyber.cyan, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _XpRangeTabs(active: range, onChanged: onRangeChanged),
          const SizedBox(height: 12),
          XpBalanceChart(
            totalXp: totalXp,
            ledger: ledger,
            range: range,
            height: 176,
          ),
        ],
      ),
    );
  }
}

class XpBalanceChart extends StatefulWidget {
  const XpBalanceChart({
    required this.totalXp,
    required this.ledger,
    required this.range,
    this.height = 220,
    super.key,
  });

  final int totalXp;
  final List<XpLedgerEntry> ledger;
  final XpChartRange range;
  final double height;

  @override
  State<XpBalanceChart> createState() => _XpBalanceChartState();
}

class _XpBalanceChartState extends State<XpBalanceChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final entries = xpLedgerForRange(widget.ledger, widget.range);
    final values = xpBalanceValues(widget.totalXp, entries);
    final selectedIndex = selectedXpChartIndex(_selectedIndex, values.length);
    return LayoutBuilder(
      builder: (context, constraints) {
        void selectAt(Offset position) {
          final index = xpChartIndexForDx(
            dx: position.dx,
            width: constraints.maxWidth,
            pointCount: values.length,
          );
          if (index == _selectedIndex) return;
          setState(() => _selectedIndex = index);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => selectAt(details.localPosition),
              onHorizontalDragUpdate: (details) =>
                  selectAt(details.localPosition),
              child: Container(
                height: widget.height,
                decoration: BoxDecoration(
                  color: const Color(0xff10192d),
                  border: Border.all(color: Cyber.border),
                ),
                child: CustomPaint(
                  painter: XpBalanceChartPainter(
                    values: values,
                    selectedIndex: selectedIndex,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'TOTAL XP',
                  style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.2),
                ),
                const Spacer(),
                Text(
                  _grouped(values[selectedIndex]),
                  style: Cyber.display(18, color: Cyber.cyan).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class XpBalanceChartPainter extends CustomPainter {
  const XpBalanceChartPainter({
    required this.values,
    required this.selectedIndex,
  });

  final List<int> values;
  final int selectedIndex;

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

    final safeValues = values.isEmpty ? const [0] : values;
    final minValue = math.max(
      0,
      safeValues.reduce(math.min) - math.max(10, safeValues.last ~/ 20),
    );
    final maxValue =
        safeValues.reduce(math.max) + math.max(10, safeValues.last ~/ 20);
    final spread = math.max(1, maxValue - minValue);
    final points = <Offset>[];
    for (var i = 0; i < safeValues.length; i++) {
      final x = safeValues.length == 1
          ? size.width
          : size.width * i / (safeValues.length - 1);
      final y =
          size.height - ((safeValues[i] - minValue) / spread) * size.height;
      points.add(Offset(x, y));
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Cyber.cyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
    final index = selectedIndex.clamp(0, points.length - 1);
    final selected = points[index];
    _drawDashedLine(
      canvas,
      Offset(selected.dx, 0),
      Offset(selected.dx, size.height),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      selected,
      8,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(selected, 4, Paint()..color = Cyber.cyan);
  }

  @override
  bool shouldRepaint(covariant XpBalanceChartPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.selectedIndex != selectedIndex;
}

enum XpChartRange { all, week, day }

class _XpRangeTabs extends StatelessWidget {
  const _XpRangeTabs({required this.active, required this.onChanged});

  final XpChartRange active;
  final ValueChanged<XpChartRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final range in XpChartRange.values) ...[
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(range),
              child: Container(
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active == range
                      ? Cyber.cyan.withValues(alpha: 0.14)
                      : Colors.transparent,
                  border: Border.all(
                    color: active == range
                        ? Cyber.cyan.withValues(alpha: 0.72)
                        : Cyber.line.withValues(alpha: 0.28),
                  ),
                ),
                child: Text(
                  range.name.toUpperCase(),
                  style: Cyber.label(
                    10,
                    color: active == range ? Cyber.cyan : Cyber.muted,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
          if (range != XpChartRange.values.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

enum _XpHistoryFilter { all, earned, lost, games, predictions, rewards }

class _XpFilterBar extends StatelessWidget {
  const _XpFilterBar({
    required this.active,
    required this.counts,
    required this.onSelect,
  });

  final _XpHistoryFilter active;
  final Map<_XpHistoryFilter, int> counts;
  final ValueChanged<_XpHistoryFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in _XpHistoryFilter.values) ...[
            HistoryFilterChip(
              label: filter.name.toUpperCase(),
              count: counts[filter] ?? 0,
              active: active == filter,
              accent: Cyber.cyan,
              onTap: () => onSelect(filter),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _XpHistoryTile extends StatelessWidget {
  const _XpHistoryTile({required this.entry});

  final XpLedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final opening = entry.type == XpTransactionType.openingBalance;
    final positive = entry.delta >= 0;
    final color = opening
        ? Cyber.cyan
        : positive
        ? Cyber.success
        : Cyber.red;
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
                    if (entry.details != null) entry.details!,
                    _timestampLabel(entry.timestamp),
                  ].join(' · '),
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
                '${entry.delta >= 0 ? '+' : '−'}${_grouped(entry.delta.abs())}',
                style: Cyber.display(
                  16,
                  color: color,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              const SizedBox(height: 4),
              Text(
                '${_grouped(entry.balanceAfter)} XP',
                style: Cyber.label(9, color: Cyber.muted, letterSpacing: 0.8),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyXpHistory extends StatelessWidget {
  const _EmptyXpHistory({required this.hasAny});

  final bool hasAny;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Text(
        hasAny
            ? 'No XP changes match this filter.'
            : 'No XP activity yet. Play a match, make a prediction, or open a pack.',
        textAlign: TextAlign.center,
        style: Cyber.body(13, color: Cyber.muted),
      ),
    );
  }
}

bool _matches(XpLedgerEntry entry, _XpHistoryFilter filter) {
  return switch (filter) {
    _XpHistoryFilter.all => true,
    _XpHistoryFilter.earned =>
      entry.delta > 0 && entry.type != XpTransactionType.openingBalance,
    _XpHistoryFilter.lost => entry.delta < 0,
    _XpHistoryFilter.games =>
      entry.source == XpTransactionSource.match ||
          entry.source == XpTransactionSource.shootout,
    _XpHistoryFilter.predictions =>
      entry.source == XpTransactionSource.prediction,
    _XpHistoryFilter.rewards =>
      entry.source == XpTransactionSource.pack ||
          entry.source == XpTransactionSource.dailyDrop ||
          entry.source == XpTransactionSource.streakReward ||
          entry.source == XpTransactionSource.cardUnlock,
  };
}

List<XpLedgerEntry> xpLedgerForRange(
  List<XpLedgerEntry> ledger,
  XpChartRange range,
) {
  final sorted = [...ledger]
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  if (sorted.isEmpty || range == XpChartRange.all) return sorted;
  final anchor = sorted.last.timestamp;
  final cutoff = anchor.subtract(
    range == XpChartRange.week
        ? const Duration(days: 7)
        : const Duration(days: 1),
  );
  final filtered = [
    for (final entry in sorted)
      if (!entry.timestamp.isBefore(cutoff)) entry,
  ];
  if (filtered.length >= 2) return filtered;
  if (sorted.length <= 2) return sorted;
  return sorted.sublist(sorted.length - 2);
}

List<int> xpBalanceValues(int totalXp, List<XpLedgerEntry> ledger) {
  if (ledger.isEmpty) return [totalXp];
  final sorted = [...ledger]
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return [for (final entry in sorted) entry.balanceAfter];
}

int selectedXpChartIndex(int? selectedIndex, int pointCount) {
  if (pointCount <= 0) return 0;
  if (selectedIndex == null) return pointCount - 1;
  return selectedIndex.clamp(0, pointCount - 1);
}

int xpChartIndexForDx({
  required double dx,
  required double width,
  required int pointCount,
}) {
  if (pointCount <= 1 || width <= 0) return 0;
  final percent = (dx / width).clamp(0.0, 1.0);
  return (percent * (pointCount - 1)).round();
}

IconData _sourceIcon(XpTransactionSource source) {
  return switch (source) {
    XpTransactionSource.match => Icons.sports_soccer,
    XpTransactionSource.shootout => Icons.sports_score,
    XpTransactionSource.prediction => Icons.analytics,
    XpTransactionSource.pack => Icons.inventory_2,
    XpTransactionSource.dailyDrop => Icons.calendar_today,
    XpTransactionSource.streakReward => Icons.local_fire_department,
    XpTransactionSource.cardUnlock => Icons.style,
    XpTransactionSource.openingBalance => Icons.history,
  };
}

String _timestampLabel(DateTime timestamp) {
  final local = timestamp.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day ${_months[local.month - 1]} $hour:$minute';
}

const _months = [
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
];

String _grouped(int value) {
  final raw = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    buffer.write(raw[i]);
    final fromEnd = raw.length - i;
    if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write(',');
  }
  return '${value < 0 ? '-' : ''}$buffer';
}

String _signed(int value) =>
    '${value >= 0 ? '+' : '−'}${_grouped(value.abs())}';

void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
  const dash = 6.0;
  const gap = 5.0;
  final total = (end - start).distance;
  if (total <= 0) return;
  final direction = (end - start) / total;
  var distance = 0.0;
  while (distance < total) {
    final from = start + direction * distance;
    final to = start + direction * math.min(distance + dash, total);
    canvas.drawLine(from, to, paint);
    distance += dash + gap;
  }
}
