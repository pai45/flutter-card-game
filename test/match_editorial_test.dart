import 'package:card_game/config/theme.dart';
import 'package:card_game/models/picks.dart';
import 'package:card_game/data/demo_championship_markets.dart';
import 'package:card_game/models/prediction.dart';
import 'package:card_game/widgets/team_logo.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/widgets/cyber/match_discovery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SportMatch fixture(Sport sport, MatchStatus status) => SportMatch(
  id: 'review',
  leagueId: 'A long competition name',
  sport: sport,
  home: const SportTeam(
    id: 'home',
    name: 'A very long home team identity',
    shortName: 'HOME',
    color: Colors.blue,
  ),
  away: const SportTeam(
    id: 'away',
    name: 'A very long visiting team identity',
    shortName: 'AWAY',
    color: Colors.red,
  ),
  kickoff: DateTime(2026, 10, 14, 20),
  status: status,
  homeScore: sport == Sport.cricket ? '187/4 (18.2 ov)' : '102',
  awayScore: sport == Sport.cricket ? '168/8 (20 ov)' : '98',
);
PickMarket market(PickMarketStatus status, int id) => PickMarket(
  id: 'market$id',
  question:
      'Will the leading player finish with at least thirty points in this match?',
  type: PickMarketType.event,
  sport: Sport.basketball,
  leagueId: 'nba',
  leagueLabel: 'National Basketball Association',
  status: status,
  outcomes: const [
    PickOutcome(
      id: 'yes',
      label: 'Yes, thirty or more',
      probabilityPercent: 68,
      color: Colors.green,
    ),
    PickOutcome(
      id: 'no',
      label: 'No',
      probabilityPercent: 32,
      color: Colors.red,
    ),
  ],
  volumeOz: 120,
  closesAt: DateTime(2026, 10, 14, 20),
);
void main() {
  test('match tint follows authoritative lifecycle and supported winner', () {
    final upcoming = fixture(Sport.football, MatchStatus.upcoming);
    expect(editorialMatchAccent(upcoming), Cyber.border);
    expect(editorialMatchAccent(upcoming, followed: true), Cyber.cyan);
    expect(
      editorialMatchAccent(
        fixture(Sport.football, MatchStatus.live),
        followed: true,
      ),
      Cyber.red,
    );
    expect(
      editorialMatchAccent(
        fixture(Sport.football, MatchStatus.finished),
        followed: true,
      ),
      Colors.blue,
    );
    expect(
      editorialMatchAccent(fixture(Sport.cricket, MatchStatus.finished)),
      Cyber.border,
    );
    expect(
      editorialMatchAccent(
        fixture(Sport.cricket, MatchStatus.finished).copyWith(
          resultLine:
              'A very long visiting team identity beat A very long home team identity',
        ),
      ),
      Colors.red,
    );
  });

  test('shared status and deadline rules', () {
    expect(editorialStatus('unresolved'), 'UNRESOLVED');
    expect(editorialStatus('voided'), 'VOID');
    final now = DateTime(2026, 10, 14, 10);
    expect(
      editorialDeadline(now.add(const Duration(minutes: 28)), 'upcoming', now),
      'Closes in 28m',
    );
    expect(
      editorialDeadline(now.subtract(const Duration(seconds: 1)), 'live', now),
      isNull,
    );
    expect(
      editorialDeadline(
        now.add(const Duration(minutes: 28)),
        'unresolved',
        now,
      ),
      isNull,
    );
    expect(
      editorialKickoff(DateTime(2026, 10, 14, 20), now),
      'Starts today · 20:00',
    );
  });
  Future<void> render(
    WidgetTester tester,
    Widget child, {
    double width = 393,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        // Keep activation checks independent of platform InkSparkle shaders.
        theme: AppTheme.darkTheme.copyWith(
          splashFactory: InkRipple.splashFactory,
        ),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 1200),
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(padding: const EdgeInsets.all(20), child: child),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final sport in [
    Sport.football,
    Sport.cricket,
    Sport.basketball,
    Sport.motorsport,
  ]) {
    for (final status in MatchStatus.values) {
      testWidgets(
        '${sport.name} ${status.name} remains readable at 320px and 1.4 text scale',
        (tester) async {
          await render(
            tester,
            EditorialMatchCard(match: fixture(sport, status), onTap: () {}),
            width: 320,
            scale: 1.4,
          );
          expect(tester.takeException(), isNull);
          expect(find.text(editorialStatus(status.name)), findsOneWidget);
          expect(
            find.textContaining('A very long home team identity'),
            findsOneWidget,
          );
        },
      );
    }
  }
  testWidgets(
    'percentage CTAs fill their row, dock right and preserve activation guards',
    (tester) async {
      var buys = 0;
      for (final scale in [1.0, 1.4]) {
        await render(
          tester,
          EditorialMarketCard(
            market: market(PickMarketStatus.live, 0),
            onOpen: () {},
            onBuy: (_) => buys++,
          ),
          width: 320,
          scale: scale,
        );
        final row = tester.getRect(
          find.byKey(const ValueKey('editorial-outcome-market0-yes')),
        );
        final price = tester.getRect(
          find.byKey(const ValueKey('editorial-price-market0-yes')),
        );
        expect(price.right, closeTo(row.right, .1));
        expect(price.top, closeTo(row.top, .1));
        expect(price.bottom, closeTo(row.bottom, .1));
        expect(price.height, greaterThanOrEqualTo(44));
        await tester.tapAt(Offset(price.right - 2, price.center.dy));
        expect(tester.takeException(), isNull);
      }
      expect(buys, 2);
      await render(
        tester,
        EditorialMarketCard(
          market: market(PickMarketStatus.closed, 0),
          onOpen: () {},
          onBuy: (_) => buys++,
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('editorial-price-market0-yes')),
      );
      expect(buys, 2);
    },
  );
  testWidgets('live match context joins its edge-docked lifecycle tag', (
    tester,
  ) async {
    for (final scale in [1.0, 1.4]) {
      await render(
        tester,
        EditorialMatchCard(
          match: fixture(
            Sport.football,
            MatchStatus.live,
          ).copyWith(liveMinute: 67),
          onTap: () {},
        ),
        width: 320,
        scale: scale,
      );
      expect(find.text('LIVE 67′'), findsOneWidget);
      expect(find.text('67′'), findsNothing);
      final tag = tester.getRect(
        find.byKey(const ValueKey('editorial-lifecycle-dock')),
      );
      final card = tester.getRect(find.byType(EditorialPlate));
      expect(tag.right, closeTo(card.right, 1));
      expect(tag.top, closeTo(card.top, 1));
      expect(tester.takeException(), isNull);
    }
    await render(
      tester,
      EditorialMatchCard(
        match: fixture(Sport.football, MatchStatus.live),
        onTap: () {},
      ),
    );
    expect(find.text('LIVE'), findsOneWidget);
    await render(
      tester,
      EditorialMatchCard(
        match: fixture(
          Sport.football,
          MatchStatus.finished,
        ).copyWith(liveMinute: 67),
        onTap: () {},
      ),
    );
    expect(find.text('FINISHED'), findsOneWidget);
    expect(find.textContaining('67′'), findsNothing);
  });
  testWidgets(
    'compact XP cards retain identities, progress and whole-card navigation',
    (tester) async {
      var opened = 0;
      for (final sport in [
        Sport.football,
        Sport.cricket,
        Sport.basketball,
        Sport.motorsport,
      ]) {
        for (final scale in [1.0, 1.4]) {
          await render(
            tester,
            EditorialMission(
              match: fixture(sport, MatchStatus.upcoming),
              quiz: const PredictionQuiz(
                matchId: 'review',
                title: 'Match Prediction',
                questions: [
                  QuizQuestion(id: 'q', text: 'Example question', reward: 20),
                ],
              ),
              onTap: () => opened++,
            ),
            width: 320,
            scale: scale,
          );
          expect(find.text('Match Prediction'), findsNothing);
          expect(find.text('Start'), findsNothing);
          expect(find.text('0 / 1 answered'), findsOneWidget);
          expect(find.text('Up to 20 XP'), findsOneWidget);
          if (sport != Sport.motorsport) {
            expect(find.byType(TeamLogo), findsNWidgets(2));
            expect(find.text('VS'), findsOneWidget);
            expect(
              find.text(fixture(sport, MatchStatus.upcoming).home.name),
              findsNothing,
            );
            expect(
              find.text(fixture(sport, MatchStatus.upcoming).away.name),
              findsNothing,
            );
          }
          await tester.tap(find.text('0 / 1 answered'));
          expect(tester.takeException(), isNull);
        }
      }
      expect(opened, 8);
    },
  );
  testWidgets(
    'status-only timing does not repeat LIVE and genuine context remains visible',
    (tester) async {
      for (final timing in ['LIVE', ' live ']) {
        await render(
          tester,
          EditorialPlate(
            child: EditorialStatusArea(
              label: 'IPL',
              status: 'live',
              timing: timing,
            ),
          ),
        );
        expect(find.text('LIVE'), findsOneWidget);
        expect(
          find.text(timing),
          timing == 'LIVE' ? findsOneWidget : findsNothing,
        );
      }
      await render(
        tester,
        const EditorialPlate(
          child: EditorialStatusArea(
            label: 'IPL',
            status: 'live',
            timing: 'Closes in 28m',
          ),
        ),
      );
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('Closes in 28m'), findsOneWidget);
    },
  );
  testWidgets(
    'demo championship Future cards keep explicit demo markers and trade/detail actions',
    (tester) async {
      var details = 0, trades = 0;
      for (final future in demoChampionshipMarkets) {
        await render(
          tester,
          EditorialMarketCard(
            market: future,
            featured: true,
            onOpen: () => details++,
            onBuy: (_) => trades++,
          ),
          width: 320,
          scale: 1.4,
        );
        expect(find.textContaining('DEMO'), findsOneWidget);
        expect(find.text(future.question), findsOneWidget);
        expect(find.text('View Future ↗'), findsOneWidget);
        expect(
          future.outcomes.fold<int>(
            0,
            (sum, outcome) => sum + outcome.probabilityPercent,
          ),
          100,
        );
        await tester.tap(find.text('View Future ↗'));
        await tester.tap(
          find.byKey(
            ValueKey(
              'editorial-price-${future.id}-${future.outcomes.first.id}',
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
      expect(details, 3);
      expect(trades, 3);
    },
  );
  testWidgets(
    'lifecycle dock is flush with the top-right card edge at normal and enlarged text',
    (tester) async {
      for (final scale in [1.0, 1.4]) {
        await render(
          tester,
          EditorialMatchCard(
            match: fixture(Sport.football, MatchStatus.live),
            onTap: () {},
          ),
          width: 393,
          scale: scale,
        );
        final card = tester.getRect(find.byType(EditorialPlate));
        final tag = tester.getRect(
          find.byKey(const ValueKey('editorial-lifecycle-dock')),
        );
        expect(tag.top, closeTo(card.top, 1));
        expect(tag.right, closeTo(card.right, 1));
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'upcoming cricket shows kickoff instead of not-yet-batted placeholders',
    (tester) async {
      await render(
        tester,
        EditorialMatchCard(
          match: fixture(
            Sport.cricket,
            MatchStatus.upcoming,
          ).copyWith(homeScore: 'Yet to Bat', awayScore: '—'),
          onTap: () {},
        ),
        width: 320,
        scale: 1.4,
      );
      expect(find.text('Yet to Bat'), findsNothing);
      expect(
        find.byKey(const ValueKey('editorial-kickoff-clock')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'three event rows are independent, questions use medium weight and unresolved fits',
    (tester) async {
      final opened = <String>[];
      await render(
        tester,
        EditorialEventsPanel(
          markets: [
            market(PickMarketStatus.live, 0),
            market(PickMarketStatus.unresolved, 1),
            market(PickMarketStatus.closed, 2),
          ],
          onOpen: opened.add,
        ),
      );
      expect(find.text('UNRESOLVED'), findsOneWidget);
      final question = find.text(
        'Will the leading player finish with at least thirty points in this match?',
      );
      expect(
        tester.widget<Text>(question.first).style!.fontWeight,
        FontWeight.w500,
      );
      await tester.tap(question.at(1));
      expect(opened, ['market1']);
      final edgeTag = tester.getRect(
        find.byKey(const ValueKey('editorial-lifecycle-dock')).first,
      );
      await tester.tapAt(Offset(edgeTag.right - 2, edgeTag.center.dy));
      expect(opened, ['market1', 'market0']);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'paired grid collapses at accessibility scale and gold reveal keeps only fixture identity',
    (tester) async {
      var tapped = 0;
      await render(
        tester,
        EditorialPairedGrid(
          children: [
            EditorialRevealCard(
              key: const ValueKey('one'),
              match: fixture(Sport.football, MatchStatus.finished),
              onTap: () => tapped++,
            ),
            EditorialRevealCard(
              key: const ValueKey('two'),
              match: fixture(Sport.cricket, MatchStatus.finished),
              onTap: () => tapped++,
            ),
          ],
        ),
        scale: 1.4,
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('two'))).dy,
        greaterThan(tester.getBottomLeft(find.byKey(const ValueKey('one'))).dy),
      );
      expect(find.textContaining('Ready to reveal'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('one')));
      await tester.pump();
      expect(tapped, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
