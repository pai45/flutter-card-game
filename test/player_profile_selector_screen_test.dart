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

  /// Pumps the selector and returns the single-element list the chosen route
  /// is recorded into.
  Future<List<PlayerProfileChoice?>> pumpSelector(
    WidgetTester tester, {
    required PlayerProfileChoice activeProfile,
    required bool firstTimeProfileReady,
    required bool returningProfileReady,
    Future<void> Function(PlayerProfileChoice)? onSelect,
  }) async {
    final selection = <PlayerProfileChoice?>[null];
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerProfileSelectorScreen(
          onSelect:
              onSelect ??
              (choice) async {
                selection[0] = choice;
              },
          activeProfile: activeProfile,
          firstTimeProfileReady: firstTimeProfileReady,
          returningProfileReady: returningProfileReady,
        ),
      ),
    );
    return selection;
  }

  testWidgets('offers first-time and returning player routes', (tester) async {
    final selection = await pumpSelector(
      tester,
      activeProfile: PlayerProfileChoice.returning,
      firstTimeProfileReady: false,
      returningProfileReady: true,
    );
    await tester.pump();

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
    expect(selection[0], PlayerProfileChoice.firstTime);
  });

  // Regression: a solo player whose only career lives in the first-time slot
  // used to be trapped — the returning card was disabled ("NO SAVED CAREER")
  // and the only enabled CTA was the slot they were already in, so logging
  // out put them straight back into the same career.
  testWidgets('always offers a real way off the active profile', (
    tester,
  ) async {
    final selection = await pumpSelector(
      tester,
      activeProfile: PlayerProfileChoice.firstTime,
      firstTimeProfileReady: true,
      returningProfileReady: false,
    );
    await tester.pump();

    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('STAY IN THIS PROFILE'), findsOneWidget);
    expect(find.text('NO SAVED CAREER'), findsNothing);

    final startNew = find.text('START NEW CAREER');
    expect(startNew, findsOneWidget);
    await tester.tap(startNew);
    await tester.pump();
    expect(selection[0], PlayerProfileChoice.returning);
  });

  testWidgets('the active slot CTA backs out instead of switching', (
    tester,
  ) async {
    final selection = await pumpSelector(
      tester,
      activeProfile: PlayerProfileChoice.returning,
      firstTimeProfileReady: false,
      returningProfileReady: true,
    );
    await tester.pump();

    expect(
      find.text('You are playing this career right now.'),
      findsOneWidget,
    );
    await tester.tap(find.text('STAY IN THIS PROFILE'));
    await tester.pump();
    expect(selection[0], PlayerProfileChoice.returning);
  });

  testWidgets('labels a previously played first-time slot as resumable', (
    tester,
  ) async {
    await pumpSelector(
      tester,
      activeProfile: PlayerProfileChoice.returning,
      firstTimeProfileReady: true,
      returningProfileReady: true,
    );
    await tester.pump();

    expect(find.text('CONTINUE ROOKIE PROFILE'), findsOneWidget);
    expect(
      find.text('Continue your saved rookie career and streak.'),
      findsOneWidget,
    );
  });

  testWidgets('keeps the player on the selector when a switch fails', (
    tester,
  ) async {
    await pumpSelector(
      tester,
      activeProfile: PlayerProfileChoice.returning,
      firstTimeProfileReady: false,
      returningProfileReady: true,
      onSelect: (_) async => throw StateError('storage interrupted'),
    );
    await tester.pump();

    await tester.tap(find.text('START FRESH'));
    await tester.pump();

    expect(
      find.text(
        'Profile switch interrupted. Your current career is safe — retry.',
      ),
      findsNWidgets(2),
    );
    expect(find.text('START FRESH'), findsOneWidget);
  });
}
