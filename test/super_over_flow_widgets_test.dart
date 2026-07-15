import 'package:card_game/blocs/super_over/super_over_state.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/models/super_over.dart';
import 'package:card_game/models/super_over_stats.dart';
import 'package:card_game/screens/super_over/super_over_pre_match_screen.dart';
import 'package:card_game/screens/super_over/widgets/super_over_pause_overlay.dart';
import 'package:card_game/screens/super_over/widgets/super_over_result.dart';
import 'package:card_game/screens/super_over/widgets/final_stand_coach_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'pre-match briefing exposes target, difficulty, and reward rules',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: SuperOverPreMatchScreen(
            mode: SuperOverMode.chase,
            difficulty: SuperOverDifficulty.pro,
            battingOrder: cricketBattingCards.take(3).toList(),
            jersey: CricketJersey.nightCyan,
            stats: const SuperOverStats(),
            target: 15,
            objective: const SuperOverObjective(
              type: SuperOverObjectiveType.runs,
              target: 16,
            ),
            onDifficultyChanged: (_) {},
            onStart: () {},
            onBack: () {},
          ),
        ),
      );

      expect(find.text('YOU NEED 16'), findsOneWidget);
      expect(find.text('STATOZ NIGHT ARENA'), findsOneWidget);
      expect(find.textContaining('+8 objective'), findsOneWidget);
      expect(find.text('START OVER'), findsOneWidget);
    },
  );

  testWidgets('pause surface includes controls, audio, restart, and quit', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: SuperOverPauseOverlay(
          settings: const SuperOverSettings(),
          onSettingsChanged: (_) {},
          onResume: () {},
          onRestart: () {},
          onQuit: () {},
        ),
      ),
    );

    expect(find.text('MATCH PAUSED'), findsOneWidget);
    expect(find.text('Left-handed layout'), findsOneWidget);
    expect(find.text('SOUND'), findsOneWidget);
    expect(find.text('RESTART OVER'), findsOneWidget);
    expect(find.text('QUIT TO SUPER OVER'), findsOneWidget);
  });

  testWidgets('tutorial announces the scripted Need 6 from 2 lesson', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FinalStandCoachOverlay(
          state: SuperOverState(ballsFaced: 4, phase: SuperOverPhase.ballSetup),
          onSkip: _noop,
        ),
      ),
    );

    expect(find.text('NEED 6 FROM 2'), findsOneWidget);
    expect(find.text('SKIP'), findsOneWidget);
  });

  testWidgets('result shows grade, insight, exact XP, and all actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final summary = _summary();
    await tester.pumpWidget(
      MaterialApp(
        home: SuperOverResult(
          state: SuperOverState(
            mode: SuperOverMode.chase,
            score: 18,
            ballsFaced: 4,
            wonChase: true,
            isOver: true,
            battingOrder: cricketBattingCards.take(3).toList(),
            wagonWheel: const [
              ShotOutcome.four,
              ShotOutcome.six,
              ShotOutcome.two,
              ShotOutcome.six,
            ],
            summary: summary,
          ),
          previousHigh: 12,
          settings: const SuperOverSettings(
            soundEnabled: false,
            hapticsEnabled: false,
          ),
          onPlayAgain: _noop,
          onChangeMode: _noop,
          onChangeBatters: _noop,
          onExit: _noop,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.textContaining('GRADE A'), findsOneWidget);
    expect(find.text('IMPROVEMENT INSIGHT'), findsOneWidget);
    expect(find.text('XP BREAKDOWN'), findsOneWidget);
    expect(find.text('PLAY AGAIN'), findsOneWidget);
    expect(find.text('CHANGE MODE'), findsOneWidget);
    expect(find.text('CHANGE BATTERS'), findsOneWidget);
    expect(find.text('BACK TO GAMES'), findsOneWidget);
  });
}

void _noop() {}

SuperOverMatchSummary _summary() => SuperOverMatchSummary(
  matchId: 'widget-summary',
  seed: 3,
  mode: SuperOverMode.chase,
  difficulty: SuperOverDifficulty.pro,
  target: 17,
  score: 18,
  wickets: 0,
  ballsFaced: 4,
  wonChase: true,
  objective: const SuperOverObjective(
    type: SuperOverObjectiveType.runs,
    target: 16,
  ),
  objectiveComplete: true,
  battingCardIds: cricketBattingCards.take(3).map((card) => card.id).toList(),
  ballRecords: const [],
  finishingBatterCardId: cricketBattingCards.first.id,
  grade: SuperOverPerformanceGrade.a,
);
