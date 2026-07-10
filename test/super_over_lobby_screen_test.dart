import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/blocs/super_over/super_over_state.dart';
import 'package:card_game/models/super_over.dart';
import 'package:card_game/models/super_over_stats.dart';
import 'package:card_game/screens/super_over/super_over_lobby_screen.dart';
import 'package:card_game/screens/super_over/widgets/super_over_overlays.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/widgets/cyber/cyber_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Super Over lobby shows deck and history CTAs', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    final gameBloc = GameBloc(SecureGameStorage())..add(GameLoaded());
    await gameBloc.stream.firstWhere((state) => !state.loading);
    addTearDown(gameBloc.close);

    var openedDeckBuilder = false;
    await tester.pumpWidget(
      BlocProvider<GameBloc>.value(
        value: gameBloc,
        child: MaterialApp(
          home: SuperOverLobbyScreen(
            onBack: () {},
            onStartGame: () {},
            onEditDeck: () => openedDeckBuilder = true,
            onJerseySelected: (_) {},
            stats: const SuperOverStats(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('SUPER OVER'), findsOneWidget);
    expect(
      find.text('START CHASE').evaluate().isNotEmpty ||
          find.text('ADD BATTERS').evaluate().isNotEmpty,
      isTrue,
    );
    expect(
      find.byKey(const ValueKey('super-over-deck-builder-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('super-over-match-history-button')),
      findsOneWidget,
    );

    tester
        .widget<CyberCtaButton>(
          find.byKey(const ValueKey('super-over-deck-builder-button')),
        )
        .onPressed
        ?.call();
    expect(openedDeckBuilder, isTrue);
  });

  testWidgets('live overlay does not expose old sector or meter controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SuperOverOverlays(
          state: const SuperOverState(
            phase: SuperOverPhase.ballInFlight,
            inputEnabled: true,
          ),
          onBatTap: () {},
          onExit: () {},
        ),
      ),
    );

    expect(find.text('OFF'), findsNothing);
    expect(find.text('V'), findsNothing);
    expect(find.text('LEG'), findsNothing);
    expect(find.text('SHOOT'), findsNothing);
    expect(find.text('TAP TO SWING'), findsOneWidget);
  });
}
