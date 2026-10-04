import 'dart:io';
import 'dart:ui' as ui;

import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_state.dart';
import 'package:card_game/config/theme.dart';
import 'package:card_game/config/tutorial_steps.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/screens/game/widgets/duel_board_phase.dart';
import 'package:card_game/screens/home/home_screen.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/utils/sound_effects.dart';
import 'package:card_game/widgets/cyber/cyber_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pitch_duel_presentation_test.dart' show fixture;

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('PITCH_VISUAL_QA')) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final folder = Directory('tmp/pitch_qa')..createSync(recursive: true);
    await File(
      '${folder.path}/$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

Widget app(GameBloc bloc, GlobalKey key, Widget child, double text) =>
    BlocProvider.value(
      value: bloc,
      child: RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(text),
              disableAnimations: true,
            ),
            child: GameTypographyScope(child: child!),
          ),
          home: child,
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in [
      ('Orbitron', 'Orbitron'),
      ('Exo 2', 'Exo2'),
      ('Onest', 'Onest'),
    ]) {
      await (FontLoader(font.$1)..addFont(
            rootBundle.load('assets/fonts/${font.$2}-VariableFont_wght.ttf'),
          ))
          .load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    AudioController.debugUseBackend(_SilentAudioBackend());
    AudioController.instance.muted.value = true;
  });

  testWidgets(
    'playing-card fronts, backs and used states stay legible at enlarged text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final bloc = GameBloc(SecureGameStorage());
      addTearDown(bloc.close);
      final key = GlobalKey();
      final base = GameState.initial();
      for (final scale in [1.0, 1.4]) {
        await tester.pumpWidget(
          app(
            bloc,
            key,
            Scaffold(
              backgroundColor: Cyber.bg,
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Text('PITCH DUEL', style: Cyber.display(22)),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CyberPlayerCardTile(
                          card: base.deckAttackers.first,
                          selected: false,
                          size: VisualCardSize.lg,
                          onTap: () {},
                        ),
                        CyberPlayerCardTile(
                          card: base.deckDefenders.first,
                          selected: true,
                          size: VisualCardSize.lg,
                          onTap: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CyberActionCardTile(
                          card: actionCards.first,
                          selected: false,
                          size: VisualCardSize.lg,
                          onTap: () {},
                        ),
                        CyberActionCardTile(
                          card: actionCards[6],
                          selected: true,
                          size: VisualCardSize.lg,
                          comboBonus: 10,
                          onTap: () {},
                        ),
                        const SizedBox(
                          width: 72,
                          height: 108,
                          child: CardBackFace(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    CyberPlayerCardTile(
                      card: base.deckAttackers.last,
                      selected: false,
                      disabled: true,
                      disabledLabel: 'USED',
                    ),
                  ],
                ),
              ),
            ),
            scale,
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        await precache(tester, [
          base.deckAttackers.first,
          base.deckDefenders.first,
          base.deckAttackers.last,
        ]);
        await capture(tester, key, 'cards-$scale');
        expect(tester.takeException(), isNull);
        expect(find.text('USED'), findsOneWidget);
        await tester.longPress(find.byType(CyberPlayerCardTile).first);
        await tester.pumpAndSettle();
        expect(find.textContaining('One affinity +4.'), findsOneWidget);
        await tester.tap(find.text('BACK TO CARDS'));
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('real-font attack and defense board cards fit phone layouts', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bloc = GameBloc(SecureGameStorage());
    addTearDown(bloc.close);
    final key = GlobalKey();
    for (final size in [const Size(360, 740), const Size(412, 915)]) {
      await tester.binding.setSurfaceSize(size);
      for (final attacking in [true, false]) {
        final state = fixture(
          attacking: attacking,
        ).copyWith(tutorialSeen: tutorialKeys.toSet());
        // ignore: invalid_use_of_visible_for_testing_member
        bloc.emit(state);
        await tester.pumpWidget(
          app(bloc, key, DuelBoardPhase(state: state, onQuit: () {}), 1.4),
        );
        await tester.pump(const Duration(milliseconds: 1000));
        await precache(tester, [
          ...state.deckAttackers,
          ...state.deckDefenders,
        ]);
        await capture(
          tester,
          key,
          'board-${size.width.toInt()}-${attacking ? 'attack' : 'defense'}',
        );
        expect(tester.takeException(), isNull);
        expect(find.textContaining('COMMIT').hitTestable(), findsOneWidget);
      }
    }
  });

  testWidgets(
    'lobby keeps PLAY MATCH reachable alongside the next skill goal',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final state = fixture().copyWith(
        loading: false,
        starterPackClaimed: true,
        ownedCardIds: [
          ...GameState.initial().deckAttackers,
          ...GameState.initial().deckDefenders,
          GameState.initial().deckKeeper!,
        ].map((p) => p.id).toList(),
        ownedActionCardIds: GameState.initial().deckActions
            .map((p) => p.id)
            .toList(),
      );
      final bloc = GameBloc(SecureGameStorage());
      // ignore: invalid_use_of_visible_for_testing_member
      bloc.emit(state);
      addTearDown(bloc.close);
      final key = GlobalKey();
      await tester.pumpWidget(
        app(
          bloc,
          key,
          HomeScreen(onNavigate: (_) {}, showBottomNavigation: false),
          1.4,
        ),
      );
      await tester.pump(const Duration(milliseconds: 1200));
      await precache(tester, [
        ...state.deckAttackers,
        ...state.deckDefenders,
        state.deckKeeper!,
      ]);
      await capture(tester, key, 'lobby-360');
      expect(tester.takeException(), isNull);
      expect(find.text('PLAY MATCH').hitTestable(), findsOneWidget);
      expect(find.text('LINK TWO PLAYS'), findsOneWidget);
    },
  );
}

Future<void> precache(WidgetTester tester, List<PlayerCard> players) async {
  final context = tester.element(find.byType(Scaffold).first);
  await tester.runAsync(() async {
    for (final asset in [
      ...players.map((p) => p.resolvedPortraitAsset).whereType<String>(),
      'assets/pitch_duel/board_texture.png',
      'assets/pitch_duel/lobby_stadium.png',
      'assets/icons/app_logo.png',
    ]) {
      await precacheImage(AssetImage(asset), context);
    }
  });
  await tester.pump();
}

class _SilentAudioBackend implements AudioPlaybackBackend {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}
