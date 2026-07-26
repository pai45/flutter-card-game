import 'package:card_game/models/sport_match.dart';
import 'package:card_game/screens/onboarding/profile_setup_screen.dart';
import 'package:card_game/utils/sound_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AudioController.instance.muted.value = true;
  });

  testWidgets('clubs step combines sports, leagues, and football clubs', (
    tester,
  ) async {
    ProfileSetupResult? result;

    await _pumpProfileSetup(tester, (value) => result = value);
    await _openClubsStep(tester);

    expect(find.text('CHOOSE CLUBS'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding_sport_selector')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('onboarding_league_selector')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('onboarding_team_grid')), findsOneWidget);
    expect(_sportPill(Icons.sports_soccer), findsOneWidget);
    expect(find.text('EPL'), findsOneWidget);
    expect(find.text('LIVERPOOL'), findsOneWidget);

    await tester.tap(find.text('LIVERPOOL'));
    await tester.pump(const Duration(milliseconds: 180));
    await _finishSetup(tester);

    expect(result, isNotNull);
    expect(result!.primarySport, Sport.football);
    expect(result!.followedLeagueIds, contains('epl'));
    expect(result!.favoriteTeams['epl'], 'liv');
  });

  testWidgets('Formula 1 skips leagues and saves selected constructor', (
    tester,
  ) async {
    ProfileSetupResult? result;

    await _pumpProfileSetup(tester, (value) => result = value);
    await _openClubsStep(tester);

    await tester.tap(_sportPill(Icons.sports_motorsports));
    await tester.pump(const Duration(milliseconds: 220));

    expect(
      find.byKey(const ValueKey('onboarding_league_selector')),
      findsNothing,
    );
    expect(find.text('RED BULL RACING'), findsOneWidget);
    expect(find.text('FERRARI'), findsOneWidget);

    await tester.tap(find.text('FERRARI'));
    await tester.pump(const Duration(milliseconds: 180));
    await _finishSetup(tester);

    expect(result, isNotNull);
    expect(result!.primarySport, Sport.motorsport);
    expect(result!.followedLeagueIds, contains('formula1'));
    expect(result!.favoriteTeams['formula1'], 'fer');
  });
}

Finder _sportPill(IconData icon) => find.descendant(
  of: find.byKey(const ValueKey('onboarding_sport_selector')),
  matching: find.byIcon(icon),
);

Future<void> _pumpProfileSetup(
  WidgetTester tester,
  ValueChanged<ProfileSetupResult> onComplete,
) async {
  await tester.binding.setSurfaceSize(const Size(430, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(home: ProfileSetupScreen(onComplete: onComplete)),
  );
  await tester.pump();

  // Dismiss the launch intro overlay.
  await tester.tapAt(const Offset(300, 300));
  await tester.pump(const Duration(milliseconds: 120));
}

Future<void> _openClubsStep(WidgetTester tester) async {
  await tester.tap(find.text('NEXT').last);
  await tester.pump(const Duration(milliseconds: 700));
  await tester.tap(find.text('NEXT').last);
  await tester.pump(const Duration(milliseconds: 700));
}

Future<void> _finishSetup(WidgetTester tester) async {
  await tester.tap(find.text('FINISH SETUP').last);
  await tester.pump(const Duration(milliseconds: 120));

  // Skip the launch countdown overlay.
  await tester.tapAt(const Offset(300, 300));
  await tester.pump();
}
