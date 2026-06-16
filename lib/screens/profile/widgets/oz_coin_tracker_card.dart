import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/oz_coin_ledger.dart';
import '../../predictions/widgets/history_hud.dart' show HistoryStatCell;
import '../../predictions/widgets/pick_status_style.dart'
    show formatOzCompact, formatOzGrouped;
import '../../shop/shop_screen.dart' show CoinIcon;
import 'profile_card.dart';

class OzCoinTrackerCard extends StatefulWidget {
  const OzCoinTrackerCard({
    required this.balance,
    required this.ledger,
    required this.onViewHistory,
    super.key,
  });

  final int balance;
  final List<OzCoinLedgerEntry> ledger;
  final VoidCallback onViewHistory;

  @override
  State<OzCoinTrackerCard> createState() => _OzCoinTrackerCardState();
}

class _OzCoinTrackerCardState extends State<OzCoinTrackerCard> {
  CoinChartRange _range = CoinChartRange.all;

  @override
  Widget build(BuildContext context) {
    final balance = widget.balance;
    final ledger = widget.ledger;
    final earned = _positiveActivity(ledger);
    final spent = _negativeActivity(ledger);
    return ProfileCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CoinIcon(size: 20),
              const SizedBox(width: 9),
              Text(
                'OZ COIN TRACKER',
                style: Cyber.display(15, color: Cyber.gold, letterSpacing: 1),
              ),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onViewHistory,
                child: Row(
                  children: [
                    Text(
                      'HISTORY',
                      style: Cyber.label(
                        10,
                        color: Cyber.gold.withValues(alpha: 0.9),
                        letterSpacing: 1.4,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Cyber.gold,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TrackerRangeTabs(
            active: _range,
            onChanged: (range) => setState(() => _range = range),
          ),
          const SizedBox(height: 12),
          CoinBalanceChart(
            balance: balance,
            ledger: ledger,
            range: _range,
            height: 176,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: HistoryStatCell(
                  label: 'BALANCE',
                  value: formatOzCompact(balance),
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
        ],
      ),
    );
  }
}

class CoinBalanceChart extends StatefulWidget {
  const CoinBalanceChart({
    required this.balance,
    required this.ledger,
    required this.range,
    this.height = 220,
    super.key,
  });

  final int balance;
  final List<OzCoinLedgerEntry> ledger;
  final CoinChartRange range;
  final double height;

  @override
  State<CoinBalanceChart> createState() => _CoinBalanceChartState();
}

class _CoinBalanceChartState extends State<CoinBalanceChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final entries = coinLedgerForRange(widget.ledger, widget.range);
    final pointCount = coinBalanceValues(widget.balance, entries).length;
    final selectedIndex = selectedCoinChartIndex(_selectedIndex, pointCount);
    return LayoutBuilder(
      builder: (context, constraints) {
        void selectAt(Offset position) {
          final index = coinChartIndexForDx(
            dx: position.dx,
            width: constraints.maxWidth,
            pointCount: pointCount,
          );
          if (index == _selectedIndex) return;
          setState(() => _selectedIndex = index);
        }

        final value = coinBalanceValues(widget.balance, entries)[selectedIndex];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => selectAt(details.localPosition),
              onHorizontalDragUpdate: (details) =>
                  selectAt(details.localPosition),
              child: _CoinBalanceChart(
                balance: widget.balance,
                ledger: entries,
                height: widget.height,
                selectedIndex: selectedIndex,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'BALANCE',
                  style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.2),
                ),
                const Spacer(),
                Text(
                  '${formatOzGrouped(value)} OZ',
                  style: Cyber.display(18, color: Cyber.gold).copyWith(
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

class _CoinBalanceChart extends StatelessWidget {
  const _CoinBalanceChart({
    required this.balance,
    required this.ledger,
    required this.height,
    required this.selectedIndex,
  });

  final int balance;
  final List<OzCoinLedgerEntry> ledger;
  final double height;
  final int? selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xff10192d),
        border: Border.all(color: Cyber.border),
      ),
      child: CustomPaint(
        painter: CoinBalanceChartPainter(
          values: coinBalanceValues(balance, ledger),
          selectedIndex: selectedIndex,
        ),
      ),
    );
  }
}

class CoinBalanceChartPainter extends CustomPainter {
  const CoinBalanceChartPainter({
    required this.values,
    required this.selectedIndex,
  });

  final List<int> values;
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

    final safeValues = values.isEmpty ? const [0] : values;
    final minValue = math.max(
      0,
      safeValues.reduce((a, b) => a < b ? a : b) - 20,
    );
    final maxValue = safeValues.reduce((a, b) => a > b ? a : b) + 20;
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
      final previous = points[i - 1];
      final point = points[i];
      path.lineTo(point.dx, previous.dy);
      path.lineTo(point.dx, point.dy);
    }
    if (points.length > 1) {
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
              Cyber.gold.withValues(alpha: 0.18),
              Cyber.gold.withValues(alpha: 0),
            ],
          ).createShader(Offset.zero & size),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Cyber.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );

    final index = selectedCoinChartIndex(selectedIndex, safeValues.length);
    final selectedX = safeValues.length <= 1
        ? size.width
        : size.width * index / (safeValues.length - 1);
    _drawDashedLine(
      canvas,
      Offset(selectedX, 0),
      Offset(selectedX, size.height),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..strokeWidth = 2,
    );
    final markerY =
        size.height - ((safeValues[index] - minValue) / spread) * size.height;
    final center = Offset(selectedX, markerY);
    canvas.drawCircle(
      center,
      9,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(center, 4, Paint()..color = Cyber.gold);
  }

  @override
  bool shouldRepaint(covariant CoinBalanceChartPainter old) =>
      old.values != values || old.selectedIndex != selectedIndex;
}

enum CoinChartRange { all, week, day }

class _TrackerRangeTabs extends StatelessWidget {
  const _TrackerRangeTabs({required this.active, required this.onChanged});

  final CoinChartRange active;
  final ValueChanged<CoinChartRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final range in CoinChartRange.values) ...[
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(range),
              child: Container(
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active == range
                      ? Cyber.gold.withValues(alpha: 0.14)
                      : Colors.transparent,
                  border: Border.all(
                    color: active == range
                        ? Cyber.gold.withValues(alpha: 0.72)
                        : Cyber.line.withValues(alpha: 0.28),
                  ),
                ),
                child: Text(
                  _rangeLabel(range),
                  style: Cyber.label(
                    10,
                    color: active == range ? Cyber.gold : Cyber.muted,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
          if (range != CoinChartRange.values.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

String _rangeLabel(CoinChartRange range) => switch (range) {
  CoinChartRange.all => 'ALL',
  CoinChartRange.week => 'WEEK',
  CoinChartRange.day => 'DAY',
};

List<OzCoinLedgerEntry> coinLedgerForRange(
  List<OzCoinLedgerEntry> ledger,
  CoinChartRange range,
) {
  final sorted = [...ledger]
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  if (sorted.isEmpty || range == CoinChartRange.all) return sorted;
  final anchor = sorted.last.timestamp;
  final cutoff = anchor.subtract(
    range == CoinChartRange.week
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

List<int> coinBalanceValues(int balance, List<OzCoinLedgerEntry> ledger) {
  if (ledger.isEmpty) return [balance];
  final sorted = [...ledger]
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return [for (final entry in sorted) entry.balanceAfter];
}

int selectedCoinChartIndex(int? selectedIndex, int pointCount) {
  if (pointCount <= 0) return 0;
  if (selectedIndex == null) return pointCount - 1;
  return selectedIndex.clamp(0, pointCount - 1);
}

int coinChartIndexForDx({
  required double dx,
  required double width,
  required int pointCount,
}) {
  if (pointCount <= 1 || width <= 0) return 0;
  final percent = (dx / width).clamp(0.0, 1.0);
  return (percent * (pointCount - 1)).round();
}

int _positiveActivity(List<OzCoinLedgerEntry> ledger) => ledger
    .where((entry) => entry.delta > 0)
    .where((entry) => entry.type != OzCoinTransactionType.openingBalance)
    .fold(0, (sum, entry) => sum + entry.delta);

int _negativeActivity(List<OzCoinLedgerEntry> ledger) => ledger
    .where((entry) => entry.delta < 0)
    .fold(0, (sum, entry) => sum + entry.delta.abs());

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
