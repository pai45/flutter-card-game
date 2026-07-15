import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/blocs/super_over/super_over_state.dart';
import 'package:card_game/models/super_over.dart';
import 'package:card_game/models/super_over_stats.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/data/super_over_batter_profiles.dart';
import 'package:card_game/screens/super_over/super_over_lobby_screen.dart';
import 'package:card_game/screens/super_over/widgets/final_stand_match_hud.dart';
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
    var backedOut = false;
    SuperOverMode? selectedMode;
    await tester.pumpWidget(
      BlocProvider<GameBloc>.value(
        value: gameBloc,
        child: MaterialApp(
          home: SuperOverLobbyScreen(
            onBack: () => backedOut = true,
            onStartGame: () {},
            onEditDeck: () => openedDeckBuilder = true,
            onJerseySelected: (_) {},
            selectedMode: SuperOverMode.chase,
            onModeChanged: (mode) => selectedMode = mode,
            stats: const SuperOverStats(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('SUPER OVER'), findsAtLeastNWidgets(1));
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

    await tester.tap(find.byKey(const ValueKey('super-over-mode-scoreAttack')));
    expect(selectedMode, SuperOverMode.scoreAttack);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    expect(backedOut, isTrue);

    tester
        .widget<CyberCtaButton>(
          find.byKey(const ValueKey('super-over-deck-builder-button')),
        )
        .onPressed
        ?.call();
    expect(openedDeckBuilder, isTrue);
  });

  testWidgets('live overlay exposes field-aware shot controls', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ShotSector? selectedSector;
    ShotStyle? selectedStyle;
    var paused = false;
    var swung = false;
    await tester.pumpWidget(
      MaterialApp(
        home: FinalStandMatchHud(
          state: SuperOverState(
            phase: SuperOverPhase.ballInFlight,
            inputEnabled: true,
            battingOrder: cricketBattingCards.take(3).toList(),
          ),
          onBatTap: () => swung = true,
          onExit: () {},
          onPause: () => paused = true,
          onSectorSelected: (sector) => selectedSector = sector,
          onShotStyleSelected: (style) => selectedStyle = style,
        ),
      ),
    );

    expect(find.text('OFF'), findsOneWidget);
    expect(find.text('STRAIGHT'), findsOneWidget);
    expect(find.text('LEG'), findsOneWidget);
    expect(find.text('GROUND'), findsOneWidget);
    expect(find.text('LOFT'), findsOneWidget);
    expect(find.textContaining('TAP TO SWING'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('final-stand-aim-leg')));
    await tester.tap(find.byKey(const ValueKey('final-stand-shot-loft')));
    await tester.tap(find.byKey(const ValueKey('final-stand-bat')));
    await tester.tap(find.byTooltip('Pause match'));
    expect(selectedSector, ShotSector.leg);
    expect(selectedStyle, ShotStyle.loft);
    expect(swung, isTrue);
    expect(paused, isTrue);
    expect(find.byKey(const ValueKey('super-over-sector-leg')), findsNothing);
  });

  testWidgets('target reveal exposes a working START control', (tester) async {
    var started = false;
    await tester.pumpWidget(
      MaterialApp(
        home: FinalStandMatchHud(
          state: SuperOverState(
            phase: SuperOverPhase.targetReveal,
            mode: SuperOverMode.chase,
            cpuTarget: 10,
            battingOrder: cricketBattingCards.take(3).toList(),
          ),
          onBatTap: () => started = true,
          onExit: () {},
          onPause: () {},
          onSectorSelected: (_) {},
          onShotStyleSelected: (_) {},
        ),
      ),
    );

    expect(find.text('CHASE 11'), findsOneWidget);
    expect(find.text('START OVER'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('final-stand-start')));
    expect(started, isTrue);
  });

  testWidgets('live overlay fits a compact 360x800 portrait', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: FinalStandMatchHud(
          state: SuperOverState(
            phase: SuperOverPhase.ballInFlight,
            inputEnabled: true,
            battingOrder: cricketBattingCards.take(3).toList(),
          ),
          onBatTap: () {},
          onExit: () {},
          onPause: () {},
          onSectorSelected: (_) {},
          onShotStyleSelected: (_) {},
        ),
      ),
    );

    expect(find.text('STRAIGHT'), findsOneWidget);
    final fictional = SuperOverBatterProfiles.fromCard(
      cricketBattingCards.first,
      orderIndex: 0,
    );
    expect(find.text(fictional.displayName), findsOneWidget);
    expect(find.textContaining('Virat Kohli'), findsNothing);
  });

  testWidgets('live overlay supports tablet, larger text, and left controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: FinalStandMatchHud(
            state: SuperOverState(
              phase: SuperOverPhase.ballInFlight,
              inputEnabled: true,
              battingOrder: cricketBattingCards.take(3).toList(),
              settings: const SuperOverSettings(
                leftHandedControls: true,
                largerFieldRadar: true,
                batButtonScale: 1.25,
                controlOpacity: .8,
              ),
            ),
            onBatTap: () {},
            onExit: () {},
            onPause: () {},
            onSectorSelected: (_) {},
            onShotStyleSelected: (_) {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('BAT'), findsOneWidget);
    expect(
      tester.getCenter(find.text('BAT')).dx,
      lessThan(tester.getCenter(find.text('STRAIGHT')).dx),
    );
  });
}
