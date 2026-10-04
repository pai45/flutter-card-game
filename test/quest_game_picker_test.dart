import 'dart:async';

import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/blocs/game/game_state.dart';
import 'package:card_game/config/game_ladder.dart';
import 'package:card_game/config/theme.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/models/unlock_progress.dart';
import 'package:card_game/screens/predictions/widgets/beginner_quest_card.dart';
import 'package:card_game/screens/predictions/widgets/unlock_sheets.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/utils/sound_effects.dart';
import 'package:card_game/widgets/cyber/cyber_widgets.dart';
import 'package:card_game/widgets/unlock_celebration_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChoiceStorage extends SecureGameStorage {
  bool fail = false;
  int writes = 0;
  Completer<void>? saveGate;
  final started = Completer<void>();

  @override
  Future<void> saveUnlockProgress(UnlockProgress progress) async {
    writes++;
    if (!started.isCompleted) started.complete();
    if (saveGate != null) await saveGate!.future;
    if (fail) throw StateError('Test save failure');
    await super.saveUnlockProgress(progress);
  }
}

class _SilentAudio implements AudioPlaybackBackend {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class ChoiceBloc extends GameBloc {
  ChoiceBloc(super.storage, UnlockProgress progress) {
    emit(GameState.initial().copyWith(loading: false, unlocks: progress));
  }
}

Future<void> finishAsync(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

Widget host(GameBloc bloc, Widget child, {double scale = 1.4}) =>
    BlocProvider<GameBloc>.value(
      value: bloc,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    AudioController.debugUseBackend(_SilentAudio());
  });

  test(
    'save precedes unlock; concurrent selection taps commit only one mission',
    () async {
      final storage = ChoiceStorage()..saveGate = Completer();
      final bloc = ChoiceBloc(storage, UnlockProgress.fresh(Sport.football));
      final first = QuestGameSelected(ArcadeGame.footballChess);
      final duplicate = QuestGameSelected(ArcadeGame.footballQuiz);
      bloc.add(first);
      await storage.started.future;
      bloc.add(duplicate);
      expect(bloc.state.unlocks.currentStep(Sport.football), isNull);
      storage.saveGate!.complete();
      expect(await first.result.future, QuestGameSelectionResult.selected);
      expect(await duplicate.result.future, QuestGameSelectionResult.rejected);
      expect(storage.writes, 1);
      expect(
        (await storage.loadUnlockProgress())!.currentStep(Sport.football),
        ArcadeGame.footballChess,
      );
      expect(
        bloc.state.unlocks.currentStep(Sport.football),
        ArcadeGame.footballChess,
      );
      await bloc.close();
    },
  );

  test(
    'failed save preserves choice state and permits retry without rewards',
    () async {
      final storage = ChoiceStorage()..fail = true;
      final bloc = ChoiceBloc(storage, UnlockProgress.fresh(Sport.cricket));
      final failed = QuestGameSelected(ArcadeGame.cricketGuessPlayer);
      bloc.add(failed);
      expect(await failed.result.future, QuestGameSelectionResult.saveFailed);
      expect(bloc.state.unlocks.needsSelection(Sport.cricket), isTrue);
      expect(bloc.state.xpLedger, isEmpty);
      expect(bloc.state.unlocks.pendingReveals, isEmpty);
      storage.fail = false;
      final retry = QuestGameSelected(ArcadeGame.cricketGuessPlayer);
      bloc.add(retry);
      expect(await retry.result.future, QuestGameSelectionResult.selected);
      expect(bloc.state.coins, 0);
      expect(bloc.state.xpLedger, isEmpty);
      await bloc.close();
    },
  );

  for (final sport in Sport.values) {
    testWidgets(
      '$sport picker shows all games, supports dismissal, and launches the saved choice at 320px',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 852));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final storage = ChoiceStorage();
        final bloc = ChoiceBloc(storage, UnlockProgress.fresh(sport));
        addTearDown(bloc.close);
        final opened = <ArcadeGame>[];
        await tester.pumpWidget(
          host(
            bloc,
            BeginnerQuestCard(
              sport: sport,
              unlocks: bloc.state.unlocks,
              onPlay: opened.add,
            ),
          ),
        );
        expect(find.text('CHOOSE YOUR FIRST GAME'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('beginner-quest-choose')));
        await tester.pump(const Duration(milliseconds: 400));
        for (final game in sportGameLadder[sport]!) {
          expect(
            find.byKey(ValueKey('quest-choice-${game.name}')),
            findsOneWidget,
          );
        }
        expect(
          tester
              .widget<CyberActionButton>(
                find.byKey(const ValueKey('quest-choose-play')),
              )
              .onPressed,
          isNull,
        );
        Navigator.of(tester.element(find.byType(QuestGamePicker))).pop();
        await tester.pump(const Duration(milliseconds: 400));
        expect(storage.writes, 0);
        expect(opened, isEmpty);
        await tester.tap(find.byKey(const ValueKey('beginner-quest-choose')));
        await tester.pump(const Duration(milliseconds: 400));
        final game = sportGameLadder[sport]!.last;
        final option = find.byKey(ValueKey('quest-choice-${game.name}'));
        await tester.ensureVisible(option);
        await tester.tap(option);
        await tester.pump();
        final commit = find.byKey(const ValueKey('quest-choose-play'));
        await tester.ensureVisible(commit);
        await tester.tap(commit);
        await finishAsync(tester);
        expect(opened, [game]);
        expect((await storage.loadUnlockProgress())!.currentStep(sport), game);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('picker reports failed saves and retries the highlighted game', (
    tester,
  ) async {
    final storage = ChoiceStorage()..fail = true;
    final bloc = ChoiceBloc(storage, UnlockProgress.fresh(Sport.cricket));
    addTearDown(bloc.close);
    final opened = <ArcadeGame>[];
    await tester.pumpWidget(
      host(
        bloc,
        BeginnerQuestCard(
          sport: Sport.cricket,
          unlocks: bloc.state.unlocks,
          onPlay: opened.add,
        ),
        scale: 1,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('beginner-quest-choose')));
    await tester.pump(const Duration(milliseconds: 400));
    final option = find.byKey(const ValueKey('quest-choice-cricketQuiz'));
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pump();
    final commit = find.byKey(const ValueKey('quest-choose-play'));
    await tester.ensureVisible(commit);
    await tester.tap(commit);
    await finishAsync(tester);
    expect(
      find.text('Could not save your mission. Try again.'),
      findsOneWidget,
    );
    expect(opened, isEmpty);
    expect(bloc.state.unlocks.needsSelection(Sport.cricket), isTrue);
    storage.fail = false;
    await tester.ensureVisible(commit);
    await tester.tap(commit);
    await finishAsync(tester);
    expect(opened, [ArcadeGame.cricketQuiz]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'next picker excludes completed games and works from Rookie Path',
    (tester) async {
      final progress = UnlockProgress.fresh(Sport.cricket)
          .selectGame(ArcadeGame.cricketQuiz)
          .recordPlay(ArcadeGame.cricketQuiz, 'set')
          .progress;
      final bloc = ChoiceBloc(ChoiceStorage(), progress);
      addTearDown(bloc.close);
      final opened = <ArcadeGame>[];
      await tester.pumpWidget(
        host(
          bloc,
          BlocBuilder<GameBloc, GameState>(
            builder: (context, state) => RookiePathPanel(
              sport: Sport.cricket,
              unlocks: state.unlocks,
              onPlay: opened.add,
            ),
          ),
        ),
      );
      expect(find.text('CHOOSE YOUR NEXT GAME'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('beginner-quest-choose')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.byKey(const ValueKey('quest-choice-cricketQuiz')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('quest-choice-finalOver')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('quest-choice-cricketGuessPlayer')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('quest-choice-finalOver')));
      await tester.pump();
      final commit = find.byKey(const ValueKey('quest-choose-play'));
      await tester.ensureVisible(commit);
      await tester.tap(commit);
      await finishAsync(tester);
      expect(opened, [ArcadeGame.finalOver]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('waiting Match quest shortcut opens the sport picker', (
    tester,
  ) async {
    Sport? chosen;
    var hubOpened = false;
    UnlockRevealGate.instance.chooseGame = (sport) => chosen = sport;
    addTearDown(() => UnlockRevealGate.instance.chooseGame = null);
    final bloc = ChoiceBloc(
      ChoiceStorage(),
      UnlockProgress.fresh(Sport.tennis),
    );
    addTearDown(bloc.close);
    await tester.pumpWidget(
      host(
        bloc,
        BeginnerQuestStrip(
          sport: Sport.tennis,
          unlocks: bloc.state.unlocks,
          onTap: () => hubOpened = true,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('beginner-quest-strip-tennis')));
    expect(chosen, Sport.tennis);
    expect(hubOpened, isFalse);
  });

  testWidgets(
    'third chosen football mission celebrates graduation and offers another choice',
    (tester) async {
      var progress = UnlockProgress.fresh(Sport.football);
      for (final game in [
        ArcadeGame.footballChess,
        ArcadeGame.footballBingo,
        ArcadeGame.penaltyShootout,
      ]) {
        progress = progress
            .selectGame(game)
            .recordPlay(game, game.name)
            .progress;
      }
      progress = progress.copyWith(
        pendingReveals: [progress.pendingReveals.last],
      );
      final bloc = ChoiceBloc(ChoiceStorage(), progress);
      addTearDown(bloc.close);
      Sport? chosen;
      UnlockRevealGate.instance.hubVisible.value = true;
      UnlockRevealGate.instance.chooseGame = (sport) => chosen = sport;
      addTearDown(() {
        UnlockRevealGate.instance.hubVisible.value = false;
        UnlockRevealGate.instance.chooseGame = null;
      });
      await tester.pumpWidget(
        host(
          bloc,
          const SizedBox(height: 800, child: UnlockCelebrationHost()),
          scale: 1,
        ),
      );
      await tester.pump();
      expect(find.text('BEGINNER CHAPTER COMPLETE'), findsOneWidget);
      expect(find.textContaining('3/6 missions cleared.'), findsOneWidget);
      final choose = find.text('CHOOSE NEXT GAME');
      await tester.ensureVisible(choose);
      await tester.tap(choose);
      expect(chosen, Sport.football);
      await finishAsync(tester);
      expect(bloc.state.unlocks.pendingReveals, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
