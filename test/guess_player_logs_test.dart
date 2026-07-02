import 'package:card_game/blocs/guess_player/guess_player_cubit.dart';
import 'package:card_game/data/guess_player_data.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/models/guess_player.dart';
import 'package:card_game/screens/guess_player/guess_player_logs_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('guess player logs use the date as the log title', (
    tester,
  ) async {
    final timeline = guessPlayerTimelines.first;
    final target = allPlayerCards.firstWhere(
      (player) => player.name == timeline.playerName,
      orElse: () => allPlayerCards.first,
    );
    final state = GuessPlayerState(
      targetPlayer: target,
      timeline: timeline,
      remainingHearts: GuessPlayerCubit.maxHearts,
      guesses: const [],
      hintsRevealed: 0,
      gameState: GuessPlayerGameState.won,
      archive: GuessPlayerArchive(
        resultsByDay: {
          '2026-07-02': GuessPlayerDailyResult(
            won: true,
            heartsRemaining: 7,
            targetPlayerName: target.name,
          ),
        },
      ),
      todayKey: '2026-07-02',
      unlockedDayKeys: const ['2026-07-02'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GuessPlayerLogsScreen(
          state: state,
          onBack: () {},
          onOpenDay: (_) {},
        ),
      ),
    );

    expect(find.text('MYSTERY LOGS'), findsOneWidget);
    expect(find.text('JUL 2, 2026'), findsOneWidget);
    expect(find.text(target.name.toUpperCase()), findsNothing);
    expect(find.text('MYSTERY PLAYER'), findsNothing);
    expect(find.text('GUESSED'), findsWidgets);
  });
}
