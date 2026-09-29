import 'package:card_game/blocs/guess_player/guess_player_cubit.dart';
import 'package:card_game/config/theme.dart';
import 'package:card_game/data/guess_player_data.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/models/guess_player.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/screens/guess_player/cricket_guess_player_lobby.dart';
import 'package:card_game/screens/guess_player/guess_player_home_screen.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/widgets/cyber/cyber_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _day = '2026-09-29';

GuessPlayerDayRecord _record({
  GuessPlayerResultStatus status = GuessPlayerResultStatus.inProgress,
  int started = 0,
  int xp = 0,
}) => GuessPlayerDayRecord(
  dayKey: _day,
  puzzleId: 'cricket-preview',
  playerId: 'hidden',
  status: status,
  guessedPlayerIds: const [],
  revealedClueCount: 1,
  attemptsRemaining: 6,
  score: 0,
  xpEarned: xp,
  elapsedMs: 0,
  startedAtEpochMs: started,
  completedAtEpochMs: status == GuessPlayerResultStatus.inProgress ? 0 : 1,
);

GuessPlayerState _state(GuessPlayerDayRecord record) =>
    GuessPlayerState.loading(_day).copyWith(
      loadStatus: GuessPlayerLoadStatus.ready,
      archive: GuessPlayerArchive(resultsByDay: {_day: record}),
      activeRecord: record,
      attemptsRemaining: record.attemptsRemaining,
    );

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'Cricket case, record and both actions fit an enlarged small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var played = 0;
      var logs = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.4),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: CricketGuessPlayerLobby(
                state: _state(_record()),
                resetLabel: '12:34:56',
                ctaLabel: 'PLAY',
                onOpenToday: () => played++,
                onOpenLogs: () => logs++,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('CRICKET // DAILY INTEL'), findsOneWidget);
      expect(find.text('NEW CASE'), findsOneWidget);
      expect(find.text('UP TO +50 XP'), findsOneWidget);
      expect(find.text('12:34:56'), findsOneWidget);
      expect(find.text('0 SOLVED / 0 PLAYED'), findsOneWidget);
      tester
          .widget<CyberActionButton>(
            find.byKey(const ValueKey('cricket-guess-player-today')),
          )
          .onPressed!();
      expect(played, 1);
      await tester.ensureVisible(find.text('OPEN 30-DAY ARCHIVE'));
      await tester.pump();
      tester
          .widget<CyberActionButton>(
            find.byKey(const ValueKey('cricket-guess-player-archive')),
          )
          .onPressed!();
      expect(logs, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Cricket shows resume and solved review from real record states',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final record in [
        _record(started: 1),
        _record(status: GuessPlayerResultStatus.won, started: 1, xp: 50),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.4),
              ),
              child: Scaffold(
                body: CricketGuessPlayerLobby(
                  state: _state(record),
                  resetLabel: '08:00:00',
                  ctaLabel: record.completed ? 'REVIEW' : 'RESUME',
                  onOpenToday: () {},
                  onOpenLogs: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.text(record.completed ? 'SOLVED TODAY' : 'IN PROGRESS'),
          findsOneWidget,
        );
        expect(
          find.text(record.completed ? 'REVIEW RESULT' : 'RESUME CASE'),
          findsOneWidget,
        );
        if (record.completed) {
          expect(find.text('+50 XP EARNED'), findsOneWidget);
          expect(find.text('1 SOLVED / 1 PLAYED'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('shared lobby selects the kit only for Cricket', (tester) async {
    for (final sport in [Sport.cricket, Sport.football]) {
      final cubit = GuessPlayerCubit(
        sport: sport,
        timelines: sport == Sport.cricket
            ? cricketGuessTimelines
            : footballGuessTimelines,
        allPlayers: sport == Sport.cricket
            ? cricketPlayerCards
            : footballPlayerCards,
        storage: SecureGameStorage(),
      );
      await tester.pumpWidget(
        BlocProvider<GuessPlayerCubit>.value(
          value: cubit,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: GuessPlayerHomeScreen(
              state: _state(_record()),
              onBack: () {},
              onOpenToday: () {},
              onOpenLogs: () {},
              onRetry: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.byType(CricketGuessPlayerLobby),
        sport == Sport.cricket ? findsOneWidget : findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await cubit.close();
    }
  });
}
