import 'package:card_game/config/theme.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/screens/onboarding/profile_setup_screen.dart';
import 'package:card_game/utils/sound_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global'),
          (_) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers'),
          (_) async => null,
        );
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
    expect(
      tester.widget<Icon>(_sportPill(Icons.sports_soccer)).color,
      Cyber.cyan,
    );
    expect(
      tester.widget<Icon>(_sportPill(Icons.sports_cricket)).color,
      AppTheme.whiteColor.withValues(alpha: 0.62),
    );
    expect(
      tester.widget<Icon>(_sportPill(Icons.sports_basketball)).color,
      Cyber.gold.withValues(alpha: 0.62),
    );
    expect(
      tester.widget<Icon>(_sportPill(Icons.sports_tennis)).color,
      Cyber.lime.withValues(alpha: 0.62),
    );
    expect(
      tester.widget<Icon>(_sportPill(Icons.sports_motorsports)).color,
      Cyber.f1Red.withValues(alpha: 0.62),
    );
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

  testWidgets('selected onboarding sport keeps its canonical full color', (
    tester,
  ) async {
    await _pumpProfileSetup(tester, (_) {});
    await _openClubsStep(tester);

    await tester.tap(_sportPill(Icons.sports_cricket));
    await tester.pump(const Duration(milliseconds: 220));

    expect(
      tester.widget<Icon>(_sportPill(Icons.sports_cricket)).color,
      AppTheme.whiteColor,
    );
    expect(
      tester.widget<Icon>(_sportPill(Icons.sports_soccer)).color,
      Cyber.cyan.withValues(alpha: 0.62),
    );
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
  await tester.ensureVisible(find.byKey(const ValueKey('onboarding-google')));
  await tester.tap(find.byKey(const ValueKey('onboarding-google')));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 500));
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
