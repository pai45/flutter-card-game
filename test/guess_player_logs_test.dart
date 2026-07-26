import 'package:card_game/blocs/guess_player/guess_player_cubit.dart';
import 'package:card_game/config/theme.dart';
import 'package:card_game/data/guess_player_data.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/models/guess_player.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/screens/guess_player/guess_player_logs_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('guess player archive uses dates without revealing answers', (
    tester,
  ) async {
    final repository = LocalGuessPlayerPuzzleRepository(
      sport: Sport.football,
      timelines: footballGuessTimelines,
      players: footballPlayerCards,
    );
    final puzzle = repository.puzzles.first;
    final target = footballPlayerCards.firstWhere(
      (player) => player.id == puzzle.playerId,
    );
    final record = GuessPlayerDayRecord(
      dayKey: '2026-07-02',
      puzzleId: puzzle.id,
      playerId: target.id,
      targetPlayerName: target.name,
      status: GuessPlayerResultStatus.won,
      guessedPlayerIds: [target.id],
      revealedClueCount: 1,
      attemptsRemaining: GuessPlayerCubit.maxAttempts,
      score: 600,
      xpEarned: 50,
      elapsedMs: 12000,
      startedAtEpochMs: 1,
      completedAtEpochMs: 2,
    );
    final archive = GuessPlayerArchive(
      resultsByDay: {'2026-07-02': record},
    );
    final state = GuessPlayerState(
      loadStatus: GuessPlayerLoadStatus.ready,
      viewMode: GuessPlayerViewMode.logs,
      archive: archive,
      currentDayKey: '2026-07-02',
      activeDayKey: '2026-07-02',
      puzzle: puzzle,
      targetPlayer: target,
      activeRecord: record,
      attemptsRemaining: GuessPlayerCubit.maxAttempts,
      revealedClueCount: 1,
      guesses: [target],
      feedback: GuessPlayerSubmissionFeedback.none,
      feedbackSerial: 0,
      saving: false,
      settlementPending: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: GuessPlayerLogsScreen(
          state: state,
          onBack: () {},
          onOpenDay: (_) async => true,
        ),
      ),
    );

    expect(find.text('30-DAY INTEL ARCHIVE'), findsOneWidget);
    expect(find.text('JUL 2'), findsOneWidget);
    expect(find.text(target.name.toUpperCase()), findsNothing);
    expect(find.text('SOLVED'), findsWidgets);
    expect(find.text('600 PTS · +50 XP'), findsOneWidget);
  });
}
