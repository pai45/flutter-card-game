import 'dart:convert';

import 'package:card_game/config/theme.dart';
import 'package:card_game/data/team_palettes.dart';
import 'package:card_game/screens/predictions/widgets/basketball_match_stats_view.dart';
import 'package:card_game/screens/predictions/widgets/cricket_match_stats_view.dart';
import 'package:card_game/services/basketball_match_package_service.dart';
import 'package:card_game/services/cricket_match_package_service.dart';
import 'package:card_game/widgets/cyber/cyber_chart.dart';
import 'package:card_game/widgets/cyber/cyber_filter_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('basketball HUD exposes all five complete data sections', (
    tester,
  ) async {
    _mobile(tester);
    final match = (await tester.runAsync(
      () => const BasketballMatchPackageService().loadBundled(),
    ))!;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: BasketballMatchStatsView(match: match, enableFeedback: false),
        ),
      ),
    );
    await _pump(tester);

    expect(
      find.byKey(const ValueKey('basketball-stats-overview')),
      findsOneWidget,
    );
    expect(find.text('GAME INTEL'), findsOneWidget);
    expect(find.textContaining('NBA Finals - Game 5'), findsNothing);
    await _scrollTo(tester, find.text('TEAM CONTROL'));
    expect(find.text('TEAM CONTROL'), findsOneWidget);

    _selectOuter(tester, 'FLOW');
    await _pump(tester);
    expect(
      find.byKey(const ValueKey('basketball-scoring-run-graph')),
      findsOneWidget,
    );
    expect(find.text('SCORING RUN'), findsOneWidget);
    expect(find.text('SCORING EDGE'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('basketball-scoring-map')),
      findsOneWidget,
    );
    await _scrollTo(tester, find.text('TURNING POINTS'));
    expect(find.text('TURNING POINTS'), findsOneWidget);
    // FLOW is score-driven now; no win-probability readout survives anywhere.
    expect(find.text('WIN PROBABILITY'), findsNothing);
    expect(find.textContaining('%'), findsNothing);

    _selectOuter(tester, 'PLAYS');
    await _pump(tester);
    expect(find.text('96'), findsOneWidget);
    expect(find.text('SCORING PLAYS'), findsOneWidget);

    _selectOuter(tester, 'BOX SCORE');
    await _pump(tester);
    expect(
      find.byKey(const ValueKey('basketball-stats-box-score')),
      findsOneWidget,
    );
    expect(find.text('Q1'), findsWidgets);

    _selectOuter(tester, 'TEAMS');
    await _pump(tester);
    expect(
      find.byKey(const ValueKey('basketball-stats-teams')),
      findsOneWidget,
    );
    expect(find.text('AVAILABILITY REPORT'), findsOneWidget);
    // Roster rows carry each player's stat line under the availability report.
    expect(find.textContaining('PTS'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cricket HUD exposes four sections with both race charts', (
    tester,
  ) async {
    _mobile(tester);
    final match = (await tester.runAsync(
      () => const CricketMatchPackageService().loadBundled(),
    ))!;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: CricketMatchStatsView(match: match, enableFeedback: false),
        ),
      ),
    );
    await _pump(tester);

    expect(
      find.byKey(const ValueKey('cricket-stats-overview')),
      findsOneWidget,
    );
    expect(find.text('MATCH INTEL'), findsOneWidget);
    expect(find.textContaining('Indian Premier League'), findsOneWidget);
    expect(find.text('INNINGS GRID'), findsNothing);
    await _scrollTo(tester, find.text('TEAM COMPARISON'));
    expect(find.text('TEAM COMPARISON'), findsOneWidget);

    _selectOuter(tester, 'RACE');
    await _pump(tester);
    expect(
      find.byKey(const ValueKey('cricket-innings-race-graph')),
      findsOneWidget,
    );
    expect(find.text('INNINGS RACE'), findsOneWidget);
    expect(find.textContaining('RCB 161/5'), findsOneWidget);
    expect(find.textContaining('GT 155/8'), findsOneWidget);
    expect(find.text('RACE VERDICT'), findsNothing);

    final painter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byKey(
                      const ValueKey('cricket-innings-race-graph'),
                    ),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as CyberChartPainter;
    final homeColor = paletteForTeam(
      match.home,
      sport: match.sport,
      competition: match.leagueId,
    ).secondaryTextColor;
    final awayColor = paletteForTeam(
      match.away,
      sport: match.sport,
      competition: match.leagueId,
    ).secondaryTextColor;
    final homeWickets = painter.markers
        .where((marker) => marker.alignTop)
        .toList();
    final awayWickets = painter.markers
        .where((marker) => !marker.alignTop)
        .toList();
    expect(homeWickets, isNotEmpty);
    expect(awayWickets, isNotEmpty);
    expect(homeWickets.map((marker) => marker.color), everyElement(homeColor));
    expect(awayWickets.map((marker) => marker.color), everyElement(awayColor));

    // Scrubbing the worm rewinds both innings to the same over.
    final race = find.byKey(const ValueKey('cricket-innings-race-graph'));
    await tester.tapAt(tester.getRect(race).centerLeft + const Offset(1, 0));
    await tester.pump();
    expect(find.textContaining('RCB 161/5'), findsNothing);
    expect(find.textContaining('OV'), findsWidgets);

    expect(find.text('CHASE'), findsNothing);
    await _scrollTo(tester, find.text('INNINGS RUN RATE'));
    expect(
      find.byKey(const ValueKey('cricket-innings-run-rate-graph')),
      findsOneWidget,
    );
    expect(find.text('INNINGS RUN RATE'), findsOneWidget);
    expect(find.text('1ST INNINGS'), findsOneWidget);
    expect(find.text('2ND INNINGS'), findsOneWidget);

    CyberChartPainter ratePainter() =>
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byKey(
                      const ValueKey('cricket-innings-run-rate-graph'),
                    ),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as CyberChartPainter;

    expect(ratePainter().series, hasLength(1));
    expect(ratePainter().series.single.label, 'RUN RATE');
    expect(ratePainter().series.single.color, awayColor);
    expect(ratePainter().markers, hasLength(18));
    expect(
      ratePainter().markers.map((marker) => marker.label),
      everyElement(anyOf('4', '6')),
    );
    expect(
      ratePainter().markers.map((marker) => marker.value),
      everyElement(isNotNull),
    );

    tester
        .widget<CyberChartPanel>(
          find.widgetWithText(CyberChartPanel, 'INNINGS RUN RATE'),
        )
        .onRangeChanged!('2ND INNINGS');
    await _pump(tester);
    expect(ratePainter().series, hasLength(2));
    expect(ratePainter().series.first.color, homeColor);
    expect(ratePainter().series.last.label, 'REQUIRED RATE');
    expect(ratePainter().series.last.color, Cyber.magenta);
    expect(ratePainter().markers, hasLength(25));

    _selectOuter(tester, 'SCORECARD');
    await _pump(tester);
    expect(
      find.byKey(const ValueKey('cricket-stats-scorecard')),
      findsOneWidget,
    );
    expect(find.textContaining('Gujarat Titans Innings'), findsOneWidget);

    _selectOuter(tester, 'MATCH FEED');
    await _pump(tester);
    expect(find.textContaining('RCB // 18 BALL ENTRIES'), findsOneWidget);
    expect(find.text('NOTES'), findsNothing);
    expect(find.text('RCB'), findsOneWidget);
    expect(find.text('GT'), findsOneWidget);
    _selectInner(tester, 'GT');
    await _pump(tester);
    expect(find.text('COMMENTARY UNAVAILABLE'), findsOneWidget);

    expect(find.text('SQUADS'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sport HUDs keep contextual empty states for partial feeds', (
    tester,
  ) async {
    final basketball = (await tester.runAsync(
      () => const BasketballMatchPackageService().loadBundled(),
    ))!;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: BasketballMatchStatsView(
            match: basketball.copyWith(clearBasketballDetails: true),
            enableFeedback: false,
          ),
        ),
      ),
    );
    _selectOuter(tester, 'FLOW');
    await _pump(tester);
    expect(find.text('FLOW FEED UNAVAILABLE'), findsOneWidget);

    final cricket = (await tester.runAsync(
      () => const CricketMatchPackageService().loadBundled(),
    ))!;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: CricketMatchStatsView(
            match: cricket.copyWith(clearCricketDetails: true),
            enableFeedback: false,
          ),
        ),
      ),
    );
    _selectOuter(tester, 'RACE');
    await _pump(tester);
    expect(find.text('RACE DATA UNAVAILABLE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('innings race remains when delivery progression is unavailable', (
    tester,
  ) async {
    _mobile(tester);
    final source = (await tester.runAsync(
      () => rootBundle.loadString(CricketMatchPackageService.assetPath),
    ))!;
    final root = jsonDecode(source) as Map<String, dynamic>
      ..remove('inningsRateProgress');
    final match = const CricketMatchPackageService().decode(jsonEncode(root));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: CricketMatchStatsView(match: match, enableFeedback: false),
        ),
      ),
    );

    _selectOuter(tester, 'RACE');
    await _pump(tester);
    expect(
      find.byKey(const ValueKey('cricket-innings-race-graph')),
      findsOneWidget,
    );
    expect(find.text('RUN-RATE DATA UNAVAILABLE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _mobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _selectOuter(WidgetTester tester, String section) {
  tester
      .widget<CyberFilterChips>(find.byType(CyberFilterChips).first)
      .onSelect(section);
}

void _selectInner(WidgetTester tester, String section) {
  tester
      .widget<CyberFilterChips>(find.byType(CyberFilterChips).last)
      .onSelect(section);
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    260,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pump();
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1100));
}
