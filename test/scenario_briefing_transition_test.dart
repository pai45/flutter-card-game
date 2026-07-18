import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_state.dart';
import 'package:card_game/config/enums.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/screens/game/widgets/duel_board_phase.dart';
import 'package:card_game/screens/game/widgets/match_phases.dart';
import 'package:card_game/services/secure_storage_service.dart';
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
    'Duel Board play beat fits one screen — hand and LOCK visible, no scroll',
    (tester) async {
      // Both a tight small phone and the reference device: the play beat must
      // lay out without overflow at either size (FittedBox guard on tiny
      // bands, plain column otherwise).
      for (final size in const [Size(360, 740), Size(412, 915)]) {
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
        // docked LOCK CTA and the action hand all hit-testable with zero
        // scrolling.
        expect(find.text('LOCK DEFENSE').hitTestable(), findsOneWidget);
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
}
