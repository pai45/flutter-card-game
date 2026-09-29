import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/blocs/game/game_state.dart';
import 'package:card_game/config/game_ladder.dart';
import 'package:card_game/config/theme.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/models/unlock_progress.dart';
import 'package:card_game/screens/predictions/widgets/unlock_sheets.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/widgets/cyber/cyber_widgets.dart';
import 'package:card_game/widgets/unlock_celebration_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestBloc extends GameBloc {
  _TestBloc(Sport target, int coins) : super(SecureGameStorage()) {
    emit(
      GameState.initial().copyWith(
        loading: false,
        coins: coins,
        unlocks: UnlockProgress.fresh(
          target == Sport.football ? Sport.cricket : Sport.football,
        ),
      ),
    );
  }
  final purchases = <SportUnlockPurchased>[];
  @override
  void add(GameEvent event) {
    if (event is SportUnlockPurchased) purchases.add(event);
    super.add(event);
  }
}

Widget _app(Widget home, {double scale = 1, bool reduced = true}) =>
    MaterialApp(
      theme: AppTheme.darkTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduced,
        ),
        child: child!,
      ),
      home: Scaffold(body: home),
    );

Future<void> _open(
  WidgetTester tester,
  _TestBloc bloc,
  Sport sport, {
  double scale = 1,
  ValueChanged<bool>? result,
}) async {
  await tester.pumpWidget(
    BlocProvider<GameBloc>.value(
      value: bloc,
      child: _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final purchased = await showSportUnlockSheet(context, sport);
              result?.call(purchased);
            },
            child: const Text('OPEN'),
          ),
        ),
        scale: scale,
      ),
    ),
  );
  await tester.tap(find.text('OPEN'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('every sport route fits mobile and enlarged short viewports', (
    tester,
  ) async {
    for (final size in [const Size(393, 852), const Size(320, 600)]) {
      await tester.binding.setSurfaceSize(size);
      for (final sport in Sport.values) {
        final bloc = _TestBloc(sport, 80);
        await _open(
          tester,
          bloc,
          sport,
          scale: size.width == 320 ? 1.4 : 1,
          result: (_) {},
        );
        expect(find.text('OPENS ON UNLOCK'), findsOneWidget);
        for (final game in sportGameLadder[sport]!) {
          final entry = find.byKey(ValueKey('sport-unlock-game-${game.name}'));
          await tester.ensureVisible(entry);
          await tester.pump();
          expect(
            find.descendant(of: entry, matching: find.text(game.title)),
            findsOneWidget,
          );
        }
        for (final game in sportGameLadder[sport]!.skip(1)) {
          expect(
            find.text(
              'AFTER ${sportGameLadder[sport]![game.ladderIndex - 1].title}',
            ),
            findsOneWidget,
          );
        }
        await tester.ensureVisible(
          find.byKey(const ValueKey('sport-unlock-cta')),
        );
        expect(tester.takeException(), isNull, reason: '$sport / $size');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(bloc.close);
      }
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('insufficient funds disable purchase and route to quests', (
    tester,
  ) async {
    for (final coins in [0, 49]) {
      final bloc = _TestBloc(Sport.cricket, coins);
      var quests = 0;
      bool? result;
      UnlockRevealGate.instance.openQuestHub = () => quests++;
      await _open(
        tester,
        bloc,
        Sport.cricket,
        result: (value) => result = value,
      );
      final purchase = tester.widget<CyberActionButton>(
        find.byKey(const ValueKey('sport-unlock-cta')),
      );
      expect(purchase.onPressed, isNull);
      expect(find.text('NEED ${50 - coins} MORE OZ'), findsOneWidget);
      final action = find.byKey(const ValueKey('sport-unlock-quests'));
      await tester.ensureVisible(action);
      await tester.pump();
      await tester.tap(action);
      await tester.pump(const Duration(milliseconds: 400));
      expect(quests, 1);
      expect(result, isFalse);
      expect(bloc.purchases, isEmpty);
      expect(bloc.state.coins, coins);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(bloc.close);
    }
    UnlockRevealGate.instance.openQuestHub = null;
  });

  testWidgets('affordable purchases dismiss once and retain queued reveal', (
    tester,
  ) async {
    for (final coins in [50, 80]) {
      final bloc = _TestBloc(Sport.cricket, coins);
      bool? result;
      await _open(
        tester,
        bloc,
        Sport.cricket,
        result: (value) => result = value,
      );
      expect(find.text('${coins - 50} OZ'), findsOneWidget);
      final action = tester.widget<CyberActionButton>(
        find.byKey(const ValueKey('sport-unlock-cta')),
      );
      action.onPressed!();
      action.onPressed!();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(result, isTrue);
      expect(bloc.purchases.length, 1);
      // Let the real bloc's asynchronous mock-storage settlement complete.
      await tester.runAsync(() async {
        if (!bloc.state.unlocks.isSportUnlocked(Sport.cricket)) {
          await bloc.stream
              .firstWhere(
                (state) => state.unlocks.isSportUnlocked(Sport.cricket),
              )
              .timeout(const Duration(seconds: 3), onTimeout: () => bloc.state);
        }
      });
      expect(bloc.state.coins, coins - 50);
      expect(bloc.state.unlocks.isSportUnlocked(Sport.cricket), isTrue);
      expect(
        bloc.state.unlocks.pendingReveals.single.kind,
        UnlockRevealKind.sport,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(bloc.close);
    }
  });

  testWidgets('close control dismisses without a purchase', (tester) async {
    final bloc = _TestBloc(Sport.cricket, 80);
    bool? result;
    await _open(tester, bloc, Sport.cricket, result: (value) => result = value);
    await tester.tap(find.bySemanticsLabel('Close unlock sheet'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(result, isFalse);
    expect(bloc.purchases, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(bloc.close);
  });

  testWidgets('buttons expose semantics, keyboard actions and blocked states', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    for (final variant in CyberActionVariant.values) {
      await tester.pumpWidget(
        _app(
          Center(
            child: SizedBox(
              width: 280,
              child: CyberActionButton(
                key: ValueKey(variant),
                label: 'ACTIVATE',
                variant: variant,
                autofocus: true,
                onPressed: () => taps++,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.getSemantics(find.byType(CyberActionButton)),
        matchesSemantics(
          label: 'ACTIVATE',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          isFocused: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(taps, (variant.index + 1) * 2);
      expect(
        tester.getSize(find.byType(CyberActionButton)).height,
        greaterThanOrEqualTo(48),
      );
    }
    for (final loading in [false, true]) {
      await tester.pumpWidget(
        _app(
          CyberActionButton(
            label: 'BLOCKED',
            loading: loading,
            onPressed: loading ? () => taps++ : null,
          ),
        ),
      );
      await tester.tap(find.byType(CyberActionButton));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(taps, 6);
    }
    semantics.dispose();
  });

  testWidgets('reduced motion removes entrance and press animation', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        CyberKitSheet(
          body: const Text('CONTENT'),
          footer: CyberActionButton(label: 'ACTION', onPressed: () {}),
          onClose: () {},
        ),
      ),
    );
    final entrance = tester.widget<TweenAnimationBuilder<double>>(
      find.byType(TweenAnimationBuilder<double>),
    );
    expect(entrance.duration, Duration.zero);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('ACTION')),
    );
    await tester.pump();
    for (final animation in tester.widgetList<AnimatedScale>(
      find.byType(AnimatedScale),
    )) {
      expect(animation.duration, Duration.zero);
      expect(animation.scale, 1);
    }
    await gesture.up();
    expect(tester.takeException(), isNull);
  });
}
