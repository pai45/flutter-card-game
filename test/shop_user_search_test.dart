import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/friends/friends_cubit.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/config/theme.dart';
import 'package:card_game/data/rival_roster.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/models/shop.dart';
import 'package:card_game/screens/shop/shop_screen.dart';
import 'package:card_game/screens/shop/widgets/shop_acquire_overlay.dart';
import 'package:card_game/screens/leaderboard/user_search_screen.dart';
import 'package:card_game/screens/leaderboard/leaderboard_screen.dart';
import 'package:card_game/screens/friends/widgets/rival_search_result_card.dart';
import 'package:card_game/screens/profile/rival_profile_screen.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/utils/catalogue_search.dart';
import 'package:card_game/utils/sound_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    for (final channel in [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
    AudioController.instance.muted.value = true;
  });
  test(
    'shop indexes every category and complete card catalogue without duplicate products',
    () {
      expect(shopSearchCatalogue.map((e) => e.category).toSet(), {
        0,
        1,
        2,
        3,
        4,
        5,
        6,
      });
      expect(
        shopSearchCatalogue.map((e) => e.id).toSet().length,
        shopSearchCatalogue.length,
      );
      expect(
        shopSearchCatalogue.where((e) => e.category == 6).length,
        allPlayerCards.length,
      );
      expect(
        searchShopCatalogue('coins').where((e) => e.category == 4).length,
        coinTiers.length,
      );
      final beyond = allPlayerCards[60];
      expect(
        searchShopCatalogue(beyond.name).map((e) => e.id),
        contains('6:${beyond.id}'),
      );
    },
  );
  test(
    'shop matches full names, metadata words, team codes and country names',
    () {
      for (final query in [
        'lionel messi',
        'argentina',
        'ARG',
        'Mumbai Indians',
        'Lakers',
        'Spain tennis',
        'Ferrari',
        'frame',
        'banner',
        'pack',
        'jersey',
      ]) {
        expect(searchShopCatalogue(query), isNotEmpty, reason: query);
      }
      expect(
        searchShopCatalogue('  LIONEL   MESSI ').map((e) => e.id),
        searchShopCatalogue('lionel messi').map((e) => e.id),
      );
      expect(searchShopCatalogue('never-existing-item'), isEmpty);
      expect(searchShopCatalogue(' '), isEmpty);
      expect(searchShopCatalogue('a'), isEmpty);
      expect(
        catalogueMatches('messi argentina', ['Lionel Messi', 'Argentina']),
        isTrue,
      );
      expect(catalogueMatchPriority('Messi', 'messi'), 0);
      expect(catalogueMatchPriority('Messi fan', 'messi'), 1);
    },
  );
  test(
    'rival search returns all matching non-self users in relevance order',
    () {
      for (final seed in kRivalRoster.where((s) => !s.isUser)) {
        expect(
          searchRivals('  ${seed.name.toUpperCase()} ').first.name,
          seed.name,
        );
      }
      final expected = kRivalRoster
          .where((s) => !s.isUser && s.name.toLowerCase().contains('ri'))
          .length;
      expect(searchRivals('ri').length, expected);
      expect(expected, greaterThan(1));
      expect(searchRivals('pai').any((e) => e.isUser), isFalse);
      expect(searchRivals('zzzzzz'), isEmpty);
      expect(searchRivals('r'), isEmpty);
    },
  );
  testWidgets(
    'user search clears, handles no matches and opens the existing profile',
    (tester) async {
      final bloc = GameBloc(SecureGameStorage());
      addTearDown(bloc.close);
      await tester.pumpWidget(_app(bloc, const UserSearchScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.byType(TextField), 'ri');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(RivalSearchResultCard), findsWidgets);
      await tester.enterText(find.byType(TextField), 'zzzzzz');
      await tester.pump();
      expect(find.text('NO PLAYERS FOUND'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Clear search'));
      await tester.pump();
      expect(find.text('START YOUR SEARCH'), findsOneWidget);
      final seed = kRivalRoster.firstWhere((s) => !s.isUser);
      await tester.enterText(find.byType(TextField), seed.name);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('VIEW'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(RivalProfileScreen), findsOneWidget);
    },
  );
  testWidgets(
    'shop search categories fit a narrow screen with keyboard and clear',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bloc = GameBloc(SecureGameStorage());
      addTearDown(bloc.close);
      await tester.pumpWidget(_app(bloc, const ShopSearchScreen()));
      for (final query in [
        'avatar',
        'frame',
        'banner',
        'jersey',
        'coins',
        'pack',
        'card',
        'zzzzzz',
      ]) {
        await tester.enterText(find.byType(TextField), query);
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull, reason: query);
      }
      expect(find.text('NO ITEMS FOUND'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Clear search'));
      await tester.pump();
      expect(find.text('START YOUR SEARCH'), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(find.byType(TextField), 'Lionel Messi');
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('search routes preserve Shop and Top tab selections on back', (
    tester,
  ) async {
    final bloc = GameBloc(SecureGameStorage());
    addTearDown(bloc.close);
    await tester.pumpWidget(
      _app(bloc, ShopScreen(initialTab: 4, onNavigate: (_) {})),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CoinsTab), findsOneWidget);
    expect(find.byKey(const ValueKey('shop-search-button')), findsOneWidget);
    await tester.tap(find.byTooltip('Search Shop'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ShopSearchScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CoinsTab), findsOneWidget);
    await tester.pumpWidget(_app(bloc, LeaderboardScreen(onNavigate: (_) {})));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('leaderboard-search-button')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Search Leaderboard'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'Falcon9');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(RivalSearchResultCard), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(LeaderboardScreen), findsOneWidget);
    expect(find.byType(UserSearchScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unaffordable search purchase preserves wallet and query', (
    tester,
  ) async {
    final bloc = GameBloc(SecureGameStorage());
    addTearDown(bloc.close);
    await tester.pumpWidget(_app(bloc, const ShopSearchScreen()));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Lionel Messi card');
    await tester.pump(const Duration(milliseconds: 500));
    final before = bloc.state.coins;
    await tester.tap(find.text('54,000'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(bloc.state.coins, before);
    expect(find.byType(ShopAcquireOverlay), findsNothing);
    expect(find.textContaining('Not enough coins'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Lionel Messi card',
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'shop result purchase updates ownership once and retains query with reward reveal',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bloc = GameBloc(SecureGameStorage());
      addTearDown(bloc.close);
      bloc.add(CoinsAdded(1000));
      await tester.pumpWidget(_app(bloc, const ShopSearchScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.byType(TextField), 'Lionel Messi avatar');
      await tester.pump(const Duration(milliseconds: 500));
      final before = bloc.state.coins;
      await tester.tap(find.text('25').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(bloc.state.coins, before - 25);
      expect(
        bloc.state.ownedAvatarIds,
        contains(
          allPlayerCards
              .firstWhere((card) => card.name == 'Lionel Messi')
              .shortName,
        ),
      );
      expect(find.byType(ShopAcquireOverlay), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Lionel Messi avatar',
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('OWNED'), findsOneWidget);
      expect(bloc.state.coins, before - 25);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _app(GameBloc bloc, Widget home) => MultiBlocProvider(
  providers: [
    BlocProvider<GameBloc>.value(value: bloc),
    BlocProvider<FriendsCubit>(
      create: (_) => FriendsCubit(SecureGameStorage()),
    ),
  ],
  child: MaterialApp(theme: AppTheme.darkTheme, home: home),
);
