import 'package:card_game/config/theme.dart';
import 'package:card_game/models/football_match_data.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/screens/predictions/widgets/football_match_stats_view.dart';
import 'package:card_game/screens/predictions/widgets/football_shot_map.dart';
import 'package:card_game/services/football_match_package_service.dart';
import 'package:card_game/widgets/cyber/cyber_chart.dart';
import 'package:card_game/widgets/cyber/cyber_filter_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SportMatch> loadMatch() =>
      const FootballMatchPackageService().loadBundled();

  test('every tracked attempt in the bundled package decodes', () async {
    final match = await loadMatch();
    final shots = match.footballDetails!.shots;

    expect(shots, hasLength(32));
    // The package's own aggregate is the cross-check that nothing was dropped.
    final totalShots = match.teamStats!.firstWhere(
      (stat) => stat.label.toUpperCase().contains('SHOT'),
    );
    expect(
      shots.where((shot) => shot.isHomeTeam).length,
      int.parse(totalShots.homeDisplay),
    );
    expect(
      shots.where((shot) => !shot.isHomeTeam).length,
      int.parse(totalShots.awayDisplay),
    );
    expect(
      shots.where((shot) => shot.isGoal).length,
      match.footballDetails!.scorers.length,
    );

    for (final shot in shots) {
      expect(shot.fieldX, inExclusiveRange(0, 1));
      expect(shot.fieldY, inExclusiveRange(0, 1));
      expect(shot.shooter, isNotEmpty);
      expect(shot.playId, isNotEmpty);
      expect(shot.period, anyOf(1, 2));
    }
  });

  test('the feed frame lands each attempt in the zone its prose describes',
      () async {
    final shots = (await loadMatch()).footballDetails!.shots;

    FootballShot shotIn(String zone) =>
        shots.firstWhere((shot) => shot.zone == zone);

    // Progress towards goal: closer prose must sit nearer the goal line.
    expect(shotIn('very close range').fieldX, greaterThan(0.94));
    expect(shotIn('the centre of the box').fieldX, greaterThan(0.83));
    expect(shotIn('outside the box').fieldX, lessThan(0.83));

    // The attacker's left is the HIGH lateral value, not the low one.
    expect(shotIn('the left side of the box').fieldY, greaterThan(0.5));
    expect(shotIn('the right side of the box').fieldY, lessThan(0.5));
  });

  test('the two sides are mirrored onto opposite goals', () async {
    final shots = (await loadMatch()).footballDetails!.shots;
    const length = PitchFrame.lengthM;
    const width = PitchFrame.widthM;

    for (final shot in shots) {
      final (x, y) = shot.pitchOffset(length, width);
      expect(x, inInclusiveRange(0, length));
      expect(y, inInclusiveRange(0, width));
      // Attempts are shot at the goal the side attacks, so every mark belongs
      // to the half in front of that side.
      expect(shot.isHomeTeam ? x > length / 2 : x < length / 2, isTrue);
    }
  });

  testWidgets('the shot map renders on the football MOMENTUM tab', (
    tester,
  ) async {
    // Asset loading is real I/O, so it has to escape the fake-async zone.
    final match = (await tester.runAsync(loadMatch))!;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: FootballMatchStatsView(match: match)),
      ),
    );
    await _pump(tester);

    _selectSection(tester, 'MOMENTUM');
    await _pump(tester);

    // The panel sits below the fold of the lazily-built momentum list.
    await tester.scrollUntilVisible(
      find.text('SHOT MAP'),
      260,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('football-stats-momentum')),
        matching: find.byType(Scrollable),
      ),
      maxScrolls: 30,
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('football-shot-map')), findsOneWidget);
    expect(find.text('32 ATTEMPTS'), findsOneWidget);
  });

  test('net placement is read for every attempt that reached the goal',
      () async {
    final shots = (await loadMatch()).footballDetails!.shots;

    bool inFrame(FootballShot s) => s.reachedGoalFrame;
    bool outside(FootballShot s) =>
        s.netPlacement != null && !s.reachedGoalFrame;

    // Goals and saves finished in the frame; misses finished outside it.
    expect(shots.where(inFrame).length, 12);
    expect(shots.where(outside).length, 8);

    // A blocked attempt never reached the goal, so it has no placement at all
    // rather than a guessed one.
    for (final shot in shots) {
      final blocked = shot.outcome == FootballShotOutcome.blocked;
      expect(
        shot.netPlacement == null,
        blocked,
        reason: '${shot.minuteLabel} ${shot.outcomeLabel}',
      );
      if (shot.outcome == FootballShotOutcome.goal ||
          shot.outcome == FootballShotOutcome.onTarget) {
        expect(inFrame(shot), isTrue, reason: shot.minuteLabel);
      }
    }
  });

  test('placement matches the corner the commentary names', () async {
    final shots = (await loadMatch()).footballDetails!.shots;

    FootballShot at(String minute) =>
        shots.firstWhere((shot) => shot.minuteLabel == minute);

    // 1' — "to the bottom left corner".
    final opener = at("1'").netPlacement!;
    expect(opener.$1, lessThan(0.5));
    expect(opener.$2, greaterThan(0.5));

    // 54' — header "to the top left corner".
    final header = shots.firstWhere((shot) => shot.isHeader && shot.isGoal);
    expect(header.netPlacement!.$1, lessThan(0.5));
    expect(header.netPlacement!.$2, lessThan(0.5));

    // 21' — "high and wide to the right" belongs outside the frame, high.
    final wide = at("21'").netPlacement!;
    expect(wide.$1, greaterThan(1.0));
    expect(wide.$2, lessThan(0.0));
  });

  testWidgets('selecting an attempt reveals where it finished', (tester) async {
    final match = (await tester.runAsync(loadMatch))!;
    final shots = match.footballDetails!.shots;
    await tester.pumpWidget(_hostPanel(match, shots));
    await _pump(tester);

    // Nothing is selected until a mark is tapped.
    expect(find.byKey(const ValueKey('football-shot-net')), findsNothing);

    final goal = shots.firstWhere((shot) => shot.isGoal);
    await _tapShot(tester, goal);
    expect(find.byKey(const ValueKey('football-shot-net')), findsOneWidget);
    expect(find.text('SCORED'), findsOneWidget);
    expect(find.text(goal.shooter), findsOneWidget);

    // A blocked attempt still draws the frame, with nothing in it.
    final blocked = shots.firstWhere(
      (shot) => shot.outcome == FootballShotOutcome.blocked,
    );
    await _tapShot(tester, blocked);
    expect(find.byKey(const ValueKey('football-shot-net')), findsOneWidget);
    expect(find.text('BLOCKED // NEVER REACHED THE GOAL'), findsOneWidget);
  });

  testWidgets('filtering narrows the plotted attempts', (tester) async {
    final match = (await tester.runAsync(loadMatch))!;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        // The panel is always hosted in a scrolling report list, so give it the
        // unbounded height it gets in the app rather than a fixed viewport.
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              FootballShotMapPanel(
                match: match,
                shots: match.footballDetails!.shots,
                homeColor: Cyber.cyan,
                awayColor: Cyber.magenta,
              ),
            ],
          ),
        ),
      ),
    );
    await _pump(tester);
    expect(find.text('32 ATTEMPTS'), findsOneWidget);

    _setRange(tester, 'GOALS');
    await _pump(tester);
    expect(find.text('5 ATTEMPTS'), findsOneWidget);

    _setRange(tester, '1ST');
    await _pump(tester);
    expect(find.text('20 ATTEMPTS'), findsOneWidget);

    _setRange(tester, '2ND');
    await _pump(tester);
    expect(find.text('12 ATTEMPTS'), findsOneWidget);
  });
}

/// Sections and range tabs are driven through their callbacks rather than by
/// tapping, matching the other stats-view tests — the ink sparkle shader is not
/// available under `flutter test`, so real taps on those controls are unreliable.
void _selectSection(WidgetTester tester, String section) {
  tester
      .widget<CyberFilterChips>(find.byType(CyberFilterChips).first)
      .onSelect(section);
}

void _setRange(WidgetTester tester, String range) {
  final tabs = tester
      .widgetList<CyberChartRangeTabs>(find.byType(CyberChartRangeTabs))
      .firstWhere((widget) => widget.ranges.contains(range));
  tabs.onChanged(range);
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1100));
}

Widget _hostPanel(SportMatch match, List<FootballShot> shots) => MaterialApp(
  theme: AppTheme.darkTheme,
  home: Scaffold(
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        FootballShotMapPanel(
          match: match,
          shots: shots,
          homeColor: Cyber.cyan,
          awayColor: Cyber.magenta,
        ),
      ],
    ),
  ),
);

/// Taps a mark by recomputing where the painter put it, so the test exercises
/// the real hit-test rather than reaching into panel state.
Future<void> _tapShot(WidgetTester tester, FootballShot shot) async {
  final map = find.byKey(const ValueKey('football-shot-map'));
  final rect = tester.getRect(map);
  final frame = PitchFrame.fit(rect.size);
  await tester.tapAt(rect.topLeft + frame.offsetFor(shot));
  await _pump(tester);
}
