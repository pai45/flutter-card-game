import 'package:card_game/config/game_ladder.dart';
import 'package:card_game/config/theme.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/widgets/cyber/statoz_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.darkTheme,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('every sport and game has a renderable StatOz mark', (
    tester,
  ) async {
    for (final sport in Sport.values) {
      await tester.pumpWidget(_host(StatozSportIcon(sport: sport)));
      expect(find.byType(SvgPicture), findsOneWidget, reason: sport.name);
      expect(tester.takeException(), isNull, reason: sport.name);
    }

    for (final game in ArcadeGame.values) {
      await tester.pumpWidget(_host(StatozGameIcon(game: game)));
      expect(find.byType(SvgPicture), findsOneWidget, reason: game.name);
      expect(tester.takeException(), isNull, reason: game.name);
    }
  });

  testWidgets('identity marks are decorative unless explicitly labelled', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const StatozGameIcon(
          game: ArcadeGame.pitchDuel,
          semanticLabel: 'Pitch Duel',
        ),
      ),
    );

    expect(find.bySemanticsLabel('Pitch Duel'), findsOneWidget);
  });
}
