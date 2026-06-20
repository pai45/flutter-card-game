import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/picks/picks_cubit.dart';
import 'package:card_game/blocs/prediction/prediction_cubit.dart';
import 'package:card_game/config/theme.dart';
import 'package:card_game/screens/predictions/streak_calendar_screen.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/services/pick_repository.dart';
import 'package:card_game/services/prediction_repository.dart';
import 'package:card_game/widgets/streak_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    expect(find.text('MILESTONES'), findsOneWidget);
    expect(find.text('YOUR STREAKS'), findsOneWidget);
    expect(find.text('ACTIVITY CALENDAR'), findsNothing);
    expect(find.text('STREAK MILESTONES'), findsNothing);

    final surfaces = tester.widgetList<StreakElevatedSurface>(
      find.byType(StreakElevatedSurface),
    );
    expect(surfaces.length, greaterThanOrEqualTo(6));
    final hardShadowDecorations = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((widget) => widget.decoration)
        .whereType<ShapeDecoration>()
        .where((decoration) => decoration.shadows?.isNotEmpty ?? false);
    expect(hardShadowDecorations, isNotEmpty);
    for (final decoration in hardShadowDecorations) {
      expect(
        decoration.shadows!.every((shadow) => shadow.blurRadius == 0),
        isTrue,
      );
    }

    final calendarTab = find.byKey(const ValueKey('streak_page_tab_1'));
    await tester.ensureVisible(calendarTab);
    tester.widget<GestureDetector>(calendarTab).onTap!();
    await tester.pump();
    await tester.pump(StreakTheme.standardDuration + StreakTheme.fastDuration);
    expect(find.text('YOUR STREAKS'), findsNothing);
    expect(find.text('ACTIVITY CALENDAR'), findsOneWidget);
    expect(find.text('STREAK MILESTONES'), findsNothing);

    final selected = DateTime.now().subtract(const Duration(days: 1));
    final selectedDayFinder = find.byKey(
      ValueKey('streak_calendar_day_${_dayKey(selected)}'),
    );
    await tester.ensureVisible(selectedDayFinder);
    await tester.tap(selectedDayFinder);
    await tester.pump(StreakTheme.standardDuration);
    final selectedLabel = _fullDate(selected).toUpperCase();
    expect(find.text(selectedLabel), findsOneWidget);

    final milestoneTab = find.byKey(const ValueKey('streak_page_tab_2'));
    await tester.ensureVisible(milestoneTab);
    tester.widget<GestureDetector>(milestoneTab).onTap!();
    await tester.pump();
    await tester.pump(StreakTheme.standardDuration + StreakTheme.fastDuration);
    expect(find.text('STREAK MILESTONES'), findsOneWidget);
    expect(find.text('ACTIVITY CALENDAR'), findsNothing);

    await tester.ensureVisible(calendarTab);
    tester.widget<GestureDetector>(calendarTab).onTap!();
    await tester.pump();
    await tester.pump(StreakTheme.standardDuration + StreakTheme.fastDuration);
    expect(find.text(selectedLabel), findsOneWidget);
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
