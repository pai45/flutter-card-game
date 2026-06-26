import 'package:card_game/blocs/friends/friends_cubit.dart';
import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/screens/friends/friends_arena_screen.dart';
import 'package:card_game/screens/friends/referral_screen.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GameBloc> _loadedGameBloc() async {
  final bloc = GameBloc(SecureGameStorage())..add(GameLoaded());
  await bloc.stream.firstWhere((state) => !state.loading);
  return bloc;
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('referral screen renders link, progress, and demo statuses', (
    tester,
  ) async {
    final gameBloc = await _loadedGameBloc();
    addTearDown(gameBloc.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: gameBloc,
        child: const MaterialApp(home: ReferralScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('REFER A FRIEND'), findsOneWidget);
    expect(find.text('EARN 500 OZ COINS'), findsOneWidget);
    expect(find.text('SHARE REFERRAL LINK'), findsOneWidget);
    expect(
      find.textContaining('https://play.statoz.app/invite?ref='),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('NovaQ'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('NovaQ'), findsOneWidget);
    expect(find.text('Vortex'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('SIMULATE FRIEND JOINED'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('SIMULATE FRIEND JOINED'), findsOneWidget);
  });

  testWidgets('simulation updates referral status and wallet once', (
    tester,
  ) async {
    final gameBloc = await _loadedGameBloc();
    addTearDown(gameBloc.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: gameBloc,
        child: const MaterialApp(home: ReferralScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.scrollUntilVisible(
      find.text('SIMULATE FRIEND JOINED'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -140));
    await tester.pump();
    await tester.tap(find.text('SIMULATE FRIEND JOINED'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('REWARDED +500'), findsOneWidget);
    expect(find.text('+500 COINS'), findsOneWidget);
    expect(gameBloc.state.coins, 500);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('DEMO REWARD CLAIMED'), findsOneWidget);
  });

  testWidgets('Friends Arena shows invite card and opens referral screen', (
    tester,
  ) async {
    final gameBloc = await _loadedGameBloc();
    final friendsCubit = FriendsCubit(SecureGameStorage());
    await friendsCubit.load();
    addTearDown(gameBloc.close);
    addTearDown(friendsCubit.close);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: gameBloc),
          BlocProvider.value(value: friendsCubit),
        ],
        child: MaterialApp(home: FriendsArenaScreen(onChallenge: (_, _) {})),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('INVITE FRIENDS'), findsOneWidget);
    expect(find.text('EARN 500 OZ COINS'), findsOneWidget);

    await tester.tap(find.text('INVITE FRIENDS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('REFER A FRIEND'), findsOneWidget);
  });
}
