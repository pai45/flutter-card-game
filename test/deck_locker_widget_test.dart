import 'package:card_game/blocs/final_over/final_over_cubit.dart';
import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_state.dart';
import 'package:card_game/screens/deck/all_decks_screen.dart';
import 'package:card_game/screens/profile/widgets/all_decks_profile_card.dart';
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

  testWidgets('Deck Locker renders all five locked sport channels', (
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
    expect(find.text('FOOTBALL'), findsOneWidget);
    expect(find.text('CRICKET'), findsOneWidget);
    expect(find.text('BASKETBALL'), findsOneWidget);
    expect(find.text('TENNIS'), findsOneWidget);
    expect(find.text('F1 / RACING'), findsOneWidget);
    expect(find.text('LOCKED'), findsNWidgets(5));
    expect(find.text('OPEN THE STARTER PACK IN GAMES'), findsNWidgets(5));
  });

  testWidgets('unlocked football channel opens management mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await _pumpLocker(
      tester,
      GameState.initial().copyWith(
        loading: false,
        starterPackClaimed: true,
      ),
    );
    addTearDown(harness.dispose);
    final footballCard = find.ancestor(
      of: find.text('FOOTBALL'),
      matching: find.byType(PressableScale),
    );

    await tester.tap(footballCard.first);
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
  GameState state,
) async {
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
      child: MaterialApp(home: AllDecksScreen(onBack: () {})),
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
