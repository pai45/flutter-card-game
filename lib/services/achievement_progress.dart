import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/game/game_bloc.dart';
import '../blocs/picks/picks_cubit.dart';
import '../blocs/prediction/prediction_cubit.dart';
import '../models/achievement.dart';
import '../models/picks.dart';
import '../models/player_stats.dart';

/// Builds the live [AchievementStats] snapshot the catalogue measures against,
/// reading the three source blocs (game / prediction / picks). This is the
/// single source of truth — the Profile screen renders from it, and the
/// app-root achievement watcher diffs successive snapshots to detect unlocks.
AchievementStats currentAchievementStats(BuildContext context) {
  final game = context.read<GameBloc>().state;
  final pred = context.read<PredictionCubit>().state;
  final picks = context.read<PicksCubit>().state;
  final record = MatchRecord.fromHistory(game.matchHistory);

  final wonPicks = picks.positions.values
      .where((p) => p.status == PickPositionStatus.won)
      .length;

  return AchievementStats(
    level: game.progression.playerLevel,
    totalXP: game.progression.totalXP,
    matchesPlayed: record.played,
    matchWins: record.wins,
    bestMatchStreak: record.bestStreak,
    cleanSheets: record.cleanSheets,
    shootoutWins: record.shootoutWins,
    basketballWins: record.basketballWins,
    predictionsMade: pred.predictionsMade,
    correctPredictions: pred.correctPredictions,
    picksPlaced: picks.positions.length,
    picksWon: wonPicks,
    pickStreak: picks.winStreak,
    pickProfit: picks.realizedProfitOz,
    ownedCards: game.ownedCardIds.length + game.ownedActionCardIds.length,
    platinumOwned: ownedPlatinumCount(game.ownedCardIds),
    coins: game.coins,
  );
}
