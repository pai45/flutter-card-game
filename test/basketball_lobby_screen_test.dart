import 'package:card_game/blocs/basketball/basketball_cubit.dart';
import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/config/enums.dart';
import 'package:card_game/screens/basketball/basketball_lobby_screen.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/widgets/cyber/cyber_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Hoop Duel lobby shows Deck Builder and Match History CTAs', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    final basketballCubit = BasketballCubit(SecureGameStorage());
    final gameBloc = GameBloc(SecureGameStorage());
    await basketballCubit.load();
    gameBloc.add(GameLoaded());
    await gameBloc.stream.firstWhere((state) => !state.loading);

    addTearDown(basketballCubit.close);
    addTearDown(gameBloc.close);

    var openedDeckBuilder = false;
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<BasketballCubit>.value(value: basketballCubit),
          BlocProvider<GameBloc>.value(value: gameBloc),
        ],
        child: MaterialApp(
          home: BasketballLobbyScreen(
            onNavigate: (AppSection _) {},
            onEditDeck: () => openedDeckBuilder = true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('TIP OFF'), findsOneWidget);
    expect(find.text('DECK BUILDER'), findsOneWidget);
    expect(find.text('MATCH HISTORY'), findsOneWidget);
    expect(find.text('ROSTER DECK'), findsNothing);
    expect(find.text('EDIT ROSTER DECK'), findsNothing);

    tester
        .widget<CyberCtaButton>(
          find.byKey(const ValueKey('hoop-deck-builder-button')),
        )
        .onPressed
        ?.call();
    expect(openedDeckBuilder, isTrue);
  });
}
