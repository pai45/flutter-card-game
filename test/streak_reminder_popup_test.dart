import 'package:card_game/config/theme.dart';
import 'package:card_game/models/streak.dart';
import 'package:card_game/models/streak_reminder.dart';
import 'package:card_game/utils/sound_effects.dart';
import 'package:card_game/widgets/streak_reminder_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    for (final channel in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
    AudioController.instance.muted.value = true;
  });

  final morning = DateTime(2026, 6, 19, 10);
  final evening = DateTime(2026, 6, 19, 20);

  /// Opens the reminder at 320px / 1.4x text, taps [label] and returns the
  /// resolved action (null = dismissed).
  Future<(bool, StreakReminderAction?)> run(
    WidgetTester tester, {
    required StreakReminderKind kind,
    required StreakSnapshot streak,
    required DateTime now,
    required String label,
    List<String> expectTexts = const [],
    List<String> absentTexts = const [],
  }) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var resolved = false;
    StreakReminderAction? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.4),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => GestureDetector(
              onTap: () async {
                result = await showStreakReminder(
                  context,
                  kind: kind,
                  streak: streak,
                  now: now,
                );
                resolved = true;
              },
              child: const Center(child: Text('OPEN')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    for (final text in expectTexts) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    for (final text in absentTexts) {
      expect(find.text(text), findsNothing, reason: text);
    }
    expect(tester.takeException(), isNull);
    final target = find.text(label);
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(StreakReminderDialog), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    return (resolved, result);
  }

  testWidgets('nudge invites the next day and opens the hub', (tester) async {
    final (resolved, action) = await run(
      tester,
      kind: StreakReminderKind.nudge,
      streak: StreakSnapshot.seeded(morning),
      now: morning,
      label: 'KEEP IT ALIVE',
      expectTexts: const [
        'KEEP THE FIRE BURNING',
        'Play anything today to make it 7.',
        '6',
      ],
      absentTexts: const ['STREAK AT RISK', 'SHIELD ARMED'],
    );
    expect(resolved, isTrue);
    expect(action, StreakReminderAction.openHub);
  });

  testWidgets('at-risk warning shows armed shields and routes PREDICT', (
    tester,
  ) async {
    final (_, action) = await run(
      tester,
      kind: StreakReminderKind.atRisk,
      streak: StreakSnapshot.seeded(evening).copyWith(shields: 1),
      now: evening,
      label: 'PREDICT',
      expectTexts: const [
        'STREAK AT RISK',
        '4H 00M left to save your 6-day run.',
        'SHIELD ARMED',
        'SAVE MY STREAK',
      ],
    );
    expect(action, StreakReminderAction.predict);
  });

  testWidgets('at-risk without shields hides the shield line; NOT NOW '
      'dismisses', (tester) async {
    final (resolved, action) = await run(
      tester,
      kind: StreakReminderKind.atRisk,
      streak: StreakSnapshot.seeded(evening),
      now: evening,
      label: 'NOT NOW',
      absentTexts: const ['SHIELD ARMED'],
    );
    expect(resolved, isTrue);
    expect(action, isNull);
  });

  for (final entry in const {
    'PLAY': StreakReminderAction.play,
    'PICK': StreakReminderAction.pick,
  }.entries) {
    testWidgets('${entry.key} quick action resolves ${entry.value}', (
      tester,
    ) async {
      final (_, action) = await run(
        tester,
        kind: StreakReminderKind.nudge,
        streak: StreakSnapshot.seeded(morning),
        now: morning,
        label: entry.key,
      );
      expect(action, entry.value);
    });
  }
}
