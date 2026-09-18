import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_state.dart';
import 'package:card_game/config/theme.dart';
import 'package:card_game/models/daily_quest.dart';
import 'package:card_game/screens/predictions/widgets/daily_quest_panel.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/utils/sound_effects.dart';
import 'package:card_game/widgets/streak_celebration_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuestWidgetBloc extends GameBloc {
  QuestWidgetBloc(DailyQuestSnapshot quests) : super(SecureGameStorage()) {
    emit(state.copyWith(loading: false, dailyQuests: quests));
  }
}

void main() {
  setUp(() {
    for (final channel in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    AudioController.instance.muted.value = true;
  });

  testWidgets(
    'narrow enlarged-text quests expose both alternatives and game destinations',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final bloc = QuestWidgetBloc(
        const DailyQuestSnapshot().refresh(DateTime.now()),
      );
      addTearDown(bloc.close);
      QuestDestination? selected;
      await tester.pumpWidget(
        BlocProvider<GameBloc>.value(
          value: bloc,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.4),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DailyQuestPanel(
                    state: bloc.state,
                    onNavigate: (destination) => selected = destination,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('1 prediction or 2 games.'), findsOneWidget);
      expect(find.text('1 pick or 3 games.'), findsOneWidget);
      await tester.ensureVisible(find.text('PLAY GAME').first);
      await tester.tap(find.text('PLAY GAME').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('CHOOSE YOUR GAME'), findsOneWidget);
      await tester.tap(find.text('DAILY GUESS THE PLAYER'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(selected, QuestDestination.guessPlayer);
      await tester.ensureVisible(find.text('MAKE PICK'));
      await tester.tap(find.text('MAKE PICK'));
      expect(selected, QuestDestination.pick);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'claim shows the coin reveal and changes ready quests to claimed',
    (tester) async {
      final now = DateTime.now();
      var quests = const DailyQuestSnapshot();
      for (var i = 0; i < 3; i++) {
        quests = quests.record(
          DailyQuestActivity.pitchDuel,
          'game-$i',
          now,
          now: now,
        );
      }
      final bloc = QuestWidgetBloc(quests);
      addTearDown(bloc.close);
      await tester.pumpWidget(
        BlocProvider<GameBloc>.value(
          value: bloc,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: Stack(
                children: [
                  child!,
                  const Positioned.fill(child: StreakCelebrationHost()),
                ],
              ),
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: BlocBuilder<GameBloc, GameState>(
                  builder: (context, state) => DailyQuestPanel(state: state),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('READY'), findsNWidgets(4));
      expect(find.text('+1 SHIELD'), findsOneWidget);
      await tester.ensureVisible(find.text('CLAIM REWARDS'));
      await tester.tap(find.text('CLAIM REWARDS'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(bloc.state.coins, 50);
      expect(find.text('QUEST REWARDS'), findsOneWidget);
      expect(find.text('+50'), findsOneWidget);
      expect(find.text('CLAIMED'), findsNWidgets(4));
      await tester.tap(find.text('CONTINUE'));
      await tester.pump();
      await tester.pump();
      expect(find.text('QUEST REWARDS'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
