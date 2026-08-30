import 'package:card_game/blocs/final_over/final_over_cubit.dart';
import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_state.dart';
import 'package:card_game/models/deck.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/screens/deck/all_decks_screen.dart';
import 'package:card_game/screens/profile/widgets/all_decks_profile_card.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/widgets/cyber/cyber_cta_button.dart';
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

  testWidgets('Profile exposes the ALL DECKS readiness panel', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: AllDecksProfileCard(
              game: GameState.initial().copyWith(loading: false),
              onTap: () => opened = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('ALL DECKS'), findsOneWidget);
    expect(find.textContaining('MANAGE THE SAME LOADOUTS'), findsOneWidget);
    expect(find.byIcon(Icons.sports_soccer), findsOneWidget);
    expect(find.byIcon(Icons.sports_cricket), findsOneWidget);
    expect(find.byIcon(Icons.sports_basketball), findsOneWidget);
    expect(find.byIcon(Icons.sports_tennis), findsOneWidget);
    expect(find.byIcon(Icons.sports_motorsports), findsOneWidget);

    await tester.tap(find.text('ALL DECKS'));
    expect(opened, isTrue);
  });

  testWidgets('Deck Locker opens on the football tab, locked', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await _pumpLocker(
      tester,
      GameState.initial().copyWith(loading: false),
    );
    addTearDown(harness.dispose);

    expect(find.text('DECK LOCKER'), findsOneWidget);
    expect(find.text('FOOTBALL SQUAD LOCKED'), findsOneWidget);
    expect(find.textContaining('claim your'), findsOneWidget);
    expect(find.text('PLAY FOOTBALL'), findsOneWidget);
  });

  testWidgets('sport tabs switch between locked loadouts', (tester) async {
    tester.view.physicalSize = const Size(430, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await _pumpLocker(
      tester,
      GameState.initial().copyWith(loading: false),
    );
    addTearDown(harness.dispose);

    expect(find.text('FOOTBALL SQUAD LOCKED'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.sports_cricket));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('CRICKET SQUAD LOCKED'), findsOneWidget);
    expect(find.text('PLAY CRICKET'), findsOneWidget);
  });

  testWidgets('locked tab CTA routes to that sport\'s GAMES tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Sport? playedSport;
    final harness = await _pumpLocker(
      tester,
      GameState.initial().copyWith(loading: false),
      onPlaySport: (sport) => playedSport = sport,
    );
    addTearDown(harness.dispose);

    await tester.tap(find.text('PLAY FOOTBALL'));
    expect(playedSport, Sport.football);
  });

  testWidgets('unlocked football channel shows the real squad and opens management mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final startingSlot = defaultDeckSlots.first;
    final harness = await _pumpLocker(
      tester,
      GameState.initial().copyWith(
        loading: false,
        starterPackClaimed: true,
        // Readiness also requires ownership, not just deck-slot assignment —
        // mirror what claiming the starter pack actually grants.
        ownedCardIds: [
          ...startingSlot.attackers,
          ...startingSlot.defenders,
          if (startingSlot.keeper != null) startingSlot.keeper!,
        ],
        ownedActionCardIds: startingSlot.actions,
      ),
    );
    addTearDown(harness.dispose);

    expect(find.text('FOOTBALL SQUAD LOCKED'), findsNothing);
    expect(find.text('EDIT LOADOUT'), findsOneWidget);
    expect(find.byType(CyberPlayerCardTile), findsWidgets);

    await tester.tap(find.byType(HudCtaButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('FOOTBALL DECK'), findsOneWidget);
    expect(find.text('SAVE LOADOUT'), findsOneWidget);
    expect(find.text('PLAY'), findsNothing);
  });

  testWidgets('Deck Locker has no overflow at 360px phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await _pumpLocker(
      tester,
      GameState.initial().copyWith(loading: false),
    );
    addTearDown(harness.dispose);

    expect(find.text('DECK LOCKER'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Deck Locker has no overflow at 900px wide layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await _pumpLocker(
      tester,
      GameState.initial().copyWith(loading: false),
    );
    addTearDown(harness.dispose);

    expect(find.text('DECK LOCKER'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}

Future<_LockerHarness> _pumpLocker(
  WidgetTester tester,
  GameState state, {
  ValueChanged<Sport>? onPlaySport,
}) async {
  final storage = SecureGameStorage();
  final game = GameBloc(storage)..emit(state);
  final finalOver = FinalOverCubit(storage);
  await finalOver.load();
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider.value(value: game),
        BlocProvider.value(value: finalOver),
      ],
      child: MaterialApp(
        home: AllDecksScreen(
          onBack: () {},
          onPlaySport: onPlaySport ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  await tester.pump(const Duration(milliseconds: 700));
  return _LockerHarness(game: game, finalOver: finalOver);
}

class _LockerHarness {
  const _LockerHarness({required this.game, required this.finalOver});

  final GameBloc game;
  final FinalOverCubit finalOver;

  Future<void> dispose() async {
    await game.close();
    await finalOver.close();
  }
}
