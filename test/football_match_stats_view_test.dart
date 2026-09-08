import 'package:card_game/config/theme.dart';
import 'package:card_game/data/team_palettes.dart';
import 'package:card_game/screens/predictions/widgets/football_match_stats_view.dart';
import 'package:card_game/widgets/cyber/player_match_sheet.dart';
import 'package:card_game/screens/predictions/widgets/match_stats_shell.dart';
import 'package:card_game/services/football_match_package_service.dart';
import 'package:card_game/widgets/cyber/cyber_filter_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('football stats HUD exposes all four supplied data views', (
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
    // The event timeline replaced the scorer block in the same slot.
    expect(find.text('GOAL IMPACT'), findsNothing);
    await _scrollTo(tester, find.text('MATCH TIMELINE'));
    expect(find.text('MATCH TIMELINE'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('football-match-timeline')),
      findsOneWidget,
    );
    expect(
      find.text(
        '${(match.timelineEvents?.length ?? 0).toString().padLeft(3, '0')} EVENTS',
      ),
      findsOneWidget,
    );
    // The compact timeline relies on its centre spine rather than a repeated
    // team/minute legend or an instructional caption.
    expect(find.text('MIN'), findsNothing);
    expect(find.text('TAP A MOMENT FOR THE FULL REPORT'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('football-match-timeline')),
        matching: find.text(match.home.shortName.toUpperCase()),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('football-match-timeline')),
        matching: find.text(match.away.shortName.toUpperCase()),
      ),
      findsNothing,
    );
    final timelineCentre = tester.view.physicalSize.width / 2;
    final homeMark = find.descendant(
      of: find.byKey(const ValueKey('football-match-timeline')),
      matching: find.text('JOSH KING'),
    );
    final awayMark = find.descendant(
      of: find.byKey(const ValueKey('football-match-timeline')),
      matching: find.text('JOÃO PEDRO'),
    );
    await _scrollTo(tester, homeMark);
    expect(tester.getRect(homeMark).right, lessThan(timelineCentre));
    await _scrollTo(tester, awayMark);
    expect(tester.getRect(awayMark).left, greaterThan(timelineCentre));

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

  testWidgets(
    'match intel stacks venue above attendance without a winner tag',
    (tester) async {
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

      final venue = tester.getRect(find.text('VENUE'));
      final attendance = tester.getRect(find.text('ATTENDANCE'));
      expect(attendance.top, greaterThan(venue.bottom));
      expect(attendance.left, closeTo(venue.left, 1));
      expect(find.textContaining('SECURED THE RESULT'), findsNothing);
    },
  );

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

    await _scrollTo(tester, find.text('EVENT LOG PENDING'));
    expect(find.text('EVENT LOG PENDING'), findsOneWidget);

    _selectSection(tester, 'COMMENTARY');
    await _pumpAnimations(tester);
    expect(find.text('MATCH COMMS SILENT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a moment unpacks the report behind it', (tester) async {
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

    // The prose stays folded away until the moment is asked about, which is
    // what keeps 22 events readable as a timeline rather than a wall of text.
    expect(find.textContaining('right footed shot'), findsNothing);
    await _scrollTo(tester, find.text('JOÃO PEDRO'));
    await tester.tap(find.text('JOÃO PEDRO'));
    await tester.pumpAndSettle();
    expect(find.textContaining('right footed shot'), findsOneWidget);

    await tester.tap(find.text('JOÃO PEDRO'));
    await tester.pumpAndSettle();
    expect(find.textContaining('right footed shot'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a substitution names who came on and who came off', (
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

    // Fulham's 67th minute: Shea Charles on for Oscar Bobb.
    await _scrollTo(tester, find.text('SHEA CHARLES'));
    expect(
      tester.widget<Text>(find.text('SHEA CHARLES')).style?.color,
      Cyber.lime,
    );
    expect(
      tester.widget<Text>(find.text('OSCAR BOBB')).style?.color,
      Cyber.danger,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a player on the pitch opens their match dossier', (
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
    _selectSection(tester, 'LINEUPS');
    await _pumpAnimations(tester);

    // Bernd Leno, Fulham's keeper.
    await tester.tap(find.byKey(const ValueKey('pitch-player-153765')));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerMatchSheetScaffold), findsOneWidget);
    expect(find.text('BERND LENO'), findsOneWidget);
    expect(find.text('STARTER'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('football-player-heatmap')),
      findsOneWidget,
    );
    // A keeper's sheet carries the goalkeeping board.
    expect(find.text('GOALKEEPING'), findsOneWidget);
    expect(find.text('SAVES'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the dossier pages across the squad', (tester) async {
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
    _selectSection(tester, 'LINEUPS');
    await _pumpAnimations(tester);

    await tester.tap(find.byKey(const ValueKey('pitch-player-153765')));
    await tester.pumpAndSettle();
    expect(find.text('BERND LENO'), findsOneWidget);
    expect(find.textContaining('1 OF 20'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('BERND LENO'), findsNothing);
    expect(find.textContaining('2 OF 20'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unused substitute gets an honest card, not an empty pitch', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final match = (await tester.runAsync(
      () => const FootballMatchPackageService().loadBundled(),
    ))!;
    final unused = match.homeLineup!.substitutes.firstWhere(
      (player) => !player.matchStats!.played,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: FootballMatchStatsView(match: match)),
      ),
    );
    await _pumpAnimations(tester);
    _selectSection(tester, 'LINEUPS');
    await _pumpAnimations(tester);

    await _scrollTo(tester, find.byKey(ValueKey('bench-player-${unused.id}')));
    await tester.tap(find.byKey(ValueKey('bench-player-${unused.id}')));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerMatchSheetScaffold), findsOneWidget);
    expect(find.text('UNUSED'), findsOneWidget);
    expect(find.text('UNUSED SUBSTITUTE'), findsOneWidget);
    expect(find.byKey(const ValueKey('football-player-heatmap')), findsNothing);
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
