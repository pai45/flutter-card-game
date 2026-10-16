import 'package:card_game/blocs/final_over/final_over_cubit.dart';
import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/config/theme.dart';
import 'package:card_game/models/final_over.dart';
import 'package:card_game/screens/final_over/final_over_hub.dart';
import 'package:card_game/screens/final_over/widgets/final_over_lobby_hero.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/utils/sound_effects.dart';
import 'package:card_game/screens/final_over/widgets/final_over_pixel_play_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    AudioController.debugUseBackend(_SilentAudio());
    AudioController.instance.muted.value = true;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<(GameBloc, FinalOverCubit)> mount(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
    bool incomplete = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = SecureGameStorage();
    final game = _LobbyGameBloc(storage);
    final finalOver = FinalOverCubit(storage);
    addTearDown(game.close);
    addTearDown(finalOver.close);
    await finalOver.load();
    game.add(GameLoaded());
    await game.stream.firstWhere((state) => !state.loading);
    if (incomplete) game.clearBattingDeck();
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<GameBloc>.value(value: game),
          BlocProvider.value(value: finalOver),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: FinalOverHub(onExit: () {}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    return (game, finalOver);
  }

  testWidgets(
    'minimal lobby keeps setup actionable and utilities behind menu',
    (tester) async {
      await mount(tester, incomplete: true);
      expect(find.text('FINAL OVER'), findsOneWidget);
      expect(find.text('Three overs. One chase.'), findsOneWidget);
      expect(find.byType(FinalOverLobbyHero), findsOneWidget);
      expect(find.text('ROOKIE'), findsNothing);
      final cta = tester.widget<FinalOverPixelPlayButton>(
        find.byKey(const ValueKey('final-over-play')),
      );
      expect(cta.label, 'BUILD SQUAD');
      expect(cta.onTap, isNotNull);
      expect(find.text('CRICKET DECK'), findsNothing);
      await tester.tap(find.byTooltip('Final Over menu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Cricket Deck'), findsOneWidget);
      expect(find.text('Match History'), findsOneWidget);
      expect(find.text('Leaderboard'), findsOneWidget);
      expect(
        tester
            .widget<FinalOverLobbyHero>(find.byType(FinalOverLobbyHero))
            .paused,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'difficulty selection updates existing Cubit and survives closing the sheet',
    (tester) async {
      final (_, cubit) = await mount(tester);
      await tester.tap(find.byTooltip('Final Over menu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.textContaining('Difficulty /'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.textContaining('ELITE'));
      await tester.pump();
      expect(cubit.state.tier, FinalOverTier.elite);
      await tester.tap(find.text('DONE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(cubit.state.tier, FinalOverTier.elite);
      expect(find.text('ELITE'), findsNothing);
      expect(
        tester
            .widget<FinalOverLobbyHero>(find.byType(FinalOverLobbyHero))
            .paused,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'authored vector animation loads, pauses under a panel and respects reduced motion',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final paused = ValueNotifier(false);
      final reduced = ValueNotifier(false);
      addTearDown(paused.dispose);
      addTearDown(reduced.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: reduced,
            builder: (context, reduce, _) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
              child: ValueListenableBuilder<bool>(
                valueListenable: paused,
                builder: (_, covered, _) => FinalOverLobbyHero(paused: covered),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await AssetLottie(FinalOverLobbyHero.animationAsset).load();
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final controller =
          tester.widget<Lottie>(find.byType(Lottie)).controller!
              as AnimationController;
      expect(controller.duration, const Duration(seconds: 12));
      expect(controller.isAnimating, isTrue);
      paused.value = true;
      await tester.pump();
      expect(controller.isAnimating, isFalse);
      paused.value = false;
      await tester.pump();
      expect(controller.isAnimating, isTrue);
      reduced.value = true;
      await tester.pump();
      expect(find.byType(Lottie), findsNothing);
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(controller.isAnimating, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(430, 932),
    const Size(1024, 768),
  ]) {
    testWidgets(
      'CTA stays reachable without overflow at $size with enlarged text',
      (tester) async {
        await mount(tester, size: size, scale: 2);
        final bounds = tester.getRect(
          find.byKey(const ValueKey('final-over-play')),
        );
        expect(bounds.bottom, lessThanOrEqualTo(size.height));
        expect(bounds.top, greaterThan(0));
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _SilentAudio implements AudioPlaybackBackend {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _LobbyGameBloc extends GameBloc {
  _LobbyGameBloc(super.storage);
  void clearBattingDeck() => emit(state.copyWith(deckFinalOverBatsmen: []));
}
