import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/screens/football_bingo/football_bingo_hub.dart';
import 'package:card_game/services/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('dbg', (tester) async {
    final game = GameBloc(SecureGameStorage())..add(GameLoaded());
    addTearDown(game.close);
    await tester.pumpWidget(MaterialApp(home: BlocProvider.value(value: game, child: FootballBingoTabContent(onNavigate: (_) {}))));
    await tester.pump();
    await tester.pump();
    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      // ignore: avoid_print
      print('TEXT=>[${t.data}]');
    }
  });
}
