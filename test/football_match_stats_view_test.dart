import 'package:card_game/config/theme.dart';
import 'package:card_game/data/team_palettes.dart';
import 'package:card_game/screens/predictions/widgets/football_match_stats_view.dart';
import 'package:card_game/screens/predictions/widgets/match_stats_shell.dart';
import 'package:card_game/services/football_match_package_service.dart';
import 'package:card_game/widgets/cyber/cyber_filter_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('football stats HUD exposes all five supplied data views', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final match = (await tester.runAsync(
      () => const FootballMatchPackageService().loadBundled(),
    ))!;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: FootballMatchStatsView(match: match)),
      ),
    );
    await _pumpAnimations(tester);

    expect(
      find.byKey(const ValueKey('football-stats-overview')),
      findsOneWidget,
    );
    expect(find.text('MATCH INTEL'), findsOneWidget);
    expect(find.byType(MatchPulseHeader), findsNothing);
    expect(find.textContaining('Craven Cottage'), findsOneWidget);
    expect(find.text('27,461'), findsOneWidget);
    // The comparison and scorer blocks sit below the fold of the lazy list.
    await _scrollTo(tester, find.text('TEAM CONTROL'));
    expect(find.text('TEAM CONTROL'), findsOneWidget);
    final homeIdentity = paletteForTeam(
      match.home,
      sport: match.sport,
      competition: match.leagueId,
    ).secondaryTextColor;
    final awayIdentity = paletteForTeam(
      match.away,
      sport: match.sport,
      competition: match.leagueId,
    ).secondaryTextColor;
    expect(
      tester
          .widgetList<Text>(find.text(match.home.shortName.toUpperCase()))
          .any((text) => text.style?.color == homeIdentity),
      isTrue,
    );
    expect(
      tester
          .widgetList<Text>(find.text(match.away.shortName.toUpperCase()))
          .any((text) => text.style?.color == awayIdentity),
      isTrue,
    );
    await _scrollTo(tester, find.text('GOAL IMPACT'));
    expect(find.text('GOAL IMPACT'), findsOneWidget);

    _selectSection(tester, 'MOMENTUM');
    await _pumpAnimations(tester);
    expect(
      find.byKey(const ValueKey('football-momentum-graph')),
      findsOneWidget,
    );
    expect(find.textContaining('98/SAMPLES'), findsOneWidget);
    // The shot map sits between the graph and the goal markers, so the
    // scorer chips now start below the fold of the lazy list.
    expect(find.text('SHOT MAP'), findsOneWidget);
    await _scrollTo(tester, find.textContaining('João Pedro'));
    expect(find.textContaining('João Pedro'), findsOneWidget);

    _selectSection(tester, 'EVENTS');
    await _pumpAnimations(tester);
    expect(find.byKey(const ValueKey('football-stats-events')), findsOneWidget);
    expect(find.text('023 EVENTS'), findsOneWidget);
    expect(find.byType(StatsRowShell), findsNothing);

    _selectSection(tester, 'LINEUPS');
    await _pumpAnimations(tester);
    expect(find.byKey(const ValueKey('match-lineup-370')), findsOneWidget);
    expect(find.text('CONFIRMED'), findsOneWidget);
    expect(find.textContaining('20 PLAYER SQUAD'), findsOneWidget);

    _selectSection(tester, 'COMMENTARY');
    await _pumpAnimations(tester);
    expect(
      find.byKey(const ValueKey('football-stats-commentary')),
      findsOneWidget,
    );
    expect(find.text('104 ENTRIES'), findsOneWidget);
    expect(find.byType(StatsRowShell), findsNothing);
    expect(
      find.text('Lineups are announced and players are warming up.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('football stats render safe empty states for partial feeds', (
    tester,
  ) async {
    final complete = (await tester.runAsync(
      () => const FootballMatchPackageService().loadBundled(),
    ))!;
    final partial = complete.copyWith(
      teamStats: const [],
      timelineEvents: const [],
      commentary: const [],
      clearFootballDetails: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: FootballMatchStatsView(match: partial)),
      ),
    );
    await _pumpAnimations(tester);
    expect(find.text('MATCH INTEL'), findsOneWidget);
    final overview = tester.widget<ListView>(
      find.byKey(const ValueKey('football-stats-overview')),
    );
    final overviewChildren =
        (overview.childrenDelegate as SliverChildListDelegate).children;
    expect(
      overviewChildren.indexWhere(
        (child) => child.key == const ValueKey('football-match-intel-heading'),
      ),
      lessThan(
        overviewChildren.indexWhere(
          (child) =>
              child.key ==
              const ValueKey('football-scoreboard-channel-heading'),
        ),
      ),
    );

    _selectSection(tester, 'EVENTS');
    await _pumpAnimations(tester);
    expect(find.text('EVENT LOG PENDING'), findsOneWidget);

    _selectSection(tester, 'COMMENTARY');
    await _pumpAnimations(tester);
    expect(find.text('MATCH COMMS SILENT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _selectSection(WidgetTester tester, String section) {
  final chips = tester.widget<CyberFilterChips>(
    find.byType(CyberFilterChips).first,
  );
  chips.onSelect(section);
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    260,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pump();
}

Future<void> _pumpAnimations(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1100));
}
