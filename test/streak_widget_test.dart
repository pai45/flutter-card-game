import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_state.dart';
import 'package:card_game/blocs/picks/picks_cubit.dart';
import 'package:card_game/blocs/prediction/prediction_cubit.dart';
import 'package:card_game/config/game_ladder.dart';
import 'package:card_game/config/theme.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/models/unlock_progress.dart';
import 'package:card_game/screens/predictions/streak_calendar_screen.dart';
import 'package:card_game/screens/predictions/widgets/beginner_quest_card.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/services/pick_repository.dart';
import 'package:card_game/services/prediction_repository.dart';
import 'package:card_game/widgets/cyber/cyber_underline_tabs.dart';
import 'package:card_game/widgets/cyber/cyber_widgets.dart';
import 'package:card_game/widgets/streak_widgets.dart';
import 'package:card_game/widgets/stat_oz_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuestHubBloc extends GameBloc {
  QuestHubBloc(UnlockProgress unlocks) : super(SecureGameStorage()) {
    emit(GameState.initial().copyWith(loading: false, unlocks: unlocks));
  }
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('zero streak badges stay hidden', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: StreakBadge(value: 0))),
    );

    expect(find.byType(StreakBadge), findsOneWidget);
    expect(find.byType(Container), findsNothing);
  });

  testWidgets('streak badges can scale their icon and tally together', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StreakBadge(value: 2, scale: 1.25)),
      ),
    );

    expect(
      tester
          .widget<Icon>(find.byIcon(Icons.local_fire_department_outlined))
          .size,
      20,
    );
    expect(tester.widget<Text>(find.text('2')).style!.fontSize, 13.75);
  });

  testWidgets('streak page remains usable with enlarged text', (tester) async {
    final bloc = GameBloc(SecureGameStorage());
    final predictionCubit = PredictionCubit(
      MockPredictionRepository(),
      SecureGameStorage(),
    );
    final picksCubit = PicksCubit(MockPickRepository(), SecureGameStorage());
    addTearDown(bloc.close);
    addTearDown(predictionCubit.close);
    addTearDown(picksCubit.close);
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: bloc),
          BlocProvider.value(value: predictionCubit),
          BlocProvider.value(value: picksCubit),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          home: const StreakCalendarScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('STREAKS'), findsNWidgets(2));
    expect(find.text('CALENDAR'), findsOneWidget);
    expect(find.text('TODAY'), findsWidgets);
    const calendarPanel = ValueKey('streak-calendar-panel');
    expect(find.text('STREAK SHIELDS'), findsNothing);
    expect(find.text('KICK OFF'), findsOneWidget);
    expect(find.byKey(calendarPanel), findsNothing);
    expect(find.text('MILESTONES'), findsOneWidget);
    expect(find.text('365 DAYS'), findsNothing);

    // Glow rule: the STREAK CORE hero is the only panel allowed to glow.
    final glowingPanels = tester
        .widgetList<CyberPanel>(find.byType(CyberPanel))
        .where((panel) => panel.glow);
    expect(glowingPanels.length, lessThanOrEqualTo(1));

    Future<void> openTab(String label) async {
      final tab = find.descendant(
        of: find.byType(CyberUnderlineTabs),
        matching: find.text(label),
      );
      await tester.ensureVisible(tab);
      await tester.tap(tab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    await openTab('STREAKS');
    expect(find.text('STREAK SHIELDS'), findsOneWidget);
    expect(find.text('PENALTY SHOOTOUT'), findsOneWidget);
    expect(find.text('KICK OFF'), findsNothing);

    await openTab('MILESTONES');
    expect(find.text('365 DAYS'), findsOneWidget);
    expect(find.text('7 DAYS'), findsOneWidget);
    expect(find.text('KICK OFF'), findsNothing);

    await openTab('CALENDAR');
    expect(find.text('STREAK SHIELDS'), findsNothing);
    expect(find.byKey(calendarPanel), findsOneWidget);
    expect(find.text('365 DAYS'), findsNothing);

    final selected = DateTime.now().subtract(const Duration(days: 1));
    final selectedDayFinder = find.byKey(
      ValueKey('streak_calendar_day_${_dayKey(selected)}'),
    );
    await tester.ensureVisible(selectedDayFinder);
    await tester.tap(selectedDayFinder);
    await tester.pump(const Duration(milliseconds: 300));
    final selectedLabel = _fullDate(selected).toUpperCase();
    expect(find.text(selectedLabel), findsOneWidget);

    await openTab('TODAY');
    expect(find.text('KICK OFF'), findsOneWidget);
    expect(find.byKey(calendarPanel), findsNothing);

    await openTab('CALENDAR');
    expect(find.text(selectedLabel), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('rookie hub replaces streak tabs and routes the current game', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bloc = QuestHubBloc(UnlockProgress.fresh(Sport.cricket));
    final predictionCubit = PredictionCubit(
      MockPredictionRepository(),
      SecureGameStorage(),
    );
    final picksCubit = PicksCubit(MockPickRepository(), SecureGameStorage());
    addTearDown(bloc.close);
    addTearDown(predictionCubit.close);
    addTearDown(picksCubit.close);
    ArcadeGame? opened;

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<GameBloc>.value(value: bloc),
          BlocProvider.value(value: predictionCubit),
          BlocProvider.value(value: picksCubit),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.4),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: StreakCalendarScreen(
            onBeginnerNavigate: (game) => opened = game,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('rookie-path-panel')), findsOneWidget);
    expect(find.text('DAILY QUESTS LOCKED'), findsOneWidget);
    expect(find.text('TODAY'), findsNothing);
    expect(find.text('KICK OFF'), findsNothing);
    await tester.ensureVisible(find.text('PLAY NOW'));
    await tester.tap(find.text('PLAY NOW'));
    await tester.pump();
    expect(opened, ArcadeGame.finalOver);
    expect(tester.takeException(), isNull);
  });

  testWidgets('games beginner quest card stays compact and actionable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ArcadeGame? opened;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: BeginnerQuestCard(
              sport: Sport.football,
              unlocks: UnlockProgress.fresh(Sport.football),
              onPlay: (game) => opened = game,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text("BEGINNER'S QUEST"), findsOneWidget);
    expect(find.text('PLAY PITCH DUEL'), findsOneWidget);
    expect(find.text('+40 XP'), findsOneWidget);
    expect(find.text('1 RUN // UNLOCKS PENALTY SHOOTOUT'), findsOneWidget);
    expect(find.text('STEP 1 OF 6'), findsNothing);
    expect(
      find.text('Finish one run - win or lose - to unlock PENALTY SHOOTOUT.'),
      findsNothing,
    );
    await tester.tap(find.text('PLAY NOW'));
    await tester.pump();
    expect(opened, ArcadeGame.pitchDuel);
    expect(tester.takeException(), isNull);
  });

  testWidgets('top bar swaps the flame for rookie ladder progress', (
    tester,
  ) async {
    final bloc = QuestHubBloc(UnlockProgress.fresh(Sport.cricket));
    addTearDown(bloc.close);
    await tester.pumpWidget(
      BlocProvider<GameBloc>.value(
        value: bloc,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: StatOzTopBar(title: 'StatOz', onAddCoins: () {}),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('top-bar-rookie-path')), findsOneWidget);
    expect(find.byKey(const ValueKey('top-bar-streak')), findsNothing);
    expect(find.text('0/3'), findsOneWidget);
  });

  testWidgets('graduated careers choose TODAY or multi-sport QUESTS', (
    tester,
  ) async {
    Future<void> pumpFor(UnlockProgress unlocks) async {
      final bloc = QuestHubBloc(unlocks);
      final predictionCubit = PredictionCubit(
        MockPredictionRepository(),
        SecureGameStorage(),
      );
      final picksCubit = PicksCubit(MockPickRepository(), SecureGameStorage());
      addTearDown(bloc.close);
      addTearDown(predictionCubit.close);
      addTearDown(picksCubit.close);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<GameBloc>.value(value: bloc),
            BlocProvider.value(value: predictionCubit),
            BlocProvider.value(value: picksCubit),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const StreakCalendarScreen(),
          ),
        ),
      );
      await tester.pump();
    }

    final oneSport = UnlockProgress(
      homeSport: Sport.football,
      unlockedSports: const {Sport.football},
      ladderReached: const {Sport.football: 6},
      completedQuests: const {Sport.football},
    );
    await pumpFor(oneSport);
    expect(find.text('TODAY'), findsWidgets);
    expect(find.byKey(const ValueKey('quest-list-page')), findsNothing);

    final twoSports = oneSport.unlockSport(Sport.cricket);
    await pumpFor(twoSports);
    expect(find.text('QUESTS'), findsOneWidget);
    expect(find.text('TODAY'), findsNothing);
    expect(find.byKey(const ValueKey('quest-list-page')), findsOneWidget);
    expect(find.text('DAILY QUESTS'), findsOneWidget);
    expect(find.text('SPORT QUESTS'), findsOneWidget);
    expect(find.text('NEXT: PLAY FINAL OVER'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

String _dayKey(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _fullDate(DateTime date) =>
    '${_monthName(date.month)} ${date.day}, ${date.year}';

String _monthName(int month) => const [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
][month - 1];
