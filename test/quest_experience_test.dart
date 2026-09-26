import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_state.dart';
import 'package:card_game/config/game_ladder.dart';
import 'package:card_game/config/theme.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/models/unlock_progress.dart';
import 'package:card_game/screens/predictions/widgets/beginner_quest_card.dart';
import 'package:card_game/screens/predictions/widgets/unlock_sheets.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/widgets/cyber/cyber_unlock_reveal.dart';
import 'package:card_game/widgets/cyber/cyber_widgets.dart';
import 'package:card_game/widgets/unlock_celebration_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReceiptBloc extends GameBloc {
  ReceiptBloc(GameState state) : super(SecureGameStorage()) { emit(state); }
}

Widget wrap(Widget child, {GameBloc? bloc, bool reduced = true}) {
  final app = MaterialApp(theme: AppTheme.darkTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.4),
        disableAnimations: reduced), child: child!),
    home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)));
  return bloc == null ? app : BlocProvider<GameBloc>.value(value: bloc, child: app);
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('every mission remains readable at 320px with enlarged text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final sport in Sport.values) {
      var progress = UnlockProgress.fresh(sport);
      for (final game in sportGameLadder[sport]!) {
        await tester.pumpWidget(wrap(RookiePathPanel(sport: sport,
          unlocks: progress, onPlay: (_) {})));
        await tester.pump();
        expect(find.text(game.questRequirement), findsOneWidget);
        expect(tester.takeException(), isNull, reason: game.name);
        progress = progress.recordPlay(game, game.name).progress;
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('receipt belongs only to the exact result, and continues once per tap', (tester) async {
    const receipt = QuestCompletionReceipt(game: ArcadeGame.finalOver, sourceId: 'run-1',
      completed: 1, total: 3, graduated: false, questCompleted: false,
      nextGame: ArcadeGame.cricketQuiz);
    final bloc = ReceiptBloc(GameState.initial().copyWith(questReceipts: {receipt.id: receipt}));
    addTearDown(bloc.close);
    var continued = 0;
    UnlockRevealGate.instance.continueQuest = () => continued++;
    addTearDown(() => UnlockRevealGate.instance.continueQuest = null);
    await tester.pumpWidget(wrap(const QuestResultReceipt(game: ArcadeGame.finalOver,
      sourceId: 'run-2'), bloc: bloc));
    expect(find.text('CONTINUE QUEST'), findsNothing);
    await tester.pumpWidget(wrap(const QuestResultReceipt(game: ArcadeGame.finalOver,
      sourceId: 'run-1'), bloc: bloc));
    expect(find.text('CRICKET QUIZ unlocked'), findsOneWidget);
    await tester.tap(find.text('CONTINUE QUEST'));
    expect(continued, 1);
  });

  testWidgets('reveal ignores background taps and reduced motion shows explicit controls', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var dismissed = 0;
    await tester.pumpWidget(MaterialApp(theme: AppTheme.darkTheme,
      home: MediaQuery(data: const MediaQueryData(size: Size(320, 852),
        textScaler: TextScaler.linear(1.4), disableAnimations: true),
        child: CyberUnlockReveal(eyebrow: 'BEGINNER CHAPTER COMPLETE',
          title: 'GUESS THE PLAYER', subtitle: '3 of 6 missions complete. Daily Quests unlocked.',
          icon: Icons.flag, accent: Cyber.cyan, onDismissed: () => dismissed++))));
    await tester.pump();
    await tester.tapAt(const Offset(8, 8));
    expect(dismissed, 0);
    await tester.ensureVisible(find.byKey(const ValueKey('unlock-reveal-continue')));
    await tester.tap(find.byKey(const ValueKey('unlock-reveal-continue')));
    expect(dismissed, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('sport purchase preview wraps prerequisites and cannot spend when broke', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bloc = ReceiptBloc(GameState.initial().copyWith(coins: 0,
      unlocks: UnlockProgress.fresh(Sport.cricket)));
    addTearDown(bloc.close);
    await tester.pumpWidget(BlocProvider<GameBloc>.value(value: bloc,
      child: MaterialApp(theme: AppTheme.darkTheme, home: Scaffold(body: Builder(
        builder: (context) => TextButton(onPressed: () => showSportUnlockSheet(context, Sport.football),
          child: const Text('Preview')))))));
    await tester.tap(find.text('Preview'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('AFTER PENALTY SHOOTOUT'), findsOneWidget);
    expect(bloc.state.coins, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
