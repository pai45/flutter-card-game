import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_state.dart';
import 'package:card_game/config/enums.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/screens/game/widgets/duel_board_phase.dart';
import 'package:card_game/screens/game/widgets/match_phases.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/widgets/cyber/cyber_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  final scenario = scenarios.first;

  GameState scenarioState(GameState base) => base.copyWith(
    loading: false,
    phase: MatchPhase.scenario,
    currentRound: 1,
    playerAttacking: false,
    currentScenario: scenario,
    opponentAttackers: base.deckAttackers,
    opponentDefenders: base.deckDefenders,
    opponentActions: base.deckActions,
    tutorialSeen: const {'scenario', 'play', 'round-result'},
  );

  testWidgets('ScenarioBriefingSection calls onComplete after countdown', (
    tester,
  ) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: ScenarioBriefingSection(
          scenario: scenario,
          attacking: false,
          initialSeconds: 3,
          onComplete: () => completed = true,
        ),
      ),
    );

    expect(find.text('3'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('1'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('GO'), findsOneWidget);
    expect(completed, isTrue);
  });

  testWidgets(
    'Duel Board play beat fits one screen — hand and COMMIT visible, no scroll',
    (tester) async {
      // A tight phone, the reference canvas and a tall phone must all keep the
      // complete move hit-testable without introducing a scroll view.
      for (final size in const [
        Size(360, 740),
        Size(390, 844),
        Size(412, 915),
      ]) {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final bloc = GameBloc(SecureGameStorage());
        addTearDown(bloc.close);
        final base = GameState.initial().copyWith(loading: false);
        final defenseAction = base.deckActions.firstWhere(
          (c) => c.category == ActionCategory.defense,
        );
        bloc.emit(
          scenarioState(base).copyWith(
            phase: MatchPhase.play,
            selectedPlayerCard: base.deckDefenders.first,
            selectedActionCard: defenseAction,
          ),
        );

        await tester.pumpWidget(
          BlocProvider.value(
            value: bloc,
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: DuelBoardPhase(state: bloc.state, onQuit: () {}),
            ),
          ),
        );
        await tester.pump();
        // Let the dealt-hand entrance animations finish so no timers linger.
        await tester.pump(const Duration(seconds: 2));

        expect(tester.takeException(), isNull);
        // The whole round decision is on ONE screen: both defenders, the
        // docked COMMIT CTA and the action hand all hit-testable with zero
        // scrolling.
        expect(find.text('COMMIT DEFENSE').hitTestable(), findsOneWidget);
        expect(find.byKey(const ValueKey('duel-full-pitch')), findsOneWidget);
        for (final card in base.deckDefenders) {
          expect(find.text(card.shortName).hitTestable(), findsWidgets);
        }
        expect(
          find.text(defenseAction.title.toUpperCase()).hitTestable(),
          findsWidgets,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
  );

  Future<void> pumpGuidanceState(
    WidgetTester tester, {
    required bool attacking,
    bool playerSelected = false,
    bool actionSelected = false,
    bool opponentCommitted = false,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final base = GameState.initial().copyWith(loading: false);
    final player = attacking
        ? base.deckAttackers.first
        : base.deckDefenders.first;
    final action = base.deckActions.firstWhere(
      (card) =>
          card.category ==
          (attacking ? ActionCategory.attack : ActionCategory.defense),
    );
    final opponentPlayer = attacking
        ? base.deckDefenders.first
        : base.deckAttackers.first;
    final opponentAction = base.deckActions.firstWhere(
      (card) =>
          card.category ==
          (attacking ? ActionCategory.defense : ActionCategory.attack),
    );
    final state = scenarioState(base).copyWith(
      phase: MatchPhase.play,
      playerAttacking: attacking,
      selectedPlayerCard: playerSelected ? player : null,
      selectedActionCard: actionSelected ? action : null,
      opponentSelectedPlayerCard: opponentCommitted ? opponentPlayer : null,
      opponentSelectedActionCard: opponentCommitted ? opponentAction : null,
    );
    final bloc = GameBloc(SecureGameStorage())..emit(state);
    addTearDown(bloc.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: bloc,
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: DuelBoardPhase(state: state, onQuit: () {}),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('duel-full-pitch')), findsOneWidget);
    expect(find.byKey(const ValueKey('opponent-full-hand')), findsOneWidget);
  }

  testWidgets('attack dock starts with player and action guidance', (
    tester,
  ) async {
    await pumpGuidanceState(tester, attacking: true);
    expect(find.text('BUILD YOUR ATTACK').hitTestable(), findsOneWidget);
    expect(
      find.text('Play 1 attacker + 1 action card').hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('defense dock starts with player and action guidance', (
    tester,
  ) async {
    await pumpGuidanceState(tester, attacking: false);
    expect(find.text('SET YOUR DEFENSE').hitTestable(), findsOneWidget);
    expect(
      find.text('Play 1 defender + 1 action card').hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('player selection advances the dock to the action step', (
    tester,
  ) async {
    await pumpGuidanceState(tester, attacking: true, playerSelected: true);
    expect(find.text('PLAYER READY').hitTestable(), findsOneWidget);
    expect(
      find.text('Now play an attack action card').hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('action-first selection advances the dock to the player step', (
    tester,
  ) async {
    await pumpGuidanceState(tester, attacking: false, actionSelected: true);
    expect(find.text('ACTION PRIMED').hitTestable(), findsOneWidget);
    expect(find.text('Now choose your defender').hitTestable(), findsOneWidget);
  });

  testWidgets('complete attack becomes the commit CTA and locks the CPU card', (
    tester,
  ) async {
    await pumpGuidanceState(
      tester,
      attacking: true,
      playerSelected: true,
      actionSelected: true,
      opponentCommitted: true,
    );
    expect(find.text('COMMIT ATTACK').hitTestable(), findsOneWidget);
    expect(find.textContaining('GOAL CHANCE').hitTestable(), findsOneWidget);
    expect(find.text('LOCKED'), findsNWidgets(2));
  });

  testWidgets(
    'all four card rails are straight and the opponent action hand is mirrored',
    (tester) async {
      await pumpGuidanceState(tester, attacking: true);
      final base = GameState.initial();
      final opponentActions = base.deckActions
          .where(
            (card) =>
                card.category == ActionCategory.defense ||
                card.category == ActionCategory.special,
          )
          .toList();

      List<double> bottoms(Iterable<String> keys) => keys
          .map(
            (key) => tester.getRect(find.byKey(ValueKey<String>(key))).bottom,
          )
          .toList();

      void expectStraight(List<double> values) {
        expect(values, isNotEmpty);
        for (final value in values.skip(1)) {
          expect(value, closeTo(values.first, 0.1));
        }
      }

      expectStraight(
        bottoms(
          [
            ...base.deckAttackers,
            ...base.deckDefenders,
          ].map((card) => 'user-player-card-${card.id}'),
        ),
      );
      expectStraight(
        bottoms(
          base.deckActions
              .where(
                (card) =>
                    card.category == ActionCategory.attack ||
                    card.category == ActionCategory.special,
              )
              .map((card) => 'user-action-card-${card.id}'),
        ),
      );
      expectStraight(
        bottoms(
          [
            ...base.deckAttackers,
            ...base.deckDefenders,
          ].map((card) => 'opponent-player-card-${card.id}'),
        ),
      );
      expectStraight(
        bottoms(
          opponentActions.map((card) => 'opponent-action-card-${card.id}'),
        ),
      );

      final opponentActionRail = find.byKey(
        const ValueKey('opponent-action-rail'),
      );
      final opponentPlayerRail = find.byKey(
        const ValueKey('opponent-player-rail'),
      );
      expect(
        tester.getRect(opponentActionRail).bottom,
        lessThan(tester.getRect(opponentPlayerRail).top),
      );
      final actionBacks = tester
          .widgetList<CardBackFace>(
            find.descendant(
              of: opponentActionRail,
              matching: find.byType(CardBackFace),
            ),
          )
          .toList();
      expect(actionBacks, hasLength(opponentActions.length));
      expect(
        actionBacks.every(
          (back) => back.silhouette == CardBackSilhouette.action,
        ),
        isTrue,
      );

      for (final card in opponentActions) {
        final transform = tester.widget<Transform>(
          find.byKey(ValueKey('opponent-action-card-${card.id}')),
        );
        expect(transform.transform.storage[0], closeTo(-1, 0.001));
        expect(transform.transform.storage[5], closeTo(-1, 0.001));
      }

      final boardPlayerTiles = tester.widgetList<CyberPlayerCardTile>(
        find.descendant(
          of: find.byKey(const ValueKey('user-player-rail')),
          matching: find.byType(CyberPlayerCardTile),
        ),
      );
      final boardActionTiles = tester.widgetList<CyberActionCardTile>(
        find.descendant(
          of: find.byKey(const ValueKey('user-action-rail')),
          matching: find.byType(CyberActionCardTile),
        ),
      );
      expect(boardPlayerTiles.every((tile) => !tile.tiltOnSelect), isTrue);
      expect(boardActionTiles.every((tile) => !tile.tiltOnSelect), isTrue);
    },
  );

  testWidgets('both opponent picks remain hidden when their locks settle', (
    tester,
  ) async {
    await pumpGuidanceState(tester, attacking: false, opponentCommitted: true);
    expect(find.text('LOCKED'), findsNWidgets(2));
    final lockedBacks = tester.widgetList<CardBackFace>(
      find.descendant(
        of: find.byKey(const ValueKey('opponent-full-hand')),
        matching: find.byType(CardBackFace),
      ),
    );
    expect(lockedBacks, hasLength(8));
  });
}
