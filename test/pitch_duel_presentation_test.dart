import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_state.dart';
import 'package:card_game/config/enums.dart';
import 'package:card_game/config/theme.dart';
import 'package:card_game/config/tutorial_steps.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/models/match.dart';
import 'package:card_game/models/pitch_duel_rules.dart';
import 'package:card_game/screens/game/widgets/duel_board_phase.dart';
import 'package:card_game/screens/game/widgets/match_phases.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/widgets/cyber/cyber_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

GameState fixture({bool attacking = true}) {
  final base = GameState.initial();
  return base.copyWith(
    loading: false,
    phase: MatchPhase.play,
    currentRound: 1,
    playerAttacking: attacking,
    currentScenario: scenarios.first,
    opponentAttackers: base.deckAttackers,
    opponentDefenders: base.deckDefenders,
    opponentActions: base.deckActions,
    selectedPlayerCard:
        (attacking ? base.deckAttackers : base.deckDefenders).first,
    selectedActionCard: base.deckActions.firstWhere(
      (a) => pitchActionFitsRole(a, attacking),
    ),
    tutorialSeen: tutorialKeys.toSet(),
  );
}

Widget app(
  GameBloc bloc,
  Widget child, {
  double text = 1,
  bool reduced = false,
}) => BlocProvider.value(
  value: bloc,
  child: MaterialApp(
    theme: AppTheme.darkTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(text),
        disableAnimations: reduced,
      ),
      child: GameTypographyScope(child: child!),
    ),
    home: child,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'attack and defense choices and COMMIT fit compact/tall phones with enlarged text',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final size in [const Size(360, 740), const Size(412, 915)]) {
        await tester.binding.setSurfaceSize(size);
        for (final attacking in [true, false]) {
          final bloc = GameBloc(SecureGameStorage())
            ..emit(fixture(attacking: attacking));
          addTearDown(bloc.close);
          await tester.pumpWidget(
            app(
              bloc,
              DuelBoardPhase(state: bloc.state, onQuit: () {}),
              text: 1.4,
            ),
          );
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
          expect(
            find
                .text(attacking ? 'COMMIT ATTACK' : 'COMMIT DEFENSE')
                .hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('user-player-rail')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('user-action-rail')),
            findsOneWidget,
          );
          expect(
            tester
                .getRect(find.byKey(const ValueKey('user-player-rail')))
                .bottom,
            lessThan(size.height),
          );
          expect(
            tester
                .getRect(find.byKey(const ValueKey('duel-intel-strip')))
                .bottom,
            lessThanOrEqualTo(
              tester
                  .getRect(find.byKey(const ValueKey('user-player-rail')))
                  .top,
            ),
            reason: 'Cards must not cover the scenario or rival power range.',
          );
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    },
  );

  testWidgets(
    'meter pauses during tutorial, then freezes the exact scored bonus on strike',
    (tester) async {
      final state = fixture();
      final bloc = GameBloc(SecureGameStorage())
        ..emit(state.copyWith(tutorialSeen: {}));
      addTearDown(bloc.close);
      final power = pitchPower(
        player: state.selectedPlayerCard!,
        action: state.selectedActionCard!,
        scenario: state.currentScenario!,
        attacking: true,
      );
      await tester.binding.setSurfaceSize(const Size(360, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        app(
          bloc,
          ShotMeterOverlay(
            power: power,
            accent: Cyber.cyan,
            rivalRange: playerRivalRange(state),
            attacking: true,
          ),
          text: 1.4,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.takeException(), isNull);
      expect(find.text('GET READY'), findsOneWidget);
      // Skip the walkthrough; scoring only starts after its completion callback.
      final skip = find.text('GOT IT >');
      expect(skip, findsOneWidget);
      await tester.tap(skip);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 450));
      await tester.tap(find.text('TAP TO STRIKE'));
      await tester.pump();
      expect(find.textContaining('PERFECT +8'), findsWidgets);
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.textContaining('PERFECT +8'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'normal, skipped and reduced-motion reveals settle identical rewards once',
    (tester) async {
      final rewards = <(int, int, int?)>[];
      for (final presentation in ['normal', 'skipped', 'reduced']) {
        final reduced = presentation == 'reduced';
        final state = fixture();
        final attack = pitchPower(
          player: state.deckAttackers.first,
          action: state.selectedActionCard!,
          scenario: state.currentScenario!,
          attacking: true,
          timing: 4,
        );
        final defenseAction = state.deckActions.firstWhere(
          (a) => a.category == ActionCategory.defense,
        );
        final defense = pitchPower(
          player: state.deckDefenders.first,
          action: defenseAction,
          scenario: state.currentScenario!,
          attacking: false,
          timing: 0,
        );
        final result = RoundResult(
          round: 1,
          scenario: state.currentScenario!,
          playerAttacking: true,
          attackerCard: state.deckAttackers.first,
          defenderCard: state.deckDefenders.first,
          attackAction: state.selectedActionCard!,
          defenseAction: defenseAction,
          outcome: RoundOutcome.goal,
          attackPower: attack.total.toDouble(),
          defensePower: defense.total.toDouble(),
          attackBreakdown: attack,
          defenseBreakdown: defense,
        );
        final bloc = GameBloc(SecureGameStorage())
          ..emit(
            state.copyWith(
              phase: MatchPhase.roundResult,
              currentRound: 4,
              playerScore: 1,
              roundResults: [result],
            ),
          );
        addTearDown(bloc.close);
        await tester.pumpWidget(
          app(
            bloc,
            DuelBoardPhase(state: bloc.state, onQuit: () {}),
            reduced: reduced,
          ),
        );
        await tester.pump();
        if (presentation == 'skipped') {
          await tester.tap(find.text('TAP TO FINISH REVEAL'));
          await tester.pump();
        } else if (presentation == 'normal') {
          await tester.pump(const Duration(milliseconds: 1450));
        }
        expect(bloc.state.roundResults, [result]);
        expect(bloc.state.playerScore, 1);
        expect(bloc.state.matchHistory, isEmpty);
        expect(find.text('FULL-TIME RESULT'), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
        expect(bloc.state.phase, MatchPhase.roundResult);
        await tester.tap(find.text('FULL-TIME RESULT'));
        for (
          var i = 0;
          i < 20 && bloc.state.phase != MatchPhase.finalResult;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(bloc.state.phase, MatchPhase.finalResult);
        expect(bloc.state.matchHistory, hasLength(1));
        rewards.add((
          bloc.state.coins,
          bloc.state.progression.totalXP,
          bloc.state.lastMatchXP,
        ));
        await tester.pumpWidget(const SizedBox.shrink());
      }
      expect(rewards.toSet(), hasLength(1));
    },
  );

  testWidgets(
    'missing football portrait and vector assets render their fallbacks',
    (tester) async {
      const p = PlayerCard(
        id: 'fallback',
        name: 'Fallback',
        shortName: 'FALLBACK',
        country: '',
        countryCode: '',
        position: 'ST',
        role: PlayerRole.attacker,
        rating: 80,
        trait: 'Finisher',
        tier: CardTier.bronze,
        icon: Icons.person,
        portraitAsset: 'assets/not-present.webp',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const CyberPlayerCardTile(card: p, selected: false),
                const PitchVectorArt(asset: 'assets/not-present.svg'),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('FALLBACK'), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
