import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/screens/profile/oz_coin_history_screen.dart';
import 'package:card_game/screens/profile/widgets/oz_coin_tracker_card.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _load(GameBloc bloc) async {
  bloc.add(GameLoaded());
  await bloc.stream
      .firstWhere((state) => !state.loading)
      .timeout(const Duration(seconds: 3));
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('coin tracker renders and opens history page', (tester) async {
    final bloc = GameBloc(SecureGameStorage());
    addTearDown(bloc.close);
    await _load(bloc);

    await tester.pumpWidget(
      BlocProvider.value(
        value: bloc,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => OzCoinTrackerCard(
                balance: bloc.state.coins,
                ledger: bloc.state.coinLedger,
                onViewHistory: () => showOzCoinHistory(context),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('OZ COIN TRACKER'), findsOneWidget);
    expect(find.text('BALANCE'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('HISTORY'));
    await tester.pumpAndSettle();

    expect(find.text('OZ COIN HISTORY'), findsOneWidget);
  });
}
