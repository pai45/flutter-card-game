import 'dart:math';

import 'package:card_game/blocs/football_chess/football_chess_cubit.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/models/football_chess.dart';
import 'package:card_game/screens/football_chess/widgets/football_chess_toss_phase.dart';
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

  testWidgets(
    'shared toss calls the coin and begins Football Chess once after landing',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cubit = FootballChessCubit(SecureGameStorage(), random: Random(7));
      addTearDown(() async {
        if (!cubit.isClosed) await cubit.close();
      });
      final match = cubit.buildMatch(
        playerSquad: [
          attackers[0],
          attackers[1],
          defenders[0],
          defenders[1],
          goalkeepers[0],
        ],
        formation: ChessFormation.box,
        opponentSquad: [
          attackers[2],
          attackers[3],
          defenders[2],
          defenders[3],
          goalkeepers[1],
        ],
        opponentName: 'Maya Santos',
        opponentLevel: 12,
      );
      cubit.startMatch(match);

      var begins = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: BlocProvider.value(
                value: cubit,
                child: FootballChessTossPhase(
                  tossKey: GlobalKey(),
                  onCall: cubit.callToss,
                  onBeginPlay: () {
                    begins++;
                    cubit.beginPlay();
                  },
                  onQuit: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('COIN TOSS'), findsOneWidget);
      expect(find.text('HEADS'), findsOneWidget);
      expect(find.text('TAILS'), findsOneWidget);

      await tester.tap(find.text('HEADS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      await tester.pump();

      expect(cubit.state.match?.tossResult, isNotNull);
      expect(find.textContaining('WON THE TOSS'), findsOneWidget);
      expect(find.text('KICKOFF PROTOCOL LOCKED'), findsOneWidget);
      expect(begins, 0);

      await tester.pump(const Duration(milliseconds: 500));
      expect(begins, 0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(begins, 1);
      expect(
        cubit.state.match?.phase,
        anyOf(ChessMatchPhase.playerTurn, ChessMatchPhase.opponentTurn),
      );

      await tester.pump(const Duration(seconds: 1));
      expect(begins, 1);
      expect(tester.takeException(), isNull);
      await cubit.close();
    },
  );
}
