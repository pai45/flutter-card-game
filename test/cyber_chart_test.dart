import 'package:card_game/config/theme.dart';
import 'package:card_game/widgets/cyber/cyber_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('chart index maths', () {
    test('chartPointCount takes the longest series', () {
      expect(
        chartPointCount(const [
          ChartSeries(label: 'A', color: Cyber.cyan, values: [1, 2]),
          ChartSeries(label: 'B', color: Cyber.gold, values: [1, 2, 3, 4]),
        ]),
        4,
      );
      expect(chartPointCount(const []), 0);
    });

    test('a null selection reads the latest point', () {
      expect(selectedChartIndex(null, 5), 4);
      expect(selectedChartIndex(null, 0), isNull);
    });

    test('an out-of-range selection clamps into the series', () {
      expect(selectedChartIndex(99, 5), 4);
      expect(selectedChartIndex(-3, 5), 0);
    });

    test('a drag position maps onto the nearest index', () {
      expect(indexForChartDx(dx: 0, width: 100, pointCount: 5), 0);
      expect(indexForChartDx(dx: 50, width: 100, pointCount: 5), 2);
      expect(indexForChartDx(dx: 100, width: 100, pointCount: 5), 4);
      // Past either edge the scrub stays inside the series.
      expect(indexForChartDx(dx: -20, width: 100, pointCount: 5), 0);
      expect(indexForChartDx(dx: 400, width: 100, pointCount: 5), 4);
      // A degenerate chart can't be scrubbed off its single point.
      expect(indexForChartDx(dx: 40, width: 100, pointCount: 1), 0);
      expect(indexForChartDx(dx: 40, width: 0, pointCount: 5), 0);
    });

    test('seriesValueAt clamps and defaults to the last value', () {
      const series = ChartSeries(
        label: 'A',
        color: Cyber.cyan,
        values: [10, 20, 30],
      );
      expect(seriesValueAt(series, null), 30);
      expect(seriesValueAt(series, 1), 20);
      expect(seriesValueAt(series, 42), 30);
    });
  });

  group('legend readout', () {
    test('formats through the series readout, index included', () {
      const scores = ['61/1', '84/2', '112/4'];
      final series = ChartSeries(
        label: 'RCB',
        color: Cyber.cyan,
        values: const [61, 84, 112],
        readout: (value, index) => scores[index],
      );
      expect(series.readoutAt(1), '84/2');
      expect(series.readoutAt(null), '112/4');
      expect(series.readoutAt(9), '112/4');
    });

    test('falls back to a rounded value with no readout', () {
      const series = ChartSeries(
        label: 'A',
        color: Cyber.cyan,
        values: [61.4, 84.6],
      );
      expect(series.readoutAt(0), '61');
      expect(series.readoutAt(1), '85');
    });

    test('an empty series reads as a dash', () {
      const series = ChartSeries(label: 'A', color: Cyber.cyan, values: []);
      expect(series.readoutAt(null), '—');
    });
  });

  testWidgets('scrubbing the plot updates the legend readout', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: CyberChartPanel(
            chartKey: const ValueKey('test_chart'),
            title: 'WIN PROBABILITY',
            caption: '3 PLAYS',
            markerSound: false,
            series: [
              ChartSeries(
                label: 'HOME',
                color: Cyber.cyan,
                values: const [20, 50, 80],
                readout: (value, _) => '${value.round()}%',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    // With nothing selected the legend reads the latest point.
    expect(find.text('HOME 80%'), findsOneWidget);

    final chart = find.byKey(const ValueKey('test_chart'));
    await tester.tapAt(tester.getRect(chart).centerLeft + const Offset(1, 0));
    await tester.pump();
    expect(find.text('HOME 20%'), findsOneWidget);

    await tester.tapAt(tester.getCenter(chart));
    await tester.pump();
    expect(find.text('HOME 50%'), findsOneWidget);
  });

  testWidgets('range tabs report the selected range', (tester) async {
    var selected = 'GAME';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => CyberChartPanel(
              title: 'FLOW',
              ranges: const ['GAME', 'H1', 'H2'],
              activeRange: selected,
              onRangeChanged: (range) => setState(() => selected = range),
              series: const [
                ChartSeries(
                  label: 'HOME',
                  color: Cyber.cyan,
                  values: [10, 20, 30],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('GAME'), findsOneWidget);
    await tester.tap(find.text('H2'));
    await tester.pump();
    expect(selected, 'H2');
  });

  testWidgets('the expand button opens the full-screen chart', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: CyberChartPanel(
            title: 'MATCH MOMENTUM',
            series: const [
              ChartSeries(label: 'HOME', color: Cyber.cyan, values: [1, 2, 3]),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.open_in_full));
    await tester.pumpAndSettle();

    expect(find.byType(CyberChartFullScreen), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });
}
