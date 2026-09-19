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

  testWidgets('the sports step leads, and its clubs page follows the pick', (
    tester,
  ) async {
    ProfileSetupResult? result;

    await _pumpProfileSetup(tester, (value) => result = value);
    await _openSportsStep(tester);

    // Sports come first, on their own board — no league or club UI yet.
    expect(find.text('PICK YOUR HOME SPORT'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding_sport_grid')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding_league_selector')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('onboarding_team_grid')), findsNothing);
    expect(_sportTile(Icons.sports_soccer), findsOneWidget);
    expect(
      tester.widget<Icon>(_sportTile(Icons.sports_soccer)).color,
      Cyber.cyan,
    );
    expect(
      tester.widget<Icon>(_sportTile(Icons.sports_cricket)).color,
      AppTheme.whiteColor.withValues(alpha: 0.62),
    );
    expect(
      tester.widget<Icon>(_sportTile(Icons.sports_basketball)).color,
      Cyber.gold.withValues(alpha: 0.62),
    );
    expect(
      tester.widget<Icon>(_sportTile(Icons.sports_tennis)).color,
      Cyber.lime.withValues(alpha: 0.62),
    );
    expect(
      tester.widget<Icon>(_sportTile(Icons.sports_motorsports)).color,
      Cyber.f1Red.withValues(alpha: 0.62),
    );

    await _next(tester);

    // The clubs page belongs to the one sport that was picked.
    expect(find.text('CHOOSE YOUR FOOTBALL CLUBS'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding_league_selector')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('onboarding_team_grid')), findsOneWidget);
    expect(find.text('EPL'), findsOneWidget);
    expect(find.text('LIVERPOOL'), findsOneWidget);
    expect(find.textContaining('HOME SPORT -'), findsNothing);
    expect(
      tester.widget<Text>(find.text('LIVERPOOL')).style?.color,
      AppTheme.whiteColor,
    );
    final clubHelper = tester.widget<Text>(
      find.text('STEP 4 OF 4 // FOOTBALL - PICK YOUR LEAGUE AND CLUB'),
    );
    expect(clubHelper.style?.color, AppTheme.textMedium);

    await _tapTile(tester, 'LIVERPOOL');
    expect(find.textContaining('locked in'), findsNothing);
    await _finishSetup(tester);

    expect(result, isNotNull);
    expect(result!.sports, [Sport.football]);
    expect(result!.primarySport, Sport.football);
    expect(result!.followedLeagueIds, contains('epl'));
    expect(result!.favoriteTeams['epl'], 'liv');
  });

  testWidgets('the home sport is single-select - a new pick replaces it', (
    tester,
  ) async {
    await _pumpProfileSetup(tester, (_) {});
    await _openSportsStep(tester);

    await _tapTile(tester, 'CRICKET');

    // Cricket takes over; football drops back to the calm unselected tint.
    expect(
      tester.widget<Icon>(_sportTile(Icons.sports_cricket)).color,
      AppTheme.whiteColor,
    );
    expect(
      tester.widget<Icon>(_sportTile(Icons.sports_soccer)).color,
      Cyber.cyan.withValues(alpha: 0.62),
    );
    expect(find.text('HOME SPORT'), findsOneWidget);

    // Re-tapping the home sport never deselects it.
    await _tapTile(tester, 'CRICKET');
    expect(
      tester.widget<Icon>(_sportTile(Icons.sports_cricket)).color,
      AppTheme.whiteColor,
    );
  });

  testWidgets('Formula 1 skips leagues and saves selected constructor', (
    tester,
  ) async {
    ProfileSetupResult? result;

    await _pumpProfileSetup(tester, (value) => result = value);
    await _openSportsStep(tester);

    await _tapTile(tester, 'MOTORSPORT');
    await _next(tester);

    expect(find.text('CHOOSE YOUR MOTORSPORT CLUBS'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding_league_selector')),
      findsNothing,
    );
    expect(find.text('RED BULL RACING'), findsOneWidget);
    expect(find.text('FERRARI'), findsOneWidget);

    await _tapTile(tester, 'FERRARI');
    await _finishSetup(tester);

    expect(result, isNotNull);
    expect(result!.sports, [Sport.motorsport]);
    expect(result!.primarySport, Sport.motorsport);
    expect(result!.followedLeagueIds, contains('formula1'));
    expect(result!.favoriteTeams['formula1'], 'fer');
  });

  testWidgets("switching home sport drops the previous sport's club picks", (
    tester,
  ) async {
    ProfileSetupResult? result;

    await _pumpProfileSetup(tester, (value) => result = value);
    await _openSportsStep(tester);

    await _next(tester);
    await _tapTile(tester, 'LIVERPOOL');

    // Back to the sports board and switch to motorsport.
    await _previous(tester);
    await _tapTile(tester, 'MOTORSPORT');
    await _next(tester);
    expect(find.text('CHOOSE YOUR MOTORSPORT CLUBS'), findsOneWidget);
    await _tapTile(tester, 'FERRARI');
    await _finishSetup(tester);

    expect(result, isNotNull);
    expect(result!.sports, [Sport.motorsport]);
    expect(result!.favoriteTeams.containsKey('epl'), isFalse);
    expect(result!.followedLeagueIds, isNot(contains('epl')));
    expect(result!.favoriteTeams['formula1'], 'fer');
  });
}

Finder _sportTile(IconData icon) => find.descendant(
  of: find.byKey(const ValueKey('onboarding_sport_grid')),
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

/// Avatar → banner → sports.
Future<void> _openSportsStep(WidgetTester tester) async {
  await _next(tester);
  await _next(tester);
}

Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.text('NEXT').last);
  await tester.pump(const Duration(milliseconds: 700));
}

Future<void> _previous(WidgetTester tester) async {
  await tester.tap(find.text('PREVIOUS').last);
  await tester.pump(const Duration(milliseconds: 700));
}

Future<void> _tapTile(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump(const Duration(milliseconds: 220));
}

Future<void> _finishSetup(WidgetTester tester) async {
  await tester.tap(find.text('FINISH SETUP').last);
  await tester.pump(const Duration(milliseconds: 120));

  // Skip the launch countdown overlay.
  await tester.tapAt(const Offset(300, 300));
  await tester.pump();
}
