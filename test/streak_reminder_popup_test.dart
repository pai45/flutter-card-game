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
  final cta = find.byKey(const ValueKey('streak-reminder-cta'));

  /// Opens the reminder sheet at 320px / 1.4x text, taps [taps] in order and
  /// returns the resolved action (null = dismissed).
  Future<(bool, StreakReminderAction?)> run(
    WidgetTester tester, {
    required StreakReminderKind kind,
    required StreakSnapshot streak,
    required DateTime now,
    List<Finder> taps = const [],
    Offset? tapScrimAt,
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
    expect(find.byType(StreakReminderSheet), findsOneWidget);
    for (final text in expectTexts) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    for (final text in absentTexts) {
      expect(find.text(text), findsNothing, reason: text);
    }
    expect(tester.takeException(), isNull);
    for (final target in taps) {
      await tester.ensureVisible(target);
      await tester.pump();
      await tester.tap(target);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
    if (tapScrimAt != null) {
      await tester.tapAt(tapScrimAt);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(tester.takeException(), isNull);
    expect(find.byType(StreakReminderSheet), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    return (resolved, result);
  }

  testWidgets('nudge shows the stakes and STREAK HUB opens the hub', (
    tester,
  ) async {
    final (resolved, action) = await run(
      tester,
      kind: StreakReminderKind.nudge,
      streak: StreakSnapshot.seeded(morning),
      now: morning,
      taps: [find.text('STREAK HUB')],
      expectTexts: const [
        'KEEP THE FIRE BURNING',
        'Play anything today to make it 7.',
        '6',
        'PENDING',
        'DAY 7 REWARD',
        'UNLOCKS TODAY',
        'NO SHIELD',
        'RESETS IN 14H 00M',
      ],
      absentTexts: const ['STREAK AT RISK', 'SHIELD ARMED'],
    );
    expect(resolved, isTrue);
    expect(action, StreakReminderAction.openHub);
  });

  testWidgets('at-risk warning shows armed shields; choosing PREDICT '
      'retargets the CTA', (tester) async {
    final (_, action) = await run(
      tester,
      kind: StreakReminderKind.atRisk,
      streak: StreakSnapshot.seeded(evening).copyWith(shields: 1),
      now: evening,
      taps: [find.text('PREDICT'), find.text('MAKE A PREDICTION')],
      expectTexts: const [
        'STREAK AT RISK',
        'AT RISK',
        '4H 00M left to save your 6-day run.',
        'SHIELD ARMED',
        'Covers a missed day.',
      ],
    );
    expect(action, StreakReminderAction.predict);
  });

  testWidgets('at-risk without shields hides the shield line; the scrim '
      'dismisses', (tester) async {
    final (resolved, action) = await run(
      tester,
      kind: StreakReminderKind.atRisk,
      streak: StreakSnapshot.seeded(evening),
      now: evening,
      tapScrimAt: const Offset(160, 4),
      absentTexts: const ['SHIELD ARMED', 'NOT NOW'],
    );
    expect(resolved, isTrue);
    expect(action, isNull);
  });

  testWidgets('the CTA preselects the most recent move', (tester) async {
    final base = StreakSnapshot.seeded(morning);
    final yesterday = streakDayKey(morning.subtract(const Duration(days: 1)));
    final (_, action) = await run(
      tester,
      kind: StreakReminderKind.nudge,
      streak: base.copyWith(
        activitiesByDay: {
          ...base.activitiesByDay,
          yesterday: const [StreakActivity.pick],
        },
      ),
      now: morning,
      taps: [cta],
      expectTexts: const ['PLACE A PICK'],
      absentTexts: const ['ONE PICK COUNTS'],
    );
    expect(action, StreakReminderAction.pick);
  });

  for (final entry in const {
    'PLAY': StreakReminderAction.play,
    'PICK': StreakReminderAction.pick,
  }.entries) {
    testWidgets('${entry.key} move resolves ${entry.value}', (tester) async {
      final (_, action) = await run(
        tester,
        kind: StreakReminderKind.nudge,
        streak: StreakSnapshot.seeded(morning),
        now: morning,
        taps: [find.text(entry.key), cta],
      );
      expect(action, entry.value);
    });
  }
}
