import 'package:card_game/config/enums.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/models/match.dart';
import 'package:card_game/screens/game/widgets/round_result_cinematic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

RoundResult _sampleResult({required bool playerAttacking}) {
  final attackAction = actionCards.firstWhere((c) => c.title == 'All In');
  final defenseAction = actionCards.firstWhere(
    (c) => c.title == 'Last-Ditch Tackle',
  );
  return RoundResult(
    round: 1,
    scenario: scenarios.first,
    playerAttacking: playerAttacking,
    attackerCard: attackers.first,
    defenderCard: defenders.first,
    attackAction: attackAction,
    defenseAction: defenseAction,
    outcome: RoundOutcome.foul,
    attackPower: 115,
    defensePower: 129,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpArena(
    WidgetTester tester, {
    required RoundResult result,
    required double progress,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final arenaKey = GlobalKey<RoundClashArenaState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: RoundClashArena(key: arenaKey, result: result),
          ),
        ),
      ),
    );
    await tester.pump();
    arenaKey.currentState!.jumpToProgress(progress);
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  testWidgets('RoundClashArena has no overflow across animation timeline', (
    tester,
  ) async {
    for (final attacking in [true, false]) {
      final result = _sampleResult(playerAttacking: attacking);
      for (final progress in [
        0.0,
        0.12,
        0.26,
        0.33,
        0.38,
        0.55,
        0.76,
        0.9,
        1.0,
      ]) {
        await pumpArena(tester, result: result, progress: progress);
      }
    }
  });
}
