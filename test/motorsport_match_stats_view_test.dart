import 'dart:typed_data';

import 'package:card_game/config/theme.dart';
import 'package:card_game/models/f1_race_package.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/screens/predictions/widgets/match_stats_shell.dart';
import 'package:card_game/screens/predictions/widgets/motorsport_match_stats_view.dart';
import 'package:card_game/services/f1_race_package_service.dart';
import 'package:card_game/widgets/cyber/cyber_chart.dart';
import 'package:card_game/widgets/cyber/cyber_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Italian GP as it reaches the app from the ESPN scoreboard: the event id
/// on `id`, the Grand Prix title on the home side, the series label on the
/// synthetic away side.
SportMatch _italianGp({String id = '600057442'}) => SportMatch(
  id: id,
  leagueId: 'f1',
  sport: Sport.motorsport,
  home: const SportTeam(
    id: 'f1_home',
    name: 'Pirelli Italian Grand Prix',
    shortName: 'F1',
    color: Color(0xFFE10600),
  ),
  away: const SportTeam(
    id: 'f1_away',
    name: 'F1',
    shortName: 'F1',
    color: Color(0xFF000000),
  ),
  kickoff: DateTime.utc(2026, 9, 6, 13),
  status: MatchStatus.finished,
);

Future<void> _pump(WidgetTester tester, SportMatch match) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // Warm the package cache outside the fake-async zone — reading the asset
  // bundle needs real I/O, and the widget's own lookup then resolves from
  // cache on the next microtask.
  await tester.runAsync(F1RacePackageService.all);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: MotorsportMatchStatsView(match: match, enableFeedback: false),
      ),
    ),
  );
  await _pumpAnimations(tester);
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await _pumpAnimations(tester);
}

/// Bounded rather than `pumpAndSettle`: the cyber surfaces carry always-on
/// glow and spark animations, so nothing on this screen ever settles. Same
/// approach the football and basketball stats-view tests take.
Future<void> _pumpAnimations(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(F1RacePackageService.clearCache);

  testWidgets('the race tab opens on the circuit and the classification', (
    tester,
  ) async {
    await _pump(tester, _italianGp());

    expect(find.byKey(const ValueKey('motorsport-stats-race')), findsOneWidget);

    // A Grand Prix is not a 1v1, so the two-sided team plate must stay away.
    expect(find.byType(MatchPulseHeader), findsNothing);

    // The race identity already reads on the page above this tab, so the hero
    // card drops the title and the location and leads with the circuit itself.
    expect(find.text('PIRELLI ITALIAN GRAND PRIX'), findsNothing);
    expect(find.text('MONZA, ITALY'), findsNothing);
    expect(find.text('Autodromo Nazionale Monza'), findsOneWidget);
    expect(find.text('LAP RECORD'), findsOneWidget);
    expect(find.text('1:20.901'), findsOneWidget);

    expect(find.text('WINNER'), findsOneWidget);
    expect(find.text('Kimi Antonelli'), findsWidgets);
    expect(find.text('FROM P19 · +18'), findsOneWidget);

    final gap = tester.widget<CyberChartPanel>(
      find.ancestor(
        of: find.byKey(const ValueKey('motorsport-gap-chart')),
        matching: find.byType(CyberChartPanel),
      ),
    );
    // Only lead-lap runners are plotted. Converting a lapped car's laps into
    // seconds would draw a deficit that never happened.
    // 14 cars with a measured gap, plus the leader at zero.
    expect(gap.caption, '15 ON THE LEAD LAP');
    expect(gap.series.single.values, hasLength(15));
    expect(gap.series.single.values.first, 0, reason: 'the leader is level');
    expect(gap.series.single.values.reduce((a, b) => a > b ? a : b), lessThan(90));
    expect(gap.series.single.readoutAt(1), '+3.857');
  });

  testWidgets('the weekend tab charts position across the six stages', (
    tester,
  ) async {
    await _pump(tester, _italianGp());
    await _openTab(tester, 'WEEKEND');

    expect(
      find.byKey(const ValueKey('motorsport-stats-weekend')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('motorsport-position-track-chart')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('motorsport-pace-chart')), findsOneWidget);

    // Every stage of the weekend is labelled, and the axis runs practice to
    // flag rather than pretending to know lap positions.
    final track = tester.widget<CyberChartPanel>(
      find.ancestor(
        of: find.byKey(const ValueKey('motorsport-position-track-chart')),
        matching: find.byType(CyberChartPanel),
      ),
    );
    expect(track.xAxisLabels, ['FP1', 'FP2', 'FP3', 'QUAL', 'GRID', 'FIN']);
    expect(track.caption, 'ANT +18 FROM THE GRID');
    expect(track.series, isNotEmpty);
    for (final series in track.series) {
      expect(
        series.values,
        hasLength(6),
        reason: '${series.label} must have a position at every stage',
      );
    }

    // The winner's line is the story: 5th in FP1 through to 1st at the flag,
    // by way of a 19th-place grid slot.
    final winner = track.series.firstWhere((s) => s.label == 'ANT');
    expect(winner.readoutAt(0), 'P5');
    expect(winner.readoutAt(3), 'P7');
    expect(winner.readoutAt(4), 'P19');
    expect(winner.readoutAt(5), 'P1');

    // Plotted inverted so P1 rides the top of the plot.
    expect(winner.values.last, greaterThan(winner.values[4]));
  });

  testWidgets('the position track excludes FP1-only reserves', (tester) async {
    await _pump(tester, _italianGp());
    await _openTab(tester, 'WEEKEND');

    final track = tester.widget<CyberChartPanel>(
      find.ancestor(
        of: find.byKey(const ValueKey('motorsport-position-track-chart')),
        matching: find.byType(CyberChartPanel),
      ),
    );
    // Reserves ran FP1 only. Their grid slot does not exist, so they are left
    // out rather than interpolated into a start they never made.
    const reserves = {'IWA', 'BRO', 'ARO', 'HER'};
    for (final series in track.series) {
      expect(reserves.contains(series.label), isFalse);
    }
  });

  testWidgets('the qualifying tab charts the cuts and positions gained', (
    tester,
  ) async {
    await _pump(tester, _italianGp());
    await _openTab(tester, 'QUALIFYING');

    expect(
      find.byKey(const ValueKey('motorsport-stats-qualifying')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('motorsport-qualifying-chart')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('motorsport-grid-delta-board')),
      findsOneWidget,
    );

    final qualifying = tester.widget<CyberChartPanel>(
      find.ancestor(
        of: find.byKey(const ValueKey('motorsport-qualifying-chart')),
        matching: find.byType(CyberChartPanel),
      ),
    );
    expect(qualifying.xAxisLabels, ['Q1', 'Q2', 'Q3']);
    // Six drop out at each cut. The counts live in the caption because an
    // edge-pinned marker draws its ring but never a label.
    expect(qualifying.caption, '6 OUT IN Q1 · 6 IN Q2');
    expect(qualifying.markers, hasLength(2));
    // Lap times read as lap times, not milliseconds.
    expect(qualifying.series.first.readoutAt(0), '1:22.612');

    // Positions gained is a bar board, not a polyline: drivers are separate
    // categories, so a line between them would imply a trend that isn't there.
    expect(find.text('POSITIONS GAINED'), findsOneWidget);
    expect(find.text('+18'), findsWidgets);
    expect(find.text('ANT'), findsWidgets);
  });

  testWidgets('a race with no package falls back to the scoreboard panels', (
    tester,
  ) async {
    final dutch = SportMatch(
      id: '600057443',
      leagueId: 'f1',
      sport: Sport.motorsport,
      home: const SportTeam(
        id: 'f1_home',
        name: 'Heineken Dutch Grand Prix',
        shortName: 'F1',
        color: Color(0xFFE10600),
      ),
      away: const SportTeam(
        id: 'f1_away',
        name: 'F1',
        shortName: 'F1',
        color: Color(0xFF000000),
      ),
      kickoff: DateTime.utc(2026, 8, 30, 13),
      status: MatchStatus.finished,
      f1Sessions: const [
        F1SessionResult(
          name: 'Race',
          results: ['1. Lando Norris · McLaren (1:28:12.345)'],
        ),
      ],
      f1DriverStandings: const ['1. Lando Norris · McLaren'],
    );

    await _pump(tester, dutch);

    expect(
      find.byKey(const ValueKey('motorsport-stats-fallback')),
      findsOneWidget,
    );
    expect(find.text('SESSION RESULTS'), findsOneWidget);
    expect(find.text('DRIVER STANDINGS'), findsOneWidget);
    expect(find.text('1. Lando Norris · McLaren (1:28:12.345)'), findsOneWidget);

    // No charts are drawn from display strings.
    expect(find.byType(CyberChartPanel), findsNothing);
  });

  testWidgets('a weekend with nothing run states so plainly', (tester) async {
    final upcoming = SportMatch(
      id: '600057499',
      leagueId: 'f1',
      sport: Sport.motorsport,
      home: const SportTeam(
        id: 'f1_home',
        name: 'Qatar Grand Prix',
        shortName: 'F1',
        color: Color(0xFFE10600),
      ),
      away: const SportTeam(
        id: 'f1_away',
        name: 'F1',
        shortName: 'F1',
        color: Color(0xFF000000),
      ),
      kickoff: DateTime.utc(2026, 11, 29, 13),
      status: MatchStatus.upcoming,
    );

    await _pump(tester, upcoming);

    expect(find.byType(CyberNoDataState), findsOneWidget);
    expect(find.text('WEEKEND NOT STARTED'), findsOneWidget);
  });

  group('the full-screen circuit map', () {
    // A stand-in for ESPN's diagram: the screen is handed bytes, so the test
    // does not need the CDN. The viewBox matches the real one, which is what
    // the start/finish marker is positioned against.
    final svg = Uint8List.fromList(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 160 96">'
              '<rect width="160" height="96" fill="#111"/></svg>'
          .codeUnits,
    );

    Future<F1RacePackage> italianPackage() async {
      final packages = await F1RacePackageService.all();
      return packages.firstWhere((p) => p.name.contains('Italian'));
    }

    testWidgets('opens on the lap, showing facts the card has no room for', (
      tester,
    ) async {
      final package = await tester.runAsync(italianPackage);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: F1TrackMapScreen(package: package!, svg: svg),
        ),
      );
      await _pumpAnimations(tester);

      expect(find.text('THE LAP'), findsOneWidget);
      // Real circuit values, and three of them appear nowhere else in the app.
      expect(find.text('RACE DISTANCE'), findsOneWidget);
      expect(find.text('306.72 KM'), findsOneWidget);
      expect(find.text('DIRECTION'), findsOneWidget);
      expect(find.text('CLOCKWISE'), findsOneWidget);
      expect(find.text('ESTABLISHED'), findsOneWidget);
      expect(find.text('1950'), findsOneWidget);
      expect(find.text('1:20.901'), findsOneWidget);
    });

    testWidgets('tapping the chequered marker reads out the start/finish', (
      tester,
    ) async {
      final package = await tester.runAsync(italianPackage);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: F1TrackMapScreen(package: package!, svg: svg),
        ),
      );
      await _pumpAnimations(tester);

      await tester.tap(find.bySemanticsLabel('Start finish line'));
      await _pumpAnimations(tester);

      expect(find.text('START / FINISH'), findsOneWidget);
      expect(find.text('POLE'), findsOneWidget);
      expect(find.text('WINNER'), findsOneWidget);
      // Antonelli started 19th and won, so he is both the winner and the
      // biggest climber of the race.
      expect(find.text('BIGGEST GAIN'), findsOneWidget);
      expect(find.text('FROM P19'), findsOneWidget);
      expect(find.text('P19 → P1 · +18'), findsOneWidget);

      // And back to the lap by tapping the drawing away from the marker. The
      // centre of the viewer is the middle of the letterboxed map box, which
      // the marker (at 0.78, 0.83 of it) is nowhere near.
      await tester.tap(find.byType(InteractiveViewer));
      // Twice: the tap only resolves once the double-tap timeout lapses, so
      // the first round starts the switch and the second finishes it.
      await _pumpAnimations(tester);
      await _pumpAnimations(tester);
      expect(find.text('THE LAP'), findsOneWidget);
      expect(find.text('START / FINISH'), findsNothing);
    });

    testWidgets('double tap zooms the map about the point tapped', (
      tester,
    ) async {
      final package = await tester.runAsync(italianPackage);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: F1TrackMapScreen(package: package!, svg: svg),
        ),
      );
      await _pumpAnimations(tester);

      final controller = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      expect(controller.value.getMaxScaleOnAxis(), 1);

      final centre = tester.getCenter(find.byType(InteractiveViewer));
      await tester.tapAt(centre);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tapAt(centre);
      await _pumpAnimations(tester);
      expect(controller.value.getMaxScaleOnAxis(), greaterThan(2));

      // And again to reset.
      await tester.tapAt(centre);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tapAt(centre);
      await _pumpAnimations(tester);
      expect(controller.value.getMaxScaleOnAxis(), 1);
    });

    testWidgets('there is no per-sector readout, because there is no data', (
      tester,
    ) async {
      final package = await tester.runAsync(italianPackage);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: F1TrackMapScreen(package: package!, svg: svg),
        ),
      );
      await _pumpAnimations(tester);

      // ESPN publishes no sector splits, and the SVG's S1/S2/S3 are text
      // outlines rather than track segments. Nothing here may invent one.
      for (final label in ['SECTOR 1', 'SECTOR 2', 'SECTOR 3', 'SECTOR']) {
        expect(find.text(label), findsNothing);
      }
      // The map carries exactly one tap target.
      expect(find.bySemanticsLabel('Start finish line'), findsOneWidget);
    });
  });
}
