import 'package:card_game/screens/onboarding/player_profile_selector_screen.dart';
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
  });

  testWidgets('offers first-time and returning player routes', (tester) async {
    PlayerProfileChoice? selection;
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerProfileSelectorScreen(
          onSelect: (choice) => selection = choice,
          firstTimeProfileReady: false,
          returningProfileReady: true,
        ),
      ),
    );

    expect(find.text('FIRST-TIME PLAYER'), findsOneWidget);
    expect(find.text('RETURNING PLAYER'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('profile_selector_first_time')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('profile_selector_returning')),
      findsOneWidget,
    );

    await tester.tap(find.text('START FRESH'));
    await tester.pump();
    expect(selection, PlayerProfileChoice.firstTime);

    await tester.tap(find.text('CONTINUE CAREER'));
    await tester.pump();
    expect(selection, PlayerProfileChoice.returning);
  });

  testWidgets('holds the returning route until a saved career exists', (
    tester,
  ) async {
    PlayerProfileChoice? selection;
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerProfileSelectorScreen(
          onSelect: (choice) => selection = choice,
          firstTimeProfileReady: false,
          returningProfileReady: false,
        ),
      ),
    );

    expect(find.text('NO SAVED CAREER'), findsOneWidget);
    await tester.tap(find.text('NO SAVED CAREER'));
    await tester.pump();
    expect(selection, isNull);
  });

  testWidgets('labels a previously played first-time slot as resumable', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PlayerProfileSelectorScreen(
          onSelect: _ignoreProfileChoice,
          firstTimeProfileReady: true,
          returningProfileReady: false,
        ),
      ),
    );

    expect(find.text('CONTINUE ROOKIE PROFILE'), findsOneWidget);
    expect(
      find.text('Continue your saved rookie career and streak.'),
      findsOneWidget,
    );
  });
}

void _ignoreProfileChoice(PlayerProfileChoice _) {}
