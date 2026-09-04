import 'package:card_game/config/theme.dart';
import 'package:card_game/screens/predictions/widgets/basketball_match_stats_view.dart';
import 'package:card_game/screens/predictions/widgets/cricket_match_stats_view.dart';
import 'package:card_game/services/basketball_match_package_service.dart';
import 'package:card_game/services/cricket_match_package_service.dart';
import 'package:card_game/widgets/cyber/cyber_filter_chips.dart';
import 'package:flutter/material.dart';
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
    expect(find.textContaining('NBA Finals - Game 5'), findsOneWidget);
    await _scrollTo(tester, find.text('TEAM CONTROL'));
    expect(find.text('TEAM CONTROL'), findsOneWidget);

    _selectOuter(tester, 'FLOW');
    await _pump(tester);
    expect(
      find.byKey(const ValueKey('basketball-win-probability-graph')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('basketball-scoring-map')),
      findsOneWidget,
    );
    await _scrollTo(tester, find.text('TURNING POINTS'));
    expect(find.text('TURNING POINTS'), findsOneWidget);

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

  testWidgets('cricket HUD exposes all five complete data sections', (
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

    // Scrubbing the worm rewinds both innings to the same over.
    final race = find.byKey(const ValueKey('cricket-innings-race-graph'));
    await tester.tapAt(tester.getRect(race).centerLeft + const Offset(1, 0));
    await tester.pump();
    expect(find.textContaining('RCB 161/5'), findsNothing);
    expect(find.textContaining('OV'), findsWidgets);

    // CHASE is the second cricket chart: actual run rate against required.
    _selectOuter(tester, 'CHASE');
    await _pump(tester);
    expect(
      find.byKey(const ValueKey('cricket-late-chase-graph')),
      findsOneWidget,
    );
    expect(find.text('LATE CHASE'), findsOneWidget);
    expect(find.textContaining('ACTUAL RR'), findsOneWidget);
    expect(find.textContaining('REQUIRED RR'), findsOneWidget);

    _selectOuter(tester, 'SCORECARD');
    await _pump(tester);
    expect(
      find.byKey(const ValueKey('cricket-stats-scorecard')),
      findsOneWidget,
    );
    expect(find.textContaining('Gujarat Titans Innings'), findsOneWidget);

    _selectOuter(tester, 'MATCH FEED');
    await _pump(tester);
    expect(find.textContaining('18 BALL ENTRIES'), findsOneWidget);
    _selectInner(tester, 'NOTES');
    await _pump(tester);
    expect(find.textContaining('25 MATCH NOTES'), findsOneWidget);

    _selectOuter(tester, 'SQUADS');
    await _pump(tester);
    expect(find.byKey(const ValueKey('cricket-stats-squads')), findsOneWidget);
    expect(find.text('CAPTAIN'), findsOneWidget);
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
