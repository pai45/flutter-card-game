import 'package:card_game/models/league.dart';
import 'package:card_game/models/league_stat_leaders.dart';
import 'package:card_game/screens/predictions/widgets/standings_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [360.0, 412.0]) {
    testWidgets('league header controls fit at ${width.toInt()}px', (
      tester,
    ) async {
      int? selected;
      var followed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: width,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: StatefulBuilder(
                    builder: (context, setState) => LeagueHeader(
                      league: _league,
                      teamCount: 20,
                      seasons: _seasons,
                      selectedSeasonYear: selected ?? 2026,
                      onSeasonSelected: (year) {
                        selected = year;
                        setState(() {});
                      },
                      followed: followed,
                      onToggleFollow: () {
                        followed = !followed;
                        setState(() {});
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('FOLLOW'), findsOneWidget);
      await tester.tap(find.text('FOLLOW'));
      await tester.pumpAndSettle();
      expect(find.text('FOLLOWING'), findsOneWidget);

      await tester.tap(find.text('2026-27'));
      await tester.pumpAndSettle();
      expect(find.text('2025-26'), findsOneWidget);
      await tester.tap(find.text('2025-26'));
      await tester.pumpAndSettle();
      expect(selected, 2025);
      expect(tester.takeException(), isNull);
    });
  }
}

const _league = League(
  id: 'eng.1',
  name: 'English Premier League',
  shortCode: 'EPL',
  accent: Color(0xffa855f7),
);

const _seasons = [
  LeagueSeasonOption(year: 2026, label: '2026-27', isCurrent: true),
  LeagueSeasonOption(year: 2025, label: '2025-26'),
  LeagueSeasonOption(year: 2024, label: '2024-25'),
];
