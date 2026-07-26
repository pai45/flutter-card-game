import 'package:card_game/blocs/guess_driver/guess_driver_cubit.dart';
import 'package:card_game/blocs/guess_winner/guess_winner_cubit.dart';
import 'package:card_game/config/theme.dart';
import 'package:card_game/models/guess_driver.dart';
import 'package:card_game/models/guess_winner.dart';
import 'package:card_game/screens/guess_driver/guess_driver_home_screen.dart';
import 'package:card_game/screens/guess_driver/guess_driver_screen.dart';
import 'package:card_game/screens/guess_winner/guess_winner_home_screen.dart';
import 'package:card_game/screens/guess_winner/guess_winner_logs_screen.dart';
import 'package:card_game/screens/guess_winner/guess_winner_screen.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/utils/sound_effects.dart';
import 'package:card_game/widgets/cyber/daily_mystery_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _slam = GrandSlamCard(
  year: '2025',
  tournament: 'Wimbledon',
  category: 'Men Singles',
  winnerName: 'Carlos Alcaraz',
);

const _race = F1RaceCard(
  year: '2025',
  trackName: 'Silverstone',
  driverName: 'Lando Norris',
  teamName: 'McLaren',
  country: 'United Kingdom',
);

Future<void> _pumpAt(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(393, 852),
  double textScale = 1,
  double keyboardInset = 0,
  bool reducedMotion = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
          viewInsets: EdgeInsets.only(bottom: keyboardInset),
          disableAnimations: reducedMotion,
        ),
        child: RepaintBoundary(
          key: const ValueKey('daily-mystery-qa-surface'),
          child: child,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await (FontLoader('Orbitron')..addFont(
          rootBundle.load('assets/fonts/Orbitron-VariableFont_wght.ttf'),
        ))
        .load();
    await (FontLoader(
          'Onest',
        )..addFont(rootBundle.load('assets/fonts/Onest-VariableFont_wght.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    AudioController.instance.muted.value = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  tearDown(() {
    AudioController.instance.muted.value = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets(
    'tennis landing uses cyber telemetry, stats, and spacious actions',
    (tester) async {
      final storage = SecureGameStorage();
      await storage.saveTennisGuessWinnerArchive(
        const GuessWinnerArchive(
          resultsByDay: {
            '2026-07-18': GuessWinnerDailyResult(
              won: true,
              heartsRemaining: 8,
              targetWinnerName: 'Carlos Alcaraz',
            ),
            '2026-07-17': GuessWinnerDailyResult(
              won: false,
              heartsRemaining: 0,
              targetWinnerName: 'Aryna Sabalenka',
            ),
          },
        ),
      );
      final cubit = GuessWinnerCubit(
        grandSlams: const [_slam],
        allPlayers: const ['Carlos Alcaraz', 'Wrong Player'],
        storage: storage,
        now: () => DateTime(2026, 7, 19, 12),
      );
      addTearDown(cubit.close);
      await cubit.load();

      await _pumpAt(
        tester,
        GuessWinnerHomeScreen(
          state: cubit.state,
          onBack: () {},
          onOpenToday: () {},
          onOpenLogs: () {},
          onRetry: () {},
          now: () => DateTime(2026, 7, 19, 12),
        ),
        size: const Size(360, 640),
        textScale: 1.15,
        reducedMotion: true,
      );

      expect(find.text('COURT ARCHIVE // ONLINE'), findsOneWidget);
      expect(find.text('ENCRYPTED CHAMPION'), findsOneWidget);
      expect(find.text('PLAY TODAY\'S FINAL'), findsOneWidget);
      expect(find.text('OPEN 30-DAY ARCHIVE'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('daily-mystery-qa-surface')),
        matchesGoldenFile('goldens/daily_mystery_tennis_landing.png'),
      );
    },
  );

  testWidgets('F1 landing keeps the pit-wall identity and primary CTA', (
    tester,
  ) async {
    final cubit = GuessDriverCubit(
      races: const [_race],
      allDrivers: const ['Lando Norris', 'Wrong Driver'],
      storage: SecureGameStorage(),
      now: () => DateTime(2026, 7, 19, 12),
    );
    addTearDown(cubit.close);
    await cubit.load();

    await _pumpAt(
      tester,
      GuessDriverHomeScreen(
        state: cubit.state,
        onBack: () {},
        onOpenToday: () {},
        onOpenLogs: () {},
        onRetry: () {},
        now: () => DateTime(2026, 7, 19, 12),
      ),
      reducedMotion: true,
    );

    expect(find.text('PIT WALL // SIGNAL LIVE'), findsOneWidget);
    expect(find.text('CLASSIFIED DRIVER'), findsOneWidget);
    expect(find.text('PLAY TODAY\'S RACE'), findsOneWidget);
    expect(find.text('OPEN 30-DAY ARCHIVE'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey('daily-mystery-qa-surface')),
      matchesGoldenFile('goldens/daily_mystery_f1_landing.png'),
    );
  });

  testWidgets(
    'driver play selection depletes a heart and adds a numbered log',
    (tester) async {
      final cubit = GuessDriverCubit(
        races: const [_race],
        allDrivers: const ['Lando Norris', 'Wrong Driver'],
        storage: SecureGameStorage(),
        now: () => DateTime(2026, 7, 19, 12),
      );
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.openToday();

      await _pumpAt(
        tester,
        BlocProvider<GuessDriverCubit>.value(
          value: cubit,
          child: GuessDriverScreen(onBack: () {}),
        ),
      );

      expect(find.text('SKIP ROUND'), findsOneWidget);
      expect(find.text('YEAR'), findsOneWidget);
      expect(find.text('TRACK'), findsOneWidget);
      expect(find.text('COUNTRY'), findsOneWidget);
      expect(find.text('TEAM'), findsNothing);
      for (var index = 0; index < 10; index++) {
        expect(
          find.byKey(ValueKey('daily-mystery-heart-$index')),
          findsOneWidget,
        );
      }
      await tester.enterText(find.byType(TextField), 'Wrong');
      await tester.pump();
      await tester.tap(find.text('Wrong Driver').last);
      await tester.pump();
      expect(find.text('LOCK DRIVER'), findsOneWidget);

      await tester.tap(find.text('LOCK DRIVER'));
      await tester.pump(const Duration(milliseconds: 450));

      expect(cubit.state.remainingHearts, 9);
      expect(find.text('1 · WRONG DRIVER'), findsOneWidget);
      expect(find.text('9 / 10'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('winner play remains usable on a short keyboard-open screen', (
    tester,
  ) async {
    final cubit = GuessWinnerCubit(
      grandSlams: const [_slam],
      allPlayers: const ['Carlos Alcaraz', 'Wrong Player'],
      storage: SecureGameStorage(),
      now: () => DateTime(2026, 7, 19, 12),
    );
    addTearDown(cubit.close);
    await cubit.load();
    await cubit.openToday();

    await _pumpAt(
      tester,
      BlocProvider<GuessWinnerCubit>.value(
        value: cubit,
        child: GuessWinnerScreen(onBack: () {}),
      ),
      size: const Size(360, 640),
      textScale: 1.2,
      keyboardInset: 250,
      reducedMotion: true,
    );

    expect(find.text('SKIP ROUND'), findsOneWidget);
    expect(find.text('TOURNAMENT'), findsOneWidget);
    expect(find.text('CATEGORY'), findsOneWidget);
    await tester.tap(find.text('SKIP ROUND'));
    await tester.pump();
    expect(cubit.state.gameState, GuessWinnerGameState.lost);
    expect(cubit.state.guesses, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('30-day archive reports live, won, lost, and missing days', (
    tester,
  ) async {
    final storage = SecureGameStorage();
    await storage.saveTennisGuessWinnerArchive(
      const GuessWinnerArchive(
        resultsByDay: {
          '2026-07-18': GuessWinnerDailyResult(
            won: true,
            heartsRemaining: 8,
            targetWinnerName: 'Carlos Alcaraz',
          ),
          '2026-07-17': GuessWinnerDailyResult(
            won: false,
            heartsRemaining: 0,
            targetWinnerName: 'Carlos Alcaraz',
          ),
        },
      ),
    );
    final cubit = GuessWinnerCubit(
      grandSlams: const [_slam],
      allPlayers: const ['Carlos Alcaraz'],
      storage: storage,
      now: () => DateTime(2026, 7, 19, 12),
    );
    addTearDown(cubit.close);
    await cubit.load();
    var openedDay = '';

    await _pumpAt(
      tester,
      BlocProvider<GuessWinnerCubit>.value(
        value: cubit,
        child: GuessWinnerLogsScreen(
          state: cubit.state,
          onBack: () {},
          onOpenDay: (dayKey) async => openedDay = dayKey,
        ),
      ),
      size: const Size(820, 900),
      reducedMotion: true,
    );

    expect(find.text('TODAY · LIVE'), findsOneWidget);
    expect(find.text('WON'), findsOneWidget);
    expect(find.text('LOST'), findsOneWidget);
    expect(find.text('NO ENTRY'), findsWidgets);
    expect(find.text('2'), findsOneWidget);
    await expectLater(
      find.byKey(const ValueKey('daily-mystery-qa-surface')),
      matchesGoldenFile('goldens/daily_mystery_tennis_archive.png'),
    );
    await tester.tap(find.text('WON'));
    await tester.pump();
    expect(openedDay, '2026-07-18');
    expect(tester.takeException(), isNull);
  });

  testWidgets('historical debrief renders immediately without reward replay', (
    tester,
  ) async {
    var consumed = false;
    await _pumpAt(
      tester,
      DailyMysteryDebrief(
        title: 'CHAMPION DEBRIEF',
        subtitle: '2026-07-18',
        won: true,
        freshResult: false,
        answer: 'Carlos Alcaraz',
        promptTitle: 'Wimbledon · 2025',
        promptDetail: 'Men Singles',
        heartsRemaining: 8,
        icon: Icons.sports_tennis_rounded,
        accent: Cyber.lime,
        onHome: () {},
        onLogs: () {},
        onConsumeReveal: () => consumed = true,
      ),
      reducedMotion: true,
    );

    expect(find.text('IDENTITY CONFIRMED'), findsOneWidget);
    expect(find.text('CARLOS ALCARAZ'), findsOneWidget);
    expect(find.text('+50 XP'), findsOneWidget);
    expect(consumed, isFalse);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey('daily-mystery-qa-surface')),
      matchesGoldenFile('goldens/daily_mystery_debrief.png'),
    );
  });
}
